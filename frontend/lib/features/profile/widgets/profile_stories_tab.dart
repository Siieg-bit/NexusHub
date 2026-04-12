import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/utils/responsive.dart';
import '../providers/profile_providers.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// =============================================================================
// STORIES TAB — Stories reais do usuário (tabela stories, NÃO posts)
// =============================================================================

class ProfileStoriesTab extends ConsumerWidget {
  final String userId;
  const ProfileStoriesTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final storiesAsync = ref.watch(userStoriesProvider(userId));

    return storiesAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
            color: context.nexusTheme.accentSecondary, strokeWidth: 2),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(s.errorLoadingStories,
                style: TextStyle(color: Colors.grey[500])),
            SizedBox(height: r.s(12)),
            GestureDetector(
              onTap: () => ref.invalidate(userStoriesProvider(userId)),
              child: Icon(Icons.refresh_rounded,
                  color: Colors.grey[500], size: r.s(32)),
            ),
          ],
        ),
      ),
      data: (stories) {
        if (stories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_stories_outlined,
                    size: r.s(48), color: Colors.grey[700]),
                SizedBox(height: r.s(12)),
                Text(s.noStoriesYet,
                    style: TextStyle(
                        color: Colors.grey[500], fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.all(r.s(8)),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: r.s(4),
            mainAxisSpacing: r.s(4),
            childAspectRatio: 9 / 16,
          ),
          itemCount: stories.length,
          itemBuilder: (context, index) {
            final story = stories[index];
            final type = story['type'] as String? ?? 'image';
            final mediaUrl = story['media_url'] as String?;
            final textContent = story['text_content'] as String?;
            final bgColor = story['background_color'] as String? ?? '#000000';
            final createdAt =
                DateTime.tryParse(story['created_at']?.toString() ?? '');

            return ClipRRect(
              borderRadius: BorderRadius.circular(r.s(8)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Conteúdo visual ──
                  if (type == 'text')
                    Container(
                      color: _parseColor(bgColor),
                      alignment: Alignment.center,
                      padding: EdgeInsets.all(r.s(8)),
                      child: Text(
                        textContent ?? '',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.fs(12),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (mediaUrl != null)
                    CachedNetworkImage(
                      imageUrl: mediaUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey[900],
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.nexusTheme.accentSecondary,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[900],
                        child: Icon(Icons.broken_image,
                            color: Colors.grey[600], size: r.s(24)),
                      ),
                    )
                  else
                    Container(color: Colors.grey[900]),

                  // ── Overlay de vídeo ──
                  if (type == 'video')
                    Center(
                      child: Icon(Icons.play_circle_fill,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: r.s(32)),
                    ),

                  // ── Timestamp no canto inferior ──
                  if (createdAt != null)
                    Positioned(
                      bottom: r.s(4),
                      left: r.s(4),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(4), vertical: r.s(2)),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(r.s(4)),
                        ),
                        child: Text(
                          timeago.format(createdAt, locale: 'pt_BR'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.fs(9),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.black;
    }
  }
}
