import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/realtime_service.dart';
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

    try {
      state = state.copyWith(status: ScreeningRoomStatus.loading);

      String sessionId;
      bool isHost;
      String? hostUserId;
      String? videoUrl;
      String? videoTitle;

      if (existingSessionId != null) {
        // ── Entrando em sessão existente ──
        sessionId = existingSessionId;

        final result = await SupabaseService.client
            .rpc('get_screening_session_state', params: {
          'p_session_id': sessionId,
        }).select();

        if (result == null || (result as List).isEmpty) {
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

        // Registrar como participante
        await _joinAsParticipant(sessionId: sessionId, userId: userId);
      } else {
        // ── Criando nova sessão (host) ──
        final session = await SupabaseService.table('call_sessions').insert({
          'creator_id': userId,
          'thread_id': threadId,
          'type': 'screening_room',
          'status': 'active',
          'metadata': {
            'video_url': initialVideoUrl ?? '',
            'video_title': initialVideoTitle ?? '',
            'video_thumbnail': initialVideoThumbnail ?? '',
          },
        }).select().single();

        sessionId = session['id'] as String;
        isHost = true;
        hostUserId = userId;
        // Usar o vídeo inicial passado pelo ScreeningCreateRoomSheet
        videoUrl = initialVideoUrl;
        videoTitle = initialVideoTitle;

        await _joinAsParticipant(sessionId: sessionId, userId: userId);
      }

      // ── Carregar participantes iniciais ──
      final participantsData = await SupabaseService.table('call_participants')
          .select('user_id, profiles(nickname, icon_url)')
          .eq('call_session_id', sessionId)
          .eq('status', 'connected');

      final participants = (participantsData as List)
          .map((p) => ScreeningParticipant.fromMap(p as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        status: ScreeningRoomStatus.active,
        sessionId: sessionId,
        isHost: isHost,
        hostUserId: hostUserId ?? userId,
        currentVideoUrl: videoUrl,
        currentVideoTitle: videoTitle,
        participants: participants,
      );

      // ── Iniciar Realtime e heartbeat ──
      _subscribeToRealtime(sessionId: sessionId, userId: userId);
      _startHeartbeat(sessionId: sessionId);
    } catch (e, st) {
      debugPrint('[ScreeningRoom] joinRoom error: $e\n$st');
      state = state.copyWith(
        status: ScreeningRoomStatus.error,
        errorMessage: 'Não foi possível entrar na sala. Tente novamente.',
      );
    }
  }

  Future<void> _joinAsParticipant({
    required String sessionId,
    required String userId,
  }) async {
    // Upsert para evitar duplicatas (caso de reconexão)
    await SupabaseService.table('call_participants').upsert({
      'call_session_id': sessionId,
      'user_id': userId,
      'status': 'connected',
      'joined_at': DateTime.now().toIso8601String(),
      'last_heartbeat': DateTime.now().toIso8601String(),
    }, onConflict: 'call_session_id,user_id');
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
