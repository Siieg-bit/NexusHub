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
    // Notificar o provider que o WebView foi destruído para evitar
    // MissingPluginException em evaluateJavascript após dispose.
    ref
        .read(screeningPlayerProvider(widget.sessionId).notifier)
        .unregisterWebViewController();
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
        // WebView com iframe embed.
        // O player já está posicionado abaixo do TopBar no layout Flutter,
        // por isso não é necessário padding-top no HTML.
        //
        // IMPORTANTE: baseUrl deve ser 'https://nexushub.app' (não youtube.com).
        // Usar baseUrl=youtube.com causa erro 152-4 (embed não permitido) porque
        // o YouTube bloqueia embeds que parecem vir do próprio domínio youtube.com.
        // O postMessage do IFrame API funciona via window.addEventListener('message')
        // no HTML wrapper, independente do baseUrl.
        final htmlContent = _buildHtmlWrapper(resolution.url);
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
            // useHybridComposition: false (AndroidView em vez de AndroidViewSurface)
            // Com false, widgets Flutter sobrepostos recebem toques normalmente.
            // Com true (AndroidViewSurface), a WebView captura todos os toques
            // no nível do Android, impedindo que o ScreeningControlsOverlay
            // receba cliques. O pointer_interceptor não funciona no Android.
            useHybridComposition: false,
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
            // Handler nativo JS→Flutter para eventos do player
            // Mais eficiente que console.log polling: o JS chama diretamente
            controller.addJavaScriptHandler(
              handlerName: 'NexusPlayerBridge',
              callback: (args) {
                if (args.isEmpty || !mounted) return;
                _handleBridgeEvent(
                  args[0].toString(),
                  args.length > 1 ? args[1] : null,
                );
              },
            );
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
    final htmlContent = _buildHtmlWrapper(embedUrl);
    // baseUrl sempre nexushub.app — youtube.com como baseUrl causa erro 152-4
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
        useHybridComposition: false,  // false para permitir toques nos controles Flutter
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
        // Handler nativo JS→Flutter para eventos do player (fallback)
        controller.addJavaScriptHandler(
          handlerName: 'NexusPlayerBridge',
          callback: (args) {
            if (args.isEmpty || !mounted) return;
            _handleBridgeEvent(
              args[0].toString(),
              args.length > 1 ? args[1] : null,
            );
          },
        );
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
    // Usa window.flutter_inappwebview.callHandler('NexusPlayerBridge', event, data)
    // para notificar o Flutter de forma nativa (sem polling de console.log).
    // O console.log permanece como fallback para compatibilidade.
    await controller.evaluateJavascript(source: r'''
      (function() {
        // Helper: notificar Flutter via handler nativo (instantâneo)
        function _bridge(event, data) {
          try {
            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
              window.flutter_inappwebview.callHandler('NexusPlayerBridge', event, data);
            } else {
              // Fallback: console.log para compatibilidade
              console.log('__' + event.toUpperCase() + '__');
            }
          } catch(e) {
            console.log('__' + event.toUpperCase() + '__');
          }
        }

        // Definir _nexusPlayer apenas se ainda não foi injetado
        if (!window._nexusPlayer) {
          window._nexusPlayer = {
            _yt: window._ytPlayer || null,

            play: function() {
              try {
                var yt = this._yt || window._ytPlayer;
                if (yt && yt.playVideo) { yt.playVideo(); return; }
                var v = document.querySelector('video');
                if (v) v.play();
              } catch(e) {}
            },
            pause: function() {
              try {
                var yt = this._yt || window._ytPlayer;
                if (yt && yt.pauseVideo) { yt.pauseVideo(); return; }
                var v = document.querySelector('video');
                if (v) v.pause();
              } catch(e) {}
            },
            seek: function(seconds) {
              try {
                var yt = this._yt || window._ytPlayer;
                if (yt && yt.seekTo) { yt.seekTo(seconds, true); return; }
                var v = document.querySelector('video');
                if (v) v.currentTime = seconds;
              } catch(e) {}
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
          video.addEventListener('playing', function() {
            _bridge('VIDEO_PLAYING');
            // Notificar posição e duração ao iniciar reprodução
            var pos = window._nexusPlayer ? window._nexusPlayer.getPosition() : -1;
            var dur = window._nexusPlayer ? window._nexusPlayer.getDuration() : 0;
            if (pos >= 0) _bridge('VIDEO_POSITION', pos);
            if (dur > 0)  _bridge('VIDEO_DURATION', dur);
          });
          video.addEventListener('pause',   function() { _bridge('VIDEO_PAUSED'); });
          video.addEventListener('waiting', function() { _bridge('VIDEO_BUFFERING'); });
          video.addEventListener('ended',   function() { _bridge('VIDEO_ENDED'); });
          video.addEventListener('durationchange', function() {
            if (!isNaN(video.duration) && video.duration > 0) {
              _bridge('VIDEO_DURATION', Math.floor(video.duration * 1000));
            }
          });
          video.addEventListener('timeupdate', function() {
            // Throttle: notificar posição a cada ~500ms via timeupdate
            var now = Date.now();
            if (!video._lastBridgeTime || now - video._lastBridgeTime > 500) {
              video._lastBridgeTime = now;
              if (!isNaN(video.currentTime)) {
                _bridge('VIDEO_POSITION', Math.floor(video.currentTime * 1000));
              }
            }
          });
        }

        // Para YouTube: conectar eventos do YT.Player ao bridge
        // (os eventos onStateChange do HTML já estão no _buildHtmlWrapper)
        // Aqui apenas garantimos que _nexusPlayer._yt está atualizado
        if (window._ytPlayer && window._nexusPlayer) {
          window._nexusPlayer._yt = window._ytPlayer;
        }
      })();
    ''');
  }

  /// Processa eventos recebidos via JavaScriptHandler 'NexusPlayerBridge'.
  /// Mais eficiente que console.log: chamada nativa direta JS→Flutter.
  void _handleBridgeEvent(String event, dynamic data) {
    if (!mounted) return;
    final notifier = ref.read(screeningPlayerProvider(widget.sessionId).notifier);
    switch (event) {
      case 'VIDEO_PLAYING':
      case 'YT_PLAYING':
        notifier.onVideoPlaying();
        break;
      case 'VIDEO_PAUSED':
      case 'YT_PAUSED':
        notifier.onVideoPaused();
        break;
      case 'VIDEO_BUFFERING':
      case 'YT_BUFFERING':
        notifier.onVideoBuffering();
        break;
      case 'VIDEO_ENDED':
        notifier.onVideoEnded();
        break;
      case 'VIDEO_POSITION':
        // Atualização de posição via timeupdate (substitui polling)
        final posMs = (data as num?)?.toInt();
        if (posMs != null && posMs >= 0) {
          notifier.onPositionUpdate(posMs);
        }
        break;
      case 'VIDEO_DURATION':
        final durMs = (data as num?)?.toInt();
        if (durMs != null && durMs > 0) {
          notifier.onDurationUpdate(durMs);
        }
        break;
    }
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
        // origin= deve bater com o baseUrl do InAppWebView ('https://nexushub.app').
        // controls=0 oculta os controles nativos do YouTube.
        return 'https://www.youtube.com/embed/$id'
            '?autoplay=1&mute=0&rel=0&modestbranding=1'
            '&playsinline=1&enablejsapi=1&controls=0'
            '&origin=https://nexushub.app';
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
  /// O player já está posicionado abaixo do TopBar no layout Flutter.
  String _buildHtmlWrapper(String embedUrl) {
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
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; padding: 0; margin: 0; }
    iframe { width: 100%; height: 100%; border: none; display: block; }
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
  // Helper: notificar Flutter via bridge nativo (instantâneo) com fallback console.log
  function _ytBridge(event, data) {
    try {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        if (data !== undefined) {
          window.flutter_inappwebview.callHandler('NexusPlayerBridge', event, data);
        } else {
          window.flutter_inappwebview.callHandler('NexusPlayerBridge', event);
        }
      } else {
        console.log('__' + event + '__');
      }
    } catch(e) {
      console.log('__' + event + '__');
    }
  }

  // Timer de polling de posição para YouTube (substitui timeupdate do <video>)
  // O YT IFrame API não expoe eventos de timeupdate, então fazemos polling leve
  var _ytPositionTimer = null;
  function _startYtPositionPolling(player) {
    if (_ytPositionTimer) clearInterval(_ytPositionTimer);
    _ytPositionTimer = setInterval(function() {
      try {
        var pos = Math.floor(player.getCurrentTime() * 1000);
        var dur = Math.floor(player.getDuration() * 1000);
        if (pos >= 0) _ytBridge('VIDEO_POSITION', pos);
        if (dur > 0)  _ytBridge('VIDEO_DURATION', dur);
      } catch(e) {}
    }, 500);
  }
  function _stopYtPositionPolling() {
    if (_ytPositionTimer) { clearInterval(_ytPositionTimer); _ytPositionTimer = null; }
  }

  // Bridge unificado: cria window._ytPlayer via YT IFrame API.
  // window._nexusPlayer será injetado pelo Flutter via _injectControlScript
  // após onLoadStop, garantindo que o YT.Player já esteja inicializado.
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
              // Notificar duração inicial
              var dur = Math.floor(e.target.getDuration() * 1000);
              if (dur > 0) _ytBridge('VIDEO_DURATION', dur);
            },
            onStateChange: function(e) {
              // -1=unstarted, 0=ended, 1=playing, 2=paused, 3=buffering
              if (e.data === 1) {
                _ytBridge('YT_PLAYING');
                _startYtPositionPolling(e.target);
                // Notificar duração ao iniciar reprodução
                var dur = Math.floor(e.target.getDuration() * 1000);
                if (dur > 0) _ytBridge('VIDEO_DURATION', dur);
              } else if (e.data === 2) {
                _ytBridge('YT_PAUSED');
                _stopYtPositionPolling();
                // Notificar posição final ao pausar
                var pos = Math.floor(e.target.getCurrentTime() * 1000);
                if (pos >= 0) _ytBridge('VIDEO_POSITION', pos);
              } else if (e.data === 3) {
                _ytBridge('YT_BUFFERING');
              } else if (e.data === 0) {
                _ytBridge('VIDEO_ENDED');
                _stopYtPositionPolling();
              }
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
