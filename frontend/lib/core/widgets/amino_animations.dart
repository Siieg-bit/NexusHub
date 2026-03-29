import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// ============================================================================
/// AminoAnimations — Animações de transição fiéis ao Amino Apps original.
///
/// O Amino usa transições suaves e rápidas:
/// - Fade + SlideUp para listas e cards
/// - Scale + Fade para modais e dialogs
/// - SlideRight para navegação push
/// - Staggered para listas (cada item aparece com delay)
/// ============================================================================
class AminoAnimations {
  AminoAnimations._();

  // ══════════════════════════════════════════════════════════════════════════
  // DURAÇÕES PADRÃO
  // ══════════════════════════════════════════════════════════════════════════

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 450);
  static const Duration staggerDelay = Duration(milliseconds: 50);

  // ══════════════════════════════════════════════════════════════════════════
  // CURVAS PADRÃO
  // ══════════════════════════════════════════════════════════════════════════

  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.easeOutBack;
  static const Curve sharpCurve = Curves.easeOutQuart;

  // ══════════════════════════════════════════════════════════════════════════
  // EXTENSÕES PARA WIDGETS — Fade + Slide
  // ══════════════════════════════════════════════════════════════════════════

  /// Fade in + slide up (padrão para cards e itens de lista).
  static List<Effect<dynamic>> fadeSlideUp({
    Duration? duration,
    Duration? delay,
    double offset = 20,
  }) {
    return [
      FadeEffect(
        duration: duration ?? normal,
        delay: delay ?? Duration.zero,
        curve: defaultCurve,
      ),
      SlideEffect(
        begin: Offset(0, offset / 100),
        end: Offset.zero,
        duration: duration ?? normal,
        delay: delay ?? Duration.zero,
        curve: defaultCurve,
      ),
    ];
  }

  /// Fade in + slide down (para dropdowns e menus).
  static List<Effect<dynamic>> fadeSlideDown({
    Duration? duration,
    Duration? delay,
    double offset = 20,
  }) {
    return [
      FadeEffect(
        duration: duration ?? normal,
        delay: delay ?? Duration.zero,
        curve: defaultCurve,
      ),
      SlideEffect(
        begin: Offset(0, -offset / 100),
        end: Offset.zero,
        duration: duration ?? normal,
        delay: delay ?? Duration.zero,
        curve: defaultCurve,
      ),
    ];
  }

  /// Fade in + slide da direita (para navegação push).
  static List<Effect<dynamic>> fadeSlideRight({
    Duration? duration,
    Duration? delay,
  }) {
    return [
      FadeEffect(
        duration: duration ?? normal,
        delay: delay ?? Duration.zero,
        curve: defaultCurve,
      ),
      SlideEffect(
        begin: const Offset(0.15, 0),
        end: Offset.zero,
        duration: duration ?? normal,
        delay: delay ?? Duration.zero,
        curve: defaultCurve,
      ),
    ];
  }

  /// Fade in + slide da esquerda (para navegação pop).
  static List<Effect<dynamic>> fadeSlideLeft({
    Duration? duration,
    Duration? delay,
  }) {
    return [
      FadeEffect(
        duration: duration ?? normal,
        delay: delay ?? Duration.zero,
        curve: defaultCurve,
      ),
      SlideEffect(
        begin: const Offset(-0.15, 0),
        end: Offset.zero,
        duration: duration ?? normal,
        delay: delay ?? Duration.zero,
        curve: defaultCurve,
      ),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXTENSÕES PARA WIDGETS — Scale
  // ══════════════════════════════════════════════════════════════════════════

  /// Scale in + fade (para modais, dialogs, FABs).
  static List<Effect<dynamic>> scaleIn({
    Duration? duration,
    Duration? delay,
    double begin = 0.85,
  }) {
    return [
      FadeEffect(
        duration: duration ?? normal,
        delay: delay ?? Duration.zero,
        curve: defaultCurve,
      ),
      ScaleEffect(
        begin: Offset(begin, begin),
        end: const Offset(1, 1),
        duration: duration ?? normal,
        delay: delay ?? Duration.zero,
        curve: bounceCurve,
      ),
    ];
  }

  /// Scale out + fade (para dismiss).
  static List<Effect<dynamic>> scaleOut({
    Duration? duration,
    double end = 0.85,
  }) {
    return [
      FadeEffect(
        duration: duration ?? fast,
        begin: 1,
        end: 0,
        curve: defaultCurve,
      ),
      ScaleEffect(
        begin: const Offset(1, 1),
        end: Offset(end, end),
        duration: duration ?? fast,
        curve: defaultCurve,
      ),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXTENSÕES PARA WIDGETS — Simples
  // ══════════════════════════════════════════════════════════════════════════

  /// Fade in simples.
  static List<Effect<dynamic>> fadeIn({
    Duration? duration,
    Duration? delay,
  }) {
    return [
      FadeEffect(
        duration: duration ?? normal,
        delay: delay ?? Duration.zero,
        curve: defaultCurve,
      ),
    ];
  }

  /// Shimmer effect (para loading placeholders).
  static List<Effect<dynamic>> shimmer({
    Duration? duration,
    Duration? delay,
    Color? color,
  }) {
    return [
      ShimmerEffect(
        duration: duration ?? const Duration(milliseconds: 1500),
        delay: delay ?? Duration.zero,
        color: color ?? Colors.white24,
      ),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE TRANSITIONS — Para GoRouter
  // ══════════════════════════════════════════════════════════════════════════

  /// Transição de página com slide da direita (push padrão do Amino).
  static CustomTransitionPage<T> slideTransition<T>({
    required Widget child,
    required GoRouterState state,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: sharpCurve));

        final fadeTween = Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn));

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
    );
  }

  /// Transição de página com fade (para tabs e modais).
  static CustomTransitionPage<T> fadeTransition<T>({
    required Widget child,
    required GoRouterState state,
    Duration duration = const Duration(milliseconds: 250),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurveTween(curve: defaultCurve).animate(animation),
          child: child,
        );
      },
    );
  }

  /// Transição de página com scale + fade (para modais fullscreen).
  static CustomTransitionPage<T> scaleTransition<T>({
    required Widget child,
    required GoRouterState state,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scaleTween = Tween<double>(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: bounceCurve));
        final fadeTween = Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn));

        return ScaleTransition(
          scale: animation.drive(scaleTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
    );
  }

  /// Transição slide de baixo para cima (para bottom sheets fullscreen).
  static CustomTransitionPage<T> slideUpTransition<T>({
    required Widget child,
    required GoRouterState state,
    Duration duration = const Duration(milliseconds: 350),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: sharpCurve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EXTENSÕES PARA WIDGET — Atalhos de animação
// ══════════════════════════════════════════════════════════════════════════════

/// Extensão para facilitar o uso de animações em qualquer widget.
/// Exemplo: myWidget.aminoFadeSlideUp(delay: 100.ms)
extension AminoAnimateExtension on Widget {
  /// Fade + slide up com stagger delay baseado no index.
  Widget aminoStagger(int index, {Duration? itemDelay}) {
    final delay = (itemDelay ?? AminoAnimations.staggerDelay) * index;
    return animate()
        .fadeIn(
          duration: AminoAnimations.normal,
          delay: delay,
          curve: AminoAnimations.defaultCurve,
        )
        .slideY(
          begin: 0.15,
          end: 0,
          duration: AminoAnimations.normal,
          delay: delay,
          curve: AminoAnimations.defaultCurve,
        );
  }

  /// Fade + slide up simples.
  Widget aminoFadeSlideUp({Duration? delay}) {
    return animate()
        .fadeIn(
          duration: AminoAnimations.normal,
          delay: delay ?? Duration.zero,
          curve: AminoAnimations.defaultCurve,
        )
        .slideY(
          begin: 0.15,
          end: 0,
          duration: AminoAnimations.normal,
          delay: delay ?? Duration.zero,
          curve: AminoAnimations.defaultCurve,
        );
  }

  /// Fade in simples.
  Widget aminoFadeIn({Duration? delay, Duration? duration}) {
    return animate().fadeIn(
      duration: duration ?? AminoAnimations.normal,
      delay: delay ?? Duration.zero,
      curve: AminoAnimations.defaultCurve,
    );
  }

  /// Scale in com bounce (para modais, badges, popups).
  Widget aminoScaleIn({Duration? delay}) {
    return animate()
        .fadeIn(
          duration: AminoAnimations.normal,
          delay: delay ?? Duration.zero,
          curve: AminoAnimations.defaultCurve,
        )
        .scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1, 1),
          duration: AminoAnimations.normal,
          delay: delay ?? Duration.zero,
          curve: AminoAnimations.bounceCurve,
        );
  }

  /// Slide da direita (para itens que entram lateralmente).
  Widget aminoSlideRight({Duration? delay}) {
    return animate()
        .fadeIn(
          duration: AminoAnimations.normal,
          delay: delay ?? Duration.zero,
          curve: AminoAnimations.defaultCurve,
        )
        .slideX(
          begin: 0.15,
          end: 0,
          duration: AminoAnimations.normal,
          delay: delay ?? Duration.zero,
          curve: AminoAnimations.defaultCurve,
        );
  }

  /// Pulse suave (para indicadores de atividade, badges de notificação).
  Widget aminoPulse({Duration? duration}) {
    return animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.05, 1.05),
          duration: duration ?? const Duration(milliseconds: 1500),
          curve: Curves.easeInOut,
        );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HERO WRAPPER — Para transições hero entre telas
// ══════════════════════════════════════════════════════════════════════════════

/// Wrapper para Hero transitions com tag consistente.
class AminoHero extends StatelessWidget {
  final String tag;
  final Widget child;

  const AminoHero({
    super.key,
    required this.tag,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (
        flightContext,
        animation,
        flightDirection,
        fromHeroContext,
        toHeroContext,
      ) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Material(
              type: MaterialType.transparency,
              child: toHeroContext.widget,
            );
          },
        );
      },
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ANIMATED LIST BUILDER — Para listas com stagger animation
// ══════════════════════════════════════════════════════════════════════════════

/// ListView com animação staggered automática para cada item.
class AminoAnimatedListView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const AminoAnimatedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return itemBuilder(context, index).aminoStagger(index);
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LOADING SHIMMER — Placeholder animado para loading states
// ══════════════════════════════════════════════════════════════════════════════

/// Shimmer placeholder para loading states (estilo Amino).
class AminoShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const AminoShimmer({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 1500),
          color: isDark ? Colors.white10 : Colors.black12,
        );
  }
}

/// Shimmer de post card para loading (estilo Amino).
class AminoPostShimmer extends StatelessWidget {
  const AminoPostShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (avatar + nome)
          Row(
            children: [
              const AminoShimmer(width: 40, height: 40, borderRadius: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  AminoShimmer(width: 120, height: 14),
                  SizedBox(height: 6),
                  AminoShimmer(width: 80, height: 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Título
          const AminoShimmer(width: 200, height: 18),
          const SizedBox(height: 10),
          // Conteúdo
          const AminoShimmer(height: 14),
          const SizedBox(height: 6),
          const AminoShimmer(width: 250, height: 14),
          const SizedBox(height: 16),
          // Imagem placeholder
          const AminoShimmer(height: 180),
          const SizedBox(height: 12),
          // Actions
          Row(
            children: const [
              AminoShimmer(width: 60, height: 24, borderRadius: 12),
              SizedBox(width: 16),
              AminoShimmer(width: 60, height: 24, borderRadius: 12),
              SizedBox(width: 16),
              AminoShimmer(width: 60, height: 24, borderRadius: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// GoRouterState placeholder para imports (evita import circular).
class GoRouterState {
  final ValueKey<String> pageKey;
  GoRouterState({required this.pageKey});
}

/// CustomTransitionPage placeholder.
class CustomTransitionPage<T> extends Page<T> {
  final Widget child;
  final Duration transitionDuration;
  final Duration reverseTransitionDuration;
  final Widget Function(BuildContext, Animation<double>, Animation<double>, Widget) transitionsBuilder;

  const CustomTransitionPage({
    super.key,
    required this.child,
    required this.transitionDuration,
    required this.reverseTransitionDuration,
    required this.transitionsBuilder,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: transitionDuration,
      reverseTransitionDuration: reverseTransitionDuration,
      transitionsBuilder: transitionsBuilder,
    );
  }
}
