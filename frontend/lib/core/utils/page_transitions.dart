import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Transições de página customizadas para o NexusHub.
///
/// Uso no GoRouter:
/// ```dart
/// GoRoute(
///   path: '/example',
///   pageBuilder: (context, state) => NexusTransitions.slide(
///     state: state,
///     child: const ExampleScreen(),
///   ),
/// )
/// ```
class NexusTransitions {
  NexusTransitions._();

  /// Transição de slide da direita para a esquerda (padrão iOS).
  static CustomTransitionPage slide({
    required GoRouterState state,
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: duration,
    );
  }

  /// Transição de fade (dissolve).
  static CustomTransitionPage fade({
    required GoRouterState state,
    required Widget child,
    Duration duration = const Duration(milliseconds: 250),
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: duration,
    );
  }

  /// Transição de scale + fade (para modais e detalhes).
  static CustomTransitionPage scaleFade({
    required GoRouterState state,
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scaleTween = Tween(begin: 0.92, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        final fadeTween = Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut));
        return ScaleTransition(
          scale: animation.drive(scaleTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
      transitionDuration: duration,
    );
  }

  /// Transição de slide de baixo para cima (para bottom sheets e modais).
  static CustomTransitionPage slideUp({
    required GoRouterState state,
    required Widget child,
    Duration duration = const Duration(milliseconds: 350),
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: duration,
    );
  }

  /// Sem transição (instantâneo).
  static CustomTransitionPage none({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
      transitionDuration: Duration.zero,
    );
  }
}
