// =============================================================================
// ScreeningQueueSheet — Fila de vídeos da Sala de Projeção (v2)
//
// Host pode:
//   - Ver todos os vídeos na fila com thumbnail, título e plataforma
//   - Reordenar via drag-and-drop (long-press + arrastar)
//   - Remover qualquer item com swipe-to-dismiss ou botão ×
//   - "Reproduzir agora" por item (pula para aquele vídeo)
//   - Adicionar via browser de plataformas (abre ScreeningBrowserSheet)
//   - Adicionar vídeo local da galeria (abre ScreeningLocalVideoSheet)
//   - "Próximo" no header para avançar para o primeiro da fila
//
// Participantes veem a fila mas não podem editá-la.
// A fila é sincronizada via Supabase Realtime Broadcast.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_room_provider.dart';
import '../services/stream_resolver_service.dart';
import '../../../../core/services/supabase_service.dart';
import 'screening_browser_sheet.dart';
import 'screening_local_video_sheet.dart';

class ScreeningQueueSheet extends ConsumerStatefulWidget {
  final String sessionId;
  final String threadId;

  const ScreeningQueueSheet({
    super.key,
    required this.sessionId,
    required this.threadId,
  });

  @override
  ConsumerState<ScreeningQueueSheet> createState() =>
      _ScreeningQueueSheetState();
}

class _ScreeningQueueSheetState extends ConsumerState<ScreeningQueueSheet> {
  bool get _isHost {
    final roomState = ref.read(screeningRoomProvider(widget.threadId));
    return roomState.hostUserId == SupabaseService.currentUserId;
  }
  // ── Reproduzir agora (item específico) ───────────────────────────────────────
  /// Carrega o item no player sem removê-lo da fila.
  /// O item permanece na fila até ser explicitamente removido pelo host.
  Future<void> _playNow(int index) async {
    HapticFeedback.heavyImpact();
    final roomState = ref.read(screeningRoomProvider(widget.threadId));
    if (index < 0 || index >= roomState.videoQueue.length) return;
    final item = roomState.videoQueue[index];
    await ref
        .read(screeningRoomProvider(widget.threadId).notifier)
        .updateVideo(
          videoUrl: item['url'] ?? '',
          videoTitle: item['title'] ?? '',
        );
    // Não remove da fila — o item fica até ser removido manualmente
    if (mounted) Navigator.of(context).pop();
  }

  // ── Próximo (primeiro da fila) ────────────────────────────────────────────
  Future<void> _playNext() async {
    final roomState = ref.read(screeningRoomProvider(widget.threadId));
    if (roomState.videoQueue.isEmpty) return;
    await _playNow(0);
  }

  // ── Remover item ──────────────────────────────────────────────────────────
  Future<void> _removeFromQueue(int index) async {
    HapticFeedback.mediumImpact();
    await ref
        .read(screeningRoomProvider(widget.threadId).notifier)
        .removeFromQueue(index);
  }

  // ── Abrir browser para adicionar à fila ──────────────────────────────────
  Future<void> _openAddBrowser() async {
    HapticFeedback.selectionClick();
    if (!mounted) return;

    // Mostrar seletor de plataforma
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _PlatformPickerSheet(
        sessionId: widget.sessionId,
        threadId: widget.threadId,
        addToQueue: true,
      ),
    );
  }

  // ── Abrir galeria para adicionar à fila ──────────────────────────────────
  Future<void> _openAddGallery() async {
    HapticFeedback.selectionClick();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ScreeningLocalVideoSheet(
        sessionId: widget.sessionId,
        threadId: widget.threadId,
        addToQueue: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(screeningRoomProvider(widget.threadId));
    final isHost = _isHost;
    final queue = roomState.videoQueue;
    final currentVideoUrl = roomState.currentVideoUrl ?? '';
    final mq = MediaQuery.of(context);

    return Container(
      height: mq.size.height * 0.80,
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E0E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle ────────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.playlist_play_rounded,
                  color: Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Fila de Vídeos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 8),
                // Badge com contagem
                if (queue.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${queue.length}',
                      style: const TextStyle(
                        color: Color(0xFF6C5CE7),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const Spacer(),
                // Botão "Próximo" para o host
                if (isHost && queue.isNotEmpty)
                  GestureDetector(
                    onTap: _playNext,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amberAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.skip_next_rounded,
                              color: Colors.amberAccent, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Próximo',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),

          // ── Lista da fila ─────────────────────────────────────────────────
          Expanded(
            child: queue.isEmpty
                ? _buildEmptyState(isHost)
                : isHost
                    ? _buildReorderableList(queue, currentVideoUrl)
                    : _buildReadOnlyList(queue, currentVideoUrl),
          ),

          // ── Botões de adicionar (apenas host) ─────────────────────────────
          if (isHost) ...[
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, mq.padding.bottom + 16),
              child: Row(
                children: [
                  // Galeria
                  Expanded(
                    child: _AddButton(
                      icon: Icons.video_library_rounded,
                      label: 'Galeria',
                      color: const Color(0xFF6C5CE7),
                      onTap: _openAddGallery,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Plataformas online
                  Expanded(
                    flex: 2,
                    child: _AddButton(
                      icon: Icons.add_rounded,
                      label: 'Adicionar à fila',
                      color: Colors.white,
                      onTap: _openAddBrowser,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            SizedBox(height: mq.padding.bottom + 16),
        ],
      ),
    );
  }

  // ── Estado vazio ──────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isHost) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.playlist_add_rounded,
            color: Colors.white.withValues(alpha: 0.15),
            size: 56,
          ),
          const SizedBox(height: 14),
          Text(
            isHost
                ? 'A fila está vazia'
                : 'Nenhum vídeo na fila',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isHost
                ? 'Adicione vídeos para reproduzir em sequência'
                : 'O host ainda não adicionou vídeos à fila',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Lista reordenável (host) ──────────────────────────────────
  Widget _buildReorderableList(
      List<Map<String, String>> queue, String currentVideoUrl) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: queue.length,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (_, child) {
            final t = Curves.easeInOut.transform(animation.value);
            final scale = 1.0 + 0.03 * t;
            return Transform.scale(
              scale: scale,
              child: Material(
                color: Colors.transparent,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        ref
            .read(screeningRoomProvider(widget.threadId).notifier)
            .reorderQueue(oldIndex, newIndex);
        HapticFeedback.selectionClick();
      },
      itemBuilder: (context, index) {
        final item = queue[index];
        return Dismissible(
          key: ValueKey('queue_dismiss_${item['url']}_$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.delete_rounded,
                color: Colors.redAccent, size: 22),
          ),
          onDismissed: (_) => _removeFromQueue(index),
          child: _QueueItemTile(
            key: ValueKey('queue_${item['url']}_$index'),
            item: item,
            index: index,
            isHost: true,
            isCurrentlyPlaying: (item['url'] ?? '') == currentVideoUrl &&
                currentVideoUrl.isNotEmpty,
            onRemove: () => _removeFromQueue(index),
            onPlayNow: () => _playNow(index),
          ),
        );
      },
    );
  }

   // ── Lista somente leitura (participantes) ─────────────────────────────
  Widget _buildReadOnlyList(
      List<Map<String, String>> queue, String currentVideoUrl) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: queue.length,
      itemBuilder: (context, index) {
        final item = queue[index];
        return _QueueItemTile(
          key: ValueKey('queue_ro_${item['url']}_$index'),
          item: item,
          index: index,
          isHost: false,
          isCurrentlyPlaying: (item['url'] ?? '') == currentVideoUrl &&
              currentVideoUrl.isNotEmpty,
          onRemove: null,
          onPlayNow: null,
        );
      },
    );
  }
}

// =============================================================================
// _QueueItemTile — Card de item da fila
// =============================================================================
class _QueueItemTile extends StatelessWidget {
  final Map<String, String> item;
  final int index;
  final bool isHost;
  final bool isCurrentlyPlaying;
  final VoidCallback? onRemove;
  final VoidCallback? onPlayNow;

  const _QueueItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.isHost,
    this.isCurrentlyPlaying = false,
    required this.onRemove,
    required this.onPlayNow,
  });

  // ── Dados da plataforma ───────────────────────────────────────────────────
  static _PlatformInfo _getPlatformInfo(String url) {
    final u = url.toLowerCase();
    if (u.contains('youtube') || u.contains('youtu.be')) {
      return _PlatformInfo('YouTube', const Color(0xFFFF0000),
          Icons.play_circle_filled_rounded);
    }
    if (u.contains('twitch.tv')) {
      return _PlatformInfo(
          'Twitch', const Color(0xFF9146FF), Icons.live_tv_rounded);
    }
    if (u.contains('kick.com')) {
      return _PlatformInfo(
          'Kick', const Color(0xFF53FC18), Icons.sports_esports_rounded);
    }
    if (u.contains('vimeo.com')) {
      return _PlatformInfo(
          'Vimeo', const Color(0xFF1AB7EA), Icons.videocam_rounded);
    }
    if (u.contains('netflix.com')) {
      return _PlatformInfo(
          'Netflix', const Color(0xFFE50914), Icons.movie_filter_rounded);
    }
    if (u.contains('disneyplus') || u.contains('disney.com')) {
      return _PlatformInfo(
          'Disney+', const Color(0xFF0063E5), Icons.auto_awesome_rounded);
    }
    if (u.contains('primevideo') || u.contains('amazon.com/video')) {
      return _PlatformInfo(
          'Prime', const Color(0xFF00A8E1), Icons.local_play_rounded);
    }
    if (u.contains('hbomax') || u.contains('max.com')) {
      return _PlatformInfo('Max', const Color(0xFF002BE7), Icons.hd_rounded);
    }
    if (u.contains('crunchyroll')) {
      return _PlatformInfo(
          'Crunchyroll', const Color(0xFFF47521), Icons.animation_rounded);
    }
    if (u.contains('tubitv')) {
      return _PlatformInfo(
          'Tubi', const Color(0xFFFA4B00), Icons.tv_rounded);
    }
    if (u.contains('pluto.tv')) {
      return _PlatformInfo(
          'Pluto TV', const Color(0xFF00A0E3), Icons.satellite_alt_rounded);
    }
    if (u.contains('drive.google')) {
      return _PlatformInfo(
          'Drive', const Color(0xFF4285F4), Icons.folder_rounded);
    }
    if (u.contains('supabase.co/storage')) {
      return _PlatformInfo(
          'Galeria', const Color(0xFF6C5CE7), Icons.video_library_rounded);
    }
    if (u.contains('dailymotion')) {
      return _PlatformInfo(
          'Dailymotion', const Color(0xFF0066DC), Icons.movie_rounded);
    }
    return _PlatformInfo('WEB', Colors.white38, Icons.language_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final title = item['title'] ?? 'Vídeo ${index + 1}';
    final url = item['url'] ?? '';
    final thumbnail = item['thumbnail'];
    final platform = _getPlatformInfo(url);

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentlyPlaying
            ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentlyPlaying
              ? const Color(0xFF7C3AED).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
          width: isCurrentlyPlaying ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // ── Thumbnail / ícone de plataforma ──────────────────────────────
          Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: platform.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              image: thumbnail != null && thumbnail.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(thumbnail),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: thumbnail == null || thumbnail.isEmpty
                ? Icon(
                    platform.icon,
                    color: platform.color.withValues(alpha: 0.8),
                    size: 26,
                  )
                : null,
          ),

          // ── Info do vídeo ─────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Badge de plataforma
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: platform.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          platform.name,
                          style: TextStyle(
                            color: platform.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '#${index + 1}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                        ),
                      ),
                      if (isCurrentlyPlaying) ...
                        [
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              '▶ TOCANDO',
                              style: TextStyle(
                                color: Color(0xFFB57BFF),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Ações (host) ──────────────────────────────────────────────────
          if (isHost) ...[
            // Botão "Reproduzir agora"
            if (onPlayNow != null)
              GestureDetector(
                onTap: onPlayNow,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 22,
                  ),
                ),
              ),
            // Botão remover
            if (onRemove != null)
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: 18,
                  ),
                ),
              ),
            // Handle de drag
            Padding(
              padding: const EdgeInsets.only(right: 10, left: 2),
              child: Icon(
                Icons.drag_handle_rounded,
                color: Colors.white.withValues(alpha: 0.2),
                size: 20,
              ),
            ),
          ] else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _PlatformInfo {
  final String name;
  final Color color;
  final IconData icon;
  const _PlatformInfo(this.name, this.color, this.icon);
}

// =============================================================================
// _AddButton — Botão de adicionar à fila
// =============================================================================
class _AddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AddButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWhite = color == Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: isWhite
              ? Colors.white
              : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: isWhite
              ? null
              : Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isWhite ? Colors.black : color,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isWhite ? Colors.black : color,
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

// =============================================================================
// _PlatformPickerSheet — Seletor de plataforma para adicionar à fila
// Reutiliza o ScreeningBrowserSheet mas com modo addToQueue
// =============================================================================
class _PlatformPickerSheet extends ConsumerWidget {
  final String sessionId;
  final String threadId;
  final bool addToQueue;

  const _PlatformPickerSheet({
    required this.sessionId,
    required this.threadId,
    required this.addToQueue,
  });

  static const _platforms = [
    _PlatformTile('youtube', 'YouTube', Icons.play_circle_outline_rounded,
        Color(0xFFFF0000)),
    _PlatformTile(
        'twitch', 'Twitch', Icons.live_tv_rounded, Color(0xFF9146FF)),
    _PlatformTile(
        'kick', 'Kick', Icons.sports_esports_rounded, Color(0xFF53FC18)),
    _PlatformTile(
        'vimeo', 'Vimeo', Icons.videocam_rounded, Color(0xFF1AB7EA)),
    _PlatformTile('dailymotion', 'Dailymotion', Icons.movie_rounded,
        Color(0xFF0066DC)),
    _PlatformTile(
        'drive', 'Drive', Icons.folder_rounded, Color(0xFF4285F4)),
    _PlatformTile(
        'web', 'WEB', Icons.language_rounded, Color(0xFF888888)),
    _PlatformTile('youtube_live', 'YT Live', Icons.stream_rounded,
        Color(0xFFFF0000)),
    _PlatformTile('tubi', 'Tubi', Icons.tv_rounded, Color(0xFFFA4B00)),
    _PlatformTile('pluto', 'Pluto TV', Icons.satellite_alt_rounded,
        Color(0xFF00A0E3)),
    _PlatformTile('netflix', 'Netflix', Icons.movie_filter_rounded,
        Color(0xFFE50914)),
    _PlatformTile('disney', 'Disney+', Icons.auto_awesome_rounded,
        Color(0xFF0063E5)),
    _PlatformTile('amazon', 'Prime', Icons.local_play_rounded,
        Color(0xFF00A8E1)),
    _PlatformTile('hbo', 'Max', Icons.hd_rounded, Color(0xFF002BE7)),
    _PlatformTile('crunchyroll', 'Crunchyroll', Icons.animation_rounded,
        Color(0xFFF47521)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final bottomPad = mq.viewInsets.bottom + mq.padding.bottom + 16;

    return Container(
      height: mq.size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E0E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Adicionar à fila',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Escolha a plataforma e selecione o vídeo',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.0,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _platforms.length,
              itemBuilder: (context, index) {
                final p = _platforms[index];
                return GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop();
                    // Abrir como tela cheia para evitar problemas de scroll
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => ScreeningBrowserSheet(
                          platformId: p.id,
                          sessionId: sessionId,
                          threadId: threadId,
                          addToQueue: true,
                          fullscreen: true,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.09),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(p.icon,
                            color: p.color.withValues(alpha: 0.8), size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            p.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformTile {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  const _PlatformTile(this.id, this.name, this.icon, this.color);
}
