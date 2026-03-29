import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';
import '../widgets/post_card.dart';
import '../../../core/utils/responsive.dart';

/// Provider para feed global (posts de todas as comunidades do usuário).
final globalFeedProvider = FutureProvider<List<PostModel>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  // Buscar posts das comunidades que o usuário participa
  final response = await SupabaseService.table('posts')
      .select(
          '*, profiles!posts_author_id_fkey(*), communities!posts_community_id_fkey(name, icon_url, theme_color)')
      .eq('status', 'ok')
      .order('created_at', ascending: false)
      .limit(30);

  return (response as List).map((e) {
    final map = Map<String, dynamic>.from(e);
    if (map['profiles'] != null) map['author'] = map['profiles'];
    return PostModel.fromJson(map);
  }).toList();
});

/// Tela de feed global com posts de todas as comunidades.
class GlobalFeedScreen extends ConsumerWidget {
  const GlobalFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final r = context.r;
    final feedAsync = ref.watch(globalFeedProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
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
            backgroundColor: context.scaffoldBg,
            elevation: 0,
            floating: true,
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(r.s(6)),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.accentColor],
                    ),
                    borderRadius: BorderRadius.circular(r.s(8)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
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
                  'NexusHub',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: r.fs(20),
                  ),
                ),
              ],
            ),
            actions: [
              // Check-in
              IconButton(
                icon: Icon(Icons.calendar_today_rounded, color: context.textPrimary),
                onPressed: () => context.push('/check-in'),
                tooltip: 'Check-in Diário',
              ),
              // Notificações
              IconButton(
                icon: Badge(
                  smallSize: 8,
                  child: Icon(Icons.notifications_outlined, color: context.textPrimary),
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
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
                children: [
                  _QuickAction(
                    icon: Icons.add_circle_rounded,
                    label: 'Criar\nComunidade',
                    color: AppTheme.primaryColor,
                    onTap: () => context.push('/create-community'),
                  ),
                  _QuickAction(
                    icon: Icons.calendar_today_rounded,
                    label: 'Check-in\nDiário',
                    color: AppTheme.warningColor,
                    onTap: () => context.push('/check-in'),
                  ),
                  _QuickAction(
                    icon: Icons.leaderboard_rounded,
                    label: 'Ranking\nGlobal',
                    color: AppTheme.accentColor,
                    onTap: () => context.push('/leaderboard'),
                  ),
                  _QuickAction(
                    icon: Icons.quiz_rounded,
                    label: 'Quiz\nDiário',
                    color: AppTheme.primaryColor,
                    onTap: () => context.push('/quiz'),
                  ),
                  _QuickAction(
                    icon: Icons.store_rounded,
                    label: 'Loja de\nCoins',
                    color: AppTheme.warningColor,
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
                    'Feed',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: r.fs(20),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref.invalidate(globalFeedProvider),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(r.s(20)),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Text(
                        'Atualizar',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
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
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: r.s(48), color: AppTheme.errorColor),
                    SizedBox(height: r.s(16)),
                    Text(
                      'Erro ao carregar feed: $error',
                      style: TextStyle(color: context.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: r.s(16)),
                    GestureDetector(
                      onTap: () => ref.invalidate(globalFeedProvider),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: r.s(24), vertical: r.s(12)),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryColor, AppTheme.accentColor],
                          ),
                          borderRadius: BorderRadius.circular(r.s(24)),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Tentar novamente',
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
                        Text('Seu feed está vazio',
                            style: TextStyle(
                                color: context.textPrimary,
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
                  (context, index) => PostCard(post: posts[index]),
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

class _QuickAction extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
