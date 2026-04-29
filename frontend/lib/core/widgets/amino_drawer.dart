import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// AminoDrawer — Drawer customizado com animação de sobreposição (overlay).
///
/// Comportamento:
///   - Puxar da borda esquerda (72px) → segue o dedo em tempo real
///   - Usa [EagerGestureRecognizer] para vencer a arena de gestos contra o
///     TabBarView — resolve o conflito de swipe na área das abas.
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
    // nada extra necessário
  }

  void _onEdgeDragUpdate(DragUpdateDetails details) {
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
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 300 || (_animController.value > 0.4 && velocity >= 0)) {
      open();
    } else {
      close();
    }
  }

  // ── Drag no overlay (para fechar quando aberto) ────────────────────────────
  void _onOverlayDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final effectiveMax = _effectiveMaxSlide;
    if (effectiveMax <= 0) return;
    _animController.value =
        (_animController.value + delta / effectiveMax).clamp(0.0, 1.0);
  }

  void _onOverlayDragEnd(DragEndDetails details) {
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

        // ── Zona de borda esquerda (72px) — usa RawGestureDetector com
        //    HorizontalDragGestureRecognizer eager para vencer a arena de
        //    gestos do TabBarView e do PageView. ────────────────────────────
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            // Quando o drawer já está aberto, a zona de borda não precisa
            // competir — o overlay cuida do fechamento.
            if (_animController.value > 0.05) return const SizedBox.shrink();
            return child!;
          },
          child: Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 72.0,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                _EagerHorizontalDragRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        _EagerHorizontalDragRecognizer>(
                  () => _EagerHorizontalDragRecognizer(),
                  (instance) {
                    instance
                      ..onStart = _onEdgeDragStart
                      ..onUpdate = _onEdgeDragUpdate
                      ..onEnd = _onEdgeDragEnd;
                  },
                ),
              },
            ),
          ),
        ),

        // ── Handle visual (indicador de puxão) ────────────────────────────────
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
        AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            if (_animController.value == 0) return const SizedBox.shrink();
            final overlayBase = context.nexusTheme.overlayColor;
            return GestureDetector(
              onTap: close,
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

/// Reconhecedor de drag horizontal que se declara vencedor imediatamente
/// na arena de gestos — resolve o conflito com TabBarView/PageView.
class _EagerHorizontalDragRecognizer extends HorizontalDragGestureRecognizer {
  _EagerHorizontalDragRecognizer() : super();

  @override
  void rejectGesture(int pointer) {
    // Aceita o gesto mesmo quando rejeitado pela arena, garantindo que
    // o drawer sempre receba os eventos quando o toque começa na borda.
    acceptGesture(pointer);
  }
}
