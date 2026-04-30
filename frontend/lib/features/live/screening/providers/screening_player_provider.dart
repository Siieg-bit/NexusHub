import 'dart:async';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import '../models/screening_player_state.dart';
import 'screening_room_provider.dart';

// =============================================================================
// ScreeningPlayerProvider — Gerencia o estado do player de vídeo (Fase 2)
//
// Melhorias sobre a Fase 1:
// ─────────────────────────────────────────────────────────────────────────────
// 1. JS UNIFICADO: script _kPlayerBridgeJs injeta uma camada de abstração
//    window._nexusPlayer que normaliza YouTube IFrame API, Twitch Player API
//    e HTML5 <video> em uma interface única. Reduz duplicação de código e
//    facilita adicionar novas plataformas.
//
// 2. DURATION DETECTION: ao carregar o vídeo, tenta obter a duração total
//    para exibir a barra de progresso corretamente.
//
// 3. BUFFER DETECTION: monitora readyState e networkState do <video> para
//    detectar buffering real (não apenas ausência de play).
//
// 4. POLLING INTELIGENTE: ao pausar, reduz o polling para 5s (economiza
//    recursos). Ao dar play, volta para 1s.
//
// 5. RETRY DE COMANDOS: play/pause/seek tentam até 3x com 300ms de intervalo
//    se o controller ainda não estiver pronto.
//
// 6. onVideoEnded: notifica quando o vídeo termina (para o host poder
//    exibir o painel de próximo vídeo).
//
// 7. MODO NATIVO: quando _isNativeMode=true, todos os comandos (play/pause/
//    seek/setRate) são roteados para o player nativo (media_kit ou DRM) e o
//    polling via evaluateJavascript é completamente desabilitado — evita o
//    MissingPluginException que ocorria quando o WebView era destruído após
//    a Twitch/HLS assumir o player.
// =============================================================================

// ── JavaScript Bridge ─────────────────────────────────────────────────────────
// Injeta window._nexusPlayer como abstração unificada sobre as APIs de cada
// plataforma. Injetado via onLoadStop do WebView.

const _kPlayerBridgeJs = r'''
(function() {
  if (window._nexusPlayer) return; // já injetado

  // Função auxiliar para emitir eventos via console.log (capturado pelo Flutter)
  function _emit(event) {
    if (event === 'playing') console.log('__YT_PLAYING__');
    else if (event === 'paused') console.log('__YT_PAUSED__');
    else if (event === 'buffering') console.log('__YT_BUFFERING__');
    else if (event === 'ended') console.log('__VIDEO_ENDED__');
    else if (event === 'ready') console.log('__YT_READY__');
  }

  window._nexusPlayer = {
    _yt: null,

    // ── Conectar ao YT.Player já criado pelo onYouTubeIframeAPIReady ─────────
    // NÃO cria um novo YT.Player para evitar conflito com o _ytPlayer
    // criado pelo _buildHtmlWrapper. Apenas conecta ao existente.
    initYT: function() {
      if (window._ytPlayer && !this._yt) {
        this._yt = window._ytPlayer;
      }
    },

    // ── Obter posição atual (ms) ────────────────────────────────────────────
    getPosition: function() {
      try {
        if (this._yt && this._yt.getCurrentTime) {
          return Math.floor(this._yt.getCurrentTime() * 1000);
        }
        // window._ytPlayer (legacy)
        if (window._ytPlayer && window._ytPlayer.getCurrentTime) {
          return Math.floor(window._ytPlayer.getCurrentTime() * 1000);
        }
        var v = document.querySelector('video');
        if (v && !isNaN(v.currentTime)) return Math.floor(v.currentTime * 1000);
      } catch(e) {}
      return -1;
    },

    // ── Obter duração total (ms) ────────────────────────────────────────────
    getDuration: function() {
      try {
        if (this._yt && this._yt.getDuration) {
          var d = this._yt.getDuration();
          if (d > 0) return Math.floor(d * 1000);
        }
        if (window._ytPlayer && window._ytPlayer.getDuration) {
          var d2 = window._ytPlayer.getDuration();
          if (d2 > 0) return Math.floor(d2 * 1000);
        }
        var v = document.querySelector('video');
        if (v && !isNaN(v.duration) && v.duration > 0) {
          return Math.floor(v.duration * 1000);
        }
      } catch(e) {}
      return 0;
    },

    // ── Verificar se está em buffering ──────────────────────────────────────
    isBuffering: function() {
      try {
        var v = document.querySelector('video');
        if (v) {
          // networkState 2 = NETWORK_LOADING, readyState < 3 = não tem dados suficientes
          return v.networkState === 2 && v.readyState < 3;
        }
      } catch(e) {}
      return false;
    },

    // ── Play ────────────────────────────────────────────────────────────────
    play: function() {
      try {
        if (this._yt && this._yt.playVideo) { this._yt.playVideo(); return; }
        if (window._ytPlayer && window._ytPlayer.playVideo) { window._ytPlayer.playVideo(); return; }
        var v = document.querySelector('video');
        if (v) v.play();
      } catch(e) {}
    },

    // ── Pause ───────────────────────────────────────────────────────────────
    pause: function() {
      try {
        if (this._yt && this._yt.pauseVideo) { this._yt.pauseVideo(); return; }
        if (window._ytPlayer && window._ytPlayer.pauseVideo) { window._ytPlayer.pauseVideo(); return; }
        var v = document.querySelector('video');
        if (v) v.pause();
      } catch(e) {}
    },

    // ── Seek ────────────────────────────────────────────────────────────────
    seek: function(seconds) {
      try {
        if (this._yt && this._yt.seekTo) { this._yt.seekTo(seconds, true); return; }
        if (window._ytPlayer && window._ytPlayer.seekTo) { window._ytPlayer.seekTo(seconds, true); return; }
        var v = document.querySelector('video');
        if (v) v.currentTime = seconds;
      } catch(e) {}
    },

    // ── Set playback rate ───────────────────────────────────────────────────
    setRate: function(rate) {
      try {
        if (this._yt && this._yt.setPlaybackRate) { this._yt.setPlaybackRate(rate); return; }
        if (window._ytPlayer && window._ytPlayer.setPlaybackRate) { window._ytPlayer.setPlaybackRate(rate); return; }
        var v = document.querySelector('video');
        if (v) v.playbackRate = rate;
      } catch(e) {}
    }
  };

  // Tentar inicializar YT imediatamente (pode já estar disponível)
  // NOTA: initYT() NÃO cria um novo YT.Player — apenas conecta ao _ytPlayer
  // já criado pelo onYouTubeIframeAPIReady no _buildHtmlWrapper.
  // Os event listeners do <video> são registrados pelo _injectControlScript
  // (widget) via callHandler nativo, evitando duplicação com console.log.
  window._nexusPlayer.initYT();

  // Aguardar YT.ready se necessário
  if (window.YT && window.YT.ready) {
    window.YT.ready(function() { window._nexusPlayer.initYT(); });
  }
  // Os event listeners do <video> HTML5 são registrados pelo
  // _injectControlScript (ScreeningPlayerWidget) via callHandler nativo.
  // Não registramos aqui para evitar duplicação de eventos.
})();
''';

// ── Provider ──────────────────────────────────────────────────────────────────

final screeningPlayerProvider = StateNotifierProvider.family<
    ScreeningPlayerNotifier, ScreeningPlayerState, String>(
  (ref, sessionId) => ScreeningPlayerNotifier(sessionId: sessionId, ref: ref),
);

class ScreeningPlayerNotifier extends StateNotifier<ScreeningPlayerState> {
  final String sessionId;
  final Ref _ref;
  String? _threadId;

  InAppWebViewController? _webViewController;
  Player? _nativePlayer;
  BetterPlayerController? _drmPlayer;
  Timer? _positionPollTimer;
  bool _bridgeInjected = false;
  bool _isNativeMode = false;
  bool _webViewDisposed = false; // true quando o InAppWebView nativo foi destruído

  ScreeningPlayerNotifier({required this.sessionId, required Ref ref})
      : _ref = ref,
        super(const ScreeningPlayerState());
  void setThreadId(String threadId) => _threadId = threadId;

  // ── Registrar o WebViewController ────────────────────────────────────────────

  void registerWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
    _bridgeInjected = false;
    _webViewDisposed = false;
    // Ao registrar um WebView, sair do modo nativo
    _isNativeMode = false;
  }

  /// Chamado quando o InAppWebView é destruído (onDispose do widget).
  /// Impede MissingPluginException ao tentar evaluateJavascript em canal morto.
  void unregisterWebViewController() {
    _webViewDisposed = true;
    _positionPollTimer?.cancel();
    _positionPollTimer = null;
    _webViewController = null;
    _bridgeInjected = false;
  }

  /// Define explicitamente se o conteúdo é ao vivo.
  /// Chamado pelo widget quando a plataforma é conhecida (Twitch, Kick, YouTubeLive).
  /// Tem precedência sobre o cálculo por duration == Duration.zero.
  void setIsLive(bool isLive) {
    if (state.isLive != isLive) {
      state = state.copyWith(isLive: isLive);
    }
  }

  /// Chamado pelo widget após injetar o _injectControlScript para evitar
  /// que o provider injete o bridge duplicado via _ensureBridge().
  void markBridgeInjected() {
    _bridgeInjected = true;
  }

  /// Chamado em onLoadStop — marca o player como pronto e inicia o polling.
  /// O bridge JS já foi injetado pelo widget (ScreeningPlayerWidget._injectControlScript)
  /// antes desta chamada, portanto não injetamos novamente para evitar sobrescrita.
  Future<void> onWebViewReady() async {
    state = state.copyWith(isReady: true, isBuffering: false);
    // Só inicia polling se NÃO estiver em modo nativo
    if (!_isNativeMode) {
      // Para lives (Twitch/Kick/YouTubeLive): NÃO iniciar polling de posição.
      // Lives não têm seek bar — o polling de posição a cada 1s é desnecessário
      // e causa evaluateJavascript frequente que compete com o thread JS do WebView,
      // degradando a performance do player de vídeo.
      if (!state.isLive) {
        _startPositionPolling(intervalSeconds: 1);
        // Tentar obter duração após um breve delay (aguarda o player carregar)
        Future.delayed(const Duration(seconds: 2), _updateDuration);
      }
    }
  }

  /// Chamado em onLoadStart — reseta o estado.
  void onWebViewLoading() {
    state = state.copyWith(isReady: false, isBuffering: true);
    _positionPollTimer?.cancel();
    _bridgeInjected = false;
  }

  // ── Injeção do bridge JS ──────────────────────────────────────────────────────

  Future<void> _injectBridge() async {
    if (_webViewController == null || _bridgeInjected || _isNativeMode) return;
    try {
      await _webViewController!.evaluateJavascript(source: _kPlayerBridgeJs);
      _bridgeInjected = true;
      debugPrint('[ScreeningPlayer] bridge JS injetado');
    } catch (e) {
      debugPrint('[ScreeningPlayer] bridge inject error: $e');
    }
  }

  // ── Polling de posição ────────────────────────────────────────────────────────

  void _startPositionPolling({required int intervalSeconds}) {
    _positionPollTimer?.cancel();
    // NUNCA iniciar polling WebView em modo nativo
    if (_isNativeMode) return;
    _positionPollTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) async {
        // Verificação dupla: se entrou em modo nativo durante o ciclo, parar
        if (_webViewController == null || !state.isReady || !mounted || _isNativeMode) return;
        try {
          final posMs = await _getPositionMs();
          final isBuffering = await _getIsBuffering();
          if (posMs != null && mounted) {
            state = state.copyWith(
              position: Duration(milliseconds: posMs),
              isBuffering: isBuffering,
            );
          }
        } catch (_) {}
      },
    );
  }

  Future<int?> _getPositionMs() async {
    if (_webViewController == null || _isNativeMode || _webViewDisposed) return null;
    try {
      final result = await _webViewController!.evaluateJavascript(
        source: 'window._nexusPlayer ? window._nexusPlayer.getPosition() : -1;',
      );
      final val = result as num?;
      if (val != null && val >= 0) return val.toInt();
    } catch (e) {
      // Silenciar MissingPluginException — ocorre quando o WebView foi destruído
      // antes do timer ser cancelado. Não é um erro real.
      if (!e.toString().contains('MissingPluginException')) {
        debugPrint('[ScreeningPlayer] getPositionMs error: $e');
      }
      _webViewDisposed = true;
      _positionPollTimer?.cancel();
    }
    return null;
  }

  Future<bool> _getIsBuffering() async {
    if (_webViewController == null || _isNativeMode) return false;
    try {
      final result = await _webViewController!.evaluateJavascript(
        source: 'window._nexusPlayer ? window._nexusPlayer.isBuffering() : false;',
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _updateDuration() async {
    if (_webViewController == null || !mounted || _isNativeMode) return;
    try {
      final result = await _webViewController!.evaluateJavascript(
        source: 'window._nexusPlayer ? window._nexusPlayer.getDuration() : 0;',
      );
      final durMs = (result as num?)?.toInt() ?? 0;
      if (durMs > 0 && mounted) {
        state = state.copyWith(duration: Duration(milliseconds: durMs));
        debugPrint('[ScreeningPlayer] duração: ${durMs}ms');
      }
    } catch (e) {
      debugPrint('[ScreeningPlayer] getDuration error: $e');
    }
  }

  // ── Comandos de reprodução (roteiam para nativo ou WebView) ──────────────────

  Future<void> play() async {
    if (_isNativeMode) {
      await _nativePlayer?.play();
      await _drmPlayer?.play();
      if (mounted) {
        state = state.copyWith(isPlaying: true);
      }
      return;
    }
    await _ensureBridge();
    await _retryCommand(() async {
      await _webViewController!.evaluateJavascript(
        source: 'window._nexusPlayer && window._nexusPlayer.play();',
      );
    });
    if (mounted) {
      state = state.copyWith(isPlaying: true);
      // Para lives: não iniciar polling (sem seek bar)
      if (!state.isLive) {
        _startPositionPolling(intervalSeconds: 1);
      }
    }
  }

  Future<void> pause() async {
    if (_isNativeMode) {
      await _nativePlayer?.pause();
      await _drmPlayer?.pause();
      if (mounted) {
        state = state.copyWith(isPlaying: false);
      }
      return;
    }
    await _ensureBridge();
    await _retryCommand(() async {
      await _webViewController!.evaluateJavascript(
        source: 'window._nexusPlayer && window._nexusPlayer.pause();',
      );
    });
    if (mounted) {
      state = state.copyWith(isPlaying: false);
      // Reduzir polling ao pausar (economiza recursos) — apenas para VODs
      if (!state.isLive) {
        _startPositionPolling(intervalSeconds: 5);
      }
    }
  }

  Future<void> seek(Duration position) async {
    if (_isNativeMode) {
      await _nativePlayer?.seek(position);
      await _drmPlayer?.seekTo(position);
      if (mounted) state = state.copyWith(position: position, hasEnded: false);
      return;
    }
    await _ensureBridge();
    final seconds = position.inMilliseconds / 1000.0;
    await _retryCommand(() async {
      await _webViewController!.evaluateJavascript(
        source: 'window._nexusPlayer && window._nexusPlayer.seek($seconds);',
      );
    });
    // Resetar hasEnded ao fazer seek
    if (mounted) state = state.copyWith(position: position, hasEnded: false);
  }

  Future<void> setRate(double rate) async {
    if (_isNativeMode) {
      // media_kit não suporta setRate diretamente via Player; ignorar microsync de rate
      // para streams ao vivo (Twitch). Para VODs nativos, poderia ser implementado.
      if (mounted) state = state.copyWith(playbackRate: rate);
      return;
    }
    await _ensureBridge();
    try {
      await _webViewController!.evaluateJavascript(
        source: 'window._nexusPlayer && window._nexusPlayer.setRate($rate);',
      );
      if (mounted) state = state.copyWith(playbackRate: rate);
    } catch (e) {
      debugPrint('[ScreeningPlayer] setRate error: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Future<void> _ensureBridge() async {
    if (!_bridgeInjected && !_isNativeMode) await _injectBridge();
  }

  /// Tenta executar um comando até 3x com 300ms de intervalo.
  Future<void> _retryCommand(Future<void> Function() command) async {
    if (_webViewController == null || _isNativeMode) return;
    for (int i = 0; i < 3; i++) {
      try {
        await command();
        return;
      } catch (e) {
        if (i < 2) await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  // ── Notificações do WebView (via JavaScriptHandler) ───────────────────────────

  void onVideoPlaying() {
    if (!mounted) return;
    state = state.copyWith(isPlaying: true, isBuffering: false);
    if (!_isNativeMode) {
      // Para lives: não iniciar polling (sem seek bar, sem necessidade de posição)
      if (!state.isLive) {
        // Polling como fallback: se o bridge JS (timeupdate) estiver ativo,
        // o primeiro onPositionUpdate cancelará o timer automaticamente.
        _startPositionPolling(intervalSeconds: 2);
        _updateDuration();
      }
    }
  }

  void onVideoPaused() {
    if (!mounted) return;
    state = state.copyWith(isPlaying: false);
    if (!_isNativeMode) {
      _startPositionPolling(intervalSeconds: 5);
    }
  }

  /// Recebe atualização de posição via JavaScriptHandler 'NexusPlayerBridge'.
  /// Chamado pelo evento 'timeupdate' do <video> HTML5 (throttled a 500ms).
  /// Mais eficiente que polling: substitui o evaluateJavascript periódico.
  void onPositionUpdate(int positionMs) {
    if (!mounted || _isNativeMode) return;
    // Cancelar polling se o bridge estiver ativo (evita dupla atualização)
    if (_positionPollTimer?.isActive == true) {
      _positionPollTimer?.cancel();
    }
    final newPos = Duration(milliseconds: positionMs);
    // Se a posição está avançando, o vídeo está reproduzindo — limpar buffering.
    // Isso é uma salvaguarda para o caso do YT_PLAYING não ser recebido.
    final wasBuffering = state.isBuffering;
    final positionAdvanced = newPos > state.position;
    state = state.copyWith(
      position: newPos,
      isBuffering: wasBuffering && positionAdvanced ? false : state.isBuffering,
    );
  }

  /// Recebe atualização de duração via JavaScriptHandler 'NexusPlayerBridge'.
  /// Chamado pelo evento 'durationchange' do <video> HTML5.
  void onDurationUpdate(int durationMs) {
    if (!mounted || _isNativeMode) return;
    if (durationMs <= 0) return;
    final newDur = Duration(milliseconds: durationMs);
    if (newDur != state.duration) {
      state = state.copyWith(duration: newDur);
    }
  }

  void onVideoBuffering() {
    if (!mounted) return;
    state = state.copyWith(isBuffering: true);
  }

  void onVideoEnded() {
    if (!mounted) return;
    state = state.copyWith(isPlaying: false, isBuffering: false, hasEnded: true);
    _positionPollTimer?.cancel();
    _autoAdvanceQueue();
  }

  /// Avança automaticamente para o próximo vídeo da fila quando o atual termina.
  /// O vídeo atual permanece na fila — apenas o currentVideoUrl é atualizado
  /// para o próximo item. O host pode remover itens manualmente da fila.
  Future<void> _autoAdvanceQueue() async {
    final tid = _threadId;
    if (tid == null) return;
    try {
      final roomState = _ref.read(screeningRoomProvider(tid));
      if (!roomState.isHost) return; // apenas o host controla a fila
      final queue = roomState.videoQueue;
      if (queue.isEmpty) return;
      // Encontrar o índice do vídeo atual na fila
      final currentUrl = roomState.currentVideoUrl ?? '';
      final currentIndex = queue.indexWhere((item) => item['url'] == currentUrl);
      // Próximo é o item após o atual, ou o primeiro se não encontrado
      final nextIndex = (currentIndex >= 0 && currentIndex + 1 < queue.length)
          ? currentIndex + 1
          : (currentIndex < 0 && queue.isNotEmpty ? 0 : -1);
      if (nextIndex < 0) return; // Não há próximo vídeo
      final next = queue[nextIndex];
      final notifier = _ref.read(screeningRoomProvider(tid).notifier);
      // Atualiza o currentVideoUrl sem remover da fila
      await notifier.updateVideo(
        videoUrl: next['url'] ?? '',
        videoTitle: next['title'] ?? '',
        videoThumbnail: next['thumbnail'],
      );
    } catch (e) {
      debugPrint('[ScreeningPlayerProvider] Auto-avanço falhou: $e');
    }
  }

  // ── Player nativo (media_kit) ─────────────────────────────────────────────────────

  void registerNativePlayer(Player player) {
    _nativePlayer = player;
    _isNativeMode = true;
    // Parar polling WebView imediatamente ao entrar em modo nativo
    _positionPollTimer?.cancel();
    _positionPollTimer = null;
    state = state.copyWith(isReady: true, isBuffering: false);
  }

  // ── Player DRM (better_player_plus / Widevine) ────────────────────────────────

  void registerDrmPlayer(BetterPlayerController controller) {
    _drmPlayer = controller;
    _isNativeMode = true;
    // Parar polling WebView imediatamente ao entrar em modo nativo
    _positionPollTimer?.cancel();
    _positionPollTimer = null;
    state = state.copyWith(isReady: true, isBuffering: false);
  }

  Future<void> drmPlay() async {
    await _drmPlayer?.play();
  }

  Future<void> drmPause() async {
    await _drmPlayer?.pause();
  }

  Future<void> drmSeek(double seconds) async {
    await _drmPlayer?.seekTo(Duration(milliseconds: (seconds * 1000).round()));
  }

  void onNativePlay() {
    if (!mounted) return;
    state = state.copyWith(isPlaying: true, isBuffering: false);
  }

  void onNativePause() {
    if (!mounted) return;
    state = state.copyWith(isPlaying: false);
  }

  void onNativePositionUpdate(double seconds) {
    if (!mounted) return;
    state = state.copyWith(
      position: Duration(milliseconds: (seconds * 1000).round()),
    );
  }

  void onNativeBuffering(bool buffering) {
    if (!mounted) return;
    state = state.copyWith(isBuffering: buffering);
  }

  Future<void> nativePlay() async {
    await _nativePlayer?.play();
  }

  Future<void> nativePause() async {
    await _nativePlayer?.pause();
  }

  Future<void> nativeSeek(double seconds) async {
    await _nativePlayer?.seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  @override
  void dispose() {
    _positionPollTimer?.cancel();
    _positionPollTimer = null;
    _webViewDisposed = true;
    _webViewController = null; // evita MissingPluginException após dispose
    _nativePlayer = null;
    _drmPlayer = null;
    super.dispose();
  }
}
