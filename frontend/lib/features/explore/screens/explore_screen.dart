import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/amino_animations.dart';

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

/// Tela Discover — réplica fiel do Amino Apps (baseada no web-preview).
/// Header com busca integrada, banner carrossel, seção "My Communities" com CHECK IN,
/// grid de comunidades com efeito de press, tabs superiores.
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

      final trendRes = await SupabaseService.table('communities')
          .select()
          .order('members_count', ascending: false)
          .limit(20);
      _trendingCommunities =
          (trendRes as List).map((e) => CommunityModel.fromJson(e)).toList();

      final newRes = await SupabaseService.table('communities')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      _newCommunities =
          (newRes as List).map((e) => CommunityModel.fromJson(e)).toList();

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
      backgroundColor: AppTheme.scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ================================================================
          // HEADER — Estilo Amino: título + busca + sino
          // ================================================================
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppTheme.scaffoldBg,
            elevation: 0,
            toolbarHeight: 56,
            title: const Text(
              'Discover',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: AppTheme.textPrimary,
              ),
            ),
            actions: [
              // Busca
              GestureDetector(
                onTap: () => _showSearchSheet(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.search_rounded,
                      color: AppTheme.textSecondary, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              // Notificações
              GestureDetector(
                onTap: () => context.push('/notifications'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_outlined,
                      color: AppTheme.textSecondary, size: 20),
                ),
              ),
              const SizedBox(width: 16),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.dividerColor.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.textHint,
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14),
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  tabs: _tabs.map((t) => Tab(text: t)).toList(),
                ),
              ),
            ),
          ),
        ],
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 2.5,
                ),
              )
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

  // ==========================================================================
  // SEARCH SHEET — Estilo Amino
  // ==========================================================================
  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          builder: (_, scrollController) {
            return Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Search input
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Buscar comunidades...',
                        hintStyle: const TextStyle(
                            color: AppTheme.textHint, fontSize: 15),
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 20, color: AppTheme.textHint),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              size: 18, color: AppTheme.textHint),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    ),
                  ),
                ),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final results =
                          ref.watch(searchCommunitiesProvider(_searchQuery));
                      return results.when(
                        loading: () => Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                            strokeWidth: 2.5,
                          ),
                        ),
                        error: (e, _) => Center(child: Text('Erro: $e')),
                        data: (communities) {
                          if (communities.isEmpty) {
                            return const Center(
                              child: Text('Nenhuma comunidade encontrada',
                                  style:
                                      TextStyle(color: AppTheme.textSecondary)),
                            );
                          }
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: communities.length,
                            itemBuilder: (_, i) => AminoAnimations.staggerItem(
                              index: i,
                              child:
                                  _CommunityListTile(community: communities[i]),
                            ),
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

  // ==========================================================================
  // TAB: Para Você
  // ==========================================================================
  Widget _buildForYouTab() {
    return RefreshIndicator(
      color: AppTheme.primaryColor,
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
                itemBuilder: (context, index) => AminoAnimations.staggerItem(
                  index: index,
                  child: _MyCommunityCard(community: _myCommunities[index]),
                ),
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
              itemBuilder: (context, index) => AminoAnimations.staggerItem(
                index: index,
                child: _TrendingCommunityCard(
                    community: _trendingCommunities[index]),
              ),
            ),
          ),

          // Seção: Novos
          _buildSectionHeader('Recém Criados', onSeeAll: () {
            _tabController.animateTo(2);
          }),
          ..._newCommunities
              .take(5)
              .toList()
              .asMap()
              .entries
              .map((entry) => AminoAnimations.staggerItem(
                    index: entry.key,
                    child: _CommunityListTile(community: entry.value),
                  )),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ==========================================================================
  // BANNER CARROSSEL — Estilo Amino (full-width, overlay gradiente)
  // ==========================================================================
  Widget _buildBannerCarousel() {
    final bannerItems = _trendingCommunities.take(5).toList();
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _bannerPageController,
            itemCount: bannerItems.length,
            onPageChanged: (i) => setState(() => _currentBanner = i),
            itemBuilder: (context, index) {
              final community = bannerItems[index];
              return AminoAnimations.cardPress(
                onTap: () => context.push('/community/${community.id}'),
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        _parseColor(community.themeColor),
                        _parseColor(community.themeColor)
                            .withValues(alpha: 0.6),
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
                        // Overlay gradiente escuro
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.75),
                              ],
                              stops: const [0.3, 1.0],
                            ),
                          ),
                        ),
                        // Conteúdo
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Row(
                            children: [
                              // Ícone da comunidade
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: community.iconUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: community.iconUrl!,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: _parseColor(
                                              community.themeColor),
                                          child: const Icon(
                                              Icons.groups_rounded,
                                              color: Colors.white70,
                                              size: 22),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      community.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${formatCount(community.membersCount)} membros',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Botão Join
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Join',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
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
        const SizedBox(height: 10),
        // Indicadores
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
        const SizedBox(height: 4),
      ],
    );
  }

  // ==========================================================================
  // SECTION HEADER — Estilo Amino
  // ==========================================================================
  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                children: [
                  Text('Ver Tudo',
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded,
                      color: AppTheme.primaryColor, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB: Grid genérico
  // ==========================================================================
  Widget _buildCommunityGrid(List<CommunityModel> communities) {
    return RefreshIndicator(
      color: AppTheme.primaryColor,
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
                childAspectRatio: 0.78,
              ),
              itemCount: communities.length,
              itemBuilder: (context, index) =>
                  _CommunityGridCard(community: communities[index]),
            ),
    );
  }

  // ==========================================================================
  // TAB: Categorias — Estilo Amino
  // ==========================================================================
  Widget _buildCategoriesTab() {
    final categories = [
      _CategoryItem(
          'Anime & Manga', Icons.movie_filter_rounded, const Color(0xFFE91E63)),
      _CategoryItem('K-Pop', Icons.music_note_rounded, const Color(0xFF9C27B0)),
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
      _CategoryItem('Music', Icons.headphones_rounded, const Color(0xFF2196F3)),
      _CategoryItem(
          'Photography', Icons.camera_alt_rounded, const Color(0xFF607D8B)),
      _CategoryItem('Science', Icons.science_rounded, const Color(0xFF00BCD4)),
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
        return AminoAnimations.staggerItem(
          index: index,
          child: AminoAnimations.cardPress(
            onTap: () {/* TODO: filtrar por categoria */},
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 22),
                ),
                title: Text(cat.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary)),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textHint, size: 20),
              ),
            ),
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
// WIDGETS AUXILIARES — Estilo Amino
// ============================================================================

/// Card horizontal "Minhas Comunidades" com botão CHECK IN verde Amino
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
            // Ícone da comunidade
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppTheme.cardColor,
                border: Border.all(
                  color: AppTheme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: community.iconUrl != null
                    ? CachedNetworkImage(
                        imageUrl: community.iconUrl!,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.groups_rounded,
                        color: AppTheme.textHint, size: 30),
              ),
            ),
            const SizedBox(height: 6),
            // Nome
            Text(
              community.name,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            // Botão CHECK IN — verde Amino (estilo web-preview: .check-in-btn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'CHECK IN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
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

/// Card vertical para trending — Estilo Amino
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
    return AminoAnimations.cardPress(
      onTap: () => context.push('/community/${community.id}'),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.5)]),
                ),
                child: community.bannerUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14)),
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
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimary),
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
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
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

/// Tile de lista para comunidades — Estilo Amino
class _CommunityListTile extends StatelessWidget {
  final CommunityModel community;
  const _CommunityListTile({required this.community});

  @override
  Widget build(BuildContext context) {
    return AminoAnimations.cardPress(
      onTap: () => context.push('/community/${community.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Ícone
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppTheme.cardColor,
                border: Border.all(
                  color: AppTheme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: community.iconUrl != null
                    ? CachedNetworkImage(
                        imageUrl: community.iconUrl!, fit: BoxFit.cover)
                    : const Icon(Icons.groups_rounded,
                        color: AppTheme.textHint, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(community.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    '${formatCount(community.membersCount)} membros',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Botão Entrar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Entrar',
                style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de grid — Estilo Amino
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
    return AminoAnimations.cardPress(
      onTap: () => context.push('/community/${community.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.5)]),
                ),
                child: community.bannerUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14)),
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
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.people_rounded, size: 12, color: color),
                        const SizedBox(width: 4),
                        Text(formatCount(community.membersCount),
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Entrar',
                            style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
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
