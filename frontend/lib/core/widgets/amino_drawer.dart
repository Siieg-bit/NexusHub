import 'package:flutter/material.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// AminoDrawer — Drawer customizado com animação de sobreposição (overlay).
///
/// Abordagem de robustez máxima:
/// Usa um [Listener] de baixo nível para detectar o início do toque na borda (72px).
/// Se o toque começar na borda, o drawer "sequestra" o gesto antes que ele chegue
/// ao TabBarView, garantindo fluidez total.
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
  
  // Controle de drag manual via PointerEvents
  bool _isDragging = false;
  double _lastPointerX = 0;
  bool _dragStartedInEdge = false;

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
    _animController.animateTo(1.0,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    if (mounted) setState(() => _isOpen = true);
  }

  void close() {
    _animController.animateTo(0.0,
        duration: const Duration(milliseconds: 240), curve: Curves.easeInCubic);
    if (mounted) setState(() => _isOpen = false);
  }

  void toggle() => _isOpen ? close() : open();

  // ── Gerenciamento de Ponteiro de Baixo Nível ───────────────────────────────
  
  void _handlePointerDown(PointerDownEvent event) {
    _lastPointerX = event.position.dx;
    // Se estiver fechado, verifica se começou na borda (72px)
    if (!_isOpen) {
      _dragStartedInEdge = event.position.dx < 72.0;
    } else {
      // Se estiver aberto, qualquer toque no overlay ou drawer pode iniciar o drag
      _dragStartedInEdge = true; 
    }
    _isDragging = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final deltaX = event.position.dx - _lastPointerX;
    _lastPointerX = event.position.dx;

    // Se começou na borda e o movimento é horizontal significativo
    if (!_isDragging && _dragStartedInEdge && deltaX.abs() > 2) {
      _isDragging = true;
    }

    if (_isDragging) {
      final effectiveMax = _effectiveMaxSlide;
      if (effectiveMax > 0) {
        _animController.value = (_animController.value + deltaX / effectiveMax).clamp(0.0, 1.0);
        if (_animController.value > 0.01 && !_isOpen) {
          setState(() => _isOpen = true);
        }
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_isDragging) {
      // Se soltar com velocidade ou mais da metade aberto, abre.
      // Como não temos VelocityTracker fácil aqui, usamos posição.
      if (_animController.value > 0.4) {
        open();
      } else {
        close();
      }
    }
    _isDragging = false;
    _dragStartedInEdge = false;
  }

  double get _effectiveMaxSlide {
    if (!mounted) return widget.maxSlide;
    final screenWidth = MediaQuery.of(context).size.width;
    return widget.maxSlide.clamp(0.0, screenWidth * 0.92);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveMaxSlide = widget.maxSlide.clamp(0.0, screenWidth * 0.92);

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // Conteúdo Principal
          widget.child,

          // Overlay (Bloqueia toques no conteúdo quando aberto)
          AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              if (_animController.value == 0) return const SizedBox.shrink();
              return Positioned.fill(
                child: GestureDetector(
                  onTap: close,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: context.nexusTheme.overlayColor.withValues(
                      alpha: context.nexusTheme.overlayOpacity * _animController.value,
                    ),
                  ),
                ),
              );
            },
          ),

          // Drawer
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
                  elevation: 16,
                  type: MaterialType.transparency,
                  child: widget.drawer,
                ),
              ),
            ),
          ),
          
          // Handle Visual (Opcional, mas ajuda a UI)
          if (!_isOpen)
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
