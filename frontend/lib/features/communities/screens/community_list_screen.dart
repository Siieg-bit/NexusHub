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

/// Tela de Comunidades — réplica fiel do Amino Apps.
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
            // ── Top Bar ──
            AminoTopBar(
              avatarUrl: _avatarUrl,
              coins: _coins,
              onSearchTap: () => context.push('/search'),
              onAddTap: () => context.push('/community/create'),
            ),

            // ── Conteúdo ──
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

  // ==========================================================================
  // LISTA DE COMUNIDADES
  // ==========================================================================
  Widget _buildCommunityList(List<CommunityModel> communities) {
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        ref.invalidate(userCommunitiesProvider);
      },
      child: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 80,
        ),
        children: [
          // ── Header "Minhas Comunidades" ──
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Minhas Comunidades',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),

          // ── Grid 2 colunas (estilo Amino original) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildGrid(communities),
          ),

          // ── Texto "Long press" ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Pressione e segure o card para mudar a posição',
                style: TextStyle(
                  color: AppTheme.textHint,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),

          // ── Botão "CRIE SUA COMUNIDADE" ──
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
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Grid 2 colunas (fiel ao Amino original)
  Widget _buildGrid(List<CommunityModel> communities) {
    final totalItems = communities.length + 1; // +1 para "Join a community"
    final rows = (totalItems / 2).ceil();

    return Column(
      children: List.generate(rows, (rowIndex) {
        final startIndex = rowIndex * 2;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(2, (colIndex) {
              final itemIndex = startIndex + colIndex;
              if (itemIndex < communities.length) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: colIndex > 0 ? 5 : 0,
                      right: colIndex < 1 ? 5 : 0,
                    ),
                    child: _AminoCommunityCard(
                      community: communities[itemIndex],
                      onTap: () =>
                          context.push('/community/${communities[itemIndex].id}'),
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        _showCommunityPreview(
                            context, communities[itemIndex]);
                      },
                    ),
                  ),
                );
              } else if (itemIndex == communities.length) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: colIndex > 0 ? 5 : 0,
                      right: colIndex < 1 ? 5 : 0,
                    ),
                    child: _JoinCommunityCard(
                      onTap: () => context.go('/explore'),
                    ),
                  ),
                );
              } else {
                return const Expanded(child: SizedBox.shrink());
              }
            }),
          ),
        );
      }),
    );
  }

  // ── Preview da comunidade (long press) ──
  void _showCommunityPreview(BuildContext context, CommunityModel community) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CommunityPreviewSheet(community: community),
    );
  }

  // ── Estado vazio ──
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_rounded,
                color: AppTheme.textHint, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma comunidade',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Explore e entre em comunidades para começar!',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => context.go('/explore'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'Explorar Comunidades',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
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

  // ── Estado de erro ──
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: AppTheme.errorColor, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Erro ao carregar comunidades',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => ref.invalidate(userCommunitiesProvider),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.accentColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Tentar novamente',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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
// CARD DE COMUNIDADE — Estilo Amino original
// Ícone pequeno no canto superior esquerdo com borda colorida,
// nome na parte inferior esquerda sobre gradiente,
// barra verde CHECK IN na base do card
// ============================================================================
class _AminoCommunityCard extends StatelessWidget {
  final CommunityModel community;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Imagem de capa com ícone e nome ──
            AspectRatio(
              aspectRatio: 0.82,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Imagem de capa (preenche todo o card)
                  community.bannerUrl != null
                      ? CachedNetworkImage(
                          imageUrl: community.bannerUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          memCacheHeight: 500,
                          placeholder: (_, __) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [color, color.withValues(alpha: 0.5)],
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [color, color.withValues(alpha: 0.5)],
                              ),
                            ),
                            child: Center(
                              child: Icon(Icons.groups_rounded,
                                  color: Colors.white.withValues(alpha: 0.3),
                                  size: 32),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [color, color.withValues(alpha: 0.5)],
                            ),
                          ),
                          child: Center(
                            child: Icon(Icons.groups_rounded,
                                color: Colors.white.withValues(alpha: 0.3),
                                size: 32),
                          ),
                        ),

                  // Gradiente escuro na parte inferior
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 70,
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

                  // Ícone pequeno — canto superior esquerdo
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: color, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: community.iconUrl != null
                          ? CachedNetworkImage(
                              imageUrl: community.iconUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 56,
                              memCacheHeight: 56,
                            )
                          : Container(
                              color: AppTheme.cardColor,
                              child: Icon(Icons.groups_rounded,
                                  color: AppTheme.textHint, size: 14),
                            ),
                    ),
                  ),

                  // Nome da comunidade — parte inferior esquerda
                  Positioned(
                    bottom: 6,
                    left: 8,
                    right: 8,
                    child: Text(
                      community.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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

            // ── Barra CHECK IN verde na base ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: AppTheme.primaryColor,
              child: const Text(
                'CHECK IN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

// ============================================================================
// CARD "JOIN A COMMUNITY"
// ============================================================================
class _JoinCommunityCard extends StatelessWidget {
  final VoidCallback onTap;
  const _JoinCommunityCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppTheme.surfaceColor.withValues(alpha: 0.5),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.cardColor.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Icon(Icons.add,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              'Entrar em uma\ncomunidade',
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Banner ──
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 160,
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
                height: 80,
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

          // ── Ícone + Nome + Tagline ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppTheme.cardColor,
                    border: Border.all(color: color, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: community.iconUrl != null
                      ? CachedNetworkImage(
                          imageUrl: community.iconUrl!,
                          fit: BoxFit.cover,
                        )
                      : Icon(Icons.groups_rounded,
                          color: AppTheme.textHint, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
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
                            fontSize: 12,
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

          const SizedBox(height: 14),

          // ── Estatísticas ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.people_rounded,
                  label: '${_formatCount(community.membersCount)} membros',
                  color: AppTheme.accentColor,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.article_rounded,
                  label: '${_formatCount(community.postsCount)} posts',
                  color: AppTheme.aminoPurple,
                ),
              ],
            ),
          ),

          // ── Descrição ──
          if (community.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                community.description,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Botões ──
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 16,
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
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Abrir',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.5),
                          width: 1),
                    ),
                    child: const Text(
                      'Check In',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 14,
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

// ── Chip de estatística ──
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
