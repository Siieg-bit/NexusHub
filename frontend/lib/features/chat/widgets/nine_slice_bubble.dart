import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Offset fixo (em pixels lógicos) que o [NineSliceBubble] aplica ao
/// [Positioned] para expandir a imagem além das bordas do container.
///
/// O [contentPadding] fornecido ao widget já deve incluir esse offset
/// (i.e., `contentPadding = kNineSliceOffset + pad_*`) para que o texto
/// não fique sobre a borda visual do bubble. O [_extractNineSliceParams]
/// em `cosmetics_provider.dart` realiza esse cálculo automaticamente.
const double kNineSliceOffset = 12.0;

/// NineSliceBubble — Motor de renderização 9-slice para Chat Bubbles.
///
/// Usa [Canvas.drawImageNine] diretamente via [CustomPainter], que é a
/// única abordagem no Flutter que não lança assertion. Tanto [DecorationImage]
/// quanto [Image widget] com centerSlice chamam internamente [paintImage]
/// que verifica 'sourceSize == inputSize' e lança assertion quando o
/// container tem tamanho diferente da imagem original.
///
/// [Canvas.drawImageNine] bypassa completamente essa verificação.
class NineSliceBubble extends StatelessWidget {
  final Widget child;
  final String imageUrl;
  final bool isMine;
  final double maxWidth;
  final EdgeInsets sliceInsets;
  final Size imageSize;
  final EdgeInsets contentPadding;

  /// Cor customizada do texto dentro do balão.
  ///
  /// Quando fornecida, sobrescreve o branco padrão do [DefaultTextStyle].
  /// Lida de [asset_config.text_color] via [UserCosmetics.chatBubbleTextColor].
  final Color? textColor;
  /// Polígono opcional de fill (8 pontos normalizados 0–1).
  ///
  /// Quando fornecido, aplica [ClipPath] com o polígono para confinar o texto.
  /// Quando nulo, usa o [contentPadding] normal — comportamento padrão.
  final List<Offset>? polyPoints;

  const NineSliceBubble({
    super.key,
    required this.child,
    required this.imageUrl,
    required this.isMine,
    this.maxWidth = 280,
    this.sliceInsets = const EdgeInsets.all(38),
    this.imageSize = const Size(128, 128),
    // Padding padrão (fallback quando não há asset_config).
    // Fórmula: sliceInset(38) - kNineSliceOffset(12) + padBruto(20/14)
    //   horizontal: 38 - 12 + 20 = 46
    //   vertical:   38 - 12 + 14 = 40
    // Isso garante que o texto fique dentro da fill zone da imagem.
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 46,
      vertical: 40,
    ),
    this.textColor,
    this.polyPoints,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    // Dimensões mínimas do container baseadas na imagem original.
    //
    // O nine-slice funciona corretamente apenas quando o container tem pelo
    // menos o tamanho da "fill zone" (área central da imagem):
    //   fillW = imageSize.width  - sliceInsets.left - sliceInsets.right
    //   fillH = imageSize.height - sliceInsets.top  - sliceInsets.bottom
    //
    // Se o container for menor que isso, o drawImageNine comprime os cantos
    // e deforma a imagem. Usamos a imagem original como mínimo para garantir
    // que os cantos nunca sejam comprimidos.
    //
    // O kNineSliceOffset (12 px) é subtraído porque o Positioned já expande
    // a imagem 12 px além das bordas do container em cada lado — portanto o
    // container precisa ser (imageSize - 2*offset) para que a imagem renderize
    // com seu tamanho original.
    final double minW = (imageSize.width  - 2 * kNineSliceOffset).clamp(48.0, maxWidth);
    final double minH = (imageSize.height - 2 * kNineSliceOffset).clamp(48.0, double.infinity);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: isMine ? 48 : 4,
          right: isMine ? 4 : 48,
          top: r.s(3),
          bottom: r.s(3),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            minWidth: minW,
            minHeight: minH,
          ),
          // O Stack precisa de pelo menos um filho não-posicionado para
          // calcular seu próprio tamanho. Por isso o conteúdo é um filho
          // normal (Padding) e apenas a imagem usa Positioned.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Frame decorativo 9-slice via drawImageNine.
              // O offset negativo expande a imagem kNineSliceOffset px além
              // das bordas do container. O contentPadding já deve compensar
              // esse offset (ver _extractNineSliceParams em cosmetics_provider).
              Positioned(
                top: -kNineSliceOffset,
                bottom: -kNineSliceOffset,
                left: -kNineSliceOffset,
                right: -kNineSliceOffset,
                child: _NineSliceImage(
                  imageUrl: imageUrl,
                  sliceInsets: sliceInsets,
                ),
              ),
              // Conteúdo da mensagem — filho não-posicionado que define o
              // tamanho do Stack. O Container com minHeight já garante que
              // o bubble não fique menor que a imagem original.
              Builder(builder: (context) {
                final textWidget = DefaultTextStyle(
                  style: TextStyle(
                    // textColor tem prioridade; fallback: branco (padrão para frames)
                    color: textColor ?? Colors.white,
                    fontSize: r.fs(14),
                    height: 1.4,
                  ),
                  child: child,
                );
                // Se polyPoints estiver disponível, aplica ClipPath poligonal.
                // O padding ainda é aplicado para garantir espaço mínimo.
                if (polyPoints != null && polyPoints!.length == 8) {
                  return Padding(
                    padding: contentPadding,
                    child: ClipPath(
                      clipper: _PolyClipper(polyPoints!, imageSize, contentPadding),
                      child: textWidget,
                    ),
                  );
                }
                return Padding(
                  padding: contentPadding,
                  child: textWidget,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}


/// CustomClipper que aplica um polígono de fill ao conteúdo do [NineSliceBubble].
///
/// Os [points] são normalizados (0–1) em relação ao tamanho da imagem original.
/// O clipper converte esses pontos para coordenadas de tela usando o tamanho
/// real do widget em tempo de layout.
class _PolyClipper extends CustomClipper<Path> {
  final List<Offset> points;
  final Size imageSize;
  final EdgeInsets padding;
  const _PolyClipper(this.points, this.imageSize, this.padding);
  @override
  Path getClip(Size size) {
    // O conteúdo já tem o padding aplicado, então o tamanho aqui é o do
    // conteúdo interno. Precisamos mapear os pontos normalizados (relativos
    // à imagem original) para o espaço do conteúdo.
    //
    // O conteúdo começa em (padding.left, padding.top) relativo ao container,
    // então subtraímos o padding ao converter.
    final double scaleX = (size.width  + padding.horizontal) / imageSize.width;
    final double scaleY = (size.height + padding.vertical)   / imageSize.height;
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final px = points[i].dx * imageSize.width  * scaleX - padding.left;
      final py = points[i].dy * imageSize.height * scaleY - padding.top;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    return path;
  }
  @override
  bool shouldReclip(_PolyClipper old) =>
      old.points != points || old.imageSize != imageSize || old.padding != padding;
}

/// Carrega a imagem como [ui.Image] e renderiza via [CustomPainter] com
/// [Canvas.drawImageNine] — sem assertion, sem DecorationImage, sem Image widget.
class _NineSliceImage extends StatefulWidget {
  final String imageUrl;
  final EdgeInsets sliceInsets;

  const _NineSliceImage({
    required this.imageUrl,
    required this.sliceInsets,
  });

  @override
  State<_NineSliceImage> createState() => _NineSliceImageState();
}

class _NineSliceImageState extends State<_NineSliceImage> {
  ui.Image? _image;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_NineSliceImage old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl) {
      setState(() {
        _image = null;
        _loading = true;
        _error = false;
      });
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    try {
      final provider = CachedNetworkImageProvider(widget.imageUrl);
      final stream = provider.resolve(ImageConfiguration.empty);
      final completer = Completer<ui.Image>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) completer.complete(info.image);
          stream.removeListener(listener);
        },
        onError: (e, st) {
          if (!completer.isCompleted) completer.completeError(e, st!);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      final img = await completer.future;
      if (mounted) setState(() { _image = img; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        decoration: BoxDecoration(
          color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
      );
    }
    if (_error || _image == null) {
      return Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
          ),
        ),
      );
    }
    return CustomPaint(
      painter: _NineSlicePainter(
        image: _image!,
        center: Rect.fromLTRB(
          widget.sliceInsets.left,
          widget.sliceInsets.top,
          _image!.width.toDouble() - widget.sliceInsets.right,
          _image!.height.toDouble() - widget.sliceInsets.bottom,
        ),
      ),
    );
  }
}

/// Painter que usa [Canvas.drawImageNine] — a única API do Flutter para
/// nine-slice que não passa por [paintImage] e portanto não lança assertion.
class _NineSlicePainter extends CustomPainter {
  final ui.Image image;
  final Rect center;

  const _NineSlicePainter({required this.image, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageNine(
      image,
      center,
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_NineSlicePainter old) =>
      old.image != image || old.center != center;
}

/// Widget público para usar o nine-slice em qualquer lugar do app.
/// Usa [Canvas.drawImageNine] internamente — sem assertion.
class NineSlicePreview extends StatelessWidget {
  final String imageUrl;
  final EdgeInsets sliceInsets;
  final Widget? child;

  const NineSlicePreview({
    super.key,
    required this.imageUrl,
    this.sliceInsets = const EdgeInsets.all(38),
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (child == null) {
      return _NineSliceImage(
        imageUrl: imageUrl,
        sliceInsets: sliceInsets,
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: _NineSliceImage(
            imageUrl: imageUrl,
            sliceInsets: sliceInsets,
          ),
        ),
        child!,
      ],
    );
  }
}

/// Painter alternativo para frames procedurais (sem imagem).
class ProceduralBubbleFrame extends StatelessWidget {
  final Widget child;
  final bool isMine;
  final String style;
  final Color primaryColor;
  final Color secondaryColor;
  final double maxWidth;

  const ProceduralBubbleFrame({
    super.key,
    required this.child,
    required this.isMine,
    this.style = 'gradient',
    this.primaryColor = const Color(0xFFE91E63),
    this.secondaryColor = const Color(0xFFFF5252),
    this.maxWidth = 280,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: isMine ? 48 : 4,
          right: isMine ? 4 : 48,
          top: r.s(3),
          bottom: r.s(3),
        ),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth, minHeight: 48),
          child: CustomPaint(
            painter: _ProceduralFramePainter(
              style: style,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              isMine: isMine,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.s(18),
                vertical: r.s(12),
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.fs(14),
                  height: 1.4,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProceduralFramePainter extends CustomPainter {
  final String style;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isMine;

  _ProceduralFramePainter({
    required this.style,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isMine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const radius = Radius.circular(18);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor.withValues(alpha: 0.85),
          secondaryColor.withValues(alpha: 0.85),
        ],
        begin: isMine ? Alignment.topRight : Alignment.topLeft,
        end: isMine ? Alignment.bottomLeft : Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.4),
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.4),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(_ProceduralFramePainter old) =>
      old.style != style ||
      old.primaryColor != primaryColor ||
      old.secondaryColor != secondaryColor;
}
