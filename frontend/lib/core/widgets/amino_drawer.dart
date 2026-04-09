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
    setState(() => _isOpen = true);
  }

  void close() {
    _animController.animateTo(0.0, curve: Curves.easeInCubic);
    setState(() => _isOpen = false);
  }

  void toggle() {
    if (_isOpen) {
      close();
    } else {
      open();
    }
  }

  // ── Drag handlers para quando o drawer já está aberto ──────────────
  void _onOverlayDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    // Atualiza diretamente sem curva — o drag deve ser 1:1 com o dedo
    _animController.value =
        (_animController.value + delta / widget.maxSlide).clamp(0.0, 1.0);
  }

  void _onOverlayDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300) {
      close();
    } else if (_animController.value > 0.5) {
      open();
    } else {
      close();
    }
  }

  // ── Drag handlers para a zona de borda esquerda (abrir drawer) ─────
  void _onEdgeDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    // Atualiza diretamente sem curva — o drag deve ser 1:1 com o dedo
    _animController.value =
        (_animController.value + delta / widget.maxSlide).clamp(0.0, 1.0);
  }

  void _onEdgeDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 300) {
      open();
    } else if (_animController.value > 0.5) {
      open();
    } else {
      close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveMaxSlide = widget.maxSlide.clamp(0.0, screenWidth * 0.92);

    return Stack(
      children: [
        // ── Conteúdo principal (não se move) ──────────────────────────────────
        widget.child,

        // ── Zona de drag exclusiva na borda esquerda ─────────────────────
        // Largura de 28px, fica por CIMA do child (tabs), então captura
        // o drag horizontal antes das tabs. Só funciona quando fechado.
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            // Só mostrar a zona de drag quando o drawer está fechado
            if (_animController.value > 0.05) {
              return const SizedBox.shrink();
            }
            return child!;
          },
          child: Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 28.0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: _onEdgeDragUpdate,
              onHorizontalDragEnd: _onEdgeDragEnd,
              child: Center(
                child: Container(
                  width: 5.0,
                  height: 48.0,
                  margin: const EdgeInsets.only(left: 2.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4.0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Overlay escuro sobre o conteúdo quando aberto ─────────────────
        // Também captura drag horizontal para fechar o drawer.
        AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            if (_animController.value == 0) return const SizedBox.shrink();
            return GestureDetector(
              onTap: close,
              onHorizontalDragUpdate: _onOverlayDragUpdate,
              onHorizontalDragEnd: _onOverlayDragEnd,
              child: Container(
                color: Colors.black
                    .withValues(alpha: 0.55 * _animController.value),
              ),
            );
          },
        ),

        // ── Drawer (sobrepõe tudo, desliza da esquerda) ───────────────────
        // Usa AnimatedBuilder com translate manual (sem CurvedAnimation)
        // para que a posição visual seja sempre 1:1 com _animController.value
        // durante o drag. O easing é aplicado apenas nas chamadas open()/close().
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
    );
  }
}
