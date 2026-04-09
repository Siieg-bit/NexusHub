import 'package:flutter/material.dart';

/// AminoDrawer — Drawer customizado com animação de sobreposição (overlay).
///
/// O drawer desliza da esquerda e sobrepõe o conteúdo principal sem
/// empurrá-lo ou redimensioná-lo. Um overlay escuro semitransparente
/// cobre o conteúdo ao fundo quando o drawer está aberto.
///
/// Comportamento:
///   - Puxar da borda esquerda (50px) para a direita → abre automaticamente
///   - Tocar no overlay escuro → fecha
///   - Arrastar o overlay para a esquerda → fecha
///   - Botão de menu (toggle) → abre/fecha
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
      duration: const Duration(milliseconds: 300),
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

  // ── Drag no overlay (para fechar quando aberto) ────────────────────
  void _onOverlayDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    _animController.value =
        (_animController.value + delta / widget.maxSlide).clamp(0.0, 1.0);
  }

  void _onOverlayDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -200 || _animController.value < 0.5) {
      close();
    } else {
      open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveMaxSlide = widget.maxSlide.clamp(0.0, screenWidth * 0.92);

    return Stack(
      children: [
        // ── Conteúdo principal (não se move) ──────────────────────────
        widget.child,

        // ── Zona de borda esquerda (50px) — abre o drawer ────────────
        // Ao detectar qualquer arrasto para a direita, chama open()
        // imediatamente. Não tenta seguir o dedo pixel a pixel.
        // Isso evita toda a competição de gestos com o TabBarView.
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 50.0,
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              // Esconde a zona quando o drawer já está abrindo/aberto
              if (_animController.value > 0.01) {
                return const SizedBox.shrink();
              }
              return child!;
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                // Qualquer movimento para a direita (delta > 2) dispara open()
                final delta = details.primaryDelta ?? 0;
                if (delta > 2) {
                  open();
                }
              },
              child: const SizedBox.expand(),
            ),
          ),
        ),

        // ── Handle visual (indicador de puxão) ──────────────────────
        // Barra branca fina na borda esquerda, visível quando fechado.
        Positioned(
          left: 2.0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                final opacity =
                    (1.0 - _animController.value * 20.0).clamp(0.0, 1.0);
                if (opacity == 0) return const SizedBox.shrink();
                return Center(
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 5.0,
                      height: 48.0,
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
                );
              },
            ),
          ),
        ),

        // ── Overlay escuro sobre o conteúdo quando aberto ────────────
        // Toque fecha. Arrastar para esquerda fecha com drag.
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

        // ── Drawer (sobrepõe tudo, desliza da esquerda) ──────────────
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
