import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/haptic_service.dart';

// ============================================================================
// MiniRoomOverlay — Overlay flutuante para salas ativas inspirado no OluOlu
//
// O OluOlu exibe um "pip" (picture-in-picture) flutuante quando o usuário
// sai de uma sala de voz ativa sem encerrá-la. O pip permite:
// - Ver o título e contagem de participantes
// - Voltar para a sala com um toque
// - Mutar/desmutar sem abrir a sala
// - Encerrar a sessão
//
// Implementação:
// - Usa Overlay do Flutter para renderizar acima de toda a navegação
// - Posição arrastável (DragTarget/Draggable)
// - Estado gerenciado via Riverpod
//
// Uso:
//   // Mostrar o mini room
//   MiniRoomOverlay.show(
//     context,
//     roomId: 'uuid',
//     title: 'Free Talk',
//     type: MiniRoomType.freeTalk,
//     onReturnWithContext: (ctx) => Navigator.of(ctx).push(...),
//     onEnd: () => leaveRoom(),
//   );
//
//   // Esconder o mini room
//   MiniRoomOverlay.hide(context);
// ============================================================================

// ─── Tipo de sala ─────────────────────────────────────────────────────────────
enum MiniRoomType {
  freeTalk,    // Sala de voz estilo palco
  voiceChat,   // Voice chat P2P/grupo
  screening,   // Sala de projeção
}

// ─── Estado do mini room ──────────────────────────────────────────────────────
class MiniRoomState {
  final String roomId;
  final String title;
  final MiniRoomType type;
  final bool isMuted;
  final int participantCount;
  final bool isVisible;
  final String? thumbnailUrl;
  final String? videoUrl;
  /// Callback legado (sem context). Mantido por compatibilidade com voice/freeTalk.
  final VoidCallback? onReturn;
  /// Callback com context do PiP — preferir este para navegação segura.
  /// Recebe o BuildContext do _MiniRoomPip (sempre válido), evitando o erro
  /// "Cannot use ref after widget was disposed" que ocorre quando o callback
  /// captura ref/context de um widget já descartado.
  final void Function(BuildContext context)? onReturnWithContext;
  final VoidCallback? onEnd;
  final VoidCallback? onToggleMute;

  const MiniRoomState({
    required this.roomId,
    required this.title,
    required this.type,
    this.isMuted = false,
    this.participantCount = 0,
    this.isVisible = true,
    this.thumbnailUrl,
    this.videoUrl,
    this.onReturn,
    this.onReturnWithContext,
    this.onEnd,
    this.onToggleMute,
  });

  MiniRoomState copyWith({
    bool? isMuted,
    int? participantCount,
    bool? isVisible,
  }) {
    return MiniRoomState(
      roomId: roomId,
      title: title,
      type: type,
      isMuted: isMuted ?? this.isMuted,
      participantCount: participantCount ?? this.participantCount,
      isVisible: isVisible ?? this.isVisible,
      thumbnailUrl: thumbnailUrl,
      videoUrl: videoUrl,
      onReturn: onReturn,
      onReturnWithContext: onReturnWithContext,
      onEnd: onEnd,
      onToggleMute: onToggleMute,
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
class MiniRoomNotifier extends StateNotifier<MiniRoomState?> {
  MiniRoomNotifier() : super(null);

  void show({
    required String roomId,
    required String title,
    required MiniRoomType type,
    bool isMuted = false,
    int participantCount = 0,
    String? thumbnailUrl,
    String? videoUrl,
    VoidCallback? onReturn,
    void Function(BuildContext context)? onReturnWithContext,
    VoidCallback? onEnd,
    VoidCallback? onToggleMute,
  }) {
    state = MiniRoomState(
      roomId: roomId,
      title: title,
      type: type,
      isMuted: isMuted,
      participantCount: participantCount,
      isVisible: true,
      thumbnailUrl: thumbnailUrl,
      videoUrl: videoUrl,
      onReturn: onReturn,
      onReturnWithContext: onReturnWithContext,
      onEnd: onEnd,
      onToggleMute: onToggleMute,
    );
  }

  void hide() => state = null;

  void updateMute(bool muted) {
    if (state == null) return;
    state = state!.copyWith(isMuted: muted);
  }

  void updateParticipantCount(int count) {
    if (state == null) return;
    state = state!.copyWith(participantCount: count);
  }
}

final miniRoomProvider =
    StateNotifierProvider<MiniRoomNotifier, MiniRoomState?>(
  (ref) => MiniRoomNotifier(),
);

// ─── Widget principal ─────────────────────────────────────────────────────────
/// Wrapper que deve envolver o MaterialApp ou o widget raiz para exibir o overlay.
class MiniRoomOverlayWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const MiniRoomOverlayWrapper({super.key, required this.child});

  @override
  ConsumerState<MiniRoomOverlayWrapper> createState() =>
      _MiniRoomOverlayWrapperState();
}

class _MiniRoomOverlayWrapperState
    extends ConsumerState<MiniRoomOverlayWrapper> {
  @override
  Widget build(BuildContext context) {
    final miniRoom = ref.watch(miniRoomProvider);

    return Stack(
      children: [
        widget.child,
        if (miniRoom != null && miniRoom.isVisible)
          Positioned(
            bottom: 90, // Acima da bottom nav bar
            right: 16,
            child: _MiniRoomPip(state: miniRoom),
          ),
      ],
    );
  }
}

// ─── PiP flutuante ────────────────────────────────────────────────────────────
class _MiniRoomPip extends ConsumerStatefulWidget {
  final MiniRoomState state;

  const _MiniRoomPip({required this.state});

  @override
  ConsumerState<_MiniRoomPip> createState() => _MiniRoomPipState();
}

class _MiniRoomPipState extends ConsumerState<_MiniRoomPip>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Offset _offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;

    return Transform.translate(
      offset: _offset,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset += details.delta;
          });
        },
        onTap: () {
          HapticService.buttonPress();
          // Preferir onReturnWithContext (passa o context do PiP, sempre válido).
          // Fallback para onReturn legado (voice/freeTalk).
          if (s.onReturnWithContext != null) {
            s.onReturnWithContext!(context);
          } else {
            s.onReturn?.call();
          }
        },
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _typeColor(s.type),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _typeColor(s.type).withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Linha superior: ícone + título + fechar
                Row(
                  children: [
                    Icon(
                      _typeIcon(s.type),
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticService.buttonPress();
                        if (s.type == MiniRoomType.screening && s.onEnd != null) {
                          s.onEnd?.call();
                        } else {
                          ref.read(miniRoomProvider.notifier).hide();
                        }
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ),
                  ],
                ),
                if (s.type == MiniRoomType.screening) ...[
                  const SizedBox(height: 8),
                  _buildScreeningPreview(s),
                ],
                const SizedBox(height: 6),
                // Linha inferior: participantes + controles
                Row(
                  children: [
                    // Indicador ao vivo
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      s.participantCount > 0
                          ? '${s.participantCount} participantes'
                          : 'Ao vivo',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    // Botão mute (apenas para voice/freeTalk)
                    if (s.type != MiniRoomType.screening &&
                        s.onToggleMute != null)
                      GestureDetector(
                        onTap: () {
                          HapticService.tap();
                          s.onToggleMute?.call();
                        },
                        child: Icon(
                          s.isMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          color: s.isMuted
                              ? Colors.red[200]
                              : Colors.white,
                          size: 16,
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Botão encerrar
                    GestureDetector(
                      onTap: () {
                        HapticService.action();
                        s.onEnd?.call();
                        ref.read(miniRoomProvider.notifier).hide();
                      },
                      child: const Icon(
                        Icons.call_end_rounded,
                        color: Colors.red,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildScreeningPreview(MiniRoomState state) {
    final thumbnailUrl = state.thumbnailUrl?.trim();
    final hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasThumbnail)
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _buildScreeningPreviewFallback(),
              )
            else
              _buildScreeningPreviewFallback(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreeningPreviewFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B1B2F), Color(0xFF0F3460)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.live_tv_rounded, color: Colors.white70, size: 30),
      ),
    );
  }

  Color _typeColor(MiniRoomType type) {
    switch (type) {
      case MiniRoomType.freeTalk:
        return const Color(0xFF7C4DFF);
      case MiniRoomType.voiceChat:
        return const Color(0xFF4CAF50);
      case MiniRoomType.screening:
        return const Color(0xFFE91E63);
    }
  }

  IconData _typeIcon(MiniRoomType type) {
    switch (type) {
      case MiniRoomType.freeTalk:
        return Icons.record_voice_over_rounded;
      case MiniRoomType.voiceChat:
        return Icons.headset_mic_rounded;
      case MiniRoomType.screening:
        return Icons.live_tv_rounded;
    }
  }
}
