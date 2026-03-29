import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// Fundo decorativo do Amino original com dois efeitos sobrepostos:
/// 1. Padrão de rede/radar: grade pontilhada + linhas concêntricas
///    emanando do centro-superior, criando um efeito de radar sutil.
/// 2. Partículas flutuantes com bokeh (desfoque) em camadas de profundidade.
class AminoParticlesBg extends StatefulWidget {
  final Widget child;
  final int particleCount;
  final Color particleColor;

  const AminoParticlesBg({
    super.key,
    required this.child,
    this.particleCount = 35,
    this.particleColor = Colors.white,
  });

  @override
  State<AminoParticlesBg> createState() => _AminoParticlesBgState();
}

class _AminoParticlesBgState extends State<AminoParticlesBg>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_BokehParticle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _particles =
        List.generate(widget.particleCount, (_) => _generateParticle());
  }

  _BokehParticle _generateParticle() {
    final depth = _random.nextDouble();

    final size = depth < 0.33
        ? _random.nextDouble() * 12 + 8
        : depth < 0.66
            ? _random.nextDouble() * 6 + 4
            : _random.nextDouble() * 3 + 2;

    final blur = depth < 0.33
        ? _random.nextDouble() * 6 + 6
        : depth < 0.66
            ? _random.nextDouble() * 3 + 2
            : _random.nextDouble() * 1.5;

    final opacity = depth < 0.33
        ? _random.nextDouble() * 0.06 + 0.02
        : depth < 0.66
            ? _random.nextDouble() * 0.08 + 0.04
            : _random.nextDouble() * 0.10 + 0.05;

    final speedFactor = depth < 0.33
        ? 0.3
        : depth < 0.66
            ? 0.6
            : 1.0;

    return _BokehParticle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      size: size,
      blur: blur,
      opacity: opacity,
      speedX: (_random.nextDouble() - 0.5) * 0.002 * speedFactor,
      speedY: (_random.nextDouble() - 0.5) * 0.002 * speedFactor,
      isHexagon: _random.nextDouble() < 0.3,
      phase: _random.nextDouble() * 2 * pi,
      depth: depth,
      glowRadius: depth > 0.66 ? _random.nextDouble() * 4 + 2 : 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Stack(
      children: [
        widget.child,
        // Camada 1: Padrão de rede/radar (estático)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _RadarGridPainter(),
            ),
          ),
        ),
        // Camada 2: Partículas bokeh (animadas)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _BokehPainter(
                    particles: _particles,
                    progress: _controller.value,
                    color: widget.particleColor,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// RADAR GRID PAINTER — Padrão de rede do Amino original
// Grade pontilhada + círculos concêntricos emanando do centro-superior.
// ============================================================================
class _RadarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.08);

    // ── Círculos concêntricos ──
    final circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final maxRadius = size.height * 1.2;
    const circleSpacing = 80.0;
    for (double r = circleSpacing; r < maxRadius; r += circleSpacing) {
      canvas.drawCircle(center, r, circlePaint);
    }

    // ── Grade pontilhada ──
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;

    const gridSpacing = 40.0;
    final dotRadius = 1.0;

    for (double x = 0; x < size.width; x += gridSpacing) {
      for (double y = 0; y < size.height; y += gridSpacing) {
        // Fade baseado na distância do centro do radar
        final dist = (Offset(x, y) - center).distance;
        final fade = (1.0 - (dist / maxRadius)).clamp(0.0, 1.0);
        if (fade > 0.05) {
          dotPaint.color = Colors.white.withValues(alpha: 0.025 * fade);
          canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
        }
      }
    }

    // ── Linhas radiais sutis ──
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const lineCount = 12;
    for (int i = 0; i < lineCount; i++) {
      final angle = (2 * pi / lineCount) * i;
      final endX = center.dx + maxRadius * cos(angle);
      final endY = center.dy + maxRadius * sin(angle);
      canvas.drawLine(center, Offset(endX, endY), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// BOKEH PARTICLES
// ============================================================================
class _BokehParticle {
  double x;
  double y;
  final double size;
  final double blur;
  final double opacity;
  final double speedX;
  final double speedY;
  final bool isHexagon;
  final double phase;
  final double depth;
  final double glowRadius;

  _BokehParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.blur,
    required this.opacity,
    required this.speedX,
    required this.speedY,
    required this.isHexagon,
    required this.phase,
    required this.depth,
    required this.glowRadius,
  });
}

class _BokehPainter extends CustomPainter {
  final List<_BokehParticle> particles;
  final double progress;
  final Color color;

  _BokehPainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sorted = List<_BokehParticle>.from(particles)
      ..sort((a, b) => a.depth.compareTo(b.depth));

    for (final p in sorted) {
      final time = progress * 2 * pi;

      final dx = p.x * size.width +
          sin(time + p.phase) * (15 + p.size) +
          p.speedX * size.width * progress * 150;
      final dy = p.y * size.height +
          cos(time * 0.7 + p.phase) * (10 + p.size * 0.5) +
          p.speedY * size.height * progress * 150;

      final px = ((dx % size.width) + size.width) % size.width;
      final py = ((dy % size.height) + size.height) % size.height;

      final pulseOpacity =
          p.opacity * (0.6 + 0.4 * sin(time * 1.5 + p.phase));

      final center = Offset(px, py);

      if (p.glowRadius > 0) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: pulseOpacity * 0.3)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, p.glowRadius * 2);
        canvas.drawCircle(center, p.size + p.glowRadius, glowPaint);
      }

      final paint = Paint()
        ..color = color.withValues(alpha: pulseOpacity)
        ..style = PaintingStyle.fill;

      if (p.blur > 0.5) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, p.blur);
      }

      if (p.isHexagon) {
        _drawHexagon(canvas, center, p.size, paint);
      } else {
        canvas.drawCircle(center, p.size, paint);
      }
    }
  }

  void _drawHexagon(
      Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i - pi / 6;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BokehPainter oldDelegate) => true;
}
