import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_player_provider.dart';
import '../providers/screening_room_provider.dart';
import '../providers/screening_sync_provider.dart';
import '../models/sync_event.dart';
import '../services/stream_resolver_service.dart';
import 'screening_entry_animation.dart';
import 'screening_ambient_gradient.dart';
import 'screening_native_player_widget.dart';

// =============================================================================
// ScreeningPlayerWidget — Player híbrido: embed (WebView) + HLS nativo
//
// Rodada 1 — Arquitetura híbrida:
// ─────────────────────────────────────────────────────────────────────────────
// • Embed (WebView): YouTube, Kick, Vimeo, Dailymotion
// • HLS nativo (media_kit): Twitch, Tubi, Pluto TV, .m3u8 direto
// • DRM relay (Rodada 3): Netflix, Disney+, Amazon, HBO
//
// O StreamResolverService detecta a plataforma e resolve a URL antes de
// renderizar o player. Um FutureProvider por URL garante que a resolução
// só acontece uma vez por URL (sem re-resolução em rebuilds).
// =============================================================================

// ── Provider de resolução de URL ─────────────────────────────────────────────
final _streamResolutionProvider = FutureProvider.autoDispose
    .family<StreamResolution, String>((ref, url) async {
  return StreamResolverService.resolve(url);
});

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

  // ── Ambient gradient key ──────────────────────────────────────────────────
  final _ambientGradientKey = GlobalKey<ScreeningAmbientGradientState>();

  // ── Seek visual feedback ──────────────────────────────────────────────────
  bool _showSeekLeft = false;
  bool _showSeekRight = false;
  late AnimationController _seekLeftController;
  late AnimationController _seekRightController;

  @override
  void initState() {
    super.initState();
    // Injetar threadId no player provider para auto-avanço de fila
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(screeningPlayerProvider(widget.sessionId).notifier)
            .setThreadId(widget.threadId);
      }
    });
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
    final videoUrl = ref.watch(
      screeningRoomProvider(widget.threadId).select((s) => s.currentVideoUrl),
    );
    final isHost = ref.watch(
      screeningRoomProvider(widget.threadId).select((s) => s.isHost),
    );
    final isBuffering = ref.watch(
      screeningPlayerProvider(widget.sessionId).select((s) => s.isBuffering),
    );

    if (videoUrl == null || videoUrl.isEmpty) {
      return _ScreeningEmptyState(isHost: isHost);
    }

    // Resolver a URL (detecta plataforma + extrai HLS se necessário)
    final resolutionAsync = ref.watch(_streamResolutionProvider(videoUrl));

    return Stack(
      children: [
        // ── Camada 0: Player (híbrido) ────────────────────────────────────
        resolutionAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          error: (error, _) => _buildErrorFallback(context, videoUrl, error.toString()),
          data: (resolution) => _buildPlayer(context, resolution),
        ),

        // ── Camada 0b: Gradiente ambiente (apenas para embed WebView) ─────
        if (resolutionAsync.valueOrNull?.type == StreamType.embed)
          Positioned.fill(
            child: ScreeningAmbientGradient(
              key: _ambientGradientKey,
              sessionId: widget.sessionId,
              webViewController: _webViewController,
            ),
          ),

        // ── Camada 1: Buffering overlay ───────────────────────────────────
        ScreeningLoadingOverlay(
          visible: _isLoading || isBuffering,
        ),

        // ── Camada 2: Gestos de double-tap (seek) ─────────────────────────
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onDoubleTap: _onDoubleTapLeft,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onDoubleTap: _onDoubleTapRight,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),

        // ── Indicadores de seek ───────────────────────────────────────────
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

  // ── Construção do player conforme o tipo de stream ────────────────────────

  Widget _buildPlayer(BuildContext context, StreamResolution resolution) {
    switch (resolution.type) {
      case StreamType.hls:
      case StreamType.direct:
        // Player nativo via media_kit.
        // O _isLoading é controlado pelo próprio ScreeningNativePlayerWidget
        // via onNativePlay/onNativeBuffering no provider. Garantir que o
        // overlay de loading do WebView não fique preso em true.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isLoading) setState(() => _isLoading = false);
        });
        return ScreeningNativePlayerWidget(
          key: ValueKey(resolution.url),
          hlsUrl: resolution.url,
          sessionId: widget.sessionId,
          threadId: widget.threadId,
          platform: resolution.platform,
        );

      case StreamType.embed:
        // WebView com iframe embed
        final mq = MediaQuery.of(context);
        // topPaddingPx: status bar + altura do ScreeningTopBar (≈48px)
        // Isso garante que o conteúdo do iframe não fique atrás do TopBar
        // em dispositivos onde o WebView ignora o z-order do Flutter.
        final topPad = mq.padding.top + 48.0;
        final htmlContent = _buildHtmlWrapper(resolution.url, topPaddingPx: topPad);
        return InAppWebView(
          key: ValueKey(resolution.url),
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
                .markBridgeInjected();
            ref
                .read(screeningPlayerProvider(widget.sessionId).notifier)
                .onWebViewReady();
          },
          onConsoleMessage: (controller, msg) {
            _handleConsoleMessage(msg.message);
            if (msg.message.startsWith('__nexus_color:')) {
              _ambientGradientKey.currentState?.handleColorMessage(msg.message);
            }
          },
        );
    }
  }

  /// Fallback: se a resolução falhar, tenta o embed direto da URL original.
  Widget _buildErrorFallback(BuildContext context, String url, String error) {
    debugPrint('[ScreeningPlayer] Resolução falhou: $error — usando embed direto');
    final embedUrl = _toEmbedUrlFallback(url);
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top + 48.0;
    final htmlContent = _buildHtmlWrapper(embedUrl, topPaddingPx: topPad);
    return InAppWebView(
      key: ValueKey('fallback_$url'),
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
        useHybridComposition: true,
        supportZoom: false,
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
      onLoadStop: (controller, url) async {
        setState(() => _isLoading = false);
        await _injectControlScript(controller);
        ref
            .read(screeningPlayerProvider(widget.sessionId).notifier)
            .markBridgeInjected();
        ref
            .read(screeningPlayerProvider(widget.sessionId).notifier)
            .onWebViewReady();
      },
      onConsoleMessage: (controller, msg) => _handleConsoleMessage(msg.message),
    );
  }

  // ── JavaScript injection ──────────────────────────────────────────────────

  Future<void> _injectControlScript(InAppWebViewController controller) async {
    // Injeta o bridge unificado window._nexusPlayer.
    //
    // IMPORTANTE: o HTML do _buildHtmlWrapper já registra onYouTubeIframeAPIReady
    // que cria window._ytPlayer. Este script NÃO recria o YT.Player para evitar
    // duplicação. Em vez disso, apenas define window._nexusPlayer (se ainda não
    // existir) e conecta os event listeners do <video> HTML5.
    await controller.evaluateJavascript(source: r'''
      (function() {
        // Definir _nexusPlayer apenas se ainda não foi injetado
        if (!window._nexusPlayer) {
          window._nexusPlayer = {
            _yt: window._ytPlayer || null,

            play: function() {
              var yt = this._yt || window._ytPlayer;
              if (yt && yt.playVideo) { yt.playVideo(); return; }
              var v = document.querySelector('video');
              if (v) v.play();
            },
            pause: function() {
              var yt = this._yt || window._ytPlayer;
              if (yt && yt.pauseVideo) { yt.pauseVideo(); return; }
              var v = document.querySelector('video');
              if (v) v.pause();
            },
            seek: function(seconds) {
              var yt = this._yt || window._ytPlayer;
              if (yt && yt.seekTo) { yt.seekTo(seconds, true); return; }
              var v = document.querySelector('video');
              if (v) v.currentTime = seconds;
            },
            getPosition: function() {
              try {
                var yt = this._yt || window._ytPlayer;
                if (yt && yt.getCurrentTime) return Math.floor(yt.getCurrentTime() * 1000);
                var v = document.querySelector('video');
                if (v && !isNaN(v.currentTime)) return Math.floor(v.currentTime * 1000);
              } catch(e) {}
              return -1;
            },
            getDuration: function() {
              try {
                var yt = this._yt || window._ytPlayer;
                if (yt && yt.getDuration) {
                  var d = yt.getDuration();
                  if (d > 0) return Math.floor(d * 1000);
                }
                var v = document.querySelector('video');
                if (v && !isNaN(v.duration) && v.duration > 0) return Math.floor(v.duration * 1000);
              } catch(e) {}
              return 0;
            },
            isBuffering: function() {
              try {
                var v = document.querySelector('video');
                if (v) return v.networkState === 2 && v.readyState < 3;
              } catch(e) {}
              return false;
            },
            setRate: function(rate) {
              try {
                var yt = this._yt || window._ytPlayer;
                if (yt && yt.setPlaybackRate) yt.setPlaybackRate(rate);
                var v = document.querySelector('video');
                if (v) v.playbackRate = rate;
              } catch(e) {}
            }
          };
        } else {
          // Já existe: apenas atualizar a referência ao _ytPlayer se disponível
          if (window._ytPlayer && !window._nexusPlayer._yt) {
            window._nexusPlayer._yt = window._ytPlayer;
          }
        }

        // Registrar event listeners do <video> HTML5 (idempotente via flag)
        var video = document.querySelector('video');
        if (video && !video._nexusListenersAttached) {
          video._nexusListenersAttached = true;
          video.addEventListener('playing', function() { console.log('__VIDEO_PLAYING__'); });
          video.addEventListener('pause',   function() { console.log('__VIDEO_PAUSED__'); });
          video.addEventListener('waiting', function() { console.log('__VIDEO_BUFFERING__'); });
          video.addEventListener('ended',   function() { console.log('__VIDEO_ENDED__'); });
        }
      })();
    ''');
  }

  void _handleConsoleMessage(String message) {
    if (!mounted) return;
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

  // ── Fallback embed URL (sem API) ──────────────────────────────────────────

  String _toEmbedUrlFallback(String url) {
    final u = url.toLowerCase();
    if (u.contains('youtube.com') || u.contains('youtu.be')) {
      final id = _extractYouTubeId(url);
      if (id.isNotEmpty) {
        // Usar youtube.com/embed para que o postMessage do IFrame API
        // funcione corretamente com o baseUrl 'https://nexushub.app'.
        return 'https://www.youtube.com/embed/$id'
            '?autoplay=1&mute=0&rel=0&modestbranding=1'
            '&playsinline=1&enablejsapi=1&origin=https://nexushub.app';
      }
    }
    if (u.contains('twitch.tv')) {
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
      RegExp(r'youtube\.com/live/([a-zA-Z0-9_-]{11})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1) ?? '';
    }
    return '';
  }

  /// Constrói o HTML wrapper para o embed do player.
  /// [topPaddingPx] é o padding-top em pixels para evitar que o vídeo
  /// fique atrás do ScreeningTopBar (status bar + altura da barra).
  String _buildHtmlWrapper(String embedUrl, {double topPaddingPx = 0}) {
    // Determina se é URL do YouTube para incluir a IFrame API
    final isYouTube = embedUrl.contains('youtube') || embedUrl.contains('youtu.be');
    final ytApiScript = isYouTube
        ? '<script src="https://www.youtube.com/iframe_api"></script>'
        : '';
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  $ytApiScript
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
    body { padding-top: \${topPaddingPx.toStringAsFixed(0)}px; }
    iframe { width: 100%; height: calc(100% - \${topPaddingPx.toStringAsFixed(0)}px); border: none; display: block; }
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
  // Bridge unificado: cria window._nexusPlayer e window._ytPlayer via YT IFrame API.
  // Nota: NÃO define window._nexusPlayer aqui — ele será injetado pelo Flutter
  // via _injectControlScript após onLoadStop, garantindo que o YT.Player já
  // esteja inicializado e evitando duplicação.
  function onYouTubeIframeAPIReady() {
    var iframe = document.getElementById('player');
    if (iframe && iframe.src && iframe.src.includes('youtube')) {
      // Criar apenas UMA instância do YT.Player
      if (!window._ytPlayer) {
        window._ytPlayer = new YT.Player('player', {
          events: {
            onReady: function(e) {
              console.log('__YT_READY__');
              e.target.playVideo();
              // Atualizar referência no _nexusPlayer se já foi injetado
              if (window._nexusPlayer) window._nexusPlayer._yt = e.target;
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
  }
</script>
</body>
</html>''';
  }
}

// =============================================================================
// _ScreeningEmptyState
// =============================================================================
class _ScreeningEmptyState extends StatelessWidget {
  final bool isHost;
  const _ScreeningEmptyState({required this.isHost});
  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
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
                color: Colors.black.withValues(alpha: 0.55),
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
