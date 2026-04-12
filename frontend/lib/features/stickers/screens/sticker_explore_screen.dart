import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/sticker_model.dart';
import '../providers/sticker_providers.dart';
import 'sticker_pack_screen.dart';
import '../../../config/nexus_theme_extension.dart';

/// Tela de exploração de packs públicos de outros usuários.
class StickerExploreScreen extends ConsumerStatefulWidget {
  const StickerExploreScreen({super.key});

  @override
  ConsumerState<StickerExploreScreen> createState() => _StickerExploreScreenState();
}

class _StickerExploreScreenState extends ConsumerState<StickerExploreScreen> {
  final _searchCtrl = TextEditingController();
  String? _searchQuery;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        title: Text(
          'Explorar Figurinhas',
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(17),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          // Barra de busca
          Padding(
            padding: EdgeInsets.all(r.s(16)),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
              decoration: InputDecoration(
                hintText: 'Buscar packs de figurinhas...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: context.nexusTheme.surfacePrimary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[600], size: r.s(20)),
                suffixIcon: _searchQuery != null
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: Colors.grey[600], size: r.s(18)),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = null);
                        },
                      )
                    : null,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: r.s(16),
                  vertical: r.s(12),
                ),
              ),
              onSubmitted: (v) => setState(() => _searchQuery = v.trim().isEmpty ? null : v.trim()),
              textInputAction: TextInputAction.search,
            ),
          ),

          // Lista de packs
          Expanded(
            child: _PublicPacksList(searchQuery: _searchQuery),
          ),
        ],
      ),
    );
  }
}

class _PublicPacksList extends ConsumerWidget {
  final String? searchQuery;
  const _PublicPacksList({this.searchQuery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final packsAsync = ref.watch(publicPacksProvider(searchQuery));

    return packsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: context.nexusTheme.accentPrimary, strokeWidth: 2),
      ),
      error: (e, _) => Center(
        child: Text('Erro ao carregar packs', style: TextStyle(color: Colors.grey[500])),
      ),
      data: (packs) {
        if (packs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off_rounded, size: r.s(48), color: Colors.grey[700]),
                SizedBox(height: r.s(12)),
                Text(
                  searchQuery != null
                      ? 'Nenhum pack encontrado para "$searchQuery"'
                      : 'Nenhum pack público disponível ainda',
                  style: TextStyle(color: Colors.grey[500], fontSize: r.fs(13)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: context.nexusTheme.accentPrimary,
          onRefresh: () async => ref.invalidate(publicPacksProvider(searchQuery)),
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: r.s(16)),
            itemCount: packs.length,
            itemBuilder: (context, index) => _ExplorePackCard(pack: packs[index]),
          ),
        );
      },
    );
  }
}

class _ExplorePackCard extends ConsumerStatefulWidget {
  final StickerPackModel pack;
  const _ExplorePackCard({required this.pack});

  @override
  ConsumerState<_ExplorePackCard> createState() => _ExplorePackCardState();
}

class _ExplorePackCardState extends ConsumerState<_ExplorePackCard> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final pickerState = ref.watch(stickerPickerProvider);
    final isSaved = pickerState.isPackSaved(widget.pack.id) || widget.pack.isSaved;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StickerPackScreen(packId: widget.pack.id, isOwner: false),
        ),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: r.s(12)),
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: context.nexusTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            // Cover do pack
            ClipRRect(
              borderRadius: BorderRadius.circular(r.s(12)),
              child: SizedBox(
                width: r.s(72),
                height: r.s(72),
                child: widget.pack.coverUrl != null && widget.pack.coverUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.pack.coverUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _PackCoverPlaceholder(name: widget.pack.name),
                      )
                    : _PackCoverPlaceholder(name: widget.pack.name),
              ),
            ),
            SizedBox(width: r.s(12)),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.pack.name,
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.pack.description.isNotEmpty) ...[
                    SizedBox(height: r.s(2)),
                    Text(
                      widget.pack.description,
                      style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: r.s(6)),
                  Row(
                    children: [
                      // Autor
                      if (widget.pack.authorName.isNotEmpty) ...[
                        CircleAvatar(
                          radius: r.s(8),
                          backgroundColor: context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
                          backgroundImage: widget.pack.creatorIcon != null
                              ? CachedNetworkImageProvider(widget.pack.creatorIcon!)
                              : null,
                          child: widget.pack.creatorIcon == null
                              ? Text(
                                  widget.pack.authorName[0].toUpperCase(),
                                  style: TextStyle(
                                    color: context.nexusTheme.accentPrimary,
                                    fontSize: r.fs(8),
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(width: r.s(4)),
                        Text(
                          widget.pack.authorName,
                          style: TextStyle(color: Colors.grey[500], fontSize: r.fs(11)),
                        ),
                        SizedBox(width: r.s(8)),
                      ],
                      Icon(Icons.collections_rounded, size: r.s(11), color: Colors.grey[600]),
                      SizedBox(width: r.s(2)),
                      Text(
                        '${widget.pack.stickerCount}',
                        style: TextStyle(color: Colors.grey[600], fontSize: r.fs(11)),
                      ),
                      SizedBox(width: r.s(6)),
                      Icon(Icons.bookmark_rounded, size: r.s(11), color: Colors.grey[600]),
                      SizedBox(width: r.s(2)),
                      Text(
                        '${widget.pack.savesCount}',
                        style: TextStyle(color: Colors.grey[600], fontSize: r.fs(11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(width: r.s(8)),

            // Botão salvar
            GestureDetector(
              onTap: _isSaving ? null : () => _toggleSave(widget.pack),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: r.s(12),
                  vertical: r.s(6),
                ),
                decoration: BoxDecoration(
                  color: isSaved
                      ? Colors.grey[800]
                      : context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.s(20)),
                  border: Border.all(
                    color: isSaved
                        ? Colors.grey[700]!
                        : context.nexusTheme.accentPrimary.withValues(alpha: 0.4),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        width: r.s(14),
                        height: r.s(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isSaved ? Colors.grey[400] : context.nexusTheme.accentPrimary,
                        ),
                      )
                    : Text(
                        isSaved ? 'Salvo' : 'Salvar',
                        style: TextStyle(
                          color: isSaved ? Colors.grey[400] : context.nexusTheme.accentPrimary,
                          fontSize: r.fs(12),
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

  Future<void> _toggleSave(StickerPackModel pack) async {
    setState(() => _isSaving = true);
    await ref.read(stickerPickerProvider.notifier).toggleSavePack(pack);
    if (mounted) setState(() => _isSaving = false);
  }
}

class _PackCoverPlaceholder extends StatelessWidget {
  final String name;
  const _PackCoverPlaceholder({required this.name});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      color: context.nexusTheme.accentPrimary.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.emoji_emotions_rounded,
          size: r.s(32),
          color: context.nexusTheme.accentPrimary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
