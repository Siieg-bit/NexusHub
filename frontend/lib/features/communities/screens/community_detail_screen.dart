import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../feed/widgets/post_card.dart';

/// Provider para detalhes de uma comunidade.
final communityDetailProvider =
    FutureProvider.family<CommunityModel, String>((ref, id) async {
  final response = await SupabaseService.table('communities')
      .select()
      .eq('id', id)
      .single();
  return CommunityModel.fromJson(response);
});

/// Provider para feed de uma comunidade.
final communityFeedProvider =
    FutureProvider.family<List<PostModel>, String>((ref, communityId) async {
  final response = await SupabaseService.table('posts')
      .select('*, profiles!posts_author_id_fkey(*)')
      .eq('community_id', communityId)
      .eq('status', 'published')
      .order('created_at', ascending: false)
      .limit(20);

  return (response as List).map((e) {
    final map = Map<String, dynamic>.from(e);
    if (map['profiles'] != null) {
      map['author'] = map['profiles'];
    }
    return PostModel.fromJson(map);
  }).toList();
});

/// Tela de detalhes de uma comunidade com feed, wiki, chat e leaderboard.
class CommunityDetailScreen extends ConsumerStatefulWidget {
  final String communityId;

  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  ConsumerState<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final communityAsync = ref.watch(communityDetailProvider(widget.communityId));
    final feedAsync = ref.watch(communityFeedProvider(widget.communityId));

    return communityAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Erro: $error')),
      ),
      data: (community) {
        final themeColor = _parseColor(community.themeColor);

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // ============================================================
              // HEADER DA COMUNIDADE
              // ============================================================
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppTheme.scaffoldBg,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Banner
                      if (community.bannerUrl != null)
                        CachedNetworkImage(
                          imageUrl: community.bannerUrl!,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [themeColor, themeColor.withOpacity(0.3)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppTheme.scaffoldBg.withOpacity(0.8),
                              AppTheme.scaffoldBg,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.3, 0.7, 1.0],
                          ),
                        ),
                      ),
                      // Info overlay
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: [
                            // Icon
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: themeColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: themeColor, width: 2),
                              ),
                              child: community.iconUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: CachedNetworkImage(
                                        imageUrl: community.iconUrl!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(Icons.groups_rounded, color: themeColor, size: 32),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(community.name,
                                      style: Theme.of(context).textTheme.headlineSmall),
                                  if (community.tagline != null)
                                    Text(community.tagline!,
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.people_rounded, size: 14, color: themeColor),
                                      const SizedBox(width: 4),
                                      Text('${community.membersCount} membros',
                                          style: TextStyle(color: themeColor, fontSize: 12)),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.circle, size: 6, color: AppTheme.onlineColor),
                                      const SizedBox(width: 4),
                                      Text('${community.onlineMembersCount} online',
                                          style: const TextStyle(
                                              color: AppTheme.onlineColor, fontSize: 12)),
                                    ],
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
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () => _showCommunityOptions(context, community),
                  ),
                ],
              ),

              // ============================================================
              // TABS
              // ============================================================
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: themeColor,
                    labelColor: themeColor,
                    tabs: const [
                      Tab(text: 'Feed'),
                      Tab(text: 'Wiki'),
                      Tab(text: 'Chat'),
                      Tab(text: 'Ranking'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Feed
                _FeedTab(communityId: widget.communityId, feedAsync: feedAsync),

                // TAB 2: Wiki
                _WikiTab(communityId: widget.communityId),

                // TAB 3: Chat
                _ChatTab(communityId: widget.communityId),

                // TAB 4: Leaderboard
                _LeaderboardTab(communityId: widget.communityId),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.push('/community/${widget.communityId}/create-post'),
            backgroundColor: themeColor,
            child: const Icon(Icons.edit_rounded, color: Colors.white),
          ),
        );
      },
    );
  }

  void _showCommunityOptions(BuildContext context, CommunityModel community) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Sobre a comunidade'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog(context, community);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_outline_rounded),
              title: const Text('Wiki'),
              onTap: () {
                Navigator.pop(context);
                context.push('/community/${community.id}/wiki');
              },
            ),
            ListTile(
              leading: const Icon(Icons.leaderboard_rounded),
              title: const Text('Leaderboard'),
              onTap: () {
                Navigator.pop(context);
                context.push('/community/${community.id}/leaderboard');
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppTheme.errorColor),
              title: const Text('Denunciar', style: TextStyle(color: AppTheme.errorColor)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, CommunityModel community) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(community.name),
        content: SingleChildScrollView(
          child: Text(community.description ?? 'Sem descrição disponível.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB: Feed
// ============================================================================
class _FeedTab extends StatelessWidget {
  final String communityId;
  final AsyncValue<List<PostModel>> feedAsync;

  const _FeedTab({required this.communityId, required this.feedAsync});

  @override
  Widget build(BuildContext context) {
    return feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.article_outlined, size: 64, color: AppTheme.textHint),
                const SizedBox(height: 16),
                Text('Nenhum post ainda',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        )),
                const SizedBox(height: 8),
                const Text('Seja o primeiro a postar!',
                    style: TextStyle(color: AppTheme.textHint)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: posts.length,
          itemBuilder: (context, index) => PostCard(post: posts[index]),
        );
      },
    );
  }
}

// ============================================================================
// TAB: Wiki
// ============================================================================
class _WikiTab extends StatelessWidget {
  final String communityId;

  const _WikiTab({required this.communityId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_rounded, size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text('Wiki da Comunidade',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => context.push('/community/$communityId/wiki'),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Ver Wiki'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB: Chat
// ============================================================================
class _ChatTab extends StatelessWidget {
  final String communityId;

  const _ChatTab({required this.communityId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text('Chats da Comunidade',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Participe das conversas!',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB: Leaderboard
// ============================================================================
class _LeaderboardTab extends StatelessWidget {
  final String communityId;

  const _LeaderboardTab({required this.communityId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.leaderboard_rounded, size: 64, color: AppTheme.warningColor),
          const SizedBox(height: 16),
          Text('Ranking', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => context.push('/community/$communityId/leaderboard'),
            icon: const Icon(Icons.emoji_events_rounded),
            label: const Text('Ver Ranking Completo'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DELEGATE: SliverTabBar
// ============================================================================
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.scaffoldBg,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
