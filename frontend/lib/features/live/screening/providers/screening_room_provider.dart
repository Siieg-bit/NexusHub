import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/realtime_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../services/streaming_rules_service.dart';
import '../models/screening_room_state.dart';
import '../models/screening_participant.dart';
import 'screening_voice_provider.dart';

// =============================================================================
// ScreeningRoomProvider — Gerencia o ciclo de vida da Sala de Projeção
//
// Responsabilidades:
// - Criar ou entrar em uma sessão existente
// - Gerenciar lista de participantes via Realtime Broadcast
// - Heartbeat de presença (30s)
// - Encerrar / sair da sala
// - Expor o estado da sala para os demais providers e widgets
// =============================================================================

final screeningRoomProvider = StateNotifierProvider.family<
    ScreeningRoomNotifier, ScreeningRoomState, String>(
  (ref, threadId) => ScreeningRoomNotifier(threadId: threadId, ref: ref),
);

class ScreeningRoomNotifier extends StateNotifier<ScreeningRoomState> {
  final String threadId;
  final Ref ref;

  RealtimeChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _cleanupTimer;
  /// Fila restaurada do metadata ao reentrar em sessão existente.
  /// Usada no joinRoom para passar ao copyWith antes de ser zerada.
  List<Map<String, String>>? _restoredQueue;

  ScreeningRoomNotifier({required this.threadId, required this.ref})
      : super(ScreeningRoomState(threadId: threadId));

  // ── Entrar na sala ──────────────────────────────────────────────────────────

  /// Entra em uma sessão existente ou cria uma nova.
  /// [existingSessionId] — ID de sessão existente (ao entrar como participante).
  /// [initialVideoUrl] — URL do vídeo inicial (passado pelo ScreeningCreateRoomSheet).
  /// [initialVideoTitle] — Título do vídeo inicial.
  /// [initialVideoThumbnail] — Thumbnail do vídeo inicial.
  Future<void> joinRoom({
    String? existingSessionId,
    String? initialVideoUrl,
    String? initialVideoTitle,
    String? initialVideoThumbnail,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      state = state.copyWith(
        status: ScreeningRoomStatus.error,
        errorMessage: 'Usuário não autenticado.',
      );
      return;
    }

    debugPrint('[ScreeningRoom] joinRoom() iniciado — userId=$userId, existingSessionId=$existingSessionId, threadId=$threadId');
    try {
      // Resetar o estado completamente antes de iniciar uma nova sessão.
      // Não usar copyWith aqui pois ele herda currentVideoUrl, videoQueue, etc.
      // da sessão anterior (copyWith não consegue setar campos para null).
      state = ScreeningRoomState(
        threadId: threadId,
        status: ScreeningRoomStatus.loading,
      );

      String sessionId;
      bool isHost;
      String? hostUserId;
      String? videoUrl;
      String? videoTitle;
      String? videoThumbnail;

      if (existingSessionId != null) {
        // ── Entrando em sessão existente ──
        debugPrint('[ScreeningRoom] Entrando em sessão existente: $existingSessionId');
        sessionId = existingSessionId;

        debugPrint('[ScreeningRoom] Chamando RPC get_screening_session_state...');
        final result = await SupabaseService.client
            .rpc('get_screening_session_state', params: {
          'p_session_id': sessionId,
        }).select();
        debugPrint('[ScreeningRoom] RPC get_screening_session_state resultado: $result');

        if (result == null || (result as List).isEmpty) {
          debugPrint('[ScreeningRoom] Sessão não encontrada ou encerrada — fechando.');
          state = state.copyWith(
            status: ScreeningRoomStatus.closed,
          );
          return;
        }

        final row = (result as List).first as Map<String, dynamic>;
        isHost = row['is_caller_host'] as bool? ?? false;
        hostUserId = row['host_user_id'] as String?;
        videoUrl = row['video_url'] as String?;
        videoTitle = row['video_title'] as String?;
        videoThumbnail = row['video_thumbnail'] as String?;
        debugPrint('[ScreeningRoom] Sessão encontrada — isHost=$isHost, hostUserId=$hostUserId, videoUrl=$videoUrl');

        // Restaurar a fila do metadata (persistida por _broadcastQueueUpdate).
        // O RPC get_screening_session_state não retorna a fila diretamente;
        // ela é armazenada no campo video_queue do metadata JSONB.
        // Buscar o metadata separadamente para restaurar a fila.
        try {
          final metaResult = await SupabaseService.client
              .from('call_sessions')
              .select('metadata')
              .eq('id', sessionId)
              .maybeSingle();
          if (metaResult != null) {
            final meta = metaResult['metadata'] as Map<String, dynamic>?;
            final rawQueue = meta?['video_queue'] as List<dynamic>?;
            if (rawQueue != null && rawQueue.isNotEmpty) {
              // Restaurar a fila no estado local antes do state = state.copyWith()
              // abaixo, que define videoQueue: const [].
              // Usamos uma variável local para passar ao copyWith.
              _restoredQueue = rawQueue
                  .map((e) => Map<String, String>.from(
                      (e as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
                  .toList();
              debugPrint('[ScreeningRoom] Fila restaurada do metadata: ${_restoredQueue!.length} itens');
            }
          }
        } catch (e) {
          debugPrint('[ScreeningRoom] Erro ao restaurar fila do metadata: $e');
        }

        // Registrar como participante
        debugPrint('[ScreeningRoom] Chamando _joinAsParticipant...');
        await _joinAsParticipant(sessionId: sessionId, userId: userId);
        debugPrint('[ScreeningRoom] _joinAsParticipant concluído.');
      } else {
        // ── Criando nova sessão (host) via RPC — regra de ouro: sem INSERT direto ──
        debugPrint('[ScreeningRoom] Criando nova sessão como host via RPC — threadId=$threadId, videoUrl=$initialVideoUrl');
        final rpcResult = await SupabaseService.rpc(
          'create_screening_session',
          params: {
            'p_thread_id':       threadId,
            'p_video_url':       initialVideoUrl ?? '',
            'p_video_title':     initialVideoTitle ?? '',
            'p_video_thumbnail': initialVideoThumbnail ?? '',
          },
        );

        final rpcData = rpcResult as Map<String, dynamic>? ?? {};
        if (rpcData['success'] != true) {
          final errCode = rpcData['error'] as String? ?? 'unknown_rpc_error';
          debugPrint('[ScreeningRoom] create_screening_session falhou: $errCode');

          // BUGFIX: Se já existe uma sessão ativa (ex: host fechou o app sem encerrar),
          // buscar a sessão existente via RPC e entrar nela como host em vez de mostrar erro.
          if (errCode == 'screening_room_already_active') {
            debugPrint('[ScreeningRoom] Sessão já ativa — buscando sessão existente via get_active_screening_session...');
            try {
              final activeResult = await SupabaseService.client
                  .rpc('get_active_screening_session', params: {'p_thread_id': threadId})
                  .select();
              final activeList = activeResult as List? ?? [];
              if (activeList.isNotEmpty) {
                final activeRow = activeList.first as Map<String, dynamic>;
                final recoveredSessionId = activeRow['id'] as String?;
                if (recoveredSessionId != null && recoveredSessionId.isNotEmpty) {
                  debugPrint('[ScreeningRoom] Sessão recuperada: $recoveredSessionId — reentrando...');
                  // Reutilizar o fluxo de reentrada recursivamente
                  return joinRoom(
                    existingSessionId: recoveredSessionId,
                    initialVideoUrl: initialVideoUrl,
                    initialVideoTitle: initialVideoTitle,
                    initialVideoThumbnail: initialVideoThumbnail,
                  );
                }
              }
            } catch (e) {
              debugPrint('[ScreeningRoom] Erro ao buscar sessão ativa: $e');
            }
            // Se não conseguiu recuperar, mostrar erro amigável
            state = state.copyWith(
              status: ScreeningRoomStatus.error,
              errorMessage: 'Já existe uma Sala de Projeção ativa neste chat.',
            );
          } else {
            state = state.copyWith(
              status: ScreeningRoomStatus.error,
              errorMessage: 'Não foi possível criar a sala ($errCode).',
            );
          }
          return;
        }

        sessionId = rpcData['session_id'] as String;
        debugPrint('[ScreeningRoom] Sessão criada via RPC: $sessionId');

        isHost = true;
        hostUserId = userId;
        // Usar o vídeo inicial passado pelo ScreeningCreateRoomSheet
        videoUrl = initialVideoUrl;
        videoTitle = initialVideoTitle;
        videoThumbnail = initialVideoThumbnail;
        // O RPC já inseriu o criador como participante HOST — não chamar _joinAsParticipant.
      }

      // ── Carregar participantes iniciais ──
      // Nota: call_participants.user_id tem FK para auth.users (não public.profiles),
      // por isso o join automático do PostgREST não funciona. Buscamos os perfis
      // separadamente via query em public.profiles.
      debugPrint('[ScreeningRoom] Carregando participantes iniciais...');
      final participantsRaw = await SupabaseService.table('call_participants')
          .select('user_id')
          .eq('call_session_id', sessionId)
          .eq('status', 'connected');

      final userIds = (participantsRaw as List)
          .map((p) => (p as Map<String, dynamic>)['user_id'] as String?)
          .whereType<String>()
          .toList();

      List<ScreeningParticipant> participants = [];
      if (userIds.isNotEmpty) {
        final profilesData = await SupabaseService.table('profiles')
            .select('id, nickname, icon_url')
            .inFilter('id', userIds);
        final profileMap = <String, Map<String, dynamic>>{};
        for (final p in (profilesData as List)) {
          final row = p as Map<String, dynamic>;
          profileMap[row['id'] as String] = row;
        }
        participants = userIds.map((uid) {
          final profile = profileMap[uid];
          return ScreeningParticipant(
            userId: uid,
            username: profile?['nickname'] as String? ?? 'Usuário',
            avatarUrl: profile?['icon_url'] as String?,
            isHost: uid == (hostUserId ?? userId),
          );
        }).toList();
      }
      debugPrint('[ScreeningRoom] Participantes carregados: ${participants.length}');

      // Usar a fila restaurada do metadata (se disponível) ou lista vazia.
      // _restoredQueue é preenchida no bloco de reentrada (existingSessionId != null)
      // ao ler o campo video_queue do metadata JSONB da sessão.
      final queueToRestore = _restoredQueue ?? const [];
      _restoredQueue = null; // limpar para não vazar para próxima chamada

      state = state.copyWith(
        status: ScreeningRoomStatus.active,
        sessionId: sessionId,
        isHost: isHost,
        hostUserId: hostUserId ?? userId,
        currentVideoUrl: videoUrl,
        currentVideoTitle: videoTitle,
        currentVideoThumbnail: videoThumbnail,
        participants: participants,
        videoQueue: queueToRestore,
      );
      debugPrint('[ScreeningRoom] Estado atualizado para active. Iniciando Realtime e heartbeat...');

      // ── Iniciar Realtime e heartbeat ──
      _subscribeToRealtime(sessionId: sessionId, userId: userId);
      _startHeartbeat(sessionId: sessionId);
      debugPrint('[ScreeningRoom] joinRoom() concluído com sucesso.');
    } catch (e, st) {
      debugPrint('[ScreeningRoom] ❌ joinRoom ERRO: $e');
      debugPrint('[ScreeningRoom] ❌ joinRoom STACK: $st');
      debugPrint('[ScreeningRoom] ❌ Contexto: userId=$userId, existingSessionId=$existingSessionId, threadId=$threadId');
      state = state.copyWith(
        status: ScreeningRoomStatus.error,
        errorMessage: 'Não foi possível entrar na sala. Erro: $e',
      );
    }
  }

  Future<void> _joinAsParticipant({
    required String sessionId,
    required String userId,
  }) async {
    debugPrint('[ScreeningRoom] _joinAsParticipant — sessionId=$sessionId, userId=$userId');
    try {
      // Usar RPC join_call_session (regra de ouro: sem mutações diretas)
      final rpcResult = await SupabaseService.rpc('join_call_session', params: {
        'p_session_id': sessionId,
      });
      final rpcData = rpcResult as Map<String, dynamic>? ?? {};
      if (rpcData['success'] != true) {
        final errCode = rpcData['error'] as String? ?? 'unknown';
        debugPrint('[ScreeningRoom] join_call_session falhou: $errCode');
        throw StateError('join_call_session failed: $errCode');
      }
      debugPrint('[ScreeningRoom] _joinAsParticipant — RPC concluído.');
    } catch (e, st) {
      debugPrint('[ScreeningRoom] ❌ _joinAsParticipant ERRO: $e');
      debugPrint('[ScreeningRoom] ❌ _joinAsParticipant STACK: $st');
      rethrow;
    }
  }

  // ── Realtime Broadcast ──────────────────────────────────────────────────────

  void _subscribeToRealtime({
    required String sessionId,
    required String userId,
  }) {
    _channel = RealtimeService.instance.subscribeWithRetry(
      channelName: 'screening_$sessionId',
      configure: (channel) {
        // Participantes entrando/saindo
        channel.onBroadcast(
          event: 'participant_update',
          callback: (payload) => _handleParticipantUpdate(payload, sessionId),
        );

        // Sala encerrada pelo host
        channel.onBroadcast(
          event: 'room_closed',
          callback: (_) {
            if (state.isHost) return; // Host não reage ao próprio evento
            state = state.copyWith(status: ScreeningRoomStatus.closed);
          },
        );

        // Atualização de vídeo (host trocou o vídeo)
        channel.onBroadcast(
          event: 'video_changed',
          callback: (payload) {
            state = state.copyWith(
              currentVideoUrl: payload['video_url'] as String?,
              currentVideoTitle: payload['video_title'] as String?,
              currentVideoThumbnail: payload['video_thumbnail'] as String?,
            );
          },
        );

        // Mudança de host
        channel.onBroadcast(
          event: 'host_changed',
          callback: (payload) {
            final newHostId = payload['new_host_id'] as String?;
            final isNowHost = newHostId == userId;
            state = state.copyWith(
              hostUserId: newHostId,
              isHost: isNowHost,
            );
          },
        );
        // Ações de moderação (host/co-admin)
        channel.onBroadcast(
          event: 'moderation_action',
          callback: (payload) => _handleModerationAction(payload, userId),
        );
        // Atualização da fila de vídeos
        channel.onBroadcast(
          event: 'queue_update',
          callback: (payload) {
            final rawQueue = payload['queue'] as List<dynamic>?;
            if (rawQueue == null) return;
            final queue = rawQueue
                .map((e) => Map<String, String>.from(
                    (e as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
                .toList();
            state = state.copyWith(videoQueue: queue);
          },
        );
      },
    );
  }

  Future<void> _handleParticipantUpdate(
    Map<String, dynamic> payload,
    String sessionId,
  ) async {
    final action = payload['action'] as String?;
    final targetUserId = payload['user_id'] as String?;
    if (targetUserId == null) return;

    if (action == 'join') {
      // Buscar perfil do novo participante
      final profileData = await SupabaseService.table('profiles')
          .select('nickname, icon_url')
          .eq('id', targetUserId)
          .maybeSingle();

      if (profileData == null) return;

      final newParticipant = ScreeningParticipant(
        userId: targetUserId,
        username: profileData['nickname'] as String? ?? 'Usuário',
        avatarUrl: profileData['icon_url'] as String?,
        isHost: targetUserId == state.hostUserId,
      );

      final updated = [...state.participants];
      if (!updated.any((p) => p.userId == targetUserId)) {
        updated.add(newParticipant);
        state = state.copyWith(participants: updated);
      }
    } else if (action == 'leave') {
      final updated =
          state.participants.where((p) => p.userId != targetUserId).toList();
      state = state.copyWith(participants: updated);
    }
  }

  Future<void> _handleModerationAction(
    Map<String, dynamic> payload,
    String currentUserId,
  ) async {
    final action = payload['action'] as String?;
    final targetUserId = payload['target_user_id'] as String?;
    if (action == null || targetUserId == null) return;

    if (action == 'kick') {
      final updated =
          state.participants.where((p) => p.userId != targetUserId).toList();
      state = state.copyWith(participants: updated);
      if (targetUserId == currentUserId) {
        if (state.sessionId != null) {
          await ref
              .read(screeningVoiceProvider(state.sessionId!).notifier)
              .leaveChannel();
        }
        state = state.copyWith(status: ScreeningRoomStatus.closed);
      }
    } else if (action == 'mute' && targetUserId == currentUserId) {
      if (state.sessionId != null) {
        await ref
            .read(screeningVoiceProvider(state.sessionId!).notifier)
            .setMuted(true);
      }
    }
  }

  Future<bool> canModerate() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;
    // Host da sessão de projeção
    if (state.isHost || state.hostUserId == userId) return true;
    try {
      // Buscar thread + community_id + perfil do usuário em paralelo
      final results = await Future.wait([
        SupabaseService.table('chat_threads')
            .select('host_id, co_hosts, community_id')
            .eq('id', threadId)
            .maybeSingle(),
        SupabaseService.table('profiles')
            .select('is_team_moderator, is_team_admin')
            .eq('id', userId)
            .maybeSingle(),
      ]);

      final thread = results[0] as Map<String, dynamic>?;
      final profile = results[1] as Map<String, dynamic>?;

      if (thread == null) return false;

      // Host do chat thread
      if (thread['host_id'] == userId) return true;

      // Co-hosts do chat thread
      final coHosts = thread['co_hosts'];
      if (coHosts is List &&
          coHosts.map((e) => e.toString()).contains(userId)) return true;
      if (coHosts is String && coHosts == userId) return true;

      // Team members (moderadores/admins globais do NexusHub)
      if (profile != null) {
        final isTeamMod = profile['is_team_moderator'] as bool? ?? false;
        final isTeamAdmin = profile['is_team_admin'] as bool? ?? false;
        if (isTeamMod || isTeamAdmin) return true;
      }

      // Cargos de staff da comunidade: agent, leader, curator
      final communityId = thread['community_id'] as String?;
      if (communityId != null) {
        final member = await SupabaseService.table('community_members')
            .select('role')
            .eq('community_id', communityId)
            .eq('user_id', userId)
            .maybeSingle();
        if (member != null) {
          final role = member['role'] as String?;
          if (role != null && ['agent', 'leader', 'curator'].contains(role)) {
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('[ScreeningRoom] canModerate error: $e');
    }
    return false;
  }

  Future<bool> kickParticipant(String targetUserId) async {
    if (state.sessionId == null || targetUserId == state.hostUserId) return false;
    if (!await canModerate()) return false;

    try {
      final result = await SupabaseService.rpc(
        'moderate_screening_participant',
        params: {
          'p_session_id': state.sessionId!,
          'p_target_user_id': targetUserId,
          'p_action': 'kick',
        },
      );
      final data = result as Map<String, dynamic>? ?? {};
      if (data['success'] != true) return false;

      _channel?.sendBroadcastMessage(
        event: 'moderation_action',
        payload: {
          'action': 'kick',
          'target_user_id': targetUserId,
          'moderator_id': SupabaseService.currentUserId,
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      );
      final updated =
          state.participants.where((p) => p.userId != targetUserId).toList();
      state = state.copyWith(participants: updated);
      return true;
    } catch (e) {
      debugPrint('[ScreeningRoom] kickParticipant error: $e');
      return false;
    }
  }

  Future<bool> muteParticipant(String targetUserId) async {
    if (state.sessionId == null || targetUserId == state.hostUserId) return false;
    if (!await canModerate()) return false;

    try {
      final result = await SupabaseService.rpc(
        'moderate_screening_participant',
        params: {
          'p_session_id': state.sessionId!,
          'p_target_user_id': targetUserId,
          'p_action': 'mute',
        },
      );
      final data = result as Map<String, dynamic>? ?? {};
      if (data['success'] != true) return false;

      _channel?.sendBroadcastMessage(
        event: 'moderation_action',
        payload: {
          'action': 'mute',
          'target_user_id': targetUserId,
          'moderator_id': SupabaseService.currentUserId,
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      );
      return true;
    } catch (e) {
      debugPrint('[ScreeningRoom] muteParticipant error: $e');
      return false;
    }
  }

  // ── Heartbeat ───────────────────────────────────────────────────────────────

  void _startHeartbeat({required String sessionId}) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        await SupabaseService.client.rpc('send_screening_heartbeat', params: {
          'p_session_id': sessionId,
        });
      } catch (e) {
        debugPrint('[ScreeningRoom] heartbeat error: $e');
      }
    });

    // Cleanup de inativos a cada 2 minutos (apenas host)
    if (state.isHost) {
      _cleanupTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
        try {
          await SupabaseService.client
              .rpc('cleanup_inactive_screening_participants', params: {
            'p_session_id': sessionId,
          });
        } catch (e) {
          debugPrint('[ScreeningRoom] cleanup error: $e');
        }
      });
    }
  }

  // ── Atualizar vídeo (host) ──────────────────────────────────────────────────

  Future<void> updateVideo({
    required String videoUrl,
    required String videoTitle,
    String? videoThumbnail,
    bool skipStreamingRuleValidation = false,
  }) async {
    if (!state.isHost || state.sessionId == null) return;

    try {
      if (!skipStreamingRuleValidation) {
        await StreamingRulesService.assertUrlAllowed(videoUrl);
      }

      // Persistir no banco — incluir video_queue para não apagar a fila ao trocar de vídeo.
      await SupabaseService.client.rpc('update_screening_metadata', params: {
        'p_session_id': state.sessionId,
        'p_metadata': {
          'video_url': videoUrl,
          'video_title': videoTitle,
          'video_thumbnail': videoThumbnail ?? '',
          'is_playing': false,
          'video_queue': state.videoQueue,
        },
      });

      // Broadcast para todos os participantes
      _channel?.sendBroadcastMessage(
        event: 'video_changed',
        payload: {
          'video_url': videoUrl,
          'video_title': videoTitle,
          'video_thumbnail': videoThumbnail ?? '',
        },
      );

      state = state.copyWith(
        currentVideoUrl: videoUrl,
        currentVideoTitle: videoTitle,
        currentVideoThumbnail: videoThumbnail ?? '',
      );
    } catch (e) {
      debugPrint('[ScreeningRoom] updateVideo error: $e');
    }
  }

  // ── Remover vídeo atual (host) ─────────────────────────────────────────────────────

  /// Remove o vídeo atual da sala, limpando a URL no banco e notificando
  /// todos os participantes. Após isso o player exibe o estado vazio.
  Future<void> clearVideo() async {
    if (!state.isHost || state.sessionId == null) return;

    try {
      await SupabaseService.client.rpc('update_screening_metadata', params: {
        'p_session_id': state.sessionId,
        'p_metadata': {
          'video_url': '',
          'video_title': '',
          'video_thumbnail': '',
          'is_playing': false,
          'video_queue': state.videoQueue,
        },
      });

      _channel?.sendBroadcastMessage(
        event: 'video_changed',
        payload: {
          'video_url': '',
          'video_title': '',
          'video_thumbnail': '',
        },
      );

      state = state.copyWith(
        currentVideoUrl: '',
        currentVideoTitle: '',
        currentVideoThumbnail: '',
      );
    } catch (e) {
      debugPrint('[ScreeningRoom] clearVideo error: $e');
    }
  }

  // ── Transferir host ─────────────────────────────────────────────────────────

  Future<void> transferHost(String newHostUserId) async {
    if (!state.isHost || state.sessionId == null) return;

    try {
      await SupabaseService.client.rpc('transfer_screening_host', params: {
        'p_session_id': state.sessionId,
        'p_new_host_id': newHostUserId,
      });

      _channel?.sendBroadcastMessage(
        event: 'host_changed',
        payload: {'new_host_id': newHostUserId},
      );

      state = state.copyWith(
        isHost: false,
        hostUserId: newHostUserId,
      );
    } catch (e) {
      debugPrint('[ScreeningRoom] transferHost error: $e');
    }
  }

  // ── Sair da sala ────────────────────────────────────────────────────────────

  Future<void> leaveRoom() async {
    final userId = SupabaseService.currentUserId;
    final sessionId = state.sessionId;
    if (userId == null || sessionId == null) return;

    try {
      if (state.isHost) {
        // Host encerra a sala para todos
        _channel?.sendBroadcastMessage(
          event: 'room_closed',
          payload: {'host_id': userId},
        );
        await Future.delayed(const Duration(milliseconds: 200));

        await SupabaseService.client.rpc('end_screening_session', params: {
          'p_session_id': sessionId,
        });
        // Enviar mensagem de sistema informando o encerramento da sala
        try {
          final nickname =
              ref.read(currentUserProvider)?.nickname ?? 'Alguém';
          await SupabaseService.rpc(
            'send_chat_message_with_reputation',
            params: {
              'p_thread_id': threadId,
              'p_content': '$nickname encerrou a Sala de Projeção',
              'p_type': 'system_screen_end',
            },
          );
        } catch (e) {
          debugPrint('[ScreeningRoom] Erro ao enviar system_screen_end: $e');
        }
      } else {
        // Participante sai silenciosamente
        _channel?.sendBroadcastMessage(
          event: 'participant_update',
          payload: {'action': 'leave', 'user_id': userId},
        );

        // Usar RPC leave_call_session (regra de ouro: sem mutações diretas)
        // O RPC também encerra a sessão se não houver mais participantes conectados.
        await SupabaseService.rpc('leave_call_session', params: {
          'p_session_id': sessionId,
        });
      }
    } catch (e) {
      debugPrint('[ScreeningRoom] leaveRoom error: $e');
    } finally {
      _dispose();
    }
  }


  // ── Fila de Vídeos ──────────────────────────────────────────────────────────

  /// Adiciona um vídeo ao final da fila e sincroniza via Broadcast.
  /// Se não houver vídeo atual no player, carrega automaticamente o primeiro
  /// item da fila (pausado) para que o host possa iniciar quando quiser.
  /// O item permanece na fila até ser explicitamente removido.
  Future<void> addToQueue({
    required String url,
    String? title,
    String? thumbnail,
    bool skipStreamingRuleValidation = false,
  }) async {
    if (!state.isHost) return;
    if (!skipStreamingRuleValidation) {
      await StreamingRulesService.assertUrlAllowed(url);
    }

    final item = <String, String>{
      'url': url,
      if (title != null) 'title': title,
      if (thumbnail != null) 'thumbnail': thumbnail,
    };
    final newQueue = [...state.videoQueue, item];
    state = state.copyWith(videoQueue: newQueue);
    _broadcastQueueUpdate(newQueue);
    // Auto-carregar o primeiro vídeo se o player estiver vazio.
    // O item NÃO é removido da fila — permanece até ser explicitamente removido.
    final hasVideo = state.currentVideoUrl != null &&
        state.currentVideoUrl!.isNotEmpty;
    if (!hasVideo) {
      await updateVideo(
        videoUrl: item['url'] ?? '',
        videoTitle: item['title'] ?? '',
        videoThumbnail: item['thumbnail'],
      );
    }
  }

  /// Remove um vídeo da fila pelo índice e sincroniza via Broadcast.
  /// Se o item removido for o vídeo atualmente em reprodução, limpa o player
  /// (clearVideo) para que o vídeo pare imediatamente para todos os participantes.
  Future<void> removeFromQueue(int index) async {
    if (!state.isHost) return;
    final newQueue = [...state.videoQueue];
    if (index < 0 || index >= newQueue.length) return;
    final removedItem = newQueue[index];
    newQueue.removeAt(index);
    state = state.copyWith(videoQueue: newQueue);
    _broadcastQueueUpdate(newQueue);
    // Se o item removido é o vídeo atual no player, limpar o player
    // para que o vídeo pare imediatamente para todos os participantes.
    final removedUrl = removedItem['url'] ?? '';
    final currentUrl = state.currentVideoUrl ?? '';
    if (removedUrl.isNotEmpty && removedUrl == currentUrl) {
      await clearVideo();
    }
  }

  /// Reordena a fila via drag-and-drop e sincroniza via Broadcast.
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (!state.isHost) return;
    final newQueue = [...state.videoQueue];
    final item = newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex, item);
    state = state.copyWith(videoQueue: newQueue);
    _broadcastQueueUpdate(newQueue);
  }

  void _broadcastQueueUpdate(List<Map<String, String>> queue) {
    _channel?.sendBroadcastMessage(
      event: 'queue_update',
      payload: {
        'queue': queue,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    );
    // Persistir a fila no metadata do banco para que seja restaurada
    // quando o host minimiza e volta à sala (joinRoom lê o metadata).
    // Faz merge com o metadata atual para não sobrescrever video_url etc.
    if (state.sessionId != null) {
      SupabaseService.client.rpc('update_screening_metadata', params: {
        'p_session_id': state.sessionId,
        'p_metadata': {
          'video_url': state.currentVideoUrl ?? '',
          'video_title': state.currentVideoTitle ?? '',
          'video_thumbnail': state.currentVideoThumbnail ?? '',
          'is_playing': false,
          'video_queue': queue,
        },
      }).catchError((e) {
        debugPrint('[ScreeningRoom] _broadcastQueueUpdate persist error: $e');
      });
    }
  }

  void _dispose() {
    _heartbeatTimer?.cancel();
    _cleanupTimer?.cancel();
    if (state.sessionId != null) {
      RealtimeService.instance.unsubscribe('screening_${state.sessionId}');
    }
    _channel = null;
    // Resetar o estado completamente para evitar que dados da sessão anterior
    // (currentVideoUrl, videoQueue, sessionId, etc.) persistam quando o usuário
    // abrir uma nova sala. O copyWith não consegue setar campos para null,
    // por isso recriamos o estado do zero.
    state = ScreeningRoomState(
      threadId: threadId,
      status: ScreeningRoomStatus.closed,
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }
}
