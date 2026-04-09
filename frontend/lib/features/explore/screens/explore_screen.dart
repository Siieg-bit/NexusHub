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
import '../../../core/providers/notification_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';

/// Provider para busca de comunidades.
final searchCommunitiesProvider =
    FutureProvider.family<List<CommunityModel>, String>((ref, query) async {
  if (query.isEmpty) {
    final response = await SupabaseService.table('communities')
        .select()
        .order('members_count', ascending: false)
        .limit(20);
    return (response as List? ?? [])
        .map((e) => CommunityModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  final response = await SupabaseService.table('communities')
      .select()
      .ilike('name', '%$query%')
      .order('members_count', ascending: false)
      .limit(20);
  return (response as List? ?? [])
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
  List<CommunityModel> _newCommunities = [];
  List<Map<String, dynamic>> _forYouPosts = [];
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
              .select('icon_url, coins')
              .eq('id', userId)
              .single();
          _avatarUrl = profile['icon_url'] as String?;
          _coins = profile['coins'] as int? ?? 0;
        } catch (e) {
          debugPrint('[explore_screen] Erro: $e');
        }

        // Minhas comunidades
        final myRes = await SupabaseService.table('community_members')
            .select('community_id, communities(*)')
            .eq('user_id', userId)
            .order('joined_at', ascending: false)
            .limit(20);
        _myCommunities = (myRes as List? ?? [])
            .where((e) => e['communities'] != null)
            .map((e) => CommunityModel.fromJson(e['communities']))
            .toList();
      }

      // Comunidades recomendadas
      final recRes = await SupabaseService.table('communities')
          .select()
          .order('members_count', ascending: false)
          .limit(20);
      _recommendedCommunities = (recRes as List? ?? [])
          .map((e) => CommunityModel.fromJson(e))
          .toList();

      // New Communities — mais recentes
      try {
        final newRes = await SupabaseService.table('communities')
            .select()
            .order('created_at', ascending: false)
            .limit(10);
        _newCommunities = (newRes as List? ?? [])
            .map((e) => CommunityModel.fromJson(e))
            .toList();
      } catch (e) {
        debugPrint('[explore_screen] Erro: $e');
      }

      // For You — posts populares recentes de comunidades do usuario
      try {
        final forYouRes = await SupabaseService.table('posts')
            .select(
                '*, profiles!posts_author_id_fkey(id, nickname, icon_url), communities!posts_community_id_fkey(id, name, icon_url)')
            .eq('status', 'ok')
            .order('likes_count', ascending: false)
            .limit(15);
        if (!mounted) return;
        _forYouPosts =
            List<Map<String, dynamic>>.from(forYouRes as List? ?? []);
      } catch (e) {
        debugPrint('[explore_screen] Erro: $e');
      }

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

  void _showCommunityContextMenu(
      BuildContext context, CommunityModel community) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final r = ctx.r;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: r.s(8)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: r.s(32),
                  height: r.s(3),
                  margin: EdgeInsets.only(bottom: r.s(8)),
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(16), vertical: r.s(8)),
                  child: Row(
                    children: [
                      Container(
                        width: r.s(40),
                        height: r.s(40),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(r.s(10)),
                          color: ctx.cardBg,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: community.iconUrl != null &&
                                community.iconUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: community.iconUrl!,
                                fit: BoxFit.cover,
                              )
                            : Icon(Icons.groups_rounded,
                                color: ctx.textHint, size: r.s(20)),
                      ),
                      SizedBox(width: r.s(12)),
                      Expanded(
                        child: Text(
                          community.name,
                          style: TextStyle(
                            color: ctx.textPrimary,
                            fontSize: r.fs(16),
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.grey[800], height: 1),
                // 1. Ver detalhes
                ListTile(
                  leading: Icon(Icons.info_outline_rounded,
                      color: AppTheme.accentColor, size: r.s(22)),
                  title: Text(
                    'Ver detalhes da comunidade',
                    style: TextStyle(
                        color: ctx.textPrimary,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/community/${community.id}/info');
                  },
                ),
                // 2. Reordenar
                ListTile(
                  leading: Icon(Icons.swap_vert_rounded,
                      color: AppTheme.aminoPurple, size: r.s(22)),
                  title: Text(
                    'Reordenar comunidades',
                    style: TextStyle(
                        color: ctx.textPrimary,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                            'Segure e arraste os cards para reordenar suas comunidades.'),
                        backgroundColor: AppTheme.accentColor,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                ),
                // 3. Sair
                ListTile(
                  leading: Icon(Icons.exit_to_app_rounded,
                      color: AppTheme.errorColor, size: r.s(22)),
                  title: Text(
                    s.leaveCommunity,
                    style: TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmLeaveCommunity(context, community);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmLeaveCommunity(
      BuildContext context, CommunityModel community) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final r = ctx.r;
        return AlertDialog(
          backgroundColor: ctx.surfaceColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.s(16))),
          title: Text(
            s.leaveCommunity,
            style:
                TextStyle(color: ctx.textPrimary, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Tem certeza que deseja sair de "${community.name}"? Voc\u00ea poder\u00e1 entrar novamente depois.',
            style: TextStyle(color: ctx.textSecondary, fontSize: r.fs(14)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  Text(s.cancel, style: TextStyle(color: ctx.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.logout,
                  style: TextStyle(
                      color: AppTheme.errorColor, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        final userId = SupabaseService.currentUserId;
        if (userId == null) return;

        await SupabaseService.table('community_members')
            .delete()
            .eq('community_id', community.id)
            .eq('user_id', userId);

        if (mounted) {
          // Refresh the list
          await _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Voc\u00ea saiu de "${community.name}".'),
              backgroundColor: AppTheme.accentColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('Erro ao sair da comunidade. Tente novamente.'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: AminoParticlesBg(
        child: Column(
          children: [
            // ── Top Bar Amino ──
            AminoTopBar(
              avatarUrl: _avatarUrl,
              coins: _coins,
              notificationCount: ref.watch(unreadNotificationCountProvider),
              onSearchTap: () => context.push('/search'),
              onAddTap: () => context.push('/coin-shop'),
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
                            _buildSectionHeader(s.myCommunitiesTitle),
                            SizedBox(
                              height: r.s(180),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    EdgeInsets.symmetric(horizontal: r.s(16)),
                                itemCount: _myCommunities.length,
                                itemBuilder: (context, index) =>
                                    _MyCommunityCard(
                                  community: _myCommunities[index],
                                  onLongPress: (c) =>
                                      _showCommunityContextMenu(context, c),
                                ),
                              ),
                            ),
                          ],

                          // ── New Communities ──
                          if (_newCommunities.isNotEmpty) ...[
                            _buildSectionHeader('New Communities'),
                            SizedBox(
                              height: r.s(120),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    EdgeInsets.symmetric(horizontal: r.s(16)),
                                itemCount: _newCommunities.length,
                                itemBuilder: (context, index) =>
                                    _NewCommunityCard(
                                        community: _newCommunities[index]),
                              ),
                            ),
                          ],

                          // ── For You ──
                          if (_forYouPosts.isNotEmpty) ...[
                            _buildSectionHeader('For You'),
                            ..._forYouPosts.map(
                              (post) => _ForYouPostTile(post: post),
                            ),
                          ],

                          // ── Comunidades Recomendadas ──
                          _buildSectionHeader(s.recommendedCommunities,
                              onSeeAll: () => context.push('/communities')),
                          ..._recommendedCommunities.map(
                            (c) => _RecommendedCommunityTile(community: c),
                          ),

                          SizedBox(height: r.s(20)),
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
    final r = context.r;
    // Banners de exemplo (serão substituídos por dados reais)
    final bannerItems = _recommendedCommunities.take(5).toList();
    if (bannerItems.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(height: r.s(8)),
        SizedBox(
          height: r.s(160),
          child: PageView.builder(
            controller: _bannerPageController,
            itemCount: bannerItems.length,
            onPageChanged: (i) => setState(() => _currentBanner = i),
            itemBuilder: (context, index) {
              final community = bannerItems[index];
              return GestureDetector(
                onTap: () => context.push('/community/${community.id}'),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: r.s(4)),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r.s(12)),
                    color: context.cardBg,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Imagem de fundo
                      if (community.bannerUrl != null &&
                          community.bannerUrl!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: community.bannerUrl ?? '',
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: context.cardBg,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _parseColor(community.themeColor),
                                  _parseColor(community.themeColor)
                                      .withValues(alpha: 0.5),
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
                                _parseColor(community.themeColor)
                                    .withValues(alpha: 0.5),
                              ],
                            ),
                          ),
                        ),
                      // Gradiente escuro na parte inferior
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: r.s(80),
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
                              width: r.s(36),
                              height: r.s(36),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(r.s(10)),
                                color: context.cardBg,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: community.iconUrl != null &&
                                      community.iconUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: community.iconUrl ?? '',
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(Icons.groups_rounded,
                                      color: context.textHint, size: r.s(20)),
                            ),
                            SizedBox(width: r.s(10)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    community.name,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: r.fs(15),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${formatCount(community.membersCount)} membros',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      fontSize: r.fs(11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Botão Join
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: r.s(16), vertical: r.s(8)),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(r.s(20)),
                              ),
                              child: Text(
                                s.login,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r.fs(12),
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
        SizedBox(height: r.s(10)),
        // Dots de paginação
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            bannerItems.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: r.s(3)),
              width: _currentBanner == i ? 20 : 6,
              height: r.s(6),
              decoration: BoxDecoration(
                color: _currentBanner == i
                    ? Colors.white
                    : context.textHint.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(r.s(3)),
              ),
            ),
          ),
        ),
        SizedBox(height: r.s(4)),
      ],
    );
  }

  // ==========================================================================
  // SECTION HEADER — Estilo Amino
  // ==========================================================================
  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(16), r.s(20), r.s(16), r.s(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: r.fs(18),
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary)),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                children: [
                  Text(s.seeAll2,
                      style: TextStyle(
                          color: AppTheme.accentColor,
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded,
                      color: AppTheme.accentColor, size: r.s(18)),
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
  final void Function(CommunityModel)? onLongPress;
  const _MyCommunityCard({required this.community, this.onLongPress});

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.aminoPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final color = _parseColor(community.themeColor);
    return GestureDetector(
      onTap: () => context.push('/community/${community.id}'),
      onLongPress: () => onLongPress?.call(community),
      child: Container(
        width: r.s(130),
        margin: EdgeInsets.only(right: r.s(12)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r.s(12)),
          color: context.cardBg,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Imagem de fundo cobrindo todo o card
            if (community.bannerUrl != null && community.bannerUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: community.bannerUrl ?? '',
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
                      color: Colors.white54, size: r.s(36)),
                ),
              ),

            // Gradiente escuro na parte inferior
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: r.s(90),
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
                  width: r.s(44),
                  height: r.s(44),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r.s(12)),
                    color: context.cardBg.withValues(alpha: 0.8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child:
                      community.iconUrl != null && community.iconUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: community.iconUrl ?? '',
                              fit: BoxFit.cover,
                            )
                          : Icon(Icons.groups_rounded,
                              color: context.textHint, size: r.s(22)),
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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.fs(12),
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
                padding: EdgeInsets.symmetric(vertical: r.s(4)),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(r.s(4)),
                ),
                child: Text(
                  'CHECK IN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.fs(10),
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

/// Card de New Community — Estilo Amino (scroll horizontal, card compacto)
class _NewCommunityCard extends StatelessWidget {
  final CommunityModel community;
  const _NewCommunityCard({required this.community});

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.aminoPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final color = _parseColor(community.themeColor);
    return GestureDetector(
      onTap: () => context.push('/community/${community.id}'),
      child: Container(
        width: r.s(200),
        margin: EdgeInsets.only(right: r.s(12)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r.s(12)),
          color: context.cardBg,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            if (community.bannerUrl != null && community.bannerUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: community.bannerUrl ?? '',
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.5)],
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.5)],
                  ),
                ),
              ),
            // Gradient overlay
            Positioned.fill(
              child: Container(
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
            ),
            // NEW badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(8), vertical: r.s(3)),
                decoration: BoxDecoration(
                  color: AppTheme.successColor,
                  borderRadius: BorderRadius.circular(r.s(6)),
                ),
                child: Text(
                  'NEW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.fs(9),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            // Info
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  Container(
                    width: r.s(32),
                    height: r.s(32),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(r.s(8)),
                      color: context.cardBg,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: community.iconUrl != null &&
                            community.iconUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: community.iconUrl ?? '',
                            fit: BoxFit.cover,
                          )
                        : Icon(Icons.groups_rounded,
                            color: context.textHint, size: r.s(16)),
                  ),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          community.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.fs(12),
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${formatCount(community.membersCount)} membros',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: r.fs(10),
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
}

/// Tile "For You" — Post popular com preview, estilo Amino
class _ForYouPostTile extends StatelessWidget {
  final Map<String, dynamic> post;
  const _ForYouPostTile({required this.post});

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final title = post['title'] as String? ?? '';
    final content = post['content'] as String? ?? '';
    final imageUrl = post['image_url'] as String?;
    final author = post['profiles'] as Map<String, dynamic>?;
    final community = post['communities'] as Map<String, dynamic>?;
    final likesCount = post['likes_count'] as int? ?? 0;
    final commentsCount = post['comments_count'] as int? ?? 0;
    final postId = post['id'] as String? ?? '';

    return GestureDetector(
      onTap: () => context.push('/post/$postId'),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(4)),
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: context.cardBg.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(r.s(8)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: r.s(64),
                  height: r.s(64),
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (imageUrl != null) SizedBox(width: r.s(12)),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Community name
                  if (community != null)
                    Row(
                      children: [
                        if (community['icon_url'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(r.s(4)),
                            child: CachedNetworkImage(
                              imageUrl: community['icon_url'] as String? ?? '',
                              width: r.s(14),
                              height: r.s(14),
                              fit: BoxFit.cover,
                            ),
                          ),
                        if (community['icon_url'] != null)
                          SizedBox(width: r.s(4)),
                        Expanded(
                          child: Text(
                            community['name'] as String? ?? '',
                            style: TextStyle(
                              color: context.textHint,
                              fontSize: r.fs(10),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (community != null) SizedBox(height: r.s(4)),
                  // Title
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(14),
                        color: context.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (title.isNotEmpty && content.isNotEmpty)
                    const SizedBox(height: 2),
                  // Content preview
                  if (content.isNotEmpty)
                    Text(
                      content,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: r.fs(12),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: r.s(6)),
                  // Author + stats
                  Row(
                    children: [
                      if (author != null) ...[
                        CircleAvatar(
                          radius: 10,
                          backgroundColor:
                              AppTheme.primaryColor.withValues(alpha: 0.2),
                          backgroundImage: author['icon_url'] != null
                              ? CachedNetworkImageProvider(
                                  author['icon_url'] as String? ?? '')
                              : null,
                          child: author['icon_url'] == null
                              ? Text(
                                  ((author['nickname'] as String?) ?? '?')[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: r.fs(8),
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(width: r.s(4)),
                        Flexible(
                          child: Text(
                            author['nickname'] as String? ?? '',
                            style: TextStyle(
                              color: context.textHint,
                              fontSize: r.fs(11),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: r.s(8)),
                      ],
                      Icon(Icons.favorite_rounded,
                          size: r.s(12), color: context.textHint),
                      const SizedBox(width: 2),
                      Text('$likesCount',
                          style: TextStyle(
                              color: context.textHint, fontSize: r.fs(11))),
                      SizedBox(width: r.s(8)),
                      Icon(Icons.chat_bubble_rounded,
                          size: r.s(12), color: context.textHint),
                      const SizedBox(width: 2),
                      Text('$commentsCount',
                          style: TextStyle(
                              color: context.textHint, fontSize: r.fs(11))),
                    ],
                  ),
                ],
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
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return GestureDetector(
      onTap: () => context.push('/community/${community.id}'),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(4)),
        padding: EdgeInsets.all(r.s(10)),
        decoration: BoxDecoration(
          color: context.cardBg.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Row(
          children: [
            // Ícone da comunidade
            Container(
              width: r.s(48),
              height: r.s(48),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r.s(14)),
                color: context.surfaceColor,
              ),
              clipBehavior: Clip.antiAlias,
              child: community.iconUrl != null && community.iconUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: community.iconUrl ?? '', fit: BoxFit.cover)
                  : Icon(Icons.groups_rounded,
                      color: context.textHint, size: r.s(24)),
            ),
            SizedBox(width: r.s(12)),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(community.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: r.fs(14),
                          color: context.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    '${formatCount(community.membersCount)} membros',
                    style: TextStyle(
                        color: context.textSecondary, fontSize: r.fs(12)),
                  ),
                ],
              ),
            ),
            // Botão Entrar
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(7)),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(r.s(20)),
              ),
              child: Text(
                s.login,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
