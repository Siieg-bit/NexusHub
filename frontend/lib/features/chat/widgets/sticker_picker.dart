import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Sticker Picker — carrega packs reais de stickers comprados na loja e
/// permite selecionar um sticker para envio no chat.
///
/// Retorna um Map com `{sticker_id, sticker_url, sticker_name, pack_id}`.
/// Emojis locais continuam sempre disponíveis.
class StickerPicker extends ConsumerStatefulWidget {
  final String? communityId;

  const StickerPicker({super.key, this.communityId});

  static Future<Map<String, String>?> show(
    BuildContext context, {
    String? communityId,
  }) {
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
  ConsumerState<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends ConsumerState<StickerPicker> {
  @override
  Widget build(BuildContext context) {
    return _StickerPickerBody(communityId: widget.communityId);
  }
}

class _StickerPickerBody extends ConsumerStatefulWidget {
  final String? communityId;
  final ScrollController? scrollController;

  const _StickerPickerBody({this.communityId, this.scrollController});

  @override
  ConsumerState<_StickerPickerBody> createState() => _StickerPickerBodyState();
}

class _StickerPickerBodyState extends ConsumerState<_StickerPickerBody>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<Map<String, dynamic>> _packs = [];
  final Map<String, List<Map<String, dynamic>>> _stickersByPack = {};
  bool _isLoading = true;

  List<Map<String, dynamic>> _favoriteStickers = [];
  Set<String> _favoriteStickerIds = {};
  List<Map<String, dynamic>> _recentStickers = [];

  static const _favTab = '❤️ Favoritos';
  static const _recentTab = '🕐 Recentes';
  static const _emojiTab = 'Emojis';

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

  void _rebuildTabController(List<Map<String, dynamic>> newPacks) {
    final oldController = _tabController;
    _tabController = TabController(length: newPacks.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController?.dispose();
    });
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

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

      _recentStickers = List<Map<String, dynamic>>.from(res as List? ?? []);
    } catch (e) {
      debugPrint('[sticker_picker] Erro ao carregar recentes: $e');
    }
  }

  Future<void> _addToRecentStickers(Map<String, dynamic> sticker) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final entry = _normalizeSticker(sticker);
      await SupabaseService.table('recently_used_stickers').upsert({
        'user_id': userId,
        'sticker_id': entry['sticker_id'],
        'sticker_url': entry['sticker_url'],
        'sticker_name': entry['sticker_name'],
        'used_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,sticker_id');
    } catch (e) {
      debugPrint('[sticker_picker] Erro ao adicionar recente: $e');
    }
  }

  Future<void> _loadFavoriteStickers() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final res = await SupabaseService.table('user_sticker_favorites')
          .select('sticker_id, sticker_url, sticker_name, pack_id')
          .eq('user_id', userId)
          .eq('category', 'favorite')
          .order('created_at', ascending: false);

      _favoriteStickers = List<Map<String, dynamic>>.from(res as List? ?? []);
      _favoriteStickerIds = _favoriteStickers
          .map((sticker) => _string(sticker['sticker_id']))
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (e) {
      debugPrint('[sticker_picker] Erro ao carregar favoritos: $e');
    }
  }

  Future<void> _loadStickerPacks() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        _packs = [
          {'name': _emojiTab, 'count': _defaultStickers.length},
        ];
        _rebuildTabController(_packs);
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Nota: filtro de join no PostgREST (.eq('store_items.type', ...)) não funciona
      // como filtro — retorna todas as compras com store_items null para as que não batem.
      // Por isso buscamos todas as compras e filtramos no Dart.
      final purchasedRes = await SupabaseService.table('user_purchases')
          .select(
            'item_id, store_items!user_purchases_item_id_fkey(id, type, name, asset_config, preview_url, asset_url)',
          )
          .eq('user_id', userId);

      final purchased = List<Map<String, dynamic>>.from(purchasedRes as List? ?? []);
      final ownedPackItems = <Map<String, dynamic>>[];
      final ownedPackIds = <String>{};

      for (final purchase in purchased) {
        final storeItem = _map(purchase['store_items']);
        if (_string(storeItem['type']) != 'sticker_pack') continue;

        final assetConfig = _map(storeItem['asset_config']);
        final packId = _firstNonEmpty([
          _string(assetConfig['pack_id']),
          _string(storeItem['pack_id']),
        ]);

        if (packId == null || packId.isEmpty || ownedPackIds.contains(packId)) {
          continue;
        }

        ownedPackIds.add(packId);
        ownedPackItems.add({...storeItem, 'resolved_pack_id': packId});
      }

      if (ownedPackIds.isNotEmpty) {
        final packsRes = await SupabaseService.table('sticker_packs')
            .select('id, name, cover_url, icon_url, sticker_count, is_active, sort_order')
            .inFilter('id', ownedPackIds.toList())
            .eq('is_active', true)
            .order('sort_order', ascending: true);

        final packRows = List<Map<String, dynamic>>.from(packsRes as List? ?? []);
        final packById = {
          for (final row in packRows) _string(row['id']): row,
        };

        final stickersRes = await SupabaseService.table('stickers')
            .select('id, pack_id, name, image_url, thumbnail_url, sort_order, is_animated')
            .inFilter('pack_id', ownedPackIds.toList())
            .order('sort_order', ascending: true);

        final stickerRows = List<Map<String, dynamic>>.from(stickersRes as List? ?? []);
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final sticker in stickerRows) {
          final normalized = _normalizeSticker(sticker);
          final packId = _string(normalized['pack_id']);
          if (packId.isEmpty) continue;
          grouped.putIfAbsent(packId, () => []).add(normalized);
        }

        final visiblePacks = <Map<String, dynamic>>[];
        for (final storeItem in ownedPackItems) {
          final packId = _string(storeItem['resolved_pack_id']);
          final pack = packById[packId];
          final stickers = grouped[packId] ?? const <Map<String, dynamic>>[];
          if (pack == null || stickers.isEmpty) continue;

          final packName = _string(pack['name'], fallback: _string(storeItem['name'], fallback: 'Pack'));
          visiblePacks.add({
            'id': packId,
            'name': packName,
            'count': stickers.length,
            'cover_url': _firstNonEmpty([
              _string(pack['cover_url']),
              _string(pack['icon_url']),
              _string(storeItem['preview_url']),
              _string(storeItem['asset_url']),
            ]),
          });
          _stickersByPack[packName] = stickers;
        }

        _packs = visiblePacks;
      } else {
        _packs = [];
      }
    } catch (e) {
      debugPrint('[sticker_picker] Erro ao carregar packs: $e');
      _packs = [];
    }

    _packs.insert(0, {'name': _emojiTab, 'count': _defaultStickers.length});

    if (_recentStickers.isNotEmpty) {
      _packs.insert(0, {'name': _recentTab, 'count': _recentStickers.length});
      _stickersByPack[_recentTab] = _recentStickers.map(_normalizeSticker).toList();
    }

    if (_favoriteStickers.isNotEmpty) {
      _packs.insert(0, {'name': _favTab, 'count': _favoriteStickers.length});
      _stickersByPack[_favTab] = _favoriteStickers.map(_normalizeSticker).toList();
    }

    _rebuildTabController(_packs);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> sticker) async {
    final s = ref.read(stringsProvider);

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final entry = _normalizeSticker(sticker);
      final stickerId = _string(entry['sticker_id']);
      if (stickerId.isEmpty) return;

      final isFav = _favoriteStickerIds.contains(stickerId);
      if (isFav) {
        await SupabaseService.table('user_sticker_favorites')
            .delete()
            .eq('user_id', userId)
            .eq('sticker_id', stickerId)
            .eq('category', 'favorite');

        if (mounted) {
          setState(() {
            _favoriteStickers.removeWhere(
              (item) => _string(item['sticker_id']) == stickerId,
            );
            _favoriteStickerIds.remove(stickerId);
            _stickersByPack[_favTab] = List.from(_favoriteStickers);

            if (_favoriteStickers.isEmpty) {
              _packs.removeWhere((pack) => pack['name'] == _favTab);
              _rebuildTabController(_packs);
            } else {
              final idx = _packs.indexWhere((pack) => pack['name'] == _favTab);
              if (idx >= 0) {
                _packs[idx] = {
                  'name': _favTab,
                  'count': _favoriteStickers.length,
                };
              }
            }
          });
        }
      } else {
        await SupabaseService.table('user_sticker_favorites').insert({
          'user_id': userId,
          'sticker_id': stickerId,
          'sticker_url': _string(entry['sticker_url']),
          'sticker_name': _string(entry['sticker_name']),
          'pack_id': _string(entry['pack_id']),
          'category': 'favorite',
        });

        if (mounted) {
          setState(() {
            _favoriteStickers.insert(0, entry);
            _favoriteStickerIds.add(stickerId);
            _stickersByPack[_favTab] = List.from(_favoriteStickers);

            final hasFavTab = _packs.any((pack) => pack['name'] == _favTab);
            if (!hasFavTab) {
              _packs.insert(0, {
                'name': _favTab,
                'count': _favoriteStickers.length,
              });
              _rebuildTabController(_packs);
            } else {
              final idx = _packs.indexWhere((pack) => pack['name'] == _favTab);
              if (idx >= 0) {
                _packs[idx] = {
                  'name': _favTab,
                  'count': _favoriteStickers.length,
                };
              }
            }
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFav ? 'Removido dos favoritos' : s.addedToFavorites),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('[sticker_picker] Erro ao favoritar: $e');
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final controller = _tabController;

    return Container(
      decoration: BoxDecoration(
        color: context.nexusTheme.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(16))),
      ),
      child: _isLoading || controller == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Center(
                  child: Container(
                    margin: EdgeInsets.only(top: r.s(8)),
                    width: r.s(40),
                    height: r.s(4),
                    decoration: BoxDecoration(
                      color: context.nexusTheme.textHint,
                      borderRadius: BorderRadius.circular(r.s(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(r.s(12)),
                  child: Row(
                    children: [
                      Text(
                        s.stickersLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: r.fs(18),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        s.holdToFavorite,
                        style: TextStyle(
                          fontSize: r.fs(11),
                          color: context.nexusTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: controller,
                  isScrollable: true,
                  labelColor: context.nexusTheme.accentPrimary,
                  unselectedLabelColor: context.nexusTheme.textSecondary,
                  indicatorColor: context.nexusTheme.accentPrimary,
                  tabs: _packs
                      .map((pack) => Tab(text: _string(pack['name'])))
                      .toList(),
                ),
                Expanded(
                  child: TabBarView(
                    controller: controller,
                    children: _packs.map((pack) {
                      final packName = _string(pack['name']);
                      if (packName == _emojiTab) {
                        return _buildEmojiGrid();
                      }
                      return _buildStickerGrid(
                        _stickersByPack[packName] ?? const [],
                        isFavTab: packName == _favTab,
                        emptyMessage: packName == _recentTab
                            ? 'Nenhum sticker recente ainda.'
                            : 'Nenhum sticker disponível neste pack.',
                      );
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
            'sticker_name': sticker['label']!,
            'pack_id': '',
            'emoji': sticker['emoji']!,
          }),
          onLongPress: () => _toggleFavorite({
            'id': sticker['id'],
            'sticker_url': '',
            'name': sticker['label'],
            'pack_id': '',
          }),
          child: Container(
            decoration: BoxDecoration(
              color: context.nexusTheme.surfacePrimary,
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Center(
              child: Text(
                sticker['emoji']!,
                style: TextStyle(fontSize: r.fs(32)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStickerGrid(
    List<Map<String, dynamic>> stickers, {
    bool isFavTab = false,
    required String emptyMessage,
  }) {
    final r = context.r;

    if (stickers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFavTab ? Icons.favorite_border_rounded : Icons.emoji_emotions_outlined,
              size: r.s(40),
              color: Colors.grey[600],
            ),
            SizedBox(height: r.s(8)),
            Text(
              isFavTab
                  ? 'Nenhum favorito ainda.\nSegure um sticker para favoritar.'
                  : emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.nexusTheme.textSecondary),
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
        final sticker = _normalizeSticker(stickers[index]);
        final imageUrl = _string(sticker['sticker_url']);
        final stickerId = _string(sticker['sticker_id']);
        final isFav = _favoriteStickerIds.contains(stickerId);

        return GestureDetector(
          onTap: () {
            _addToRecentStickers(sticker);
            Navigator.pop(context, {
              'sticker_id': stickerId,
              'sticker_url': imageUrl,
              'sticker_name': _string(sticker['sticker_name']),
              'pack_id': _string(sticker['pack_id']),
            });
          },
          onLongPress: () => _toggleFavorite(sticker),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: context.nexusTheme.surfacePrimary,
                  borderRadius: BorderRadius.circular(r.s(12)),
                  border: isFav
                      ? Border.all(
                          color: context.nexusTheme.accentPrimary.withValues(alpha: 0.6),
                          width: 1.5,
                        )
                      : null,
                ),
                child: imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(r.s(12)),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          _string(sticker['sticker_name'], fallback: '?'),
                          style: TextStyle(fontSize: r.fs(12)),
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
              if (isFav)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(
                    Icons.favorite_rounded,
                    size: r.s(12),
                    color: context.nexusTheme.accentPrimary,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic> _normalizeSticker(Map<String, dynamic> sticker) {
    return {
      'sticker_id': _firstNonEmpty([
            _string(sticker['sticker_id']),
            _string(sticker['id']),
          ]) ??
          '',
      'sticker_url': _firstNonEmpty([
            _string(sticker['sticker_url']),
            _string(sticker['image_url']),
            _string(sticker['thumbnail_url']),
          ]) ??
          '',
      'sticker_name': _firstNonEmpty([
            _string(sticker['sticker_name']),
            _string(sticker['name']),
            _string(sticker['label']),
          ]) ??
          '',
      'pack_id': _firstNonEmpty([
            _string(sticker['pack_id']),
          ]) ??
          '',
    };
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _string(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return null;
}
