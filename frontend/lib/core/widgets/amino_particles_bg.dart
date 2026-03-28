import 'dart:math';
import 'package:flutter/material.dart';

/// Efeito de partículas flutuantes com bokeh (desfoque) do Amino original.
/// Partículas com blur variável para criar sensação de profundidade:
/// - Camada de fundo: grandes, muito desfocadas, opacidade baixa
/// - Camada do meio: médias, desfoque moderado
/// - Camada da frente: pequenas, nítidas, com glow sutil
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
    // Camada de profundidade: 0 = fundo (grande, blur alto), 1 = frente (pequena, nítida)
    final depth = _random.nextDouble();

    // Partículas de fundo: grandes (8-20px), blur alto (6-12), opacidade baixa
    // Partículas de frente: pequenas (2-5px), blur baixo (0-2), opacidade mais alta
    final size = depth < 0.33
        ? _random.nextDouble() * 12 + 8 // Fundo: 8-20px
        : depth < 0.66
            ? _random.nextDouble() * 6 + 4 // Meio: 4-10px
            : _random.nextDouble() * 3 + 2; // Frente: 2-5px

    final blur = depth < 0.33
        ? _random.nextDouble() * 6 + 6 // Fundo: blur 6-12
        : depth < 0.66
            ? _random.nextDouble() * 3 + 2 // Meio: blur 2-5
            : _random.nextDouble() * 1.5; // Frente: blur 0-1.5

    final opacity = depth < 0.33
        ? _random.nextDouble() * 0.06 + 0.02 // Fundo: 0.02-0.08
        : depth < 0.66
            ? _random.nextDouble() * 0.08 + 0.04 // Meio: 0.04-0.12
            : _random.nextDouble() * 0.10 + 0.05; // Frente: 0.05-0.15

    // Velocidade inversamente proporcional à profundidade (parallax)
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
      isHexagon: _random.nextDouble() < 0.3, // 30% hexágonos
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
    return Stack(
      children: [
        widget.child,
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
    // Ordenar por profundidade: fundo primeiro, frente por último
    final sorted = List<_BokehParticle>.from(particles)
      ..sort((a, b) => a.depth.compareTo(b.depth));

    for (final p in sorted) {
      final time = progress * 2 * pi;

      // Movimento suave com drift + oscilação senoidal
      final dx = p.x * size.width +
          sin(time + p.phase) * (15 + p.size) +
          p.speedX * size.width * progress * 150;
      final dy = p.y * size.height +
          cos(time * 0.7 + p.phase) * (10 + p.size * 0.5) +
          p.speedY * size.height * progress * 150;

      // Wrap around
      final px = ((dx % size.width) + size.width) % size.width;
      final py = ((dy % size.height) + size.height) % size.height;

      // Pulsing opacity (respiração suave)
      final pulseOpacity =
          p.opacity * (0.6 + 0.4 * sin(time * 1.5 + p.phase));

      final center = Offset(px, py);

      // Glow para partículas da frente
      if (p.glowRadius > 0) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: pulseOpacity * 0.3)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, p.glowRadius * 2);
        canvas.drawCircle(center, p.size + p.glowRadius, glowPaint);
      }

      // Partícula principal com blur (bokeh)
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
