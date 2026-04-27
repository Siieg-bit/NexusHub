import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_room_provider.dart';
import '../providers/screening_player_provider.dart';
import '../providers/screening_sync_provider.dart';
import '../models/sync_event.dart';

// =============================================================================
// ScreeningControlsOverlay — Controles flutuantes da Sala de Projeção
//
// Camada 4 do Stack imersivo. Aparece ao tocar na tela e some após 3s.
// Layout:
// - Centro: botões play/pause, ±10s, anterior/próximo (apenas host)
// - Bottom: seek bar com tempos + botão fullscreen (apenas host)
// - Toque na área transparente central: esconde os controles (toggle)
// =============================================================================

class ScreeningControlsOverlay extends ConsumerStatefulWidget {
  final String sessionId;
  final String threadId;
  final bool visible;
  final VoidCallback onMinimize;
  /// Callback chamado quando o usuário toca na área transparente do overlay
  /// para esconder os controles (toggle off).
  final VoidCallback? onTapToDismiss;

  const ScreeningControlsOverlay({
    super.key,
    required this.sessionId,
    required this.threadId,
    required this.visible,
    required this.onMinimize,
    this.onTapToDismiss,
  });

  @override
  ConsumerState<ScreeningControlsOverlay> createState() =>
      _ScreeningControlsOverlayState();
}

class _ScreeningControlsOverlayState
    extends ConsumerState<ScreeningControlsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Estado de fullscreen (landscape forçado)
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(ScreeningControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    // Restaurar orientação ao sair
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _animController.dispose();
    super.dispose();
  }

  void _toggleFullscreen() {
    HapticFeedback.selectionClick();
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      // Forçar landscape
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // Restaurar todas as orientações
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(screeningRoomProvider(widget.threadId));
    final mq = MediaQuery.of(context);
    final hasVideo = roomState.currentVideoUrl?.isNotEmpty == true;

    // Atualizar estado de fullscreen com base na orientação atual
    final isLandscape = mq.orientation == Orientation.landscape;
    if (isLandscape != _isFullscreen) {
      // Sincronizar estado interno com a orientação real do dispositivo
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isFullscreen = isLandscape);
      });
    }

    return Stack(
      children: [
        // ── Controles de reprodução + gradientes (só quando há vídeo) ────────
        if (hasVideo)
          FadeTransition(
            opacity: _fadeAnim,
            child: IgnorePointer(
              ignoring: !widget.visible,
              child: Stack(
                children: [
                  // ── Área transparente central: toque para esconder controles ──
                  // Posicionada entre o gradiente superior e os controles do bottom.
                  // Quando o usuário toca aqui (fora dos botões), os controles somem.
                  if (widget.onTapToDismiss != null)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: widget.onTapToDismiss,
                        behavior: HitTestBehavior.translucent,
                        child: const SizedBox.expand(),
                      ),
                    ),

                  // ── Gradiente superior ─────────────────────────────────────
                  Positioned(
                    top: 0, left: 0, right: 0,
                    height: 80 + mq.padding.top,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.72),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Gradiente inferior ─────────────────────────────────────
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    height: 160,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.85),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Botões centrais (play/pause, ±10s, anterior/próximo) ───
                  // Apenas host. Posicionados no centro vertical do player.
                  if (roomState.isHost)
                    Positioned.fill(
                      child: Center(
                        child: _CenterControlsConsumer(
                          sessionId: widget.sessionId,
                          threadId: widget.threadId,
                          onSeekAndBroadcast: _seekAndBroadcast,
                          onTogglePlayPause: _togglePlayPause,
                        ),
                      ),
                    ),

                  // ── Seek bar + botão fullscreen (bottom) ───────────────────
                  // Seek bar: apenas host e apenas para VOD (duration > 0).
                  // Botão fullscreen: sempre visível quando há vídeo.
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: _BottomControlsConsumer(
                      sessionId: widget.sessionId,
                      threadId: widget.threadId,
                      onSeekAndBroadcast: _seekAndBroadcast,
                      isFullscreen: _isFullscreen,
                      onToggleFullscreen: _toggleFullscreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // TopBar gerenciada pelo _PortraitLayout (ScreeningTopBar fixo)
      ],
    );
  }

  void _togglePlayPause(dynamic playerState) {
    final syncNotifier =
        ref.read(screeningSyncProvider(widget.sessionId).notifier);
    final playerNotifier =
        ref.read(screeningPlayerProvider(widget.sessionId).notifier);
    final posMs = playerState.position.inMilliseconds;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (playerState.isPlaying) {
      playerNotifier.pause();
      syncNotifier.broadcastEvent(SyncEvent(
        type: SyncEventType.pause,
        positionMs: posMs,
        serverTimestampMs: now,
      ));
    } else {
      playerNotifier.play();
      syncNotifier.broadcastEvent(SyncEvent(
        type: SyncEventType.play,
        positionMs: posMs,
        serverTimestampMs: now,
      ));
    }
  }

  void _seekAndBroadcast(Duration position, bool isPlaying) {
    final syncNotifier =
        ref.read(screeningSyncProvider(widget.sessionId).notifier);
    final playerNotifier =
        ref.read(screeningPlayerProvider(widget.sessionId).notifier);

    playerNotifier.seek(position);
    syncNotifier.broadcastEvent(SyncEvent(
      type: SyncEventType.seek,
      positionMs: position.inMilliseconds,
      serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _ControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final double size;
  final String? label;
  /// Badge numérico exibido no canto superior direito (ex: tamanho da fila).
  final String? badge;
  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.color,
    this.size = 22,
    this.label,
    this.badge,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    _pressController.forward().then((_) => _pressController.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: widget.label != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: widget.color ?? Colors.white, size: widget.size),
                    const SizedBox(width: 4),
                    Text(
                      widget.label!,
                      style: TextStyle(
                        color: widget.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Icon(widget.icon, color: widget.color ?? Colors.white, size: widget.size),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onTap;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.isBuffering,
    required this.onTap,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    _pressController.forward().then((_) => _pressController.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: widget.isBuffering
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2.5,
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                  child: Icon(
                    widget.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    key: ValueKey(widget.isPlaying),
                    color: Colors.black,
                    size: 36,
                  ),
                ),
        ),
      ),
    );
  }
}


class _SeekBar extends ConsumerStatefulWidget {
  final String sessionId;
  final Duration position;
  final Duration duration;
  final void Function(Duration position, bool isPlaying) onSeekAndBroadcast;

  const _SeekBar({
    required this.sessionId,
    required this.position,
    required this.duration,
    required this.onSeekAndBroadcast,
  });

  @override
  ConsumerState<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<_SeekBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inMilliseconds.toDouble();
    final current = widget.position.inMilliseconds.toDouble().clamp(0.0, total);
    final progress = total > 0 ? current / total : 0.0;
    final displayProgress = _isDragging ? _dragValue : progress;
    final displayPosition = _isDragging
        ? Duration(milliseconds: (_dragValue * total).toInt())
        : widget.position;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Barra de progresso ───────────────────────────────────────────
        SliderTheme(
          data: SliderThemeData(
            trackHeight: _isDragging ? 5 : 3,
            thumbShape: _isDragging
                ? const RoundSliderThumbShape(enabledThumbRadius: 9)
                : const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.15),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: displayProgress.clamp(0.0, 1.0),
            onChangeStart: (value) {
              HapticFeedback.selectionClick();
              setState(() {
                _isDragging = true;
                _dragValue = value;
              });
            },
            onChanged: (value) {
              setState(() => _dragValue = value);
            },
            onChangeEnd: (value) {
              final newPos = Duration(milliseconds: (value * total).toInt());
              final playerState = ref.read(screeningPlayerProvider(widget.sessionId));
              widget.onSeekAndBroadcast(newPos, playerState.isPlaying);
              setState(() => _isDragging = false);
            },
          ),
        ),

        // ── Tempos ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(displayPosition),
                style: TextStyle(
                  color: _isDragging ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: _isDragging
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
              Text(
                _formatDuration(widget.duration),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// =============================================================================
// _CenterControlsConsumer — Botões centrais do player (play/pause, ±10s, prev/next)
// Posicionados no centro vertical do player, visíveis quando os controles estão ativos.
// =============================================================================
class _CenterControlsConsumer extends ConsumerWidget {
  final String sessionId;
  final String threadId;
  final void Function(Duration position, bool isPlaying) onSeekAndBroadcast;
  final void Function(dynamic playerState) onTogglePlayPause;

  const _CenterControlsConsumer({
    required this.sessionId,
    required this.threadId,
    required this.onSeekAndBroadcast,
    required this.onTogglePlayPause,
  });

  Future<void> _navigateTo(WidgetRef ref, Map<String, String> item, String threadId) async {
    final notifier = ref.read(screeningRoomProvider(threadId).notifier);
    await notifier.updateVideo(
      videoUrl: item['url'] ?? '',
      videoTitle: item['title'] ?? '',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(screeningPlayerProvider(sessionId));
    final roomState   = ref.watch(screeningRoomProvider(threadId));

    // ── Navegação de fila ─────────────────────────────────────────────
    final queue      = roomState.videoQueue;
    final currentUrl = roomState.currentVideoUrl ?? '';
    final currentIdx = queue.indexWhere((e) => (e['url'] ?? '') == currentUrl);
    final hasPrev    = currentIdx > 0;
    final hasNext    = currentIdx >= 0 && currentIdx < queue.length - 1;
    final hasNextFallback = currentIdx < 0 && queue.isNotEmpty;

    final prevItem = hasPrev ? queue[currentIdx - 1] : null;
    final nextItem = hasNext
        ? queue[currentIdx + 1]
        : (hasNextFallback ? queue[0] : null);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Botão Anterior
        if (prevItem != null)
          _ControlButton(
            icon: Icons.skip_previous_rounded,
            size: 28,
            onTap: () => _navigateTo(ref, prevItem, threadId),
          )
        else
          const SizedBox(width: 48),
        const SizedBox(width: 8),

        // Botão -10s (apenas VOD)
        if (!playerState.isLiveStream)
          _ControlButton(
            icon: Icons.replay_10_rounded,
            size: 28,
            onTap: () {
              final pos = playerState.position;
              final newPos = pos - const Duration(seconds: 10);
              onSeekAndBroadcast(
                newPos.isNegative ? Duration.zero : newPos,
                playerState.isPlaying,
              );
            },
          )
        else
          const SizedBox(width: 48),
        const SizedBox(width: 16),

        // Botão Play/Pause (central — maior)
        _PlayPauseButton(
          isPlaying: playerState.isPlaying,
          isBuffering: playerState.isBuffering,
          onTap: () => onTogglePlayPause(playerState),
        ),
        const SizedBox(width: 16),

        // Botão +10s (apenas VOD)
        if (!playerState.isLiveStream)
          _ControlButton(
            icon: Icons.forward_10_rounded,
            size: 28,
            onTap: () {
              final pos = playerState.position;
              onSeekAndBroadcast(
                pos + const Duration(seconds: 10),
                playerState.isPlaying,
              );
            },
          )
        else
          const SizedBox(width: 48),
        const SizedBox(width: 8),

        // Botão Próximo
        if (nextItem != null)
          _ControlButton(
            icon: Icons.skip_next_rounded,
            size: 28,
            onTap: () => _navigateTo(ref, nextItem, threadId),
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }
}

// =============================================================================
// _BottomControlsConsumer — Seek bar + botão fullscreen (bottom do player)
// Seek bar apenas para host e VOD. Botão fullscreen sempre visível.
// =============================================================================
class _BottomControlsConsumer extends ConsumerWidget {
  final String sessionId;
  final String threadId;
  final void Function(Duration position, bool isPlaying) onSeekAndBroadcast;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  const _BottomControlsConsumer({
    required this.sessionId,
    required this.threadId,
    required this.onSeekAndBroadcast,
    required this.isFullscreen,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(screeningPlayerProvider(sessionId));
    final roomState   = ref.watch(screeningRoomProvider(threadId));
    final mq = MediaQuery.of(context);

    final showSeekBar = roomState.isHost && playerState.duration > Duration.zero;

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, mq.padding.bottom + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Seek bar (host + VOD) ─────────────────────────────────────
          if (showSeekBar)
            _SeekBar(
              sessionId: sessionId,
              position: playerState.position,
              duration: playerState.duration,
              onSeekAndBroadcast: onSeekAndBroadcast,
            ),

          // ── Linha inferior: espaço + botão fullscreen ─────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Botão fullscreen (canto inferior direito)
                GestureDetector(
                  onTap: onToggleFullscreen,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 0.5,
                      ),
                    ),
                    child: Icon(
                      isFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
