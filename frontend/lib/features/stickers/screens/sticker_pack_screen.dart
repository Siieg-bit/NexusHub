import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/sticker_model.dart';
import '../providers/sticker_providers.dart';
import '../repositories/sticker_repository.dart';
import 'sticker_creator_screen.dart';

/// Tela de detalhes de um pack de stickers.
/// Permite visualizar, editar (se dono), salvar e usar stickers.
class StickerPackScreen extends ConsumerStatefulWidget {
  final String packId;
  final bool isOwner;

  const StickerPackScreen({
    super.key,
    required this.packId,
    this.isOwner = false,
  });

  @override
  ConsumerState<StickerPackScreen> createState() => _StickerPackScreenState();
}

class _StickerPackScreenState extends ConsumerState<StickerPackScreen> {
  List<StickerModel> _stickers = [];
  bool _isLoadingStickers = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadStickers();
  }

  Future<void> _loadStickers() async {
    setState(() => _isLoadingStickers = true);
    final stickers = await StickerRepository.instance.getPackStickers(widget.packId);
    if (mounted) {
      setState(() {
        _stickers = stickers;
        _isLoadingStickers = false;
      });
    }
  }

  Future<void> _toggleSavePack(StickerPackModel pack) async {
    setState(() => _isSaving = true);
    final saved = await ref.read(stickerPickerProvider.notifier).toggleSavePack(pack);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved ? 'Pack salvo!' : 'Pack removido dos salvos'),
          backgroundColor: saved ? AppTheme.primaryColor : Colors.grey[700],
          duration: const Duration(seconds: 2),
        ),
      );
      ref.invalidate(savedPacksProvider);
    }
  }

  Future<void> _deletePack() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Deletar pack?',
            style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Todos os stickers deste pack serão removidos permanentemente.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deletar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(packEditorProvider.notifier).deletePack(widget.packId);
      ref.read(stickerPickerProvider.notifier).removeMyPack(widget.packId);
      ref.invalidate(myPacksProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteSticker(StickerModel sticker) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Remover sticker?',
            style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Este sticker será removido do pack.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await StickerRepository.instance.deleteStickerFromPack(sticker.id);
      setState(() => _stickers.removeWhere((s) => s.id == sticker.id));
      ref.invalidate(myPacksProvider);
      ref.read(stickerPickerProvider.notifier).reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final packAsync = ref.watch(packDetailProvider(widget.packId));
    final pickerState = ref.watch(stickerPickerProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: packAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Text('Erro ao carregar pack', style: TextStyle(color: Colors.grey[500])),
        ),
        data: (pack) {
          if (pack == null) {
            return const Center(child: Text('Pack não encontrado'));
          }

          final isSaved = pickerState.isPackSaved(pack.id) || pack.isSaved;

          return CustomScrollView(
            slivers: [
              // App Bar com cover
              SliverAppBar(
                expandedHeight: r.s(200),
                pinned: true,
                backgroundColor: context.surfaceColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: pack.coverUrl != null && pack.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: pack.coverUrl!,
                          fit: BoxFit.cover,
                          color: Colors.black.withValues(alpha: 0.4),
                          colorBlendMode: BlendMode.darken,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryColor.withValues(alpha: 0.3),
                                AppTheme.accentColor.withValues(alpha: 0.2),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.emoji_emotions_rounded,
                              size: r.s(64),
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                ),
                actions: [
                  if (widget.isOwner)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: Colors.white),
                      color: context.surfaceColor,
                      onSelected: (val) {
                        if (val == 'delete') _deletePack();
                        if (val == 'edit') _openEditPack(pack);
                        if (val == 'toggle_public') _togglePublic(pack);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_rounded, size: r.s(16), color: context.textPrimary),
                            SizedBox(width: r.s(8)),
                            Text('Editar pack', style: TextStyle(color: context.textPrimary)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'toggle_public',
                          child: Row(children: [
                            Icon(
                              pack.isPublic ? Icons.lock_rounded : Icons.public_rounded,
                              size: r.s(16),
                              color: context.textPrimary,
                            ),
                            SizedBox(width: r.s(8)),
                            Text(
                              pack.isPublic ? 'Tornar privado' : 'Tornar público',
                              style: TextStyle(color: context.textPrimary),
                            ),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_rounded, size: r.s(16), color: Colors.red),
                            SizedBox(width: r.s(8)),
                            const Text('Deletar pack', style: TextStyle(color: Colors.red)),
                          ]),
                        ),
                      ],
                    ),
                ],
              ),

              // Info do pack
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(r.s(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pack.name,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: r.fs(20),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (pack.description.isNotEmpty) ...[
                                  SizedBox(height: r.s(4)),
                                  Text(
                                    pack.description,
                                    style: TextStyle(color: Colors.grey[400], fontSize: r.fs(13)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Botão salvar (para não-donos)
                          if (!widget.isOwner)
                            GestureDetector(
                              onTap: _isSaving ? null : () => _toggleSavePack(pack),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(
                                  horizontal: r.s(16),
                                  vertical: r.s(8),
                                ),
                                decoration: BoxDecoration(
                                  color: isSaved
                                      ? Colors.grey[800]
                                      : AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(r.s(20)),
                                ),
                                child: _isSaving
                                    ? SizedBox(
                                        width: r.s(16),
                                        height: r.s(16),
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSaved
                                                ? Icons.bookmark_rounded
                                                : Icons.bookmark_border_rounded,
                                            size: r.s(16),
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: r.s(4)),
                                          Text(
                                            isSaved ? 'Salvo' : 'Salvar',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: r.fs(13),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: r.s(12)),
                      // Stats
                      Row(
                        children: [
                          _StatChip(
                            icon: Icons.collections_rounded,
                            label: '${pack.stickerCount} figurinhas',
                          ),
                          SizedBox(width: r.s(8)),
                          _StatChip(
                            icon: Icons.bookmark_rounded,
                            label: '${pack.savesCount} salvos',
                          ),
                          if (!pack.isPublic) ...[
                            SizedBox(width: r.s(8)),
                            _StatChip(
                              icon: Icons.lock_rounded,
                              label: 'Privado',
                              color: Colors.orange,
                            ),
                          ],
                        ],
                      ),
                      // Autor
                      if (pack.authorName.isNotEmpty && !widget.isOwner) ...[
                        SizedBox(height: r.s(12)),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: r.s(12),
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                              backgroundImage: pack.creatorIcon != null
                                  ? CachedNetworkImageProvider(pack.creatorIcon!)
                                  : null,
                              child: pack.creatorIcon == null
                                  ? Text(
                                      pack.authorName.isNotEmpty
                                          ? pack.authorName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: r.fs(10),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            SizedBox(width: r.s(8)),
                            Text(
                              'por ${pack.authorName}',
                              style: TextStyle(color: Colors.grey[400], fontSize: r.fs(12)),
                            ),
                          ],
                        ),
                      ],
                      // Tags
                      if (pack.tags.isNotEmpty) ...[
                        SizedBox(height: r.s(12)),
                        Wrap(
                          spacing: r.s(6),
                          runSpacing: r.s(4),
                          children: pack.tags.map((tag) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: r.s(8),
                              vertical: r.s(3),
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(r.s(8)),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                color: AppTheme.accentColor,
                                fontSize: r.fs(11),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                      SizedBox(height: r.s(16)),
                      Divider(color: Colors.white.withValues(alpha: 0.05)),
                    ],
                  ),
                ),
              ),

              // Grid de stickers
              _isLoadingStickers
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  : _stickers.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(r.s(32)),
                            child: Column(
                              children: [
                                Icon(Icons.emoji_emotions_outlined,
                                    size: r.s(48), color: Colors.grey[700]),
                                SizedBox(height: r.s(12)),
                                Text(
                                  widget.isOwner
                                      ? 'Nenhuma figurinha ainda.\nAdicione a primeira!'
                                      : 'Nenhuma figurinha neste pack.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[500], fontSize: r.fs(13)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: r.s(8),
                              mainAxisSpacing: r.s(8),
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final sticker = _stickers[index];
                                return _StickerGridItem(
                                  sticker: sticker,
                                  isOwner: widget.isOwner,
                                  onDelete: widget.isOwner
                                      ? () => _deleteSticker(sticker)
                                      : null,
                                );
                              },
                              childCount: _stickers.length,
                            ),
                          ),
                        ),

              // Botão de adicionar sticker (apenas para donos)
              if (widget.isOwner)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(r.s(16)),
                    child: ElevatedButton.icon(
                      onPressed: () => _openStickerCreator(pack),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Adicionar Figurinha'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, r.s(48)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.s(12)),
                        ),
                      ),
                    ),
                  ),
                ),

              SliverToBoxAdapter(child: SizedBox(height: r.s(32))),
            ],
          );
        },
      ),
    );
  }

  void _openStickerCreator(StickerPackModel pack) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StickerCreatorScreen(packId: widget.packId, packName: pack.name),
      ),
    );
    if (result == true) {
      await _loadStickers();
      ref.invalidate(myPacksProvider);
      ref.read(stickerPickerProvider.notifier).reload();
    }
  }

  void _openEditPack(StickerPackModel pack) async {
    // Abrir dialog de edição inline
    final nameCtrl = TextEditingController(text: pack.name);
    final descCtrl = TextEditingController(text: pack.description);
    final r = context.r;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Editar pack',
            style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nome',
                labelStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: r.s(12)),
            TextField(
              controller: descCtrl,
              style: TextStyle(color: context.textPrimary),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Descrição',
                labelStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Salvar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      await ref.read(packEditorProvider.notifier).updatePack(
        packId: widget.packId,
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
      );
      ref.invalidate(packDetailProvider(widget.packId));
      ref.invalidate(myPacksProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _togglePublic(StickerPackModel pack) async {
    try {
      await ref.read(packEditorProvider.notifier).updatePack(
        packId: widget.packId,
        isPublic: !pack.isPublic,
      );
      ref.invalidate(packDetailProvider(widget.packId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pack.isPublic ? 'Pack tornado privado' : 'Pack tornado público'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _StickerGridItem extends ConsumerWidget {
  final StickerModel sticker;
  final bool isOwner;
  final VoidCallback? onDelete;

  const _StickerGridItem({
    required this.sticker,
    this.isOwner = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final pickerState = ref.watch(stickerPickerProvider);
    final isFav = pickerState.isFavorite(sticker.id);

    return GestureDetector(
      onLongPress: () => _showStickerOptions(context, ref, isFav),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(r.s(12)),
              border: isFav
                  ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5), width: 1.5)
                  : null,
            ),
            child: sticker.imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(r.s(12)),
                    child: CachedNetworkImage(
                      imageUrl: sticker.imageUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.grey[600]),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      sticker.name.isNotEmpty ? sticker.name : '?',
                      style: TextStyle(fontSize: r.fs(12)),
                    ),
                  ),
          ),
          if (isFav)
            Positioned(
              top: r.s(2),
              right: r.s(2),
              child: Icon(Icons.favorite_rounded, size: r.s(12), color: AppTheme.primaryColor),
            ),
        ],
      ),
    );
  }

  void _showStickerOptions(BuildContext context, WidgetRef ref, bool isFav) {
    final r = context.r;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(r.s(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sticker.imageUrl.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: r.s(16)),
                child: CachedNetworkImage(
                  imageUrl: sticker.imageUrl,
                  height: r.s(80),
                  fit: BoxFit.contain,
                ),
              ),
            ListTile(
              leading: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? AppTheme.primaryColor : context.textPrimary,
              ),
              title: Text(
                isFav ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
                style: TextStyle(color: context.textPrimary),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(stickerPickerProvider.notifier).toggleFavorite(sticker);
              },
            ),
            if (isOwner && onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text('Remover sticker', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _StatChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final c = color ?? Colors.grey[500]!;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(8), vertical: r.s(4)),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(r.s(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: r.s(12), color: c),
          SizedBox(width: r.s(4)),
          Text(label, style: TextStyle(color: c, fontSize: r.fs(11), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
