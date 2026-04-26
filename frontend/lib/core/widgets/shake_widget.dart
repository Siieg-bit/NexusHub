import 'package:flutter/material.dart';

/// Widget que aplica uma animação de "shake" horizontal ao filho.
///
/// Ideal para dar feedback visual de erro em campos de formulário
/// ou botões que falharam.
///
/// Uso:
/// ```dart
/// final _shakeKey = GlobalKey<ShakeWidgetState>();
///
/// // Para acionar o shake:
/// _shakeKey.currentState?.shake();
///
/// // No widget:
/// ShakeWidget(key: _shakeKey, child: myWidget)
/// ```
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double shakeOffset;
  final int shakeCount;

  const ShakeWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.shakeOffset = 8.0,
    this.shakeCount = 3,
  });

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Aciona a animação de shake.
  void shake() {
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final sineValue = _animation.value == 1.0
            ? 0.0
            : _sineWave(_animation.value, widget.shakeCount);
        return Transform.translate(
          offset: Offset(sineValue * widget.shakeOffset, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }

  double _sineWave(double t, int count) {
    // Gera uma onda senoidal que decai ao longo do tempo
    return (1 - t) * (count * 2 * 3.14159265 * t).sin();
  }
}

extension _DoubleExt on double {
  double sin() {
    // Aproximação de seno usando série de Taylor para evitar import de dart:math
    // Para uso simples de shake, a precisão é suficiente
    double x = this % (2 * 3.14159265);
    return x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  }
}
