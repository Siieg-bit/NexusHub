import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Sticker Picker — carrega sticker packs da store e permite seleção.
/// Retorna um Map com {sticker_id, sticker_url} via Navigator.pop().
/// Long-press em qualquer sticker adiciona/remove dos favoritos.
class StickerPicker extends StatefulWidget {
  final String? communityId;
  const StickerPicker({super.key, this.communityId});

  /// Abre o picker como bottom sheet.
  static Future<Map<String, String>?> show(BuildContext context,
      {String? communityId}) {
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (ctx, scrollController) => _StickerPickerBody(
          communityId: communityId,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  State<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<StickerPicker> {
  @override
  Widget build(BuildContext context) {
    return _StickerPickerBody(communityId: widget.communityId);
  }
}

class _StickerPickerBody extends StatefulWidget {
  final String? communityId;
  final ScrollController? scrollController;
  const _StickerPickerBody({this.communityId, this.scrollController});

  @override
  State<_StickerPickerBody> createState() => _StickerPickerBodyState();
}

class _StickerPickerBodyState extends State<_StickerPickerBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _packs = [];
  Map<String, List<Map<String, dynamic>>> _stickersByPack = {};
  bool _isLoading = true;
  List<Map<String, dynamic>> _favoriteStickers = [];
  Set<String> _favoriteStickerIds = {};
  List<Map<String, dynamic>> _recentStickers = [];

  static const _favTab = '❤️ Favoritos';
  static const _recentTab = '🕐 Recentes';

  // Default emoji stickers (always available)
  static const _defaultStickers = [
    {'id': 'emoji_1', 'emoji': '😀', 'label': 'Grinning'},
    {'id': 'emoji_2', 'emoji': '😂', 'label': 'Joy'},
    {'id': 'emoji_3', 'emoji': '😍', 'label': 'Heart Eyes'},
    {'id': 'emoji_4', 'emoji': '🤔', 'label': 'Thinking'},
    {'id': 'emoji_5', 'emoji': '😎', 'label': 'Cool'},
    {'id': 'emoji_6', 'emoji': '😢', 'label': 'Crying'},
    {'id': 'emoji_7', 'emoji': '😡', 'label': 'Angry'},
    {'id': 'emoji_8', 'emoji': '🥺', 'label': 'Pleading'},
    {'id': 'emoji_9', 'emoji': '🤩', 'label': 'Star-Struck'},
    {'id': 'emoji_10', 'emoji': '🥰', 'label': 'Smiling Hearts'},
    {'id': 'emoji_11', 'emoji': '😴', 'label': 'Sleeping'},
    {'id': 'emoji_12', 'emoji': '🤗', 'label': 'Hugging'},
    {'id': 'emoji_13', 'emoji': '👋', 'label': 'Waving'},
    {'id': 'emoji_14', 'emoji': '👍', 'label': 'Thumbs Up'},
    {'id': 'emoji_15', 'emoji': '❤️', 'label': 'Heart'},
    {'id': 'emoji_16', 'emoji': '🔥', 'label': 'Fire'},
    {'id': 'emoji_17', 'emoji': '⭐', 'label': 'Star'},
    {'id': 'emoji_18', 'emoji': '🎉', 'label': 'Party'},
    {'id': 'emoji_19', 'emoji': '💀', 'label': 'Skull'},
    {'id': 'emoji_20', 'emoji': '🙏', 'label': 'Pray'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadFavoriteStickers();
    await _loadRecentStickers();
    await _loadStickerPacks();
  }

  Future<void> _loadRecentStickers() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final res = await SupabaseService.table('recently_used_stickers')
          .select('sticker_id, sticker_url, sticker_name')
          .eq('user_id', userId)
          .order('used_at', ascending: false)
          .limit(20);
      _recentStickers = List<Map<String, dynamic>>.from(res as List);
    } catch (_) {}
  }

  Future<void> _addToRecentStickers(Map<String, dynamic> sticker) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final stickerId = sticker['sticker_id'] as String? ?? sticker['id'] as String? ?? '';
      final stickerUrl = sticker['sticker_url'] as String? ?? sticker['image_url'] as String? ?? '';
      final stickerName = sticker['sticker_name'] as String? ?? sticker['name'] as String? ?? '';
      await SupabaseService.table('recently_used_stickers').upsert({
        'user_id': userId,
        'sticker_id': stickerId,
        'sticker_url': stickerUrl,
        'sticker_name': stickerName,
        'used_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,sticker_id');
    } catch (_) {}
  }

  Future<void> _loadFavoriteStickers() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final res = await SupabaseService.table('favorite_stickers')
          .select('sticker_id, sticker_url, sticker_name')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      _favoriteStickers = List<Map<String, dynamic>>.from(res as List);
      _favoriteStickerIds = _favoriteStickers
          .map((s) => s['sticker_id'] as String)
          .toSet();
    } catch (_) {}
  }

  Future<void> _loadStickerPacks() async {
    try {
      final res = await SupabaseService.table('store_items')
          .select()
          .eq('type', 'sticker')
          .eq('is_active', true)
          .order('name');
      final items = List<Map<String, dynamic>>.from(res as List);

      final packs = <String, List<Map<String, dynamic>>>{};
      for (final item in items) {
        final pack = item['category'] as String? ?? 'Geral';
        packs.putIfAbsent(pack, () => []);
        packs[pack]!.add(item);
      }

      _packs = packs.keys
          .map((k) => {'name': k, 'count': packs[k]!.length})
          .toList();
      _stickersByPack = packs;
    } catch (_) {}

    // Aba Emojis padrão
    _packs.insert(0, {'name': 'Emojis', 'count': _defaultStickers.length});

    // Aba Recentes (se houver)
    if (_recentStickers.isNotEmpty) {
      _packs.insert(0, {'name': _recentTab, 'count': _recentStickers.length});
      _stickersByPack[_recentTab] = _recentStickers;
    }

    // Aba Favoritos no início (se houver)
    if (_favoriteStickers.isNotEmpty) {
      _packs.insert(0, {'name': _favTab, 'count': _favoriteStickers.length});
      _stickersByPack[_favTab] = _favoriteStickers;
    }

    _tabController = TabController(length: _packs.length, vsync: this);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleFavorite(Map<String, dynamic> sticker) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final stickerId = sticker['sticker_id'] as String? ??
          sticker['id'] as String? ?? '';
      final isFav = _favoriteStickerIds.contains(stickerId);

      if (isFav) {
        await SupabaseService.table('favorite_stickers')
            .delete()
            .eq('user_id', userId)
            .eq('sticker_id', stickerId);
        if (mounted) {
          setState(() {
            _favoriteStickers.removeWhere((s) => s['sticker_id'] == stickerId);
            _favoriteStickerIds.remove(stickerId);
            _stickersByPack[_favTab] = _favoriteStickers;
          });
        }
      } else {
        final entry = {
          'user_id': userId,
          'sticker_id': stickerId,
          'sticker_url': sticker['sticker_url'] as String? ??
              sticker['image_url'] as String? ?? '',
          'sticker_name': sticker['name'] as String? ?? '',
        };
        await SupabaseService.table('favorite_stickers').insert(entry);
        if (mounted) {
          setState(() {
            _favoriteStickers.insert(0, {
              'sticker_id': stickerId,
              'sticker_url': entry['sticker_url'],
              'sticker_name': entry['sticker_name'],
            });
            _favoriteStickerIds.add(stickerId);
            _stickersByPack[_favTab] = _favoriteStickers;
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isFav ? 'Removido dos favoritos' : 'Adicionado aos favoritos'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: context.scaffoldBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: EdgeInsets.only(top: r.s(8)),
                    width: r.s(40),
                    height: r.s(4),
                    decoration: BoxDecoration(
                      color: context.textHint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: EdgeInsets.all(r.s(12)),
                  child: Row(
                    children: [
                      Text('Figurinhas',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: r.fs(18))),
                      const Spacer(),
                      Text('Segure para favoritar',
                          style: TextStyle(
                              fontSize: r.fs(11),
                              color: context.textSecondary)),
                    ],
                  ),
                ),
                // Tab bar for packs
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: context.textSecondary,
                  indicatorColor: AppTheme.primaryColor,
                  tabs: _packs
                      .map((p) => Tab(text: p['name'] as String))
                      .toList(),
                ),
                // Sticker grid
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _packs.map((pack) {
                      final packName = pack['name'] as String;
                      if (packName == 'Emojis') {
                        return _buildEmojiGrid();
                      }
                      return _buildStickerGrid(
                          _stickersByPack[packName] ?? [],
                          isFavTab: packName == _favTab);
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmojiGrid() {
    final r = context.r;
    return GridView.builder(
      controller: widget.scrollController,
      padding: EdgeInsets.all(r.s(12)),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _defaultStickers.length,
      itemBuilder: (context, index) {
        final sticker = _defaultStickers[index];
        return GestureDetector(
          onTap: () => Navigator.pop(context, {
            'sticker_id': sticker['id']!,
            'sticker_url': '',
            'emoji': sticker['emoji']!,
          }),
          onLongPress: () => _toggleFavorite({
            'id': sticker['id'],
            'sticker_url': '',
            'name': sticker['label'],
          }),
          child: Container(
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Center(
              child: Text(sticker['emoji']!,
                  style: TextStyle(fontSize: r.fs(32))),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStickerGrid(List<Map<String, dynamic>> stickers,
      {bool isFavTab = false}) {
    final r = context.r;
    if (stickers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded,
                size: r.s(40), color: Colors.grey[600]),
            SizedBox(height: r.s(8)),
            Text(
              isFavTab
                  ? 'Nenhum favorito ainda.\nSegure um sticker para favoritar!'
                  : 'Nenhum sticker neste pack',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      controller: widget.scrollController,
      padding: EdgeInsets.all(r.s(12)),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];
        final imageUrl = sticker['image_url'] as String? ??
            sticker['sticker_url'] as String? ?? '';
        final stickerId = sticker['id'] as String? ??
            sticker['sticker_id'] as String? ?? '';
        final isFav = _favoriteStickerIds.contains(stickerId);
        return GestureDetector(
          onTap: () {
            _addToRecentStickers(sticker);
            Navigator.pop(context, {
              'sticker_id': stickerId,
              'sticker_url': imageUrl,
            });
          },
          onLongPress: () => _toggleFavorite(sticker),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(r.s(12)),
                  border: isFav
                      ? Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.6),
                          width: 1.5)
                      : null,
                ),
                child: imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(r.s(12)),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_rounded)),
                        ),
                      )
                    : Center(
                        child: Text(sticker['name'] as String? ?? '?',
                            style: TextStyle(fontSize: r.fs(12))),
                      ),
              ),
              if (isFav)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(Icons.favorite_rounded,
                      size: r.s(12), color: AppTheme.primaryColor),
                ),
            ],
          ),
        );
      },
    );
  }
}
