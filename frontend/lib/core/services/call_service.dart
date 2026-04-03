import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'realtime_service.dart';

/// ============================================================================
/// CallService — Gerencia chamadas de voz, vídeo e screening room.
///
/// Integração completa com Agora.io RTC SDK para áudio/vídeo real.
///
/// Fluxo:
/// 1. Criador chama `createCall()` → RPC `create_call_session` + join Agora
/// 2. Participantes recebem convite via Realtime (chat message)
/// 3. Participante chama `joinCall()` → RPC `join_call_session` + join Agora
/// 4. A UI de chamada é exibida (CallScreen) com vídeo real
/// 5. Quando a chamada termina → RPC `leave_call_session`/`end_call_session`
///
/// CONFIGURAÇÃO:
/// 1. Crie uma conta em https://console.agora.io
/// 2. Crie um projeto e copie o App ID
/// 3. Substitua `_agoraAppId` abaixo pelo seu App ID
/// 4. Para produção, gere tokens temporários via Edge Function
///
/// AUDITORIA 4: Migrado de inserts diretos para RPCs server-side.
/// AUDITORIA 4: Migrado de SupabaseService.client.channel() para
///              RealtimeService.instance.subscribeWithRetry() (retry automático).
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
      id: json['id'] as String? ?? '',
      threadId: json['thread_id'] as String? ?? '',
      type: _parseType(json['type'] as String? ?? 'voice'),
      // Suporta tanto creator_id quanto host_id (banco tem ambos)
      creatorId:
          json['creator_id'] as String? ?? json['host_id'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.tryParse(json['created_at'] as String? ??
              json['started_at'] as String? ??
              '') ??
          DateTime.now(),
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
/// CallService com Agora.io RTC integrado + RPCs + RealtimeService
/// ============================================================================
class CallService {
  // ── Agora Configuration ──
  static const String _agoraAppId = 'dc3fc8b039374782af029efa33f17198';
  static String? _agoraToken;

  // ── Agora Engine ──
  static RtcEngine? _engine;
  static bool _isEngineInitialized = false;

  // ── State ──
  static String? _callChannelName;
  static CallSession? activeCall;
  static final _participantsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  static final _remoteUsersController = StreamController<Set<int>>.broadcast();
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

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        debugPrint(
            'Agora: Joined channel ${connection.channelId} in ${elapsed}ms');
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
      onAudioVolumeIndication:
          (connection, speakers, speakerNumber, totalVolume) {
        for (final speaker in speakers) {
          _audioLevels[speaker.uid ?? 0] = (speaker.volume ?? 0).toDouble();
        }
        _audioLevelsController.add(Map.from(_audioLevels));
      },
      onError: (err, msg) {
        debugPrint('Agora Error: $err - $msg');
      },
    ));

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

  /// =========================================================================
  /// createCall — Usa RPC `create_call_session` ao invés de INSERT direto.
  ///
  /// A RPC valida:
  /// - Autenticação (auth.uid())
  /// - Membership no chat (status = 'active')
  /// - Não duplica sessões ativas no mesmo thread
  /// - Cria sessão + participante atomicamente
  /// =========================================================================
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

      // Criar sessão via RPC (validação server-side)
      final typeStr = type == CallType.voice
          ? 'voice'
          : type == CallType.video
              ? 'video'
              : 'screening_room';

      final rpcResult =
          await SupabaseService.rpc('create_call_session', params: {
        'p_thread_id': threadId,
        'p_type': typeStr,
      });

      final result = rpcResult as Map<String, dynamic>? ?? {};
      if (result['success'] != true) {
        debugPrint('CallService.createCall RPC error: ${result['error']}');
        return null;
      }

      final sessionId = result['session_id'] as String;

      // Buscar a sessão completa
      final res = await SupabaseService.table('call_sessions')
          .select()
          .eq('id', sessionId)
          .single();

      final session = CallSession.fromJson(res);
      activeCall = session;

      // Inicializar Agora e entrar no canal
      await _joinAgoraChannel(session);

      // Inscrever no Realtime via RealtimeService (com retry automático)
      _subscribeToCall(session.id);

      return session;
    } catch (e) {
      debugPrint('CallService.createCall error: $e');
      return null;
    }
  }

  /// =========================================================================
  /// joinCall — Usa RPC `join_call_session` ao invés de INSERT direto.
  ///
  /// A RPC valida:
  /// - Autenticação
  /// - Sessão existe e está ativa
  /// - Membership no chat
  /// - Upsert (suporta reconexão sem duplicar)
  /// =========================================================================
  static Future<bool> joinCall(String callSessionId) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return false;

      // Join via RPC (validação server-side)
      final rpcResult = await SupabaseService.rpc('join_call_session', params: {
        'p_session_id': callSessionId,
      });

      final result = rpcResult as Map<String, dynamic>? ?? {};
      if (result['success'] != true) {
        debugPrint('CallService.joinCall RPC error: ${result['error']}');
        return false;
      }

      // Buscar sessão completa
      final res = await SupabaseService.table('call_sessions')
          .select()
          .eq('id', callSessionId)
          .single();

      final session = CallSession.fromJson(res);
      activeCall = session;

      // Solicitar permissões
      final granted = await _requestPermissions(session.type);
      if (!granted) return false;

      // Inicializar Agora e entrar no canal
      await _joinAgoraChannel(session);

      // Inscrever no Realtime via RealtimeService
      _subscribeToCall(callSessionId);

      return true;
    } catch (e) {
      debugPrint('CallService.joinCall error: $e');
      return false;
    }
  }

  /// Gera o channelName a partir do ID da sessão.
  static String _channelName(CallSession session) {
    return 'nexushub_${session.id.replaceAll('-', '').substring(0, 16)}';
  }

  /// Busca token Agora via Supabase Edge Function.
  static Future<String?> _fetchAgoraToken(String channelName) async {
    try {
      final res = await SupabaseService.edgeFunction(
        'agora-token',
        body: {
          'channelName': channelName,
          'uid': 0,
          'role': 'publisher',
        },
      );
      if (res.status == 200 && res.data != null) {
        final data = res.data as Map<String, dynamic>;
        return data['token'] as String?;
      }
    } catch (e) {
      debugPrint('CallService._fetchAgoraToken error: $e');
    }
    return null;
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

    await _engine!.setEnableSpeakerphone(_isSpeakerOn);

    final channelName = _channelName(session);

    _agoraToken = await _fetchAgoraToken(channelName);

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

  /// =========================================================================
  /// leaveCall — Usa RPC `leave_call_session`.
  ///
  /// A RPC:
  /// - Marca participante como disconnected
  /// - Se é o criador, encerra a chamada
  /// - Se ninguém mais está conectado, encerra automaticamente
  /// =========================================================================
  static Future<void> leaveCall() async {
    if (activeCall == null) return;
    try {
      // Sair do canal Agora
      await _engine?.leaveChannel();
      await _engine?.stopPreview();

      // Leave via RPC (validação server-side)
      final currentCall = activeCall;
      if (currentCall != null) {
        await SupabaseService.rpc('leave_call_session', params: {
          'p_session_id': currentCall.id,
        });
      }
    } catch (e) {
      debugPrint('CallService.leaveCall error: $e');
    }
    _cleanup();
  }

  /// =========================================================================
  /// endCall — Usa RPC `end_call_session`.
  ///
  /// A RPC:
  /// - Verifica se é o criador ou admin
  /// - Encerra sessão e desconecta todos os participantes
  /// =========================================================================
  static Future<void> endCall() async {
    final call = activeCall;
    if (call == null) return;
    try {
      await _engine?.leaveChannel();

      await SupabaseService.rpc('end_call_session', params: {
        'p_session_id': call.id,
      });
    } catch (e) {
      debugPrint('[call_service] Erro: $e');
    }
    _cleanup();
  }

  /// Buscar participantes ativos
  static Future<List<Map<String, dynamic>>> getParticipants() async {
    final call = activeCall;
    if (call == null) return [];
    try {
      final res = await SupabaseService.table('call_participants')
          .select('*, profiles!call_participants_user_id_fkey(*)')
          .eq('call_session_id', call.id)
          .eq('status', 'connected');
      return List<Map<String, dynamic>>.from(res as List? ?? []);
    } catch (_) {
      return [];
    }
  }

  /// =========================================================================
  /// _subscribeToCall — Usa RealtimeService com retry automático.
  ///
  /// Antes: usava SupabaseService.client.channel() diretamente (sem retry).
  /// Agora: usa RealtimeService.instance.subscribeWithRetry() que tem
  /// backoff exponencial e reconexão automática.
  /// =========================================================================
  static void _subscribeToCall(String callSessionId) {
    _callChannelName = 'call:$callSessionId';

    RealtimeService.instance.subscribeWithRetry(
      channelName: _callChannelName!,
      configure: (channel) {
        channel.onPostgresChanges(
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
            if (!_participantsController.isClosed) {
              _participantsController.add(participants);
            }
          },
        );
      },
    );
  }

  static void _cleanup() {
    // Desinscrever via RealtimeService (ao invés de channel.unsubscribe() direto)
    if (_callChannelName != null) {
      RealtimeService.instance.unsubscribe(_callChannelName!);
      _callChannelName = null;
    }
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
