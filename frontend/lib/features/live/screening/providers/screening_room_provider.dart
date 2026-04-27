import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/realtime_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../models/screening_room_state.dart';
import '../models/screening_participant.dart';

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
      state = state.copyWith(status: ScreeningRoomStatus.loading);

      String sessionId;
      bool isHost;
      String? hostUserId;
      String? videoUrl;
      String? videoTitle;

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
        debugPrint('[ScreeningRoom] Sessão encontrada — isHost=$isHost, hostUserId=$hostUserId, videoUrl=$videoUrl');

        // Registrar como participante
        debugPrint('[ScreeningRoom] Chamando _joinAsParticipant...');
        await _joinAsParticipant(sessionId: sessionId, userId: userId);
        debugPrint('[ScreeningRoom] _joinAsParticipant concluído.');
      } else {
        // ── Criando nova sessão (host) ──
        debugPrint('[ScreeningRoom] Criando nova sessão como host — threadId=$threadId, videoUrl=$initialVideoUrl');
        final session = await SupabaseService.table('call_sessions').insert({
          'creator_id': userId,
          'host_id': userId, // NOT NULL constraint na tabela call_sessions
          'thread_id': threadId,
          'type': 'screening_room',
          'status': 'active',
          'metadata': {
            'video_url': initialVideoUrl ?? '',
            'video_title': initialVideoTitle ?? '',
            'video_thumbnail': initialVideoThumbnail ?? '',
          },
        }).select().single();
        debugPrint('[ScreeningRoom] Sessao criada: ${session["id"]}');

        sessionId = session['id'] as String;
        isHost = true;
        hostUserId = userId;
        // Usar o vídeo inicial passado pelo ScreeningCreateRoomSheet
        videoUrl = initialVideoUrl;
        videoTitle = initialVideoTitle;

        debugPrint('[ScreeningRoom] Chamando _joinAsParticipant como host...');
        await _joinAsParticipant(sessionId: sessionId, userId: userId);
        debugPrint('[ScreeningRoom] _joinAsParticipant (host) concluído.');
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

      state = state.copyWith(
        status: ScreeningRoomStatus.active,
        sessionId: sessionId,
        isHost: isHost,
        hostUserId: hostUserId ?? userId,
        currentVideoUrl: videoUrl,
        currentVideoTitle: videoTitle,
        participants: participants,
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
      // Upsert para evitar duplicatas (caso de reconexão)
      await SupabaseService.table('call_participants').upsert({
        'call_session_id': sessionId,
        'user_id': userId,
        'status': 'connected',
        'joined_at': DateTime.now().toIso8601String(),
        'last_heartbeat': DateTime.now().toIso8601String(),
      }, onConflict: 'call_session_id,user_id');
      debugPrint('[ScreeningRoom] _joinAsParticipant — upsert concluído.');
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
  }) async {
    if (!state.isHost || state.sessionId == null) return;

    try {
      // Persistir no banco
      await SupabaseService.client.rpc('update_screening_metadata', params: {
        'p_session_id': state.sessionId,
        'p_metadata': {
          'video_url': videoUrl,
          'video_title': videoTitle,
          'is_playing': false,
        },
      });

      // Broadcast para todos os participantes
      _channel?.sendBroadcastMessage(
        event: 'video_changed',
        payload: {
          'video_url': videoUrl,
          'video_title': videoTitle,
        },
      );

      state = state.copyWith(
        currentVideoUrl: videoUrl,
        currentVideoTitle: videoTitle,
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
          'is_playing': false,
        },
      });

      _channel?.sendBroadcastMessage(
        event: 'video_changed',
        payload: {
          'video_url': '',
          'video_title': '',
        },
      );

      state = state.copyWith(
        currentVideoUrl: '',
        currentVideoTitle: '',
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

        await SupabaseService.table('call_participants')
            .update({
              'status': 'disconnected',
              'left_at': DateTime.now().toIso8601String(),
            })
            .eq('call_session_id', sessionId)
            .eq('user_id', userId);
      }
    } catch (e) {
      debugPrint('[ScreeningRoom] leaveRoom error: $e');
    } finally {
      _dispose();
    }
  }


  // ── Fila de Vídeos ──────────────────────────────────────────────────────────

  /// Adiciona um vídeo ao final da fila e sincroniza via Broadcast.
  Future<void> addToQueue({
    required String url,
    String? title,
    String? thumbnail,
  }) async {
    if (!state.isHost) return;
    final item = <String, String>{
      'url': url,
      if (title != null) 'title': title,
      if (thumbnail != null) 'thumbnail': thumbnail,
    };
    final newQueue = [...state.videoQueue, item];
    state = state.copyWith(videoQueue: newQueue);
    _broadcastQueueUpdate(newQueue);
  }

  /// Remove um vídeo da fila pelo índice e sincroniza via Broadcast.
  Future<void> removeFromQueue(int index) async {
    if (!state.isHost) return;
    final newQueue = [...state.videoQueue];
    if (index < 0 || index >= newQueue.length) return;
    newQueue.removeAt(index);
    state = state.copyWith(videoQueue: newQueue);
    _broadcastQueueUpdate(newQueue);
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
  }

  void _dispose() {
    _heartbeatTimer?.cancel();
    _cleanupTimer?.cancel();
    if (state.sessionId != null) {
      RealtimeService.instance.unsubscribe('screening_${state.sessionId}');
    }
    _channel = null;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }
}
