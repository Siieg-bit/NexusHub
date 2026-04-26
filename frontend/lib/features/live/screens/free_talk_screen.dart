import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/call_service.dart';
import '../../../core/utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ============================================================================
// FreeTalkScreen — Sala de Voz estilo "palco" inspirada no OluOlu
//
// Arquitetura de 3 camadas:
//   • Sinalização: Supabase Realtime (voice_room_members)
//   • Mídia: Agora.io RTC (já integrado no NexusHub)
//   • Estado: Riverpod (FreeTalkNotifier)
//
// Roles: host > speaker > listener
// Fluxo: listener levanta a mão → host aceita → listener vira speaker
// ============================================================================

// ─── Modelo de membro ────────────────────────────────────────────────────────
class VoiceRoomMember {
  final String userId;
  final String role; // 'host' | 'speaker' | 'listener'
  final bool isMuted;
  final bool handRaised;
  final String nickname;
  final String? iconUrl;
  final bool isSpeaking;

  const VoiceRoomMember({
    required this.userId,
    required this.role,
    required this.isMuted,
    required this.handRaised,
    required this.nickname,
    this.iconUrl,
    this.isSpeaking = false,
  });

  VoiceRoomMember copyWith({
    String? role,
    bool? isMuted,
    bool? handRaised,
    bool? isSpeaking,
  }) {
    return VoiceRoomMember(
      userId: userId,
      role: role ?? this.role,
      isMuted: isMuted ?? this.isMuted,
      handRaised: handRaised ?? this.handRaised,
      nickname: nickname,
      iconUrl: iconUrl,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }

  bool get isOnStage => role == 'host' || role == 'speaker';
}

// ─── State do FreeTalk ───────────────────────────────────────────────────────
class FreeTalkState {
  final String roomId;
  final String title;
  final String hostId;
  final List<VoiceRoomMember> members;
  final bool isLoading;
  final bool isMuted;
  final String myRole;
  final bool myHandRaised;
  final String? errorMessage;

  const FreeTalkState({
    required this.roomId,
    required this.title,
    required this.hostId,
    this.members = const [],
    this.isLoading = true,
    this.isMuted = true,
    this.myRole = 'listener',
    this.myHandRaised = false,
    this.errorMessage,
  });

  List<VoiceRoomMember> get speakers =>
      members.where((m) => m.isOnStage).toList();

  List<VoiceRoomMember> get listeners =>
      members.where((m) => m.role == 'listener').toList();

  List<VoiceRoomMember> get handRaisedListeners =>
      listeners.where((m) => m.handRaised).toList();

  bool get isHost => myRole == 'host';
  bool get isSpeaker => myRole == 'speaker';
  bool get isListener => myRole == 'listener';
  bool get isOnStage => isHost || isSpeaker;

  FreeTalkState copyWith({
    List<VoiceRoomMember>? members,
    bool? isLoading,
    bool? isMuted,
    String? myRole,
    bool? myHandRaised,
    String? errorMessage,
  }) {
    return FreeTalkState(
      roomId: roomId,
      title: title,
      hostId: hostId,
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
      isMuted: isMuted ?? this.isMuted,
      myRole: myRole ?? this.myRole,
      myHandRaised: myHandRaised ?? this.myHandRaised,
      errorMessage: errorMessage,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────
class FreeTalkNotifier extends StateNotifier<FreeTalkState> {
  final String roomId;
  StreamSubscription? _realtimeSub;
  StreamSubscription? _audioLevelsSub;
  Set<int> _speakingUids = {};

  FreeTalkNotifier({
    required this.roomId,
    required String title,
    required String hostId,
    required String initialRole,
  }) : super(FreeTalkState(
          roomId: roomId,
          title: title,
          hostId: hostId,
          myRole: initialRole,
          isMuted: initialRole == 'listener',
        ));

  Future<void> initialize() async {
    await _loadMembers();
    _subscribeRealtime();
    _subscribeAudioLevels();
  }

  Future<void> _loadMembers() async {
    try {
      final data = await SupabaseService.rpc(
        'get_voice_room_members',
        params: {'p_room_id': roomId},
      );
      final list = (data as List? ?? [])
          .map((m) => _memberFromJson(m as Map<String, dynamic>))
          .toList();
      final myId = SupabaseService.currentUserId ?? '';
      final myMember = list.firstWhere(
        (m) => m.userId == myId,
        orElse: () => VoiceRoomMember(
          userId: myId,
          role: state.myRole,
          isMuted: state.isMuted,
          handRaised: false,
          nickname: '',
        ),
      );
      state = state.copyWith(
        members: list,
        myRole: myMember.role,
        myHandRaised: myMember.handRaised,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void _subscribeRealtime() {
    _realtimeSub = SupabaseService.client
        .from('voice_room_members')
        .stream(primaryKey: ['room_id', 'user_id'])
        .eq('room_id', roomId)
        .listen((rows) {
          final myId = SupabaseService.currentUserId ?? '';
          final list = rows
              .map((r) => _memberFromJson(r))
              .toList();
          final myMember = list.firstWhere(
            (m) => m.userId == myId,
            orElse: () => VoiceRoomMember(
              userId: myId,
              role: state.myRole,
              isMuted: state.isMuted,
              handRaised: false,
              nickname: '',
            ),
          );
          // Preservar isSpeaking dos membros existentes
          final updatedList = list.map((m) {
            final existing = state.members.firstWhere(
              (e) => e.userId == m.userId,
              orElse: () => m,
            );
            return m.copyWith(isSpeaking: existing.isSpeaking);
          }).toList();

          state = state.copyWith(
            members: updatedList,
            myRole: myMember.role,
            myHandRaised: myMember.handRaised,
          );

          // Haptic feedback quando promovido a speaker
          if (myMember.role == 'speaker' && state.myRole == 'listener') {
            HapticFeedback.mediumImpact();
          }
        });
  }

  void _subscribeAudioLevels() {
    _audioLevelsSub = CallService.audioLevelsStream.listen((levels) {
      if (!mounted) return;
      final speakingUids = levels.entries
          .where((e) => e.value > 0.1)
          .map((e) => e.key)
          .toSet();
      if (speakingUids == _speakingUids) return;
      _speakingUids = speakingUids;
      // Mapear UIDs do Agora para user_ids (simplificado: usar índice)
      final updatedMembers = state.members.map((m) {
        final idx = state.members.indexOf(m);
        return m.copyWith(isSpeaking: speakingUids.contains(idx));
      }).toList();
      state = state.copyWith(members: updatedMembers);
    });
  }

  Future<void> toggleMute() async {
    final newMuted = !state.isMuted;
    state = state.copyWith(isMuted: newMuted);
    try {
      await CallService.toggleMute();
      await SupabaseService.rpc(
        'mute_voice_room_member',
        params: {
          'p_room_id': roomId,
          'p_target_user': SupabaseService.currentUserId,
          'p_muted': newMuted,
        },
      );
      if (!newMuted) HapticFeedback.lightImpact();
    } catch (_) {
      state = state.copyWith(isMuted: !newMuted);
    }
  }

  Future<void> raiseHand() async {
    final newRaised = !state.myHandRaised;
    state = state.copyWith(myHandRaised: newRaised);
    HapticFeedback.selectionClick();
    try {
      await SupabaseService.rpc(
        'raise_hand_voice_room',
        params: {'p_room_id': roomId, 'p_raised': newRaised},
      );
    } catch (_) {
      state = state.copyWith(myHandRaised: !newRaised);
    }
  }

  Future<void> acceptSpeaker(String targetUserId) async {
    HapticFeedback.mediumImpact();
    try {
      await SupabaseService.rpc(
        'accept_speaker_request',
        params: {
          'p_room_id': roomId,
          'p_target_user': targetUserId,
        },
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> kickMember(String targetUserId) async {
    try {
      await SupabaseService.rpc(
        'kick_voice_room_member',
        params: {
          'p_room_id': roomId,
          'p_target_user': targetUserId,
        },
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> muteMember(String targetUserId, bool muted) async {
    try {
      await SupabaseService.rpc(
        'mute_voice_room_member',
        params: {
          'p_room_id': roomId,
          'p_target_user': targetUserId,
          'p_muted': muted,
        },
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> stepDown() async {
    try {
      await SupabaseService.rpc(
        'step_down_from_stage',
        params: {'p_room_id': roomId},
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  static VoiceRoomMember _memberFromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? {};
    return VoiceRoomMember(
      userId: json['user_id'] as String? ?? '',
      role: json['role'] as String? ?? 'listener',
      isMuted: json['is_muted'] as bool? ?? true,
      handRaised: json['hand_raised'] as bool? ?? false,
      nickname: profile['nickname'] as String? ?? 'Usuário',
      iconUrl: profile['icon_url'] as String?,
    );
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _audioLevelsSub?.cancel();
    super.dispose();
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────
final freeTalkProvider = StateNotifierProvider.family<
    FreeTalkNotifier, FreeTalkState, Map<String, String>>(
  (ref, params) => FreeTalkNotifier(
    roomId: params['roomId']!,
    title: params['title'] ?? 'Sala de Voz',
    hostId: params['hostId'] ?? '',
    initialRole: params['role'] ?? 'listener',
  ),
);

// ─── Tela principal ───────────────────────────────────────────────────────────
class FreeTalkScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String title;
  final String hostId;
  final String initialRole;

  const FreeTalkScreen({
    super.key,
    required this.roomId,
    required this.title,
    required this.hostId,
    this.initialRole = 'listener',
  });

  static Future<void> show(
    BuildContext context, {
    required String roomId,
    required String title,
    required String hostId,
    String role = 'listener',
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FreeTalkScreen(
          roomId: roomId,
          title: title,
          hostId: hostId,
          initialRole: role,
        ),
      ),
    );
  }

  @override
  ConsumerState<FreeTalkScreen> createState() => _FreeTalkScreenState();
}

class _FreeTalkScreenState extends ConsumerState<FreeTalkScreen> {
  late final Map<String, String> _params;

  @override
  void initState() {
    super.initState();
    _params = {
      'roomId': widget.roomId,
      'title': widget.title,
      'hostId': widget.hostId,
      'role': widget.initialRole,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(freeTalkProvider(_params).notifier).initialize();
    });
  }

  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Sair da sala',
            style: TextStyle(color: context.nexusTheme.textPrimary)),
        content: Text('Deseja sair desta sala de voz?',
            style: TextStyle(color: Colors.grey[400])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.nexusTheme.error,
            ),
            child: const Text('Sair',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await SupabaseService.rpc(
        'leave_voice_room',
        params: {'p_room_id': widget.roomId},
      );
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _endRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Encerrar sala',
            style: TextStyle(color: context.nexusTheme.textPrimary)),
        content: Text(
            'Encerrar a sala para todos os participantes?',
            style: TextStyle(color: Colors.grey[400])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: context.nexusTheme.error),
            child: const Text('Encerrar',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await SupabaseService.rpc(
        'end_voice_room',
        params: {'p_room_id': widget.roomId},
      );
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(freeTalkProvider(_params));
    final notifier = ref.read(freeTalkProvider(_params).notifier);
    final r = context.r;

    return Scaffold(
      backgroundColor: context.surfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _FreeTalkHeader(
              title: state.title,
              memberCount: state.members.length,
              isHost: state.isHost,
              onLeave: _leaveRoom,
              onEnd: _endRoom,
            ),

            // ── Palco (Speakers) ─────────────────────────────────────────────
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: r.s(16)),

                          // Speakers grid
                          _SpeakersStage(
                            speakers: state.speakers,
                            isHost: state.isHost,
                            onSpeakerTap: (member) =>
                                _showSpeakerActions(context, member, state, notifier),
                          ),

                          SizedBox(height: r.s(24)),

                          // Mãos levantadas (apenas para host)
                          if (state.isHost && state.handRaisedListeners.isNotEmpty) ...[
                            _SectionTitle(
                              icon: Icons.back_hand_rounded,
                              label: 'Mãos levantadas (${state.handRaisedListeners.length})',
                              color: const Color(0xFFFF9800),
                            ),
                            SizedBox(height: r.s(8)),
                            _ListenersGrid(
                              listeners: state.handRaisedListeners,
                              isHost: state.isHost,
                              onTap: (member) =>
                                  _showListenerActions(context, member, state, notifier),
                            ),
                            SizedBox(height: r.s(16)),
                          ],

                          // Listeners
                          if (state.listeners.isNotEmpty) ...[
                            _SectionTitle(
                              icon: Icons.headphones_rounded,
                              label: 'Ouvintes (${state.listeners.length})',
                              color: Colors.grey[500]!,
                            ),
                            SizedBox(height: r.s(8)),
                            _ListenersGrid(
                              listeners: state.listeners,
                              isHost: state.isHost,
                              onTap: (member) =>
                                  _showListenerActions(context, member, state, notifier),
                            ),
                            SizedBox(height: r.s(80)),
                          ],
                        ],
                      ),
                    ),
            ),

            // ── Barra de controles ───────────────────────────────────────────
            _FreeTalkControls(
              state: state,
              onToggleMute: notifier.toggleMute,
              onRaiseHand: notifier.raiseHand,
              onStepDown: notifier.stepDown,
              onLeave: _leaveRoom,
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeakerActions(
    BuildContext context,
    VoiceRoomMember member,
    FreeTalkState state,
    FreeTalkNotifier notifier,
  ) {
    final myId = SupabaseService.currentUserId ?? '';
    final isMe = member.userId == myId;
    if (!state.isHost && !isMe) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MemberActionsSheet(
        member: member,
        isHost: state.isHost,
        isMe: isMe,
        onMute: (muted) {
          Navigator.pop(ctx);
          notifier.muteMember(member.userId, muted);
        },
        onKick: () {
          Navigator.pop(ctx);
          notifier.kickMember(member.userId);
        },
        onStepDown: () {
          Navigator.pop(ctx);
          notifier.stepDown();
        },
      ),
    );
  }

  void _showListenerActions(
    BuildContext context,
    VoiceRoomMember member,
    FreeTalkState state,
    FreeTalkNotifier notifier,
  ) {
    if (!state.isHost) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mic_rounded, color: Color(0xFF4CAF50)),
              title: const Text('Convidar para o palco'),
              onTap: () {
                Navigator.pop(ctx);
                notifier.acceptSpeaker(member.userId);
              },
            ),
            ListTile(
              leading: Icon(Icons.person_remove_rounded,
                  color: context.nexusTheme.error),
              title: const Text('Expulsar da sala'),
              onTap: () {
                Navigator.pop(ctx);
                notifier.kickMember(member.userId);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────
class _FreeTalkHeader extends StatelessWidget {
  final String title;
  final int memberCount;
  final bool isHost;
  final VoidCallback onLeave;
  final VoidCallback onEnd;

  const _FreeTalkHeader({
    required this.title,
    required this.memberCount,
    required this.isHost,
    required this.onLeave,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Título e contagem
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: r.s(8),
                      height: r.s(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: r.s(6)),
                    Text(
                      'AO VIVO',
                      style: TextStyle(
                        color: const Color(0xFF4CAF50),
                        fontSize: r.fs(10),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.s(2)),
                Text(
                  title,
                  style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(16),
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$memberCount participantes',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: r.fs(12),
                  ),
                ),
              ],
            ),
          ),
          // Botão encerrar (host) ou sair
          if (isHost)
            TextButton(
              onPressed: onEnd,
              child: Text(
                'Encerrar',
                style: TextStyle(
                  color: context.nexusTheme.error,
                  fontWeight: FontWeight.w700,
                  fontSize: r.fs(14),
                ),
              ),
            )
          else
            TextButton(
              onPressed: onLeave,
              child: Text(
                'Sair',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w600,
                  fontSize: r.fs(14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Palco de Speakers ────────────────────────────────────────────────────────
class _SpeakersStage extends StatelessWidget {
  final List<VoiceRoomMember> speakers;
  final bool isHost;
  final void Function(VoiceRoomMember) onSpeakerTap;

  const _SpeakersStage({
    required this.speakers,
    required this.isHost,
    required this.onSpeakerTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    if (speakers.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: r.s(32)),
          child: Text(
            'Nenhum speaker no palco ainda',
            style: TextStyle(color: Colors.grey[600], fontSize: r.fs(14)),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: speakers.length == 1 ? 1 : 3,
        mainAxisSpacing: r.s(16),
        crossAxisSpacing: r.s(16),
        childAspectRatio: 0.8,
      ),
      itemCount: speakers.length,
      itemBuilder: (context, index) {
        final member = speakers[index];
        return _SpeakerCard(
          member: member,
          onTap: () => onSpeakerTap(member),
        );
      },
    );
  }
}

// ─── Card de Speaker com Halo pulsante ───────────────────────────────────────
class _SpeakerCard extends StatefulWidget {
  final VoiceRoomMember member;
  final VoidCallback onTap;

  const _SpeakerCard({required this.member, required this.onTap});

  @override
  State<_SpeakerCard> createState() => _SpeakerCardState();
}

class _SpeakerCardState extends State<_SpeakerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _haloController;
  late Animation<double> _haloAnimation;

  @override
  void initState() {
    super.initState();
    _haloController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _haloAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _haloController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_SpeakerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.member.isSpeaking && !_haloController.isAnimating) {
      _haloController.repeat(reverse: true);
    } else if (!widget.member.isSpeaking && _haloController.isAnimating) {
      _haloController.stop();
      _haloController.reset();
    }
  }

  @override
  void dispose() {
    _haloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final member = widget.member;
    final avatarSize = r.s(64.0);

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar com halo pulsante
          AnimatedBuilder(
            animation: _haloAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: member.isSpeaking ? _haloAnimation.value : 1.0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Halo verde (apenas quando falando)
                    if (member.isSpeaking)
                      Container(
                        width: avatarSize + r.s(12),
                        height: avatarSize + r.s(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF4CAF50),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    // Avatar
                    CircleAvatar(
                      radius: avatarSize / 2,
                      backgroundColor: context.nexusTheme.accentPrimary
                          .withValues(alpha: 0.2),
                      backgroundImage: member.iconUrl != null
                          ? CachedNetworkImageProvider(member.iconUrl!)
                          : null,
                      child: member.iconUrl == null
                          ? Text(
                              member.nickname.isNotEmpty
                                  ? member.nickname[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: context.nexusTheme.accentPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: r.fs(22),
                              ),
                            )
                          : null,
                    ),
                    // Badge de status (muted / host)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: _StatusBadge(member: member),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: r.s(8)),
          // Nome
          Text(
            member.nickname,
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: r.fs(12),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          // Role badge
          if (member.role == 'host')
            Container(
              margin: EdgeInsets.only(top: r.s(2)),
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(6), vertical: r.s(2)),
              decoration: BoxDecoration(
                color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(r.s(8)),
              ),
              child: Text(
                'Host',
                style: TextStyle(
                  color: context.nexusTheme.accentPrimary,
                  fontSize: r.fs(10),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Badge de status do speaker ──────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final VoiceRoomMember member;
  const _StatusBadge({required this.member});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    if (!member.isMuted) return const SizedBox.shrink();

    return Container(
      width: r.s(20),
      height: r.s(20),
      decoration: BoxDecoration(
        color: context.nexusTheme.error,
        shape: BoxShape.circle,
        border: Border.all(color: context.surfaceColor, width: 1.5),
      ),
      child: Icon(Icons.mic_off_rounded, color: Colors.white, size: r.s(11)),
    );
  }
}

// ─── Grid de Listeners ────────────────────────────────────────────────────────
class _ListenersGrid extends StatelessWidget {
  final List<VoiceRoomMember> listeners;
  final bool isHost;
  final void Function(VoiceRoomMember) onTap;

  const _ListenersGrid({
    required this.listeners,
    required this.isHost,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Wrap(
      spacing: r.s(12),
      runSpacing: r.s(12),
      children: listeners
          .map((m) => GestureDetector(
                onTap: () => onTap(m),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: r.s(24),
                          backgroundColor: context.nexusTheme.surfacePrimary,
                          backgroundImage: m.iconUrl != null
                              ? CachedNetworkImageProvider(m.iconUrl!)
                              : null,
                          child: m.iconUrl == null
                              ? Text(
                                  m.nickname.isNotEmpty
                                      ? m.nickname[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: context.nexusTheme.textPrimary,
                                    fontSize: r.fs(14),
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : null,
                        ),
                        // Mão levantada
                        if (m.handRaised)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: r.s(16),
                              height: r.s(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9800),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: context.surfaceColor, width: 1.5),
                              ),
                              child: Icon(Icons.back_hand_rounded,
                                  color: Colors.white, size: r.s(9)),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: r.s(4)),
                    SizedBox(
                      width: r.s(52),
                      child: Text(
                        m.nickname,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: r.fs(10),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ─── Título de seção ──────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionTitle({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Row(
      children: [
        Icon(icon, color: color, size: r.s(16)),
        SizedBox(width: r.s(6)),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: r.fs(13),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─── Barra de controles ───────────────────────────────────────────────────────
class _FreeTalkControls extends StatelessWidget {
  final FreeTalkState state;
  final VoidCallback onToggleMute;
  final VoidCallback onRaiseHand;
  final VoidCallback onStepDown;
  final VoidCallback onLeave;

  const _FreeTalkControls({
    required this.state,
    required this.onToggleMute,
    required this.onRaiseHand,
    required this.onStepDown,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.s(24), vertical: r.s(16)),
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Botão de microfone (apenas para quem está no palco)
          if (state.isOnStage) ...[
            _ControlButton(
              icon: state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: state.isMuted ? 'Mudo' : 'Microfone',
              color: state.isMuted ? context.nexusTheme.error : const Color(0xFF4CAF50),
              onTap: onToggleMute,
            ),
            // Descer do palco (apenas speaker, não host)
            if (state.isSpeaker)
              _ControlButton(
                icon: Icons.arrow_downward_rounded,
                label: 'Sair do palco',
                color: Colors.grey[400]!,
                onTap: onStepDown,
              ),
          ],

          // Levantar a mão (apenas listener)
          if (state.isListener)
            _ControlButton(
              icon: state.myHandRaised
                  ? Icons.back_hand_rounded
                  : Icons.back_hand_outlined,
              label: state.myHandRaised ? 'Baixar mão' : 'Levantar mão',
              color: state.myHandRaised
                  ? const Color(0xFFFF9800)
                  : Colors.grey[400]!,
              onTap: onRaiseHand,
            ),

          // Sair (para não-hosts)
          if (!state.isHost)
            _ControlButton(
              icon: Icons.call_end_rounded,
              label: 'Sair',
              color: context.nexusTheme.error,
              onTap: onLeave,
              isLarge: true,
            ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLarge;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final size = isLarge ? r.s(64.0) : r.s(56.0);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: r.s(isLarge ? 28.0 : 24.0)),
          ),
          SizedBox(height: r.s(4)),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: r.fs(10),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sheet de ações do membro ─────────────────────────────────────────────────
class _MemberActionsSheet extends StatelessWidget {
  final VoiceRoomMember member;
  final bool isHost;
  final bool isMe;
  final void Function(bool) onMute;
  final VoidCallback onKick;
  final VoidCallback onStepDown;

  const _MemberActionsSheet({
    required this.member,
    required this.isHost,
    required this.isMe,
    required this.onMute,
    required this.onKick,
    required this.onStepDown,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Nome do membro
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              member.nickname,
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const Divider(height: 1),
          // Ações
          if (isMe || isHost)
            ListTile(
              leading: Icon(
                member.isMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
                color: member.isMuted
                    ? const Color(0xFF4CAF50)
                    : context.nexusTheme.error,
              ),
              title: Text(member.isMuted ? 'Ativar microfone' : 'Mutar'),
              onTap: () => onMute(!member.isMuted),
            ),
          if (isMe && member.role == 'speaker')
            ListTile(
              leading: const Icon(Icons.arrow_downward_rounded,
                  color: Colors.grey),
              title: const Text('Sair do palco'),
              onTap: onStepDown,
            ),
          if (isHost && !isMe)
            ListTile(
              leading: Icon(Icons.person_remove_rounded,
                  color: context.nexusTheme.error),
              title: const Text('Expulsar da sala'),
              onTap: onKick,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
