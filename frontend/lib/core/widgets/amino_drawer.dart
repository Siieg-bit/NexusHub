import 'package:flutter/gestures.dart';
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

  // ── Drag handlers para a zona de borda (abrir) e overlay (fechar) ──
  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    _animController.value =
        (_animController.value + delta / widget.maxSlide).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
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

    return Stack(
      children: [
        // ── Conteúdo principal (não se move) ──────────────────────────
        widget.child,

        // ── Zona de drag na borda esquerda (abre o drawer) ───────────
        // Usa _EdgeDragArea com EagerGestureRecognizer para SEMPRE
        // vencer a gesture arena contra o TabBarView interno.
        // Sem isso, o TabBarView rouba o drag horizontal e o drawer
        // trava em ~5%.
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            // Só mostrar quando o drawer está fechado
            if (_animController.value > 0.05) {
              return const SizedBox.shrink();
            }
            return child!;
          },
          child: Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 40.0,
            child: _EdgeDragArea(
              onDragUpdate: _onDragUpdate,
              onDragEnd: _onDragEnd,
            ),
          ),
        ),

        // ── Handle visual (indicador de puxão) ──────────────────────
        // Barra branca fina na borda esquerda, visível quando fechado.
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              final opacity = (1.0 - _animController.value * 20.0).clamp(0.0, 1.0);
              if (opacity == 0) return const SizedBox.shrink();
              return Positioned(
                left: 2.0,
                top: 0,
                bottom: 0,
                child: Center(
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
                ),
              );
            },
          ),
        ),

        // ── Overlay escuro sobre o conteúdo quando aberto ────────────
        // Captura taps para fechar e drag horizontal para arrastar.
        AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            if (_animController.value == 0) return const SizedBox.shrink();
            return GestureDetector(
              onTap: close,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
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

// =============================================================================
// _EdgeDragArea — Zona de borda que SEMPRE vence a gesture arena
// =============================================================================
/// Widget que usa [RawGestureDetector] com [EagerGestureRecognizer] para
/// capturar o drag horizontal imediatamente, impedindo que o [TabBarView]
/// (ou qualquer outro widget com scroll horizontal) roube o gesto.
class _EdgeDragArea extends StatelessWidget {
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  const _EdgeDragArea({
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        // O EagerGestureRecognizer aceita o gesto imediatamente na arena,
        // antes que qualquer outro recognizer (como o do TabBarView) tenha
        // chance de competir. Isso garante que o drag na borda esquerda
        // SEMPRE controla o drawer.
        _EagerHorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
                _EagerHorizontalDragGestureRecognizer>(
          () => _EagerHorizontalDragGestureRecognizer(),
          (_EagerHorizontalDragGestureRecognizer instance) {
            instance
              ..onUpdate = onDragUpdate
              ..onEnd = onDragEnd;
          },
        ),
      },
      behavior: HitTestBehavior.translucent,
      child: const SizedBox.expand(),
    );
  }
}

// =============================================================================
// _EagerHorizontalDragGestureRecognizer
// =============================================================================
/// Recognizer horizontal que aceita imediatamente na gesture arena.
/// Estende [HorizontalDragGestureRecognizer] e sobrescreve [acceptGesture]
/// para que ele sempre ganhe, mesmo contra o [TabBarView].
class _EagerHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  @override
  void resolve(GestureDisposition disposition) {
    // Sempre aceita — nunca rejeita.
    super.resolve(GestureDisposition.accepted);
  }
}
