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

/// Widget raiz que detecta a orientação e alterna entre portrait e landscape.
class ScreeningAdaptiveLayout extends ConsumerStatefulWidget {
  final String sessionId;
  final String threadId;
  final bool showControls;
  final bool entryAnimationDone;
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
// Layout Portrait — Stack imersivo padrão
// =============================================================================
class _PortraitLayout extends StatelessWidget {
  final String sessionId;
  final String threadId;
  final bool showControls;
  final bool entryAnimationDone;
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
    required this.onTap,
    required this.onMinimize,
    required this.onEntryAnimationComplete,
    required this.roomTitle,
    this.emojiRainKey,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camada 0: Player
          ScreeningPlayerWidget(
            sessionId: sessionId,
            threadId: threadId,
          ),
          // Camada 1: SyncStatusBadge
          if (sessionId.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: ScreeningSyncBadge(sessionId: sessionId),
              ),
            ),
          // Camada 2: Gradientes de contraste
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.65),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.80),
                    ],
                    stops: const [0.0, 0.18, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Camada 3: Chat overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size.height * 0.48,
            child: SafeArea(
              top: false,
              child: ScreeningChatOverlay(
                sessionId: sessionId,
                threadId: threadId,
                emojiRainKey: emojiRainKey,
              ),
            ),
          ),
          // Camada 4a: Barra de reações
          if (sessionId.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: size.height * 0.48 + 8,
              child: SafeArea(
                top: false,
                child: ScreeningReactionBar(sessionId: sessionId),
              ),
            ),
          // Camada 4b: Controles flutuantes
          Positioned.fill(
            child: ScreeningControlsOverlay(
              sessionId: sessionId,
              threadId: threadId,
              visible: showControls,
              onMinimize: onMinimize,
            ),
          ),
          // Camada 5: Overlay de vídeo encerrado
          if (sessionId.isNotEmpty)
            Positioned.fill(
              child: ScreeningVideoEndedOverlay(
                sessionId: sessionId,
                threadId: threadId,
              ),
            ),
          // Camada 6: Animação de entrada
          if (!entryAnimationDone)
            Positioned.fill(
              child: ScreeningEntryAnimation(
                onComplete: onEntryAnimationComplete,
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Layout Landscape — Row com player à esquerda e chat à direita
// =============================================================================
class _LandscapeLayout extends StatelessWidget {
  final String sessionId;
  final String threadId;
  final bool showControls;
  final bool entryAnimationDone;
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
    required this.onTap,
    required this.onMinimize,
    required this.onEntryAnimationComplete,
    required this.roomTitle,
    this.emojiRainKey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Área do Player (70% da largura) ─────────────────────────────────
        Expanded(
          flex: 70,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Player
                ScreeningPlayerWidget(
                  sessionId: sessionId,
                  threadId: threadId,
                ),
                // Gradiente de contraste (apenas topo e base)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.55),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.70),
                          ],
                          stops: const [0.0, 0.15, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // SyncStatusBadge
                if (sessionId.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: ScreeningSyncBadge(sessionId: sessionId),
                    ),
                  ),
                // Barra de reações (canto inferior esquerdo)
                if (sessionId.isNotEmpty)
                  Positioned(
                    left: 8,
                    bottom: 64,
                    child: ScreeningReactionBar(
                      sessionId: sessionId,
                      compact: true,
                    ),
                  ),
                // Controles flutuantes
                Positioned.fill(
                  child: ScreeningControlsOverlay(
                    sessionId: sessionId,
                    threadId: threadId,
                    visible: showControls,
                    onMinimize: onMinimize,
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
                // Animação de entrada
                if (!entryAnimationDone)
                  Positioned.fill(
                    child: ScreeningEntryAnimation(
                      onComplete: onEntryAnimationComplete,
                    ),
                  ),
              ],
            ),
          ),
        ),
        // ── Divisor vertical ────────────────────────────────────────────────
        Container(
          width: 1,
          color: Colors.white.withOpacity(0.08),
        ),
        // ── Painel lateral do Chat (30% da largura) ──────────────────────────
        Expanded(
          flex: 30,
          child: Container(
            color: Colors.black.withOpacity(0.85),
            child: Column(
              children: [
                // Header do painel lateral
                _LandscapeChatHeader(
                  threadId: threadId,
                  onMinimize: onMinimize,
                ),
                // Chat overlay expandido
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
        color: Colors.white.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
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
              color: Colors.white.withOpacity(0.1),
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
