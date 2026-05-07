import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/call_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/models/message_model.dart';
import '../../../core/widgets/mini_room_overlay.dart';

// ============================================================================
// ChatCallState — Estado imutável da call inline
//
// Modos possíveis:
//   isConnecting = true           → spinner "Conectando..."
//   isAudience = true             → ouvindo passivamente (painel completo visível)
//   isOnStage = true              → no palco como speaker/host
//   todos false + session != null → estado transitório
// ============================================================================
class ChatCallState {
  final CallSession? session;
  /// Usuário está no palco (broadcaster) — pode falar.
  final bool isOnStage;
  /// Usuário está ouvindo passivamente (audience) — vê o painel mas não fala.
  final bool isAudience;
  /// Painel visível mas ainda conectando ao Agora (loading state).
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
  /// Elapsed calculado a partir do created_at universal da sessão.
  final String elapsed;
  final List<MessageModel> messages;
  final bool isSendingMessage;
  /// Mensagem de erro de conexão (null = sem erro).
  final String? connectError;

  const ChatCallState({
    this.session,
    this.isOnStage = false,
    this.isAudience = false,
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

  /// O painel deve ser exibido quando há sessão ativa (qualquer modo).
  bool get isActive => isOnStage || isAudience;

  /// Compatibilidade retroativa com código que usa isActive diretamente.
  bool get isOnStageLegacy => isOnStage;

  ChatCallState copyWith({
    CallSession? session,
    bool? isOnStage,
    bool? isAudience,
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
      isOnStage: isOnStage ?? this.isOnStage,
      isAudience: isAudience ?? this.isAudience,
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

  // Inclui 'audience' como fallback de compatibilidade:
  // participantes inseridos antes da migration 232 (DEFAULT era 'audience')
  // ainda aparecem no palco em vez de ficarem invisíveis.
  // O host fica sempre na primeira posição (à esquerda na UI); os demais
  // participantes mantêm a ordem de entrada carregada do serviço.
  List<Map<String, dynamic>> get speakers {
    final stageParticipants = participants
        .where((p) =>
            p['stage_role'] == 'host' ||
            p['stage_role'] == 'speaker' ||
            p['stage_role'] == 'audience' ||
            p['stage_role'] == null)
        .toList();
    final hosts = stageParticipants.where((p) => p['stage_role'] == 'host');
    final others = stageParticipants.where((p) => p['stage_role'] != 'host');
    return [...hosts, ...others];
  }

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
  Timer? _participantsTimer; // Polling periódico como fallback ao Realtime
  String? _chatChannelName;
  int _prevHandRaisedCount = 0;

  // ── Stream de speaker ativo (alimenta o PiP) ──────────────────────────────
  final StreamController<ActiveSpeakerInfo?> _activeSpeakerController =
      StreamController<ActiveSpeakerInfo?>.broadcast();

  /// Stream que emite o speaker ativo a cada tick de áudio.
  /// Emite null quando ninguém está falando acima do threshold.
  Stream<ActiveSpeakerInfo?> get activeSpeakerStream =>
      _activeSpeakerController.stream;

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
    state = const ChatCallState();
    debugPrint('[ChatCallController] connectFailed: $error');
  }

  // ── Entrar como ouvinte passivo (painel completo, sem mic) ────────────────
  /// Chamado automaticamente quando há call ativa no thread.
  /// O usuário vê o palco completo e ouve tudo, mas não aparece como participante.
  Future<void> attachAsAudience(CallSession session) async {
    state = ChatCallState(
      session: session,
      isAudience: true,
      isOnStage: false,
      isConnecting: false,
      isExpanded: true,
      isMuted: true,
      isSpeakerOn: true,
    );
    _subscribeStreams();
    _startUniversalTimer(session.createdAt);
    _startParticipantsPolling();
    await _loadParticipants();
    _subscribeChatRealtime(session.threadId);
  }

  // ── Subir ao palco (ouvinte → speaker) ───────────────────────────────────
  /// Chama promoteToStage no CallService (RPC + troca de role no Agora).
  Future<void> goOnStage() async {
    final session = state.session;
    if (session == null) return;
    HapticService.action();
    state = state.copyWith(isConnecting: true);
    try {
      final promoted = await CallService.promoteToStage(
        threadId: session.threadId,
      );
      if (!mounted) return;
      if (promoted != null) {
        state = state.copyWith(
          isOnStage: true,
          isAudience: false,
          isConnecting: false,
          isMuted: CallService.isMuted,
          myRole: CallService.myStageRole,
        );
        // Primeiro carregamento imediato após 300ms (race condition com o banco).
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        await _loadParticipants();
        // Segundo carregamento após 800ms para garantir que o Realtime do host
        // recebeu o evento de INSERT e atualizou a lista no dispositivo remoto.
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        await _loadParticipants();
      } else {
        state = state.copyWith(isConnecting: false);
        debugPrint('[ChatCallController] goOnStage: promoteToStage returned null');
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isConnecting: false);
      debugPrint('[ChatCallController] goOnStage error: $e');
    }
  }

  // ── Descer do palco (speaker → ouvinte) ──────────────────────────────────
  /// Chama demoteToAudience no CallService (RPC + troca de role no Agora).
  Future<void> leaveStage() async {
    HapticService.action();
    await CallService.demoteToAudience();
    if (!mounted) return;
    state = state.copyWith(
      isOnStage: false,
      isAudience: true,
      isMuted: true,
      myRole: StageRole.listener,
    );
    await _loadParticipants();
  }

  // ── Iniciar ou entrar na call como speaker (host) ─────────────────────────
  /// Chamado pelo host ao criar a call ou ao entrar como speaker direto.
  Future<void> attach(CallSession session) async {
    state = ChatCallState(
      session: session,
      isOnStage: true,
      isAudience: false,
      isConnecting: false,
      isExpanded: true,
      isMuted: CallService.isMuted,
      isSpeakerOn: CallService.isSpeakerOn,
      myRole: CallService.myStageRole,
    );
    _subscribeStreams();
    _startUniversalTimer(session.createdAt);
    _startParticipantsPolling();
    await _loadParticipants();
    _subscribeChatRealtime(session.threadId);
  }

  // ── Encerramento global (host encerrou) ───────────────────────────────────
  /// Chamado quando o activeCallSessionProvider retorna null após estar ativo.
  /// Fecha o painel para todos os ouvintes passivos.
  void forceClose() {
    if (!mounted) return;
    _teardown();
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
      _emitActiveSpeaker(l);
    });

    _stageRoleSub = CallService.stageRoleStream.listen((role) {
      if (!mounted) return;
      state = state.copyWith(myRole: role);
    });

    _handRaisedSub = CallService.handRaisedUsersStream.listen((raised) {
      if (!mounted) return;
      if (state.myRole.isHost && raised.length > _prevHandRaisedCount) {
        HapticService.action();
      }
      _prevHandRaisedCount = raised.length;
      state = state.copyWith(handRaisedUsers: raised);
    });
  }

  // ── Timer universal baseado em created_at da sessão ──────────────────────
  /// Todos os usuários veem o mesmo contador, independente de quando entraram.
  void _startUniversalTimer(DateTime sessionCreatedAt) {
    _durationTimer?.cancel();
    _participantsTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final diff = DateTime.now().difference(sessionCreatedAt);
      final mm = diff.inMinutes.toString().padLeft(2, '0');
      final ss = (diff.inSeconds % 60).toString().padLeft(2, '0');
      state = state.copyWith(elapsed: '$mm:$ss');
    });
  }
  // ── Polling periódico de participantes (fallback ao Realtime) ─────────────
  /// Garante que a lista de participantes está sempre atualizada,
  /// mesmo que o Realtime tenha delay ou falhe.
  void _startParticipantsPolling() {
    _participantsTimer?.cancel();
    _participantsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      await _loadParticipants();
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

  // ── Controles (apenas para quem está no palco) ────────────────────────────
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

  /// Sair do palco e voltar a ouvinte passivo.
  Future<void> leave() async {
    HapticService.action();
    if (state.isOnStage) {
      await leaveStage();
    } else {
      // Ouvinte passivo sai completamente.
      await CallService.leaveAudience();
      _teardown();
    }
  }

  /// Encerrar a call (apenas host). Envia mensagem de sistema e fecha para todos.
  Future<void> end(String? callerNickname) async {
    HapticService.error();
    final session = state.session;
    await CallService.endCall();
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
    _prevHandRaisedCount = 0;
    if (mounted) {
      state = const ChatCallState();
    }
  }

  @override
  void dispose() {
    _teardown();
    if (!_activeSpeakerController.isClosed) {
      _activeSpeakerController.close();
    }
    super.dispose();
  }
  // ── Emitir speaker ativo para o PiP ───────────────────────────────────────────────
  /// Encontra o participante com maior nível de áudio acima do threshold
  /// e emite um [ActiveSpeakerInfo] para o PiP. Emite null quando ninguém fala.
  void _emitActiveSpeaker(Map<int, double> levels) {
    if (_activeSpeakerController.isClosed) return;

    const threshold = 15.0; // Volume mínimo para considerar que está falando
    int? topUid;
    double topLevel = threshold;

    for (final entry in levels.entries) {
      if (entry.value > topLevel) {
        topLevel = entry.value;
        topUid = entry.key;
      }
    }

    if (topUid == null) {
      _activeSpeakerController.add(null);
      return;
    }

    // Encontrar o participante correspondente ao agoraUid
    final participants = state.participants;
    Map<String, dynamic>? match;
    for (final p in participants) {
      final dynamic rawUid = p['agora_uid'];
      final uid = rawUid is int
          ? rawUid
          : int.tryParse(rawUid?.toString() ?? '') ??
              CallService.agoraUidForUserId(p['user_id'] as String?);
      if (uid == topUid) {
        match = p;
        break;
      }
    }

    // Fallback: uid 0 = próprio usuário local
    if (match == null && topUid == 0) {
      final myId = SupabaseService.currentUserId;
      if (myId != null) {
        match = participants.where((p) => p['user_id'] == myId).firstOrNull;
      }
    }

    if (match == null) {
      _activeSpeakerController.add(null);
      return;
    }

    final profile = match['profiles'] as Map<String, dynamic>?;
    final name = (profile?['nickname'] as String?) ??
        (match['nickname'] as String?) ??
        'Participante';
    final avatarUrl = (profile?['icon_url'] as String?) ??
        (match['icon_url'] as String?);

    _activeSpeakerController.add(ActiveSpeakerInfo(
      name: name,
      avatarUrl: avatarUrl,
      audioLevel: (topLevel / 255.0).clamp(0.0, 1.0),
    ));
  }

  // ── Helper: nível de áudio de um participante ───────────────────────────────────────────────
  double audioLevelFor(Map<String, dynamic> participant) {
    final userId = participant['user_id'] as String?;
    final dynamic rawAgoraUid = participant['agora_uid'];
    final agoraUid = rawAgoraUid is int
        ? rawAgoraUid
        : int.tryParse(rawAgoraUid?.toString() ?? '') ??
            CallService.agoraUidForUserId(userId);
    final levels = state.audioLevels;

    // Mapeamento exato: cada anel verde deve responder apenas ao UID do
    // participante correspondente. O fallback antigo usava o maior volume global
    // quando o UID não batia, fazendo todos os avatares parecerem estar falando.
    final matchedLevel = levels[agoraUid];
    if (matchedLevel != null) {
      return (matchedLevel / 255.0).clamp(0.0, 1.0);
    }

    // Em alguns callbacks do Agora o usuário local pode chegar como UID 0.
    // Esse fallback é restrito ao próprio usuário, então não contamina os demais
    // participantes do palco.
    if (userId == SupabaseService.currentUserId && levels.containsKey(0)) {
      return (levels[0]! / 255.0).clamp(0.0, 1.0);
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

// ============================================================================
// activeScreeningSessionProvider — busca a sessão de projeção ativa do thread.
// Usado para animar o ícone de projeção no AppBar quando há sala ativa.
// ============================================================================
final activeScreeningSessionProvider =
    FutureProvider.family<CallSession?, String>((ref, threadId) async {
  try {
    return await CallService.getActiveCallForThread(
      threadId,
      allowedTypes: {CallType.screeningRoom},
    );
  } catch (_) {
    return null;
  }
});
