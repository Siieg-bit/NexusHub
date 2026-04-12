import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';

/// NineSliceBubble — Motor de renderização 9-slice para Chat Bubbles.
///
/// No Amino original, os "Bubble Frames" comprados na loja são imagens PNG
/// decorativas que envolvem o texto. A técnica de 9-slice (ou 9-patch no Android)
/// divide a imagem em 9 regiões:
///
/// ```
/// ┌───┬───────┬───┐
/// │ 1 │   2   │ 3 │  ← cantos e borda superior (fixos)
/// ├───┼───────┼───┤
/// │ 4 │   5   │ 6 │  ← bordas laterais (esticam verticalmente)
/// ├───┼───────┼───┤
/// │ 7 │   8   │ 9 │  ← cantos e borda inferior (fixos)
/// └───┴───────┴───┘
/// ```
///
/// As 4 regiões de canto (1,3,7,9) mantêm tamanho fixo.
/// As 4 regiões de borda (2,4,6,8) esticam em uma direção.
/// A região central (5) estica em ambas as direções.
///
/// Isso permite que decorações nos cantos (flores, estrelas, etc.)
/// fiquem intactas independente do tamanho da mensagem.
class NineSliceBubble extends StatelessWidget {
  final Widget child;
  final String imageUrl;
  final bool isMine;
  final double maxWidth;

  /// Insets definem o tamanho das bordas fixas (em pixels da imagem).
  /// Para a imagem padrão de 128×128px com artes nos cantos, use EdgeInsets.all(38).
  final EdgeInsets sliceInsets;

  /// Dimensões reais da imagem PNG em pixels. Padrão: 128×128.
  final Size imageSize;

  /// Padding interno para o conteúdo (texto da mensagem).
  final EdgeInsets contentPadding;

  const NineSliceBubble({
    super.key,
    required this.child,
    required this.imageUrl,
    required this.isMine,
    this.maxWidth = 280,
    this.sliceInsets = const EdgeInsets.all(38),
    this.imageSize = const Size(128, 128),
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 14,
    ),
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Frame decorativo 9-slice ──
              Positioned(
                top: -12,
                bottom: -12,
                left: -12,
                right: -12,
                child: _NineSliceImage(
                  imageUrl: imageUrl,
                  sliceInsets: sliceInsets,
                  imageSize: imageSize,
                ),
              ),

              // ── Conteúdo da mensagem ──
              Padding(
                padding: contentPadding,
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.fs(14),
                    height: 1.4,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget interno que renderiza a imagem com 9-slice scaling.
///
/// IMPORTANTE: usa o widget [Image] nativo do Flutter com [centerSlice],
/// NÃO [DecorationImage] — o Flutter lança assertion error quando
/// [DecorationImage.centerSlice] é usado sem fit exato.
///
/// O widget [Image] com [centerSlice] não tem essa restrição e é a
/// abordagem correta para nine-slice no Flutter.
class _NineSliceImage extends StatelessWidget {
  final String imageUrl;
  final EdgeInsets sliceInsets;
  final Size imageSize;

  const _NineSliceImage({
    required this.imageUrl,
    required this.sliceInsets,
    this.imageSize = const Size(128, 128),
  });

  @override
  Widget build(BuildContext context) {
    // centerSlice: região central esticável em pixels da imagem original.
    // Os 4 cantos fora desse rect são renderizados em tamanho fixo.
    final centerSlice = Rect.fromLTRB(
      sliceInsets.left,
      sliceInsets.top,
      imageSize.width - sliceInsets.right,
      imageSize.height - sliceInsets.bottom,
    );

    return CachedNetworkImage(
      imageUrl: imageUrl,
      memCacheWidth: imageSize.width.toInt() * 2,
      memCacheHeight: imageSize.height.toInt() * 2,
      imageBuilder: (context, imageProvider) {
        // Usa Image widget com centerSlice — abordagem correta para nine-slice.
        // DecorationImage+centerSlice lança assertion no Flutter moderno.
        return Image(
          image: imageProvider,
          fit: BoxFit.fill,
          centerSlice: centerSlice,
          width: double.infinity,
          height: double.infinity,
        );
      },
      placeholder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
    );
  }
}

/// Painter alternativo para frames que não são imagens,
/// mas padrões decorativos gerados proceduralmente.
///
/// Suporta diferentes estilos de decoração:
/// - stars: estrelinhas nos cantos
/// - hearts: corações nos cantos
/// - sparkle: brilhos/faíscas
/// - gradient: gradiente decorativo nas bordas
class ProceduralBubbleFrame extends StatelessWidget {
  final Widget child;
  final bool isMine;
  final String style; // 'stars', 'hearts', 'sparkle', 'gradient'
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
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(18), vertical: r.s(12)),
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

    // Fundo com gradiente
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

    // Borda decorativa
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

    // Decorações nos cantos baseadas no estilo
    switch (style) {
      case 'stars':
        _drawStars(canvas, size);
        break;
      case 'hearts':
        _drawHearts(canvas, size);
        break;
      case 'sparkle':
        _drawSparkles(canvas, size);
        break;
      case 'gradient':
      default:
        _drawGlowEdges(canvas, size);
        break;
    }
  }

  void _drawStars(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    _drawStar(canvas, Offset(12, 10), 4, paint);
    _drawStar(canvas, Offset(size.width - 12, 10), 3.5, paint);
    _drawStar(canvas, Offset(10, size.height - 10), 3, paint);
    _drawStar(canvas, Offset(size.width - 10, size.height - 10), 4.5, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 72 - 90) * 3.14159 / 180;
      final innerAngle = ((i * 72) + 36 - 90) * 3.14159 / 180;
      if (i == 0) {
        path.moveTo(
          center.dx + radius * _cos(angle),
          center.dy + radius * _sin(angle),
        );
      } else {
        path.lineTo(
          center.dx + radius * _cos(angle),
          center.dy + radius * _sin(angle),
        );
      }
      path.lineTo(
        center.dx + (radius * 0.4) * _cos(innerAngle),
        center.dy + (radius * 0.4) * _sin(innerAngle),
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawHearts(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    _drawHeart(canvas, Offset(10, 10), 5, paint);
    _drawHeart(canvas, Offset(size.width - 10, 10), 4, paint);
    _drawHeart(canvas, Offset(10, size.height - 10), 4, paint);
    _drawHeart(canvas, Offset(size.width - 10, size.height - 10), 5, paint);
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy + size * 0.3);
    path.cubicTo(
      center.dx - size, center.dy - size * 0.5,
      center.dx - size * 1.5, center.dy + size * 0.5,
      center.dx, center.dy + size,
    );
    path.cubicTo(
      center.dx + size * 1.5, center.dy + size * 0.5,
      center.dx + size, center.dy - size * 0.5,
      center.dx, center.dy + size * 0.3,
    );
    canvas.drawPath(path, paint);
  }

  void _drawSparkles(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    _drawSparkle(canvas, Offset(10, 10), 5, paint);
    _drawSparkle(canvas, Offset(size.width - 10, 12), 4, paint);
    _drawSparkle(canvas, Offset(12, size.height - 10), 4, paint);
    _drawSparkle(canvas, Offset(size.width - 12, size.height - 10), 5, paint);
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Paint paint) {
    for (int i = 0; i < 4; i++) {
      final angle = i * 45 * 3.14159 / 180;
      canvas.drawLine(
        Offset(center.dx - radius * _cos(angle), center.dy - radius * _sin(angle)),
        Offset(center.dx + radius * _cos(angle), center.dy + radius * _sin(angle)),
        paint,
      );
    }
  }

  void _drawGlowEdges(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.3),
          Colors.transparent,
        ],
        radius: 0.8,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);
  }

  double _cos(double angle) => (angle == 0) ? 1.0 : (angle == 3.14159 / 2) ? 0.0 : _mathCos(angle);
  double _sin(double angle) => (angle == 0) ? 0.0 : (angle == 3.14159 / 2) ? 1.0 : _mathSin(angle);

  double _mathCos(double x) {
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  double _mathSin(double x) {
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  @override
  bool shouldRepaint(_ProceduralFramePainter old) =>
      old.style != style ||
      old.primaryColor != primaryColor ||
      old.secondaryColor != secondaryColor;
}
