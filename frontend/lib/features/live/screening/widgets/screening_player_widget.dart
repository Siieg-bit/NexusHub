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
// ────────────────────────────────────────────────────────────────────────────────
// • Embed (WebView): YouTube, Twitch, Kick, Vimeo, Dailymotion
// • HLS nativo (media_kit): Tubi, Pluto TV, .m3u8 direto
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

  // Referência direta ao notifier guardada no initState para uso seguro no dispose.
  // Não usar ref.read() no dispose() pois o ConsumerStatefulElement já foi
  // desmontado nesse ponto e lança 'Bad state: Cannot use ref after disposed'.
  ScreeningPlayerNotifier? _playerNotifier;

  // ── Ambient gradient key ────────────────────────────────────────────────────────────────────────────────────────
  final _ambientGradientKey = GlobalKey<ScreeningAmbientGradientState>();

  // ── Fallback de erro nativo ───────────────────────────────────────────────
  // Quando o player nativo (media_kit) falha repetidamente (ex: DNS não resolve
  // para usher.twitchapps.com), este flag faz o widget usar o embed WebView
  // em vez do player nativo. Resetado quando a URL do vídeo muda.
  bool _nativeErrorOccurred = false;

  // ── Seek visual feedback ────────────────────────────────────────────────────────────────────────────────────────
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
        _playerNotifier = ref.read(
          screeningPlayerProvider(widget.sessionId).notifier,
        );
        _playerNotifier!.setThreadId(widget.threadId);
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
    // Usar _playerNotifier (guardado no initState) em vez de ref.read().
    // ref não pode ser usado no dispose() de ConsumerStatefulWidget pois o
    // ConsumerStatefulElement já foi desmontado antes do dispose() ser chamado.
    _playerNotifier?.unregisterWebViewController();
    _playerNotifier = null;
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

    // ── Detecção imediata de troca de vídeo ─────────────────────────────────
    // Quando a URL muda (troca de vídeo na fila), o InAppWebView é recriado
    // com nova key: ValueKey(url). Mas o _ScreeningPlayerWidgetState NÃO é
    // recriado — o _isLoading pode ser false do carregamento anterior.
    // O onWebViewCreated seta _isLoading=true, mas é assíncrono (chega depois
    // do primeiro frame do novo InAppWebView).
    //
    // Solução: ref.listen detecta a mudança de URL e seta _isLoading=true
    // IMEDIATAMENTE (síncrono, durante o build), antes do primeiro frame do
    // novo InAppWebView. Isso garante que o overlay preto cobre os badges
    // nativos do YouTube desde o frame zero.
    ref.listen(
      screeningRoomProvider(widget.threadId).select((s) => s.currentVideoUrl),
      (previous, next) {
        // O ref.listen do Riverpod é chamado FORA do ciclo de build (reativo),
        // portanto chamar setState() aqui é seguro e imediato.
        // Quando a URL muda (troca de vídeo), setar _isLoading=true
        // IMEDIATAMENTE para que o overlay preto já esteja visível antes
        // do primeiro frame do novo InAppWebView (que será recriado com
        // nova key: ValueKey(url) no próximo rebuild).
        if (previous != next && next != null && next.isNotEmpty && mounted) {
          setState(() {
            _isLoading = true;
            _nativeErrorOccurred = false; // reset ao trocar de vídeo
          });
        }
      },
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

        // ── Camada 0b: Gradiente ambiente (apenas para embed WebView não-live) ──
        // Desativado para Twitch/Kick/YouTubeLive: o canvas sampling (drawImage)
        // a cada 2s sobre um stream HLS ao vivo causa jank severo no Android.
        if (resolutionAsync.valueOrNull?.type == StreamType.embed &&
            resolutionAsync.valueOrNull?.platform != StreamPlatform.twitch &&
            resolutionAsync.valueOrNull?.platform != StreamPlatform.kick &&
            resolutionAsync.valueOrNull?.platform != StreamPlatform.youtubeLive)
          Positioned.fill(
            child: ScreeningAmbientGradient(
              key: _ambientGradientKey,
              sessionId: widget.sessionId,
              webViewController: _webViewController,
            ),
          ),

        // ── Camada 1: Buffering overlay ───────────────────────────────────
        // isInitialLoad=true → fundo preto sólido para ocultar badges nativos
        // do YouTube durante o carregamento inicial (antes do controls=0 ser
        // aplicado). isInitialLoad=false → semi-transparente para buffering.
        ScreeningLoadingOverlay(
          visible: _isLoading || isBuffering,
          isInitialLoad: _isLoading,
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
          // Informar ao provider se é live stream (Twitch HLS é sempre ao vivo).
          if (mounted) {
            final isLivePlatform = resolution.platform == StreamPlatform.twitch
                || resolution.platform == StreamPlatform.kick
                || resolution.platform == StreamPlatform.youtubeLive;
            ref
                .read(screeningPlayerProvider(widget.sessionId).notifier)
                .setIsLive(isLivePlatform);
          }
        });
        // Se o player nativo falhou (ex: DNS não resolve para Twitch),
        // usar embed WebView como fallback.
        if (_nativeErrorOccurred) {
          debugPrint('[ScreeningPlayer] Fallback para embed após erro nativo');
          return _buildDirectEmbedPlayer(context, StreamResolution(
            url: _toEmbedUrlFallback(resolution.originalUrl ?? resolution.url) ?? resolution.url,
            type: StreamType.embed,
            platform: resolution.platform,
            originalUrl: resolution.originalUrl ?? resolution.url,
          ));
        }
        return ScreeningNativePlayerWidget(
          key: ValueKey('${resolution.url}_${widget.sessionId}'),
          hlsUrl: resolution.url,
          sessionId: widget.sessionId,
          threadId: widget.threadId,
          platform: resolution.platform,
          resolution: resolution,
          onNativeError: () {
            if (mounted) setState(() => _nativeErrorOccurred = true);
          },
        );

      case StreamType.embed:
        // Para Twitch/Kick: carregar a URL do embed DIRETAMENTE no InAppWebView
        // (sem HTML wrapper com iframe). Isso permite que o _injectControlScript
        // acesse o DOM do player diretamente (document.querySelector('video'))
        // sem a barreira cross-origin do iframe.
        //
        // YouTube NÃO usa modo direto: o YouTube Erro 153 ocorre quando o embed
        // é carregado diretamente no WebView sem estar dentro de um <iframe> em
        // uma página com o origin correto. O HTML wrapper com baseUrl=nexushub.app
        // é a única forma de evitar o erro 153 para YouTube.
        if (resolution.platform == StreamPlatform.twitch ||
            resolution.platform == StreamPlatform.kick) {
          return _buildDirectEmbedPlayer(context, resolution);
        }
        // Para YouTube/Vimeo/outros: HTML wrapper com iframe embed.
        // O player já está posicionado abaixo do TopBar no layout Flutter,
        // por isso não é necessário padding-top no HTML.
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
            // User-Agent desktop: impede o YouTube de redirecionar para m.youtube.com
            // (versão mobile que exibe controles nativos e botões indesejados).
            // O embed youtube.com/embed/ funciona corretamente com UA desktop.
            userAgent:
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/124.0.0.0 Safari/537.36',
          ),
          onWebViewCreated: (controller) {
            // Resetar _isLoading=true sempre que um novo InAppWebView é criado
            // (inclusive ao trocar de vídeo via key: ValueKey(url)).
            // Garante que o overlay preto cobre os badges nativos do YouTube
            // durante o carregamento inicial de cada vídeo.
            _webViewController = controller;
            // BUGFIX AmbientGradient: setState força o rebuild do Stack, que
            // passa o controller atualizado ao ScreeningAmbientGradient via
            // didUpdateWidget. Sem isso, o gradient recebia null no construtor
            // e nunca era atualizado (variável local não causa rebuild).
            if (mounted) setState(() => _isLoading = true);
            final notifier = ref.read(screeningPlayerProvider(widget.sessionId).notifier);
            notifier.registerWebViewController(controller);
            // Informar ao provider se é live stream com base na plataforma.
            // Twitch, Kick e YouTubeLive são sempre ao vivo — a seek bar
            // não deve aparecer mesmo que o player reporte uma duração de DVR.
            final isLivePlatform = resolution.platform == StreamPlatform.twitch
                || resolution.platform == StreamPlatform.kick
                || resolution.platform == StreamPlatform.youtubeLive;
            notifier.setIsLive(isLivePlatform);
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
            // Para YouTube: NÃO remover o overlay aqui.
            // O overlay só é removido quando __YT_READY__ for recebido via
            // console.log, garantindo que os controles nativos (badges, botões)
            // já foram desabilitados pelo IFrame API antes de exibir o vídeo.
            // Para outros embeds (Kick, Twitch, Vimeo): remover imediatamente.
            final isYouTube = resolution.platform == StreamPlatform.youtube ||
                resolution.platform == StreamPlatform.youtubeLive;
            if (!isYouTube) {
              if (mounted) setState(() => _isLoading = false);
            }
            await _injectControlScript(controller);
            // Injetar o color sampler do AmbientGradient após o carregamento.
            // O _scheduleScriptInjection() do widget usa um Timer de 1.5s, mas
            // pode falhar se o controller ainda não estiver pronto. Injetar
            // diretamente aqui garante que o sampler rode após o onLoadStop.
            _ambientGradientKey.currentState?.injectColorSampler(controller);
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

  /// Player direto para Twitch/Kick: carrega a URL do embed diretamente no
  /// InAppWebView (sem HTML wrapper com iframe). O _injectControlScript acessa
  /// o DOM do player diretamente via document.querySelector('video').
  Widget _buildDirectEmbedPlayer(BuildContext context, StreamResolution resolution) {
    final embedUrl = resolution.url;
    final isLive = resolution.platform == StreamPlatform.twitch ||
        resolution.platform == StreamPlatform.kick;
    return InAppWebView(
      key: ValueKey('direct_$embedUrl'),
      initialUrlRequest: URLRequest(url: WebUri(embedUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        allowsAirPlayForMediaPlayback: true,
        // useHybridComposition: true para Twitch/Kick.
        // No Flutter 3.27+ / Android 14+, useHybridComposition:false ativa o
        // SurfaceProducer backend (Vulkan) que causa erros AHardwareBuffer em
        // dispositivos Qualcomm (formato pixel 0x3b não suportado pelo gralloc).
        // Com true (AndroidViewSurface/SurfaceTexture), a composição é feita
        // via SurfaceTexture que tem suporte universal em todos os dispositivos.
        useHybridComposition: true,
        supportZoom: false,
        disableHorizontalScroll: true,
        disableVerticalScroll: true,
        transparentBackground: true,
        // User-Agent mobile para Twitch/Kick (UI simplificada)
        userAgent:
            'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/124.0.0.0 Mobile Safari/537.36',
      ),
      onWebViewCreated: (controller) {
        if (mounted) setState(() => _isLoading = true);
        _webViewController = controller;
        final notifier = ref.read(screeningPlayerProvider(widget.sessionId).notifier);
        // forceWebMode: true — garante que o provider sai do modo nativo
        // (caso o ScreeningNativePlayerWidget ainda não tenha sido destruído
        // pelo Flutter quando o embed WebView é criado como fallback).
        notifier.registerWebViewController(controller, forceWebMode: true);
        notifier.setIsLive(isLive);
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
        ref.read(screeningPlayerProvider(widget.sessionId).notifier).onWebViewLoading();
      },
      onLoadStop: (controller, url) async {
        if (mounted) setState(() => _isLoading = false);
        // Injetar CSS para ocultar UI nativa da Twitch/Kick e bloquear toques
        await controller.evaluateJavascript(source: r'''
          (function() {
            // Injetar CSS para ocultar UI nativa da Twitch/Kick.
            // NÃO usar touch-action:none nem killEvent no document inteiro —
            // isso impede o autoplay da Twitch que depende de interação JS interna.
            // O bloqueio de toques do usuário é feito pelo #touch-blocker no
            // HTML wrapper (YouTube) ou pelo PointerInterceptor Flutter (Twitch/Kick).
            var style = document.createElement('style');
            style.textContent =
              // ── Twitch: ocultar header, follow, chat, controles do player ──
              '.top-nav, .top-bar, .channel-header, .follow-btn, .tw-button,' +
              '[data-a-target="follow-button"], [data-a-target="subscribe-button"],' +
              '[data-a-target="gift-button"], .player-controls, .player-ui,' +
              '.player-overlay-background, .player-overlay, .player-button,' +
              '.player-seek-bar, .player-volume, .player-settings,' +
              '.channel-info-content, .metadata-layout, .tw-title,' +
              // ── Kick: ocultar controles e header ──
              '.player-controls-wrapper, .player-header,' +
              // ── Kick: ocultar elementos adicionais ──
              '.vod-controls, .live-controls, .channel-info,' +
              '[class*="Controls"], [class*="controls"],' +
              '[class*="Header"], [class*="header"]' +
              ' { display: none !important; }' +
              // ── Vídeo ocupa 100% da tela ──
              'video { width: 100vw !important; height: 100vh !important;' +
              '  position: fixed !important; top: 0 !important; left: 0 !important;' +
              '  object-fit: contain !important; z-index: 1 !important;' +
              '  background: #000 !important; }';
            document.head.appendChild(style);
          })();
        ''');
        await _injectControlScript(controller);
        final notifier = ref.read(screeningPlayerProvider(widget.sessionId).notifier);
        notifier.markBridgeInjected();
        notifier.onWebViewReady();
      },
      onConsoleMessage: (controller, msg) {
        _handleConsoleMessage(msg.message);
      },
    );
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
        // User-Agent desktop: impede redirect para m.youtube.com
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/124.0.0.0 Safari/537.36',
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
    // O console.log é emitido SEMPRE como fallback robusto (funciona com qualquer
    // useHybridComposition). Para posição/duração: __YT_POS:N__ e __YT_DUR:N__.
    await controller.evaluateJavascript(source: r'''
      (function() {
        // Helper: notificar Flutter via handler nativo + console.log (sempre)
        // O callHandler falha silenciosamente no Android com useHybridComposition:false,
        // mas o console.log é capturado pelo onConsoleMessage e funciona sempre.
        function _bridge(event, data) {
          // Emitir console.log SEMPRE (fallback robusto)
          if (event === 'VIDEO_POSITION' && data !== undefined) {
            console.log('__YT_POS:' + data + '__');
          } else if (event === 'VIDEO_DURATION' && data !== undefined) {
            console.log('__YT_DUR:' + data + '__');
          } else if (event === 'VIDEO_PLAYING' || event === 'YT_PLAYING') {
            console.log('__YT_PLAYING__');
          } else if (event === 'VIDEO_PAUSED' || event === 'YT_PAUSED') {
            console.log('__YT_PAUSED__');
          } else if (event === 'VIDEO_BUFFERING' || event === 'YT_BUFFERING') {
            console.log('__YT_BUFFERING__');
          } else if (event === 'VIDEO_ENDED') {
            console.log('__VIDEO_ENDED__');
          } else {
            console.log('__' + event + '__');
          }
          // Tentar callHandler também (mais eficiente quando funciona)
          try {
            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
              if (data !== undefined) {
                window.flutter_inappwebview.callHandler('NexusPlayerBridge', event, data);
              } else {
                window.flutter_inappwebview.callHandler('NexusPlayerBridge', event);
              }
            }
          } catch(e) { /* silencioso */ }
        }

        // Definir _nexusPlayer apenas se ainda não foi injetado.
        // IMPORTANTE: nenhum método armazena referência estática ao _ytPlayer
        // (_yt foi removido). Todos consultam window._ytPlayer dinamicamente
        // em tempo de execução, eliminando o race condition onde _yt ficava
        // null porque onYouTubeIframeAPIReady ainda não havia sido chamado
        // no momento do onLoadStop.
        if (!window._nexusPlayer) {
          window._nexusPlayer = {
            play: function() {
              try {
                var yt = window._ytPlayer;
                if (yt && yt.playVideo) { yt.playVideo(); return; }
                var v = document.querySelector('video');
                if (v) v.play();
              } catch(e) {}
            },
            pause: function() {
              try {
                var yt = window._ytPlayer;
                if (yt && yt.pauseVideo) { yt.pauseVideo(); return; }
                var v = document.querySelector('video');
                if (v) v.pause();
              } catch(e) {}
            },
            seek: function(seconds) {
              try {
                // Cobrir controles que aparecem ao seekar no YouTube
                if (typeof window._showYtCovers === 'function') window._showYtCovers(3500);
                var yt = window._ytPlayer;
                if (yt && yt.seekTo) { yt.seekTo(seconds, true); return; }
                var v = document.querySelector('video');
                if (v) v.currentTime = seconds;
              } catch(e) {}
            },
            getPosition: function() {
              try {
                var yt = window._ytPlayer;
                if (yt && yt.getCurrentTime) return Math.floor(yt.getCurrentTime() * 1000);
                var v = document.querySelector('video');
                if (v && !isNaN(v.currentTime)) return Math.floor(v.currentTime * 1000);
              } catch(e) {}
              return -1;
            },
            getDuration: function() {
              try {
                var yt = window._ytPlayer;
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
                var yt = window._ytPlayer;
                if (yt && yt.setPlaybackRate) yt.setPlaybackRate(rate);
                var v = document.querySelector('video');
                if (v) v.playbackRate = rate;
              } catch(e) {}
            }
          };
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

        // Para Twitch/Kick no modo direto: desmutar apos autoplay.
        // muted=true foi necessario para autoplay funcionar no Chromium Android.
        // Como o script roda no contexto do player (nao cross-origin),
        // podemos desmutar diretamente via video.muted = false.
        if (video && video.muted) {
          // Tentar desmutar imediatamente
          try { video.muted = false; } catch(e) {}
          // Retry apos 1s e 2s caso o player ainda esteja inicializando
          setTimeout(function() { try { if(video.muted) video.muted = false; } catch(e) {} }, 1000);
          setTimeout(function() { try { if(video.muted) video.muted = false; } catch(e) {} }, 2000);
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
    if (message.contains('__YT_READY__')) {
      // YouTube IFrame API pronto: controles nativos já foram desabilitados
      // (controls=0 aplicado). Agora é seguro remover o overlay preto.
      if (mounted && _isLoading) setState(() => _isLoading = false);
    } else if (message.contains('__YT_PLAYING__') ||
        message.contains('__VIDEO_PLAYING__')) {
      notifier.onVideoPlaying();
      // Garantia extra: se ainda estiver loading quando o vídeo começar a tocar,
      // remover o overlay (fallback para embeds que não emitem __YT_READY__).
      if (mounted && _isLoading) setState(() => _isLoading = false);
    } else if (message.contains('__YT_PAUSED__') ||
        message.contains('__VIDEO_PAUSED__')) {
      notifier.onVideoPaused();
    } else if (message.contains('__YT_BUFFERING__') ||
        message.contains('__VIDEO_BUFFERING__')) {
      notifier.onVideoBuffering();
    } else if (message.contains('__VIDEO_ENDED__')) {
      notifier.onVideoEnded();
    }
    // Parsear posição e duração via console.log (fallback quando callHandler falha
    // no Android com useHybridComposition:false).
    // Formato: __YT_POS:12345__ (ms) e __YT_DUR:300000__ (ms)
    else if (message.contains('__YT_POS:')) {
      final match = RegExp(r'__YT_POS:(\d+)__').firstMatch(message);
      final posMs = int.tryParse(match?.group(1) ?? '');
      if (posMs != null && posMs >= 0) {
        notifier.onPositionUpdate(posMs);
        // Se a posição está chegando, o vídeo está carregado — remover overlay
        if (mounted && _isLoading) setState(() => _isLoading = false);
      }
    } else if (message.contains('__YT_DUR:')) {
      final match = RegExp(r'__YT_DUR:(\d+)__').firstMatch(message);
      final durMs = int.tryParse(match?.group(1) ?? '');
      if (durMs != null && durMs > 0) {
        notifier.onDurationUpdate(durMs);
      }
    }
    // Estado do player emitido a cada ciclo do _ytPositionTimer.
    // Garante que isPlaying seja corrigido mesmo após race condition no startup
    // (onStateChange disparado antes do onConsoleMessage estar registrado).
    else if (message.contains('__YT_STATE:playing__')) {
      notifier.onVideoPlaying();
      if (mounted && _isLoading) setState(() => _isLoading = false);
    } else if (message.contains('__YT_STATE:paused__')) {
      notifier.onVideoPaused();
    } else if (message.contains('__YT_STATE:buffering__')) {
      notifier.onVideoBuffering();
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
        // iv_load_policy=3: desativa info cards e anotações (badges nativos)
        // disablekb=1: desativa atalhos de teclado nativos do YouTube
        return 'https://www.youtube.com/embed/$id'
            '?autoplay=1&mute=0&rel=0&modestbranding=1'
            '&playsinline=1&enablejsapi=1&controls=0'
            '&iv_load_policy=3&disablekb=1&showinfo=0'
            '&fs=0&cc_load_policy=0&hl=pt&color=white'
            '&origin=https://nexushub.app';
      }
    }
    if (u.contains('twitch.tv')) {
      final match = RegExp(r'twitch\.tv/(?:videos/)?(\d+|[a-zA-Z0-9_]+)').firstMatch(url);
      final channel = match?.group(1) ?? '';
      if (channel.isNotEmpty) {
        final isVod = u.contains('/videos/');
        final twitchParam = isVod ? 'video=$channel' : 'channel=$channel';
        return 'https://player.twitch.tv/?$twitchParam'
            '&parent=nexushub.app&parent=localhost'
            '&autoplay=true&muted=true&controls=false';
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
    // Determina se é URL do YouTube para incluir a IFrame API.
    final isYouTube = embedUrl.contains('youtube') || embedUrl.contains('youtu.be');
    final isGoogleDrive = embedUrl.contains('drive.google.com');
    final ytApiScript = isYouTube
        ? '<script src="https://www.youtube.com/iframe_api"></script>'
        : '';
    // A maioria dos embeds é controlada por JS do NexusHub e deve ter os toques
    // bloqueados. Google Drive é exceção: o preview autenticado nem sempre
    // inicia por autoplay e pode exigir toque direto no botão nativo de play.
    final needsTouchBlocker = !isGoogleDrive;
    final iframePointerEvents = needsTouchBlocker ? 'none' : 'auto';
    final iframeTouchAction = needsTouchBlocker ? 'none' : 'auto';
    final touchBlockerHtml = needsTouchBlocker
        ? '<div id="touch-blocker"></div>'
        : '';
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  $ytApiScript
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%; height: 100%;
      background: #000;
      overflow: hidden;
      padding: 0; margin: 0;
      /* Impedir scroll/bounce nativo do WebView */
      touch-action: none;
      -webkit-overflow-scrolling: none;
      overscroll-behavior: none;
    }
    iframe {
      width: 100%; height: 100%;
      border: none; display: block;
      /* Todos os players: pointer-events:none.
         O NexusHub controla via JS injetado (window._nexusPlayer),
         nunca via interacao direta do usuario com o iframe. */
      pointer-events: $iframePointerEvents;
      touch-action: $iframeTouchAction;
    }
    /* Touch-blocker: ativo para TODOS os embeds.
       Bloqueia controles nativos de YouTube, Twitch, Kick, Vimeo etc. */
    #touch-blocker {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      z-index: 9999;
      background: transparent;
      pointer-events: all;
      touch-action: none;
      -webkit-touch-callout: none;
      -webkit-user-select: none;
      user-select: none;
      overscroll-behavior: none;
    }
    /* Overlay de pausa: cobre o iframe quando o vídeo está pausado para
       ocultar badges/end-cards nativos do YouTube. É completamente
       transparente (rgba 0,0,0,0) por padrão e fica opaco ao pausar. */
    #pause-overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      z-index: 9998;
      background: rgba(0, 0, 0, 0);
      pointer-events: none;
      transition: background 0.25s ease;
    }
    #pause-overlay.paused {
      background: rgba(0, 0, 0, 0.85);
    }
    /* ── Overlays de cobertura de controles do YouTube ──────────────────────
       O YouTube renderiza seus controles DENTRO do iframe, que é cross-origin.
       Não podemos injetar CSS no iframe (same-origin policy bloqueia).
       Solução: cobrir as áreas onde os controles aparecem com divs no
       documento pai que ficam na frente do iframe via z-index.

       Layout do player YouTube (proporções aproximadas):
         - Topo (~10%): .ytp-chrome-top (título, botões de share/watch-later)
         - Base (~12%): .ytp-chrome-bottom (seekbar, controles, volume)
         - Canto inf-dir: .ytp-watermark (logo YouTube)
         - Overlay de pausa: cobre tudo quando pausado (já tratado acima)

       Os overlays têm background #000 e opacity:0 (invisíveis ao usuário).
       O iframe fica atrás deles (z-index menor), então os controles do
       YouTube ficam ocultos sem afetar a área de vídeo no centro.
    */
    /* Transición suave para os overlays de cobertura */
    #yt-top-cover, #yt-bottom-cover, #yt-watermark-cover {
      position: fixed;
      z-index: 9997;
      background: #000;
      opacity: 0;
      pointer-events: none;
      transition: opacity 0.6s ease;
    }
    #yt-top-cover.visible, #yt-bottom-cover.visible, #yt-watermark-cover.visible {
      opacity: 1;
    }
    #yt-top-cover {
      top: 0; left: 0; right: 0;
      /* Altura do .ytp-chrome-top: ~8-12% da altura do player */
      height: 12%;
    }
    #yt-bottom-cover {
      bottom: 0; left: 0; right: 0;
      /* Altura do .ytp-chrome-bottom: ~10-14% da altura do player */
      height: 14%;
    }
    #yt-watermark-cover {
      /* Logo do YouTube: canto inferior direito, acima do chrome-bottom */
      bottom: 14%;
      right: 0;
      width: 15%;
      height: 8%;
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
<!-- Overlay de pausa: cobre badges/end-cards nativos do YouTube quando pausado -->
<div id="pause-overlay"></div>
<!-- Overlays de cobertura das áreas de controles do YouTube.
     Ficam na frente do iframe via z-index. São ativados temporariamente
     (opacity:1) após state changes para cobrir os controles durante
     o fade-in/out natural do YouTube, depois voltam a opacity:0. -->
<div id="yt-top-cover"></div>
<div id="yt-bottom-cover"></div>
<div id="yt-watermark-cover"></div>
<!-- Overlay transparente com pointer-events:all que intercepta TODOS os
     eventos de input antes de chegarem ao iframe do YouTube. O YouTube
     nunca recebe toques, swipes (horizontais ou verticais), cliques, etc.
     O player é controlado 100% via JavaScript injetado pelo Flutter. -->
$touchBlockerHtml
<script>
  // Helper: notificar Flutter via bridge nativo (instantâneo) com fallback console.log
  // IMPORTANTE: sempre emite console.log ALÉM do callHandler.
  // O callHandler falha silenciosamente no Android com useHybridComposition:false,
  // mas o console.log sempre funciona e é capturado pelo onConsoleMessage do Flutter.
  // Para posição/duração, usamos formato parseável: __YT_POS:12345__ e __YT_DUR:300000__
  function _ytBridge(event, data) {
    // Emitir console.log SEMPRE (funciona com qualquer useHybridComposition)
    if (event === 'VIDEO_POSITION' && data !== undefined) {
      console.log('__YT_POS:' + data + '__');
    } else if (event === 'VIDEO_DURATION' && data !== undefined) {
      console.log('__YT_DUR:' + data + '__');
    } else if (event === 'YT_PLAYING' || event === 'VIDEO_PLAYING') {
      console.log('__YT_PLAYING__');
    } else if (event === 'YT_PAUSED' || event === 'VIDEO_PAUSED') {
      console.log('__YT_PAUSED__');
    } else if (event === 'YT_BUFFERING' || event === 'VIDEO_BUFFERING') {
      console.log('__YT_BUFFERING__');
    } else if (event === 'VIDEO_ENDED') {
      console.log('__VIDEO_ENDED__');
    } else {
      console.log('__' + event + '__');
    }
    // Tentar callHandler também (mais eficiente quando funciona)
    try {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        if (data !== undefined) {
          window.flutter_inappwebview.callHandler('NexusPlayerBridge', event, data);
        } else {
          window.flutter_inappwebview.callHandler('NexusPlayerBridge', event);
        }
      }
    } catch(e) { /* silencioso */ }
  }

  // ── Overlays de cobertura de controles do YouTube ─────────────────────────
  // Ativa os overlays (topo, base, watermark) por [durationMs] ms e depois
  // faz fade-out suave. Usado para cobrir os controles nativos durante o
  // período em que o YouTube os exibe (após play, seek, state change).
  var _ytCoversTimer = null;
  function _showYtCovers(durationMs) {
    var top = document.getElementById('yt-top-cover');
    var bot = document.getElementById('yt-bottom-cover');
    var wm  = document.getElementById('yt-watermark-cover');
    if (top) top.classList.add('visible');
    if (bot) bot.classList.add('visible');
    if (wm)  wm.classList.add('visible');
    if (_ytCoversTimer) clearTimeout(_ytCoversTimer);
    _ytCoversTimer = setTimeout(function() {
      if (top) top.classList.remove('visible');
      if (bot) bot.classList.remove('visible');
      if (wm)  wm.classList.remove('visible');
    }, durationMs || 3500);
  }
  function _hideYtCovers() {
    if (_ytCoversTimer) { clearTimeout(_ytCoversTimer); _ytCoversTimer = null; }
    var top = document.getElementById('yt-top-cover');
    var bot = document.getElementById('yt-bottom-cover');
    var wm  = document.getElementById('yt-watermark-cover');
    if (top) top.classList.remove('visible');
    if (bot) bot.classList.remove('visible');
    if (wm)  wm.classList.remove('visible');
  }
  // Expor no window para acesso pelo _injectControlScript (IIFE)
  window._showYtCovers = _showYtCovers;
  window._hideYtCovers = _hideYtCovers;

  // Ativar overlays imediatamente ao carregar a página.
  // O YouTube exibe elementos de UI durante o carregamento e nos primeiros
  // segundos após o autoplay. Cobrir por 5s garante que não aparecem.
  // O onReady do YT.Player vai chamar _showYtCovers(4000) novamente.
  _showYtCovers(5000);

  // Timer de polling de posição para YouTube (substitui timeupdate do <video>)
  // O YT IFrame API não expoe eventos de timeupdate, então fazemos polling leve.
  // IMPORTANTE: emite também o estado de playing a cada ciclo via __YT_STATE:N__
  // para que o Flutter possa inferir isPlaying mesmo se o onStateChange foi
  // disparado antes do onConsoleMessage estar registrado (race condition no startup).
  var _ytPositionTimer = null;
  function _startYtPositionPolling(player) {
    if (_ytPositionTimer) clearInterval(_ytPositionTimer);
    _ytPositionTimer = setInterval(function() {
      try {
        var pos = Math.floor(player.getCurrentTime() * 1000);
        var dur = Math.floor(player.getDuration() * 1000);
        var state = player.getPlayerState(); // 1=playing, 2=paused, 3=buffering
        if (pos >= 0) _ytBridge('VIDEO_POSITION', pos);
        if (dur > 0)  _ytBridge('VIDEO_DURATION', dur);
        // Emitir estado atual a cada ciclo — garante que o Flutter saiba
        // se está tocando ou pausado mesmo após race condition no startup.
        if (state === 1) console.log('__YT_STATE:playing__');
        else if (state === 2) console.log('__YT_STATE:paused__');
        else if (state === 3) console.log('__YT_STATE:buffering__');
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
              // Cobrir controles nativos que aparecem nos primeiros segundos
              // O YouTube exibe o título e botões por ~3s ao iniciar
              _showYtCovers(4000);
              e.target.playVideo();
              // Injetar CSS diretamente no documento do iframe do YouTube.
              // O InAppWebView (WebView nativo) não aplica same-origin para
              // JS executado nativamente, então contentDocument é acessível.
              // Oculta: overlay de pausa, título, logo, badges, gradientes,
              // botões de share/watch-later e a seekbar nativa.
              try {
                var iframeDoc = e.target.getIframe().contentDocument ||
                                e.target.getIframe().contentWindow.document;
                if (iframeDoc) {
                  var s = iframeDoc.createElement('style');
                  s.id = 'nexus-yt-hide';
                  s.textContent = [
                    '.ytp-pause-overlay,',
                    '.ytp-pause-overlay-container,',
                    '.ytp-chrome-top,',
                    '.ytp-chrome-top-buttons,',
                    '.ytp-title,',
                    '.ytp-title-text,',
                    '.ytp-watermark,',
                    '.ytp-gradient-top,',
                    '.ytp-gradient-bottom,',
                    '.ytp-chrome-bottom,',
                    '.ytp-progress-bar-container,',
                    '.ytp-time-display,',
                    '.ytp-left-controls,',
                    '.ytp-right-controls,',
                    '.ytp-button,',
                    '.ytp-share-button,',
                    '.ytp-watch-later-button,',
                    '.ytp-copylink-button,',
                    '.ytp-settings-button,',
                    '.ytp-fullscreen-button,',
                    '.ytp-overflow-button,',
                    '.ytp-subtitles-button,',
                    '.ytp-cards-button,',
                    '.ytp-endscreen-element,',
                    '.ytp-ce-element,',
                    '.iv-branding,',
                    '.iv-card-cta,',
                    '.ytp-cards-teaser,',
                    '.ytp-spinner { display: none !important; }'
                  ].join('');
                  if (!iframeDoc.getElementById('nexus-yt-hide')) {
                    iframeDoc.head.appendChild(s);
                  }
                }
              } catch(cssErr) { /* cross-origin bloqueado — silencioso */ }
              // Notificar duração inicial — com retries caso o handler Flutter
              // ainda não esteja registrado no primeiro frame (race condition
              // entre onWebViewCreated Dart e onReady JS).
              var _ytTarget = e.target;
              function _sendDuration() {
                var dur = Math.floor(_ytTarget.getDuration() * 1000);
                if (dur > 0) _ytBridge('VIDEO_DURATION', dur);
              }
              _sendDuration();
              setTimeout(_sendDuration, 500);
              setTimeout(_sendDuration, 1500);
              setTimeout(_sendDuration, 3000);
            },
            onStateChange: function(e) {
              // -1=unstarted, 0=ended, 1=playing, 2=paused, 3=buffering
              var overlay = document.getElementById('pause-overlay');
              if (e.data === 1) {
                _ytBridge('YT_PLAYING');
                _startYtPositionPolling(e.target);
                // Cobrir controles que aparecem ao retomar reprodução
                // O YouTube exibe controles por ~3s ao dar play/resume
                _showYtCovers(3500);
                // Remover overlay de pausa ao retomar reprodução
                if (overlay) overlay.classList.remove('paused');
                // Notificar duração ao iniciar reprodução
                var dur = Math.floor(e.target.getDuration() * 1000);
                if (dur > 0) _ytBridge('VIDEO_DURATION', dur);
              } else if (e.data === 2) {
                _ytBridge('YT_PAUSED');
                _stopYtPositionPolling();
                // Esconder covers de controles (pause-overlay cobre tudo)
                _hideYtCovers();
                // Ativar overlay de pausa para ocultar badges/end-cards nativos
                if (overlay) overlay.classList.add('paused');
                // Notificar posição final ao pausar
                var pos = Math.floor(e.target.getCurrentTime() * 1000);
                if (pos >= 0) _ytBridge('VIDEO_POSITION', pos);
              } else if (e.data === 3) {
                _ytBridge('YT_BUFFERING');
                // Remover overlay ao bufferizar (vídeo vai retomar)
                if (overlay) overlay.classList.remove('paused');
              } else if (e.data === 0) {
                _ytBridge('VIDEO_ENDED');
                _stopYtPositionPolling();
                // Esconder covers (pause-overlay cobre end-cards)
                _hideYtCovers();
                // Ativar overlay ao terminar para ocultar end-cards
                if (overlay) overlay.classList.add('paused');
              }
            }
          }
        });
      }
    }
  }

  // ── Bloqueio total de input ─────────────────────────────────────────────────────
  // Estratégia de defesa em profundidade para impedir que a UI nativa do
  // YouTube (badges, logo, controles, seek bar) apareça por qualquer gesto:
  //
  // CAMADA 1 (CSS): iframe tem pointer-events:none e touch-action:none.
  //   O iframe nunca recebe eventos de ponteiro diretamente.
  //
  // CAMADA 2 (CSS): #touch-blocker tem pointer-events:all e touch-action:none.
  //   É uma barreira física transparente na frente do iframe que absorve
  //   TODOS os toques antes de chegarem ao iframe.
  //
  // CAMADA 3 (JS): event listeners no document e no #touch-blocker com
  //   capture:true e passive:false para cancelar qualquer evento residual.
  //   Cobre: touch, mouse (sintetizado pelo Chromium), pointer (API moderna),
  //   wheel (scroll), contextmenu, drag, gestos de zoom.
  //
  // IMPORTANTE: isso NÃO afeta o Flutter. Os toques são processados pela
  // camada nativa Android ANTES de chegarem à WebView. O player é controlado
  // 100% via JavaScript injetado pelo Flutter (window._nexusPlayer).
  (function() {
    function killEvent(e) {
      e.preventDefault();
      e.stopPropagation();
      e.stopImmediatePropagation();
      return false;
    }

    var capOpts  = { capture: true, passive: false };
    var capPassive = { capture: true, passive: true }; // para eventos que não permitem preventDefault

    // ─ Touch events (horizontal + vertical + qualquer direção) ───────────
    ['touchstart', 'touchmove', 'touchend', 'touchcancel'].forEach(function(ev) {
      document.addEventListener(ev, killEvent, capOpts);
      document.body.addEventListener(ev, killEvent, capOpts);
    });

    // ─ Mouse events (sintetizados pelo Chromium a partir de touch) ────────
    ['mousedown', 'mousemove', 'mouseup', 'mouseenter', 'mouseleave',
     'mouseover', 'mouseout', 'click', 'dblclick', 'contextmenu'].forEach(function(ev) {
      document.addEventListener(ev, killEvent, capOpts);
    });

    // ─ Pointer events (API moderna, usada pelo YouTube player) ──────────
    ['pointerdown', 'pointermove', 'pointerup', 'pointercancel',
     'pointerenter', 'pointerleave', 'pointerover', 'pointerout',
     'gotpointercapture', 'lostpointercapture'].forEach(function(ev) {
      document.addEventListener(ev, killEvent, capOpts);
    });

    // ─ Wheel / scroll (swipe vertical pode gerar scroll) ──────────────
    document.addEventListener('wheel', killEvent, capOpts);
    document.addEventListener('scroll', function(e) { e.stopPropagation(); }, capPassive);

    // ─ Drag events ──────────────────────────────────────────────────
    ['dragstart', 'drag', 'dragend', 'dragenter', 'dragleave',
     'dragover', 'drop'].forEach(function(ev) {
      document.addEventListener(ev, killEvent, capOpts);
    });

    // ─ Também no #touch-blocker (segunda linha de defesa) ──────────────
    var blocker = document.getElementById('touch-blocker');
    if (blocker) {
      ['touchstart', 'touchmove', 'touchend', 'touchcancel',
       'mousedown', 'mousemove', 'mouseup', 'click', 'dblclick',
       'pointerdown', 'pointermove', 'pointerup', 'pointercancel',
       'wheel', 'contextmenu'].forEach(function(ev) {
        blocker.addEventListener(ev, killEvent, capOpts);
      });
    }
  })();
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
