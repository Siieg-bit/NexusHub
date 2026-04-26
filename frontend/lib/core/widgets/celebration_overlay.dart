import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// =============================================================================
// CELEBRATION OVERLAY — Confetti e partículas usando flutter_animate
// Inspirado nas animações do OluOlu para check-in e level up
// =============================================================================

/// Overlay de celebração com confetti colorido e partículas.
/// Use [CelebrationOverlay.show] para exibir sobre qualquer tela.
class CelebrationOverlay extends StatefulWidget {
  final Widget child;
  final bool active;
  final CelebrationStyle style;

  const CelebrationOverlay({
    super.key,
    required this.child,
    this.active = false,
    this.style = CelebrationStyle.confetti,
  });

  @override
  State<CelebrationOverlay> createState() => CelebrationOverlayState();

  /// Exibe o overlay de celebração sobre a tela atual
  static void show(
    BuildContext context, {
    CelebrationStyle style = CelebrationStyle.confetti,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CelebrationOverlayEntry(
        style: style,
        onDone: () => entry.remove(),
        duration: duration,
      ),
    );
    overlay.insert(entry);
  }
}

class CelebrationOverlayState extends State<CelebrationOverlay> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.active)
          Positioned.fill(
            child: IgnorePointer(
              child: _CelebrationParticles(style: widget.style),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// ENTRY PARA OVERLAY GLOBAL
// =============================================================================
class _CelebrationOverlayEntry extends StatefulWidget {
  final CelebrationStyle style;
  final VoidCallback onDone;
  final Duration duration;

  const _CelebrationOverlayEntry({
    required this.style,
    required this.onDone,
    required this.duration,
  });

  @override
  State<_CelebrationOverlayEntry> createState() =>
      _CelebrationOverlayEntryState();
}

class _CelebrationOverlayEntryState extends State<_CelebrationOverlayEntry> {
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: _CelebrationParticles(style: widget.style),
    );
  }
}

// =============================================================================
// ESTILOS DE CELEBRAÇÃO
// =============================================================================
enum CelebrationStyle {
  confetti, // Confetti colorido caindo
  stars,    // Estrelas explodindo do centro
  streakFire, // Chamas e faíscas para streak
}

// =============================================================================
// PARTÍCULAS DE CELEBRAÇÃO
// =============================================================================
class _CelebrationParticles extends StatefulWidget {
  final CelebrationStyle style;
  const _CelebrationParticles({required this.style});

  @override
  State<_CelebrationParticles> createState() => _CelebrationParticlesState();
}

class _CelebrationParticlesState extends State<_CelebrationParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();
    _particles = _generateParticles();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Particle> _generateParticles() {
    final count = widget.style == CelebrationStyle.confetti ? 60 : 40;
    return List.generate(count, (i) => _Particle.random(_rng, widget.style));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: size,
          painter: _ParticlePainter(
            particles: _particles,
            progress: _controller.value,
            style: widget.style,
          ),
        );
      },
    );
  }
}

// =============================================================================
// MODELO DE PARTÍCULA
// =============================================================================
class _Particle {
  final double startX;
  final double startY;
  final double velocityX;
  final double velocityY;
  final double size;
  final Color color;
  final double rotation;
  final double rotationSpeed;
  final double delay; // 0.0 a 0.5

  _Particle({
    required this.startX,
    required this.startY,
    required this.velocityX,
    required this.velocityY,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.delay,
  });

  static const _confettiColors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFF6BCB77),
    Color(0xFF4D96FF),
    Color(0xFFFF6FC8),
    Color(0xFFC77DFF),
    Color(0xFFFF9F1C),
    Color(0xFF00F5D4),
  ];

  static const _starColors = [
    Color(0xFFFFD700),
    Color(0xFFFFA500),
    Color(0xFFFFFF00),
    Color(0xFFFFEC8B),
  ];

  static const _fireColors = [
    Color(0xFFFF4500),
    Color(0xFFFF6B00),
    Color(0xFFFF9800),
    Color(0xFFFFD700),
    Color(0xFFFF3D00),
  ];

  factory _Particle.random(math.Random rng, CelebrationStyle style) {
    final colors = style == CelebrationStyle.confetti
        ? _confettiColors
        : style == CelebrationStyle.stars
            ? _starColors
            : _fireColors;

    double startX, startY, vx, vy;

    switch (style) {
      case CelebrationStyle.confetti:
        // Cai de cima
        startX = rng.nextDouble();
        startY = -0.1 - rng.nextDouble() * 0.3;
        vx = (rng.nextDouble() - 0.5) * 0.3;
        vy = 0.4 + rng.nextDouble() * 0.6;
        break;
      case CelebrationStyle.stars:
        // Explode do centro
        startX = 0.5;
        startY = 0.5;
        final angle = rng.nextDouble() * math.pi * 2;
        final speed = 0.3 + rng.nextDouble() * 0.5;
        vx = math.cos(angle) * speed;
        vy = math.sin(angle) * speed;
        break;
      case CelebrationStyle.streakFire:
        // Sobe de baixo
        startX = 0.2 + rng.nextDouble() * 0.6;
        startY = 1.1;
        vx = (rng.nextDouble() - 0.5) * 0.2;
        vy = -(0.5 + rng.nextDouble() * 0.8);
        break;
    }

    return _Particle(
      startX: startX,
      startY: startY,
      velocityX: vx,
      velocityY: vy,
      size: 4.0 + rng.nextDouble() * 8.0,
      color: colors[rng.nextInt(colors.length)],
      rotation: rng.nextDouble() * math.pi * 2,
      rotationSpeed: (rng.nextDouble() - 0.5) * 10,
      delay: rng.nextDouble() * 0.4,
    );
  }
}

// =============================================================================
// PAINTER
// =============================================================================
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final CelebrationStyle style;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Aplicar delay
      final t = ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      // Fade out nos últimos 30%
      final opacity = t < 0.7 ? 1.0 : (1.0 - t) / 0.3;
      if (opacity <= 0) continue;

      // Posição com gravidade para confetti
      final gravity = style == CelebrationStyle.confetti ? 0.3 : 0.0;
      final x = (p.startX + p.velocityX * t) * size.width;
      final y = (p.startY + p.velocityY * t + gravity * t * t) * size.height;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotationSpeed * t);

      if (style == CelebrationStyle.stars) {
        // Estrela de 5 pontas
        _drawStar(canvas, paint, p.size);
      } else if (style == CelebrationStyle.streakFire) {
        // Círculo com glow
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
        final glowPaint = Paint()
          ..color = p.color.withValues(alpha: opacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(Offset.zero, p.size, glowPaint);
      } else {
        // Retângulo (confetti)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.5),
            const Radius.circular(1),
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double size) {
    final path = Path();
    const points = 5;
    final outerRadius = size / 2;
    final innerRadius = outerRadius * 0.4;
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = math.cos(angle) * radius;
      final y = math.sin(angle) * radius;
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
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

// =============================================================================
// EXTENSÃO PARA USAR COM flutter_animate
// =============================================================================

/// Widget de ícone de check-in com animação de celebração encadeada
class CheckInSuccessAnimation extends StatelessWidget {
  final Widget child;
  final bool animate;

  const CheckInSuccessAnimation({
    super.key,
    required this.child,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!animate) return child;
    return child
        .animate()
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1.0, 1.0),
          duration: 600.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 200.ms)
        .then()
        .shimmer(
          duration: 800.ms,
          color: Colors.white.withValues(alpha: 0.4),
        );
  }
}

/// Widget de XP/coins ganhos com animação de pop
class RewardPopAnimation extends StatelessWidget {
  final Widget child;
  final int delayMs;

  const RewardPopAnimation({
    super.key,
    required this.child,
    this.delayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: Duration(milliseconds: delayMs))
        .scale(
          begin: const Offset(0.0, 0.0),
          end: const Offset(1.0, 1.0),
          duration: 500.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 200.ms);
  }
}
