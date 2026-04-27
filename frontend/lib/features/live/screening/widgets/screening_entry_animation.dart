import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// =============================================================================
// ScreeningEntryAnimation — Tela de entrada imersiva da Sala de Projeção
//
// Exibida quando o status é `loading`. Substitui o CircularProgressIndicator
// genérico por uma experiência cinematográfica:
//
// 1. Fundo preto total
// 2. Ícone de projetor com shimmer animado
// 3. Texto "Entrando na sala..." com fade-in sequencial
// 4. Barra de progresso indeterminada estilizada
// 5. Fade-out suave ao completar (controlado pelo pai via `onComplete`)
// =============================================================================

class ScreeningEntryAnimation extends StatefulWidget {
  /// Chamado quando a animação de saída termina (para remover o widget da árvore)
  final VoidCallback? onComplete;

  /// Se true, inicia a animação de saída (fade-out)
  final bool isExiting;

  const ScreeningEntryAnimation({
    super.key,
    this.onComplete,
    this.isExiting = false,
  });

  @override
  State<ScreeningEntryAnimation> createState() =>
      _ScreeningEntryAnimationState();
}

class _ScreeningEntryAnimationState extends State<ScreeningEntryAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _exitController;
  late Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _exitOpacity = CurvedAnimation(
      parent: _exitController,
      curve: Curves.easeIn,
    );

    // Se o widget já nasce com isExiting=true (ex: joinRoom() completou antes
    // do primeiro build), disparar o fade-out no próximo frame.
    if (widget.isExiting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _exitController.forward().then((_) {
            widget.onComplete?.call();
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(ScreeningEntryAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Disparar fade-out quando isExiting muda de false → true
    if (widget.isExiting && !oldWidget.isExiting) {
      _exitController.forward().then((_) {
        widget.onComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_exitOpacity),
      child: Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Ícone animado ────────────────────────────────────────────
              const Icon(
                Icons.videocam_rounded,
                color: Colors.white,
                size: 52,
              )
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .scale(
                    begin: const Offset(1.0, 1.0),
                    end: const Offset(1.08, 1.08),
                    duration: 1200.ms,
                    curve: Curves.easeInOut,
                  )
                  .then()
                  .shimmer(
                    duration: 1800.ms,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),

              const SizedBox(height: 28),

              // ── Título ───────────────────────────────────────────────────
              const Text(
                'Sala de Projeção',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms)
                  .slideY(begin: 0.15, end: 0.0, duration: 400.ms, delay: 200.ms),

              const SizedBox(height: 8),

              // ── Subtítulo ────────────────────────────────────────────────
              Text(
                'Preparando a experiência...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 500.ms),

              const SizedBox(height: 36),

              // ── Barra de progresso estilizada ────────────────────────────
              SizedBox(
                width: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.7),
                    ),
                    minHeight: 2,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 700.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ScreeningLoadingOverlay — Overlay de carregamento do player (buffering)
//
// Exibido sobre o player quando `isLoading == true`.
// Mais sutil que o ScreeningEntryAnimation — apenas um spinner central
// com fundo semi-transparente para não bloquear a visão do vídeo.
// =============================================================================

class ScreeningLoadingOverlay extends StatelessWidget {
  final bool visible;
  /// Quando true (carregamento inicial da WebView), usa fundo preto sólido
  /// para ocultar badges nativos do YouTube que aparecem brevemente antes
  /// do controls=0 ser aplicado pelo IFrame API. Quando false (buffering),
  /// usa semi-transparente para não bloquear a visão do vídeo.
  final bool isInitialLoad;

  const ScreeningLoadingOverlay({
    super.key,
    required this.visible,
    this.isInitialLoad = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !visible,
        child: Container(
          color: isInitialLoad
              ? Colors.black
              : Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Spinner com anel duplo
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Anel externo lento
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          color: Colors.white.withValues(alpha: 0.2),
                          strokeWidth: 2,
                          value: 1.0,
                        ),
                      ),
                      // Anel interno rápido
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Carregando...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
