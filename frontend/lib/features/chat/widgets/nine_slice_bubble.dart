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
  /// Por padrão, assume que 30% de cada lado é borda decorativa.
  final EdgeInsets sliceInsets;

  /// Padding interno para o conteúdo (texto da mensagem).
  final EdgeInsets contentPadding;

  NineSliceBubble({
    super.key,
    required this.child,
    required this.imageUrl,
    required this.isMine,
    this.maxWidth = 280,
    this.sliceInsets = const EdgeInsets.all(24),
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
/// Usa [CachedNetworkImage] para cache e [DecorationImage] com
/// [centerSlice] para o efeito de 9-slice nativo do Flutter.
class _NineSliceImage extends StatelessWidget {
  final String imageUrl;
  final EdgeInsets sliceInsets;

  const _NineSliceImage({
    required this.imageUrl,
    required this.sliceInsets,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return CachedNetworkImage(
      imageUrl: imageUrl,
      memCacheWidth: 600,
      memCacheHeight: 400,
      imageBuilder: (context, imageProvider) {
        return Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.fill,
              // centerSlice é o coração do 9-slice no Flutter.
              // Define o retângulo central que será esticado.
              centerSlice: Rect.fromLTRB(
                sliceInsets.left,
                sliceInsets.top,
                // Assumimos imagem de ~100px, então right = 100 - right_inset
                100 - sliceInsets.right,
                100 - sliceInsets.bottom,
              ),
            ),
          ),
        );
      },
      placeholder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(r.s(16)),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(16)),
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
              padding: EdgeInsets.symmetric(horizontal: r.s(18), vertical: r.s(12)),
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

    // Estrelas nos 4 cantos
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
          center.dx + radius * 1.0 * _cos(angle),
          center.dy + radius * 1.0 * _sin(angle),
        );
      } else {
        path.lineTo(
          center.dx + radius * 1.0 * _cos(angle),
          center.dy + radius * 1.0 * _sin(angle),
        );
      }
      path.lineTo(
        center.dx + radius * 0.4 * _cos(innerAngle),
        center.dy + radius * 0.4 * _sin(innerAngle),
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  double _cos(double angle) => _cosVal(angle);
  double _sin(double angle) => _sinVal(angle);

  static double _cosVal(double rad) {
    // Simple cos approximation
    return _dartMathCos(rad);
  }

  static double _sinVal(double rad) {
    return _dartMathSin(rad);
  }

  static double _dartMathCos(double x) {
    // Use dart:math via import workaround
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  static double _dartMathSin(double x) {
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  void _drawHearts(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Corações pequenos nos cantos
    _drawHeart(canvas, Offset(14, 12), 5, paint);
    _drawHeart(canvas, Offset(size.width - 14, size.height - 12), 5, paint);
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy + size * 0.4);
    path.cubicTo(
      center.dx - size, center.dy - size * 0.2,
      center.dx - size * 0.5, center.dy - size,
      center.dx, center.dy - size * 0.4,
    );
    path.cubicTo(
      center.dx + size * 0.5, center.dy - size,
      center.dx + size, center.dy - size * 0.2,
      center.dx, center.dy + size * 0.4,
    );
    canvas.drawPath(path, paint);
  }

  void _drawSparkles(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    // Pontos brilhantes
    canvas.drawCircle(Offset(8, 8), 2, paint);
    canvas.drawCircle(Offset(size.width - 8, 8), 1.5, paint);
    canvas.drawCircle(Offset(size.width / 2, 5), 1, paint);
    canvas.drawCircle(Offset(8, size.height - 8), 1.5, paint);
    canvas.drawCircle(Offset(size.width - 8, size.height - 8), 2, paint);

    // Linhas de brilho
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;

    canvas.drawLine(Offset(8, 5), Offset(8, 11), linePaint);
    canvas.drawLine(Offset(5, 8), Offset(11, 8), linePaint);
  }

  void _drawGlowEdges(Canvas canvas, Size size) {
    // Brilho sutil nas bordas superiores
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.center,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final topRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.4),
      const Radius.circular(18),
    );
    canvas.drawRRect(topRect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _ProceduralFramePainter old) =>
      style != old.style ||
      primaryColor != old.primaryColor ||
      secondaryColor != old.secondaryColor;
}
