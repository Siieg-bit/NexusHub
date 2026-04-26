import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/cache_service.dart';
import '../widgets/post_card.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/nexus_empty_state.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../../router/shell_screen.dart';
import '../widgets/announcement_banner.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provider de feed global com paginação (AsyncNotifier)
// Usa o RPC get_global_feed para evitar N+1 e suportar infinite scroll.
// ─────────────────────────────────────────────────────────────────────────────

class GlobalFeedNotifier extends AsyncNotifier<List<PostModel>> {
  static const _pageSize = 20;
  int _page = 0;
  bool _hasMore = true;

  bool get hasMore => _hasMore;

  @override
  Future<List<PostModel>> build() async {
    _page = 0;
    _hasMore = true;

    // Cache-first: exibe dados do cache imediatamente enquanto busca da rede
    final cached = CacheService.getCachedGlobalFeed();
    if (cached != null && cached.isNotEmpty) {
      // Emite cache imediatamente e atualiza em background
      Future.microtask(() async {
        try {
          final fresh = await _fetchPage(0);
          state = AsyncData(fresh);
        } catch (_) {}
      });
      return cached.map((e) => PostModel.fromJson(e)).toList();
    }

    return _fetchPage(0);
  }

  Future<List<PostModel>> _fetchPage(int page) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    try {
      final response = await SupabaseService.rpc('get_global_feed', params: {
        'p_user_id': userId,
        'p_limit': _pageSize,
        'p_offset': page * _pageSize,
      });

      final list = (response as List? ?? []);
      _hasMore = list.length >= _pageSize;

      final posts = list.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return PostModel.fromJson(map);
      }).toList();

      // Salva apenas a primeira página no cache
      if (page == 0 && posts.isNotEmpty) {
        CacheService.cacheGlobalFeed(
            list.map((e) => Map<String, dynamic>.from(e as Map)).toList());
      }

      return posts;
    } catch (e) {
      debugPrint('[GlobalFeed] Erro ao buscar feed: $e');
      // Fallback para query direta se RPC falhar
      final response = await SupabaseService.table('posts')
          .select(
              '*, profiles!posts_author_id_fkey(*), communities!posts_community_id_fkey(id, name, icon_url, theme_color)')
          .eq('status', 'ok')
          .order('created_at', ascending: false)
          .range(page * _pageSize, (page + 1) * _pageSize - 1);

      final list = (response as List? ?? []);
      _hasMore = list.length >= _pageSize;

      return list.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        if (map['profiles'] != null) map['author'] = map['profiles'];
        return PostModel.fromJson(map);
      }).toList();
    }
  }

  /// Carrega a próxima página (infinite scroll)
  Future<void> loadMore() async {
    if (!_hasMore || state.isLoading) return;
    final current = state.valueOrNull ?? [];
    _page++;
    try {
      final next = await _fetchPage(_page);
      state = AsyncData([...current, ...next]);
    } catch (_) {
      _page--;
    }
  }

  /// Atualiza o feed do início
  Future<void> refresh() async {
    _page = 0;
    _hasMore = true;
    state = const AsyncLoading();
    state = AsyncData(await _fetchPage(0));
  }
}

final globalFeedProvider =
    AsyncNotifierProvider<GlobalFeedNotifier, List<PostModel>>(
        GlobalFeedNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// Tela de feed global
// ─────────────────────────────────────────────────────────────────────────────

class GlobalFeedScreen extends ConsumerStatefulWidget {
  const GlobalFeedScreen({super.key});

  @override
  ConsumerState<GlobalFeedScreen> createState() => _GlobalFeedScreenState();
}

class _GlobalFeedScreenState extends ConsumerState<GlobalFeedScreen> {
  // Tab 0 = Discover/Feed
  // Usa o tabScrollControllerProvider para que o re-tap na aba acione scroll-to-top
  ScrollController get _scrollController =>
      ref.read(tabScrollControllerProvider(0));

  @override
  void initState() {
    super.initState();
    // Listener adicionado após o primeiro frame para garantir que o provider está pronto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.addListener(_onScroll);
    });
  }

  @override
  void dispose() {
    // Não dispose o controller pois ele é gerenciado pelo provider
    super.dispose();
  }

  void _onScroll() {
    // Carrega mais quando chegar a 200px do final
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final notifier = ref.read(globalFeedProvider.notifier);
      if (notifier.hasMore) {
        notifier.loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final feedAsync = ref.watch(globalFeedProvider);

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      body: RefreshIndicator(
        color: context.nexusTheme.accentPrimary,
        onRefresh: () => ref.read(globalFeedProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          // Pré-renderiza 500px além da área visível para scroll mais suave
          cacheExtent: 500,
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
                  tooltip: 'Notificações',
                ),
              ],
            ),

            // ================================================================
            // ANNOUNCEMENT BANNER
            // ================================================================
            const SliverToBoxAdapter(child: AnnouncementBanner()),
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
            // FEED HEADER
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
                      onTap: () => ref.read(globalFeedProvider.notifier).refresh(),
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

            // ================================================================
            // FEED CONTENT
            // ================================================================
            feedAsync.when(
              loading: () => const GlobalFeedSkeleton(count: 4),
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
                        onTap: () => ref.read(globalFeedProvider.notifier).refresh(),
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
                          child: Text(
                            s.retry,
                            style: const TextStyle(
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
                    child: NexusEmptyState(
                      icon: Icons.explore_rounded,
                      title: 'Seu feed está vazio',
                      subtitle: 'Entre em comunidades para ver posts aqui.',
                      actionLabel: 'Explorar comunidades',
                      onAction: () => context.push('/explore'),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Indicador de carregamento no final da lista
                      if (index == posts.length) {
                        final notifier = ref.read(globalFeedProvider.notifier);
                        if (!notifier.hasMore) return const SizedBox.shrink();
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      return RepaintBoundary(
                        child: PostCard(post: posts[index]),
                      );
                    },
                    // +1 para o indicador de carregamento no final
                    childCount: posts.length + 1,
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

// ─────────────────────────────────────────────────────────────────────────────
// Widget auxiliar: ação rápida
// ─────────────────────────────────────────────────────────────────────────────
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
        width: r.s(72),
        margin: EdgeInsets.only(right: r.s(8)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: r.s(48),
              height: r.s(48),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: r.s(22)),
            ),
            SizedBox(height: r.s(4)),
            Text(
              label,
              style: TextStyle(
                color: context.nexusTheme.textSecondary,
                fontSize: r.fs(10),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
