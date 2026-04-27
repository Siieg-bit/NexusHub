// =============================================================================
// ScreeningHistoryScreen — Histórico de Salas de Projeção
//
// Lista as sessões encerradas de um thread, mostrando:
//   - Título do vídeo assistido
//   - Número de participantes
//   - Data/hora de início e duração
//   - Botão para reutilizar o vídeo em uma nova sala
//
// Acessível pelo botão "Histórico" na tela da comunidade (live_screen).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../screens/screening_room_screen.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final screeningHistoryProvider = FutureProvider.family<
    List<ScreeningHistoryEntry>, String>((ref, communityId) async {
  // Buscar todos os threads da comunidade
  final threads = await SupabaseService.client
      .from('threads')
      .select('id')
      .eq('community_id', communityId);
  final threadIds = (threads as List).map((t) => t['id'] as String).toList();
  if (threadIds.isEmpty) return [];

  final data = await SupabaseService.client
      .from('call_sessions')
      .select(
          'id, created_at, ended_at, metadata, thread_id, call_participants(count)')
      .inFilter('thread_id', threadIds)
      .eq('session_type', 'screening')
      .eq('is_active', false)
      .order('created_at', ascending: false)
      .limit(30);

  return (data as List)
      .map((row) => ScreeningHistoryEntry.fromJson(row))
      .toList();
});

// ── Model ─────────────────────────────────────────────────────────────────────

class ScreeningHistoryEntry {
  final String sessionId;
  final String threadId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? videoUrl;
  final String? videoTitle;
  final String? videoThumbnail;
  final int participantCount;

  const ScreeningHistoryEntry({
    required this.sessionId,
    required this.threadId,
    required this.startedAt,
    this.endedAt,
    this.videoUrl,
    this.videoTitle,
    this.videoThumbnail,
    required this.participantCount,
  });

  factory ScreeningHistoryEntry.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    final participants = json['call_participants'] as List?;
    final count = participants?.isNotEmpty == true
        ? (participants!.first['count'] as int? ?? 0)
        : 0;
    return ScreeningHistoryEntry(
      sessionId: json['id'] as String,
      threadId: json['thread_id'] as String? ?? '',
      startedAt: DateTime.parse(json['created_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      videoUrl: metadata['video_url'] as String?,
      videoTitle: metadata['video_title'] as String?,
      videoThumbnail: metadata['video_thumbnail'] as String?,
      participantCount: count,
    );
  }

  Duration? get duration {
    if (endedAt == null) return null;
    return endedAt!.difference(startedAt);
  }

  String get formattedDuration {
    final d = duration;
    if (d == null) return '—';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(startedAt);
    if (diff.inDays == 0) {
      final h = startedAt.hour.toString().padLeft(2, '0');
      final m = startedAt.minute.toString().padLeft(2, '0');
      return 'Hoje às $h:$m';
    } else if (diff.inDays == 1) {
      return 'Ontem';
    } else if (diff.inDays < 7) {
      return 'Há ${diff.inDays} dias';
    } else {
      return '${startedAt.day}/${startedAt.month}/${startedAt.year}';
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ScreeningHistoryScreen extends ConsumerWidget {
  final String communityId;
  final String communityName;

  const ScreeningHistoryScreen({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(screeningHistoryProvider(communityId));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Histórico de Salas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              communityName,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: historyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: Colors.white24,
            strokeWidth: 2,
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white24, size: 48),
              const SizedBox(height: 12),
              Text(
                'Erro ao carregar histórico:\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    ref.invalidate(screeningHistoryProvider(communityId)),
                child: const Text('Tentar novamente',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
        data: (entries) => entries.isEmpty
            ? _buildEmptyState()
            : _buildList(context, entries),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.movie_filter_outlined,
              color: Colors.white12, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma sala realizada ainda.',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crie a primeira Sala de Projeção\nno chat da comunidade!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<ScreeningHistoryEntry> entries) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _HistoryCard(
          entry: entry,
          threadId: entry.threadId,
        );
      },
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final ScreeningHistoryEntry entry;
  final String threadId;

  const _HistoryCard({required this.entry, required this.threadId});

  String _getPlatformIcon(String? url) {
    if (url == null) return '🎥';
    if (url.contains('youtube') || url.contains('youtu.be')) return '▶️';
    if (url.contains('twitch')) return '🎮';
    if (url.contains('vimeo')) return '🎬';
    if (url.contains('netflix')) return '🎭';
    if (url.contains('drive.google')) return '📁';
    return '🎥';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: entry.videoUrl != null
              ? () => _reuseVideo(context)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Thumbnail / ícone
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    image: entry.videoThumbnail != null
                        ? DecorationImage(
                            image: NetworkImage(entry.videoThumbnail!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: entry.videoThumbnail == null
                      ? Center(
                          child: Text(
                            _getPlatformIcon(entry.videoUrl),
                            style: const TextStyle(fontSize: 24),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.videoTitle ?? 'Sala sem vídeo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              color: Colors.white38, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            entry.formattedDate,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.timer_outlined,
                              color: Colors.white38, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            entry.formattedDuration,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.people_outline_rounded,
                              color: Colors.white38, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.participantCount}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Botão reutilizar
                if (entry.videoUrl != null)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            color: Colors.white70, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Reutilizar',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _reuseVideo(BuildContext context) {
    // Navegar para a ScreeningRoomScreen com o vídeo pré-carregado
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScreeningRoomScreen(
          threadId: threadId,
          initialVideoUrl: entry.videoUrl,
          initialVideoTitle: entry.videoTitle,
          initialVideoThumbnail: entry.videoThumbnail,
        ),
      ),
    );
  }
}
