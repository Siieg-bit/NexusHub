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
      body: CustomScrollView(
        slivers: [
          // ================================================================
          // HEADER
          // ================================================================
          SliverAppBar(
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
                  ),
                  child: const Icon(Icons.hub_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('NexusHub'),
              ],
            ),
            actions: [
              // Check-in
              IconButton(
                icon: const Icon(Icons.calendar_today_rounded),
                onPressed: () => context.push('/check-in'),
                tooltip: 'Check-in Diário',
              ),
              // Notificações
              IconButton(
                icon: const Badge(
                  smallSize: 8,
                  child: Icon(Icons.notifications_outlined),
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
              height: 90,
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
                    color: AppTheme.successColor,
                    onTap: () {},
                  ),
                  _QuickAction(
                    icon: Icons.store_rounded,
                    label: 'Loja de\nCoins',
                    color: Colors.orange,
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Feed', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: () => ref.invalidate(globalFeedProvider),
                    child: const Text('Atualizar'),
                  ),
                ],
              ),
            ),
          ),

          feedAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 16),
                    Text('Erro ao carregar feed: $error'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(globalFeedProvider),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
            data: (posts) {
              if (posts.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.explore_rounded,
                            size: 64, color: AppTheme.textHint),
                        SizedBox(height: 16),
                        Text('Seu feed está vazio',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 16)),
                        SizedBox(height: 8),
                        Text(
                            'Explore e entre em comunidades para ver posts aqui!',
                            style: TextStyle(color: AppTheme.textHint)),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style:
                  const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
