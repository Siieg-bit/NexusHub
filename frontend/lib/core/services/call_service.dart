import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// ============================================================================
/// CallService — Gerencia chamadas de voz, vídeo e screening room.
///
/// Fluxo:
/// 1. Criador chama `createCall()` → insere registro em `call_sessions`
/// 2. Participantes recebem convite via Realtime (chat message type voice_chat/video_chat)
/// 3. Participante chama `joinCall()` → insere em `call_participants`
/// 4. A UI de chamada é exibida (CallScreen)
/// 5. Quando a chamada termina → `endCall()` atualiza status
///
/// NOTA: A sinalização WebRTC real (SDP/ICE) requer um servidor TURN/STUN
/// e um pacote como `flutter_webrtc`. Este serviço gerencia apenas o estado
/// da chamada via Supabase Realtime. Para produção, integrar com:
/// - Agora.io (recomendado para mobile)
/// - LiveKit (open-source, self-hosted)
/// - Jitsi Meet (para screening room)
/// ============================================================================

enum CallType { voice, video, screeningRoom }

class CallSession {
  final String id;
  final String threadId;
  final CallType type;
  final String creatorId;
  final String status; // active, ended
  final DateTime createdAt;

  const CallSession({
    required this.id,
    required this.threadId,
    required this.type,
    required this.creatorId,
    required this.status,
    required this.createdAt,
  });

  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      type: _parseType(json['type'] as String? ?? 'voice'),
      creatorId: json['creator_id'] as String,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  static CallType _parseType(String t) {
    switch (t) {
      case 'video':
        return CallType.video;
      case 'screening_room':
        return CallType.screeningRoom;
      default:
        return CallType.voice;
    }
  }

  String get typeString {
    switch (type) {
      case CallType.video:
        return 'video';
      case CallType.screeningRoom:
        return 'screening_room';
      case CallType.voice:
        return 'voice';
    }
  }
}

class CallService {
  static RealtimeChannel? _callChannel;
  static CallSession? activeCall;
  static final _participantsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  static Stream<List<Map<String, dynamic>>> get participantsStream =>
      _participantsController.stream;

  /// Cria uma nova sessão de chamada
  static Future<CallSession?> createCall({
    required String threadId,
    required CallType type,
  }) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return null;

      final res = await SupabaseService.table('call_sessions').insert({
        'thread_id': threadId,
        'type': type == CallType.voice
            ? 'voice'
            : type == CallType.video
                ? 'video'
                : 'screening_room',
        'creator_id': userId,
        'status': 'active',
      }).select().single();

      final session = CallSession.fromJson(res);
      activeCall = session;

      // Adicionar criador como participante
      await SupabaseService.table('call_participants').insert({
        'call_session_id': session.id,
        'user_id': userId,
        'status': 'connected',
      });

      // Inscrever no canal Realtime da chamada
      _subscribeToCall(session.id);

      return session;
    } catch (e) {
      debugPrint('CallService.createCall error: $e');
      return null;
    }
  }

  /// Entrar em uma chamada existente
  static Future<bool> joinCall(String callSessionId) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return false;

      // Buscar sessão
      final res = await SupabaseService.table('call_sessions')
          .select()
          .eq('id', callSessionId)
          .eq('status', 'active')
          .single();

      activeCall = CallSession.fromJson(res);

      await SupabaseService.table('call_participants').insert({
        'call_session_id': callSessionId,
        'user_id': userId,
        'status': 'connected',
      });

      _subscribeToCall(callSessionId);
      return true;
    } catch (e) {
      debugPrint('CallService.joinCall error: $e');
      return false;
    }
  }

  /// Sair da chamada
  static Future<void> leaveCall() async {
    if (activeCall == null) return;
    try {
      final userId = SupabaseService.currentUserId;
      await SupabaseService.table('call_participants')
          .update({'status': 'disconnected', 'left_at': DateTime.now().toIso8601String()})
          .eq('call_session_id', activeCall!.id)
          .eq('user_id', userId!);

      // Se o criador saiu, encerrar a chamada
      if (activeCall!.creatorId == userId) {
        await endCall();
      }
    } catch (_) {}
    _cleanup();
  }

  /// Encerrar a chamada (apenas criador)
  static Future<void> endCall() async {
    if (activeCall == null) return;
    try {
      await SupabaseService.table('call_sessions')
          .update({'status': 'ended', 'ended_at': DateTime.now().toIso8601String()})
          .eq('id', activeCall!.id);
    } catch (_) {}
    _cleanup();
  }

  /// Buscar participantes ativos
  static Future<List<Map<String, dynamic>>> getParticipants() async {
    if (activeCall == null) return [];
    try {
      final res = await SupabaseService.table('call_participants')
          .select('*, profiles!call_participants_user_id_fkey(*)')
          .eq('call_session_id', activeCall!.id)
          .eq('status', 'connected');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
  }

  static void _subscribeToCall(String callSessionId) {
    _callChannel?.unsubscribe();
    _callChannel = SupabaseService.client
        .channel('call:$callSessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'call_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'call_session_id',
            value: callSessionId,
          ),
          callback: (_) async {
            final participants = await getParticipants();
            _participantsController.add(participants);
          },
        )
        .subscribe();
  }

  static void _cleanup() {
    _callChannel?.unsubscribe();
    _callChannel = null;
    activeCall = null;
  }
}
