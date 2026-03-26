import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';

/// Provider para busca de comunidades.
final searchCommunitiesProvider =
    FutureProvider.family<List<CommunityModel>, String>((ref, query) async {
  if (query.isEmpty) {
    // Retornar comunidades populares
    final response = await SupabaseService.table('communities')
        .select()
        .eq('is_public', true)
        .order('members_count', ascending: false)
        .limit(20);

    return (response as List).map((e) => CommunityModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  final response = await SupabaseService.table('communities')
      .select()
      .eq('is_public', true)
      .ilike('name', '%$query%')
      .order('members_count', ascending: false)
      .limit(20);

  return (response as List).map((e) => CommunityModel.fromJson(e as Map<String, dynamic>)).toList();
});

/// Tela de explorar/buscar comunidades e conteúdo.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final communitiesAsync = ref.watch(searchCommunitiesProvider(_searchQuery));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ================================================================
          // HEADER COM BUSCA
          // ================================================================
          SliverAppBar(
            floating: true,
            title: const Text('Explorar'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar comunidades...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value.trim()),
                ),
              ),
            ),
          ),

          // ================================================================
          // CATEGORIAS RÁPIDAS
          // ================================================================
          if (_searchQuery.isEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _CategoryChip(label: 'Anime', icon: Icons.movie_rounded),
                    _CategoryChip(label: 'K-Pop', icon: Icons.music_note_rounded),
                    _CategoryChip(label: 'Games', icon: Icons.sports_esports_rounded),
                    _CategoryChip(label: 'Arte', icon: Icons.palette_rounded),
                    _CategoryChip(label: 'Livros', icon: Icons.menu_book_rounded),
                    _CategoryChip(label: 'Ciência', icon: Icons.science_rounded),
                    _CategoryChip(label: 'Tech', icon: Icons.computer_rounded),
                    _CategoryChip(label: 'Esportes', icon: Icons.sports_rounded),
                  ],
                ),
              ),
            ),

          // ================================================================
          // TÍTULO DA SEÇÃO
          // ================================================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                _searchQuery.isEmpty ? 'Comunidades Populares' : 'Resultados',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),

          // ================================================================
          // GRID DE COMUNIDADES
          // ================================================================
          communitiesAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(child: Text('Erro: $error')),
            ),
            data: (communities) {
              if (communities.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 64, color: AppTheme.textHint),
                        const SizedBox(height: 16),
                        Text('Nenhuma comunidade encontrada',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                )),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _CommunityCard(community: communities[index]),
                    childCount: communities.length,
                  ),
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _CategoryChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: AppTheme.primaryLight),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: () {/* TODO: Filtrar por categoria */},
        backgroundColor: AppTheme.cardColor,
        side: BorderSide.none,
      ),
    );
  }
}

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
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: LinearGradient(
                    colors: [themeColor, themeColor.withOpacity(0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: community.bannerUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: CachedNetworkImage(
                          imageUrl: community.bannerUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : Center(
                        child: Icon(Icons.groups_rounded, color: Colors.white54, size: 40),
                      ),
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.people_rounded, size: 12, color: themeColor),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(community.membersCount),
                          style: TextStyle(color: themeColor, fontSize: 11),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Entrar',
                            style: TextStyle(
                              color: themeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
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

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
