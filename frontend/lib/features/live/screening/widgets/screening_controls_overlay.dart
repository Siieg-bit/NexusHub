import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_room_provider.dart';
import '../providers/screening_player_provider.dart';
import '../providers/screening_sync_provider.dart';
import '../providers/screening_voice_provider.dart';
import '../models/sync_event.dart';
import 'screening_add_video_sheet.dart';
import 'screening_transfer_host_sheet.dart';
import 'screening_queue_sheet.dart';

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
    final playerState = ref.watch(screeningPlayerProvider(widget.sessionId));
    final voiceState = ref.watch(screeningVoiceProvider(widget.sessionId));

    return FadeTransition(
      opacity: _fadeAnim,
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Top Bar ──────────────────────────────────────────────────
              _buildTopBar(context, roomState, voiceState),

              // ── Host Controls (apenas host) ───────────────────────────────
              if (roomState.isHost)
                _buildHostControls(context, roomState, playerState),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar(
    BuildContext context,
    dynamic roomState,
    dynamic voiceState,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Botão voltar / minimizar
          _ControlButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: widget.onMinimize,
          ),
          const SizedBox(width: 8),

          // Título do vídeo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sala de Projeção',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (roomState.currentVideoTitle?.isNotEmpty == true)
                  Text(
                    roomState.currentVideoTitle!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Contagem de viewers
          _ViewerCountBadge(count: roomState.viewerCount),
          const SizedBox(width: 8),

          // Microfone movido para a barra inferior do chat (como no Rave)
        ],
      ),
    );
  }

  // ── Host Controls ───────────────────────────────────────────────────────────

  Widget _buildHostControls(
    BuildContext context,
    dynamic roomState,
    dynamic playerState,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.75),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seek bar
          if (!playerState.isLiveStream)
            _SeekBar(
              sessionId: widget.sessionId,
              position: playerState.position,
              duration: playerState.duration,
            ),
          const SizedBox(height: 8),

          // Botões de controle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Retroceder 10s
              _ControlButton(
                icon: Icons.replay_10_rounded,
                size: 28,
                onTap: () {
                  final pos = playerState.position;
                  final newPos = pos - const Duration(seconds: 10);
                  _seekAndBroadcast(
                    newPos.isNegative ? Duration.zero : newPos,
                    playerState.isPlaying,
                  );
                },
              ),
              const SizedBox(width: 24),

              // Play / Pause
              _PlayPauseButton(
                isPlaying: playerState.isPlaying,
                isBuffering: playerState.isBuffering,
                onTap: () => _togglePlayPause(playerState),
              ),
              const SizedBox(width: 24),

              // Avançar 10s
              _ControlButton(
                icon: Icons.forward_10_rounded,
                size: 28,
                onTap: () {
                  final pos = playerState.position;
                  _seekAndBroadcast(
                    pos + const Duration(seconds: 10),
                    playerState.isPlaying,
                  );
                },
              ),
              const Spacer(),

              // Transferir host
              _ControlButton(
                icon: Icons.swap_horiz_rounded,
                label: 'Host',
                color: Colors.amberAccent,
                onTap: () => ScreeningTransferHostSheet.show(
                  context,
                  sessionId: widget.sessionId,
                  threadId: widget.threadId,
                ),
              ),
              const SizedBox(width: 8),
              // Trocar vídeo
              _ControlButton(
                icon: Icons.add_circle_outline_rounded,
                label: 'Vídeo',
                onTap: () => _showAddVideoSheet(context),
              ),
              const SizedBox(width: 8),
              // Fila de vídeos
              _ControlButton(
                icon: Icons.queue_music_rounded,
                label: 'Fila',
                color: roomState.videoQueue.isNotEmpty
                    ? Colors.greenAccent[400]!
                    : null,
                badge: roomState.videoQueue.isNotEmpty
                    ? '${roomState.videoQueue.length}'
                    : null,
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => ScreeningQueueSheet(
                    sessionId: widget.sessionId,
                    threadId: widget.threadId,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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

  void _showAddVideoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ScreeningAddVideoSheet(
        sessionId: widget.sessionId,
        threadId: widget.threadId,
      ),
    );
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
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
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
                color: Colors.white.withOpacity(0.25),
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

class _ViewerCountBadge extends StatelessWidget {
  final int count;

  const _ViewerCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.remove_red_eye_outlined,
              color: Colors.white70, size: 13),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _SeekBar Premium — Seek bar com preview de posição e thumb animado
// =============================================================================

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
            inactiveTrackColor: Colors.white.withOpacity(0.2),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withOpacity(0.15),
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
              ref
                  .read(screeningPlayerProvider(widget.sessionId).notifier)
                  .seek(Duration(milliseconds: (value * total).toInt()));
            },
            onChangeEnd: (value) {
              final newPos = Duration(milliseconds: (value * total).toInt());
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
