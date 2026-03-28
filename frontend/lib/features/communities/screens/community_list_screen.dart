import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/amino_top_bar.dart';
import '../../../core/widgets/amino_particles_bg.dart';

/// Provider para comunidades do usuário.
final userCommunitiesProvider =
    FutureProvider<List<CommunityModel>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final response = await SupabaseService.table('community_members')
      .select('community_id, communities(*)')
      .eq('user_id', userId)
      .eq('is_banned', false)
      .order('joined_at', ascending: false);

  return (response as List)
      .where((e) => e['communities'] != null)
      .map((e) =>
          CommunityModel.fromJson(e['communities'] as Map<String, dynamic>))
      .toList();
});

/// Provider para comunidades sugeridas.
final suggestedCommunitiesProvider =
    FutureProvider<List<CommunityModel>>((ref) async {
  final response = await SupabaseService.table('communities')
      .select()
      .eq('is_active', true)
      .eq('is_searchable', true)
      .order('members_count', ascending: false)
      .limit(50);

  return (response as List)
      .map((e) => CommunityModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class CommunityListScreen extends ConsumerStatefulWidget {
  final bool isExplore;

  const CommunityListScreen({super.key, this.isExplore = false});

  @override
  ConsumerState<CommunityListScreen> createState() =>
      _CommunityListScreenState();
}

class _CommunityListScreenState extends ConsumerState<CommunityListScreen> {
  String? _avatarUrl;
  int _coins = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final profile = await SupabaseService.table('profiles')
          .select('avatar_url, coins_count')
          .eq('id', userId)
          .single();
      if (mounted) {
        setState(() {
          _avatarUrl = profile['avatar_url'] as String?;
          _coins = profile['coins_count'] as int? ?? 0;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final communitiesAsync = ref.watch(userCommunitiesProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: AminoParticlesBg(
        child: Column(
          children: [
            AminoTopBar(
              avatarUrl: _avatarUrl,
              coins: _coins,
              onSearchTap: () => context.push('/search'),
              onAddTap: () => context.push('/community/create'),
            ),
            Expanded(
              child: communitiesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.accentColor,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (error, stack) => _buildErrorState(),
                data: (communities) {
                  if (communities.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildCommunityList(communities);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityList(List<CommunityModel> communities) {
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        ref.invalidate(userCommunitiesProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Título "Minhas Comunidades" ──
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Text(
                'Minhas Comunidades',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

            // ── Grade horizontal de cards ──
            // 3 cards visíveis na tela: 2 comunidades + 1 "Entrar em uma comunidade"
            SizedBox(
              height: 175, // espaço para o ícone flutuante acima do card
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16, right: 8),
                itemCount: communities.length + 1,
                itemBuilder: (context, index) {
                  if (index < communities.length) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _AminoCommunityCard(
                        community: communities[index],
                        onTap: () => context
                            .push('/community/${communities[index].id}'),
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          _showCommunityPreview(context, communities[index]);
                        },
                      ),
                    );
                  }
                  // Card "Entrar em uma comunidade"
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _JoinCommunityCard(
                      onTap: () => context.go('/explore'),
                    ),
                  );
                },
              ),
            ),

            // ── Texto instrucional ──
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 14),
              child: Center(
                child: Text(
                  'Pressione e segure o card para mudar a posição',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            // ── Botão outline "CRIE SUA COMUNIDADE" ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => context.push('/community/create'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.accentColor,
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'CRIE SUA COMUNIDADE',
                      style: TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommunityPreview(BuildContext context, CommunityModel community) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CommunityPreviewSheet(community: community),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_rounded,
                color: AppTheme.textHint, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Nenhuma comunidade',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Explore e entre em comunidades para começar!',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => context.go('/explore'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Explorar Comunidades',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: AppTheme.errorColor, size: 40),
          const SizedBox(height: 10),
          const Text(
            'Erro ao carregar comunidades',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => ref.invalidate(userCommunitiesProvider),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accentColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Tentar novamente',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CARD DE COMUNIDADE — Clone pixel-perfect do Amino original
//
// Estrutura visual (de cima para baixo):
// - Ícone flutuante no canto superior esquerdo (parcialmente fora do card)
// - Banner (imagem de capa) preenchendo o card
// - Gradiente escuro na base para legibilidade
// - Nome da comunidade na parte inferior da imagem
// - Barra CHECK IN ciano/verde-água na base
// ============================================================================
class _AminoCommunityCard extends StatelessWidget {
  final CommunityModel community;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// Largura do card — compacto, ~1/3 da tela para caber 3 cards
  static const double _cardWidth = 120;

  /// Tamanho do ícone flutuante
  static const double _iconSize = 32;

  /// Quanto o ícone sai acima da borda do card
  static const double _iconOverflow = 10;

  const _AminoCommunityCard({
    required this.community,
    required this.onTap,
    required this.onLongPress,
  });

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
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: _cardWidth,
        child: Padding(
          // Espaço acima para o ícone flutuante
          padding: const EdgeInsets.only(top: _iconOverflow),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Card principal ──
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF1E1E3A),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Banner (imagem de capa)
                    SizedBox(
                      height: 125,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Imagem
                          community.bannerUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: community.bannerUrl!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 360,
                                  memCacheHeight: 400,
                                  placeholder: (_, __) => Container(
                                    color: color.withValues(alpha: 0.3),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: color.withValues(alpha: 0.3),
                                    child: Center(
                                      child: Icon(Icons.groups_rounded,
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                          size: 28),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: color.withValues(alpha: 0.3),
                                  child: Center(
                                    child: Icon(Icons.groups_rounded,
                                        color: Colors.white
                                            .withValues(alpha: 0.2),
                                        size: 28),
                                  ),
                                ),

                          // Gradiente inferior para legibilidade do nome
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 55,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0xCC000000),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Nome da comunidade
                          Positioned(
                            bottom: 5,
                            left: 7,
                            right: 7,
                            child: Text(
                              community.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 6,
                                  ),
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Barra CHECK IN — ciano/verde-água
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      color: AppTheme.accentColor,
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
                  ],
                ),
              ),

              // ── Ícone flutuante (canto superior esquerdo, parcialmente fora) ──
              Positioned(
                top: -_iconOverflow,
                left: 8,
                child: Container(
                  width: _iconSize,
                  height: _iconSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF1E1E3A),
                    border: Border.all(color: color, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: community.iconUrl != null
                      ? CachedNetworkImage(
                          imageUrl: community.iconUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 64,
                          memCacheHeight: 64,
                        )
                      : Icon(Icons.groups_rounded,
                          color: AppTheme.textHint, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CARD "ENTRAR EM UMA COMUNIDADE" — translúcido cinza-azulado, placeholder
// Ícone "+" no topo, texto "Entrar em uma comunidade" centralizado.
// ============================================================================
class _JoinCommunityCard extends StatelessWidget {
  final VoidCallback onTap;
  const _JoinCommunityCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120, // mesma largura que os cards de comunidade
        margin: const EdgeInsets.only(top: 10), // alinha com o card (sem ícone flutuante)
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF2A2A5E).withValues(alpha: 0.5),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone "+"
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                color: Colors.white.withValues(alpha: 0.5),
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            // Texto
            Text(
              'Entrar em uma\ncomunidade',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PREVIEW DA COMUNIDADE — Bottom sheet (long press)
// ============================================================================
class _CommunityPreviewSheet extends StatelessWidget {
  final CommunityModel community;

  const _CommunityPreviewSheet({required this.community});

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.aminoPurple;
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(community.themeColor);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 32,
            height: 3,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Banner
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: community.bannerUrl != null
                      ? CachedNetworkImage(
                          imageUrl: community.bannerUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color, color.withValues(alpha: 0.5)],
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color, color.withValues(alpha: 0.5)],
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withValues(alpha: 0.5)],
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppTheme.surfaceColor.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Ícone + Nome + Tagline
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.cardColor,
                    border: Border.all(color: color, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: community.iconUrl != null
                      ? CachedNetworkImage(
                          imageUrl: community.iconUrl!,
                          fit: BoxFit.cover,
                        )
                      : Icon(Icons.groups_rounded,
                          color: AppTheme.textHint, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (community.tagline.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          community.tagline,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Estatísticas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.people_rounded,
                  label: '${_formatCount(community.membersCount)} membros',
                  color: AppTheme.accentColor,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.article_rounded,
                  label: '${_formatCount(community.postsCount)} posts',
                  color: AppTheme.aminoPurple,
                ),
              ],
            ),
          ),

          // Descrição
          if (community.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                community.description,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Botões
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/community/${community.id}');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Abrir',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          width: 1),
                    ),
                    child: const Text(
                      'Check In',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
