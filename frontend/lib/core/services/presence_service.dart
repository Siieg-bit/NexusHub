import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Serviço de presença online em tempo real usando Supabase Realtime Presence.
///
/// Cada comunidade tem um canal de presença separado (`presence:community:{id}`).
/// Quando o usuário entra em uma comunidade, ele faz `track()` no canal.
/// Quando sai, faz `untrack()`. O Supabase gerencia automaticamente a
/// desconexão (se o app crashar ou perder conexão, o leave é disparado).
///
/// Também mantém um canal global (`presence:global`) para presença geral.
class PresenceService {
  PresenceService._();
  static final PresenceService _instance = PresenceService._();
  static PresenceService get instance => _instance;

  final _supabase = Supabase.instance.client;

  /// Canais de presença ativos por communityId (ou 'global').
  final Map<String, RealtimeChannel> _channels = {};

  /// Controllers de stream para notificar mudanças de presença.
  /// Chave: communityId (ou 'global'), Valor: StreamController com Set de userIds online.
  final Map<String, StreamController<Set<String>>> _controllers = {};

  /// Cache local do estado de presença por canal.
  final Map<String, Set<String>> _presenceState = {};

  /// Timer para atualizar online_status no banco periodicamente.
  Timer? _heartbeatTimer;

  /// UserId do usuário atual.
  String? _currentUserId;

  // ── Inicialização ──

  /// Inicializa o serviço de presença para o usuário atual.
  /// Deve ser chamado após o login.
  Future<void> initialize() async {
    _currentUserId = SupabaseService.currentUserId;
    if (_currentUserId == null) return;

    // Iniciar presença global
    await joinChannel('global');

    // Heartbeat: atualizar last_seen_at a cada 2 minutos
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _updateHeartbeat(),
    );

    // Atualizar status online no banco
    await _setOnlineStatus(1);
  }

  /// Encerra o serviço de presença.
  /// Deve ser chamado no logout.
  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    // Sair de todos os canais
    final channelKeys = List<String>.from(_channels.keys);
    for (final key in channelKeys) {
      await leaveChannel(key);
    }

    // Atualizar status offline no banco
    await _setOnlineStatus(2);

    _currentUserId = null;
  }

  // ── Canais de Presença ──

  /// Entra em um canal de presença (comunidade ou global).
  Future<void> joinChannel(String channelId) async {
    final userId = _currentUserId;
    if (userId == null) return;
    if (_channels.containsKey(channelId)) return; // Já está no canal

    final channelName = channelId == 'global'
        ? 'presence:global'
        : 'presence:community:$channelId';

    final channel = _supabase.channel(
      channelName,
      opts: RealtimeChannelConfig(key: userId),
    );

    // Criar controller de stream se não existir
    _controllers[channelId] ??= StreamController<Set<String>>.broadcast();
    _presenceState[channelId] = {};

    // Escutar eventos de presença
    channel
        .onPresenceSync((_) {
          _handleSync(channelId, channel);
        })
        .onPresenceJoin((payload) {
          _handleJoin(channelId, payload);
        })
        .onPresenceLeave((payload) {
          _handleLeave(channelId, payload);
        });

    // Subscrever e fazer track
    channel.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        try {
          await channel.track({
            'user_id': userId,
            'online_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (e) {
          debugPrint('[PresenceService] Erro ao fazer track: $e');
        }
      }
    });

    _channels[channelId] = channel;
  }

  /// Sai de um canal de presença.
  Future<void> leaveChannel(String channelId) async {
    final channel = _channels.remove(channelId);
    if (channel != null) {
      try {
        await channel.untrack();
        await _supabase.removeChannel(channel);
      } catch (e) {
        debugPrint('[PresenceService] Erro ao sair do canal: $e');
      }
    }
    _presenceState.remove(channelId);
    // Não fechar o controller — pode ter listeners ativos
  }

  // ── Handlers de Eventos ──

  void _handleSync(String channelId, RealtimeChannel channel) {
    try {
      final state = channel.presenceState();
      final onlineUserIds = <String>{};

      for (final entry in state) {
        for (final presence in entry.presences) {
          final userId = presence.payload['user_id'] as String?;
          if (userId != null) {
            onlineUserIds.add(userId);
          }
        }
      }

      _presenceState[channelId] = onlineUserIds;
      _controllers[channelId]?.add(Set.unmodifiable(onlineUserIds));
    } catch (e) {
      debugPrint('[PresenceService] Erro no sync: $e');
    }
  }

  void _handleJoin(String channelId, dynamic payload) {
    try {
      if (payload is Map) {
        final newPresences = payload['newPresences'] as List?;
        if (newPresences != null) {
          for (final p in newPresences) {
            final userId = (p as Map?)?['user_id'] as String?;
            if (userId != null) {
              _presenceState[channelId]?.add(userId);
            }
          }
        }
      }
      final current = _presenceState[channelId];
      if (current != null) {
        _controllers[channelId]?.add(Set.unmodifiable(current));
      }
    } catch (e) {
      debugPrint('[PresenceService] Erro no join: $e');
    }
  }

  void _handleLeave(String channelId, dynamic payload) {
    try {
      if (payload is Map) {
        final leftPresences = payload['leftPresences'] as List?;
        if (leftPresences != null) {
          for (final p in leftPresences) {
            final userId = (p as Map?)?['user_id'] as String?;
            if (userId != null) {
              _presenceState[channelId]?.remove(userId);
            }
          }
        }
      }
      final current = _presenceState[channelId];
      if (current != null) {
        _controllers[channelId]?.add(Set.unmodifiable(current));
      }
    } catch (e) {
      debugPrint('[PresenceService] Erro no leave: $e');
    }
  }

  // ── Getters ──

  /// Stream de userIds online em um canal específico.
  Stream<Set<String>> onlineUsersStream(String channelId) {
    _controllers[channelId] ??= StreamController<Set<String>>.broadcast();
    return _controllers[channelId]!.stream;
  }

  /// Snapshot atual dos userIds online em um canal.
  Set<String> getOnlineUsers(String channelId) {
    return _presenceState[channelId] ?? {};
  }

  /// Contagem de membros online em um canal.
  int getOnlineCount(String channelId) {
    return _presenceState[channelId]?.length ?? 0;
  }

  /// Verifica se um usuário específico está online (em qualquer canal).
  bool isUserOnline(String userId) {
    for (final state in _presenceState.values) {
      if (state.contains(userId)) return true;
    }
    return false;
  }

  /// Verifica se um usuário está online em um canal específico.
  bool isUserOnlineInChannel(String channelId, String userId) {
    return _presenceState[channelId]?.contains(userId) ?? false;
  }

  // ── Helpers Privados ──

  Future<void> _updateHeartbeat() async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      await SupabaseService.table('profiles').update({
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (e) {
      debugPrint('[PresenceService] Erro no heartbeat: $e');
    }
  }

  Future<void> _setOnlineStatus(int status) async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      await SupabaseService.table('profiles').update({
        'online_status': status,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (e) {
      debugPrint('[PresenceService] Erro ao setar online_status: $e');
    }
  }
}
