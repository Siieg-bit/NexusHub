import 'package:flutter/material.dart';

/// AminoDrawer — Drawer customizado com animação push/scale estilo Amino.
///
/// No Amino original, abrir a sidebar não apenas sobrepõe o conteúdo:
/// ela empurra e escala o conteúdo principal para a direita, criando
/// um efeito 3D de profundidade. O conteúdo principal fica com cantos
/// arredondados e levemente reduzido (scale ~0.85).
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
  final double minScale;
  final double cornerRadius;

  const AminoDrawerController({
    super.key,
    required this.drawer,
    required this.child,
    this.maxSlide = 280,
    this.minScale = 0.82,
    this.cornerRadius = 24,
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final slide = widget.maxSlide * _animController.value;
        final scale = 1 - ((1 - widget.minScale) * _animController.value);
        final radius = widget.cornerRadius * _animController.value;

        return Stack(
          children: [
            // ── Drawer (fundo) ──
            // Animação: começa deslocado à esquerda e desliza para a posição
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: widget.maxSlide,
              child: FadeTransition(
                opacity: _animController,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-0.3, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animController,
                    curve: Curves.easeOutCubic,
                  )),
                  child: widget.drawer,
                ),
              ),
            ),

            // ── Conteúdo principal (frente) ──
            // Animação: escala + desloca para a direita + cantos arredondados
            Transform(
              transform: Matrix4.identity()
                ..setTranslationRaw(slide, 0, 0)
                ..scale(scale, scale, 1.0),
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: _isOpen ? close : null,
                onHorizontalDragUpdate: (details) {
                  final delta = details.primaryDelta ?? 0;
                  _animController.value += delta / widget.maxSlide;
                },
                onHorizontalDragEnd: (details) {
                  if (_animController.value > 0.5) {
                    open();
                  } else {
                    close();
                  }
                },
                child: AbsorbPointer(
                  absorbing: _isOpen,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: _isOpen
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(-5, 0),
                                ),
                              ]
                            : null,
                      ),
                      child: Overlay(
                        initialEntries: [
                          OverlayEntry(
                            builder: (_) => widget.child,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Overlay escuro sobre o conteúdo quando aberto ──
            if (_isOpen)
              Positioned(
                left: slide,
                top: 0,
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: close,
                  child: Container(
                    color: Colors.black
                        .withValues(alpha: 0.15 * _animController.value),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
