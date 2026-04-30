import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/call_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/models/message_model.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/mini_room_overlay.dart';
import '../../moderation/widgets/report_dialog.dart';
import '../widgets/chat_message_actions.dart';

// ============================================================================
// CallScreen — Tela de chamada reformada.
//
// Layout:
//   • Modo padrão (split): grade de participantes (60%) + chat de texto (40%)
//   • Modo tela cheia: grade ocupa 100% da tela, chat oculto
//
// Roles (via CallService.myStageRole):
//   • host    — controles completos (mutar, expulsar, encerrar)
//   • speaker — mic ativo, pode descer do palco
//   • listener — mic silenciado, pode levantar a mão
//
// Chat:
//   • Mensagens salvas no histórico do thread (RPC send_chat_message_with_reputation)
//   • Stream Realtime via RealtimeService
// ============================================================================

class CallScreen extends ConsumerStatefulWidget {
  final CallSession session;

  const CallScreen({super.key, required this.session});

  static Future<void> show(BuildContext context, CallSession session) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CallScreen(session: session),
      ),
    );
  }

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen>
    with TickerProviderStateMixin {
  // ── Participantes ──
  List<Map<String, dynamic>> _participants = [];
  Set<int> _remoteUsers = {};
  Map<int, double> _audioLevels = {};
  StageRole _myRole = StageRole.speaker;
  Set<String> _handRaisedUsers = {};
  bool _handRaised = false;
  int _prevHandRaisedCount = 0;

  // ── Streams ──
  StreamSubscription? _participantsSub;
  StreamSubscription? _remoteUsersSub;
  StreamSubscription? _audioLevelsSub;
  StreamSubscription? _stageRoleSub;
  StreamSubscription? _handRaisedSub;

  // ── Estado local ──
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isFullScreen = false;
  bool _controlsVisible = true;
  Timer? _controlsTimer;

  // ── Timer de duração ──
  late DateTime _startTime;
  Timer? _durationTimer;
  String _elapsed = '00:00';

  // ── Chat ──
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();
  final List<MessageModel> _messages = [];
  bool _isSendingMessage = false;
  String? _chatChannelName;

  // ── Animação split ↔ tela cheia ──
  late AnimationController _splitAnimCtrl;
  late Animation<double> _chatFraction;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _isMuted = CallService.isMuted;
    _isSpeakerOn = CallService.isSpeakerOn;
    _myRole = CallService.myStageRole;

    // Animação: chatFraction vai de 0.4 (split) a 0.0 (tela cheia)
    _splitAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _chatFraction = Tween<double>(begin: 0.4, end: 0.0).animate(
      CurvedAnimation(parent: _splitAnimCtrl, curve: Curves.easeInOut),
    );

    // Streams do CallService
    _participantsSub =
        CallService.participantsStream.listen((p) {
      if (mounted) setState(() => _participants = p);
    });
    _remoteUsersSub =
        CallService.remoteUsersStream.listen((u) {
      if (mounted) setState(() => _remoteUsers = u);
    });
    _audioLevelsSub =
        CallService.audioLevelsStream.listen((l) {
      if (mounted) setState(() => _audioLevels = l);
    });
    _stageRoleSub = CallService.stageRoleStream.listen((role) {
      if (mounted) setState(() => _myRole = role);
    });
    _handRaisedSub =
        CallService.handRaisedUsersStream.listen((raised) {
      if (!mounted) return;
      // Notificar o host quando alguém novo levantar a mão
      if (_myRole == StageRole.host &&
          raised.length > _prevHandRaisedCount) {
        final newCount = raised.length - _prevHandRaisedCount;
        HapticService.action();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('\u270b',
                    style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    newCount == 1
                        ? '1 pessoa quer falar — toque no chip para aceitar'
                        : '$newCount pessoas querem falar',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF9C27B0),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      _prevHandRaisedCount = raised.length;
      setState(() => _handRaisedUsers = raised);
    });

    // Timer de duração
    _durationTimer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final diff = DateTime.now().difference(_startTime);
      setState(() {
        _elapsed =
            '${diff.inMinutes.toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
      });
    });

    _loadParticipants();
    _loadMessages();
    _subscribeChatRealtime();
  }

  @override
  void dispose() {
    _participantsSub?.cancel();
    _remoteUsersSub?.cancel();
    _audioLevelsSub?.cancel();
    _stageRoleSub?.cancel();
    _handRaisedSub?.cancel();
    _durationTimer?.cancel();
    _controlsTimer?.cancel();
    _chatController.dispose();
    _chatScrollController.dispose();
    _splitAnimCtrl.dispose();
    if (_chatChannelName != null) {
      RealtimeService.instance.unsubscribe(_chatChannelName!);
    }
    super.dispose();
  }

  // ── Participantes ──────────────────────────────────────────────────────────

  Future<void> _loadParticipants() async {
    // CallService.getParticipants() já aplica local_icon_url/local_nickname
    // via CallSession.communityId — sem query extra aqui.
    final p = await CallService.getParticipants();
    if (!mounted) return;
    setState(() => _participants = p);
  }

  List<Map<String, dynamic>> get _speakers => _participants
      .where((p) =>
          p['stage_role'] == 'host' ||
          p['stage_role'] == 'speaker' ||
          p['stage_role'] == null) // retrocompatibilidade
      .toList();

  List<Map<String, dynamic>> get _listeners =>
      _participants.where((p) => p['stage_role'] == 'listener').toList();

  // ── Chat ───────────────────────────────────────────────────────────────────



  Future<void> _loadMessages() async {
    try {
      final res = await SupabaseService.table('chat_messages')
          .select(
              '*, profiles!chat_messages_author_id_fkey(id, nickname, icon_url)')
          .eq('thread_id', widget.session.threadId)
          .order('created_at', ascending: false)
          .limit(50);
      final raw = List<Map<String, dynamic>>.from(res as List? ?? []);
      // Enriquecer perfis com identidade local em batch via CallSession.communityId
      final communityId = widget.session.communityId;
      Map<String, Map<String, dynamic>> memberCache = {};
      if (communityId != null && communityId.isNotEmpty) {
        final authorIds = raw
            .map((e) => (e['author_id'] as String?) ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        if (authorIds.isNotEmpty) {
          try {
            final membershipsRes = await SupabaseService.table('community_members')
                .select('user_id, local_nickname, local_icon_url')
                .eq('community_id', communityId)
                .inFilter('user_id', authorIds);
            for (final m in List<Map<String, dynamic>>.from(
                membershipsRes as List? ?? [])) {
              final uid = m['user_id'] as String?;
              if (uid != null) memberCache[uid] = Map<String, dynamic>.from(m);
            }
          } catch (_) {}
        }
      }
      final normalized = raw.map((e) {
        final map = Map<String, dynamic>.from(e);
        final authorId = (map['author_id'] as String?) ?? '';
        if (map['profiles'] != null) {
          final profile = Map<String, dynamic>.from(map['profiles'] as Map);
          final membership = memberCache[authorId];
          if (membership != null) {
            final localNick = (membership['local_nickname'] as String?)?.trim();
            final localIcon = (membership['local_icon_url'] as String?)?.trim();
            if (localNick != null && localNick.isNotEmpty) profile['nickname'] = localNick;
            if (localIcon != null && localIcon.isNotEmpty) profile['icon_url'] = localIcon;
          }
          map['sender'] = profile;
          map['author'] = profile;
          map['profiles'] = profile;
        }
        return MessageModel.fromJson(map);
      }).toList().reversed.toList();
      if (mounted) {
        setState(() => _messages
          ..clear()
          ..addAll(normalized));
        _scrollChatToBottom();
      }
    } catch (e) {
      debugPrint('[CallScreen] loadMessages error: $e');
    }
  }

  void _subscribeChatRealtime() {
    _chatChannelName = 'call_chat:${widget.session.threadId}';
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
            value: widget.session.threadId,
          ),
          callback: (payload) async {
            final newRow = payload.newRecord;
            if (newRow.isEmpty) return;
            final authorId = newRow['author_id'] as String?;
            Map<String, dynamic>? profile;
            if (authorId != null) {
              try {
                final res = await SupabaseService.table('profiles')
                    .select('id, nickname, icon_url')
                    .eq('id', authorId)
                    .single();
                profile = Map<String, dynamic>.from(res);
              } catch (_) {}
            }
            // Aplicar identidade local via CallSession.communityId
            if (authorId != null && profile != null) {
              final communityId = widget.session.communityId;
              if (communityId != null && communityId.isNotEmpty) {
                try {
                  final membership = await SupabaseService.table('community_members')
                      .select('local_nickname, local_icon_url')
                      .eq('community_id', communityId)
                      .eq('user_id', authorId)
                      .maybeSingle();
                  if (membership != null) {
                    final localNick = (membership['local_nickname'] as String?)?.trim();
                    final localIcon = (membership['local_icon_url'] as String?)?.trim();
                    if (localNick != null && localNick.isNotEmpty) profile!['nickname'] = localNick;
                    if (localIcon != null && localIcon.isNotEmpty) profile!['icon_url'] = localIcon;
                  }
                } catch (_) {}
              }
            }
            final map = Map<String, dynamic>.from(newRow);
            if (profile != null) {
              map['profiles'] = profile;
              map['sender'] = profile;
              map['author'] = profile;
            }
            final msg = MessageModel.fromJson(map);
            if (mounted) {
              setState(() => _messages.add(msg));
              _scrollChatToBottom();
            }
          },
        );
      },
    );
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isSendingMessage) return;
    setState(() => _isSendingMessage = true);
    _chatController.clear();
    HapticService.action();
    try {
      await SupabaseService.rpc(
          'send_chat_message_with_reputation',
          params: {
            'p_thread_id': widget.session.threadId,
            'p_content': text,
            'p_type': 'text',
          });
    } catch (e) {
      debugPrint('[CallScreen] sendChatMessage error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Erro ao enviar mensagem'),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  // ── Message Actions ────────────────────────────────────────────────────────

  Future<void> _showMessageActions(MessageModel message) async {
    final userId = SupabaseService.currentUserId;
    final currentUser = ref.read(currentUserProvider);
    final myStageRole = _myParticipant?['stage_role'] as String? ?? 'listener';
    final canModerate = myStageRole == 'host' ||
        myStageRole == 'co_host' ||
        (currentUser?.isTeamMember ?? false);
    final action = await ChatMessageActionsSheet.show(
      context,
      message: message,
      onReaction: (_) {}, // reações não disponíveis na call
      canModerate: canModerate,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ChatMessageAction.reply:
        // reply não disponível na call — sem campo de resposta
        break;
      case ChatMessageAction.copy:
        Clipboard.setData(ClipboardData(text: message.content ?? ''));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Mensagem copiada'),
          backgroundColor: context.nexusTheme.accentPrimary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
        break;
      case ChatMessageAction.edit:
        // edição não disponível na call
        break;
      case ChatMessageAction.forward:
        // encaminhar não disponível na call
        break;
      case ChatMessageAction.pin:
        // fixar não disponível na call
        break;
      case ChatMessageAction.deleteForMe:
        try {
          await SupabaseService.rpc('delete_chat_message_for_me',
              params: {'p_message_id': message.id});
          if (mounted) setState(() => _messages.remove(message));
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Erro ao apagar mensagem'),
              backgroundColor: context.nexusTheme.error,
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
        break;
      case ChatMessageAction.deleteForAll:
        try {
          await SupabaseService.rpc('delete_chat_message_for_all',
              params: {'p_message_id': message.id});
          if (mounted) setState(() => _messages.remove(message));
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Erro ao apagar mensagem'),
              backgroundColor: context.nexusTheme.error,
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
        break;
      case ChatMessageAction.report:
        if (mounted) {
          await ReportDialog.show(
            context,
            communityId: widget.session.communityId,
            targetMessageId: message.id,
          );
        }
        break;
      case ChatMessageAction.moderate:
        if (!mounted) break;
        final authorNickname =
            message.author?.nickname ?? message.authorId ?? 'Usuário';
        final modAction = await ModerationQuickSheet.show(
          context,
          targetUserId: message.authorId ?? '',
          targetUserNickname: authorNickname,
          messageId: message.id,
          communityId: widget.session.communityId,
        );
        if (!mounted || modAction == null) break;
        if (modAction == ModerationQuickAction.deleteMessage) {
          try {
            await SupabaseService.rpc('delete_chat_message_for_all',
                params: {'p_message_id': message.id});
            if (mounted) setState(() => _messages.remove(message));
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Erro ao remover mensagem'),
                backgroundColor: context.nexusTheme.error,
                behavior: SnackBarBehavior.floating,
              ));
            }
          }
        } else if (widget.session.communityId != null) {
          final actionId = switch (modAction) {
            ModerationQuickAction.warn => 'warn',
            ModerationQuickAction.mute => 'mute',
            ModerationQuickAction.ban => 'ban',
            _ => 'warn',
          };
          if (mounted) {
            context.push(
              '/community/${widget.session.communityId}/mod-action',
              extra: {
                'targetUserId': message.authorId,
                'preselectedAction': actionId,
              },
            );
          }
        }
        break;
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Controles ──────────────────────────────────────────────────────────────

  void _scheduleHideControls() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isFullScreen) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _onTapScreen() {
    if (_isFullScreen) {
      setState(() => _controlsVisible = !_controlsVisible);
      if (_controlsVisible) _scheduleHideControls();
    }
  }

  Future<void> _toggleMute() async {
    HapticService.micOn();
    await CallService.toggleMute();
    if (!mounted) return;
    setState(() => _isMuted = CallService.isMuted);
  }

  Future<void> _toggleSpeaker() async {
    HapticService.buttonPress();
    await CallService.toggleSpeaker();
    if (!mounted) return;
    setState(() => _isSpeakerOn = CallService.isSpeakerOn);
  }

  Future<void> _toggleHandRaise() async {
    HapticService.handRaise();
    final newState = !_handRaised;
    setState(() => _handRaised = newState);
    await CallService.raiseHand(raised: newState);
  }

  Future<void> _stepDown() async {
    HapticService.action();
    await CallService.stepDown();
  }

   /// Minimiza a chamada para o PiP flutuante sem encerrar a sessão.
  void _minimizeToMiniRoom() {
    HapticService.tap();
    final session = widget.session;
    ref.read(miniRoomProvider.notifier).show(
      roomId: session.id,
      title: session.type == CallType.screeningRoom
          ? 'Sala de Projeção'
          : 'Voice Chat',
      type: session.type == CallType.screeningRoom
          ? MiniRoomType.screening
          : MiniRoomType.voiceChat,
      isMuted: _isMuted,
      participantCount: _participants.length,
      onReturn: () {
        // Reabrir o CallScreen ao tocar no PiP
        ref.read(miniRoomProvider.notifier).hide();
        CallScreen.show(context, session);
      },
      onEnd: () {
        // Encerrar a sessão pelo PiP
        CallService.leaveCall();
      },
      onToggleMute: () {
        CallService.toggleMute();
        ref.read(miniRoomProvider.notifier).updateMute(CallService.isMuted);
      },
    );
    Navigator.of(context).pop();
  }

  Future<void> _leaveCall() async {
    HapticService.action();
    // Esconder PiP se estiver ativo (saída definitiva)
    ref.read(miniRoomProvider.notifier).hide();
    await CallService.leaveCall();
    if (!mounted) return;
    Navigator.of(context).pop();
  }
  Future<void> _endCall() async {
    HapticService.error();
    // Esconder PiP se estiver ativo (encerramento definitivo)
    ref.read(miniRoomProvider.notifier).hide();
    await CallService.endCall();
    // Enviar mensagem de sistema informando o encerramento da chamada
    try {
      final nickname =
          ref.read(currentUserProvider)?.nickname ?? 'Alguém';
      await SupabaseService.rpc(
        'send_chat_message_with_reputation',
        params: {
          'p_thread_id': widget.session.threadId,
          'p_content': '$nickname encerrou o Voice Chat',
          'p_type': 'system_voice_end',
        },
      );
    } catch (e) {
      debugPrint('[CallScreen] Erro ao enviar system_voice_end: $e');
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _toggleFullScreen() {
    HapticService.tap();
    setState(() {
      _isFullScreen = !_isFullScreen;
      _controlsVisible = true;
    });
    if (_isFullScreen) {
      _splitAnimCtrl.forward();
      _scheduleHideControls();
    } else {
      _splitAnimCtrl.reverse();
      _controlsTimer?.cancel();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = context.nexusTheme;
    final isScreening =
        widget.session.type == CallType.screeningRoom;

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: _onTapScreen,
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              _buildHeader(isScreening),

              // ── Grade + Chat (animados) ──
              Expanded(
                child: AnimatedBuilder(
                  animation: _chatFraction,
                  builder: (context, _) {
                    final chatF = _chatFraction.value;
                    final gridF = 1.0 - chatF;
                    return Column(
                      children: [
                        Expanded(
                          flex: (gridF * 100).round().clamp(1, 100),
                          child: _buildParticipantsGrid(),
                        ),
                        if (chatF > 0.01)
                          Expanded(
                            flex: (chatF * 100).round().clamp(1, 100),
                            child: _buildChatPanel(),
                          ),
                      ],
                    );
                  },
                ),
              ),

              // ── Controles ──
              AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: _buildControls(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isScreening) {
    final r = context.r;
    final theme = context.nexusTheme;
    final title = isScreening ? 'Sala de Projeção' : 'Voice Chat';

    return AnimatedOpacity(
      opacity: _controlsVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(8), vertical: r.s(8)),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: theme.textPrimary, size: r.s(22)),
              onPressed: _minimizeToMiniRoom,
              tooltip: 'Minimizar (continuar em segundo plano)',
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: r.fs(16),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: r.s(7),
                        height: r.s(7),
                        decoration: BoxDecoration(
                          color: theme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: r.s(4)),
                      Text(
                        _elapsed,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: r.fs(12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: r.s(8)),
                      Text(
                        '${_participants.length} participante${_participants.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: r.fs(12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Botão tela cheia / split
            IconButton(
              icon: Icon(
                _isFullScreen
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                color: theme.textSecondary,
                size: r.s(22),
              ),
              onPressed: _toggleFullScreen,
              tooltip: _isFullScreen ? 'Modo split' : 'Tela cheia',
            ),
          ],
        ),
      ),
    );
  }

  // ── Grade de participantes ─────────────────────────────────────────────────

  Widget _buildParticipantsGrid() {
    final r = context.r;
    final theme = context.nexusTheme;
    final speakers = _speakers;
    final listeners = _listeners;

    if (_participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                color: theme.accentPrimary),
            SizedBox(height: r.s(12)),
            Text('Aguardando participantes...',
                style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: r.fs(13))),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: r.s(12), vertical: r.s(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Speakers / Host ──
          if (speakers.isNotEmpty) ...[
            _SectionLabel(
              icon: Icons.mic_rounded,
              label: 'No palco (${speakers.length})',
              color: theme.accentPrimary,
            ),
            SizedBox(height: r.s(8)),
            _buildSpeakersGrid(speakers),
          ],

          // ── Listeners ──
          if (listeners.isNotEmpty) ...[
            SizedBox(height: r.s(12)),
            _SectionLabel(
              icon: Icons.headphones_rounded,
              label: 'Ouvindo (${listeners.length})',
              color: theme.textSecondary,
            ),
            SizedBox(height: r.s(8)),
            _buildListenersWrap(listeners),
          ],

          SizedBox(height: r.s(8)),
        ],
      ),
    );
  }

  Widget _buildSpeakersGrid(List<Map<String, dynamic>> speakers) {
    final r = context.r;
    final crossAxisCount = speakers.length <= 2 ? 2 : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: r.s(8),
        mainAxisSpacing: r.s(8),
        childAspectRatio: 0.95,
      ),
      itemCount: speakers.length,
      itemBuilder: (context, i) => _SpeakerCard(
        participant: speakers[i],
        audioLevel: _getAudioLevel(speakers[i]),
        isMe: _isMe(speakers[i]),
        myRole: _myRole,
        onMute: (uid) => CallService.muteParticipant(uid),
        onKick: (uid) => CallService.kickParticipant(uid),
      ),
    );
  }

  Widget _buildListenersWrap(
      List<Map<String, dynamic>> listeners) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: listeners
          .map((p) => _ListenerChip(
                participant: p,
                hasHandRaised: _handRaisedUsers
                    .contains(p['user_id'] as String? ?? ''),
                isMe: _isMe(p),
                myRole: _myRole,
                onAcceptSpeaker: (uid) async {
                  HapticService.promoted();
                  await CallService.acceptSpeaker(uid);
                },
              ))
          .toList(),
    );
  }

  double _getAudioLevel(Map<String, dynamic> participant) {
    final agoraUid = participant['agora_uid'] as int?;
    if (agoraUid != null && _audioLevels.containsKey(agoraUid)) {
      return (_audioLevels[agoraUid]! / 255.0).clamp(0.0, 1.0);
    }
    if (_audioLevels.isNotEmpty) {
      final maxLevel =
          _audioLevels.values.reduce((a, b) => a > b ? a : b);
      return (maxLevel / 255.0).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  bool _isMe(Map<String, dynamic> participant) =>
      participant['user_id'] == SupabaseService.currentUserId;

  // ── Chat Panel ─────────────────────────────────────────────────────────────

  Widget _buildChatPanel() {
    final r = context.r;
    final theme = context.nexusTheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.surfacePrimary,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Título
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: r.s(12), vertical: r.s(6)),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    color: theme.textSecondary, size: r.s(14)),
                SizedBox(width: r.s(6)),
                Text(
                  'Chat da sala',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Mensagens
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'Nenhuma mensagem ainda.\nDiga olá! 👋',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textHint,
                        fontSize: r.fs(13),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(10), vertical: r.s(4)),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) =>
                        _ChatBubble(
                          message: _messages[i],
                          onLongPress: _showMessageActions,
                        ),
                  ),
          ),

          // Input
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    final r = context.r;
    final theme = context.nexusTheme;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.s(12), vertical: r.s(8)),
      decoration: BoxDecoration(
        color: theme.backgroundSecondary,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              style: TextStyle(
                  color: theme.textPrimary, fontSize: r.fs(14)),
              decoration: InputDecoration(
                hintText: 'Mensagem...',
                hintStyle: TextStyle(
                    color: theme.textHint, fontSize: r.fs(14)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: r.s(4), vertical: r.s(6)),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendChatMessage(),
              maxLines: 1,
            ),
          ),
          SizedBox(width: r.s(8)),
          GestureDetector(
            onTap: _sendChatMessage,
            child: Container(
              width: r.s(36),
              height: r.s(36),
              decoration: BoxDecoration(
                color: theme.accentPrimary,
                shape: BoxShape.circle,
              ),
              child: _isSendingMessage
                  ? Padding(
                      padding: EdgeInsets.all(r.s(10)),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.send_rounded,
                      color: Colors.white, size: r.s(18)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Controles ──────────────────────────────────────────────────────────────

  Widget _buildControls() {
    final r = context.r;
    final theme = context.nexusTheme;
    final isHost = _myRole.isHost;
    final canSpeak = _myRole.canSpeak;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.s(16), vertical: r.s(12)),
      decoration: BoxDecoration(
        color: theme.backgroundSecondary.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute (speakers/host)
          if (canSpeak)
            _ControlButton(
              icon: _isMuted
                  ? Icons.mic_off_rounded
                  : Icons.mic_rounded,
              label: _isMuted ? 'Mudo' : 'Mic',
              isActive: !_isMuted,
              onTap: _toggleMute,
            ),

          // Levantar mão (listeners)
          if (!canSpeak)
            _ControlButton(
              icon: _handRaised
                  ? Icons.back_hand_rounded
                  : Icons.back_hand_outlined,
              label: _handRaised ? 'Abaixar' : 'Mão',
              isActive: _handRaised,
              onTap: _toggleHandRaise,
            ),

          // Alto-falante
          _ControlButton(
            icon: _isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            label: 'Alto-falante',
            isActive: _isSpeakerOn,
            onTap: _toggleSpeaker,
          ),

          // Descer do palco (speakers não-host)
          if (_myRole == StageRole.speaker)
            _ControlButton(
              icon: Icons.arrow_downward_rounded,
              label: 'Descer',
              isActive: false,
              onTap: _stepDown,
            ),

          // Encerrar (host) ou Sair (outros)
          _ControlButton(
            icon: isHost
                ? Icons.call_end_rounded
                : Icons.exit_to_app_rounded,
            label: isHost ? 'Encerrar' : 'Sair',
            isActive: false,
            isEnd: true,
            onTap: isHost ? _endCall : _leaveCall,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _SectionLabel
// ============================================================================

class _SectionLabel extends ConsumerWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return Row(
      children: [
        Icon(icon, color: color, size: r.s(14)),
        SizedBox(width: r.s(4)),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: r.fs(12),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// _SpeakerCard — Card grande para speakers/host no palco
// ============================================================================

class _SpeakerCard extends ConsumerWidget {
  final Map<String, dynamic> participant;
  final double audioLevel;
  final bool isMe;
  final StageRole myRole;
  final Future<bool> Function(String) onMute;
  final Future<bool> Function(String) onKick;

  const _SpeakerCard({
    required this.participant,
    required this.audioLevel,
    required this.isMe,
    required this.myRole,
    required this.onMute,
    required this.onKick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;
    final profile =
        participant['profiles'] as Map<String, dynamic>?;
    final userId = participant['user_id'] as String? ?? '';
    final nickname =
        profile?['nickname'] as String? ?? 'Usuário';
    final iconUrl = profile?['icon_url'] as String?;
    final isMuted = participant['is_muted'] as bool? ?? false;
    final isHost = participant['stage_role'] == 'host';
    final isSpeaking = audioLevel > 0.15;

    return GestureDetector(
      onLongPress: () {
        if (myRole.isHost && !isMe) {
          _showHostActions(context, userId, nickname, isMuted);
        }
      },
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar com anel de fala
            Stack(
              alignment: Alignment.center,
              children: [
                // Anel verde pulsante quando falando
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: r.s(isSpeaking ? 70 : 60),
                  height: r.s(isSpeaking ? 70 : 60),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSpeaking
                        ? Border.all(
                            color: theme.success,
                            width: 2.5,
                          )
                        : null,
                    boxShadow: isSpeaking
                        ? [
                            BoxShadow(
                              color: theme.success.withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                ),
                CosmeticAvatar(
                  userId: userId,
                  avatarUrl: iconUrl,
                  size: r.s(56),
                ),
                if (isMuted)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(r.s(3)),
                      decoration: BoxDecoration(
                        color: theme.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: theme.surfacePrimary,
                            width: 1.5),
                      ),
                      child: Icon(Icons.mic_off_rounded,
                          color: Colors.white, size: r.s(10)),
                    ),
                  ),
              ],
            ),
            SizedBox(height: r.s(8)),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(6)),
              child: Text(
                isMe ? '$nickname (você)' : nickname,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: r.s(4)),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(8), vertical: r.s(2)),
              decoration: BoxDecoration(
                color: isHost
                    ? theme.accentPrimary.withValues(alpha: 0.15)
                    : theme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(r.s(20)),
              ),
              child: Text(
                isHost ? '👑 Host' : '🎙️ Speaker',
                style: TextStyle(
                  color: isHost
                      ? theme.accentPrimary
                      : theme.success,
                  fontSize: r.fs(10),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!isMuted && isSpeaking) ...[
              SizedBox(height: r.s(6)),
              _AudioLevelBar(level: audioLevel),
            ],
          ],
        ),
    );
  }
  void _showHostActions(BuildContext context, String userId,
      String nickname, bool isMuted) {
    final theme = context.nexusTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.modalBackground,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isMuted
                    ? Icons.mic_rounded
                    : Icons.mic_off_rounded,
                color: theme.textPrimary,
              ),
              title: Text(
                isMuted ? 'Desmutar' : 'Mutar',
                style: TextStyle(color: theme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                onMute(userId);
              },
            ),
            ListTile(
              leading: Icon(Icons.person_remove_rounded,
                  color: theme.error),
              title: Text('Expulsar $nickname',
                  style: TextStyle(color: theme.error)),
              onTap: () {
                Navigator.pop(context);
                onKick(userId);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// _ListenerChip — Chip compacto para listeners na plateia
// ============================================================================

class _ListenerChip extends ConsumerWidget {
  final Map<String, dynamic> participant;
  final bool hasHandRaised;
  final bool isMe;
  final StageRole myRole;
  final Future<void> Function(String) onAcceptSpeaker;

  const _ListenerChip({
    required this.participant,
    required this.hasHandRaised,
    required this.isMe,
    required this.myRole,
    required this.onAcceptSpeaker,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;
    final profile =
        participant['profiles'] as Map<String, dynamic>?;
    final userId = participant['user_id'] as String? ?? '';
    final nickname =
        profile?['nickname'] as String? ?? 'Usuário';
    final iconUrl = profile?['icon_url'] as String?;

    return GestureDetector(
      onTap: () {
        if (myRole.isHost && hasHandRaised) {
          onAcceptSpeaker(userId);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(10), vertical: r.s(6)),
        decoration: BoxDecoration(
          color: hasHandRaised
              ? theme.accentPrimary.withValues(alpha: 0.12)
              : theme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(20)),
          border: Border.all(
            color: hasHandRaised
                ? theme.accentPrimary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CosmeticAvatar(
              userId: userId,
              avatarUrl: iconUrl,
              size: r.s(28),
            ),
            SizedBox(width: r.s(6)),
            Text(
              isMe ? '$nickname (você)' : nickname,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: r.fs(12),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasHandRaised) ...[
              SizedBox(width: r.s(4)),
              Text('✋',
                  style: TextStyle(fontSize: r.fs(14))),
              if (myRole.isHost) ...[
                SizedBox(width: r.s(4)),
                Icon(Icons.check_circle_rounded,
                    color: theme.success, size: r.s(16)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// _ChatBubble — Bolha de mensagem no chat da sala
// ============================================================================

class _ChatBubble extends ConsumerWidget {
  final MessageModel message;
  final Future<void> Function(MessageModel)? onLongPress;

  const _ChatBubble({required this.message, this.onLongPress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;
    final isMe =
        message.authorId == SupabaseService.currentUserId;
    final nickname = message.author?.nickname ?? 'Usuário';
    final iconUrl = message.author?.iconUrl;

    return GestureDetector(
      onLongPress: onLongPress != null ? () => onLongPress!(message) : null,
      child: Padding(
      padding: EdgeInsets.only(bottom: r.s(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CosmeticAvatar(
              userId: message.authorId,
              avatarUrl: iconUrl,
              size: r.s(28),
            ),
            SizedBox(width: r.s(6)),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: EdgeInsets.only(bottom: r.s(2)),
                    child: Text(
                      nickname,
                      style: TextStyle(
                        color: theme.accentPrimary,
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(10), vertical: r.s(6)),
                  decoration: BoxDecoration(
                    color: isMe
                        ? theme.accentPrimary
                            .withValues(alpha: 0.85)
                        : theme.surfaceSecondary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(r.s(12)),
                      topRight: Radius.circular(r.s(12)),
                      bottomLeft: Radius.circular(
                          isMe ? r.s(12) : r.s(2)),
                      bottomRight: Radius.circular(
                          isMe ? r.s(2) : r.s(12)),
                    ),
                  ),
                  child: Text(
                    message.content ?? '',
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : theme.textPrimary,
                      fontSize: r.fs(13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[SizedBox(width: r.s(6)), CosmeticAvatar(userId: message.authorId, avatarUrl: iconUrl, size: r.s(28))],
        ],
      ),
    ),
    );
  }
}

// ============================================================================
// _AudioLevelBar — Barras animadas de nível de áudio
// ============================================================================

class _AudioLevelBar extends ConsumerWidget {
  final double level; // 0.0 a 1.0

  const _AudioLevelBar({required this.level});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final threshold = (i + 1) / 5;
        final isActive = level >= threshold;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: r.s(3),
          height: r.s(4.0 + (i * 3).toDouble()),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isActive
                ? theme.success
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

// ============================================================================
// _ControlButton — Botão de controle circular
// ============================================================================

class _ControlButton extends ConsumerWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isEnd;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.isEnd = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: r.s(52),
            height: r.s(52),
            decoration: BoxDecoration(
              color: isEnd
                  ? theme.error
                  : isActive
                      ? theme.accentPrimary
                          .withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: isEnd
                    ? Colors.transparent
                    : isActive
                        ? theme.accentPrimary
                            .withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isEnd
                  ? Colors.white
                  : isActive
                      ? theme.accentPrimary
                      : Colors.grey[500],
              size: r.s(22),
            ),
          ),
          SizedBox(height: r.s(5)),
          Text(
            label,
            style: TextStyle(
              color:
                  isEnd ? theme.error : Colors.grey[500],
              fontSize: r.fs(10),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
