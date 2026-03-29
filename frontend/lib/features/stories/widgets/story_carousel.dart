import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../screens/story_viewer_screen.dart';
import '../screens/create_story_screen.dart';

/// Story Carousel — Carrossel horizontal de stories no topo do feed.
///
/// No Amino original, stories aparecem como círculos de avatar
/// com borda gradiente no topo do feed da comunidade.
/// Stories não visualizadas têm borda colorida; já vistas, borda cinza.
class StoryCarousel extends StatefulWidget {
  final String communityId;
  const StoryCarousel({super.key, required this.communityId});

  @override
  State<StoryCarousel> createState() => _StoryCarouselState();
}

class _StoryCarouselState extends State<StoryCarousel> {
  List<Map<String, dynamic>> _storyGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    try {
      // Buscar stories ativas e não expiradas, agrupadas por autor
      final res = await SupabaseService.table('stories')
          .select('*, profiles!author_id(id, username, avatar_url)')
          .eq('community_id', widget.communityId)
          .eq('is_active', true)
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      final stories = List<Map<String, dynamic>>.from(res as List);

      // Agrupar por autor
      final Map<String, Map<String, dynamic>> grouped = {};
      for (final story in stories) {
        final authorId = story['author_id'] as String;
        if (!grouped.containsKey(authorId)) {
          grouped[authorId] = {
            'author_id': authorId,
            'profile': story['profiles'],
            'stories': <Map<String, dynamic>>[],
            'has_unviewed': false,
          };
        }
        (grouped[authorId]!['stories'] as List).add(story);
      }

      // Verificar quais foram visualizadas pelo usuário atual
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId != null) {
        final viewedRes = await SupabaseService.table('story_views')
            .select('story_id')
            .eq('viewer_id', currentUserId);
        final viewedIds = (viewedRes as List)
            .map((v) => v['story_id'] as String)
            .toSet();

        for (final group in grouped.values) {
          final groupStories =
              group['stories'] as List<Map<String, dynamic>>;
          group['has_unviewed'] =
              groupStories.any((s) => !viewedIds.contains(s['id']));
        }
      }

      _storyGroups = grouped.values.toList();

      // Colocar stories não vistas primeiro
      _storyGroups.sort((a, b) {
        final aUnseen = a['has_unviewed'] as bool;
        final bUnseen = b['has_unviewed'] as bool;
        if (aUnseen && !bUnseen) return -1;
        if (!aUnseen && bUnseen) return 1;
        return 0;
      });

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: _isLoading
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accentColor),
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _storyGroups.length + 1, // +1 para o botão "Criar"
              itemBuilder: (ctx, i) {
                if (i == 0) return _buildCreateButton(ctx);
                return _buildStoryAvatar(ctx, _storyGroups[i - 1]);
              },
            ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                CreateStoryScreen(communityId: widget.communityId),
          ));
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.cardBg,
                    border: Border.all(
                      color: AppTheme.accentColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: AppTheme.accentColor, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Seu Story',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryAvatar(
      BuildContext context, Map<String, dynamic> group) {
    final profile = group['profile'] as Map<String, dynamic>?;
    final username = profile?['username'] as String? ?? '?';
    final avatarUrl = profile?['avatar_url'] as String?;
    final hasUnviewed = group['has_unviewed'] as bool? ?? false;
    final stories =
        group['stories'] as List<Map<String, dynamic>>;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => StoryViewerScreen(
              stories: stories,
              authorProfile: profile ?? {},
            ),
          ));
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasUnviewed
                    ? const LinearGradient(
                        colors: [
                          Color(0xFFE91E63),
                          Color(0xFFFF5722),
                          Color(0xFFFF9800),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: hasUnviewed
                    ? null
                    : Border.all(color: Colors.grey[700]!, width: 2),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.scaffoldBg, width: 2),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: context.cardBg,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          username[0].toUpperCase(),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 64,
              child: Text(
                username,
                style: TextStyle(
                  color: hasUnviewed
                      ? context.textPrimary
                      : Colors.grey[600],
                  fontSize: 10,
                  fontWeight:
                      hasUnviewed ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
