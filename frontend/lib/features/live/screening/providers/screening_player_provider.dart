import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/screening_player_state.dart';

// =============================================================================
// ScreeningPlayerProvider — Gerencia o estado do player de vídeo
//
// Responsabilidades:
// - Manter referência ao InAppWebViewController
// - Expor estado de reprodução (isPlaying, position, duration)
// - Executar comandos de play/pause/seek via JavaScript injection
// - Reportar posição atual para o ScreeningSyncProvider
//
// Nota: O player usa InAppWebView com HTML wrapper para máxima compatibilidade
// com YouTube, Twitch, Kick, Vimeo e outros. O controle é feito via
// JavaScript Injection usando as APIs nativas de cada plataforma.
// =============================================================================

final screeningPlayerProvider = StateNotifierProvider.family<
    ScreeningPlayerNotifier, ScreeningPlayerState, String>(
  (ref, sessionId) => ScreeningPlayerNotifier(sessionId: sessionId),
);

class ScreeningPlayerNotifier extends StateNotifier<ScreeningPlayerState> {
  final String sessionId;

  InAppWebViewController? _webViewController;
  Timer? _positionPollTimer;

  ScreeningPlayerNotifier({required this.sessionId})
      : super(const ScreeningPlayerState());

  // ── Registrar o WebViewController ──────────────────────────────────────────

  void registerWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
  }

  void onWebViewReady() {
    state = state.copyWith(isReady: true);
    _startPositionPolling();
  }

  void onWebViewLoading() {
    state = state.copyWith(isReady: false, isBuffering: true);
    _positionPollTimer?.cancel();
  }

  // ── Polling de posição ──────────────────────────────────────────────────────
  // Consulta a posição atual do vídeo via JS a cada 1s para o Microsync.

  void _startPositionPolling() {
    _positionPollTimer?.cancel();
    _positionPollTimer =
        Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_webViewController == null || !state.isReady) return;
      try {
        final posMs = await _getPositionMs();
        if (posMs != null) {
          state = state.copyWith(
            position: Duration(milliseconds: posMs),
            isBuffering: false,
          );
        }
      } catch (_) {}
    });
  }

  Future<int?> _getPositionMs() async {
    if (_webViewController == null) return null;
    try {
      // Tenta obter posição via API do YouTube IFrame
      final result = await _webViewController!.evaluateJavascript(
        source: '''
          (function() {
            try {
              // YouTube IFrame API
              if (window._ytPlayer && typeof window._ytPlayer.getCurrentTime === 'function') {
                return Math.floor(window._ytPlayer.getCurrentTime() * 1000);
              }
              // HTML5 video genérico
              var v = document.querySelector('video');
              if (v) return Math.floor(v.currentTime * 1000);
              return -1;
            } catch(e) { return -1; }
          })();
        ''',
      );
      final val = result as num?;
      if (val != null && val >= 0) return val.toInt();
    } catch (e) {
      debugPrint('[ScreeningPlayer] getPositionMs error: $e');
    }
    return null;
  }

  // ── Comandos de reprodução ──────────────────────────────────────────────────

  Future<void> play() async {
    if (_webViewController == null) return;
    try {
      await _webViewController!.evaluateJavascript(source: '''
        (function() {
          try {
            if (window._ytPlayer && typeof window._ytPlayer.playVideo === 'function') {
              window._ytPlayer.playVideo();
            } else {
              var v = document.querySelector('video');
              if (v) v.play();
            }
          } catch(e) {}
        })();
      ''');
      state = state.copyWith(isPlaying: true);
    } catch (e) {
      debugPrint('[ScreeningPlayer] play error: $e');
    }
  }

  Future<void> pause() async {
    if (_webViewController == null) return;
    try {
      await _webViewController!.evaluateJavascript(source: '''
        (function() {
          try {
            if (window._ytPlayer && typeof window._ytPlayer.pauseVideo === 'function') {
              window._ytPlayer.pauseVideo();
            } else {
              var v = document.querySelector('video');
              if (v) v.pause();
            }
          } catch(e) {}
        })();
      ''');
      state = state.copyWith(isPlaying: false);
    } catch (e) {
      debugPrint('[ScreeningPlayer] pause error: $e');
    }
  }

  Future<void> seek(Duration position) async {
    if (_webViewController == null) return;
    final seconds = position.inMilliseconds / 1000.0;
    try {
      await _webViewController!.evaluateJavascript(source: '''
        (function() {
          try {
            if (window._ytPlayer && typeof window._ytPlayer.seekTo === 'function') {
              window._ytPlayer.seekTo($seconds, true);
            } else {
              var v = document.querySelector('video');
              if (v) v.currentTime = $seconds;
            }
          } catch(e) {}
        })();
      ''');
      state = state.copyWith(position: position);
    } catch (e) {
      debugPrint('[ScreeningPlayer] seek error: $e');
    }
  }

  Future<void> setRate(double rate) async {
    if (_webViewController == null) return;
    try {
      await _webViewController!.evaluateJavascript(source: '''
        (function() {
          try {
            if (window._ytPlayer && typeof window._ytPlayer.setPlaybackRate === 'function') {
              window._ytPlayer.setPlaybackRate($rate);
            } else {
              var v = document.querySelector('video');
              if (v) v.playbackRate = $rate;
            }
          } catch(e) {}
        })();
      ''');
      state = state.copyWith(playbackRate: rate);
    } catch (e) {
      debugPrint('[ScreeningPlayer] setRate error: $e');
    }
  }

  // ── Notificações do WebView ─────────────────────────────────────────────────

  void onVideoPlaying() => state = state.copyWith(isPlaying: true, isBuffering: false);
  void onVideoPaused() => state = state.copyWith(isPlaying: false);
  void onVideoBuffering() => state = state.copyWith(isBuffering: true);

  @override
  void dispose() {
    _positionPollTimer?.cancel();
    super.dispose();
  }
}
