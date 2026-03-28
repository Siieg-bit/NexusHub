import 'dart:math';
import 'package:flutter/material.dart';

/// Efeito de partículas flutuantes (bokeh) do Amino original.
/// Hexágonos/círculos brancos semi-transparentes flutuando no fundo roxo-índigo.
class AminoParticlesBg extends StatefulWidget {
  final Widget child;
  final int particleCount;
  final Color particleColor;

  const AminoParticlesBg({
    super.key,
    required this.child,
    this.particleCount = 30,
    this.particleColor = Colors.white,
  });

  @override
  State<AminoParticlesBg> createState() => _AminoParticlesBgState();
}

class _AminoParticlesBgState extends State<AminoParticlesBg>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _particles = List.generate(widget.particleCount, (_) => _generateParticle());
  }

  _Particle _generateParticle() {
    return _Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      size: _random.nextDouble() * 6 + 2, // 2-8px
      opacity: _random.nextDouble() * 0.12 + 0.03, // 0.03-0.15
      speedX: (_random.nextDouble() - 0.5) * 0.003,
      speedY: (_random.nextDouble() - 0.5) * 0.003,
      isHexagon: _random.nextBool(),
      phase: _random.nextDouble() * 2 * pi,
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
                  painter: _ParticlesPainter(
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

class _Particle {
  double x;
  double y;
  final double size;
  final double opacity;
  final double speedX;
  final double speedY;
  final bool isHexagon;
  final double phase;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.speedX,
    required this.speedY,
    required this.isHexagon,
    required this.phase,
  });
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color color;

  _ParticlesPainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final time = progress * 2 * pi;
      final dx = p.x * size.width + sin(time + p.phase) * 20 + p.speedX * size.width * progress * 100;
      final dy = p.y * size.height + cos(time + p.phase) * 15 + p.speedY * size.height * progress * 100;

      // Wrap around
      final px = dx % size.width;
      final py = dy % size.height;

      // Pulsing opacity
      final pulseOpacity = p.opacity * (0.7 + 0.3 * sin(time * 2 + p.phase));

      final paint = Paint()
        ..color = color.withValues(alpha: pulseOpacity)
        ..style = PaintingStyle.fill;

      if (p.isHexagon) {
        _drawHexagon(canvas, Offset(px, py), p.size, paint);
      } else {
        canvas.drawCircle(Offset(px, py), p.size, paint);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
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
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) => true;
}
