import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../utils/responsive.dart';

/// Dialog fullscreen de Level Up estilo Amino Apps.
///
/// Exibe:
///   - Confetti animado caindo do topo
///   - Número do nível com glow pulsante
///   - Título desbloqueado
///   - Barra de progresso para o próximo nível
///   - Botão "Incrível!" para fechar
///
/// Uso:
/// ```dart
/// LevelUpDialog.show(context, newLevel: 5, newTitle: 'Veterano');
/// ```
class LevelUpDialog {
  static Future<void> show(
    BuildContext context, {
    required int newLevel,
    String? newTitle,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Level Up',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 500),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.elasticOut,
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return _LevelUpContent(
          newLevel: newLevel,
          newTitle: newTitle ?? _getTitleForLevel(newLevel),
        );
      },
    );
  }

  static String _getTitleForLevel(int level) {
    const titles = {
      1: 'Novato',
      2: 'Iniciante',
      3: 'Aprendiz',
      4: 'Explorador',
      5: 'Aventureiro',
      6: 'Contribuidor',
      7: 'Regular',
      8: 'Dedicado',
      9: 'Ativo',
      10: 'Veterano',
      11: 'Expert',
      12: 'Mestre',
      13: 'Guru',
      14: 'Sábio',
      15: 'Lendário',
      16: 'Mítico',
      17: 'Divino',
      18: 'Celestial',
      19: 'Transcendente',
      20: 'Supremo',
    };
    return titles[level] ?? 'Nível $level';
  }
}

class _LevelUpContent extends StatefulWidget {
  final int newLevel;
  final String newTitle;

  const _LevelUpContent({
    required this.newLevel,
    required this.newTitle,
  });

  @override
  State<_LevelUpContent> createState() => _LevelUpContentState();
}

class _LevelUpContentState extends State<_LevelUpContent>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _confettiController;
  late AnimationController _slideController;
  late Animation<double> _glowAnimation;
  late Animation<double> _slideAnimation;
  final List<_ConfettiParticle> _particles = [];
  final _random = Random();

  @override
  void initState() {
      final r = context.r;
    super.initState();

    // Glow pulsante no número do nível
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Confetti caindo
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Slide in do conteúdo
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    );

    // Gerar partículas de confetti
    for (int i = 0; i < 60; i++) {
      _particles.add(_ConfettiParticle(
        x: _random.nextDouble(),
        y: _random.nextDouble() * -1.0,
        speed: 0.2 + _random.nextDouble() * 0.5,
        size: r.s(4) + _random.nextDouble() * 8,
        color: [
          AppTheme.accentColor,
          AppTheme.fabPink,
          const Color(0xFFFFD700),
          const Color(0xFF00E676),
          const Color(0xFF7C4DFF),
          const Color(0xFFFF6D00),
        ][_random.nextInt(6)],
        rotation: _random.nextDouble() * 360,
        rotationSpeed: _random.nextDouble() * 4 - 2,
        wobble: _random.nextDouble() * 0.02,
      ));
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _confettiController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final levelColor = AppTheme.getLevelColor(widget.newLevel);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── CONFETTI ──
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, _) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _confettiController.value,
                ),
              );
            },
          ),

          // ── CONTEÚDO CENTRAL ──
          Center(
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - _slideAnimation.value)),
                  child: Opacity(
                    opacity: _slideAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: r.s(40)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Estrela decorativa
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: r.s(40),
                      color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                    ),
                    SizedBox(height: r.s(8)),

                    // "LEVEL UP!"
                    Text(
                      'LEVEL UP!',
                      style: TextStyle(
                        fontSize: r.fs(16),
                        fontWeight: FontWeight.w800,
                        color: context.textSecondary,
                        letterSpacing: 4,
                      ),
                    ),
                    SizedBox(height: r.s(20)),

                    // Número do nível com glow
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, _) {
                        return Container(
                          width: r.s(120),
                          height: r.s(120),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                levelColor.withValues(
                                    alpha: 0.3 * _glowAnimation.value),
                                Colors.transparent,
                              ],
                              radius: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: levelColor
                                    .withValues(alpha: 0.4 * _glowAnimation.value),
                                blurRadius: 30 * _glowAnimation.value,
                                spreadRadius: 5 * _glowAnimation.value,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${widget.newLevel}',
                                  style: TextStyle(
                                    fontSize: r.fs(52),
                                    fontWeight: FontWeight.w900,
                                    color: levelColor,
                                    height: 1,
                                    shadows: [
                                      Shadow(
                                        color: levelColor.withValues(alpha: 0.5),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: r.s(24)),

                    // Título desbloqueado
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(20), vertical: r.s(8)),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            levelColor.withValues(alpha: 0.3),
                            levelColor.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(r.s(20)),
                        border: Border.all(
                          color: levelColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        widget.newTitle,
                        style: TextStyle(
                          fontSize: r.fs(18),
                          fontWeight: FontWeight.w800,
                          color: levelColor,
                        ),
                      ),
                    ),
                    SizedBox(height: r.s(12)),

                    Text(
                      'Novo título desbloqueado!',
                      style: TextStyle(
                        fontSize: r.fs(13),
                        color: context.textSecondary,
                      ),
                    ),
                    SizedBox(height: r.s(40)),

                    // Botão "Incrível!"
                    SizedBox(
                      width: r.s(200),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: levelColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: r.s(14)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r.s(25)),
                          ),
                          elevation: 8,
                          shadowColor: levelColor.withValues(alpha: 0.5),
                        ),
                        child: Text(
                          'Incrível!',
                          style: TextStyle(
                            fontSize: r.fs(16),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONFETTI SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════

class _ConfettiParticle {
  double x;
  double y;
  final double speed;
  final double size;
  final Color color;
  double rotation;
  final double rotationSpeed;
  final double wobble;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.wobble,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Atualizar posição
      final y = ((p.y + progress * p.speed * 3) % 1.3) * size.height;
      final x = (p.x + sin(progress * 10 + p.rotation) * p.wobble) *
          size.width;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * p.rotationSpeed * pi);

      final paint = Paint()
        ..color = p.color.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      // Desenhar retângulo de confetti
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          Radius.circular(p.size * 0.15),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
