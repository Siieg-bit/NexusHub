import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';
import '../widgets/post_card.dart';

/// Provider para feed global (posts de todas as comunidades do usuário).
final globalFeedProvider = FutureProvider<List<PostModel>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  // Buscar posts das comunidades que o usuário participa
  final response = await SupabaseService.table('posts')
      .select(
          '*, profiles!posts_author_id_fkey(*), communities!posts_community_id_fkey(name, icon_url, theme_color)')
      .eq('status', 'published')
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
    final feedAsync = ref.watch(globalFeedProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // ================================================================
          // HEADER
          // ================================================================
          SliverAppBar(
            backgroundColor: AppTheme.scaffoldBg,
            elevation: 0,
            floating: true,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.accentColor],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.hub_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'NexusHub',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            actions: [
              // Check-in
              IconButton(
                icon: const Icon(Icons.calendar_today_rounded, color: AppTheme.textPrimary),
                onPressed: () => context.push('/check-in'),
                tooltip: 'Check-in Diário',
              ),
              // Notificações
              IconButton(
                icon: const Badge(
                  smallSize: 8,
                  child: Icon(Icons.notifications_outlined, color: AppTheme.textPrimary),
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
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    onTap: () {},
                  ),
                  _QuickAction(
                    icon: Icons.quiz_rounded,
                    label: 'Quiz\nDiário',
                    color: AppTheme.primaryColor,
                    onTap: () {},
                  ),
                  _QuickAction(
                    icon: Icons.store_rounded,
                    label: 'Loja de\nCoins',
                    color: AppTheme.warningColor,
                    onTap: () {},
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Feed',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref.invalidate(globalFeedProvider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: const Text(
                        'Atualizar',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
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
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 16),
                    Text(
                      'Erro ao carregar feed: $error',
                      style: const TextStyle(color: AppTheme.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => ref.invalidate(globalFeedProvider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryColor, AppTheme.accentColor],
                          ),
                          borderRadius: BorderRadius.circular(24),
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
                            size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        const Text('Seu feed está vazio',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
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

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
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
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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
