import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/utils/amino_animations.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/nexus_theme_extension.dart';

/// Tela de Onboarding — réplica fiel do Amino Apps.
/// Fundo escuro com gradiente animado, logo centralizado, botões translúcidos.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.nexusTheme.backgroundPrimary,
                  Color.lerp(
                    const Color(0xFF0F0F1A),
                    const Color(0xFF1A001A),
                    _bgController.value * 0.3,
                  )!,
                  context.nexusTheme.backgroundPrimary,
                ],
                stops: [0.0, 0.5 + _bgController.value * 0.2, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(32)),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Logo e Branding
                AminoAnimations.scaleIn(
                  child: Column(
                    children: [
                      Container(
                        width: r.s(110),
                        height: r.s(110),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF2D78).withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/nexushub_logo.jpg',
                            width: r.s(110),
                            height: r.s(110),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SizedBox(height: r.s(24)),
                      Text(
                        s.nexusHub,
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontSize: r.fs(36),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: r.s(8)),
                      Text(
                        'Sua comunidade, seu mundo.',
                        style: TextStyle(
                          color: context.nexusTheme.textSecondary,
                          fontSize: r.fs(16),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // Features Highlights
                AminoAnimations.slideUp(
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      _FeatureRow(
                        icon: Icons.groups_rounded,
                        color: context.nexusTheme.accentPrimary,
                        text: s.thousandsOfCommunities,
                      ),
                      SizedBox(height: r.s(16)),
                      _FeatureRow(
                        icon: Icons.chat_bubble_rounded,
                        color: context.nexusTheme.accentSecondary,
                        text: s.realTimeChat,
                      ),
                      SizedBox(height: r.s(16)),
                      _FeatureRow(
                        icon: Icons.auto_awesome_rounded,
                        color: context.nexusTheme.accentSecondary,
                        text: s.customizeProfile,
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Botões de Ação
                AminoAnimations.slideUp(
                  delay: const Duration(milliseconds: 400),
                  child: Column(
                    children: [
                      // Botão principal — Criar Conta
                      SizedBox(
                        width: double.infinity,
                        height: r.s(52),
                        child: ElevatedButton(
                          onPressed: () => context.go('/signup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE8003A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(r.s(14)),
                            ),
                            textStyle: TextStyle(
                              fontSize: r.fs(16),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Criar Conta'),
                        ),
                      ),

                      SizedBox(height: r.s(12)),

                      // Botão secundário — Login (translúcido com blur)
                      SizedBox(
                        width: double.infinity,
                        height: r.s(52),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(r.s(14)),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(r.s(14)),
                                border: Border.all(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: TextButton(
                                onPressed: () => context.go('/login'),
                                style: TextButton.styleFrom(
                                  foregroundColor: context.nexusTheme.textPrimary,
                                  textStyle: TextStyle(
                                    fontSize: r.fs(16),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: Text(s.alreadyHaveAccountShort),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: r.s(16)),

                // Termos
                AminoAnimations.fadeIn(
                  delay: const Duration(milliseconds: 600),
                  child: Text(
                    s.agreeTermsAndPrivacy,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.nexusTheme.textHint,
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
      ),
    );
  }
}

class _FeatureRow extends ConsumerWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return Row(
      children: [
        Container(
          width: r.s(40),
          height: r.s(40),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(r.s(12)),
          ),
          child: Icon(icon, color: color, size: r.s(20)),
        ),
        SizedBox(width: r.s(14)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(14),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
