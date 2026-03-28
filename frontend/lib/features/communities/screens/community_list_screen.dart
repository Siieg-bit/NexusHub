import 'package:flutter/material.dart';
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
/// Layout: AminoTopBar + "Minhas Comunidades" (grid cards com CHECK IN)
/// + "Long press the card to change position" + botão "CRIE A SUA"
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
            // ── Top Bar Amino ──
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
  // LISTA DE COMUNIDADES — Estilo Amino
  // ==========================================================================
  Widget _buildCommunityList(List<CommunityModel> communities) {
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async => ref.invalidate(userCommunitiesProvider),
      child: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 80,
        ),
        children: [
          // ── Header "Minhas Comunidades" ──
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Minhas Comunidades',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),

          // ── Grid de comunidades (estilo Amino: 2 colunas) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: communities.length + 1, // +1 para o card "Join a community"
              itemBuilder: (context, index) {
                if (index < communities.length) {
                  return _AminoCommunityCard(community: communities[index]);
                }
                // Último card: "Join a community" (estilo Amino)
                return _JoinCommunityCard(
                  onTap: () => context.go('/explore'),
                );
              },
            ),
          ),

          // ── Texto "Long press the card to change position" ──
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

          // ── Botão "CRIE A SUA" (estilo Amino: borda ciano/teal) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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

  // ==========================================================================
  // ESTADO VAZIO — Estilo Amino
  // ==========================================================================
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 64,
              color: AppTheme.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma comunidade ainda',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Entre em comunidades para encontrar pessoas com os mesmos interesses!',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Botão "Explorar Comunidades"
            GestureDetector(
              onTap: () => context.go('/explore'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.explore_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Explorar Comunidades',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Botão "CRIE A SUA"
            GestureDetector(
              onTap: () => context.push('/community/create'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.accentColor, width: 1.5),
                ),
                child: const Text(
                  'CRIE SUA COMUNIDADE',
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // ESTADO DE ERRO
  // ==========================================================================
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          const Text(
            'Erro ao carregar comunidades',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => ref.invalidate(userCommunitiesProvider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Tentar novamente',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CARD DE COMUNIDADE — Estilo Amino (imagem de fundo + nome + avatar + CHECK IN)
// ============================================================================
class _AminoCommunityCard extends StatelessWidget {
  final CommunityModel community;
  const _AminoCommunityCard({required this.community});

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
      onLongPress: () {
        // TODO: Reordenar comunidades
      },
      child: Container(
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
                      color: Colors.white54, size: 40),
                ),
              ),

            // Gradiente escuro inferior
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),

            // Ícone da comunidade (centro)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
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
                      : Icon(Icons.groups_rounded,
                          color: AppTheme.textHint, size: 24),
                ),
              ),
            ),

            // Nome da comunidade
            Positioned(
              bottom: 36,
              left: 8,
              right: 8,
              child: Text(
                community.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),

            // Botão CHECK IN — verde Amino
            Positioned(
              bottom: 8,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 5),
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

// ============================================================================
// CARD "JOIN A COMMUNITY" — Estilo Amino (card cinza com ícone +)
// ============================================================================
class _JoinCommunityCard extends StatelessWidget {
  final VoidCallback onTap;
  const _JoinCommunityCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppTheme.surfaceColor.withValues(alpha: 0.6),
          border: Border.all(
            color: AppTheme.dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: AppTheme.textSecondary, size: 28),
            ),
            const SizedBox(height: 12),
            const Text(
              'Entrar em uma\ncomunidade',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
