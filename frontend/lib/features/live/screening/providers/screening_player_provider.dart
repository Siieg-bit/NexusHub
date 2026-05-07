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

  // IMPORTANTE: nenhum método armazena referência estática ao _ytPlayer.
  // Todos consultam window._ytPlayer dinamicamente em tempo de execução,
  // eliminando o race condition onde _yt ficava null porque
  // onYouTubeIframeAPIReady ainda não havia sido chamado no onLoadStop.
  window._nexusPlayer = {

    // ── Obter posição atual (ms) ──────────────────────────────────────────────
    getPosition: function() {
      try {
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
        if (window._ytPlayer && window._ytPlayer.getDuration) {
          var d = window._ytPlayer.getDuration();
          if (d > 0) return Math.floor(d * 1000);
        }
        var v = document.querySelector('video');
        if (v && !isNaN(v.duration) && v.duration > 0) {
          return Math.floor(v.duration * 1000);
        }
      } catch(e) {}
      return 0;
    },

    // ── Verificar se está em buffering ──────────────────────────────────────────
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

    // ── Play ──────────────────────────────────────────────────────────────────────
    play: function() {
      try {
        if (window._ytPlayer && window._ytPlayer.playVideo) { window._ytPlayer.playVideo(); return; }
        var v = document.querySelector('video');
        if (v) v.play();
      } catch(e) {}
    },

    // ── Pause ─────────────────────────────────────────────────────────────────────
    pause: function() {
      try {
        if (window._ytPlayer && window._ytPlayer.pauseVideo) { window._ytPlayer.pauseVideo(); return; }
        var v = document.querySelector('video');
        if (v) v.pause();
      } catch(e) {}
    },

    // ── Seek ──────────────────────────────────────────────────────────────────────
    seek: function(seconds) {
      try {
        if (window._ytPlayer && window._ytPlayer.seekTo) { window._ytPlayer.seekTo(seconds, true); return; }
        var v = document.querySelector('video');
        if (v) v.currentTime = seconds;
      } catch(e) {}
    },

    // ── Set playback rate ────────────────────────────────────────────────────────────
    setRate: function(rate) {
      try {
        if (window._ytPlayer && window._ytPlayer.setPlaybackRate) { window._ytPlayer.setPlaybackRate(rate); return; }
        var v = document.querySelector('video');
        if (v) v.playbackRate = rate;
      } catch(e) {}
    }
  };

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

/// Token global de Keep Alive por sessão.
/// Permite que o InAppWebView da sala de projeção seja reutilizado
/// pelo PiP flutuante sem recarregar o vídeo.
/// Regra: apenas UMA instância ativa por token ao mesmo tempo.
final screeningWebViewKeepAliveProvider =
    Provider.family<InAppWebViewKeepAlive, String>(
  (ref, sessionId) => InAppWebViewKeepAlive(),
);

class ScreeningPlayerNotifier extends StateNotifier<ScreeningPlayerState> {
  final String sessionId;
  final Ref _ref;
  String? _threadId;

  InAppWebViewController? _webViewController;
  Player? _nativePlayer;
  BetterPlayerController? _drmPlayer;
  Timer? _positionPollTimer;
  Timer? _bufferingTimeoutTimer;
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
    // NUNCA zerar _isNativeMode se o player nativo já foi registrado.
    // O ScreeningPlayerWidget pode ser reconstruído (ex: mudança de sessionId)
    // e chamar registerWebViewController novamente — mas se o ScreeningNativePlayerWidget
    // já registrou o player nativo, _isNativeMode deve permanecer true.
    // Só sair do modo nativo se explicitamente não há player nativo ativo.
    if (_nativePlayer == null && _drmPlayer == null) {
      _isNativeMode = false;
    }
    debugPrint('[ScreeningPlayer] registerWebViewController — _isNativeMode=$_isNativeMode (nativePlayer=${_nativePlayer != null}, drmPlayer=${_drmPlayer != null})');
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
        // Tentar obter duração imediatamente e com retries progressivos.
        // O delay fixo de 2s causava isLiveStream=true durante esse período,
        // ocultando a seek bar e os botões de avançar/retroceder na primeira carga.
        _scheduleDurationRetries();
      }
    }
  }

  /// Chamado em onLoadStart — reseta o estado.
  /// Reseta duration/position/isLive/hasEnded/isPlaying para evitar que o
  /// getter isLiveStream (isLive || duration==zero) fique true durante o
  /// carregamento inicial e oculte os controles de VOD (seek bar, ±10s).
  void onWebViewLoading() {
    _positionPollTimer?.cancel();
    _bridgeInjected = false;
    // Reconstruir o estado do zero para garantir que duration/position/isLive
    // não herdem valores de um vídeo anterior. copyWith não consegue setar
    // duration/position para Duration.zero de forma confiável quando o estado
    // anterior já tem esses valores.
    state = ScreeningPlayerState(
      isReady: false,
      isBuffering: true,
    );
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
          // Detectar isPlaying via getPlayerState() === 1 (playing)
          // Isso é mais confiável que esperar a posição avançar no primeiro ciclo.
          final isPlayingByState = await _getIsPlayingByState();
          if (posMs != null && mounted) {
            final newPos = Duration(milliseconds: posMs);
            final positionAdvanced = newPos > state.position;
            // isPlaying: verdadeiro se posição avançou OU getPlayerState()==1
            final correctedIsPlaying = (positionAdvanced || isPlayingByState) ? true : state.isPlaying;
            final correctedIsBuffering = positionAdvanced ? false : isBuffering;
            state = state.copyWith(
              position: newPos,
              isPlaying: correctedIsPlaying,
              isBuffering: correctedIsBuffering,
            );
          } else if (isPlayingByState && mounted) {
            // Posição ainda não disponível mas YT.Player já está reproduzindo
            state = state.copyWith(isPlaying: true, isBuffering: false);
          }
          // Atualizar duração via polling também (não depender apenas do bridge JS).
          // Isso garante que a seek bar apareça mesmo se VIDEO_DURATION via callHandler falhar.
          if (state.duration == Duration.zero) {
            await _updateDuration();
          }
        } catch (_) {}
      },
    );
  }

  Future<bool> _getIsPlayingByState() async {
    if (_webViewController == null || _isNativeMode || _webViewDisposed) return false;
    try {
      // YT.Player.getPlayerState() === 1 significa playing
      final result = await _webViewController!.evaluateJavascript(source: '''
        (function() {
          try {
            if (window._ytPlayer && window._ytPlayer.getPlayerState) {
              return window._ytPlayer.getPlayerState() === 1;
            }
          } catch(e) {}
          return false;
        })()
      ''');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<int?> _getPositionMs() async {
    if (_webViewController == null || _isNativeMode || _webViewDisposed) return null;
    try {
      // Tenta obter posição via window._ytPlayer (YouTube IFrame API)
      // ou document.querySelector('video') (HTML5 <video>).
      final result = await _webViewController!.evaluateJavascript(source: '''
        (function() {
          try {
            if (window._ytPlayer && window._ytPlayer.getCurrentTime) {
              var p = Math.floor(window._ytPlayer.getCurrentTime() * 1000);
              if (p >= 0) return p;
            }
            var v = document.querySelector('video');
            if (v && !isNaN(v.currentTime)) return Math.floor(v.currentTime * 1000);
          } catch(e) {}
          return -1;
        })()
      ''');
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
      // YT.Player.getPlayerState() === 3 significa buffering
      // Fallback: networkState/readyState do <video> HTML5
      final result = await _webViewController!.evaluateJavascript(source: '''
        (function() {
          try {
            if (window._ytPlayer && window._ytPlayer.getPlayerState) {
              return window._ytPlayer.getPlayerState() === 3;
            }
            var v = document.querySelector('video');
            if (v) return v.networkState === 2 && v.readyState < 3;
          } catch(e) {}
          return false;
        })()
      ''');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _updateDuration() async {
    if (_webViewController == null || !mounted || _isNativeMode) return;
    try {
      // Tenta obter duração via window._ytPlayer (YouTube IFrame API)
      // ou document.querySelector('video') (HTML5 <video>).
      final result = await _webViewController!.evaluateJavascript(source: '''
        (function() {
          try {
            if (window._ytPlayer && window._ytPlayer.getDuration) {
              var d = window._ytPlayer.getDuration();
              if (d > 0) return Math.floor(d * 1000);
            }
            var v = document.querySelector('video');
            if (v && !isNaN(v.duration) && v.duration > 0) return Math.floor(v.duration * 1000);
          } catch(e) {}
          return 0;
        })()
      ''');
      final durMs = (result as num?)?.toInt() ?? 0;
      if (durMs > 0 && mounted) {
        state = state.copyWith(duration: Duration(milliseconds: durMs));
        debugPrint('[ScreeningPlayer] duração: ${durMs}ms');
      }
    } catch (e) {
      debugPrint('[ScreeningPlayer] getDuration error: $e');
    }
  }

  /// Tenta obter a duração imediatamente e com retries progressivos.
  /// Evita o delay fixo de 2s que deixava isLiveStream=true e ocultava
  /// a seek bar e os botões de avançar/retroceder na primeira carga.
  void _scheduleDurationRetries() {
    // Tentativas: 300ms, 800ms, 1.5s, 3s, 5s, 8s, 10s
    // Estendido até 10s para cobrir conexões lentas onde o YT.Player
    // demora mais para inicializar e reportar a duração.
    const delays = [300, 800, 1500, 3000, 5000, 8000, 10000];
    for (final ms in delays) {
      Future.delayed(Duration(milliseconds: ms), () async {
        if (!mounted || state.duration > Duration.zero) return;
        await _updateDuration();
      });
    }
  }

  // ── Comandos de reprodução (roteiam para nativo ou WebView) ──────────────────

  Future<void> play() async {
    debugPrint('[ScreeningPlayer] play() — _isNativeMode=$_isNativeMode, _nativePlayer=${_nativePlayer != null}');
    if (_isNativeMode) {
      await _nativePlayer?.play();
      await _drmPlayer?.play();
      debugPrint('[ScreeningPlayer] play() nativo executado');
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
    debugPrint('[ScreeningPlayer] pause() — _isNativeMode=$_isNativeMode, _nativePlayer=${_nativePlayer != null}');
    if (_isNativeMode) {
      await _nativePlayer?.pause();
      await _drmPlayer?.pause();
      debugPrint('[ScreeningPlayer] pause() nativo executado');
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
    // Timeout de segurança: se YT_PLAYING não chegar em 4s após o seek,
    // limpar isBuffering automaticamente (evita loading infinito).
    // 4s é suficiente para a maioria das conexões; em conexões lentas o
    // YT_BUFFERING será reenviado e o isBuffering voltara a true corretamente.
    _bufferingTimeoutTimer?.cancel();
    _bufferingTimeoutTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && state.isBuffering) {
        state = state.copyWith(isBuffering: false);
      }
    });
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
    // Idempotente: se já está tocando, apenas limpar isBuffering sem reiniciar
    // o polling. Isso evita que o __YT_STATE:playing__ emitido a cada 500ms
    // pelo _ytPositionTimer reinicie o timer de polling Dart repetidamente.
    final wasPlaying = state.isPlaying;
    state = state.copyWith(isPlaying: true, isBuffering: false);
    if (!_isNativeMode && !wasPlaying) {
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
    // Idempotente: se já está pausado, não reiniciar o polling.
    // O __YT_STATE:paused__ é emitido a cada 500ms pelo _ytPositionTimer
    // enquanto pausado, então precisamos evitar reiniciar o timer repetidamente.
    final wasPlaying = state.isPlaying;
    state = state.copyWith(isPlaying: false);
    if (!_isNativeMode && wasPlaying) {
      _startPositionPolling(intervalSeconds: 5);
    }
  }

  /// Recebe atualização de posição via JavaScriptHandler 'NexusPlayerBridge'.
  /// Chamado pelo evento 'timeupdate' do <video> HTML5 (throttled a 500ms).
  /// Mais eficiente que polling: substitui o evaluateJavascript periódico.
  void onPositionUpdate(int positionMs) {
    if (!mounted || _isNativeMode) return;
    // Não cancelar o polling: o bridge pode falhar no Android e o polling
    // é a fonte primária de verdade para posição/isPlaying/isBuffering.
    // O bridge atualiza o estado quando funciona, sem conflito com o polling.
    final newPos = Duration(milliseconds: positionMs);
    // Se a posição está avançando, o vídeo está reproduzindo — corrigir isPlaying
    // e limpar isBuffering mesmo que YT_PLAYING não tenha chegado via bridge.
    final positionAdvanced = newPos > state.position;
    state = state.copyWith(
      position: newPos,
      isPlaying: positionAdvanced ? true : state.isPlaying,
      isBuffering: positionAdvanced ? false : state.isBuffering,
    );
  }

  /// Recebe atualização de duração via JavaScriptHandler 'NexusPlayerBridge'.
  /// Chamado pelo evento 'durationchange' do <video> HTML5 (modo WebView).
  void onDurationUpdate(int durationMs) {
    if (!mounted) return;
    // Em modo nativo, a duração é atualizada via onNativeDurationUpdate.
    // Ignorar chamadas do WebView quando o player nativo está ativo.
    if (_isNativeMode) return;
    if (durationMs <= 0) return;
    final newDur = Duration(milliseconds: durationMs);
    if (newDur != state.duration) {
      state = state.copyWith(duration: newDur);
    }
  }

  /// Recebe atualização de duração do player nativo (media_kit / DRM).
  /// Não verifica _isNativeMode — é chamado diretamente pelo stream.duration
  /// do media_kit, independente do estado do provider.
  void onNativeDurationUpdate(int durationMs) {
    if (!mounted) return;
    if (durationMs <= 0) return;
    final newDur = Duration(milliseconds: durationMs);
    if (newDur != state.duration) {
      debugPrint('[ScreeningPlayer] onNativeDurationUpdate: ${durationMs}ms');
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
    debugPrint('[ScreeningPlayer] registerNativePlayer OK — _isNativeMode=true');
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
    debugPrint('[ScreeningPlayer] onNativePlay()');
    state = state.copyWith(isPlaying: true, isBuffering: false);
  }

  void onNativePause() {
    if (!mounted) return;
    debugPrint('[ScreeningPlayer] onNativePause()');
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
    _bufferingTimeoutTimer?.cancel();
    _bufferingTimeoutTimer = null;
    _webViewDisposed = true;
    _webViewController = null; // evita MissingPluginException após dispose
    _nativePlayer = null;
    _drmPlayer = null;
    super.dispose();
  }
}
