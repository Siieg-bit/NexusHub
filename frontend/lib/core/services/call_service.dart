import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// ============================================================================
/// CallService — Gerencia chamadas de voz, vídeo e screening room.
///
/// Integração completa com Agora.io RTC SDK para áudio/vídeo real.
///
/// Fluxo:
/// 1. Criador chama `createCall()` → insere em `call_sessions` + join Agora
/// 2. Participantes recebem convite via Realtime (chat message)
/// 3. Participante chama `joinCall()` → insere em `call_participants` + join Agora
/// 4. A UI de chamada é exibida (CallScreen) com vídeo real
/// 5. Quando a chamada termina → `endCall()` atualiza status + leave Agora
///
/// CONFIGURAÇÃO:
/// 1. Crie uma conta em https://console.agora.io
/// 2. Crie um projeto e copie o App ID
/// 3. Substitua `_agoraAppId` abaixo pelo seu App ID
/// 4. Para produção, gere tokens temporários via Edge Function
/// ============================================================================

enum CallType { voice, video, screeningRoom }

class CallSession {
  final String id;
  final String threadId;
  final CallType type;
  final String creatorId;
  final String status;
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

/// ============================================================================
/// CallService com Agora.io RTC integrado
/// ============================================================================
class CallService {
  // ── Agora Configuration ──
  // SUBSTITUA pelo seu App ID do Agora Console (https://console.agora.io)
  static const String _agoraAppId = 'YOUR_AGORA_APP_ID';

  // Para produção, gere tokens temporários via Supabase Edge Function.
  // Em modo de teste, deixe vazio (o Agora permite sem token em modo dev).
  static String? _agoraToken;

  // ── Agora Engine ──
  static RtcEngine? _engine;
  static bool _isEngineInitialized = false;

  // ── State ──
  static RealtimeChannel? _callChannel;
  static CallSession? activeCall;
  static final _participantsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  static final _remoteUsersController =
      StreamController<Set<int>>.broadcast();
  static final _audioLevelsController =
      StreamController<Map<int, double>>.broadcast();

  static Stream<List<Map<String, dynamic>>> get participantsStream =>
      _participantsController.stream;
  static Stream<Set<int>> get remoteUsersStream =>
      _remoteUsersController.stream;
  static Stream<Map<int, double>> get audioLevelsStream =>
      _audioLevelsController.stream;

  static final Set<int> _remoteUsers = {};
  static final Map<int, double> _audioLevels = {};
  static bool _isMuted = false;
  static bool _isCameraOn = false;
  static bool _isSpeakerOn = true;

  static bool get isMuted => _isMuted;
  static bool get isCameraOn => _isCameraOn;
  static bool get isSpeakerOn => _isSpeakerOn;
  static RtcEngine? get engine => _engine;
  static Set<int> get remoteUsers => _remoteUsers;

  /// Inicializa o Agora RTC Engine (chamado uma vez)
  static Future<void> _initEngine() async {
    if (_isEngineInitialized && _engine != null) return;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: _agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // Registrar event handlers
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        debugPrint('Agora: Joined channel ${connection.channelId} in ${elapsed}ms');
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        debugPrint('Agora: Remote user $remoteUid joined');
        _remoteUsers.add(remoteUid);
        _remoteUsersController.add(Set.from(_remoteUsers));
      },
      onUserOffline: (connection, remoteUid, reason) {
        debugPrint('Agora: Remote user $remoteUid left ($reason)');
        _remoteUsers.remove(remoteUid);
        _audioLevels.remove(remoteUid);
        _remoteUsersController.add(Set.from(_remoteUsers));
      },
      onAudioVolumeIndication: (connection, speakers, speakerNumber, totalVolume) {
        for (final speaker in speakers) {
          _audioLevels[speaker.uid ?? 0] = (speaker.volume ?? 0).toDouble();
        }
        _audioLevelsController.add(Map.from(_audioLevels));
      },
      onError: (err, msg) {
        debugPrint('Agora Error: $err - $msg');
      },
    ));

    // Habilitar detecção de volume de áudio
    await _engine!.enableAudioVolumeIndication(
      interval: 250,
      smooth: 3,
      reportVad: true,
    );

    _isEngineInitialized = true;
  }

  /// Solicita permissões de câmera e microfone
  static Future<bool> _requestPermissions(CallType type) async {
    final permissions = <Permission>[Permission.microphone];
    if (type == CallType.video) {
      permissions.add(Permission.camera);
    }

    final statuses = await permissions.request();
    return statuses.values.every((s) => s.isGranted);
  }

  /// Cria uma nova sessão de chamada e entra no canal Agora
  static Future<CallSession?> createCall({
    required String threadId,
    required CallType type,
  }) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return null;

      // Solicitar permissões
      final granted = await _requestPermissions(type);
      if (!granted) {
        debugPrint('CallService: Permissões negadas');
        return null;
      }

      // Criar sessão no Supabase
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

      // Inicializar Agora e entrar no canal
      await _joinAgoraChannel(session);

      // Inscrever no Realtime do Supabase para atualizações de participantes
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

      final session = CallSession.fromJson(res);
      activeCall = session;

      // Solicitar permissões
      final granted = await _requestPermissions(session.type);
      if (!granted) return false;

      // Registrar participante no Supabase
      await SupabaseService.table('call_participants').insert({
        'call_session_id': callSessionId,
        'user_id': userId,
        'status': 'connected',
      });

      // Inicializar Agora e entrar no canal
      await _joinAgoraChannel(session);

      // Inscrever no Realtime
      _subscribeToCall(callSessionId);

      return true;
    } catch (e) {
      debugPrint('CallService.joinCall error: $e');
      return false;
    }
  }

  /// Entra no canal Agora com áudio/vídeo real
  static Future<void> _joinAgoraChannel(CallSession session) async {
    await _initEngine();

    final isVideo = session.type == CallType.video;

    if (isVideo) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
      _isCameraOn = true;
    } else {
      await _engine!.disableVideo();
      _isCameraOn = false;
    }

    await _engine!.enableAudio();
    _isMuted = false;

    // Configurar speaker
    await _engine!.setEnableSpeakerphone(_isSpeakerOn);

    // O channelName é o ID da sessão (único por chamada)
    // Para produção, gere um token temporário via Edge Function
    // usando o Agora Token Builder com o channelName e uid.
    final channelName = 'nexushub_${session.id.replaceAll('-', '').substring(0, 16)}';

    // uid = 0 → Agora atribui automaticamente
    await _engine!.joinChannel(
      token: _agoraToken ?? '',
      channelId: channelName,
      uid: 0,
      options: ChannelMediaOptions(
        autoSubscribeAudio: true,
        autoSubscribeVideo: isVideo,
        publishMicrophoneTrack: true,
        publishCameraTrack: isVideo,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  /// Toggle mute do microfone
  static Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _engine?.muteLocalAudioStream(_isMuted);
  }

  /// Toggle câmera (apenas para video calls)
  static Future<void> toggleCamera() async {
    _isCameraOn = !_isCameraOn;
    if (_isCameraOn) {
      await _engine?.enableVideo();
      await _engine?.startPreview();
    } else {
      await _engine?.stopPreview();
      await _engine?.disableVideo();
    }
  }

  /// Toggle speaker/earpiece
  static Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await _engine?.setEnableSpeakerphone(_isSpeakerOn);
  }

  /// Trocar câmera frontal/traseira
  static Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  /// Sair da chamada
  static Future<void> leaveCall() async {
    if (activeCall == null) return;
    try {
      final userId = SupabaseService.currentUserId;

      // Sair do canal Agora
      await _engine?.leaveChannel();
      await _engine?.stopPreview();

      // Atualizar status no Supabase
      await SupabaseService.table('call_participants')
          .update({
            'status': 'disconnected',
            'left_at': DateTime.now().toIso8601String(),
          })
          .eq('call_session_id', activeCall!.id)
          .eq('user_id', userId!);

      // Se o criador saiu, encerrar a chamada
      if (activeCall!.creatorId == userId) {
        await endCall();
      }
    } catch (e) {
      debugPrint('CallService.leaveCall error: $e');
    }
    _cleanup();
  }

  /// Encerrar a chamada (apenas criador)
  static Future<void> endCall() async {
    if (activeCall == null) return;
    try {
      await _engine?.leaveChannel();
      await SupabaseService.table('call_sessions')
          .update({
            'status': 'ended',
            'ended_at': DateTime.now().toIso8601String(),
          })
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

  /// Inscreve no Realtime do Supabase para atualizações de participantes
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
    _remoteUsers.clear();
    _audioLevels.clear();
    _isMuted = false;
    _isCameraOn = false;
  }

  /// Libera recursos do Agora Engine (chamar no dispose do app)
  static Future<void> dispose() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    _isEngineInitialized = false;
    _participantsController.close();
    _remoteUsersController.close();
    _audioLevelsController.close();
  }
}
