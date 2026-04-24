// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';

/// Parâmetros de layout calculados pelo [DynamicNineSliceLayout].
///
/// Esses valores são pré-computados com [TextPainter] antes de qualquer
/// renderização, garantindo que o widget [NineSliceBubble] receba um tamanho
/// exato e não precise decidir seu próprio tamanho.
///
/// Compatibilidade: quando [mode] != "dynamic_nineslice", os valores são
/// calculados usando a lógica clássica (slice + pad), mantendo total
/// retrocompatibilidade com balões existentes.
class DynamicNineSliceResult {
  /// Largura final do container do balão (em pixels lógicos).
  final double width;

  /// Altura final do container do balão (em pixels lógicos).
  final double height;

  /// Padding a ser aplicado ao conteúdo interno do balão.
  ///
  /// Já inclui a compensação do [kNineSliceOffset] (12 px) do Positioned.
  final EdgeInsets contentPadding;

  /// Número de linhas de texto após a quebra automática.
  final int lineCount;

  /// Linhas de texto quebradas (para debug / testes).
  final List<String> lines;

  const DynamicNineSliceResult({
    required this.width,
    required this.height,
    required this.contentPadding,
    required this.lineCount,
    required this.lines,
  });
}

/// Configuração do conteúdo do modo dynamic_nineslice.
class DynamicContentConfig {
  /// Padding horizontal interno (entre o texto e as bordas de slice).
  final double paddingX;

  /// Padding vertical interno (entre o texto e as bordas de slice).
  final double paddingY;

  /// Largura máxima do balão (em pixels lógicos).
  final double maxWidth;

  /// Largura mínima do balão (em pixels lógicos).
  final double minWidth;

  const DynamicContentConfig({
    this.paddingX = 16.0,
    this.paddingY = 12.0,
    this.maxWidth = 260.0,
    this.minWidth = 60.0,
  });

  /// Lê a configuração do asset_config JSON.
  ///
  /// Retorna valores padrão seguros caso os campos não existam,
  /// garantindo compatibilidade retroativa.
  factory DynamicContentConfig.fromAssetConfig(Map<String, dynamic> assetConfig) {
    final content = assetConfig['content'] as Map<String, dynamic>?;
    if (content == null) {
      return const DynamicContentConfig();
    }
    final padding = content['padding'] as Map<String, dynamic>?;
    return DynamicContentConfig(
      paddingX: _asDouble(padding?['x'], fallback: 16.0),
      paddingY: _asDouble(padding?['y'], fallback: 12.0),
      maxWidth: _asDouble(content['maxWidth'], fallback: 260.0),
      minWidth: _asDouble(content['minWidth'], fallback: 60.0),
    );
  }
}

/// Configuração de comportamento do modo dynamic_nineslice.
class DynamicBehaviorConfig {
  /// Quando true, o balão expande horizontalmente antes de quebrar linha.
  /// Quando false, quebra linha mais cedo (usa ~70% do maxWidth).
  final bool horizontalPriority;

  /// Proporção máxima da altura da tela que o balão pode ocupar.
  final double maxHeightRatio;

  /// Proporção da área central usada como zona de transição (suavização).
  final double transitionZone;

  const DynamicBehaviorConfig({
    this.horizontalPriority = true,
    this.maxHeightRatio = 0.6,
    this.transitionZone = 0.15,
  });

  /// Lê a configuração do asset_config JSON.
  factory DynamicBehaviorConfig.fromAssetConfig(Map<String, dynamic> assetConfig) {
    final behavior = assetConfig['behavior'] as Map<String, dynamic>?;
    if (behavior == null) {
      return const DynamicBehaviorConfig();
    }
    return DynamicBehaviorConfig(
      horizontalPriority: behavior['horizontalPriority'] as bool? ?? true,
      maxHeightRatio: _asDouble(behavior['maxHeightRatio'], fallback: 0.6),
      transitionZone: _asDouble(behavior['transitionZone'], fallback: 0.15),
    );
  }
}

/// Motor de layout pré-calculado para o modo dynamic_nineslice.
///
/// ## Princípio de funcionamento
///
/// No modo clássico, o [NineSliceBubble] decide seu próprio tamanho com base
/// nos constraints do Flutter. Isso pode causar distorções quando o texto é
/// curto (balão muito largo) ou quando há muito texto (bordas comprimidas).
///
/// No modo dinâmico, o layout é calculado ANTES de construir o widget:
/// 1. [TextPainter] mede o texto com a fonte e tamanho corretos.
/// 2. A largura é calculada com `clamp(textWidth + 2*paddingX, minWidth, maxWidth)`.
/// 3. A quebra de linha é aplicada dentro dessa largura.
/// 4. A altura é calculada com base no número de linhas.
/// 5. O widget recebe o tamanho final e apenas desenha — não decide mais.
///
/// ## Compatibilidade retroativa
///
/// Quando [mode] != "dynamic_nineslice" (ou quando não está definido),
/// o método [calculate] retorna null, sinalizando ao caller para usar
/// o comportamento clássico sem alterações.
class DynamicNineSliceLayout {
  /// Offset fixo do Positioned no NineSliceBubble.
  ///
  /// Deve permanecer sincronizado com [kNineSliceOffset] em nine_slice_bubble.dart.
  static const double kNineSliceOffset = 12.0;

  /// Calcula o layout pré-determinado para o modo dynamic_nineslice.
  ///
  /// Retorna [DynamicNineSliceResult] com as dimensões e padding calculados,
  /// ou null se o modo não for "dynamic_nineslice" (compatibilidade clássica).
  ///
  /// ### Parâmetros
  /// - [text]: Texto da mensagem a ser renderizado.
  /// - [textStyle]: Estilo do texto (fonte, tamanho, etc.).
  /// - [sliceInsets]: Bordas de slice do nine-slice (em pixels da imagem).
  /// - [content]: Configuração de conteúdo (padding, maxWidth, minWidth).
  /// - [behavior]: Configuração de comportamento (prioridade, transição).
  /// - [mode]: Modo do balão. Apenas "dynamic_nineslice" ativa o cálculo.
  static DynamicNineSliceResult? calculate({
    required String text,
    required TextStyle textStyle,
    required EdgeInsets sliceInsets,
    required DynamicContentConfig content,
    required DynamicBehaviorConfig behavior,
    required String? mode,
  }) {
    // Compatibilidade: se não for dynamic_nineslice, retorna null
    if (mode != 'dynamic_nineslice') return null;

    // ── Padding total = slice + padding de conteúdo ──────────────────────────
    // O contentPadding efetivo deve compensar o kNineSliceOffset do Positioned,
    // exatamente como _extractNineSliceParams faz para o modo clássico.
    final double innerLeft   = sliceInsets.left   + content.paddingX - kNineSliceOffset;
    final double innerRight  = sliceInsets.right  + content.paddingX - kNineSliceOffset;
    final double innerTop    = sliceInsets.top    + content.paddingY - kNineSliceOffset;
    final double innerBottom = sliceInsets.bottom + content.paddingY - kNineSliceOffset;

    // Garante padding mínimo de 4 px (proteção contra distorção)
    final double safeLeft   = innerLeft.clamp(4.0, double.infinity);
    final double safeRight  = innerRight.clamp(4.0, double.infinity);
    final double safeTop    = innerTop.clamp(4.0, double.infinity);
    final double safeBottom = innerBottom.clamp(4.0, double.infinity);

    // ── Medir texto com TextPainter ──────────────────────────────────────────
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: double.infinity);

    final double rawTextWidth = painter.width;

    // ── Cálculo de largura (clamp) ───────────────────────────────────────────
    // horizontalPriority = true  → expande até maxWidth antes de quebrar linha
    // horizontalPriority = false → quebra linha mais cedo (usa 70% do maxWidth)
    final double effectiveMax = behavior.horizontalPriority
        ? content.maxWidth
        : content.maxWidth * 0.7;

    final double idealWidth = rawTextWidth + safeLeft + safeRight;
    final double logW = idealWidth.clamp(content.minWidth, effectiveMax);
    final double maxContentW = (logW - safeLeft - safeRight).clamp(1.0, double.infinity);

    // ── Quebra de linha ──────────────────────────────────────────────────────
    final breakPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxContentW);

    // Conta as linhas usando getLineBoundaries
    final lineMetrics = breakPainter.computeLineMetrics();
    final int lineCount = lineMetrics.isEmpty ? 1 : lineMetrics.length;

    // Gera lista de linhas para debug (usando wrapping manual)
    final List<String> lines = _wrapText(text, textStyle, maxContentW);

    // ── Cálculo de altura ────────────────────────────────────────────────────
    final double lineHeight = (textStyle.fontSize ?? 14.0) * (textStyle.height ?? 1.45);
    final double textHeight = lineCount * lineHeight;
    final double minContainerH = sliceInsets.top + sliceInsets.bottom + 8.0;
    final double logH = (textHeight + safeTop + safeBottom).clamp(minContainerH, double.infinity);

    return DynamicNineSliceResult(
      width: logW,
      height: logH,
      contentPadding: EdgeInsets.fromLTRB(safeLeft, safeTop, safeRight, safeBottom),
      lineCount: lineCount,
      lines: lines,
    );
  }

  /// Quebra o texto em linhas respeitando a largura máxima de conteúdo.
  ///
  /// Usado internamente para debug e para o preview web.
  static List<String> _wrapText(
    String text,
    TextStyle style,
    double maxContentW,
  ) {
    final measurePainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    final words = text.split(' ');
    final lines = <String>[];
    var current = '';

    for (final word in words) {
      final test = current.isEmpty ? word : '$current $word';
      measurePainter.text = TextSpan(text: test, style: style);
      measurePainter.layout(maxWidth: double.infinity);
      if (measurePainter.width > maxContentW && current.isNotEmpty) {
        lines.add(current);
        current = word;
      } else {
        current = test;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    if (lines.isEmpty) lines.add('');
    return lines;
  }
}

/// Lê um campo do asset_config como double com fallback seguro.
double _asDouble(dynamic value, {required double fallback}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

/// Widget que aplica o layout dinâmico ao [NineSliceBubble].
///
/// Quando o modo é "dynamic_nineslice", pré-calcula as dimensões com
/// [DynamicNineSliceLayout.calculate] e passa um [SizedBox] com tamanho
/// fixo ao filho, eliminando a necessidade do widget filho decidir seu tamanho.
///
/// Quando o modo não é dinâmico, passa o filho diretamente sem alteração,
/// mantendo total compatibilidade com o comportamento clássico.
///
/// ## Uso
/// ```dart
/// DynamicNineSliceWrapper(
///   text: message.text,
///   textStyle: TextStyle(fontSize: 14),
///   sliceInsets: sliceInsets,
///   content: DynamicContentConfig.fromAssetConfig(assetConfig),
///   behavior: DynamicBehaviorConfig.fromAssetConfig(assetConfig),
///   mode: assetConfig['mode'] as String?,
///   builder: (context, result) => NineSliceBubble(
///     // Se result != null, usa as dimensões pré-calculadas
///     contentPadding: result?.contentPadding ?? defaultPadding,
///     // ...
///   ),
/// )
/// ```
class DynamicNineSliceWrapper extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final EdgeInsets sliceInsets;
  final DynamicContentConfig content;
  final DynamicBehaviorConfig behavior;
  final String? mode;

  /// Builder que recebe o resultado do cálculo (null = modo clássico).
  final Widget Function(BuildContext context, DynamicNineSliceResult? result) builder;

  const DynamicNineSliceWrapper({
    super.key,
    required this.text,
    required this.textStyle,
    required this.sliceInsets,
    required this.content,
    required this.behavior,
    required this.mode,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final result = DynamicNineSliceLayout.calculate(
      text: text,
      textStyle: textStyle,
      sliceInsets: sliceInsets,
      content: content,
      behavior: behavior,
      mode: mode,
    );

    if (result == null) {
      // Modo clássico: passa null para o builder usar o comportamento padrão
      return builder(context, null);
    }

    // Modo dinâmico: envolve o filho em um SizedBox com tamanho pré-calculado
    return SizedBox(
      width: result.width,
      height: result.height,
      child: builder(context, result),
    );
  }
}
