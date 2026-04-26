import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_room_provider.dart';
import '../providers/screening_player_provider.dart';
import '../providers/screening_sync_provider.dart';
import '../models/sync_event.dart';
import 'screening_add_video_sheet.dart';

// =============================================================================
// ScreeningVideoEndedOverlay — Overlay exibido quando o vídeo termina
//
// Exibido como camada sobre o player quando `playerState.hasEnded == true`.
// Mostra:
// - Ícone de replay animado
// - Mensagem de "Vídeo encerrado"
// - Botão de replay (apenas host) — reinicia do início
// - Botão de novo vídeo (apenas host) — abre ScreeningAddVideoSheet
// - Contagem de participantes ainda na sala
// =============================================================================

class ScreeningVideoEndedOverlay extends ConsumerWidget {
  final String sessionId;
  final String threadId;

  const ScreeningVideoEndedOverlay({
    super.key,
    required this.sessionId,
    required this.threadId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(screeningPlayerProvider(sessionId));
    final roomState = ref.watch(screeningRoomProvider(threadId));

    if (!playerState.hasEnded) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: playerState.hasEnded ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        color: Colors.black.withOpacity(0.82),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Ícone de replay ──────────────────────────────────────────
              Icon(
                Icons.replay_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 64,
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .rotate(
                    begin: -0.1,
                    end: 0.0,
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  ),

              const SizedBox(height: 20),

              // ── Título ───────────────────────────────────────────────────
              const Text(
                'Vídeo encerrado',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms)
                  .slideY(begin: 0.1, end: 0.0, duration: 400.ms, delay: 200.ms),

              const SizedBox(height: 8),

              // ── Participantes ainda na sala ───────────────────────────────
              Text(
                '${roomState.participants.length} ${roomState.participants.length == 1 ? 'pessoa' : 'pessoas'} na sala',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 350.ms),

              if (roomState.isHost) ...[
                const SizedBox(height: 32),

                // ── Botões do host ─────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Replay
                    _EndedButton(
                      icon: Icons.replay_rounded,
                      label: 'Repetir',
                      onTap: () {
                        ref
                            .read(screeningPlayerProvider(sessionId).notifier)
                            .seek(Duration.zero);
                        ref
                            .read(screeningPlayerProvider(sessionId).notifier)
                            .play();
                        ref
                            .read(screeningSyncProvider(sessionId).notifier)
                            .broadcastEvent(SyncEvent(
                              type: SyncEventType.seek,
                              positionMs: 0,
                              serverTimestampMs:
                                  DateTime.now().millisecondsSinceEpoch,
                            ));
                        ref
                            .read(screeningSyncProvider(sessionId).notifier)
                            .broadcastEvent(SyncEvent(
                              type: SyncEventType.play,
                              positionMs: 0,
                              serverTimestampMs:
                                  DateTime.now().millisecondsSinceEpoch,
                            ));
                      },
                    ),

                    const SizedBox(width: 16),

                    // Novo vídeo
                    _EndedButton(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Novo vídeo',
                      isPrimary: true,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => ScreeningAddVideoSheet(
                            sessionId: sessionId,
                            threadId: threadId,
                          ),
                        );
                      },
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 500.ms)
                    .slideY(begin: 0.1, end: 0.0, duration: 400.ms, delay: 500.ms),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Botão de ação no estado de vídeo encerrado ────────────────────────────────

class _EndedButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _EndedButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary
              ? Colors.white
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(24),
          border: isPrimary
              ? null
              : Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.black : Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.black : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
