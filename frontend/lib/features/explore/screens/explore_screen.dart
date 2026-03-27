import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';

/// Provider para busca de comunidades.
final searchCommunitiesProvider =
    FutureProvider.family<List<CommunityModel>, String>((ref, query) async {
  if (query.isEmpty) {
    final response = await SupabaseService.table('communities')
        .select()
        .order('members_count', ascending: false)
        .limit(20);
    return (response as List)
        .map((e) => CommunityModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  final response = await SupabaseService.table('communities')
      .select()
      .ilike('name', '%$query%')
      .order('members_count', ascending: false)
      .limit(20);
  return (response as List)
      .map((e) => CommunityModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Tela Discover — cópia 1:1 do Amino Apps.
/// Banner carrossel full-width, tabs superiores, seção "My Communities" com CHECK IN.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _bannerPageController = PageController(viewportFraction: 0.92);
  final _searchController = TextEditingController();
  int _currentBanner = 0;
  String _searchQuery = '';

  List<CommunityModel> _myCommunities = [];
  List<CommunityModel> _trendingCommunities = [];
  List<CommunityModel> _newCommunities = [];
  bool _isLoading = true;

  final _tabs = const ['Para Você', 'Trending', 'Novos', 'Categorias'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = SupabaseService.currentUserId;

      // Minhas comunidades
      if (userId != null) {
        final myRes = await SupabaseService.table('community_members')
            .select('community_id, communities(*)')
            .eq('user_id', userId)
            .order('joined_at', ascending: false)
            .limit(20);
        _myCommunities = (myRes as List)
            .where((e) => e['communities'] != null)
            .map((e) => CommunityModel.fromJson(e['communities']))
            .toList();
      }

      // Trending (por membros)
      final trendRes = await SupabaseService.table('communities')
          .select()
          .order('members_count', ascending: false)
          .limit(20);
      _trendingCommunities = (trendRes as List)
          .map((e) => CommunityModel.fromJson(e))
          .toList();

      // Novos
      final newRes = await SupabaseService.table('communities')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      _newCommunities = (newRes as List)
          .map((e) => CommunityModel.fromJson(e))
          .toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bannerPageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text(
              'Discover',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () => _showSearchSheet(context),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {/* TODO: notifications */},
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabAlignment: TabAlignment.start,
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildForYouTab(),
                  _buildCommunityGrid(_trendingCommunities),
                  _buildCommunityGrid(_newCommunities),
                  _buildCategoriesTab(),
                ],
              ),
      ),
    );
  }

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar comunidades...',
                      prefixIcon:
                          const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                      filled: true,
                      fillColor: AppTheme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final results = ref.watch(
                          searchCommunitiesProvider(_searchQuery));
                      return results.when(
                        loading: () => const Center(
                            child: CircularProgressIndicator()),
                        error: (e, _) =>
                            Center(child: Text('Erro: $e')),
                        data: (communities) {
                          if (communities.isEmpty) {
                            return const Center(
                              child: Text('Nenhuma comunidade encontrada',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary)),
                            );
                          }
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: communities.length,
                            itemBuilder: (_, i) => _CommunityListTile(
                                community: communities[i]),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ========================================================================
  // TAB: Para Você
  // ========================================================================
  Widget _buildForYouTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Banner Carrossel
          if (_trendingCommunities.isNotEmpty) _buildBannerCarousel(),

          // Seção: Minhas Comunidades
          if (_myCommunities.isNotEmpty) ...[
            _buildSectionHeader('Minhas Comunidades', onSeeAll: () {}),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _myCommunities.length,
                itemBuilder: (context, index) =>
                    _MyCommunityCard(community: _myCommunities[index]),
              ),
            ),
          ],

          // Seção: Trending
          _buildSectionHeader('Trending', onSeeAll: () {
            _tabController.animateTo(1);
          }),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _trendingCommunities.take(10).length,
              itemBuilder: (context, index) => _TrendingCommunityCard(
                  community: _trendingCommunities[index]),
            ),
          ),

          // Seção: Novos
          _buildSectionHeader('Recém Criados', onSeeAll: () {
            _tabController.animateTo(2);
          }),
          ..._newCommunities
              .take(5)
              .map((c) => _CommunityListTile(community: c)),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildBannerCarousel() {
    final bannerItems = _trendingCommunities.take(5).toList();
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _bannerPageController,
            itemCount: bannerItems.length,
            onPageChanged: (i) => setState(() => _currentBanner = i),
            itemBuilder: (context, index) {
              final community = bannerItems[index];
              return GestureDetector(
                onTap: () => context.push('/community/${community.id}'),
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        _parseColor(community.themeColor),
                        _parseColor(community.themeColor).withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (community.bannerUrl != null)
                          CachedNetworkImage(
                            imageUrl: community.bannerUrl!,
                            fit: BoxFit.cover,
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7)
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                community.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${formatCount(community.membersCount)} membros',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            bannerItems.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentBanner == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentBanner == i
                    ? AppTheme.primaryColor
                    : AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text('Ver Tudo',
                  style:
                      TextStyle(color: AppTheme.primaryColor, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  // ========================================================================
  // TAB: Grid genérico
  // ========================================================================
  Widget _buildCommunityGrid(List<CommunityModel> communities) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: communities.isEmpty
          ? const Center(
              child: Text('Nenhuma comunidade encontrada',
                  style: TextStyle(color: AppTheme.textSecondary)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: communities.length,
              itemBuilder: (context, index) =>
                  _CommunityGridCard(community: communities[index]),
            ),
    );
  }

  // ========================================================================
  // TAB: Categorias
  // ========================================================================
  Widget _buildCategoriesTab() {
    final categories = [
      _CategoryItem(
          'Anime & Manga', Icons.movie_filter_rounded, const Color(0xFFE91E63)),
      _CategoryItem(
          'K-Pop', Icons.music_note_rounded, const Color(0xFF9C27B0)),
      _CategoryItem(
          'Gaming', Icons.sports_esports_rounded, const Color(0xFF4CAF50)),
      _CategoryItem(
          'Art & Design', Icons.palette_rounded, const Color(0xFFFF9800)),
      _CategoryItem(
          'Fashion', Icons.checkroom_rounded, const Color(0xFFE040FB)),
      _CategoryItem(
          'Books & Writing', Icons.menu_book_rounded, const Color(0xFF795548)),
      _CategoryItem(
          'Movies & TV', Icons.theaters_rounded, const Color(0xFFF44336)),
      _CategoryItem(
          'Music', Icons.headphones_rounded, const Color(0xFF2196F3)),
      _CategoryItem(
          'Photography', Icons.camera_alt_rounded, const Color(0xFF607D8B)),
      _CategoryItem(
          'Science', Icons.science_rounded, const Color(0xFF00BCD4)),
      _CategoryItem(
          'Sports', Icons.fitness_center_rounded, const Color(0xFFFF5722)),
      _CategoryItem(
          'Technology', Icons.computer_rounded, const Color(0xFF3F51B5)),
      _CategoryItem('Cosplay', Icons.face_retouching_natural_rounded,
          const Color(0xFFFF4081)),
      _CategoryItem('Spirituality', Icons.self_improvement_rounded,
          const Color(0xFF8BC34A)),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(cat.icon, color: cat.color),
            ),
            title: Text(cat.name,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textHint),
            onTap: () {/* TODO: filtrar por categoria */},
          ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }
}

// ============================================================================
// WIDGETS AUXILIARES
// ============================================================================

/// Card horizontal "Minhas Comunidades" com botão CHECK IN ciano
class _MyCommunityCard extends StatelessWidget {
  final CommunityModel community;
  const _MyCommunityCard({required this.community});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/community/${community.id}'),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppTheme.cardColor,
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: community.iconUrl != null
                    ? CachedNetworkImage(
                        imageUrl: community.iconUrl!,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.groups_rounded,
                        color: AppTheme.textHint, size: 32),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              community.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'CHECK IN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card vertical para trending
class _TrendingCommunityCard extends StatelessWidget {
  final CommunityModel community;
  const _TrendingCommunityCard({required this.community});

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(community.themeColor);
    return GestureDetector(
      onTap: () => context.push('/community/${community.id}'),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.5)]),
                ),
                child: community.bannerUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: CachedNetworkImage(
                          imageUrl: community.bannerUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : Center(
                        child: Icon(Icons.groups_rounded,
                            color: Colors.white54, size: 36)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.people_rounded, size: 12, color: color),
                        const SizedBox(width: 4),
                        Text(
                          formatCount(community.membersCount),
                          style: TextStyle(color: color, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tile de lista para comunidades
class _CommunityListTile extends StatelessWidget {
  final CommunityModel community;
  const _CommunityListTile({required this.community});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppTheme.cardColor,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: community.iconUrl != null
              ? CachedNetworkImage(
                  imageUrl: community.iconUrl!, fit: BoxFit.cover)
              : const Icon(Icons.groups_rounded, color: AppTheme.textHint),
        ),
      ),
      title: Text(community.name,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        '${formatCount(community.membersCount)} membros',
        style:
            const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Entrar',
          style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
      ),
      onTap: () => context.push('/community/${community.id}'),
    );
  }
}

/// Card de grid
class _CommunityGridCard extends StatelessWidget {
  final CommunityModel community;
  const _CommunityGridCard({required this.community});

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(community.themeColor);
    return GestureDetector(
      onTap: () => context.push('/community/${community.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.5)]),
                ),
                child: community.bannerUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: CachedNetworkImage(
                          imageUrl: community.bannerUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : Center(
                        child: Icon(Icons.groups_rounded,
                            color: Colors.white54, size: 40)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.people_rounded, size: 12, color: color),
                        const SizedBox(width: 4),
                        Text(formatCount(community.membersCount),
                            style: TextStyle(color: color, fontSize: 11)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Entrar',
                            style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryItem {
  final String name;
  final IconData icon;
  final Color color;
  const _CategoryItem(this.name, this.icon, this.color);
}
