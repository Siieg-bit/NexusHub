import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/sticker_model.dart';
import '../providers/sticker_providers.dart';
import '../screens/sticker_gallery_screen.dart';
import '../screens/sticker_explore_screen.dart';
import '../screens/create_pack_screen.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Callback quando um sticker é selecionado.
typedef OnStickerSelected = void Function(StickerModel sticker);

/// Picker de stickers renovado — bottom sheet com abas completas.
/// Exibe: Recentes, Favoritos, Meus Packs, Packs Salvos, Packs da Loja.
class StickerPickerV2 extends ConsumerStatefulWidget {
  final OnStickerSelected onStickerSelected;

  const StickerPickerV2({
    super.key,
    required this.onStickerSelected,
  });

  /// Abre o picker como bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required OnStickerSelected onStickerSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: StickerPickerV2(onStickerSelected: onStickerSelected),
      ),
    );
  }

  @override
  ConsumerState<StickerPickerV2> createState() => _StickerPickerV2State();
}

class _StickerPickerV2State extends ConsumerState<StickerPickerV2>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onStickerTap(StickerModel sticker) {
    // Registrar uso
    ref.read(stickerPickerProvider.notifier).trackUsed(sticker);
    // Fechar picker e retornar sticker
    Navigator.pop(context);
    widget.onStickerSelected(sticker);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final pickerState = ref.watch(stickerPickerProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(24))),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: EdgeInsets.only(top: r.s(10), bottom: r.s(4)),
              width: r.s(36),
              height: r.s(4),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(r.s(2)),
              ),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
            child: Row(
              children: [
                if (_isSearching) ...[
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
                      decoration: InputDecoration(
                        hintText: 'Buscar figurinhas...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: context.nexusTheme.surfacePrimary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.s(10)),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: r.s(12),
                          vertical: r.s(8),
                        ),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[600], size: r.s(18)),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  SizedBox(width: r.s(8)),
                  GestureDetector(
                    onTap: () => setState(() {
                      _isSearching = false;
                      _searchQuery = '';
                      _searchCtrl.clear();
                    }),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: context.nexusTheme.accentPrimary, fontSize: r.fs(13)),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Figurinhas',
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontSize: r.fs(16),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  // Botão de busca
                  IconButton(
                    icon: Icon(Icons.search_rounded, color: Colors.grey[500], size: r.s(20)),
                    onPressed: () => setState(() => _isSearching = true),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: r.s(32), minHeight: r.s(32)),
                  ),
                  // Botão explorar
                  IconButton(
                    icon: Icon(Icons.explore_rounded, color: Colors.grey[500], size: r.s(20)),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StickerExploreScreen()),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: r.s(32), minHeight: r.s(32)),
                  ),
                  // Botão gerenciar
                  IconButton(
                    icon: Icon(Icons.settings_rounded, color: Colors.grey[500], size: r.s(20)),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StickerGalleryScreen()),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: r.s(32), minHeight: r.s(32)),
                  ),
                ],
              ],
            ),
          ),

          // Conteúdo de busca ou abas normais
          if (_isSearching && _searchQuery.isNotEmpty)
            Expanded(child: _SearchResults(
              query: _searchQuery,
              pickerState: pickerState,
              onStickerTap: _onStickerTap,
            ))
          else ...[
            // Tabs
            _buildTabBar(r),
            Expanded(
              child: pickerState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: context.nexusTheme.accentPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Aba Recentes
                        _RecentsTab(
                          stickers: pickerState.recents,
                          onStickerTap: _onStickerTap,
                          favorites: pickerState.favorites,
                        ),
                        // Aba Favoritos
                        _FavoritesTab(
                          stickers: pickerState.favorites,
                          onStickerTap: _onStickerTap,
                        ),
                        // Aba Meus Packs
                        _PacksTab(
                          packs: pickerState.myPacks,
                          onStickerTap: _onStickerTap,
                          favorites: pickerState.favorites,
                          emptyTitle: 'Nenhum pack criado',
                          emptySubtitle: 'Crie seu primeiro pack!',
                          onEmptyAction: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CreatePackScreen()),
                            );
                          },
                          emptyActionLabel: 'Criar Pack',
                        ),
                        // Aba Packs Salvos
                        _PacksTab(
                          packs: pickerState.savedPacks,
                          onStickerTap: _onStickerTap,
                          favorites: pickerState.favorites,
                          emptyTitle: 'Nenhum pack salvo',
                          emptySubtitle: 'Explore e salve packs de outros usuários!',
                          onEmptyAction: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const StickerExploreScreen()),
                            );
                          },
                          emptyActionLabel: 'Explorar',
                        ),
                        // Aba Loja
                        _PacksTab(
                          packs: pickerState.storePacks,
                          onStickerTap: _onStickerTap,
                          favorites: pickerState.favorites,
                          emptyTitle: 'Nenhum pack na loja',
                          emptySubtitle: 'Em breve novos packs!',
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar(Responsive r) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(16)),
      height: r.s(40),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: context.nexusTheme.accentPrimary,
        labelColor: context.nexusTheme.accentPrimary,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: TextStyle(fontSize: r.fs(12), fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: r.fs(12)),
        indicatorSize: TabBarIndicatorSize.label,
        tabs: const [
          Tab(text: 'Recentes'),
          Tab(text: 'Favoritos'),
          Tab(text: 'Meus'),
          Tab(text: 'Salvos'),
          Tab(text: 'Loja'),
        ],
      ),
    );
  }
}

// ============================================================================
// ABA RECENTES
// ============================================================================
class _RecentsTab extends ConsumerWidget {
  final List<StickerModel> stickers;
  final List<StickerModel> favorites;
  final void Function(StickerModel) onStickerTap;

  const _RecentsTab({
    required this.stickers,
    required this.favorites,
    required this.onStickerTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;

    if (stickers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: r.s(40), color: Colors.grey[700]),
            SizedBox(height: r.s(8)),
            Text(
              'Nenhuma figurinha usada recentemente',
              style: TextStyle(color: Colors.grey[600], fontSize: r.fs(13)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(r.s(12)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: r.s(6),
        mainAxisSpacing: r.s(6),
      ),
      itemCount: stickers.length,
      itemBuilder: (_, i) {
        final s = stickers[i];
        final isFav = favorites.any((f) => f.id == s.id);
        return _StickerCell(
          sticker: s,
          isFavorite: isFav,
          onTap: () => onStickerTap(s),
          onLongPress: () => _showOptions(context, ref, s, isFav),
        );
      },
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref, StickerModel s, bool isFav) {
    _showStickerOptions(context, ref, s, isFav);
  }
}

// ============================================================================
// ABA FAVORITOS
// ============================================================================
class _FavoritesTab extends ConsumerWidget {
  final List<StickerModel> stickers;
  final void Function(StickerModel) onStickerTap;

  const _FavoritesTab({required this.stickers, required this.onStickerTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;

    if (stickers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded, size: r.s(40), color: Colors.grey[700]),
            SizedBox(height: r.s(8)),
            Text(
              'Segure uma figurinha para favoritar',
              style: TextStyle(color: Colors.grey[600], fontSize: r.fs(13)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(r.s(12)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: r.s(6),
        mainAxisSpacing: r.s(6),
      ),
      itemCount: stickers.length,
      itemBuilder: (_, i) {
        final s = stickers[i];
        return _StickerCell(
          sticker: s,
          isFavorite: true,
          onTap: () => onStickerTap(s),
          onLongPress: () => _showStickerOptions(context, ref, s, true),
        );
      },
    );
  }
}

// ============================================================================
// ABA DE PACKS (genérica)
// ============================================================================
class _PacksTab extends ConsumerStatefulWidget {
  final List<StickerPackModel> packs;
  final List<StickerModel> favorites;
  final void Function(StickerModel) onStickerTap;
  final String emptyTitle;
  final String emptySubtitle;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  const _PacksTab({
    required this.packs,
    required this.favorites,
    required this.onStickerTap,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  @override
  ConsumerState<_PacksTab> createState() => _PacksTabState();
}

class _PacksTabState extends ConsumerState<_PacksTab> {
  String? _selectedPackId;

  @override
  void initState() {
    super.initState();
    if (widget.packs.isNotEmpty) {
      _selectedPackId = widget.packs.first.id;
    }
  }

  @override
  void didUpdateWidget(_PacksTab old) {
    super.didUpdateWidget(old);
    if (widget.packs.isNotEmpty && _selectedPackId == null) {
      _selectedPackId = widget.packs.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    if (widget.packs.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(r.s(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_emotions_outlined, size: r.s(40), color: Colors.grey[700]),
              SizedBox(height: r.s(8)),
              Text(
                widget.emptyTitle,
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(14),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: r.s(4)),
              Text(
                widget.emptySubtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: r.fs(12)),
                textAlign: TextAlign.center,
              ),
              if (widget.emptyActionLabel != null && widget.onEmptyAction != null) ...[
                SizedBox(height: r.s(16)),
                ElevatedButton(
                  onPressed: widget.onEmptyAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.nexusTheme.accentPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(10)),
                    ),
                  ),
                  child: Text(widget.emptyActionLabel!),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Seletor de pack (horizontal)
        SizedBox(
          height: r.s(72),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
            itemCount: widget.packs.length,
            itemBuilder: (_, i) {
              final pack = widget.packs[i];
              final isSelected = pack.id == _selectedPackId;
              return GestureDetector(
                onTap: () => setState(() => _selectedPackId = pack.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(right: r.s(8)),
                  padding: EdgeInsets.symmetric(
                    horizontal: r.s(12),
                    vertical: r.s(4),
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.nexusTheme.accentPrimary.withValues(alpha: 0.15)
                        : context.nexusTheme.surfacePrimary,
                    borderRadius: BorderRadius.circular(r.s(20)),
                    border: Border.all(
                      color: isSelected
                          ? context.nexusTheme.accentPrimary
                          : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pack.coverUrl != null && pack.coverUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(r.s(4)),
                          child: CachedNetworkImage(
                            imageUrl: pack.coverUrl!,
                            width: r.s(20),
                            height: r.s(20),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.emoji_emotions_rounded,
                              size: r.s(20),
                              color: isSelected ? context.nexusTheme.accentPrimary : Colors.grey[600],
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.emoji_emotions_rounded,
                          size: r.s(20),
                          color: isSelected ? context.nexusTheme.accentPrimary : Colors.grey[600],
                        ),
                      SizedBox(width: r.s(6)),
                      Text(
                        pack.name,
                        style: TextStyle(
                          color: isSelected ? context.nexusTheme.accentPrimary : Colors.grey[500],
                          fontSize: r.fs(12),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),

        // Grid de stickers do pack selecionado
        Expanded(
          child: _selectedPackId == null
              ? const SizedBox.shrink()
              : _PackStickerGrid(
                  packId: _selectedPackId!,
                  favorites: widget.favorites,
                  onStickerTap: widget.onStickerTap,
                ),
        ),
      ],
    );
  }
}

class _PackStickerGrid extends ConsumerWidget {
  final String packId;
  final List<StickerModel> favorites;
  final void Function(StickerModel) onStickerTap;

  const _PackStickerGrid({
    required this.packId,
    required this.favorites,
    required this.onStickerTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final stickersAsync = ref.watch(packStickersProvider(packId));

    return stickersAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: context.nexusTheme.accentPrimary, strokeWidth: 2),
      ),
      error: (e, _) => Center(
        child: Text('Erro ao carregar', style: TextStyle(color: Colors.grey[600])),
      ),
      data: (stickers) {
        if (stickers.isEmpty) {
          return Center(
            child: Text(
              'Nenhuma figurinha neste pack',
              style: TextStyle(color: Colors.grey[600], fontSize: r.fs(13)),
            ),
          );
        }
        return GridView.builder(
          padding: EdgeInsets.all(r.s(12)),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: r.s(6),
            mainAxisSpacing: r.s(6),
          ),
          itemCount: stickers.length,
          itemBuilder: (_, i) {
            final s = stickers[i];
            final isFav = favorites.any((f) => f.id == s.id);
            return _StickerCell(
              sticker: s,
              isFavorite: isFav,
              onTap: () => onStickerTap(s),
              onLongPress: () => _showStickerOptions(context, ref, s, isFav),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// BUSCA
// ============================================================================
class _SearchResults extends StatelessWidget {
  final String query;
  final StickerPickerState pickerState;
  final void Function(StickerModel) onStickerTap;

  const _SearchResults({
    required this.query,
    required this.pickerState,
    required this.onStickerTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final lq = query.toLowerCase();

    // Buscar em todos os stickers disponíveis
    final allStickers = <StickerModel>[];
    for (final pack in [...pickerState.myPacks, ...pickerState.savedPacks, ...pickerState.storePacks]) {
      allStickers.addAll(pack.stickers.where((s) =>
        s.name.toLowerCase().contains(lq) ||
        s.tags.any((t) => t.toLowerCase().contains(lq))
      ));
    }
    // Adicionar favoritos que batem
    for (final s in pickerState.favorites) {
      if (s.name.toLowerCase().contains(lq) && !allStickers.any((a) => a.id == s.id)) {
        allStickers.add(s);
      }
    }

    if (allStickers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: r.s(40), color: Colors.grey[700]),
            SizedBox(height: r.s(8)),
            Text(
              'Nenhuma figurinha encontrada',
              style: TextStyle(color: Colors.grey[600], fontSize: r.fs(13)),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(r.s(12)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: r.s(6),
        mainAxisSpacing: r.s(6),
      ),
      itemCount: allStickers.length,
      itemBuilder: (_, i) {
        final s = allStickers[i];
        final isFav = pickerState.favorites.any((f) => f.id == s.id);
        return Consumer(
          builder: (ctx, ref, _) => _StickerCell(
            sticker: s,
            isFavorite: isFav,
            onTap: () => onStickerTap(s),
            onLongPress: () => _showStickerOptions(ctx, ref, s, isFav),
          ),
        );
      },
    );
  }
}

// ============================================================================
// CÉLULA DE STICKER
// ============================================================================
class _StickerCell extends StatelessWidget {
  final StickerModel sticker;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _StickerCell({
    required this.sticker,
    this.isFavorite = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: context.nexusTheme.surfacePrimary,
              borderRadius: BorderRadius.circular(r.s(10)),
              border: isFavorite
                  ? Border.all(
                      color: context.nexusTheme.accentPrimary.withValues(alpha: 0.5),
                      width: 1.5,
                    )
                  : null,
            ),
            child: sticker.imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(r.s(10)),
                    child: CachedNetworkImage(
                      imageUrl: sticker.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => Container(
                        color: Colors.grey[900],
                        child: Center(
                          child: SizedBox(
                            width: r.s(16),
                            height: r.s(16),
                            child: const CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: context.nexusTheme.accentPrimary,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: Colors.grey[700],
                          size: r.s(20),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      sticker.name.isNotEmpty ? sticker.name : '?',
                      style: TextStyle(fontSize: r.fs(10)),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
          if (isFavorite)
            Positioned(
              top: r.s(1),
              right: r.s(1),
              child: Icon(
                Icons.favorite_rounded,
                size: r.s(10),
                color: context.nexusTheme.accentPrimary,
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// BOTTOM SHEET DE OPÇÕES DO STICKER
// ============================================================================
void _showStickerOptions(
  BuildContext context,
  WidgetRef ref,
  StickerModel sticker,
  bool isFav,
) {
  final r = context.r;
  showModalBottomSheet(
    context: context,
    backgroundColor: context.surfaceColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Preview do sticker
          if (sticker.imageUrl.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: r.s(12)),
              child: CachedNetworkImage(
                imageUrl: sticker.imageUrl,
                height: r.s(80),
                fit: BoxFit.contain,
              ),
            ),
          if (sticker.name.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: r.s(12)),
              child: Text(
                sticker.name,
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(14),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Divider(color: Colors.white.withValues(alpha: 0.05)),
          // Favoritar
          ListTile(
            leading: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? context.nexusTheme.accentPrimary : context.nexusTheme.textPrimary,
              size: r.s(20),
            ),
            title: Text(
              isFav ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
              style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
            ),
            onTap: () async {
              Navigator.pop(ctx);
              await ref.read(stickerPickerProvider.notifier).toggleFavorite(sticker);
            },
          ),
        ],
      ),
    ),
  );
}
