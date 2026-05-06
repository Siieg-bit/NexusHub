import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';
import '../../core/l10n/locale_provider.dart';
import 'realtime_service.dart';
import 'supabase_service.dart';

/// ============================================================================
/// CallService — Gerencia chamadas de voz, vídeo e Sala de Projeção.
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

enum CallType { voice, video, screeningRoom, stage }

// ─── Stage Roles ─────────────────────────────────────────────────────────────
enum StageRole { host, speaker, listener }

extension StageRoleX on StageRole {
  String get value {
    switch (this) {
      case StageRole.host:     return 'host';
      case StageRole.speaker:  return 'speaker';
      case StageRole.listener: return 'listener';
    }
  }

  bool get canSpeak => this == StageRole.host || this == StageRole.speaker;
  bool get isHost   => this == StageRole.host;

  static StageRole fromString(String? s) {
    switch (s) {
      case 'host':     return StageRole.host;
      case 'listener': return StageRole.listener;
      default:         return StageRole.speaker;
    }
  }
}

class CallSession {
  final String id;
  final String threadId;
  final String? communityId;
  final CallType type;
  final String creatorId;
  final String status;
  final DateTime createdAt;

  const CallSession({
    required this.id,
    required this.threadId,
    this.communityId,
    required this.type,
    required this.creatorId,
    required this.status,
    required this.createdAt,
  });

  factory CallSession.fromJson(Map<String, dynamic> json) {
    // community_id pode vir diretamente (quando a query faz join com chat_threads)
    // ou via o mapa aninhado 'chat_threads' (quando select inclui o relacionamento)
    final threadMap = json['chat_threads'] as Map<String, dynamic>?;
    final communityId = (json['community_id'] as String?) ??
        (threadMap?['community_id'] as String?);
    return CallSession(
      id: json['id'] as String? ?? '',
      threadId: json['thread_id'] as String? ?? '',
      communityId: communityId?.trim().isEmpty == true ? null : communityId?.trim(),
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
      case 'stage':
        return CallType.stage;
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
      case CallType.stage:
        return 'stage';
      case CallType.voice:
        return 'voice';
    }
  }
}

class OpenThreadCallResult {
  final CallSession session;
  final bool reusedExistingSession;

  const OpenThreadCallResult({
    required this.session,
    required this.reusedExistingSession,
  });
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
  static final _stageRoleController =
      StreamController<StageRole>.broadcast();
  static final _handRaisedUsersController =
      StreamController<Set<String>>.broadcast();

  static Stream<List<Map<String, dynamic>>> get participantsStream =>
      _participantsController.stream;
  static Stream<Set<int>> get remoteUsersStream =>
      _remoteUsersController.stream;
  static Stream<Map<int, double>> get audioLevelsStream =>
      _audioLevelsController.stream;
  static Stream<StageRole> get stageRoleStream => _stageRoleController.stream;
  static Stream<Set<String>> get handRaisedUsersStream =>
      _handRaisedUsersController.stream;

  static final Set<int> _remoteUsers = {};
  static final Map<int, double> _audioLevels = {};
  static bool _isMuted = false;
  static bool _isCameraOn = false;
  static bool _isSpeakerOn = true;
  static StageRole _myStageRole = StageRole.speaker;
  static Set<String> _handRaisedUsers = {};
  static Map<String, Map<String, dynamic>> _participantsCache = {};
  static Object? _lastError;
  static StackTrace? _lastStackTrace;
  static String? _lastErrorStage;
  static Map<String, dynamic>? _lastErrorContext;

  static bool get isMuted => _isMuted;
  static bool get isCameraOn => _isCameraOn;
  static bool get isSpeakerOn => _isSpeakerOn;
  static StageRole get myStageRole => _myStageRole;

  /// Força o role para host — usado ao reconectar o host após reiniciar o app.
  static void setMyStageRoleHost() {
    _myStageRole = StageRole.host;
    if (!_stageRoleController.isClosed) {
      _stageRoleController.add(_myStageRole);
    }
  }
  static Set<String> get handRaisedUsers => Set.unmodifiable(_handRaisedUsers);
  static RtcEngine? get engine => _engine;
  static Set<int> get remoteUsers => _remoteUsers;
  static String? get lastErrorStage => _lastErrorStage;
  static Object? get lastError => _lastError;
  static StackTrace? get lastStackTrace => _lastStackTrace;
  static Map<String, dynamic>? get lastErrorContext => _lastErrorContext == null
      ? null
      : Map<String, dynamic>.from(_lastErrorContext!);

  static void clearLastError() {
    _lastError = null;
    _lastStackTrace = null;
    _lastErrorStage = null;
    _lastErrorContext = null;
  }

  static void _recordFailure({
    required String stage,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    _lastErrorStage = stage;
    _lastError = error;
    _lastStackTrace = stackTrace;
    _lastErrorContext = context == null ? null : Map<String, dynamic>.from(context);

    debugPrint('[CallService][$stage] $error');
    if (context != null && context.isNotEmpty) {
      debugPrint('[CallService][$stage][context] $context');
    }
    if (stackTrace != null) {
      debugPrintStack(
        label: '[CallService][$stage][stackTrace]',
        stackTrace: stackTrace,
      );
    }
  }

  static String buildLastErrorReport({
    String title = 'CALL ERROR REPORT',
  }) {
    final buffer = StringBuffer()
      ..writeln('===== $title =====')
      ..writeln('stage: ${_lastErrorStage ?? 'unknown'}')
      ..writeln('error: ${_lastError ?? 'none'}');

    if (_lastErrorContext != null && _lastErrorContext!.isNotEmpty) {
      buffer.writeln('context: ${_lastErrorContext.toString()}');
    }

    if (_lastStackTrace != null) {
      buffer
        ..writeln('stackTrace:')
        ..writeln(_lastStackTrace.toString());
    } else {
      buffer.writeln('stackTrace: <not captured>');
    }

    buffer.writeln('===== END CALL ERROR REPORT =====');
    return buffer.toString();
  }

  static String get lastErrorSummary {
    final stage = _lastErrorStage ?? 'unknown';
    final error = _lastError?.toString() ?? 'unknown error';
    return '[$stage] $error';
  }

  static Never throwLastErrorAsStateError([String fallbackMessage = 'Unknown call error']) {
    final report = buildLastErrorReport();
    throw StateError(report.isEmpty ? fallbackMessage : report);
  }

  /// Inicializa o Agora RTC Engine (chamado uma vez)
  static Future<void> _initEngine() async {
    if (_isEngineInitialized && _engine != null) return;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: _agoraAppId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));
    // Cenário ChatRoom: áudio bidirecional otimizado para voz em grupo.
    // Evita supressão de eco agressiva que silencia o áudio remoto.
    await _engine!.setAudioScenario(AudioScenarioType.audioScenarioChatroom);

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
      final s = getStrings();
        debugPrint(
            s.joinedChannelInMs);
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
    clearLastError();
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        _recordFailure(
          stage: 'createCall.auth',
          error: StateError('SupabaseService.currentUserId returned null'),
          stackTrace: StackTrace.current,
          context: {
            'threadId': threadId,
            'type': type.name,
          },
        );
        return null;
      }

      // Solicitar permissões
      final granted = await _requestPermissions(type);
      if (!granted) {
        _recordFailure(
          stage: 'createCall.permissions',
          error: StateError('Microphone/camera permission denied'),
          stackTrace: StackTrace.current,
          context: {
            'threadId': threadId,
            'type': type.name,
            'userId': userId,
          },
        );
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
        final errCode = result['error'] as String? ?? 'unknown rpc error';

        // Race condition: outro usuário criou uma call no mesmo instante.
        // Tentar recuperar a sessão ativa e entrar nela.
        if (errCode == 'call_already_active') {
          final raceWinner = await getActiveCallForThread(
            threadId,
            allowedTypes: {type},
          );
          if (raceWinner != null) {
            // Entrar na sessão criada pelo outro usuário
            return joinCallSession(raceWinner.id);
          }
        }

        _recordFailure(
          stage: 'createCall.rpc',
          error: StateError('create_call_session returned success=false: $errCode'),
          stackTrace: StackTrace.current,
          context: {
            'threadId': threadId,
            'type': typeStr,
            'userId': userId,
            'rpcResult': result,
          },
        );
        return null;
      }

      final sessionId = result['session_id'] as String;

          // Buscar a sessão completa incluindo community_id via join
      final res = await SupabaseService.table('call_sessions')
          .select('*, chat_threads!call_sessions_thread_id_fkey(community_id)')
          .eq('id', sessionId)
          .single();
      final session = CallSession.fromJson(res);
      activeCall = session;
      // O criador da sessão é sempre o host
      _myStageRole = StageRole.host;
      if (!_stageRoleController.isClosed) _stageRoleController.add(_myStageRole);
      // Inicializar Agora e entrar no canal
      await _joinAgoraChannel(session);
      // Inscrever no Realtime via RealtimeService (com retry automático)
      _subscribeToCall(session.id);
      return session;
    } catch (e, st) {
      _recordFailure(
        stage: 'createCall.exception',
        error: e,
        stackTrace: st,
        context: {
          'threadId': threadId,
          'type': type.name,
        },
      );
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
  static Future<CallSession?> joinCallSession(String callSessionId) async {
    clearLastError();
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        _recordFailure(
          stage: 'joinCall.auth',
          error: StateError('SupabaseService.currentUserId returned null'),
          stackTrace: StackTrace.current,
          context: {
            'callSessionId': callSessionId,
          },
        );
        return null;
      }

      // Join via RPC (validação server-side)
      final rpcResult = await SupabaseService.rpc('join_call_session', params: {
        'p_session_id': callSessionId,
      });

      final result = rpcResult as Map<String, dynamic>? ?? {};
      if (result['success'] != true) {
        _recordFailure(
          stage: 'joinCall.rpc',
          error: StateError('join_call_session returned success=false: ${result['error'] ?? 'unknown rpc error'}'),
          stackTrace: StackTrace.current,
          context: {
            'callSessionId': callSessionId,
            'userId': userId,
            'rpcResult': result,
          },
        );
        return null;
      }

      // Buscar sessão completa incluindo community_id via join
      final res = await SupabaseService.table('call_sessions')
          .select('*, chat_threads!call_sessions_thread_id_fkey(community_id)')
          .eq('id', callSessionId)
          .single();
      final session = CallSession.fromJson(res);
      activeCall = session;

      // Solicitar permissões
      final granted = await _requestPermissions(session.type);
      if (!granted) {
        _recordFailure(
          stage: 'joinCall.permissions',
          error: StateError('Microphone/camera permission denied'),
          stackTrace: StackTrace.current,
          context: {
            'callSessionId': callSessionId,
            'threadId': session.threadId,
            'type': session.typeString,
            'userId': userId,
          },
        );
        return null;
      }

      // Inicializar Agora e entrar no canal
      await _joinAgoraChannel(session);

      // Inscrever no Realtime via RealtimeService
      _subscribeToCall(callSessionId);

      return session;
    } catch (e, st) {
      _recordFailure(
        stage: 'joinCall.exception',
        error: e,
        stackTrace: st,
        context: {
          'callSessionId': callSessionId,
        },
      );
      return null;
    }
  }

  static Future<bool> joinCall(String callSessionId) async {
    return (await joinCallSession(callSessionId)) != null;
  }

  static Future<CallSession?> getActiveCallForThread(
    String threadId, {
    Set<CallType>? allowedTypes,
  }) async {
    try {
      // Busca sessões ativas: status='active' OU (status IS NULL AND is_active=true).
      // O banco pode ter sessões antigas com status NULL mas is_active=true
      // (criadas antes da coluna status existir), o que causa call_already_active
      // no RPC mas não é detectado pelo Flutter com .eq('status','active').
      final res = await SupabaseService.table('call_sessions')
          .select('*, chat_threads!call_sessions_thread_id_fkey(community_id)')
          .eq('thread_id', threadId)
          .or('status.eq.active,and(status.is.null,is_active.eq.true)')
          .order('created_at', ascending: false)
          .limit(10);

      final rows = List<Map<String, dynamic>>.from(res as List? ?? const []);
      for (final row in rows) {
        final session = CallSession.fromJson(row);
        if (allowedTypes == null || allowedTypes.contains(session.type)) {
          return session;
        }
      }
    } catch (e, st) {
      _recordFailure(
        stage: 'getActiveCallForThread.exception',
        error: e,
        stackTrace: st,
        context: {
          'threadId': threadId,
          'allowedTypes': allowedTypes?.map((type) => type.name).toList(),
        },
      );
    }
    return null;
  }

  static Future<OpenThreadCallResult?> openThreadCallDetailed({
    required String threadId,
    required CallType type,
  }) async {
    clearLastError();
    final allowedTypes = {type};

    final existing = await getActiveCallForThread(
      threadId,
      allowedTypes: allowedTypes,
    );
    if (existing != null) {
      final session = activeCall?.id == existing.id
          ? activeCall
          : await joinCallSession(existing.id);
      if (session == null) return null;
      return OpenThreadCallResult(
        session: session,
        reusedExistingSession: true,
      );
    }

    final created = await createCall(threadId: threadId, type: type);
    if (created != null) {
      return OpenThreadCallResult(
        session: created,
        reusedExistingSession: false,
      );
    }

    final raceWinner = await getActiveCallForThread(
      threadId,
      allowedTypes: allowedTypes,
    );
    if (raceWinner != null) {
      final session = activeCall?.id == raceWinner.id
          ? activeCall
          : await joinCallSession(raceWinner.id);
      if (session == null) return null;
      return OpenThreadCallResult(
        session: session,
        reusedExistingSession: true,
      );
    }

    if (lastError == null) {
      _recordFailure(
        stage: 'openThreadCall.empty-result',
        error: StateError('No active session was found or created for the requested thread'),
        stackTrace: StackTrace.current,
        context: {
          'threadId': threadId,
          'type': type.name,
        },
      );
    }

    return null;
  }

  static Future<CallSession?> openThreadCall({
    required String threadId,
    required CallType type,
  }) async {
    final result = await openThreadCallDetailed(threadId: threadId, type: type);
    return result?.session;
  }

  /// =========================================================================
  /// createCallOnly — Cria uma nova call SEM entrar em uma existente.
  ///
  /// Usado pelo botão do AppBar: se já existe uma call ativa no thread,
  /// retorna `callAlreadyActive` em vez de entrar automaticamente.
  /// O usuário deve usar o botão "Entrar" no bubble para participar.
  /// =========================================================================
  static Future<({CallSession? session, bool callAlreadyActive})>
      createCallOnly({
    required String threadId,
    required CallType type,
  }) async {
    clearLastError();
    final allowedTypes = {type};

    // Verificar se já existe uma call ativa — NÃO entrar, apenas informar.
    final existing = await getActiveCallForThread(
      threadId,
      allowedTypes: allowedTypes,
    );
    if (existing != null) {
      // Se o próprio usuário já está nessa call, retornar a sessão existente.
      if (activeCall?.id == existing.id) {
        return (session: activeCall, callAlreadyActive: false);
      }
      // Outro usuário iniciou — não entrar automaticamente.
      return (session: null, callAlreadyActive: true);
    }

    // Nenhuma call ativa: criar uma nova (e entrar como host).
    final created = await createCall(threadId: threadId, type: type);
    return (session: created, callAlreadyActive: false);
  }

  /// =========================================================================
  /// joinExistingCall — Entra em uma call existente no thread.
  ///
  /// Usado pelo botão "Entrar" no bubble da mensagem system_voice_start.
  /// Retorna null se não houver call ativa.
  /// =========================================================================
  static Future<CallSession?> joinExistingCall({
    required String threadId,
    required CallType type,
  }) async {
    clearLastError();
    final allowedTypes = {type};

    final existing = await getActiveCallForThread(
      threadId,
      allowedTypes: allowedTypes,
    );
    if (existing == null) return null;

    // Se já está na call, retornar a sessão sem re-entrar.
    if (activeCall?.id == existing.id) return activeCall;

    return joinCallSession(existing.id);
  }

  /// =========================================================================
  /// joinAsAudience — Entra no canal Agora como ouvinte passivo (sem publicar).
  ///
  /// Não chama nenhuma RPC de call_participants — o usuário apenas ouve.
  /// Usado para mostrar o painel completo para todos os membros do chat.
  /// =========================================================================
  static Future<CallSession?> joinAsAudience({
    required String threadId,
  }) async {
    clearLastError();
    try {
      final existing = await getActiveCallForThread(
        threadId,
        allowedTypes: {CallType.voice, CallType.stage},
      );
      if (existing == null) return null;
      // Se já está na call como participante ativo, retornar sessão existente.
      if (activeCall?.id == existing.id) return activeCall;
      final channelName = _channelName(existing);
      final initEngineFuture = _initEngine();
      final tokenFuture = _fetchAgoraToken(channelName);
      await initEngineFuture;
      await _engine!.disableVideo();
      await _engine!.enableAudio();
      _isMuted = true; // ouvinte não publica mic
      _agoraToken = await tokenFuture;
      if (_agoraToken == null || _agoraToken!.isEmpty) {
        throw StateError('Unable to fetch Agora token for audience join');
      }
      final userId = SupabaseService.currentUserId ?? '';
      final agoraUid = userId.isNotEmpty
          ? userId.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0x7FFFFFFF)
          : 0;
      await _engine!.joinChannel(
        token: _agoraToken!,
        channelId: channelName,
        uid: agoraUid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: false,
          publishMicrophoneTrack: false,
          publishCameraTrack: false,
          clientRoleType: ClientRoleType.clientRoleAudience,
        ),
      );
      await _applySpeakerphonePreference(allowRetry: true);
      // Assinar Realtime de participantes para exibir quem está no palco.
      _subscribeToCall(existing.id);
      // Marcar sessão ativa localmente (sem participante no banco).
      activeCall = existing;
      return existing;
    } catch (e, st) {
      _recordFailure(
        stage: 'joinAsAudience.exception',
        error: e,
        stackTrace: st,
        context: {'threadId': threadId},
      );
      return null;
    }
  }

  /// =========================================================================
  /// promoteToStage — Promove ouvinte passivo para broadcaster (sobe ao palco).
  ///
  /// Chama join_call_session RPC para registrar participante no banco,
  /// depois troca o clientRole do Agora para broadcaster.
  /// =========================================================================
  static Future<CallSession?> promoteToStage({
    required String threadId,
  }) async {
    clearLastError();
    try {
      final existing = await getActiveCallForThread(
        threadId,
        allowedTypes: {CallType.voice, CallType.stage},
      );
      if (existing == null) return null;
      // Registrar como participante no banco (join_call_session RPC).
      final rpcResult = await SupabaseService.rpc('join_call_session', params: {
        'p_session_id': existing.id,
      });
      final result = rpcResult as Map<String, dynamic>? ?? {};
      if (result['success'] != true) {
        _recordFailure(
          stage: 'promoteToStage.rpc',
          error: StateError('join_call_session returned success=false: ${result['error'] ?? 'unknown'}'),
          stackTrace: StackTrace.current,
          context: {'threadId': threadId, 'sessionId': existing.id},
        );
        return null;
      }
      // Solicitar permissão de microfone (pode não ter sido solicitada no joinAsAudience).
      final granted = await _requestPermissions(CallType.voice);
      if (!granted) {
        _recordFailure(
          stage: 'promoteToStage.permissions',
          error: StateError('Microphone permission denied'),
          stackTrace: StackTrace.current,
          context: {'threadId': threadId},
        );
        return null;
      }
      // Garantir que o áudio está habilitado antes de trocar de role.
      await _engine?.enableAudio();
      // Trocar role no Agora para broadcaster (pode falar).
      // No SDK 6.x, setClientRole sozinho não ativa a publicação do mic.
      // É necessário chamar updateChannelMediaOptions com publishMicrophoneTrack=true.
      await _engine?.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine?.updateChannelMediaOptions(const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: false,
      ));
      await _engine?.muteLocalAudioStream(false);
      _isMuted = false;
      _myStageRole = StageRole.speaker;
      if (!_stageRoleController.isClosed) {
        _stageRoleController.add(_myStageRole);
      }
      activeCall = existing;
      return existing;
    } catch (e, st) {
      _recordFailure(
        stage: 'promoteToStage.exception',
        error: e,
        stackTrace: st,
        context: {'threadId': threadId},
      );
      return null;
    }
  }

  /// =========================================================================
  /// demoteToAudience — Desce do palco, volta a ouvinte passivo.
  ///
  /// Chama leave_call_session RPC para remover do banco,
  /// depois troca o clientRole do Agora para audience.
  /// =========================================================================
  static Future<void> demoteToAudience() async {
    final call = activeCall;
    if (call == null) return;
    try {
      await SupabaseService.rpc('leave_call_session', params: {
        'p_session_id': call.id,
      });
    } catch (e) {
      debugPrint('[CallService] demoteToAudience.rpc error: $e');
    }
    try {
      await _engine?.setClientRole(role: ClientRoleType.clientRoleAudience);
      await _engine?.updateChannelMediaOptions(const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleAudience,
        publishMicrophoneTrack: false,
        publishCameraTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: false,
      ));
      await _engine?.muteLocalAudioStream(true);
    } catch (e) {
      debugPrint('[CallService] demoteToAudience.agora error: $e');
    }
    _isMuted = true;
    _myStageRole = StageRole.listener;
    if (!_stageRoleController.isClosed) {
      _stageRoleController.add(_myStageRole);
    }
    // Manter activeCall para continuar ouvindo — não chamar _cleanup().
  }

  /// =========================================================================
  /// leaveAudience — Sai completamente do canal como ouvinte (sem RPC).
  ///
  /// Chamado quando a call é encerrada pelo host e o usuário estava só ouvindo.
  /// =========================================================================
  static Future<void> leaveAudience() async {
    try {
      await _engine?.leaveChannel();
    } catch (e) {
      debugPrint('[CallService] leaveAudience error: $e');
    }
    _cleanup();
  }

    /// Gera o channelName a partir do ID da sessão.
  static String _channelName(CallSession session) {
    return 'nexushub_${session.id.replaceAll('-', '').substring(0, 16)}';
  }

  /// Busca token Agora via Edge Function com headers explícitos e retry
  /// após refresh da sessão. Isso evita chamadas com JWT antigo e garante que
  /// a função receba tanto `Authorization` quanto `apikey`.
  static Future<String?> _fetchAgoraToken(String channelName) async {
    Future<String?> requestWithAccessToken(String accessToken) async {
      final uri = Uri.parse('${AppConfig.supabaseUrl}/functions/v1/agora-token');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'apikey': AppConfig.supabaseAnonKey,
        },
        body: jsonEncode({
          'channelName': channelName,
          'uid': 0,
          'role': 'publisher',
        }),
      );

      dynamic responseData;
      if (response.body.isNotEmpty) {
        try {
          responseData = jsonDecode(response.body);
        } catch (_) {
          responseData = response.body;
        }
      }

      if (response.statusCode == 200 && responseData is Map<String, dynamic>) {
        final token = responseData['token'] as String?;
        if (token == null || token.isEmpty) {
          _recordFailure(
            stage: 'fetchAgoraToken.empty-token',
            error: StateError('agora-token edge function returned an empty token'),
            stackTrace: StackTrace.current,
            context: {
              'channelName': channelName,
              'responseData': responseData,
            },
          );
          return null;
        }
        return token;
      }

      throw StateError(
        'agora-token edge function failed with status ${response.statusCode}: $responseData',
      );
    }

    try {
      final session = SupabaseService.currentSession;
      if (session == null) {
        throw StateError('No authenticated Supabase session available');
      }

      try {
        return await requestWithAccessToken(session.accessToken);
      } catch (firstError, firstStackTrace) {
        final refreshed = await SupabaseService.auth.refreshSession();
        final refreshedSession = refreshed.session ?? SupabaseService.currentSession;
        if (refreshedSession == null) {
          Error.throwWithStackTrace(firstError, firstStackTrace);
        }
        return await requestWithAccessToken(refreshedSession.accessToken);
      }
    } catch (e, st) {
      _recordFailure(
        stage: 'fetchAgoraToken.exception',
        error: e,
        stackTrace: st,
        context: {
          'channelName': channelName,
        },
      );
    }
    return null;
  }

  static Future<void> _applySpeakerphonePreference({bool allowRetry = false}) async {
    final engine = _engine;
    if (engine == null) return;

    Object? lastError;
    StackTrace? lastStackTrace;
    final totalAttempts = allowRetry ? 3 : 1;

    for (var attempt = 0; attempt < totalAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 250 * attempt));
      }

      try {
        await engine.setEnableSpeakerphone(_isSpeakerOn);
        return;
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;
      }
    }

    debugPrint(
      '[CallService][speakerphone] Unable to apply speaker preference after $totalAttempts attempt(s): $lastError',
    );
    if (lastStackTrace != null) {
      debugPrintStack(
        label: '[CallService][speakerphone][stackTrace]',
        stackTrace: lastStackTrace,
      );
    }
  }

  /// Entra no canal Agora com áudio/vídeo real
  static Future<void> _joinAgoraChannel(CallSession session) async {
    final channelName = _channelName(session);
    final initEngineFuture = _initEngine();
    final tokenFuture = _fetchAgoraToken(channelName);

    await initEngineFuture;

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

    _agoraToken = await tokenFuture;
    if (_agoraToken == null || _agoraToken!.isEmpty) {
      throw StateError('Unable to fetch a valid Agora token for channel $channelName');
    }

    // Gerar UID único e determinístico a partir do userId do Supabase.
    // uid=0 faz o Agora atribuir UIDs aleatórios que podem colidir entre usuários.
    final userId = SupabaseService.currentUserId ?? '';
    final agoraUid = userId.isNotEmpty
        ? userId.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0x7FFFFFFF)
        : 0;

    await _engine!.joinChannel(
      token: _agoraToken!,
      channelId: channelName,
      uid: agoraUid,
      options: ChannelMediaOptions(
        autoSubscribeAudio: true,
        autoSubscribeVideo: isVideo,
        publishMicrophoneTrack: true,
        publishCameraTrack: isVideo,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );

    // Garantir que o microfone está ativo após entrar no canal.
    await _engine!.muteLocalAudioStream(false);
    await _applySpeakerphonePreference(allowRetry: true);
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
    await _applySpeakerphonePreference(allowRetry: true);
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
    final currentCall = activeCall;
    if (currentCall == null) return;
    try {
      // Sair do canal Agora
      await _engine?.leaveChannel();
      await _engine?.stopPreview();

      // Leave via RPC (validação server-side)
      await SupabaseService.rpc('leave_call_session', params: {
        'p_session_id': currentCall.id,
      });
    } catch (e, st) {
      _recordFailure(
        stage: 'leaveCall.exception',
        error: e,
        stackTrace: st,
        context: {
          'callId': currentCall.id,
        },
      );
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
    } catch (e, st) {
      _recordFailure(
        stage: 'endCall.exception',
        error: e,
        stackTrace: st,
        context: {
          'callId': call.id,
        },
      );
    }
    _cleanup();
  }

  /// forceEndMyCallSessions — Encerra todas as sessões ativas onde o usuário é host.
  /// Usado quando o host fecha o app sem encerrar a call explicitamente.
  /// Não depende de activeCall local — opera direto no banco via RPC.
  static Future<void> forceEndMyCallSessions({String? threadId}) async {
    try {
      await _engine?.leaveChannel();
      await SupabaseService.rpc('force_end_my_call_sessions', params: {
        if (threadId != null) 'p_thread_id': threadId,
      });
    } catch (e) {
      debugPrint('[CallService] forceEndMyCallSessions error: \$e');
    }
    _cleanup();
  }

  /// Buscar participantes ativos
  static Future<List<Map<String, dynamic>>> getParticipants() async {
    final call = activeCall;
    if (call == null) return [];
    try {
      final res = await SupabaseService.table('call_participants')
          .select()
          .eq('call_session_id', call.id)
          .eq('status', 'connected');
      final participants = List<Map<String, dynamic>>.from(res as List? ?? []);
      if (participants.isEmpty) return participants;
      final userIds = participants
          .map((row) => row['user_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      if (userIds.isEmpty) return participants;
      // Buscar perfis globais
      final profilesRes = await SupabaseService.table('profiles')
          .select('id, nickname, icon_url, amino_id')
          .inFilter('id', userIds);
      final profiles = {
        for (final row in List<Map<String, dynamic>>.from(profilesRes as List? ?? []))
          (row['id'] as String?) ?? '': Map<String, dynamic>.from(row),
      };
      // Sobrescrever com identidade local quando o chat pertence a uma comunidade
      final communityId = call.communityId;
      if (communityId != null && communityId.isNotEmpty) {
        final membershipsRes = await SupabaseService.table('community_members')
            .select('user_id, local_nickname, local_icon_url')
            .eq('community_id', communityId)
            .inFilter('user_id', userIds);
        for (final m in List<Map<String, dynamic>>.from(
            membershipsRes as List? ?? [])) {
          final uid = m['user_id'] as String?;
          if (uid == null) continue;
          final profile = profiles[uid] ?? {};
          final localNick = (m['local_nickname'] as String?)?.trim();
          final localIcon = (m['local_icon_url'] as String?)?.trim();
          if (localNick != null && localNick.isNotEmpty) {
            profile['nickname'] = localNick;
          }
          if (localIcon != null && localIcon.isNotEmpty) {
            profile['icon_url'] = localIcon;
          }
          profiles[uid] = profile;
        }
      }
      return participants.map((participant) {
        final userId = participant['user_id'] as String? ?? '';
        return {
          ...participant,
          'profiles': profiles[userId],
        };
      }).toList();
    } catch (e, st) {
      _recordFailure(
        stage: 'getParticipants.exception',
        error: e,
        stackTrace: st,
        context: {
          'callId': call.id,
        },
      );
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
            _updateMyRole(participants);
          },
        );
      },
    );
  }

  // =========================================================================
  // STAGE METHODS — roles, mão levantada, moderar
  // =========================================================================

  /// Levantar / abaixar a mão (apenas listeners/speakers)
  static Future<bool> raiseHand({bool raised = true}) async {
    final call = activeCall;
    if (call == null) return false;
    try {
      final res = await SupabaseService.rpc('raise_hand_call', params: {
        'p_session_id': call.id,
        'p_raised': raised,
      });
      return (res as Map<String, dynamic>?)?['success'] == true;
    } catch (e) {
      debugPrint('[CallService] raiseHand error: $e');
      return false;
    }
  }

  /// Host aceita um speaker (promove listener → speaker)
  static Future<bool> acceptSpeaker(String targetUserId) async {
    final call = activeCall;
    if (call == null) return false;
    try {
      final res = await SupabaseService.rpc('accept_call_speaker', params: {
        'p_session_id': call.id,
        'p_target_user': targetUserId,
      });
      return (res as Map<String, dynamic>?)?['success'] == true;
    } catch (e) {
      debugPrint('[CallService] acceptSpeaker error: $e');
      return false;
    }
  }

  /// Speaker desce do palco voluntariamente
  static Future<bool> stepDown() async {
    final call = activeCall;
    if (call == null) return false;
    try {
      final res = await SupabaseService.rpc('step_down_call', params: {
        'p_session_id': call.id,
      });
      if ((res as Map<String, dynamic>?)?['success'] == true) {
        _myStageRole = StageRole.listener;
        if (!_stageRoleController.isClosed) {
          _stageRoleController.add(_myStageRole);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[CallService] stepDown error: $e');
      return false;
    }
  }

  /// Host muta/desmuta um participante
  static Future<bool> muteParticipant(String targetUserId,
      {bool muted = true}) async {
    final call = activeCall;
    if (call == null) return false;
    try {
      final res = await SupabaseService.rpc('mute_call_participant', params: {
        'p_session_id': call.id,
        'p_target_user': targetUserId,
        'p_muted': muted,
      });
      return (res as Map<String, dynamic>?)?['success'] == true;
    } catch (e) {
      debugPrint('[CallService] muteParticipant error: $e');
      return false;
    }
  }

  /// Host expulsa um participante
  static Future<bool> kickParticipant(String targetUserId) async {
    final call = activeCall;
    if (call == null) return false;
    try {
      final res = await SupabaseService.rpc('kick_call_participant', params: {
        'p_session_id': call.id,
        'p_target_user': targetUserId,
      });
      return (res as Map<String, dynamic>?)?['success'] == true;
    } catch (e) {
      debugPrint('[CallService] kickParticipant error: $e');
      return false;
    }
  }

  /// Atualiza o role local do usuário e emite nos streams
  static void _updateMyRole(List<Map<String, dynamic>> participants) {
    final myId = SupabaseService.currentUserId;
    if (myId == null) return;

    final me = participants.firstWhere(
      (p) => p['user_id'] == myId,
      orElse: () => {},
    );

    if (me.isNotEmpty) {
      final newRole =
          StageRoleX.fromString(me['stage_role'] as String?);
      if (newRole != _myStageRole) {
        _myStageRole = newRole;
        if (!_stageRoleController.isClosed) {
          _stageRoleController.add(_myStageRole);
        }
      }
    }

    // Atualizar mãos levantadas
    final raised = participants
        .where((p) => p['hand_raised'] == true)
        .map((p) => p['user_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    if (raised != _handRaisedUsers) {
      _handRaisedUsers = raised;
      if (!_handRaisedUsersController.isClosed) {
        _handRaisedUsersController.add(Set.from(_handRaisedUsers));
      }
    }

    // Cache dos participantes por userId
    _participantsCache = {
      for (final p in participants)
        if (p['user_id'] != null) p['user_id'] as String: p,
    };
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
    _handRaisedUsers.clear();
    _participantsCache.clear();
    _myStageRole = StageRole.speaker;
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
    _stageRoleController.close();
    _handRaisedUsersController.close();
  }
}
