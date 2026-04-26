// =============================================================================
// ScreeningQueueSheet — Fila de vídeos da Sala de Projeção
//
// Permite ao host:
//   - Ver os vídeos na fila
//   - Adicionar novos vídeos à fila
//   - Reordenar via drag-and-drop
//   - Remover vídeos da fila
//   - Avançar para o próximo vídeo manualmente
//
// Os participantes veem a fila mas não podem editá-la.
// A fila é sincronizada via Supabase Realtime Broadcast.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_room_provider.dart';
import '../providers/screening_player_provider.dart';
import '../models/screening_room_state.dart';
import '../../../../core/services/supabase_service.dart';

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
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  bool _isAdding = false;
  bool _showAddForm = false;

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  bool get _isHost {
    final roomState = ref.read(screeningRoomProvider(widget.threadId));
    return roomState.hostUserId == SupabaseService.currentUserId;
  }

  Future<void> _addToQueue() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      await ref.read(screeningRoomProvider(widget.threadId).notifier)
          .addToQueue(
            url: url,
            title: _titleController.text.trim().isEmpty
                ? _extractTitleFromUrl(url)
                : _titleController.text.trim(),
          );
      _urlController.clear();
      _titleController.clear();
      setState(() => _showAddForm = false);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _removeFromQueue(int index) async {
    HapticFeedback.mediumImpact();
    await ref.read(screeningRoomProvider(widget.threadId).notifier)
        .removeFromQueue(index);
  }

  Future<void> _playNext() async {
    final roomState = ref.read(screeningRoomProvider(widget.threadId));
    if (roomState.videoQueue.isEmpty) return;

    final next = roomState.videoQueue.first;
    HapticFeedback.heavyImpact();
    await ref.read(screeningRoomProvider(widget.threadId).notifier)
        .updateVideo(
          url: next['url'] ?? '',
          title: next['title'],
          thumbnail: next['thumbnail'],
        );
    await ref.read(screeningRoomProvider(widget.threadId).notifier)
        .removeFromQueue(0);
    if (mounted) Navigator.of(context).pop();
  }

  String _extractTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtube') || uri.host.contains('youtu.be')) {
        return 'Vídeo do YouTube';
      } else if (uri.host.contains('twitch')) {
        return 'Stream da Twitch';
      } else if (uri.host.contains('vimeo')) {
        return 'Vídeo do Vimeo';
      }
      return uri.host;
    } catch (_) {
      return 'Vídeo';
    }
  }

  String _getPlatformIcon(String url) {
    if (url.contains('youtube') || url.contains('youtu.be')) return '▶️';
    if (url.contains('twitch')) return '🎮';
    if (url.contains('vimeo')) return '🎬';
    if (url.contains('netflix')) return '🎭';
    if (url.contains('drive.google')) return '📁';
    return '🎥';
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(screeningRoomProvider(widget.threadId));
    final isHost = _isHost;
    final queue = roomState.videoQueue;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.queue_music_rounded,
                    color: Colors.white70, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Fila de Vídeos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${queue.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                // Botão "Próximo" para o host
                if (isHost && queue.isNotEmpty)
                  TextButton.icon(
                    onPressed: _playNext,
                    icon: const Icon(Icons.skip_next_rounded,
                        color: Colors.amberAccent, size: 18),
                    label: const Text(
                      'Próximo',
                      style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      backgroundColor: Colors.amberAccent.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // ── Lista da fila ────────────────────────────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: queue.isEmpty
                ? _buildEmptyQueue(isHost)
                : isHost
                    ? _buildReorderableQueue(queue)
                    : _buildReadOnlyQueue(queue),
          ),
          // ── Formulário de adicionar ──────────────────────────────────────────
          if (isHost) ...[
            const Divider(color: Colors.white12, height: 1),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _showAddForm
                  ? _buildAddForm()
                  : _buildAddButton(),
            ),
          ],
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildEmptyQueue(bool isHost) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.playlist_play_rounded,
              color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text(
            isHost
                ? 'Nenhum vídeo na fila.\nAdicione um para reproduzir a seguir!'
                : 'Nenhum vídeo na fila.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableQueue(List<Map<String, String>> queue) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: queue.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        ref.read(screeningRoomProvider(widget.threadId).notifier)
            .reorderQueue(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final item = queue[index];
        return _QueueItem(
          key: ValueKey('queue_$index'),
          item: item,
          index: index,
          isHost: true,
          platformIcon: _getPlatformIcon(item['url'] ?? ''),
          onRemove: () => _removeFromQueue(index),
        );
      },
    );
  }

  Widget _buildReadOnlyQueue(List<Map<String, String>> queue) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: queue.length,
      itemBuilder: (context, index) {
        final item = queue[index];
        return _QueueItem(
          key: ValueKey('queue_$index'),
          item: item,
          index: index,
          isHost: false,
          platformIcon: _getPlatformIcon(item['url'] ?? ''),
          onRemove: null,
        );
      },
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _showAddForm = true),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Adicionar à fila'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adicionar à fila',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          // Campo URL
          TextField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'URL do vídeo (YouTube, Twitch, etc.)',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              filled: true,
              fillColor: Colors.white.withOpacity(0.07),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon:
                  const Icon(Icons.link_rounded, color: Colors.white38, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          // Campo título (opcional)
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Título (opcional)',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              filled: true,
              fillColor: Colors.white.withOpacity(0.07),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon:
                  const Icon(Icons.title_rounded, color: Colors.white38, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _urlController.clear();
                    _titleController.clear();
                    setState(() => _showAddForm = false);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white38,
                    side: const BorderSide(color: Colors.white12),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isAdding ? null : _addToQueue,
                  icon: _isAdding
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.add_rounded, size: 18),
                  label: Text(_isAdding ? 'Adicionando...' : 'Adicionar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Item da fila
// =============================================================================
class _QueueItem extends StatelessWidget {
  final Map<String, String> item;
  final int index;
  final bool isHost;
  final String platformIcon;
  final VoidCallback? onRemove;

  const _QueueItem({
    super.key,
    required this.item,
    required this.index,
    required this.isHost,
    required this.platformIcon,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final title = item['title'] ?? 'Vídeo ${index + 1}';
    final url = item['url'] ?? '';
    final thumbnail = item['thumbnail'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          // Número / thumbnail
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              image: thumbnail != null
                  ? DecorationImage(
                      image: NetworkImage(thumbnail),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: thumbnail == null
                ? Center(
                    child: Text(
                      platformIcon,
                      style: const TextStyle(fontSize: 18),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Título e URL
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  url,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Posição na fila
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '#${index + 1}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Botão remover (apenas host)
          if (isHost && onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
              ),
            ),
          ],
          // Handle de drag (apenas host)
          if (isHost)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(
                Icons.drag_handle_rounded,
                color: Colors.white24,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}
