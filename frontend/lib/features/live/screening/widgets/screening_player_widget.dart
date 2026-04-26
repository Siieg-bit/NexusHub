import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_player_provider.dart';
import '../providers/screening_room_provider.dart';
import '../providers/screening_sync_provider.dart';
import '../models/sync_event.dart';

// =============================================================================
// ScreeningPlayerWidget — Player de vídeo imersivo via InAppWebView
//
// Ocupa toda a tela disponível (Camada 0 do Stack imersivo).
// Injeta JavaScript para controle de play/pause/seek e polling de posição.
// O host pode controlar o player; participantes recebem sync automático.
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

class _ScreeningPlayerWidgetState extends ConsumerState<ScreeningPlayerWidget> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(screeningRoomProvider(widget.threadId));
    final videoUrl = roomState.currentVideoUrl;

    if (videoUrl == null || videoUrl.isEmpty) {
      return _buildEmptyState(context, roomState.isHost);
    }

    final embedUrl = _toEmbedUrl(videoUrl);
    final htmlContent = _buildHtmlWrapper(embedUrl);

    return Stack(
      children: [
        // Player WebView
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
            // Injetar script de controle
            await _injectControlScript(controller);
            ref
                .read(screeningPlayerProvider(widget.sessionId).notifier)
                .onWebViewReady();
          },
          onConsoleMessage: (controller, msg) {
            // Processar eventos do player via console.log
            _handleConsoleMessage(msg.message);
          },
        ),

        // Loading overlay
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(
              color: Colors.white54,
              strokeWidth: 2,
            ),
          ),
      ],
    );
  }

  // ── Estado vazio (sem vídeo) ────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context, bool isHost) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.movie_outlined,
              color: Colors.white.withOpacity(0.3),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              isHost
                  ? 'Adicione um vídeo para começar'
                  : 'Aguardando o host adicionar um vídeo...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── JavaScript injection ────────────────────────────────────────────────────

  Future<void> _injectControlScript(InAppWebViewController controller) async {
    await controller.evaluateJavascript(source: '''
      (function() {
        // ── YouTube IFrame API ──
        if (window.YT && window.YT.Player) {
          var iframe = document.querySelector('iframe');
          if (iframe) {
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
    }
  }

  // ── Helpers de URL ──────────────────────────────────────────────────────────

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
