import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

// =============================================================================
// ScreeningAmbientGradient — Gradiente dinâmico baseado nas cores do vídeo
//
// Inspirado na engenharia reversa do Rave APK v8.2.34:
// O Rave usa um ShaderRenderer com BackgroundBlurVertexShader + VideoFrameProcessor
// que captura frames do ExoPlayer via OpenGL ES (samplerExternalOES) e calcula
// a cor média (colorAvg += texture2D(sTexture, ...)) para criar o fundo ambient.
//
// No NexusHub com WebView, replicamos via:
// 1. Canvas 2D sampling: captura pixels de um <canvas> sobreposto ao <video>
// 2. Amostragem em grid 4x4 (16 pixels) para calcular cor dominante
// 3. Transição suave com AnimatedContainer (800ms) — idêntico ao Rave
// 4. Fallback para preto quando não há vídeo
//
// Arquitetura:
// ─────────────────────────────────────────────────────────────────────────────
//  WebView (JS)  ──→  console.log('__nexus_color:R,G,B')
//      ↓
//  _handleColorMessage()  ──→  _updateAmbientColor()
//      ↓
//  AnimatedContainer  ──→  RadialGradient dinâmico nas bordas da tela
// =============================================================================

// ── Provider de cor ambiente ──────────────────────────────────────────────────
final screeningAmbientColorProvider =
    StateProvider.family<Color, String>((ref, sessionId) => Colors.black);

// ── Script JS de extração de cor ─────────────────────────────────────────────
const _kColorSamplerScript = r'''
(function() {
  if (window._nexusColorSamplerActive) return;
  window._nexusColorSamplerActive = true;

  function sampleVideoColor() {
    try {
      var video = document.querySelector('video');
      if (!video || video.paused || video.readyState < 2) return;
      if (video.videoWidth === 0 || video.videoHeight === 0) return;

      // Canvas de amostragem (baixa resolução para performance)
      var canvas = document.createElement('canvas');
      canvas.width = 16;
      canvas.height = 9;
      var ctx = canvas.getContext('2d');
      ctx.drawImage(video, 0, 0, 16, 9);

      // Amostragem em grid 4x4 nas bordas (evita área central do conteúdo)
      var r = 0, g = 0, b = 0, count = 0;
      var samplePoints = [
        [0,0],[4,0],[8,0],[12,0],[15,0],
        [0,4],[15,4],
        [0,8],[15,8],
      ];
      for (var i = 0; i < samplePoints.length; i++) {
        var px = ctx.getImageData(samplePoints[i][0], samplePoints[i][1], 1, 1).data;
        r += px[0]; g += px[1]; b += px[2]; count++;
      }
      r = Math.round(r / count);
      g = Math.round(g / count);
      b = Math.round(b / count);

      // Escurecer para não ofuscar o conteúdo (multiplicar por 0.6)
      r = Math.round(r * 0.55);
      g = Math.round(g * 0.55);
      b = Math.round(b * 0.55);

      console.log('__nexus_color:' + r + ',' + g + ',' + b);
    } catch(e) {
      // CORS ou erro de canvas — silencioso
    }
  }

  // Amostrar a cada 2 segundos (performance-friendly)
  window._nexusColorInterval = setInterval(sampleVideoColor, 2000);
  // Primeira amostragem após 1s (aguardar vídeo carregar)
  setTimeout(sampleVideoColor, 1000);
})();
''';

// ── Widget principal ──────────────────────────────────────────────────────────
// ignore: must_be_immutable
class ScreeningAmbientGradient extends ConsumerStatefulWidget {
  final String sessionId;
  final InAppWebViewController? webViewController;

  const ScreeningAmbientGradient({
    super.key,
    required this.sessionId,
    this.webViewController,
  });

  @override
  ConsumerState<ScreeningAmbientGradient> createState() =>
      ScreeningAmbientGradientState();
}

class ScreeningAmbientGradientState
    extends ConsumerState<ScreeningAmbientGradient>
    with SingleTickerProviderStateMixin {
  late AnimationController _transitionController;
  Color _currentColor = Colors.black;
  Color _targetColor = Colors.black;
  Timer? _injectTimer;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // Injetar o script de amostragem quando o controller estiver disponível
    _scheduleScriptInjection();
  }

  @override
  void didUpdateWidget(ScreeningAmbientGradient oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.webViewController != oldWidget.webViewController &&
        widget.webViewController != null) {
      _injectColorSampler(widget.webViewController!);
    }
  }

  @override
  void dispose() {
    _transitionController.dispose();
    _injectTimer?.cancel();
    super.dispose();
  }

  void _scheduleScriptInjection() {
    _injectTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final controller = widget.webViewController;
      if (controller != null) {
        _injectColorSampler(controller);
      }
    });
  }

  Future<void> _injectColorSampler(InAppWebViewController controller) async {
    try {
      await controller.evaluateJavascript(source: _kColorSamplerScript);
      debugPrint('[AmbientGradient] color sampler injetado');
    } catch (e) {
      debugPrint('[AmbientGradient] erro ao injetar sampler: $e');
    }
  }

  /// Extrai a cor dominante de um thumbnail (URL) usando palette_generator.
  /// Chamado quando o vídeo é definido mas ainda não carregou no WebView.
  /// Isso garante que o gradiente já esteja animado durante o loading.
  Future<void> loadFromThumbnail(String thumbnailUrl) async {
    if (thumbnailUrl.isEmpty) return;
    try {
      final imageProvider = NetworkImage(thumbnailUrl);
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(100, 56), // baixa resolução para performance
        maximumColorCount: 8,
      );
      // Prioridade: vibrantColor > dominantColor > darkVibrantColor
      final dominantColor = palette.vibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.darkVibrantColor?.color;
      if (dominantColor != null) {
        // Escurecer para não ofuscar o conteúdo (mesmo fator do JS: 0.55)
        final darkened = Color.fromARGB(
          255,
          (dominantColor.red * 0.55).round(),
          (dominantColor.green * 0.55).round(),
          (dominantColor.blue * 0.55).round(),
        );
        _updateAmbientColor(darkened);
        debugPrint('[AmbientGradient] cor do thumbnail: $darkened');
      }
    } catch (e) {
      debugPrint('[AmbientGradient] erro ao processar thumbnail: $e');
    }
  }

  /// Chamado pelo ScreeningPlayerWidget ao receber console.log('__nexus_color:R,G,B')
  void handleColorMessage(String message) {
    if (!message.startsWith('__nexus_color:')) return;
    try {
      final parts = message.substring('__nexus_color:'.length).split(',');
      if (parts.length != 3) return;
      final r = int.parse(parts[0].trim());
      final g = int.parse(parts[1].trim());
      final b = int.parse(parts[2].trim());
      final newColor = Color.fromARGB(255, r, g, b);
      _updateAmbientColor(newColor);
    } catch (e) {
      debugPrint('[AmbientGradient] parse error: $e');
    }
  }

  void _updateAmbientColor(Color newColor) {
    if (!mounted) return;
    // Ignorar mudanças muito pequenas (evita flickering)
    if (_colorDistance(_currentColor, newColor) < 15) return;

    setState(() {
      _currentColor = _targetColor;
      _targetColor = newColor;
    });
    _transitionController.forward(from: 0);

    // Atualizar o provider global para outros widgets poderem consumir
    ref.read(screeningAmbientColorProvider(widget.sessionId).notifier).state =
        newColor;
  }

  double _colorDistance(Color a, Color b) {
    return math.sqrt(
      math.pow(a.red - b.red, 2) +
          math.pow(a.green - b.green, 2) +
          math.pow(a.blue - b.blue, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, _) {
        final t = _transitionController.value;
        final interpolated = Color.lerp(_currentColor, _targetColor, t)!;

        return IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.bottomCenter,
                radius: 1.4,
                colors: [
                  interpolated.withOpacity(0.55),
                  interpolated.withOpacity(0.25),
                  Colors.black.withOpacity(0.0),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Mixin para integrar o AmbientGradient no ScreeningPlayerWidget ─────────────
// Uso: adicionar no onConsoleMessage do InAppWebView:
//   _ambientGradientKey.currentState?.handleColorMessage(msg.message);
//
// E no Stack do player:
//   ScreeningAmbientGradient(
//     key: _ambientGradientKey,
//     sessionId: widget.sessionId,
//     webViewController: _webViewController,
//   ),
