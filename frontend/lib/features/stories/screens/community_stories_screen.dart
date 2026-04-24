import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import 'story_viewer_screen.dart';
import 'create_story_screen.dart';

/// Tela de listagem de stories de uma comunidade.
/// Exibida ao clicar em "Stories" na aba lateral do drawer.
class CommunityStoriesScreen extends ConsumerStatefulWidget {
  final String communityId;
  const CommunityStoriesScreen({super.key, required this.communityId});

  @override
  ConsumerState<CommunityStoriesScreen> createState() =>
      _CommunityStoriesScreenState();
}

class _CommunityStoriesScreenState
    extends ConsumerState<CommunityStoriesScreen> {
  List<Map<String, dynamic>> _storyGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    try {
      final res = await SupabaseService.table('stories')
          .select('*, profiles!author_id(id, nickname, icon_url)')
          .eq('community_id', widget.communityId)
          .eq('is_active', true)
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      final stories = List<Map<String, dynamic>>.from(res as List? ?? []);

      // Enriquecer com dados locais de comunidade
      try {
        final authorIds = stories
            .map((s) => s['author_id'] as String?)
            .whereType<String>()
            .toSet()
            .toList();
        if (authorIds.isNotEmpty) {
          final memberships = await SupabaseService.table('community_members')
              .select('user_id, local_nickname, local_icon_url')
              .eq('community_id', widget.communityId)
              .inFilter('user_id', authorIds);
          final localMap = <String, Map<String, dynamic>>{
            for (final m in (memberships as List? ?? []))
              (m['user_id'] as String): Map<String, dynamic>.from(m as Map),
          };
          for (final story in stories) {
            final authorId = story['author_id'] as String?;
            if (authorId == null) continue;
            final membership = localMap[authorId];
            if (membership == null) continue;
            final profile = story['profiles'] as Map<String, dynamic>?;
            if (profile == null) continue;
            final merged = Map<String, dynamic>.from(profile);
            final localNickname =
                (membership['local_nickname'] as String?)?.trim();
            final localIconUrl =
                (membership['local_icon_url'] as String?)?.trim();
            if (localNickname != null && localNickname.isNotEmpty) {
              merged['nickname'] = localNickname;
            }
            if (localIconUrl != null && localIconUrl.isNotEmpty) {
              merged['icon_url'] = localIconUrl;
            }
            story['profiles'] = merged;
          }
        }
      } catch (e) {
        debugPrint('[community_stories_screen] enrich error: $e');
      }

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

      // Verificar visualizações
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId != null) {
        final viewedRes = await SupabaseService.table('story_views')
            .select('story_id')
            .eq('viewer_id', currentUserId);
        final viewedIds = (viewedRes as List? ?? [])
            .map((v) => (v['story_id'] as String?) ?? '')
            .toSet();
        for (final group in grouped.values) {
          final groupStories =
              group['stories'] as List<Map<String, dynamic>>;
          group['has_unviewed'] =
              groupStories.any((s) => !viewedIds.contains(s['id']));
        }
      }

      _storyGroups = grouped.values.toList();
      // Não vistas primeiro
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
    final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        elevation: 0,
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        title: Text(
          s.stories,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.nexusTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded,
                color: context.nexusTheme.textPrimary),
            tooltip: 'Criar story',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    CreateStoryScreen(communityId: widget.communityId),
              ));
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: context.nexusTheme.accentPrimary))
          : RefreshIndicator(
              color: context.nexusTheme.accentPrimary,
              onRefresh: () async {
                setState(() => _isLoading = true);
                await _loadStories();
              },
              child: _storyGroups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.amp_stories_rounded,
                              size: r.s(48),
                              color: context.nexusTheme.textSecondary
                                  .withValues(alpha: 0.4)),
                          SizedBox(height: r.s(12)),
                          Text(
                            'Nenhum story ativo',
                            style: TextStyle(
                                color: context.nexusTheme.textSecondary,
                                fontSize: r.fs(15)),
                          ),
                          SizedBox(height: r.s(8)),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => CreateStoryScreen(
                                    communityId: widget.communityId),
                              ));
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Criar story'),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.all(r.s(12)),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: r.s(10),
                        mainAxisSpacing: r.s(10),
                        childAspectRatio: 0.6,
                      ),
                      itemCount: _storyGroups.length,
                      itemBuilder: (ctx, i) =>
                          _buildStoryCard(ctx, _storyGroups[i]),
                    ),
            ),
    );
  }

  Widget _buildStoryCard(
      BuildContext context, Map<String, dynamic> group) {
    final r = context.r;
    final profile = group['profile'] as Map<String, dynamic>?;
    final username = profile?['nickname'] as String? ?? '?';
    final avatarUrl = profile?['icon_url'] as String?;
    final hasUnviewed = group['has_unviewed'] as bool? ?? false;
    final stories = group['stories'] as List<Map<String, dynamic>>;
    // Pegar capa do primeiro story
    final firstStory = stories.isNotEmpty ? stories.first : <String, dynamic>{};
    final coverUrl = firstStory['media_url'] as String?;
    final bgColor = firstStory['background_color'] as String? ?? '#1a1a2e';
    final storyCount = stories.length;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StoryViewerScreen(
            stories: stories,
            authorProfile: profile ?? {},
            communityId: widget.communityId,
          ),
        ));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r.s(14)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fundo
            if (coverUrl != null)
              Image.network(coverUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      color: _parseColor(bgColor)))
            else
              Container(color: _parseColor(bgColor)),
            // Gradiente
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
            // Borda de não visto
            if (hasUnviewed)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r.s(14)),
                  border: Border.all(
                    color: const Color(0xFFE91E63),
                    width: 2.5,
                  ),
                ),
              ),
            // Conteúdo
            Positioned(
              bottom: r.s(10),
              left: r.s(10),
              right: r.s(10),
              child: Row(
                children: [
                  Container(
                    width: r.s(32),
                    height: r.s(32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: hasUnviewed
                            ? const Color(0xFFE91E63)
                            : Colors.white54,
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? Text(username[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12))
                          : null,
                    ),
                  ),
                  SizedBox(width: r.s(6)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          username,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.fs(11),
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (storyCount > 1)
                          Text(
                            '$storyCount stories',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: r.fs(9),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
    } catch (_) {
      return const Color(0xFF1a1a2e);
    }
  }
}
