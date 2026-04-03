import 'package:flutter/material.dart';

/// AminoDrawer — Drawer customizado com animação de sobreposição (overlay).
///
/// O drawer desliza da esquerda e sobrepõe o conteúdo principal sem
/// empurrá-lo ou redimensioná-lo. Um overlay escuro semitransparente
/// cobre o conteúdo ao fundo quando o drawer está aberto.
///
/// Uso:
/// ```dart
/// AminoDrawerController(
///   drawer: CommunityDrawer(...),
///   child: Scaffold(...),
/// )
/// ```
class AminoDrawerController extends StatefulWidget {
  final Widget drawer;
  final Widget child;
  final double maxSlide;

  const AminoDrawerController({
    super.key,
    required this.drawer,
    required this.child,
    this.maxSlide = 300,
  });

  /// Abre/fecha o drawer a partir de qualquer descendente
  static AminoDrawerControllerState? of(BuildContext context) {
    return context.findAncestorStateOfType<AminoDrawerControllerState>();
  }

  @override
  State<AminoDrawerController> createState() => AminoDrawerControllerState();
}

class AminoDrawerControllerState extends State<AminoDrawerController>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  bool _isOpen = false;

  /// Largura da zona de borda esquerda que detecta swipe para abrir (px).
  static const double _edgeDragWidth = 24.0;
  bool _edgeDragActive = false;

  bool get isOpen => _isOpen;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void open() {
    _animController.forward();
    setState(() => _isOpen = true);
  }

  void close() {
    _animController.reverse();
    setState(() => _isOpen = false);
  }

  void toggle() {
    if (_isOpen) {
      close();
    } else {
      open();
    }
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _edgeDragActive = !_isOpen && details.globalPosition.dx <= _edgeDragWidth;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    if (_isOpen || _edgeDragActive) {
      _animController.value += delta / widget.maxSlide;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isOpen || _edgeDragActive) {
      final velocity = details.primaryVelocity ?? 0;
      if (velocity > 300) {
        open();
      } else if (velocity < -300) {
        close();
      } else if (_animController.value > 0.5) {
        open();
      } else {
        close();
      }
    }
    _edgeDragActive = false;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveMaxSlide = widget.maxSlide.clamp(0.0, screenWidth * 0.92);

    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        children: [
          // ── Conteúdo principal (não se move) ──────────────────────────────
          widget.child,

          // ── Overlay escuro sobre o conteúdo quando aberto ─────────────────
          AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              if (_animController.value == 0) return const SizedBox.shrink();
              return GestureDetector(
                onTap: close,
                child: Container(
                  color: Colors.black
                      .withValues(alpha: 0.45 * _animController.value),
                ),
              );
            },
          ),

          // ── Drawer (sobrepõe tudo, desliza da esquerda) ───────────────────
          // O Material garante que o drawer herde corretamente o Theme,
          // DefaultTextStyle e tipografia do app — sem isso os textos
          // ficam com fonte monospace e sublinhado amarelo (estilo raw Flutter).
          SlideTransition(
            position: _slideAnimation,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: effectiveMaxSlide,
                child: Material(
                  type: MaterialType.transparency,
                  child: widget.drawer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
