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
// Contém:
// - TopBar: botão voltar, título do vídeo, contagem de viewers, mute
// - HostControls: play/pause, seek bar, trocar vídeo (apenas host)
// =============================================================================

class ScreeningControlsOverlay extends ConsumerStatefulWidget {
  final String sessionId;
  final String threadId;
  final bool visible;
  final VoidCallback onMinimize;

  const ScreeningControlsOverlay({
    super.key,
    required this.sessionId,
    required this.threadId,
    required this.visible,
    required this.onMinimize,
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
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(screeningRoomProvider(widget.threadId));
    final mq = MediaQuery.of(context);
    final hasVideo = roomState.currentVideoUrl?.isNotEmpty == true;

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
                  // Gradiente superior
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
                  // Gradiente inferior
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    height: 120,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.80),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Controles do Player (bottom) — apenas host
                  if (roomState.isHost)
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: _HostControlsConsumer(
                        sessionId: widget.sessionId,
                        threadId: widget.threadId,
                        onSeekAndBroadcast: _seekAndBroadcast,
                        onTogglePlayPause: _togglePlayPause,
                                      ),
                    ),
                ],
              ),
            ),
          ),
        // TopBar agora gerenciada pelo _PortraitLayout (ScreeningTopBar fixo)
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

  Future<void> _handleTap() async {
    HapticFeedback.selectionClick();
    await _pressController.forward();
    await _pressController.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.all(8),
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

  Future<void> _handleTap() async {
    HapticFeedback.mediumImpact();
    await _pressController.forward();
    await _pressController.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 60,
          height: 60,
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
                    size: 34,
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

  const _SeekBar({
    required this.sessionId,
    required this.position,
    required this.duration,
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
              // Apenas atualiza o valor visual durante o drag.
              // O seek real é feito somente no onChangeEnd para evitar
              // avalanche de evaluateJavascript a cada frame.
              setState(() => _dragValue = value);
            },
            onChangeEnd: (value) {
              final newPos = Duration(milliseconds: (value * total).toInt());
              // 1. Seek local imediato para o host ver o resultado
              ref
                  .read(screeningPlayerProvider(widget.sessionId).notifier)
                  .seek(newPos);
              // 2. Broadcast para sincronizar os outros participantes
              ref
                  .read(screeningSyncProvider(widget.sessionId).notifier)
                  .broadcastEvent(SyncEvent(
                    type: SyncEventType.seek,
                    positionMs: newPos.inMilliseconds,
                    serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
                  ));
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
// _HostControlsConsumer — Widget isolado que observa playerState
// Evita que o overlay inteiro reconstrua a cada tick do polling de posição.
// =============================================================================
class _HostControlsConsumer extends ConsumerWidget {
  final String sessionId;
  final String threadId;
  final void Function(Duration position, bool isPlaying) onSeekAndBroadcast;
  final void Function(dynamic playerState) onTogglePlayPause;

  const _HostControlsConsumer({
    required this.sessionId,
    required this.threadId,
    required this.onSeekAndBroadcast,
    required this.onTogglePlayPause,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(screeningPlayerProvider(sessionId));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Seek bar (apenas para vídeos não-live) ──────────────────────
          if (!playerState.isLiveStream)
            _SeekBar(
              sessionId: sessionId,
              position: playerState.position,
              duration: playerState.duration,
            ),
          const SizedBox(height: 12),
          // ── Botões de controle ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlButton(
                icon: Icons.replay_10_rounded,
                size: 32,
                onTap: () {
                  final pos = playerState.position;
                  final newPos = pos - const Duration(seconds: 10);
                  onSeekAndBroadcast(
                    newPos.isNegative ? Duration.zero : newPos,
                    playerState.isPlaying,
                  );
                },
              ),
              const SizedBox(width: 28),
              _PlayPauseButton(
                isPlaying: playerState.isPlaying,
                isBuffering: playerState.isBuffering,
                onTap: () => onTogglePlayPause(playerState),
              ),
              const SizedBox(width: 28),
              _ControlButton(
                icon: Icons.forward_10_rounded,
                size: 32,
                onTap: () {
                  final pos = playerState.position;
                  onSeekAndBroadcast(
                    pos + const Duration(seconds: 10),
                    playerState.isPlaying,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
