import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../screens/story_viewer_screen.dart';
import '../screens/create_story_screen.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Story Carousel — Carrossel horizontal de stories no topo do feed.
///
/// No Amino original, stories aparecem como círculos de avatar
/// com borda gradiente no topo do feed da comunidade.
/// Stories não visualizadas têm borda colorida; já vistas, borda cinza.
class StoryCarousel extends ConsumerStatefulWidget {
  final String communityId;
  const StoryCarousel({super.key, required this.communityId});

  @override
  ConsumerState<StoryCarousel> createState() => _StoryCarouselState();
}

class _StoryCarouselState extends ConsumerState<StoryCarousel> {
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
          .select('*, profiles!author_id(id, nickname, icon_url)')
          .eq('community_id', widget.communityId)
          .eq('is_active', true)
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      final stories = List<Map<String, dynamic>>.from(res as List? ?? []);

      // Agrupar por autor
      final Map<String, Map<String, dynamic>> grouped = {};
      for (final story in stories) {
        final authorId = (story['author_id'] as String?) ?? '';
        if (!grouped.containsKey(authorId)) {
          grouped[authorId] = {
            'author_id': authorId,
            'profile': story['profiles'],
            'stories': <Map<String, dynamic>>[],
            'has_unviewed': false,
          };
        }
        (grouped[authorId]?['stories'] as List?)?.add(story);
      }

      // Verificar quais foram visualizadas pelo usuário atual
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId != null) {
        final viewedRes = await SupabaseService.table('story_views')
            .select('story_id')
            .eq('viewer_id', currentUserId);
        final viewedIds = (viewedRes as List? ?? [])
            .map((v) => (v['story_id'] as String?) ?? '')
            .toSet();

        for (final group in grouped.values) {
          final groupStories = group['stories'] as List<Map<String, dynamic>>;
          group['has_unviewed'] =
              groupStories.any((s) => !viewedIds.contains(s['id']));
        }
      }

      _storyGroups = grouped.values.toList();

      // Colocar stories não vistas primeiro
      _storyGroups.sort((a, b) {
        final aUnseen = a['has_unviewed'] as bool? ?? false;
        final bUnseen = b['has_unviewed'] as bool? ?? false;
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
    final r = context.r;
    return SizedBox(
      height: r.s(100),
      child: _isLoading
          ? Center(
              child: SizedBox(
                width: r.s(20),
                height: r.s(20),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: context.nexusTheme.accentSecondary),
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
              itemCount: _storyGroups.length + 1, // +1 para o botão s.create
              itemBuilder: (ctx, i) {
                if (i == 0) return _buildCreateButton(ctx);
                return _buildStoryAvatar(ctx, _storyGroups[i - 1]);
              },
            ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    final s = ref.read(stringsProvider);
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(right: r.s(12)),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CreateStoryScreen(communityId: widget.communityId),
          ));
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: r.s(60),
                  height: r.s(60),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.nexusTheme.surfacePrimary,
                    border: Border.all(
                      color: context.nexusTheme.accentSecondary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(Icons.add_rounded,
                      color: context.nexusTheme.accentSecondary, size: r.s(28)),
                ),
              ],
            ),
            SizedBox(height: r.s(4)),
            Text(
              s.yourStory,
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(10),
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

  Widget _buildStoryAvatar(BuildContext context, Map<String, dynamic> group) {
    final r = context.r;
    final profile = group['profile'] as Map<String, dynamic>?;
    final username = profile?['nickname'] as String? ?? '?';
    final avatarUrl = profile?['icon_url'] as String?;
    final hasUnviewed = group['has_unviewed'] as bool? ?? false;
    final stories = group['stories'] as List<Map<String, dynamic>>;

    return Padding(
      padding: EdgeInsets.only(right: r.s(12)),
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
              width: r.s(64),
              height: r.s(64),
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
                    : Border.all(
                        color: Colors.grey[700] ?? Colors.grey, width: 2),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.nexusTheme.backgroundPrimary, width: 2),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: context.nexusTheme.surfacePrimary,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          username[0].toUpperCase(),
                          style: TextStyle(
                            color: context.nexusTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            SizedBox(height: r.s(4)),
            SizedBox(
              width: r.s(64),
              child: Text(
                username,
                style: TextStyle(
                  color: hasUnviewed ? context.nexusTheme.textPrimary : Colors.grey[600],
                  fontSize: r.fs(10),
                  fontWeight: hasUnviewed ? FontWeight.w700 : FontWeight.w500,
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
