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
  bool _isOpen = false;

  // Posição X onde o drag começou — usado para decidir se é drag de borda
  double _dragStartX = 0.0;
  // Se o drag atual foi iniciado como um drag de borda (para abrir)
  bool _isDragging = false;

  bool get isOpen => _isOpen;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void open() {
    _animController.animateTo(1.0, curve: Curves.easeOutCubic);
    if (mounted) setState(() => _isOpen = true);
  }

  void close() {
    _animController.animateTo(0.0, curve: Curves.easeInCubic);
    if (mounted) setState(() => _isOpen = false);
  }

  void toggle() {
    if (_isOpen) {
      close();
    } else {
      open();
    }
  }

  void _onDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    // Aceita drag se: drawer já aberto OU toque começou na borda esquerda (60px)
    if (_isOpen || _dragStartX < 60.0) {
      _isDragging = true;
    } else {
      _isDragging = false;
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final delta = details.primaryDelta ?? 0;
    _animController.value =
        (_animController.value + delta / widget.maxSlide).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 300) {
      open();
    } else if (velocity < -300) {
      close();
    } else if (_animController.value > 0.4) {
      open();
    } else {
      close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveMaxSlide = widget.maxSlide.clamp(0.0, screenWidth * 0.92);

    return GestureDetector(
      // Captura drag horizontal em toda a tela — a lógica de borda
      // é feita no _onDragStart pelo _dragStartX
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // ── Conteúdo principal (não se move) ──────────────────────────
          widget.child,

          // ── Overlay escuro sobre o conteúdo quando aberto ─────────────
          AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              if (_animController.value == 0) return const SizedBox.shrink();
              return GestureDetector(
                onTap: close,
                // Bloqueia taps no conteúdo quando o drawer está aberto
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black
                      .withValues(alpha: 0.55 * _animController.value),
                ),
              );
            },
          ),

          // ── Drawer (sobrepõe tudo, desliza da esquerda) ───────────────
          // Usa Transform.translate 1:1 com o valor do controller.
          // O easing é aplicado apenas via animateTo() em open()/close().
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final offset = effectiveMaxSlide * (_animController.value - 1.0);
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
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
