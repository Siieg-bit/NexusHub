import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_player_provider.dart';
import '../providers/screening_room_provider.dart';
import '../providers/screening_sync_provider.dart';
import '../models/sync_event.dart';
import 'screening_entry_animation.dart';

// =============================================================================
// ScreeningPlayerWidget — Player de vídeo imersivo via InAppWebView — Fase 3
//
// Melhorias sobre a Fase 2:
// ─────────────────────────────────────────────────────────────────────────────
// 1. BUFFERING OVERLAY: ScreeningLoadingOverlay com spinner duplo e fade suave
// 2. GESTOS DE DOUBLE-TAP: esquerdo/direito para seek ±10s (apenas host)
//    com indicador visual animado (_SeekIndicator)
// 3. EMPTY STATE POLIDO: ícone pulsante + chips de plataformas suportadas
// 4. EVENTO ENDED: notifica o provider quando o vídeo termina
// =============================================================================

class ScreeningPlayerWidget extends ConsumerStatefulWidget {
  final String sessionId;
  final String threadId;

  const ScreeningPlayerWidget({
    super.key,
    required this.sessionId,
    required this.threadId,
  });

  @override
  ConsumerState<ScreeningPlayerWidget> createState() =>
      _ScreeningPlayerWidgetState();
}

class _ScreeningPlayerWidgetState extends ConsumerState<ScreeningPlayerWidget>
    with TickerProviderStateMixin {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;

  // ── Seek visual feedback ──────────────────────────────────────────────────
  bool _showSeekLeft = false;
  bool _showSeekRight = false;
  late AnimationController _seekLeftController;
  late AnimationController _seekRightController;

  @override
  void initState() {
    super.initState();
    _seekLeftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _seekRightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _seekLeftController.dispose();
    _seekRightController.dispose();
    super.dispose();
  }

  // ── Double-tap seek ───────────────────────────────────────────────────────

  void _onDoubleTapLeft() {
    final roomState = ref.read(screeningRoomProvider(widget.threadId));
    if (!roomState.isHost) return;

    HapticFeedback.lightImpact();
    final playerState = ref.read(screeningPlayerProvider(widget.sessionId));
    final newPos = playerState.position - const Duration(seconds: 10);
    final clamped = newPos.isNegative ? Duration.zero : newPos;

    ref.read(screeningPlayerProvider(widget.sessionId).notifier).seek(clamped);
    ref.read(screeningSyncProvider(widget.sessionId).notifier).broadcastEvent(
          SyncEvent(
            type: SyncEventType.seek,
            positionMs: clamped.inMilliseconds,
            serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    setState(() => _showSeekLeft = true);
    _seekLeftController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showSeekLeft = false);
    });
  }

  void _onDoubleTapRight() {
    final roomState = ref.read(screeningRoomProvider(widget.threadId));
    if (!roomState.isHost) return;

    HapticFeedback.lightImpact();
    final playerState = ref.read(screeningPlayerProvider(widget.sessionId));
    final newPos = playerState.position + const Duration(seconds: 10);

    ref.read(screeningPlayerProvider(widget.sessionId).notifier).seek(newPos);
    ref.read(screeningSyncProvider(widget.sessionId).notifier).broadcastEvent(
          SyncEvent(
            type: SyncEventType.seek,
            positionMs: newPos.inMilliseconds,
            serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    setState(() => _showSeekRight = true);
    _seekRightController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showSeekRight = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(screeningRoomProvider(widget.threadId));
    final playerState = ref.watch(screeningPlayerProvider(widget.sessionId));
    final videoUrl = roomState.currentVideoUrl;

    if (videoUrl == null || videoUrl.isEmpty) {
      return _ScreeningEmptyState(isHost: roomState.isHost);
    }

    final embedUrl = _toEmbedUrl(videoUrl);
    final htmlContent = _buildHtmlWrapper(embedUrl);

    return Stack(
      children: [
        // ── Camada 0: Player WebView ──────────────────────────────────────
        InAppWebView(
          key: ValueKey(videoUrl),
          initialData: InAppWebViewInitialData(
            data: htmlContent,
            mimeType: 'text/html',
            encoding: 'utf-8',
            baseUrl: WebUri('https://nexushub.app'),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            allowsAirPlayForMediaPlayback: true,
            useHybridComposition: true,
            supportZoom: false,
            disableHorizontalScroll: true,
            disableVerticalScroll: true,
            transparentBackground: true,
            iframeAllow: 'autoplay; fullscreen; picture-in-picture',
            iframeAllowFullscreen: true,
          ),
          onWebViewCreated: (controller) {
            _webViewController = controller;
            ref
                .read(screeningPlayerProvider(widget.sessionId).notifier)
                .registerWebViewController(controller);
          },
          onLoadStart: (controller, url) {
            setState(() => _isLoading = true);
            ref
                .read(screeningPlayerProvider(widget.sessionId).notifier)
                .onWebViewLoading();
          },
          onLoadStop: (controller, url) async {
            setState(() => _isLoading = false);
            await _injectControlScript(controller);
            ref
                .read(screeningPlayerProvider(widget.sessionId).notifier)
                .onWebViewReady();
          },
          onConsoleMessage: (controller, msg) {
            _handleConsoleMessage(msg.message);
          },
        ),

        // ── Camada 1: Buffering overlay ───────────────────────────────────
        ScreeningLoadingOverlay(
          visible: _isLoading || playerState.isBuffering,
        ),

        // ── Camada 2: Gestos de double-tap (seek) ─────────────────────────
        Row(
          children: [
            // Metade esquerda — retroceder 10s
            Expanded(
              child: GestureDetector(
                onDoubleTap: _onDoubleTapLeft,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            // Metade direita — avançar 10s
            Expanded(
              child: GestureDetector(
                onDoubleTap: _onDoubleTapRight,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),

        // ── Indicador visual de seek esquerdo ─────────────────────────────
        if (_showSeekLeft)
          Positioned(
            left: 24,
            top: 0,
            bottom: 0,
            child: Center(
              child: _SeekIndicator(
                controller: _seekLeftController,
                isForward: false,
              ),
            ),
          ),

        // ── Indicador visual de seek direito ──────────────────────────────
        if (_showSeekRight)
          Positioned(
            right: 24,
            top: 0,
            bottom: 0,
            child: Center(
              child: _SeekIndicator(
                controller: _seekRightController,
                isForward: true,
              ),
            ),
          ),
      ],
    );
  }

  // ── JavaScript injection ──────────────────────────────────────────────────

  Future<void> _injectControlScript(InAppWebViewController controller) async {
    await controller.evaluateJavascript(source: r'''
      (function() {
        // ── window._nexusPlayer: interface unificada de controle ──
        window._nexusPlayer = {
          play: function() {
            if (window._ytPlayer && window._ytPlayer.playVideo) {
              window._ytPlayer.playVideo();
            } else {
              var v = document.querySelector('video');
              if (v) v.play();
            }
          },
          pause: function() {
            if (window._ytPlayer && window._ytPlayer.pauseVideo) {
              window._ytPlayer.pauseVideo();
            } else {
              var v = document.querySelector('video');
              if (v) v.pause();
            }
          },
          seek: function(seconds) {
            if (window._ytPlayer && window._ytPlayer.seekTo) {
              window._ytPlayer.seekTo(seconds, true);
            } else {
              var v = document.querySelector('video');
              if (v) v.currentTime = seconds;
            }
          },
          getCurrentTime: function() {
            if (window._ytPlayer && window._ytPlayer.getCurrentTime) {
              return window._ytPlayer.getCurrentTime();
            }
            var v = document.querySelector('video');
            return v ? v.currentTime : 0;
          },
          getDuration: function() {
            if (window._ytPlayer && window._ytPlayer.getDuration) {
              return window._ytPlayer.getDuration();
            }
            var v = document.querySelector('video');
            return v ? v.duration : 0;
          },
          isBuffering: function() {
            var v = document.querySelector('video');
            if (!v) return false;
            return v.networkState === 2 && v.readyState < 3;
          },
          setRate: function(rate) {
            if (window._ytPlayer && window._ytPlayer.setPlaybackRate) {
              window._ytPlayer.setPlaybackRate(rate);
            }
            var v = document.querySelector('video');
            if (v) v.playbackRate = rate;
          }
        };

        // ── YouTube IFrame API ──
        if (typeof YT !== 'undefined' && YT.Player) {
          var iframe = document.getElementById('player');
          if (iframe && iframe.src && iframe.src.includes('youtube')) {
            window._ytPlayer = new YT.Player(iframe, {
              events: {
                onReady: function(e) {
                  console.log('__YT_READY__');
                  e.target.playVideo();
                },
                onStateChange: function(e) {
                  if (e.data === YT.PlayerState.PLAYING) {
                    console.log('__YT_PLAYING__');
                  } else if (e.data === YT.PlayerState.PAUSED) {
                    console.log('__YT_PAUSED__');
                  } else if (e.data === YT.PlayerState.BUFFERING) {
                    console.log('__YT_BUFFERING__');
                  } else if (e.data === YT.PlayerState.ENDED) {
                    console.log('__VIDEO_ENDED__');
                  }
                }
              }
            });
          }
        }

        // ── HTML5 video genérico ──
        var video = document.querySelector('video');
        if (video) {
          video.addEventListener('playing', function() {
            console.log('__VIDEO_PLAYING__');
          });
          video.addEventListener('pause', function() {
            console.log('__VIDEO_PAUSED__');
          });
          video.addEventListener('waiting', function() {
            console.log('__VIDEO_BUFFERING__');
          });
          video.addEventListener('ended', function() {
            console.log('__VIDEO_ENDED__');
          });
        }
      })();
    ''');
  }

  void _handleConsoleMessage(String message) {
    final notifier =
        ref.read(screeningPlayerProvider(widget.sessionId).notifier);
    if (message.contains('__YT_PLAYING__') ||
        message.contains('__VIDEO_PLAYING__')) {
      notifier.onVideoPlaying();
    } else if (message.contains('__YT_PAUSED__') ||
        message.contains('__VIDEO_PAUSED__')) {
      notifier.onVideoPaused();
    } else if (message.contains('__YT_BUFFERING__') ||
        message.contains('__VIDEO_BUFFERING__')) {
      notifier.onVideoBuffering();
    } else if (message.contains('__VIDEO_ENDED__')) {
      notifier.onVideoEnded();
    }
  }

  // ── Helpers de URL ────────────────────────────────────────────────────────

  String _toEmbedUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('youtube.com') || u.contains('youtu.be')) {
      final id = _extractYouTubeId(url);
      if (id.isNotEmpty) {
        return 'https://www.youtube-nocookie.com/embed/$id'
            '?autoplay=1&mute=0&rel=0&modestbranding=1'
            '&playsinline=1&enablejsapi=1&origin=https://nexushub.app';
      }
    }
    if (u.contains('twitch.tv') && !u.contains('/clip')) {
      final match = RegExp(r'twitch\.tv/([a-zA-Z0-9_]+)').firstMatch(url);
      final channel = match?.group(1) ?? '';
      if (channel.isNotEmpty) {
        return 'https://player.twitch.tv/?channel=$channel'
            '&parent=nexushub.app&parent=localhost&autoplay=true';
      }
    }
    if (u.contains('vimeo.com')) {
      final match = RegExp(r'vimeo\.com/(\d+)').firstMatch(url);
      final id = match?.group(1) ?? '';
      if (id.isNotEmpty) {
        return 'https://player.vimeo.com/video/$id?autoplay=1&dnt=1';
      }
    }
    if (u.contains('kick.com')) {
      final match = RegExp(r'kick\.com/([a-zA-Z0-9_]+)').firstMatch(url);
      final channel = match?.group(1) ?? '';
      if (channel.isNotEmpty) {
        return 'https://player.kick.com/$channel?autoplay=true';
      }
    }
    return url;
  }

  String _extractYouTubeId(String url) {
    final patterns = [
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1) ?? '';
    }
    return '';
  }

  String _buildHtmlWrapper(String embedUrl) {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <script src="https://www.youtube.com/iframe_api"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%; height: 100%;
      background: #000; overflow: hidden;
    }
    iframe {
      width: 100%; height: 100%;
      border: none; display: block;
    }
  </style>
</head>
<body>
<iframe
  id="player"
  src="$embedUrl"
  allow="autoplay; fullscreen; picture-in-picture; encrypted-media"
  allowfullscreen
  allowtransparency="true"
  frameborder="0"
  scrolling="no"
></iframe>
<script>
  function onYouTubeIframeAPIReady() {
    var iframe = document.getElementById('player');
    if (iframe && iframe.src.includes('youtube')) {
      window._ytPlayer = new YT.Player('player', {
        events: {
          onReady: function(e) {
            console.log('__YT_READY__');
            e.target.playVideo();
          },
          onStateChange: function(e) {
            if (e.data === 1) console.log('__YT_PLAYING__');
            else if (e.data === 2) console.log('__YT_PAUSED__');
            else if (e.data === 3) console.log('__YT_BUFFERING__');
            else if (e.data === 0) console.log('__VIDEO_ENDED__');
          }
        }
      });
    }
  }
</script>
</body>
</html>''';
  }
}

// =============================================================================
// _ScreeningEmptyState — Estado vazio polido com animação e chips de plataforma
// =============================================================================

class _ScreeningEmptyState extends StatelessWidget {
  final bool isHost;

  const _ScreeningEmptyState({required this.isHost});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone animado com pulso suave
            Icon(
              Icons.movie_creation_outlined,
              color: Colors.white.withOpacity(0.15),
              size: 80,
            )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .fade(
                  begin: 0.15,
                  end: 0.4,
                  duration: 2000.ms,
                  curve: Curves.easeInOut,
                ),

            const SizedBox(height: 24),

            // Título
            Text(
              isHost ? 'Adicione um vídeo' : 'Aguardando o host',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms, delay: 200.ms)
                .slideY(begin: 0.1, end: 0.0, duration: 500.ms, delay: 200.ms),

            const SizedBox(height: 8),

            // Subtítulo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                isHost
                    ? 'Cole um link do YouTube, Twitch, Vimeo ou Kick para começar a sessão'
                    : 'O host ainda não adicionou um vídeo. Fique à vontade para conversar no chat!',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms, delay: 400.ms),

            if (isHost) ...[
              const SizedBox(height: 32),

              // Chips de plataformas suportadas
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: const [
                  _PlatformChip(label: '▶ YouTube'),
                  _PlatformChip(label: '🎮 Twitch'),
                  _PlatformChip(label: '🎬 Vimeo'),
                  _PlatformChip(label: '🟢 Kick'),
                ],
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 600.ms),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  final String label;

  const _PlatformChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// =============================================================================
// _SeekIndicator — Indicador visual de seek por double-tap
// =============================================================================

class _SeekIndicator extends StatelessWidget {
  final AnimationController controller;
  final bool isForward;

  const _SeekIndicator({
    required this.controller,
    required this.isForward,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final opacity = (1.0 - controller.value).clamp(0.0, 1.0);
        final scale = 1.0 + controller.value * 0.3;

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isForward
                        ? Icons.forward_10_rounded
                        : Icons.replay_10_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isForward ? '+10s' : '-10s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
