import 'package:flutter/material.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// AminoDrawer — Drawer customizado com animação de sobreposição (overlay).
///
/// Versão com bloqueio de propagação:
/// Usa uma zona de borda opaca que captura o gesto horizontal ANTES dele chegar
/// no TabBarView. Isso impede que as abas troquem enquanto o drawer é puxado.
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

  // ── Drag Handlers ──────────────────────────────────────────────────────────

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final effectiveMax = _effectiveMaxSlide;
    if (effectiveMax <= 0) return;
    
    _animController.value = (_animController.value + delta / effectiveMax).clamp(0.0, 1.0);
    
    if (_animController.value > 0.01 && !_isOpen) {
      setState(() => _isOpen = true);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 300 || (_animController.value > 0.4 && velocity >= 0)) {
      open();
    } else {
      close();
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
        // 1. Conteúdo Principal
        widget.child,

        // 2. ZONA DE BORDA (72px) — Bloqueia o TabBarView
        // Usamos um GestureDetector OPACO aqui. Quando o drag começa nesta zona,
        // o GestureDetector "consome" o evento e ele não chega no TabBarView.
        if (!_isOpen)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 72.0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: const SizedBox.expand(),
            ),
          ),

        // 3. Overlay (Bloqueia toques no conteúdo quando aberto)
        AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            if (_animController.value == 0) return const SizedBox.shrink();
            return Positioned.fill(
              child: GestureDetector(
                onTap: close,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
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

        // 4. Drawer (O conteúdo deslizante)
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

        // 5. Handle Visual (Indicador de borda)
        if (!_isOpen)
          Positioned(
            left: 3,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.nexusTheme.appBarForeground.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
