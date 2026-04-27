import '../../../../core/widgets/emoji_rain_overlay.dart';
// =============================================================================
// ScreeningLandscapeLayout — Layout adaptativo para modo landscape
//
// Em portrait: Stack imersivo padrão (player em tela cheia, chat sobreposto)
// Em landscape: Row com player à esquerda (70%) e chat à direita (30%)
//
// Detecta a orientação via OrientationBuilder e alterna entre os dois layouts.
// Quando em landscape, o SystemChrome oculta a status bar para maximizar
// o espaço do player.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screening_player_widget.dart';
import 'screening_controls_overlay.dart';
import 'screening_chat_overlay.dart';
import 'screening_reaction_bar.dart';
import 'screening_video_ended_overlay.dart';
import 'screening_entry_animation.dart';
import '../widgets/screening_sync_badge.dart';
import '../providers/screening_room_provider.dart';
import 'screening_ambient_gradient.dart';
import 'screening_top_bar.dart';

/// Widget raiz que detecta a orientação e alterna entre portrait e landscape.
class ScreeningAdaptiveLayout extends ConsumerStatefulWidget {
  final String sessionId;
  final String threadId;
  final bool showControls;
  final bool entryAnimationDone;
  final bool entryAnimationExiting;
  final VoidCallback onTap;
  final VoidCallback onMinimize;
  final VoidCallback onEntryAnimationComplete;
  /// Key local do EmojiRainOverlay da tela pai para disparar animações.
  final GlobalKey<EmojiRainOverlayState>? emojiRainKey;

  const ScreeningAdaptiveLayout({
    super.key,
    required this.sessionId,
    required this.threadId,
    required this.showControls,
    required this.entryAnimationDone,
    required this.entryAnimationExiting,
    required this.onTap,
    required this.onMinimize,
    required this.onEntryAnimationComplete,
    this.emojiRainKey,
  });

  @override
  ConsumerState<ScreeningAdaptiveLayout> createState() =>
      _ScreeningAdaptiveLayoutState();
}

class _ScreeningAdaptiveLayoutState
    extends ConsumerState<ScreeningAdaptiveLayout> {
  Orientation? _lastOrientation;

  void _handleOrientationChange(Orientation orientation) {
    if (_lastOrientation == orientation) return;
    _lastOrientation = orientation;

    if (orientation == Orientation.landscape) {
      // Landscape: ocultar status bar e navigation bar para tela cheia
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      // Portrait: restaurar UI do sistema
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  @override
  void dispose() {
    // Restaurar UI do sistema ao sair
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(screeningRoomProvider(widget.threadId));

    return OrientationBuilder(
      builder: (context, orientation) {
        _handleOrientationChange(orientation);

        if (orientation == Orientation.landscape) {
          return _LandscapeLayout(
            sessionId: widget.sessionId,
            threadId: widget.threadId,
            showControls: widget.showControls,
            entryAnimationDone: widget.entryAnimationDone,
            entryAnimationExiting: widget.entryAnimationExiting,
            onTap: widget.onTap,
            onMinimize: widget.onMinimize,
            onEntryAnimationComplete: widget.onEntryAnimationComplete,
            roomTitle: roomState.title ?? 'Sala de Projeção',
            emojiRainKey: widget.emojiRainKey,
          );
        }

        return _PortraitLayout(
          sessionId: widget.sessionId,
          threadId: widget.threadId,
          showControls: widget.showControls,
          entryAnimationDone: widget.entryAnimationDone,
          entryAnimationExiting: widget.entryAnimationExiting,
          onTap: widget.onTap,
          onMinimize: widget.onMinimize,
          onEntryAnimationComplete: widget.onEntryAnimationComplete,
          roomTitle: roomState.title ?? 'Sala de Projeção',
          emojiRainKey: widget.emojiRainKey,
        );
      },
    );
  }
}

// =============================================================================
// Layout Portrait — Column: vídeo no topo + chat sólido embaixo (estilo Rave)
// =============================================================================
class _PortraitLayout extends ConsumerWidget {
  final String sessionId;
  final String threadId;
  final bool showControls;
  final bool entryAnimationDone;
  final bool entryAnimationExiting;
  final VoidCallback onTap;
  final VoidCallback onMinimize;
  final VoidCallback onEntryAnimationComplete;
  final String roomTitle;
  final GlobalKey<EmojiRainOverlayState>? emojiRainKey;

  const _PortraitLayout({
    required this.sessionId,
    required this.threadId,
    required this.showControls,
    required this.entryAnimationDone,
    required this.entryAnimationExiting,
    required this.onTap,
    required this.onMinimize,
    required this.onEntryAnimationComplete,
    required this.roomTitle,
    this.emojiRainKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    // Altura da status bar do sistema
    final statusBarH = mq.padding.top;
    // Altura do TopBar (ícones + padding interno de 4px em cima e embaixo)
    const topBarH = 52.0;
    // Altura total do bloco superior: status bar + topbar
    final headerH = statusBarH + topBarH;
    // Altura do player: 40% da tela, clampada. O player fica ABAIXO do header.
    final playerHeight = (mq.size.height * 0.40).clamp(200.0, 320.0);
    // Cor ambiente para o gradiente dinâmico do chat
    final ambientColor = sessionId.isNotEmpty
        ? ref.watch(screeningAmbientColorProvider(sessionId))
        : Colors.black;

    return Stack(
      children: [
        // ── Estrutura principal: Column com header + vídeo + chat ────────
        Column(
          children: [
            // ── Header (status bar + TopBar) — fundo sólido para cobrir
            //    qualquer conteúdo que possa vazar por baixo ──────────────
            Container(
              height: headerH,
              color: Colors.black,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: topBarH,
                  child: ScreeningTopBar(
                    sessionId: sessionId,
                    threadId: threadId,
                    onMinimize: onMinimize,
                    // TopBar está fora do player, não precisa de padding.top
                    overrideTopPadding: 0,
                  ),
                ),
              ),
            ),
            // ── Área do Player (abaixo do header, altura fixa) ───────────
            SizedBox(
              height: playerHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Player WebView (toque dispara controles de reprodução)
                  GestureDetector(
                    onTap: onTap,
                    behavior: HitTestBehavior.opaque,
                    child: ScreeningPlayerWidget(
                      sessionId: sessionId,
                      threadId: threadId,
                    ),
                  ),
                  // Controles de reprodução (play/pause/seek) — overlay de fade
                  Positioned.fill(
                    child: ScreeningControlsOverlay(
                      sessionId: sessionId,
                      threadId: threadId,
                      visible: showControls,
                      onMinimize: onMinimize,
                    ),
                  ),
                  // SyncStatusBadge (topo do player)
                  if (sessionId.isNotEmpty)
                    Positioned(
                      top: 4,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: ScreeningSyncBadge(sessionId: sessionId),
                      ),
                    ),
                  // Overlay de vídeo encerrado
                  if (sessionId.isNotEmpty)
                    Positioned.fill(
                      child: ScreeningVideoEndedOverlay(
                        sessionId: sessionId,
                        threadId: threadId,
                      ),
                    ),
                ],
              ),
            ),
            // ── Área do Chat (resto da tela, gradiente dinâmico) ─────────
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(Colors.black, ambientColor, 0.35)!
                          .withValues(alpha: 1.0),
                      Color.lerp(Colors.black, ambientColor, 0.15)!
                          .withValues(alpha: 1.0),
                      const Color(0xFF0A0A0A),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
                child: ScreeningChatOverlay(
                  sessionId: sessionId,
                  threadId: threadId,
                  emojiRainKey: emojiRainKey,
                ),
              ),
            ),
          ],
        ),
        // ── Animação de entrada (por cima de tudo) ───────────────────────
        if (!entryAnimationDone)
          Positioned.fill(
            child: ScreeningEntryAnimation(
              isExiting: entryAnimationExiting,
              onComplete: onEntryAnimationComplete,
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// Layout Landscape — Row: player à esquerda (70%) + chat à direita (30%)
// =============================================================================
class _LandscapeLayout extends StatelessWidget {
  final String sessionId;
  final String threadId;
  final bool showControls;
  final bool entryAnimationDone;
  final bool entryAnimationExiting;
  final VoidCallback onTap;
  final VoidCallback onMinimize;
  final VoidCallback onEntryAnimationComplete;
  final String roomTitle;
  final GlobalKey<EmojiRainOverlayState>? emojiRainKey;

  const _LandscapeLayout({
    required this.sessionId,
    required this.threadId,
    required this.showControls,
    required this.entryAnimationDone,
    required this.entryAnimationExiting,
    required this.onTap,
    required this.onMinimize,
    required this.onEntryAnimationComplete,
    required this.roomTitle,
    this.emojiRainKey,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          children: [
            // ── Player (70%) ─────────────────────────────────────────────
            Expanded(
              flex: 70,
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ScreeningPlayerWidget(
                      sessionId: sessionId,
                      threadId: threadId,
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.55),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.70),
                              ],
                              stops: const [0.0, 0.15, 0.65, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (sessionId.isNotEmpty)
                      Positioned.fill(
                        child: ScreeningControlsOverlay(
                          sessionId: sessionId,
                          threadId: threadId,
                          visible: showControls,
                          onMinimize: onMinimize,
                        ),
                      ),
                    if (sessionId.isNotEmpty)
                      Positioned.fill(
                        child: ScreeningVideoEndedOverlay(
                          sessionId: sessionId,
                          threadId: threadId,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // ── Divisor ──────────────────────────────────────────────────
            Container(
              width: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            // ── Chat (30%) ───────────────────────────────────────────────
            Expanded(
              flex: 30,
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
                child: Column(
                  children: [
                    _LandscapeChatHeader(
                      threadId: threadId,
                      onMinimize: onMinimize,
                    ),
                    Expanded(
                      child: ScreeningChatOverlay(
                        sessionId: sessionId,
                        threadId: threadId,
                        isLandscape: true,
                        emojiRainKey: emojiRainKey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Animação de entrada
        if (!entryAnimationDone)
          Positioned.fill(
            child: ScreeningEntryAnimation(
              isExiting: entryAnimationExiting,
              onComplete: onEntryAnimationComplete,
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// Header do painel lateral (landscape)
// =============================================================================
class _LandscapeChatHeader extends ConsumerWidget {
  final String threadId;
  final VoidCallback onMinimize;

  const _LandscapeChatHeader({
    required this.threadId,
    required this.onMinimize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(screeningRoomProvider(threadId));

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline_rounded,
              color: Colors.white54, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              roomState.title ?? 'Chat da Sala',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Contador de participantes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_outline_rounded,
                    color: Colors.white54, size: 12),
                const SizedBox(width: 4),
                Text(
                  '${roomState.viewerCount}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Botão de minimizar
          GestureDetector(
            onTap: onMinimize,
            child: const Icon(Icons.minimize_rounded,
                color: Colors.white38, size: 18),
          ),
        ],
      ),
    );
  }
}
