import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/amino_top_bar.dart';
import '../../../core/widgets/amino_particles_bg.dart';

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

/// Tela Discover — réplica fiel do Amino Apps.
/// Layout: AminoTopBar + Banner Carousel + My Communities (CHECK IN) + Recommended Communities
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _bannerPageController = PageController(viewportFraction: 0.92);
  int _currentBanner = 0;

  List<CommunityModel> _myCommunities = [];
  List<CommunityModel> _recommendedCommunities = [];
  bool _isLoading = true;

  // Dados do usuário para a top bar
  String? _avatarUrl;
  int _coins = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = SupabaseService.currentUserId;

      if (userId != null) {
        // Carregar perfil do usuário
        try {
          final profile = await SupabaseService.table('profiles')
              .select('avatar_url, coins_count')
              .eq('id', userId)
              .single();
          _avatarUrl = profile['avatar_url'] as String?;
          _coins = profile['coins_count'] as int? ?? 0;
        } catch (_) {}

        // Minhas comunidades
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

      // Comunidades recomendadas
      final recRes = await SupabaseService.table('communities')
          .select()
          .order('members_count', ascending: false)
          .limit(20);
      _recommendedCommunities =
          (recRes as List).map((e) => CommunityModel.fromJson(e)).toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _bannerPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: AminoParticlesBg(
        child: Column(
          children: [
            // ── Top Bar Amino ──
            AminoTopBar(
              avatarUrl: _avatarUrl,
              coins: _coins,
              onSearchTap: () => context.push('/search'),
              onAddTap: () => context.push('/community/create'),
            ),

            // ── Conteúdo scrollável ──
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accentColor,
                        strokeWidth: 2.5,
                      ),
                    )
                  : RefreshIndicator(
                      color: AppTheme.primaryColor,
                      onRefresh: _loadData,
                      child: ListView(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).padding.bottom + 80,
                        ),
                        children: [
                          // ── Banner Carousel ──
                          _buildBannerCarousel(),

                          // ── Minhas Comunidades ──
                          if (_myCommunities.isNotEmpty) ...[
                            _buildSectionHeader('Minhas Comunidades'),
                            SizedBox(
                              height: 180,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _myCommunities.length,
                                itemBuilder: (context, index) =>
                                    _MyCommunityCard(community: _myCommunities[index]),
                              ),
                            ),
                          ],

                          // ── Comunidades Recomendadas ──
                          _buildSectionHeader('Comunidades Recomendadas',
                              onSeeAll: () => context.push('/communities')),
                          ..._recommendedCommunities.map(
                            (c) => _RecommendedCommunityTile(community: c),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BANNER CAROUSEL — Estilo Amino (banner grande + dots)
  // ==========================================================================
  Widget _buildBannerCarousel() {
    // Banners de exemplo (serão substituídos por dados reais)
    final bannerItems = _recommendedCommunities.take(5).toList();
    if (bannerItems.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _bannerPageController,
            itemCount: bannerItems.length,
            onPageChanged: (i) => setState(() => _currentBanner = i),
            itemBuilder: (context, index) {
              final community = bannerItems[index];
              return GestureDetector(
                onTap: () => context.push('/community/${community.id}'),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.cardColor,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Imagem de fundo
                      if (community.bannerUrl != null)
                        CachedNetworkImage(
                          imageUrl: community.bannerUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppTheme.cardColor,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _parseColor(community.themeColor),
                                  _parseColor(community.themeColor).withValues(alpha: 0.5),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _parseColor(community.themeColor),
                                _parseColor(community.themeColor).withValues(alpha: 0.5),
                              ],
                            ),
                          ),
                        ),
                      // Gradiente escuro na parte inferior
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 80,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Texto do banner
                      Positioned(
                        bottom: 12,
                        left: 14,
                        right: 14,
                        child: Row(
                          children: [
                            // Ícone da comunidade
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: AppTheme.cardColor,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: community.iconUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: community.iconUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(Icons.groups_rounded,
                                      color: AppTheme.textHint, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    community.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${formatCount(community.membersCount)} membros',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 11,
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
                                'Entrar',
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
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dots de paginação
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
                    ? Colors.white
                    : AppTheme.textHint.withValues(alpha: 0.4),
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
                          color: AppTheme.accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded,
                      color: AppTheme.accentColor, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.aminoPurple;
    }
  }
}

// ============================================================================
// WIDGETS AUXILIARES — Estilo Amino Original
// ============================================================================

/// Card "Minhas Comunidades" — estilo Amino com imagem de fundo + nome + CHECK IN
/// Cards verticais com imagem de fundo cobrindo todo o card, nome sobreposto,
/// avatar do usuário e botão "CHECK IN" verde na parte inferior.
class _MyCommunityCard extends StatelessWidget {
  final CommunityModel community;
  const _MyCommunityCard({required this.community});

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.aminoPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(community.themeColor);
    return GestureDetector(
      onTap: () => context.push('/community/${community.id}'),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppTheme.cardColor,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Imagem de fundo cobrindo todo o card
            if (community.bannerUrl != null)
              CachedNetworkImage(
                imageUrl: community.bannerUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [color, color.withValues(alpha: 0.6)],
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [color, color.withValues(alpha: 0.6)],
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withValues(alpha: 0.6)],
                  ),
                ),
                child: Center(
                  child: Icon(Icons.groups_rounded,
                      color: Colors.white54, size: 36),
                ),
              ),

            // Gradiente escuro na parte inferior
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 90,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),

            // Ícone da comunidade (centro-superior)
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.cardColor.withValues(alpha: 0.8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: community.iconUrl != null
                      ? CachedNetworkImage(
                          imageUrl: community.iconUrl!,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.groups_rounded,
                          color: AppTheme.textHint, size: 22),
                ),
              ),
            ),

            // Nome da comunidade
            Positioned(
              bottom: 32,
              left: 8,
              right: 8,
              child: Text(
                community.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),

            // Botão CHECK IN — verde Amino (estilo original)
            Positioned(
              bottom: 8,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'CHECK IN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tile de comunidade recomendada — Estilo Amino (lista vertical)
class _RecommendedCommunityTile extends StatelessWidget {
  final CommunityModel community;
  const _RecommendedCommunityTile({required this.community});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/community/${community.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.cardColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Ícone da comunidade
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppTheme.surfaceColor,
              ),
              clipBehavior: Clip.antiAlias,
              child: community.iconUrl != null
                  ? CachedNetworkImage(
                      imageUrl: community.iconUrl!, fit: BoxFit.cover)
                  : const Icon(Icons.groups_rounded,
                      color: AppTheme.textHint, size: 24),
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
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Entrar',
                style: TextStyle(
                    color: Colors.white,
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

