import 'package:flutter/material.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// AminoDrawer — Drawer customizado com animação de sobreposição (overlay).
///
/// O drawer desliza da esquerda e sobrepõe o conteúdo principal sem
/// empurrá-lo ou redimensioná-lo. Um overlay escuro semitransparente
/// cobre o conteúdo ao fundo quando o drawer está aberto.
///
/// Comportamento melhorado:
///   - Puxar da borda esquerda (72px) → segue o dedo em tempo real
///   - Arrastar de qualquer ponto quando aberto → fecha seguindo o dedo
///   - Velocidade de fling detectada → abre/fecha com snap
///   - Toque no overlay → fecha com animação
///   - Botão de menu (toggle) → abre/fecha
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

  // Rastreia se estamos em modo de drag (para não competir com TabBarView)
  bool _isDragging = false;
  double _dragStartX = 0;

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

  void toggle() {
    if (_isOpen) {
      close();
    } else {
      open();
    }
  }

  // ── Drag na zona de borda (para abrir) ────────────────────────────────────
  void _onEdgeDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragStartX = details.globalPosition.dx;
  }

  void _onEdgeDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final delta = details.primaryDelta ?? 0;
    final effectiveMax = _effectiveMaxSlide;
    if (effectiveMax <= 0) return;
    _animController.value =
        (_animController.value + delta / effectiveMax).clamp(0.0, 1.0);
    if (_animController.value > 0.01 && !_isOpen) {
      setState(() => _isOpen = true);
    }
  }

  void _onEdgeDragEnd(DragEndDetails details) {
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0;
    // Fling para direita → abre; fling para esquerda → fecha
    if (velocity > 300 || (_animController.value > 0.4 && velocity >= 0)) {
      open();
    } else {
      close();
    }
  }

  // ── Drag no overlay (para fechar quando aberto) ────────────────────────────
  void _onOverlayDragStart(DragStartDetails details) {
    _isDragging = true;
  }

  void _onOverlayDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final delta = details.primaryDelta ?? 0;
    final effectiveMax = _effectiveMaxSlide;
    if (effectiveMax <= 0) return;
    _animController.value =
        (_animController.value + delta / effectiveMax).clamp(0.0, 1.0);
  }

  void _onOverlayDragEnd(DragEndDetails details) {
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300 || _animController.value < 0.5) {
      close();
    } else {
      open();
    }
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

    return Stack(
      children: [
        // ── Conteúdo principal (não se move) ──────────────────────────────────
        widget.child,

        // ── Zona de borda esquerda (72px) — segue o dedo para abrir ──────────
        // Só ativa quando o drawer está fechado (< 1% aberto)
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            if (_animController.value > 0.02) return const SizedBox.shrink();
            return child!;
          },
          child: Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 72.0, // área maior para facilitar o gesto
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _onEdgeDragStart,
              onHorizontalDragUpdate: _onEdgeDragUpdate,
              onHorizontalDragEnd: _onEdgeDragEnd,
              child: const SizedBox.expand(),
            ),
          ),
        ),

        // ── Handle visual (indicador de puxão) ────────────────────────────────
        // Barra fina na borda esquerda, visível quando fechado.
        Positioned(
          left: 3.0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                final opacity =
                    (1.0 - _animController.value * 15.0).clamp(0.0, 1.0);
                if (opacity == 0) return const SizedBox.shrink();
                final handleColor = context.nexusTheme.appBarForeground;
                return Center(
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 4.0,
                      height: 52.0,
                      decoration: BoxDecoration(
                        color: handleColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3.0),
                        boxShadow: [
                          BoxShadow(
                            color: context.nexusTheme.overlayColor
                                .withValues(alpha: 0.25),
                            blurRadius: 6.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // ── Overlay sobre o conteúdo quando aberto ────────────────────────────
        // Toque fecha. Arrastar para esquerda fecha com drag contínuo.
        AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            if (_animController.value == 0) return const SizedBox.shrink();
            final overlayBase = context.nexusTheme.overlayColor;
            return GestureDetector(
              onTap: close,
              onHorizontalDragStart: _onOverlayDragStart,
              onHorizontalDragUpdate: _onOverlayDragUpdate,
              onHorizontalDragEnd: _onOverlayDragEnd,
              child: Container(
                color: overlayBase.withValues(
                    alpha: context.nexusTheme.overlayOpacity *
                        _animController.value),
              ),
            );
          },
        ),

        // ── Drawer (sobrepõe tudo, desliza da esquerda) ───────────────────────
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
