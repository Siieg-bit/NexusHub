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
/// Layout: AminoTopBar + "Minhas Comunidades" (grid 3 colunas com CHECK IN)
/// + "Long press the card to change position" + botão "CREATE YOUR OWN"
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
  bool _isReordering = false;
  List<CommunityModel> _reorderList = [];

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
                  // Inicializa a lista de reordenação se necessário
                  if (_reorderList.isEmpty ||
                      _reorderList.length != communities.length) {
                    _reorderList = List.from(communities);
                  }
                  return _buildCommunityList(
                      _isReordering ? _reorderList : communities);
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
      onRefresh: () async {
        _reorderList = [];
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
              ),
            ),
          ),

          // ── Grid de comunidades (estilo Amino: 3 colunas) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _isReordering
                ? _buildReorderGrid(communities)
                : _buildStaticGrid(communities),
          ),

          // ── Texto "Long press the card to change position" ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
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

          // ── Botão "CRIE SUA COMUNIDADE" (estilo Amino: borda ciano/teal) ──
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

  // Grid estático (3 colunas) com toque para preview e long press para reordenar
  Widget _buildStaticGrid(List<CommunityModel> communities) {
    // Calcula o número de linhas necessárias (incluindo o card "Join")
    final totalItems = communities.length + 1;
    final rows = (totalItems / 3).ceil();

    return Column(
      children: List.generate(rows, (rowIndex) {
        final startIndex = rowIndex * 3;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(3, (colIndex) {
              final itemIndex = startIndex + colIndex;
              if (itemIndex < communities.length) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: colIndex > 0 ? 6 : 0,
                      right: colIndex < 2 ? 6 : 0,
                    ),
                    child: _AminoCommunityCard(
                      community: communities[itemIndex],
                      onTap: () => _showCommunityPreview(
                          context, communities[itemIndex]),
                      onLongPress: () => _enterReorderMode(communities),
                    ),
                  ),
                );
              } else if (itemIndex == communities.length) {
                // Card "Join a community"
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: colIndex > 0 ? 6 : 0,
                      right: colIndex < 2 ? 6 : 0,
                    ),
                    child: _JoinCommunityCard(
                      onTap: () => context.go('/explore'),
                    ),
                  ),
                );
              } else {
                // Célula vazia para completar a linha
                return const Expanded(child: SizedBox.shrink());
              }
            }),
          ),
        );
      }),
    );
  }

  // Grid de reordenação com drag & drop
  Widget _buildReorderGrid(List<CommunityModel> communities) {
    return Column(
      children: [
        // Aviso de modo reordenação
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppTheme.accentColor.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.drag_indicator_rounded,
                  color: AppTheme.accentColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Arraste os cards para reordenar',
                  style: TextStyle(
                      color: AppTheme.accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isReordering = false),
                child: Text(
                  'Concluir',
                  style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        // Grid reordenável
        ReorderableWrap(
          communities: communities,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              final item = _reorderList.removeAt(oldIndex);
              _reorderList.insert(newIndex, item);
            });
          },
        ),
      ],
    );
  }

  void _enterReorderMode(List<CommunityModel> communities) {
    HapticFeedback.mediumImpact();
    setState(() {
      _reorderList = List.from(communities);
      _isReordering = true;
    });
  }

  // ==========================================================================
  // PREVIEW DA COMUNIDADE — Bottom sheet estilo Amino
  // ==========================================================================
  void _showCommunityPreview(BuildContext context, CommunityModel community) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CommunityPreviewSheet(community: community),
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
            GestureDetector(
              onTap: () => context.go('/explore'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
            GestureDetector(
              onTap: () => context.push('/community/create'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.accentColor, width: 1.5),
                ),
                child: const Text(
                  'CRIE SUA COMUNIDADE',
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 1.0,
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: AppTheme.errorColor.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            const Text(
              'Erro ao carregar comunidades',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => ref.invalidate(userCommunitiesProvider),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
      ),
    );
  }
}

// ============================================================================
// REORDERABLE WRAP — Grid reordenável simples
// ============================================================================
class ReorderableWrap extends StatelessWidget {
  final List<CommunityModel> communities;
  final void Function(int oldIndex, int newIndex) onReorder;

  const ReorderableWrap({
    super.key,
    required this.communities,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: communities.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final community = communities[index];
        return ReorderableDragStartListener(
          key: ValueKey(community.id),
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AminoCommunityCard(
              community: community,
              isDragging: true,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// CARD DE COMUNIDADE — Estilo Amino fiel ao APK original
// 3 colunas, ícone no canto superior esquerdo, imagem de fundo, CHECK IN
// ============================================================================
class _AminoCommunityCard extends StatelessWidget {
  final CommunityModel community;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isDragging;

  const _AminoCommunityCard({
    required this.community,
    required this.onTap,
    required this.onLongPress,
    this.isDragging = false,
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
      child: AspectRatio(
        aspectRatio: 0.72, // proporção fiel ao APK (mais alto que largo)
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: AppTheme.cardColor,
            boxShadow: isDragging
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Imagem de fundo (banner) cobrindo todo o card ──
              if (community.bannerUrl != null)
                CachedNetworkImage(
                  imageUrl: community.bannerUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 300, // otimização de memória
                  placeholder: (_, __) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color, color.withValues(alpha: 0.5)],
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color, color.withValues(alpha: 0.5)],
                      ),
                    ),
                    child: Center(
                      child: Icon(Icons.groups_rounded,
                          color: Colors.white38, size: 32),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [color, color.withValues(alpha: 0.5)],
                    ),
                  ),
                  child: Center(
                    child: Icon(Icons.groups_rounded,
                        color: Colors.white38, size: 32),
                  ),
                ),

              // ── Gradiente escuro na parte inferior ──
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
                        Colors.black.withValues(alpha: 0.80),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Ícone da comunidade — canto superior ESQUERDO (fiel ao APK) ──
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppTheme.cardColor.withValues(alpha: 0.9),
                    border: Border.all(
                      color: color.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
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
                          memCacheWidth: 64,
                        )
                      : Icon(Icons.groups_rounded,
                          color: AppTheme.textHint, size: 18),
                ),
              ),

              // ── Nome da comunidade — acima do botão CHECK IN ──
              Positioned(
                bottom: 30,
                left: 6,
                right: 6,
                child: Text(
                  community.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                ),
              ),

              // ── Botão CHECK IN — verde Amino, largura total ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor, // verde Amino #2DBE60
                  ),
                  child: const Text(
                    'CHECK IN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
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
// CARD "JOIN A COMMUNITY" — Estilo Amino (card cinza com ícone +)
// ============================================================================
class _JoinCommunityCard extends StatelessWidget {
  final VoidCallback onTap;
  const _JoinCommunityCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 0.72,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: AppTheme.surfaceColor.withValues(alpha: 0.6),
            border: Border.all(
              color: AppTheme.dividerColor.withValues(alpha: 0.4),
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
                  color: AppTheme.cardColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add,
                    color: AppTheme.textSecondary, size: 26),
              ),
              const SizedBox(height: 10),
              const Text(
                'Entrar em uma\ncomunidade',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PREVIEW DA COMUNIDADE — Bottom sheet estilo Amino
// Aparece ao primeiro toque no card, com botão "Entrar" ou "Abrir"
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
            margin: const EdgeInsets.only(top: 12, bottom: 0),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Banner da comunidade ──
          Stack(
            children: [
              // Imagem de capa
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
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
              // Gradiente inferior sobre o banner
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
                // Ícone
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
                // Nome e tagline
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

          // ── Botões de ação ──
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Row(
              children: [
                // Botão "Abrir" — abre a comunidade
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
                // Botão "Check In"
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/check-in');
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
