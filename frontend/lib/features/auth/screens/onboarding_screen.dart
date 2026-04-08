import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/amino_animations.dart';
import '../../../core/utils/responsive.dart';

// Cores extraídas da logo oficial do NexusHub
const Color _neonRed    = Color(0xFFE8003A);
const Color _neonPink   = Color(0xFFFF2D78);
const Color _neonPurple = Color(0xFF8B00FF);
const Color _neonBlue   = Color(0xFF0066FF);
const Color _neonCyan   = Color(0xFF00E5FF);
const Color _bgBlack    = Color(0xFF000000);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _particleController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: _bgBlack,
      body: Stack(
        children: [
          // Partículas neon de fundo
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) => CustomPaint(
                painter: _NeonParticlesPainter(_particleController.value),
              ),
            ),
          ),
          // Aura radial animada
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) {
                final double intensity = 0.06 + _glowController.value * 0.04;
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.0, -0.25),
                      radius: 0.9,
                      colors: [
                        _neonPink.withValues(alpha: intensity),
                        _neonPurple.withValues(alpha: intensity * 0.5),
                        _bgBlack.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Conteúdo principal
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.s(28)),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  AminoAnimations.scaleIn(
                    child: _GlowLogo(
                      controller: _glowController,
                      size: r.s(160),
                    ),
                  ),
                  SizedBox(height: r.s(28)),
                  AminoAnimations.fadeIn(
                    delay: const Duration(milliseconds: 200),
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [_neonPink, _neonPurple, _neonCyan],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                      child: Text(
                        'NexusHub',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.fs(38),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: r.s(8)),
                  AminoAnimations.fadeIn(
                    delay: const Duration(milliseconds: 300),
                    child: Text(
                      'Sua comunidade, seu mundo.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: r.fs(15),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  AminoAnimations.slideUp(
                    delay: const Duration(milliseconds: 350),
                    child: _FeaturesList(r: r),
                  ),
                  const Spacer(flex: 2),
                  AminoAnimations.slideUp(
                    delay: const Duration(milliseconds: 500),
                    child: Column(
                      children: [
                        // Botão Criar Conta
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final double pulse = _pulseController.value;
                            return Container(
                              width: double.infinity,
                              height: r.s(54),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_neonRed, _neonPink, _neonPurple, _neonBlue],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(r.s(16)),
                                boxShadow: [
                                  BoxShadow(
                                    color: _neonPink.withValues(
                                      alpha: 0.3 + pulse * 0.25,
                                    ),
                                    blurRadius: 20.0 + pulse * 10.0,
                                    spreadRadius: 0.0,
                                  ),
                                  BoxShadow(
                                    color: _neonBlue.withValues(
                                      alpha: 0.2 + pulse * 0.15,
                                    ),
                                    blurRadius: 30.0,
                                    spreadRadius: -5.0,
                                    offset: const Offset(0.0, 8.0),
                                  ),
                                ],
                              ),
                              child: child,
                            );
                          },
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => context.go('/signup'),
                              borderRadius: BorderRadius.circular(r.s(16)),
                              child: Center(
                                child: Text(
                                  'Criar Conta',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: r.fs(16),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: r.s(14)),
                        // Botão Já tenho conta
                        SizedBox(
                          width: double.infinity,
                          height: r.s(54),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(r.s(16)),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(r.s(16)),
                                  border: Border.all(
                                    color: _neonCyan.withValues(alpha: 0.3),
                                    width: 1.0,
                                  ),
                                ),
                                child: TextButton(
                                  onPressed: () => context.go('/login'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    textStyle: TextStyle(
                                      fontSize: r.fs(16),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  child: const Text('Já tenho conta'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.s(20)),
                  AminoAnimations.fadeIn(
                    delay: const Duration(milliseconds: 700),
                    child: Text(
                      'Ao continuar, você concorda com os Termos de Uso\ne Política de Privacidade.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.28),
                        fontSize: r.fs(11),
                        height: 1.4,
                      ),
                    ),
                  ),
                  SizedBox(height: r.s(24)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Logo com glow neon animado
class _GlowLogo extends StatelessWidget {
  final AnimationController controller;
  final double size;
  const _GlowLogo({required this.controller, required this.size});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final double glow = controller.value;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _neonPink.withValues(alpha: 0.25 + glow * 0.35),
                blurRadius: 40.0 + glow * 30.0,
                spreadRadius: 5.0 + glow * 8.0,
              ),
              BoxShadow(
                color: _neonCyan.withValues(alpha: 0.15 + glow * 0.25),
                blurRadius: 25.0 + glow * 20.0,
                spreadRadius: 0.0,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.04 + glow * 0.06),
                blurRadius: 15.0,
                spreadRadius: -5.0,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ClipOval(
        child: Image.asset(
          'assets/images/nexushub_logo.jpg',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

// Lista de features
class _FeaturesList extends StatelessWidget {
  final dynamic r;
  const _FeaturesList({required this.r});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _NeonFeatureRow(
          icon: Icons.groups_rounded,
          gradientColors: const [_neonRed, _neonPink],
          text: 'Milhares de comunidades para explorar',
          r: r,
        ),
        SizedBox(height: r.s(14)),
        _NeonFeatureRow(
          icon: Icons.chat_bubble_rounded,
          gradientColors: const [_neonPurple, _neonBlue],
          text: 'Chat em tempo real com seus amigos',
          r: r,
        ),
        SizedBox(height: r.s(14)),
        _NeonFeatureRow(
          icon: Icons.auto_awesome_rounded,
          gradientColors: const [_neonBlue, _neonCyan],
          text: 'Personalize seu perfil e suba de nível',
          r: r,
        ),
      ],
    );
  }
}

class _NeonFeatureRow extends StatelessWidget {
  final IconData icon;
  final List<Color> gradientColors;
  final String text;
  final dynamic r;

  const _NeonFeatureRow({
    required this.icon,
    required this.gradientColors,
    required this.text,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: r.s(42),
          height: r.s(42),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(r.s(12)),
            boxShadow: [
              BoxShadow(
                color: gradientColors.last.withValues(alpha: 0.35),
                blurRadius: 12.0,
                spreadRadius: 0.0,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: r.s(20)),
        ),
        SizedBox(width: r.s(14)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: r.fs(14),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// Partículas neon flutuantes no fundo
class _NeonParticlesPainter extends CustomPainter {
  final double progress;

  static final List<_Particle> _particles = List.generate(30, (i) {
    final rng = math.Random(i * 7 + 13);
    return _Particle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: 1.0 + rng.nextDouble() * 2.5,
      speed: 0.03 + rng.nextDouble() * 0.06,
      phase: rng.nextDouble() * math.pi * 2.0,
      colorIndex: i % 4,
    );
  });

  static const List<Color> _colors = [
    _neonPink,
    _neonCyan,
    _neonPurple,
    _neonBlue,
  ];

  _NeonParticlesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final double y = (p.y + progress * p.speed) % 1.0;
      final double x = p.x + math.sin(progress * math.pi * 2.0 + p.phase) * 0.02;
      final double opacity = 0.15 + math.sin(progress * math.pi * 4.0 + p.phase) * 0.1;
      final paint = Paint()
        ..color = _colors[p.colorIndex].withValues(
          alpha: opacity.clamp(0.05, 0.4),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_NeonParticlesPainter old) => old.progress != progress;
}

class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double phase;
  final int colorIndex;

  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
    required this.colorIndex,
  });
}
