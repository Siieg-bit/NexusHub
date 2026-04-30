import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_room_provider.dart';
import '../models/screening_participant.dart';
import 'screening_add_video_sheet.dart';
import 'screening_queue_sheet.dart';

// =============================================================================
// ScreeningTopBar — Barra superior fixa da Sala de Projeção (estilo Rave)
//
// Sempre visível sobre o player (não é overlay de fade).
// Layout: X | ⚙️ | NEXUS (centralizado) | 🔍 | 👥 | 📋
//
// Otimização de performance: em vez de ref.watch(screeningRoomProvider)
// completo (que reconstruía o TopBar a cada mudança de estado da sala —
// participantes, posição, queue, etc.), usamos .select() para cada campo
// específico. O TopBar só é reconstruído quando isHost, viewerCount ou
// videoQueue.length realmente mudam.
// =============================================================================

class ScreeningTopBar extends ConsumerWidget {
  final String sessionId;
  final String threadId;
  final VoidCallback onMinimize;
  /// Quando não nulo, sobrescreve o padding top calculado via mq.padding.top.
  /// Use 0 quando o TopBar está fora do player (já posicionado abaixo da status bar).
  /// Use null (padrão) quando o TopBar está sobreposto ao player (usa mq.padding.top).
  final double? overrideTopPadding;

  const ScreeningTopBar({
    super.key,
    required this.sessionId,
    required this.threadId,
    required this.onMinimize,
    this.overrideTopPadding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Otimização: .select() garante rebuild apenas quando o campo específico muda.
    // Antes: ref.watch(screeningRoomProvider(threadId)) → rebuild em qualquer
    // mudança de estado (participantes, posição, status, currentVideoUrl, etc.).
    final isHost = ref.watch(
      screeningRoomProvider(threadId).select((s) => s.isHost),
    );
    final viewerCount = ref.watch(
      screeningRoomProvider(threadId).select((s) => s.viewerCount),
    );
    final queueLength = ref.watch(
      screeningRoomProvider(threadId).select((s) => s.videoQueue.length),
    );
    final hasQueue = queueLength > 0;

    final mq = MediaQuery.of(context);
    // Se overrideTopPadding for fornecido, usa ele; caso contrário usa mq.padding.top
    final topPad = overrideTopPadding ?? mq.padding.top;

    return Container(
      padding: EdgeInsets.only(
        top: topPad + 4,
        left: 4,
        right: 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.90),
            Colors.black.withValues(alpha: 0.60),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Botão fechar / minimizar ──────────────────────────────────
          _TopBarButton(
            icon: Icons.close_rounded,
            onTap: onMinimize,
          ),
          const SizedBox(width: 4),
          // ── Configurações (host) ──────────────────────────────────────
          if (isHost)
            _TopBarButton(
              icon: Icons.settings_rounded,
              onTap: () => _showSettings(context),
            ),
          if (!isHost) const SizedBox(width: 8),
          // ── Logo NEXUS centralizado ───────────────────────────────────
          Expanded(
            child: Center(
              child: const Text(
                'NEXUS',
                style: TextStyle(
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
          if (isHost)
            _TopBarButton(
              icon: Icons.search_rounded,
              onTap: () => _showAddVideo(context),
            ),
          const SizedBox(width: 4),
          // ── Viewers ───────────────────────────────────────────────────
          _ViewersBadge(
            count: viewerCount,
            onTap: () => _showMembersPanel(context),
          ),
          // ── Fila (host) ───────────────────────────────────────────────
          if (isHost) ...[
            const SizedBox(width: 4),
            _TopBarButton(
              icon: Icons.playlist_play_rounded,
              badge: hasQueue ? '$queueLength' : null,
              onTap: () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                useSafeArea: true,
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

  void _showMembersPanel(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, _) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: Align(
            alignment: Alignment.centerRight,
            child: _MembersPanelSheet(threadId: threadId),
          ),
        );
      },
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

  void _showSettings(BuildContext context) {
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
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: Colors.white,
              size: 26,
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
  final VoidCallback? onTap;
  const _ViewersBadge({required this.count, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _MembersPanelSheet ────────────────────────────────────────────────────────
// Painel lateral transparente com lista de participantes da sala de projeção.
// Abre via showGeneralDialog com slide da direita para a esquerda.
// =============================================================================
class _MembersPanelSheet extends ConsumerWidget {
  final String threadId;
  const _MembersPanelSheet({required this.threadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participants = ref.watch(
      screeningRoomProvider(threadId).select((s) => s.participants),
    );
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = (screenWidth * 0.72).clamp(200.0, 260.0);
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Container(
          width: panelWidth,
          height: double.infinity,
          margin: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.people_rounded, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Participantes (${participants.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              decoration: TextDecoration.none,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                  // Lista de participantes
                  Expanded(
                    child: participants.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhum participante',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: participants.length,
                            itemBuilder: (context, index) {
                              final p = participants[index];
                              return _MemberTile(participant: p);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── _MemberTile ───────────────────────────────────────────────────────────────
class _MemberTile extends StatelessWidget {
  final ScreeningParticipant participant;
  const _MemberTile({required this.participant});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            backgroundImage: participant.avatarUrl != null
                ? NetworkImage(participant.avatarUrl!)
                : null,
            child: participant.avatarUrl == null
                ? Text(
                    participant.username.isNotEmpty
                        ? participant.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          // Nome
          Expanded(
            child: Text(
              participant.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Badge host
          if (participant.isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: const Text(
                'HOST',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
