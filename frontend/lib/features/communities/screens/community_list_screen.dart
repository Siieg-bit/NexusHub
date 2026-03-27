import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Provider para comunidades do usuário (Home).
final userCommunitiesProvider = FutureProvider<List<CommunityModel>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final response = await SupabaseService.table('community_members')
      .select('community_id, communities(*)')
      .eq('user_id', userId)
      .eq('is_banned', false)
      .order('joined_at', ascending: false);

  return (response as List)
      .map((e) => CommunityModel.fromJson(e['communities'] as Map<String, dynamic>))
      .toList();
});

/// Provider para comunidades sugeridas (Explorar).
final suggestedCommunitiesProvider = FutureProvider<List<CommunityModel>>((ref) async {
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

/// Tela de lista de comunidades.
/// Exibe comunidades do usuário (Home) ou comunidades para explorar.
class CommunityListScreen extends ConsumerStatefulWidget {
  final bool isExplore;

  const CommunityListScreen({super.key, this.isExplore = false});

  @override
  ConsumerState<CommunityListScreen> createState() => _CommunityListScreenState();
}

class _CommunityListScreenState extends ConsumerState<CommunityListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final communitiesAsync = widget.isExplore
        ? ref.watch(suggestedCommunitiesProvider)
        : ref.watch(userCommunitiesProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ================================================================
          // APP BAR
          // ================================================================
          SliverAppBar(
            floating: true,
            snap: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isExplore ? 'Explorar' : 'Minhas Comunidades',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            if (!widget.isExplore && user != null)
                              Text(
                                'Olá, ${user.nickname}!',
                                style: const TextStyle(color: AppTheme.textSecondary),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            // Check-in button
                            IconButton(
                              onPressed: () => context.push('/check-in'),
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.calendar_today_rounded,
                                    color: AppTheme.warningColor, size: 20),
                              ),
                            ),
                            // Notificações
                            IconButton(
                              onPressed: () {
                                // TODO: Tela de notificações
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.notifications_outlined,
                                    color: AppTheme.primaryColor, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ================================================================
          // BARRA DE PESQUISA
          // ================================================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: widget.isExplore
                      ? 'Buscar comunidades...'
                      : 'Pesquisar nas suas comunidades...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textHint),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),

          // ================================================================
          // LISTA DE COMUNIDADES
          // ================================================================
          communitiesAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 16),
                    Text('Erro ao carregar comunidades',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (widget.isExplore) {
                          ref.invalidate(suggestedCommunitiesProvider);
                        } else {
                          ref.invalidate(userCommunitiesProvider);
                        }
                      },
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
            data: (communities) {
              // Filtrar por pesquisa
              final filtered = _searchQuery.isEmpty
                  ? communities
                  : communities
                      .where((c) =>
                          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          c.tagline.toLowerCase().contains(_searchQuery.toLowerCase()))
                      .toList();

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isExplore ? Icons.explore_off_rounded : Icons.group_off_rounded,
                          size: 64,
                          color: AppTheme.textHint,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.isExplore
                              ? 'Nenhuma comunidade encontrada'
                              : 'Você ainda não entrou em nenhuma comunidade',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        if (!widget.isExplore) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/explore'),
                            icon: const Icon(Icons.explore_rounded),
                            label: const Text('Explorar Comunidades'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _CommunityCard(community: filtered[index]),
                  childCount: filtered.length,
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: !widget.isExplore
          ? FloatingActionButton(
              onPressed: () => context.push('/community/create'),
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }
}

/// Card de comunidade na lista.
class _CommunityCard extends StatelessWidget {
  final CommunityModel community;

  const _CommunityCard({required this.community});

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _parseColor(community.themeColor);

    return GestureDetector(
      onTap: () => context.push('/community/${community.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            // Banner
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: community.bannerUrl != null
                    ? CachedNetworkImage(
                        imageUrl: community.bannerUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [themeColor, themeColor.withValues(alpha: 0.5)],
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [themeColor, themeColor.withValues(alpha: 0.5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Ícone da comunidade
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: themeColor.withValues(alpha: 0.5)),
                    ),
                    child: community.iconUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: community.iconUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(Icons.groups_rounded, color: themeColor, size: 28),
                  ),
                  const SizedBox(width: 12),

                  // Nome e tagline
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          community.name,
                          style: Theme.of(context).textTheme.titleLarge,
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

                  // Membros
                  Column(
                    children: [
                      Text(
                        _formatCount(community.membersCount),
                        style: TextStyle(
                          color: themeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'membros',
                        style: TextStyle(color: AppTheme.textHint, fontSize: 10),
                      ),
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

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
