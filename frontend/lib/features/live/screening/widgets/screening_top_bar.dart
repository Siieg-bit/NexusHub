import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_room_provider.dart';
import 'screening_add_video_sheet.dart';
import 'screening_queue_sheet.dart';
import 'screening_transfer_host_sheet.dart';

// =============================================================================
// ScreeningTopBar — Barra superior fixa da Sala de Projeção (estilo Rave)
//
// Sempre visível sobre o player (não é overlay de fade).
// Layout: X | ⚙️ | NEXUS (centralizado) | 🔍 | 👥 (+ botões host)
// =============================================================================

class ScreeningTopBar extends ConsumerWidget {
  final String sessionId;
  final String threadId;
  final VoidCallback onMinimize;

  const ScreeningTopBar({
    super.key,
    required this.sessionId,
    required this.threadId,
    required this.onMinimize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(screeningRoomProvider(threadId));
    final mq = MediaQuery.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: mq.padding.top + 4,
        left: 4,
        right: 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.75),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Botão fechar ──────────────────────────────────────────────
          _TopBarButton(
            icon: Icons.close_rounded,
            onTap: onMinimize,
          ),
          const SizedBox(width: 4),
          // ── Configurações (host) ──────────────────────────────────────
          if (roomState.isHost)
            _TopBarButton(
              icon: Icons.settings_rounded,
              onTap: () => _showSettings(context, roomState),
            ),
          if (!roomState.isHost) const SizedBox(width: 8),
          // ── Logo NEXUS centralizado ───────────────────────────────────
          Expanded(
            child: Center(
              child: Text(
                'NEXUS',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  shadows: [
                    Shadow(
                      blurRadius: 8,
                      color: Colors.black87,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Busca / Adicionar vídeo (host) ────────────────────────────
          if (roomState.isHost)
            _TopBarButton(
              icon: Icons.search_rounded,
              onTap: () => _showAddVideo(context),
            ),
          const SizedBox(width: 4),
          // ── Viewers ───────────────────────────────────────────────────
          _ViewersBadge(count: roomState.viewerCount),
          // ── Fila (host) ───────────────────────────────────────────────
          if (roomState.isHost && roomState.videoQueue.isNotEmpty) ...[
            const SizedBox(width: 4),
            _TopBarButton(
              icon: Icons.queue_music_rounded,
              badge: '${roomState.videoQueue.length}',
              onTap: () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => ScreeningQueueSheet(
                  sessionId: sessionId,
                  threadId: threadId,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddVideo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ScreeningAddVideoSheet(
        sessionId: sessionId,
        threadId: threadId,
      ),
    );
  }

  void _showSettings(BuildContext context, dynamic roomState) {
    // TODO: abrir painel de configurações da sala
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configurações em breve'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

// ── _TopBarButton ─────────────────────────────────────────────────────────────

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;

  const _TopBarButton({
    required this.icon,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
          if (badge != null)
            Positioned(
              top: 4,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.greenAccent[400],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── _ViewersBadge ─────────────────────────────────────────────────────────────

class _ViewersBadge extends StatelessWidget {
  final int count;
  const _ViewersBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
