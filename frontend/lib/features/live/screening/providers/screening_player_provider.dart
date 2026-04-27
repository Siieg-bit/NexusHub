import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/screening_player_state.dart';

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

    // ── Inicializar YouTube IFrame API ──────────────────────────────────────
    initYT: function() {
      if (window.YT && window.YT.Player) {
        var iframe = document.querySelector('iframe[src*="youtube"]');
        if (iframe && !this._yt) {
          this._yt = new YT.Player(iframe, {
            events: {
              onReady: function(e) { _emit('ready'); e.target.playVideo(); },
              onStateChange: function(e) {
                // -1=unstarted, 0=ended, 1=playing, 2=paused, 3=buffering
                if (e.data === 1) _emit('playing');
                else if (e.data === 2) _emit('paused');
                else if (e.data === 3) _emit('buffering');
                else if (e.data === 0) _emit('ended');
              }
            }
          });
        }
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
  window._nexusPlayer.initYT();

  // Aguardar YT.ready se necessário
  if (window.YT && window.YT.ready) {
    window.YT.ready(function() { window._nexusPlayer.initYT(); });
  }

  // Observar eventos do <video> HTML5
  var v = document.querySelector('video');
  if (v) {
    v.addEventListener('playing', function() { _emit('playing'); });
    v.addEventListener('pause',   function() { _emit('paused'); });
    v.addEventListener('waiting', function() { _emit('buffering'); });
    v.addEventListener('ended',   function() { _emit('ended'); });
    v.addEventListener('loadedmetadata', function() { _emit('ready'); });
  }
})();
''';

// ── Provider ──────────────────────────────────────────────────────────────────

final screeningPlayerProvider = StateNotifierProvider.family<
    ScreeningPlayerNotifier, ScreeningPlayerState, String>(
  (ref, sessionId) => ScreeningPlayerNotifier(sessionId: sessionId),
);

class ScreeningPlayerNotifier extends StateNotifier<ScreeningPlayerState> {
  final String sessionId;

  InAppWebViewController? _webViewController;
  Timer? _positionPollTimer;
  bool _bridgeInjected = false;

  ScreeningPlayerNotifier({required this.sessionId})
      : super(const ScreeningPlayerState());

  // ── Registrar o WebViewController ────────────────────────────────────────────

  void registerWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
    _bridgeInjected = false;
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
    _startPositionPolling(intervalSeconds: 1);
    // Tentar obter duração após um breve delay (aguarda o player carregar)
    Future.delayed(const Duration(seconds: 2), _updateDuration);
  }

  /// Chamado em onLoadStart — reseta o estado.
  void onWebViewLoading() {
    state = state.copyWith(isReady: false, isBuffering: true);
    _positionPollTimer?.cancel();
    _bridgeInjected = false;
  }

  // ── Injeção do bridge JS ──────────────────────────────────────────────────────

  Future<void> _injectBridge() async {
    if (_webViewController == null || _bridgeInjected) return;
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
    _positionPollTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) async {
        if (_webViewController == null || !state.isReady || !mounted) return;
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
    if (_webViewController == null) return null;
    try {
      final result = await _webViewController!.evaluateJavascript(
        source: 'window._nexusPlayer ? window._nexusPlayer.getPosition() : -1;',
      );
      final val = result as num?;
      if (val != null && val >= 0) return val.toInt();
    } catch (e) {
      debugPrint('[ScreeningPlayer] getPositionMs error: $e');
    }
    return null;
  }

  Future<bool> _getIsBuffering() async {
    if (_webViewController == null) return false;
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
    if (_webViewController == null || !mounted) return;
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

  // ── Comandos de reprodução ────────────────────────────────────────────────────

  Future<void> play() async {
    await _ensureBridge();
    await _retryCommand(() async {
      await _webViewController!.evaluateJavascript(
        source: 'window._nexusPlayer && window._nexusPlayer.play();',
      );
    });
    if (mounted) {
      state = state.copyWith(isPlaying: true);
      _startPositionPolling(intervalSeconds: 1);
    }
  }

  Future<void> pause() async {
    await _ensureBridge();
    await _retryCommand(() async {
      await _webViewController!.evaluateJavascript(
        source: 'window._nexusPlayer && window._nexusPlayer.pause();',
      );
    });
    if (mounted) {
      state = state.copyWith(isPlaying: false);
      // Reduzir polling ao pausar (economiza recursos)
      _startPositionPolling(intervalSeconds: 5);
    }
  }

  Future<void> seek(Duration position) async {
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
    if (!_bridgeInjected) await _injectBridge();
  }

  /// Tenta executar um comando até 3x com 300ms de intervalo.
  Future<void> _retryCommand(Future<void> Function() command) async {
    if (_webViewController == null) return;
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
    _startPositionPolling(intervalSeconds: 1);
    _updateDuration(); // atualizar duração se ainda não tiver
  }

  void onVideoPaused() {
    if (!mounted) return;
    state = state.copyWith(isPlaying: false);
    _startPositionPolling(intervalSeconds: 5);
  }

  void onVideoBuffering() {
    if (!mounted) return;
    state = state.copyWith(isBuffering: true);
  }

  void onVideoEnded() {
    if (!mounted) return;
    state = state.copyWith(isPlaying: false, isBuffering: false, hasEnded: true);
    _positionPollTimer?.cancel();
  }

  @override
  void dispose() {
    _positionPollTimer?.cancel();
    _positionPollTimer = null;
    _webViewController = null; // evita MissingPluginException após dispose
    super.dispose();
  }
}
