import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/sticker_model.dart';
import '../providers/sticker_providers.dart';
import 'sticker_pack_screen.dart';
import 'create_pack_screen.dart';
import 'sticker_explore_screen.dart';
import '../../../config/nexus_theme_extension.dart';

/// Tela principal de stickers — gerencia packs próprios, salvos e descobre novos.
class StickerGalleryScreen extends ConsumerStatefulWidget {
  const StickerGalleryScreen({super.key});

  @override
  ConsumerState<StickerGalleryScreen> createState() => _StickerGalleryScreenState();
}

class _StickerGalleryScreenState extends ConsumerState<StickerGalleryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          'Figurinhas',
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(18),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.explore_rounded, color: context.nexusTheme.accentSecondary, size: r.s(22)),
            tooltip: 'Descobrir packs',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StickerExploreScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add_rounded, color: context.nexusTheme.accentPrimary, size: r.s(24)),
            tooltip: 'Criar pack',
            onPressed: () => _openCreatePack(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.nexusTheme.accentPrimary,
          labelColor: context.nexusTheme.accentPrimary,
          unselectedLabelColor: Colors.grey[500],
          labelStyle: TextStyle(fontSize: r.fs(13), fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Meus Packs'),
            Tab(text: 'Salvos'),
            Tab(text: 'Favoritos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyPacksTab(onCreatePack: _openCreatePack),
          const _SavedPacksTab(),
          const _FavoritesTab(),
        ],
      ),
    );
  }

  void _openCreatePack() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePackScreen()),
    );
    if (result == true) {
      ref.invalidate(myPacksProvider);
      ref.read(stickerPickerProvider.notifier).reload();
    }
  }
}

// ============================================================================
// ABA: MEUS PACKS
// ============================================================================
class _MyPacksTab extends ConsumerWidget {
  final VoidCallback onCreatePack;
  const _MyPacksTab({required this.onCreatePack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final packsAsync = ref.watch(myPacksProvider);

    return packsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: context.nexusTheme.accentPrimary, strokeWidth: 2),
      ),
      error: (e, _) => Center(
        child: Text('Erro ao carregar packs', style: TextStyle(color: Colors.grey[500])),
      ),
      data: (packs) {
        if (packs.isEmpty) {
          return _EmptyState(
            icon: Icons.collections_bookmark_rounded,
            title: 'Nenhum pack criado',
            subtitle: 'Crie seu primeiro pack de figurinhas personalizadas!',
            actionLabel: 'Criar Pack',
            onAction: onCreatePack,
          );
        }
        return RefreshIndicator(
          color: context.nexusTheme.accentPrimary,
          onRefresh: () async => ref.invalidate(myPacksProvider),
          child: GridView.builder(
            padding: EdgeInsets.all(r.s(16)),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: r.s(12),
              mainAxisSpacing: r.s(12),
              childAspectRatio: 0.85,
            ),
            itemCount: packs.length + 1,
            itemBuilder: (context, index) {
              if (index == packs.length) {
                return _CreatePackCard(onTap: onCreatePack);
              }
              return _PackCard(pack: packs[index], isOwner: true);
            },
          ),
        );
      },
    );
  }
}

// ============================================================================
// ABA: PACKS SALVOS
// ============================================================================
class _SavedPacksTab extends ConsumerWidget {
  const _SavedPacksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final packsAsync = ref.watch(savedPacksProvider);

    return packsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: context.nexusTheme.accentPrimary, strokeWidth: 2),
      ),
      error: (e, _) => Center(
        child: Text('Erro ao carregar packs', style: TextStyle(color: Colors.grey[500])),
      ),
      data: (packs) {
        if (packs.isEmpty) {
          return _EmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'Nenhum pack salvo',
            subtitle: 'Explore e salve packs de outros usuários!',
            actionLabel: 'Explorar',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StickerExploreScreen()),
            ),
          );
        }
        return RefreshIndicator(
          color: context.nexusTheme.accentPrimary,
          onRefresh: () async => ref.invalidate(savedPacksProvider),
          child: GridView.builder(
            padding: EdgeInsets.all(r.s(16)),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: r.s(12),
              mainAxisSpacing: r.s(12),
              childAspectRatio: 0.85,
            ),
            itemCount: packs.length,
            itemBuilder: (context, index) => _PackCard(pack: packs[index], isOwner: false),
          ),
        );
      },
    );
  }
}

// ============================================================================
// ABA: FAVORITOS
// ============================================================================
class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final favsAsync = ref.watch(favoritesProvider);

    return favsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: context.nexusTheme.accentPrimary, strokeWidth: 2),
      ),
      error: (e, _) => Center(
        child: Text('Erro ao carregar favoritos', style: TextStyle(color: Colors.grey[500])),
      ),
      data: (stickers) {
        if (stickers.isEmpty) {
          return _EmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'Nenhum favorito',
            subtitle: 'Segure qualquer figurinha para adicioná-la aos favoritos!',
          );
        }
        return RefreshIndicator(
          color: context.nexusTheme.accentPrimary,
          onRefresh: () async => ref.invalidate(favoritesProvider),
          child: GridView.builder(
            padding: EdgeInsets.all(r.s(16)),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: r.s(8),
              mainAxisSpacing: r.s(8),
            ),
            itemCount: stickers.length,
            itemBuilder: (context, index) {
              final sticker = stickers[index];
              return _StickerTile(
                sticker: sticker,
                isFavorite: true,
                onLongPress: () async {
                  await ref.read(stickerPickerProvider.notifier).toggleFavorite(sticker);
                  ref.invalidate(favoritesProvider);
                },
              );
            },
          ),
        );
      },
    );
  }
}

// ============================================================================
// WIDGETS AUXILIARES
// ============================================================================

class _PackCard extends ConsumerWidget {
  final StickerPackModel pack;
  final bool isOwner;

  const _PackCard({required this.pack, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StickerPackScreen(packId: pack.id, isOwner: isOwner),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.nexusTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover do pack
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(16))),
                child: pack.coverUrl != null && pack.coverUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: pack.coverUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _PackCoverPlaceholder(name: pack.name),
                      )
                    : _PackCoverPlaceholder(name: pack.name),
              ),
            ),
            // Info do pack
            Padding(
              padding: EdgeInsets.all(r.s(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pack.name,
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: r.s(4)),
                  Row(
                    children: [
                      Icon(Icons.collections_rounded, size: r.s(11), color: Colors.grey[500]),
                      SizedBox(width: r.s(3)),
                      Text(
                        '${pack.stickerCount}',
                        style: TextStyle(color: Colors.grey[500], fontSize: r.fs(11)),
                      ),
                      SizedBox(width: r.s(8)),
                      Icon(Icons.bookmark_rounded, size: r.s(11), color: Colors.grey[500]),
                      SizedBox(width: r.s(3)),
                      Text(
                        '${pack.savesCount}',
                        style: TextStyle(color: Colors.grey[500], fontSize: r.fs(11)),
                      ),
                      const Spacer(),
                      if (!pack.isPublic)
                        Icon(Icons.lock_rounded, size: r.s(12), color: Colors.grey[600]),
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

class _PackCoverPlaceholder extends StatelessWidget {
  final String name;
  const _PackCoverPlaceholder({required this.name});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      color: context.nexusTheme.accentPrimary.withValues(alpha: 0.1),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_emotions_rounded,
                size: r.s(40), color: context.nexusTheme.accentPrimary.withValues(alpha: 0.5)),
            SizedBox(height: r.s(4)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.s(8)),
              child: Text(
                name,
                style: TextStyle(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.7),
                  fontSize: r.fs(11),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePackCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CreatePackCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.nexusTheme.accentPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(
            color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: r.s(48),
              height: r.s(48),
              decoration: BoxDecoration(
                color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, color: context.nexusTheme.accentPrimary, size: r.s(28)),
            ),
            SizedBox(height: r.s(10)),
            Text(
              'Criar Pack',
              style: TextStyle(
                color: context.nexusTheme.accentPrimary,
                fontSize: r.fs(13),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickerTile extends StatelessWidget {
  final StickerModel sticker;
  final bool isFavorite;
  final VoidCallback? onLongPress;

  const _StickerTile({
    required this.sticker,
    this.isFavorite = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: context.nexusTheme.surfacePrimary,
              borderRadius: BorderRadius.circular(r.s(12)),
              border: isFavorite
                  ? Border.all(color: context.nexusTheme.accentPrimary.withValues(alpha: 0.5), width: 1.5)
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
                      sticker.name.isNotEmpty ? sticker.name[0] : '?',
                      style: TextStyle(fontSize: r.fs(24)),
                    ),
                  ),
          ),
          if (isFavorite)
            Positioned(
              top: r.s(2),
              right: r.s(2),
              child: Icon(Icons.favorite_rounded, size: r.s(12), color: context.nexusTheme.accentPrimary),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.s(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: r.s(56), color: Colors.grey[700]),
            SizedBox(height: r.s(16)),
            Text(
              title,
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.s(8)),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[500], fontSize: r.fs(13)),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: r.s(20)),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.nexusTheme.accentPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(12)),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: r.s(24),
                    vertical: r.s(12),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: r.fs(14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
