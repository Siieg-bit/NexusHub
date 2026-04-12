import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';
import '../widgets/post_card.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Provider para feed global (posts de todas as comunidades do usuário).
final globalFeedProvider = FutureProvider<List<PostModel>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  // Buscar posts das comunidades que o usuário participa
  final response = await SupabaseService.table('posts')
      .select(
          '*, profiles!posts_author_id_fkey(*), communities!posts_community_id_fkey(name, icon_url, theme_color), original_author:profiles!posts_original_author_id_fkey(id, nickname, icon_url), original_post:original_post_id(id, title, content, type, cover_image_url, media_list, created_at, author_id, community_id, original_post_id)')
      .eq('status', 'ok')
      .order('created_at', ascending: false)
      .limit(30);

  return (response as List? ?? []).map((e) {
    final map = Map<String, dynamic>.from(e);
    if (map['profiles'] != null) map['author'] = map['profiles'];
    if (map['original_post'] != null) {
      final op = Map<String, dynamic>.from(map['original_post'] as Map);
      if (op['profiles'] != null) op['author'] = op['profiles'];
      map['original_post'] = op;
    }
    return PostModel.fromJson(map);
  }).toList();
});

/// Tela de feed global com posts de todas as comunidades.
class GlobalFeedScreen extends ConsumerWidget {
  const GlobalFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final feedAsync = ref.watch(globalFeedProvider);

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      body: RefreshIndicator(
        color: context.nexusTheme.accentPrimary,
        onRefresh: () async {
          ref.invalidate(globalFeedProvider);
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: CustomScrollView(
          slivers: [
            // ================================================================
            // HEADER
            // ================================================================
            SliverAppBar(
              backgroundColor: context.nexusTheme.backgroundPrimary,
              elevation: 0,
              floating: true,
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(r.s(6)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [context.nexusTheme.accentPrimary, context.nexusTheme.accentSecondary],
                      ),
                      borderRadius: BorderRadius.circular(r.s(8)),
                      boxShadow: [
                        BoxShadow(
                          color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.hub_rounded,
                        color: Colors.white, size: r.s(20)),
                  ),
                  SizedBox(width: r.s(10)),
                  Text(
                    s.nexusHub,
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: r.fs(20),
                    ),
                  ),
                ],
              ),
              actions: [
                // Check-in
                IconButton(
                  icon: Icon(Icons.calendar_today_rounded,
                      color: context.nexusTheme.textPrimary),
                  onPressed: () => context.push('/check-in'),
                  tooltip: s.dailyCheckIn2,
                ),
                // Notificações
                IconButton(
                  icon: Badge(
                    smallSize: 8,
                    child: Icon(Icons.notifications_outlined,
                        color: context.nexusTheme.textPrimary),
                  ),
                  onPressed: () => context.push('/notifications'),
                ),
              ],
            ),

            // ================================================================
            // QUICK ACTIONS
            // ================================================================
            SliverToBoxAdapter(
              child: SizedBox(
                height: r.s(100),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(16), vertical: r.s(8)),
                  children: [
                    _QuickAction(
                      icon: Icons.add_circle_rounded,
                      label: s.createCommunityNewline,
                      color: context.nexusTheme.accentPrimary,
                      onTap: () => context.push('/create-community'),
                    ),
                    _QuickAction(
                      icon: Icons.calendar_today_rounded,
                      label: s.checkInDaily,
                      color: context.nexusTheme.warning,
                      onTap: () => context.push('/check-in'),
                    ),
                    _QuickAction(
                      icon: Icons.leaderboard_rounded,
                      label: s.globalRankingNewline,
                      color: context.nexusTheme.accentSecondary,
                      onTap: () => context.push('/leaderboard'),
                    ),
                    _QuickAction(
                      icon: Icons.quiz_rounded,
                      label: s.quizDaily,
                      color: context.nexusTheme.accentPrimary,
                      onTap: () => context.push('/quiz'),
                    ),
                    _QuickAction(
                      icon: Icons.store_rounded,
                      label: s.coinShopNewline,
                      color: context.nexusTheme.warning,
                      onTap: () => context.push('/wallet'),
                    ),
                  ],
                ),
              ),
            ),

            // ================================================================
            // FEED
            // ================================================================
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), r.s(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.feed,
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(20),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => ref.invalidate(globalFeedProvider),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(12), vertical: r.s(6)),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(r.s(20)),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Text(
                          s.refresh,
                          style: TextStyle(
                            color: context.nexusTheme.accentPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: r.fs(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            feedAsync.when(
              loading: () => SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(
                        color: context.nexusTheme.accentPrimary)),
              ),
              error: (error, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: r.s(48), color: context.nexusTheme.error),
                      SizedBox(height: r.s(16)),
                      Text(
                        'Erro ao carregar feed. Tente novamente.',
                        style: TextStyle(color: context.nexusTheme.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: r.s(16)),
                      GestureDetector(
                        onTap: () => ref.invalidate(globalFeedProvider),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(24), vertical: r.s(12)),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                context.nexusTheme.accentPrimary,
                                context.nexusTheme.accentSecondary
                              ],
                            ),
                            borderRadius: BorderRadius.circular(r.s(24)),
                            boxShadow: [
                              BoxShadow(
                                color: context.nexusTheme.accentPrimary
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child:  Text(
                            s.retry,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (posts) {
                if (posts.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.explore_rounded,
                              size: r.s(64), color: Colors.grey[600]),
                          SizedBox(height: r.s(16)),
                          Text(s.feedEmpty,
                              style: TextStyle(
                                  color: context.nexusTheme.textPrimary,
                                  fontSize: r.fs(18),
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: r.s(8)),
                          Text(
                            'Explore e entre em comunidades para ver posts aqui!',
                            style: TextStyle(color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => RepaintBoundary(
                      child: PostCard(post: posts[index]),
                    ),
                    childCount: posts.length,
                  ),
                );
              },
            ),

            SliverToBoxAdapter(child: SizedBox(height: r.s(80))),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends ConsumerWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: r.s(80),
        margin: EdgeInsets.only(right: r.s(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: r.s(50),
              height: r.s(50),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(r.s(16)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: r.s(24)),
            ),
            SizedBox(height: r.s(8)),
            Text(
              label,
              style: TextStyle(
                fontSize: r.fs(11),
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
