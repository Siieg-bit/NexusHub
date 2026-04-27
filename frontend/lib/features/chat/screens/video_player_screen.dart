// =============================================================================
// VideoPlayerScreen — Player de vídeo fullscreen para mensagens de chat
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    // Forçar orientação landscape ao abrir o player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await _controller.initialize();
      _controller.addListener(_onVideoUpdate);
      if (mounted) {
        setState(() => _isInitialized = true);
        _controller.play();
        // Esconder controles após 3s
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _controller.value.isPlaying) {
            setState(() => _showControls = false);
          }
        });
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    final isBuffering = _controller.value.isBuffering;
    if (isBuffering != _isBuffering) {
      setState(() => _isBuffering = isBuffering);
    }
    // Quando o vídeo termina, mostrar controles
    if (_controller.value.position >= _controller.value.duration &&
        _controller.value.duration > Duration.zero) {
      setState(() => _showControls = true);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoUpdate);
    _controller.dispose();
    // Restaurar orientações e UI
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls && _controller.value.isPlaying) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _controller.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _controller.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
    setState(() {});
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Vídeo ──────────────────────────────────────────────────────
            if (_isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              )
            else if (_hasError)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.white54, size: 48),
                    SizedBox(height: 12),
                    Text('Não foi possível reproduzir o vídeo',
                        style: TextStyle(color: Colors.white54)),
                  ],
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),

            // ── Buffering indicator ────────────────────────────────────────
            if (_isInitialized && _isBuffering)
              const Center(
                child: CircularProgressIndicator(
                    color: Colors.white70, strokeWidth: 2),
              ),

            // ── Controles ─────────────────────────────────────────────────
            if (_showControls)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.0, 0.2, 0.75, 1.0],
                    ),
                  ),
                  child: Column(
                    children: [
                      // ── Topo: botão fechar ─────────────────────────────
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_rounded,
                                    color: Colors.white, size: 24),
                                onPressed: () => context.pop(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // ── Centro: play/pause ─────────────────────────────
                      if (_isInitialized)
                        GestureDetector(
                          onTap: _togglePlayPause,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),

                      const Spacer(),

                      // ── Barra de progresso ─────────────────────────────
                      if (_isInitialized)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Column(
                            children: [
                              VideoProgressIndicator(
                                _controller,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(
                                  playedColor: Colors.white,
                                  bufferedColor: Colors.white38,
                                  backgroundColor: Colors.white12,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(
                                        _controller.value.position),
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12),
                                  ),
                                  Text(
                                    _formatDuration(
                                        _controller.value.duration),
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
