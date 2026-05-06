import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/call_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../providers/chat_call_provider.dart';
import '../../auth/providers/auth_provider.dart';

// ============================================================================
// InlineChatCallPanel
//
// Painel de palco integrado à sala de chat. Desce do topo com animação
// SlideTransition + FadeTransition ao ser ativado. O chat normal permanece
// visível abaixo.
//
// Dois modos:
//   • Expandido  — grade de participantes completa (~220px)
//   • Compacto   — faixa fina com avatares em linha (~72px)
//
// A transição entre modos usa AnimatedSize para altura e AnimatedSwitcher
// para o conteúdo interno.
// ============================================================================
class InlineChatCallPanel extends ConsumerStatefulWidget {
  final String threadId;

  const InlineChatCallPanel({super.key, required this.threadId});

  @override
  ConsumerState<InlineChatCallPanel> createState() =>
      _InlineChatCallPanelState();
}

class _InlineChatCallPanelState extends ConsumerState<InlineChatCallPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _fadeAnim = CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  // Reage a mudanças no isActive para animar entrada/saída
  void _syncAnimation(bool isActive) {
    if (isActive && _slideCtrl.status != AnimationStatus.completed) {
      _slideCtrl.forward();
    } else if (!isActive && _slideCtrl.status != AnimationStatus.dismissed) {
      _slideCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(chatCallProvider(widget.threadId));
    _syncAnimation(callState.isActive);

    // Quando a animação de saída termina e a call não está ativa,
    // não renderizar nada para liberar recursos.
    return AnimatedBuilder(
      animation: _slideCtrl,
      builder: (context, _) {
        if (_slideCtrl.isDismissed && !callState.isActive) {
          return const SizedBox.shrink();
        }
        return FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: _PanelBody(threadId: widget.threadId),
          ),
        );
      },
    );
  }
}

// ============================================================================
// _PanelBody — corpo do painel, separado para isolar rebuilds
// ============================================================================
class _PanelBody extends ConsumerWidget {
  final String threadId;
  const _PanelBody({required this.threadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;
    final callState = ref.watch(chatCallProvider(threadId));
    final ctrl = ref.read(chatCallProvider(threadId).notifier);

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.backgroundSecondary,
          border: Border(
            bottom: BorderSide(
              color: theme.accentPrimary.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header sempre visível ──────────────────────────────────────
            _PanelHeader(threadId: threadId),

            // ── Conteúdo animado: expandido ou compacto ────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(
                  sizeFactor: anim,
                  axisAlignment: -1,
                  child: child,
                ),
              ),
              child: callState.isExpanded
                  ? _ExpandedContent(
                      key: const ValueKey('expanded'),
                      threadId: threadId,
                    )
                  : _CompactContent(
                      key: const ValueKey('compact'),
                      threadId: threadId,
                    ),
            ),

            // ── Barra de controles ─────────────────────────────────────────
            _ControlsBar(threadId: threadId),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// _PanelHeader — título, timer, contagem, botão expandir/colapsar
// ============================================================================
class _PanelHeader extends ConsumerWidget {
  final String threadId;
  const _PanelHeader({required this.threadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;
    final callState = ref.watch(chatCallProvider(threadId));
    final ctrl = ref.read(chatCallProvider(threadId).notifier);
    final count = callState.participants.length;

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: r.s(12), vertical: r.s(8)),
      child: Row(
        children: [
          // Indicador ao vivo
          Container(
            width: r.s(7),
            height: r.s(7),
            decoration: BoxDecoration(
              color: theme.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.success.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          SizedBox(width: r.s(6)),
          Text(
            'Voice Chat',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: r.fs(13),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: r.s(8)),
          Text(
            callState.elapsed,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: r.fs(12),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: r.s(6)),
          Text(
            '· $count participante${count != 1 ? 's' : ''}',
            style: TextStyle(
              color: theme.textHint,
              fontSize: r.fs(11),
            ),
          ),
          const Spacer(),
          // Botão expandir / colapsar
          GestureDetector(
            onTap: ctrl.toggleExpanded,
            child: AnimatedRotation(
              turns: callState.isExpanded ? 0 : 0.5,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                color: theme.textSecondary,
                size: r.s(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _ExpandedContent — grade completa de speakers + chips de listeners
// ============================================================================
class _ExpandedContent extends ConsumerWidget {
  const _ExpandedContent({super.key, required this.threadId});
  final String threadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;
    final callState = ref.watch(chatCallProvider(threadId));
    final ctrl = ref.read(chatCallProvider(threadId).notifier);
    final speakers = callState.speakers;
    final listeners = callState.listeners;

    if (callState.participants.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: r.s(16)),
        child: Center(
          child: Text(
            'Aguardando participantes...',
            style: TextStyle(
                color: theme.textSecondary, fontSize: r.fs(12)),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: r.s(220)),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(12), vertical: r.s(4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Speakers
            if (speakers.isNotEmpty) ...[
              _SectionLabel(
                icon: Icons.mic_rounded,
                label: 'No palco (${speakers.length})',
                color: theme.accentPrimary,
              ),
              SizedBox(height: r.s(6)),
              _SpeakersRow(
                speakers: speakers,
                callState: callState,
                ctrl: ctrl,
              ),
            ],
            // Listeners
            if (listeners.isNotEmpty) ...[
              SizedBox(height: r.s(10)),
              _SectionLabel(
                icon: Icons.headphones_rounded,
                label: 'Ouvindo (${listeners.length})',
                color: theme.textSecondary,
              ),
              SizedBox(height: r.s(6)),
              _ListenersWrap(
                listeners: listeners,
                callState: callState,
              ),
            ],
            SizedBox(height: r.s(4)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// _CompactContent — linha de avatares quando o painel está colapsado
// ============================================================================
class _CompactContent extends ConsumerWidget {
  const _CompactContent({super.key, required this.threadId});
  final String threadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;
    final callState = ref.watch(chatCallProvider(threadId));
    final speakers = callState.speakers;

    return Padding(
      padding: EdgeInsets.only(
          left: r.s(12), right: r.s(12), bottom: r.s(8)),
      child: Row(
        children: [
          ...speakers.take(5).map((p) {
            final profile =
                p['profiles'] as Map<String, dynamic>?;
            final userId = p['user_id'] as String? ?? '';
            final iconUrl = profile?['icon_url'] as String?;
            final level = (ref
                    .read(chatCallProvider(threadId).notifier)
                    .audioLevelFor(p))
                .clamp(0.0, 1.0);
            return Padding(
              padding: EdgeInsets.only(right: r.s(6)),
              child: _CompactAvatar(
                userId: userId,
                iconUrl: iconUrl,
                isSpeaking: level > 0.1,
                accentColor: theme.accentPrimary,
                size: r.s(32),
              ),
            );
          }),
          if (speakers.length > 5) ...[
            Container(
              width: r.s(32),
              height: r.s(32),
              decoration: BoxDecoration(
                color: theme.surfacePrimary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '+${speakers.length - 5}',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: r.fs(10),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// _ControlsBar — mic, speaker, sair/encerrar
// ============================================================================
class _ControlsBar extends ConsumerWidget {
  final String threadId;
  const _ControlsBar({required this.threadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;
    final callState = ref.watch(chatCallProvider(threadId));
    final ctrl = ref.read(chatCallProvider(threadId).notifier);
    final isHost = callState.myRole.isHost;
    final canSpeak = callState.myRole.canSpeak;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.s(16), vertical: r.s(10)),
      decoration: BoxDecoration(
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
          // Mic (speakers/host)
          if (canSpeak)
            _CallControlBtn(
              icon: callState.isMuted
                  ? Icons.mic_off_rounded
                  : Icons.mic_rounded,
              label: callState.isMuted ? 'Mudo' : 'Mic',
              isActive: !callState.isMuted,
              onTap: ctrl.toggleMute,
            ),
          // Levantar mão (listeners)
          if (!canSpeak)
            _CallControlBtn(
              icon: callState.handRaised
                  ? Icons.back_hand_rounded
                  : Icons.back_hand_outlined,
              label: callState.handRaised ? 'Abaixar' : 'Mão',
              isActive: callState.handRaised,
              onTap: ctrl.toggleHandRaise,
            ),
          // Alto-falante
          _CallControlBtn(
            icon: callState.isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            label: 'Alto-falante',
            isActive: callState.isSpeakerOn,
            onTap: ctrl.toggleSpeaker,
          ),
          // Descer do palco (speakers não-host)
          if (callState.myRole == StageRole.speaker)
            _CallControlBtn(
              icon: Icons.arrow_downward_rounded,
              label: 'Descer',
              isActive: false,
              onTap: ctrl.stepDown,
            ),
          // Encerrar (host) ou Sair (outros)
          _CallControlBtn(
            icon: isHost
                ? Icons.call_end_rounded
                : Icons.exit_to_app_rounded,
            label: isHost ? 'Encerrar' : 'Sair',
            isActive: false,
            isEnd: true,
            onTap: () {
              if (isHost) {
                final nickname =
                    ref.read(currentUserProvider)?.nickname;
                ctrl.end(nickname);
              } else {
                ctrl.leave();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _SpeakersRow — linha horizontal de cards de speaker
// ============================================================================
class _SpeakersRow extends StatelessWidget {
  final List<Map<String, dynamic>> speakers;
  final ChatCallState callState;
  final ChatCallController ctrl;

  const _SpeakersRow({
    required this.speakers,
    required this.callState,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: speakers.map((p) {
          final profile = p['profiles'] as Map<String, dynamic>?;
          final userId = p['user_id'] as String? ?? '';
          final nickname = profile?['nickname'] as String? ?? 'Usuário';
          final iconUrl = profile?['icon_url'] as String?;
          final isHost = p['stage_role'] == 'host';
          final isMuted = p['is_muted'] == true;
          final isMe = userId == SupabaseService.currentUserId;
          final level = ctrl.audioLevelFor(p);
          final isSpeaking = level > 0.1 && !isMuted;

          return Padding(
            padding: EdgeInsets.only(right: r.s(10)),
            child: GestureDetector(
              onLongPress: callState.myRole.isHost && !isMe
                  ? () => _showHostActions(context, userId, nickname, isMuted)
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.all(isSpeaking ? r.s(2) : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSpeaking
                            ? context.nexusTheme.success
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: CosmeticAvatar(
                      userId: userId,
                      avatarUrl: iconUrl,
                      size: r.s(44),
                    ),
                  ),
                  SizedBox(height: r.s(4)),
                  Text(
                    isMe ? 'Você' : nickname,
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontSize: r.fs(10),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isHost)
                    Text(
                      '👑 Host',
                      style: TextStyle(
                        color: context.nexusTheme.accentPrimary,
                        fontSize: r.fs(9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (isMuted)
                    Icon(Icons.mic_off_rounded,
                        color: context.nexusTheme.error,
                        size: r.s(12)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showHostActions(
      BuildContext context, String userId, String nickname, bool isMuted) {
    final theme = context.nexusTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.modalBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
                color: theme.textPrimary,
              ),
              title: Text(
                isMuted ? 'Desmutar' : 'Mutar',
                style: TextStyle(color: theme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                CallService.muteParticipant(userId, muted: !isMuted);
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.person_remove_rounded, color: theme.error),
              title: Text(
                'Expulsar $nickname',
                style: TextStyle(color: theme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                CallService.kickParticipant(userId);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// _ListenersWrap — chips compactos para listeners
// ============================================================================
class _ListenersWrap extends StatelessWidget {
  final List<Map<String, dynamic>> listeners;
  final ChatCallState callState;

  const _ListenersWrap({
    required this.listeners,
    required this.callState,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;

    return Wrap(
      spacing: r.s(6),
      runSpacing: r.s(6),
      children: listeners.map((p) {
        final profile = p['profiles'] as Map<String, dynamic>?;
        final userId = p['user_id'] as String? ?? '';
        final nickname = profile?['nickname'] as String? ?? 'Usuário';
        final iconUrl = profile?['icon_url'] as String?;
        final isMe = userId == SupabaseService.currentUserId;
        final hasHand = callState.handRaisedUsers.contains(userId);

        return GestureDetector(
          onTap: callState.myRole.isHost && hasHand
              ? () => CallService.acceptSpeaker(userId)
              : null,
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: r.s(8), vertical: r.s(4)),
            decoration: BoxDecoration(
              color: hasHand
                  ? theme.accentPrimary.withValues(alpha: 0.12)
                  : theme.surfacePrimary,
              borderRadius: BorderRadius.circular(r.s(20)),
              border: Border.all(
                color: hasHand
                    ? theme.accentPrimary.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CosmeticAvatar(
                    userId: userId, avatarUrl: iconUrl, size: r.s(20)),
                SizedBox(width: r.s(4)),
                Text(
                  isMe ? 'Você' : nickname,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: r.fs(11),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasHand) ...[
                  SizedBox(width: r.s(3)),
                  Text('✋', style: TextStyle(fontSize: r.fs(12))),
                  if (callState.myRole.isHost) ...[
                    SizedBox(width: r.s(3)),
                    Icon(Icons.check_circle_rounded,
                        color: theme.success, size: r.s(14)),
                  ],
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================================
// _CompactAvatar — avatar com anel de speaking para modo compacto
// ============================================================================
class _CompactAvatar extends StatelessWidget {
  final String userId;
  final String? iconUrl;
  final bool isSpeaking;
  final Color accentColor;
  final double size;

  const _CompactAvatar({
    required this.userId,
    required this.iconUrl,
    required this.isSpeaking,
    required this.accentColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.all(isSpeaking ? 2 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSpeaking ? accentColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: CosmeticAvatar(
        userId: userId,
        avatarUrl: iconUrl,
        size: size,
      ),
    );
  }
}

// ============================================================================
// _SectionLabel — label de seção (palco / ouvindo)
// ============================================================================
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: r.s(13)),
        SizedBox(width: r.s(4)),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: r.fs(11),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// _CallControlBtn — botão de controle circular
// ============================================================================
class _CallControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isEnd;
  final VoidCallback onTap;

  const _CallControlBtn({
    required this.icon,
    required this.label,
    required this.isActive,
    this.isEnd = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: r.s(44),
            height: r.s(44),
            decoration: BoxDecoration(
              color: isEnd
                  ? theme.error
                  : isActive
                      ? theme.accentPrimary.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: isEnd
                    ? Colors.transparent
                    : isActive
                        ? theme.accentPrimary.withValues(alpha: 0.5)
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
              size: r.s(20),
            ),
          ),
          SizedBox(height: r.s(4)),
          Text(
            label,
            style: TextStyle(
              color: isEnd ? theme.error : Colors.grey[500],
              fontSize: r.fs(9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
