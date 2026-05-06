import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/call_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/models/message_model.dart';

// ============================================================================
// ChatCallState — Estado imutável da call inline
// ============================================================================
class ChatCallState {
  final CallSession? session;
  final bool isActive;
  /// Painel visível mas ainda conectando ao Agora (loading state)
  final bool isConnecting;
  final bool isExpanded;
  final List<Map<String, dynamic>> participants;
  final Set<int> remoteUsers;
  final Map<int, double> audioLevels;
  final StageRole myRole;
  final Set<String> handRaisedUsers;
  final bool handRaised;
  final bool isMuted;
  final bool isSpeakerOn;
  final String elapsed;
  final List<MessageModel> messages;
  final bool isSendingMessage;
  /// Mensagem de erro de conexão (null = sem erro)
  final String? connectError;

  const ChatCallState({
    this.session,
    this.isActive = false,
    this.isConnecting = false,
    this.isExpanded = true,
    this.participants = const [],
    this.remoteUsers = const {},
    this.audioLevels = const {},
    this.myRole = StageRole.speaker,
    this.handRaisedUsers = const {},
    this.handRaised = false,
    this.isMuted = false,
    this.isSpeakerOn = true,
    this.elapsed = '00:00',
    this.messages = const [],
    this.isSendingMessage = false,
    this.connectError,
  });

  ChatCallState copyWith({
    CallSession? session,
    bool? isActive,
    bool? isConnecting,
    bool? isExpanded,
    List<Map<String, dynamic>>? participants,
    Set<int>? remoteUsers,
    Map<int, double>? audioLevels,
    StageRole? myRole,
    Set<String>? handRaisedUsers,
    bool? handRaised,
    bool? isMuted,
    bool? isSpeakerOn,
    String? elapsed,
    List<MessageModel>? messages,
    bool? isSendingMessage,
    String? connectError,
    bool clearConnectError = false,
  }) {
    return ChatCallState(
      session: session ?? this.session,
      isActive: isActive ?? this.isActive,
      isConnecting: isConnecting ?? this.isConnecting,
      isExpanded: isExpanded ?? this.isExpanded,
      participants: participants ?? this.participants,
      remoteUsers: remoteUsers ?? this.remoteUsers,
      audioLevels: audioLevels ?? this.audioLevels,
      myRole: myRole ?? this.myRole,
      handRaisedUsers: handRaisedUsers ?? this.handRaisedUsers,
      handRaised: handRaised ?? this.handRaised,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      elapsed: elapsed ?? this.elapsed,
      messages: messages ?? this.messages,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
      connectError: clearConnectError ? null : (connectError ?? this.connectError),
    );
  }

  List<Map<String, dynamic>> get speakers => participants
      .where((p) =>
          p['stage_role'] == 'host' ||
          p['stage_role'] == 'speaker' ||
          p['stage_role'] == null)
      .toList();

  List<Map<String, dynamic>> get listeners =>
      participants.where((p) => p['stage_role'] == 'listener').toList();
}

// ============================================================================
// ChatCallController — StateNotifier com toda a lógica de call extraída
// ============================================================================
class ChatCallController extends StateNotifier<ChatCallState> {
  StreamSubscription? _participantsSub;
  StreamSubscription? _remoteUsersSub;
  StreamSubscription? _audioLevelsSub;
  StreamSubscription? _stageRoleSub;
  StreamSubscription? _handRaisedSub;
  Timer? _durationTimer;
  DateTime? _startTime;
  String? _chatChannelName;
  int _prevHandRaisedCount = 0;

  ChatCallController(Ref ref) : super(const ChatCallState());

  // ── Abrir painel imediatamente (estado de conexão) ────────────────────────
  /// Chamado ANTES de createCallOnly/joinExistingCall para abrir o painel
  /// instantaneamente com spinner de "Conectando...". Elimina o delay percebido.
  void startConnecting() {
    state = const ChatCallState(
      isConnecting: true,
      isExpanded: true,
    );
  }

  /// Chamado quando a conexão falha — fecha o painel e exibe o erro.
  void connectFailed(String error) {
    if (!mounted) return;
    state = const ChatCallState(); // fecha o painel
    debugPrint('[ChatCallController] connectFailed: $error');
  }

  // ── Iniciar ou entrar na call (após Agora conectado) ──────────────────────
  Future<void> attach(CallSession session) async {
    _startTime = DateTime.now();

    state = ChatCallState(
      session: session,
      isActive: true,
      isConnecting: false, // Agora conectado — sai do loading
      isExpanded: true,
      isMuted: CallService.isMuted,
      isSpeakerOn: CallService.isSpeakerOn,
      myRole: CallService.myStageRole,
    );

    _subscribeStreams();
    _startDurationTimer();
    await _loadParticipants();
    _subscribeChatRealtime(session.threadId);
  }

  // ── Streams do CallService ────────────────────────────────────────────────

  void _subscribeStreams() {
    _participantsSub = CallService.participantsStream.listen((p) {
      if (!mounted) return;
      state = state.copyWith(participants: p);
    });

    _remoteUsersSub = CallService.remoteUsersStream.listen((u) {
      if (!mounted) return;
      state = state.copyWith(remoteUsers: u);
    });

    _audioLevelsSub = CallService.audioLevelsStream.listen((l) {
      if (!mounted) return;
      state = state.copyWith(audioLevels: l);
    });

    _stageRoleSub = CallService.stageRoleStream.listen((role) {
      if (!mounted) return;
      state = state.copyWith(myRole: role);
    });

    _handRaisedSub = CallService.handRaisedUsersStream.listen((raised) {
      if (!mounted) return;
      // Notificar host quando alguém novo levantar a mão
      if (state.myRole.isHost && raised.length > _prevHandRaisedCount) {
        HapticService.action();
      }
      _prevHandRaisedCount = raised.length;
      state = state.copyWith(handRaisedUsers: raised);
    });
  }

  // ── Timer de duração ──────────────────────────────────────────────────────

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _startTime == null) return;
      final diff = DateTime.now().difference(_startTime!);
      final mm = diff.inMinutes.toString().padLeft(2, '0');
      final ss = (diff.inSeconds % 60).toString().padLeft(2, '0');
      state = state.copyWith(elapsed: '$mm:$ss');
    });
  }

  // ── Participantes ─────────────────────────────────────────────────────────

  Future<void> _loadParticipants() async {
    final p = await CallService.getParticipants();
    if (!mounted) return;
    state = state.copyWith(participants: p);
  }

  // ── Chat Realtime ─────────────────────────────────────────────────────────

  void _subscribeChatRealtime(String threadId) {
    _chatChannelName = 'inline_call_chat:$threadId';
    RealtimeService.instance.subscribeWithRetry(
      channelName: _chatChannelName!,
      configure: (channel) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) async {
            if (!mounted) return;
            final raw = Map<String, dynamic>.from(
                payload.newRecord as Map? ?? {});
            if (raw.isEmpty) return;
            // Enriquecer com perfil
            try {
              final authorId = raw['author_id'] as String?;
              if (authorId != null) {
                final profileRes = await SupabaseService.table('profiles')
                    .select('id, nickname, icon_url')
                    .eq('id', authorId)
                    .maybeSingle();
                if (profileRes != null) {
                  raw['profiles'] = profileRes;
                  raw['sender'] = profileRes;
                  raw['author'] = profileRes;
                }
              }
            } catch (_) {}
            final msg = MessageModel.fromJson(raw);
            if (!mounted) return;
            state = state.copyWith(
              messages: [...state.messages, msg],
            );
          },
        );
      },
    );
  }

  // ── Controles ─────────────────────────────────────────────────────────────

  Future<void> toggleMute() async {
    HapticService.micOn();
    await CallService.toggleMute();
    if (!mounted) return;
    state = state.copyWith(isMuted: CallService.isMuted);
  }

  Future<void> toggleSpeaker() async {
    HapticService.buttonPress();
    await CallService.toggleSpeaker();
    if (!mounted) return;
    state = state.copyWith(isSpeakerOn: CallService.isSpeakerOn);
  }

  Future<void> toggleHandRaise() async {
    HapticService.handRaise();
    final newState = !state.handRaised;
    state = state.copyWith(handRaised: newState);
    await CallService.raiseHand(raised: newState);
  }

  Future<void> stepDown() async {
    HapticService.action();
    await CallService.stepDown();
  }

  void toggleExpanded() {
    HapticService.tap();
    state = state.copyWith(isExpanded: !state.isExpanded);
  }

  // ── Sair / Encerrar ───────────────────────────────────────────────────────

  Future<void> leave() async {
    HapticService.action();
    await CallService.leaveCall();
    _teardown();
  }

  Future<void> end(String? callerNickname) async {
    HapticService.error();
    final session = state.session;
    await CallService.endCall();
    // Mensagem de sistema informando encerramento
    if (session != null) {
      try {
        final nickname = callerNickname ?? 'Alguém';
        await SupabaseService.rpc(
          'send_chat_message_with_reputation',
          params: {
            'p_thread_id': session.threadId,
            'p_content': '$nickname encerrou o Voice Chat',
            'p_type': 'system_voice_end',
          },
        );
      } catch (e) {
        debugPrint('[ChatCallController] Erro ao enviar system_voice_end: $e');
      }
    }
    _teardown();
  }

  // ── Limpeza interna ───────────────────────────────────────────────────────

  void _teardown() {
    _participantsSub?.cancel();
    _remoteUsersSub?.cancel();
    _audioLevelsSub?.cancel();
    _stageRoleSub?.cancel();
    _handRaisedSub?.cancel();
    _durationTimer?.cancel();
    if (_chatChannelName != null) {
      RealtimeService.instance.unsubscribe(_chatChannelName!);
      _chatChannelName = null;
    }
    _startTime = null;
    _prevHandRaisedCount = 0;
    if (mounted) {
      state = const ChatCallState();
    }
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  // ── Helper: nível de áudio de um participante ─────────────────────────────

  double audioLevelFor(Map<String, dynamic> participant) {
    final agoraUid = participant['agora_uid'] as int?;
    final levels = state.audioLevels;
    if (agoraUid != null && levels.containsKey(agoraUid)) {
      return (levels[agoraUid]! / 255.0).clamp(0.0, 1.0);
    }
    if (levels.isNotEmpty) {
      return (levels.values.reduce((a, b) => a > b ? a : b) / 255.0)
          .clamp(0.0, 1.0);
    }
    return 0.0;
  }
}

// ============================================================================
// Provider — scoped por threadId para suportar múltiplos chats abertos
// ============================================================================
final chatCallProvider = StateNotifierProvider.family<
    ChatCallController, ChatCallState, String>(
  (ref, threadId) => ChatCallController(ref),
);

// ============================================================================
// activeCallSessionProvider — busca a call ativa do thread no banco.
// Usado para exibir o painel para TODOS os membros do chat, mesmo quem
// ainda não entrou na call.
// ============================================================================
final activeCallSessionProvider =
    FutureProvider.family<CallSession?, String>((ref, threadId) async {
  try {
    return await CallService.getActiveCallForThread(
      threadId,
      allowedTypes: {CallType.voice, CallType.stage},
    );
  } catch (_) {
    return null;
  }
});
