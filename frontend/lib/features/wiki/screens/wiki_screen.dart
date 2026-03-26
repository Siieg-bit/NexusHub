import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/wiki_model.dart';
import '../../../core/services/supabase_service.dart';

/// Provider para entradas wiki de uma comunidade.
final wikiEntriesProvider =
    FutureProvider.family<List<WikiEntry>, String>((ref, communityId) async {
  final response = await SupabaseService.table('wiki_entries')
      .select('*, profiles!wiki_entries_author_id_fkey(nickname, avatar_url)')
      .eq('community_id', communityId)
      .eq('status', 'published')
      .order('created_at', ascending: false);

  return (response as List).map((e) => WikiEntry.fromJson(e as Map<String, dynamic>)).toList();
});

/// Tela de Wiki da comunidade.
class WikiScreen extends ConsumerWidget {
  final String communityId;

  const WikiScreen({super.key, required this.communityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wikiAsync = ref.watch(wikiEntriesProvider(communityId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wiki'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {/* TODO: Buscar wiki */},
          ),
        ],
      ),
      body: wikiAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.menu_book_rounded, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  Text('Wiki vazia',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          )),
                  const SizedBox(height: 8),
                  const Text('Seja o primeiro a criar uma entrada!',
                      style: TextStyle(color: AppTheme.textHint)),
                ],
              ),
            );
          }

          // Agrupar por categoria
          final categories = <String, List<WikiEntry>>{};
          for (final entry in entries) {
            final cat = entry.category ?? 'Geral';
            categories.putIfAbsent(cat, () => []);
            categories[cat]!.add(entry);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: categories.entries.map((catEntry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      catEntry.key,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.primaryLight,
                          ),
                    ),
                  ),
                  ...catEntry.value.map((entry) => _WikiEntryCard(entry: entry)),
                  const SizedBox(height: 8),
                ],
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/community/$communityId/wiki/create'),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

class _WikiEntryCard extends StatelessWidget {
  final WikiEntry entry;

  const _WikiEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/wiki/${entry.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: entry.coverImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: entry.coverImageUrl!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.article_rounded, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.summary != null)
                      Text(
                        entry.summary!,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 12, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Text('${entry.viewsCount}',
                            style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                        const SizedBox(width: 12),
                        const Icon(Icons.favorite_border_rounded, size: 12, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Text('${entry.likesCount}',
                            style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
