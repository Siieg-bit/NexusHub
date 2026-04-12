import 'package:flutter/material.dart';

/// Utilitários de animação no estilo Amino Apps.
/// Baseado nas keyframes do web-preview (index.css).
class AminoAnimations {
  AminoAnimations._();

  // ============================================================================
  // DURAÇÕES PADRÃO
  // ============================================================================

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration celebrate = Duration(milliseconds: 500);

  // ============================================================================
  // CURVAS PADRÃO
  // ============================================================================

  static const Curve easeOut = Curves.easeOut;
  static const Curve spring = Curves.elasticOut;
  static const Curve bounceOut = Curves.bounceOut;
  static const Curve decelerate = Curves.decelerate;

  /// Curva customizada para drawer slide (cubic-bezier(0.16, 1, 0.3, 1))
  static const Curve drawerCurve = Cubic(0.16, 1, 0.3, 1);

  // ============================================================================
  // FADE IN (amino-fade-in)
  // ============================================================================

  static Widget fadeIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Duration delay = Duration.zero,
  }) {
    return _AnimatedEntry(
      duration: duration,
      delay: delay,
      builder: (animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  // ============================================================================
  // SLIDE UP (amino-slide-up)
  // ============================================================================

  static Widget slideUp({
    required Widget child,
    Duration duration = const Duration(milliseconds: 350),
    Duration delay = Duration.zero,
    double offset = 20.0,
  }) {
    return _AnimatedEntry(
      duration: duration,
      delay: delay,
      builder: (animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, offset / 100),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    );
  }

  // ============================================================================
  // SLIDE LEFT (amino-slide-left — screen enter)
  // ============================================================================

  static Widget slideLeft({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Duration delay = Duration.zero,
  }) {
    return _AnimatedEntry(
      duration: duration,
      delay: delay,
      builder: (animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.3, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: drawerCurve)),
          child: child,
        ),
      ),
    );
  }

  // ============================================================================
  // SCALE IN (amino-scale-in)
  // ============================================================================

  static Widget scaleIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Duration delay = Duration.zero,
  }) {
    return _AnimatedEntry(
      duration: duration,
      delay: delay,
      builder: (animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: child,
        ),
      ),
    );
  }

  // ============================================================================
  // SCALE BOUNCE (amino-scale-bounce)
  // ============================================================================

  static Widget scaleBounce({
    required Widget child,
    Duration duration = const Duration(milliseconds: 400),
    Duration delay = Duration.zero,
  }) {
    return _AnimatedEntry(
      duration: duration,
      delay: delay,
      builder: (animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.elasticOut),
          ),
          child: child,
        ),
      ),
    );
  }

  // ============================================================================
  // STAGGER (amino-stagger-in) — para listas
  // ============================================================================

  static Widget staggerItem({
    required Widget child,
    required int index,
    Duration baseDelay = const Duration(milliseconds: 50),
  }) {
    return slideUp(
      child: child,
      duration: const Duration(milliseconds: 300),
      delay: Duration(milliseconds: baseDelay.inMilliseconds * index),
      offset: 12.0,
    );
  }

  // ============================================================================
  // PULSE GLOW (amino-pulse-glow) — para botões de check-in
  // ============================================================================

  static Widget pulseGlow({
    required Widget child,
    Color glowColor = const Color(0xFF2DBE60),
  }) {
    return _PulseGlowWidget(glowColor: glowColor, child: child);
  }

  // ============================================================================
  // CHECK CELEBRATE (amino-check-celebrate)
  // ============================================================================

  static Widget checkCelebrate({
    required Widget child,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    return _CelebrateWidget(duration: duration, child: child);
  }

  // ============================================================================
  // CARD PRESS EFFECT (card-press)
  // ============================================================================

  static Widget cardPress({required Widget child, VoidCallback? onTap}) {
    return _CardPressWidget(onTap: onTap, child: child);
  }

  // ============================================================================
  // PAGE ROUTE TRANSITION (screen-enter / screen-exit)
  // ============================================================================

  static Route<T> slideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: drawerCurve,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      transitionDuration: normal,
    );
  }
}

// ==============================================================================
// WIDGETS INTERNOS DE ANIMAÇÃO
// ==============================================================================

class _AnimatedEntry extends StatefulWidget {
  final Duration duration;
  final Duration delay;
  final Widget Function(Animation<double> animation) builder;

  const _AnimatedEntry({
    required this.duration,
    required this.delay,
    required this.builder,
  });

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}

/// Widget com efeito de pulso brilhante (amino-pulse-glow)
class _PulseGlowWidget extends StatefulWidget {
  final Color glowColor;
  final Widget child;

  const _PulseGlowWidget({required this.glowColor, required this.child});

  @override
  State<_PulseGlowWidget> createState() => _PulseGlowWidgetState();
}

class _PulseGlowWidgetState extends State<_PulseGlowWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color:
                  widget.glowColor.withValues(alpha: 0.4 * _controller.value),
              blurRadius: 8 * _controller.value,
              spreadRadius: 0,
            ),
          ],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Widget com efeito de celebração (amino-check-celebrate)
class _CelebrateWidget extends StatefulWidget {
  final Duration duration;
  final Widget child;

  const _CelebrateWidget({required this.duration, required this.child});

  @override
  State<_CelebrateWidget> createState() => _CelebrateWidgetState();
}

class _CelebrateWidgetState extends State<_CelebrateWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scaleAnimation, child: widget.child);
  }
}

/// Widget com efeito de press (card-press)
class _CardPressWidget extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _CardPressWidget({this.onTap, required this.child});

  @override
  State<_CardPressWidget> createState() => _CardPressWidgetState();
}

class _CardPressWidgetState extends State<_CardPressWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Usa onTap (não onTapUp) para que filhos com GestureDetector
      // possam absorver o toque sem acionar a navegação do card pai.
      // O efeito visual de press é mantido via onTapDown/onTapCancel.
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTap: () => widget.onTap?.call(),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        transform: Matrix4.diagonal3Values(
            _isPressed ? 0.97 : 1.0, _isPressed ? 0.97 : 1.0, 1.0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isPressed ? 0.85 : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}
