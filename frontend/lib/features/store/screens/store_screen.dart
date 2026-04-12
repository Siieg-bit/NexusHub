import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/providers/cosmetics_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../stickers/providers/sticker_providers.dart';
import '../../chat/widgets/nine_slice_bubble.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

/// Tela Store — Loja de itens virtuais (Avatar Frames, Chat Bubbles, Sticker Packs).
///
/// Esta implementação usa o schema real do backend:
/// - `store_items.price_coins`
/// - `store_items.preview_url` / `store_items.asset_url`
/// - `store_items.is_limited_edition`
/// - `user_purchases.is_equipped`
///
/// Também respeita estados reais de posse/equipar para itens cosméticos globais.
class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<Map<String, dynamic>> _items = [];
  final Map<String, Map<String, dynamic>> _purchasesByItemId = {};
  final Set<String> _busyItemIds = <String>{};

  bool _isLoading = true;
  int _userCoins = 0;

  final List<String> _tabs = const [
    'Todos',
    'Frames',
    'Bubbles',
    'Stickers',
  ];

  final List<IconData> _tabIcons = const [
    Icons.storefront_rounded,
    Icons.face_rounded,
    Icons.chat_bubble_rounded,
    Icons.emoji_emotions_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadStore();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStore() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final profileFuture = SupabaseService.table('profiles')
          .select('coins')
          .eq('id', userId)
          .maybeSingle();

      final itemsFuture = SupabaseService.table('store_items')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final purchasesFuture = SupabaseService.table('user_purchases')
          .select(
            'id, item_id, is_equipped, equipped_in_community, purchased_at, '
            'store_items!user_purchases_item_id_fkey(id, type, name)',
          )
          .eq('user_id', userId);

      final results = await Future.wait([
        profileFuture,
        itemsFuture,
        purchasesFuture,
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final items = List<Map<String, dynamic>>.from(results[1] as List? ?? []);
      final purchases =
          List<Map<String, dynamic>>.from(results[2] as List? ?? []);

      _items
        ..clear()
        ..addAll(items);

      _purchasesByItemId
        ..clear()
        ..addEntries(
          purchases
              .where((purchase) => _asString(purchase['item_id']).isNotEmpty)
              .map(
                (purchase) => MapEntry(
                  _asString(purchase['item_id']),
                  purchase,
                ),
              ),
        );

      _userCoins = _asInt(profile?['coins']);
    } catch (e) {
      debugPrint('[store_screen] Erro ao carregar loja: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _filterItems(int tabIndex) {
    // Filtra profile_background de todas as abas
    final visible = _items
        .where((item) => _asString(item['type']) != 'profile_background')
        .toList();

    if (tabIndex == 0) return visible;

    const types = [
      '',
      'avatar_frame',
      'chat_bubble',
      'sticker_pack',
    ];

    final targetType = types[tabIndex];
    return visible.where((item) => _asString(item['type']) == targetType).toList();
  }

  bool _isOwned(Map<String, dynamic> item) {
    final itemId = _asString(item['id']);
    return itemId.isNotEmpty && _purchasesByItemId.containsKey(itemId);
  }

  bool _isEquipped(Map<String, dynamic> item) {
    final itemId = _asString(item['id']);
    final purchase = _purchasesByItemId[itemId];
    return _asBool(purchase?['is_equipped']);
  }

  bool _isEquipableType(String type) {
    return type == 'avatar_frame' || type == 'chat_bubble';
  }

  Future<void> _purchaseItem(Map<String, dynamic> item) async {
    final s = getStrings();
    final r = context.r;
    final itemId = _asString(item['id']);
    final itemName = _asString(item['name'], fallback: 'Item');
    final price = _asInt(item['price_coins']);

    if (itemId.isEmpty || _busyItemIds.contains(itemId)) return;

    if (_isOwned(item)) {
      await _equipItem(item);
      return;
    }

    if (_userCoins < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Moedas insuficientes!'),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(10)),
          ),
        ),
      );
      return;
    }

    setState(() => _busyItemIds.add(itemId));

    try {
      final result = await SupabaseService.client.rpc(
        'purchase_store_item',
        params: {'p_item_id': itemId},
      );

      final payload = result is Map<String, dynamic>
          ? result
          : Map<String, dynamic>.from(result as Map? ?? const {});
      final error = _asString(payload['error']);

      if (error.isNotEmpty) {
        final message = switch (error) {
          'already_purchased' => '$itemName já foi adquirido.',
          'insufficient_coins' => 'Você não tem moedas suficientes.',
          'sold_out' => '$itemName está esgotado.',
          'item_not_found' => 'Este item não está mais disponível.',
          _ => s.errorPurchase(error),
        };
        _showSnack(message, isError: true);
        return;
      }

      await _loadStore();
      // Invalida o cache de cosméticos e packs comprados para refletir a nova compra
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        ref.invalidate(userCosmeticsProvider(userId));
      }
      ref.invalidate(purchasedStorePacksProvider);

      if (!mounted) return;
      _showSnack('$itemName comprado com sucesso!');
    } catch (e) {
      _showSnack(s.errorPurchase(e.toString()), isError: true);
    } finally {
      if (mounted) {
        setState(() => _busyItemIds.remove(itemId));
      }
    }
  }

  Future<void> _equipItem(Map<String, dynamic> item) async {
    final itemId = _asString(item['id']);
    final itemName = _asString(item['name'], fallback: 'Item');
    final type = _asString(item['type']);

    if (itemId.isEmpty || !_isOwned(item) || !_isEquipableType(type)) {
      return;
    }

    if (_busyItemIds.contains(itemId)) return;

    final purchase = _purchasesByItemId[itemId];
    final purchaseId = _asString(purchase?['id']);
    if (purchaseId.isEmpty) return;

    setState(() => _busyItemIds.add(itemId));

    try {
      // Usa o RPC equip_store_item (SECURITY DEFINER) para operação atômica:
      // desequipa conflitos e equipa/desequipa o item em uma única transação.
      final result = await SupabaseService.client.rpc(
        'equip_store_item',
        params: {
          'p_purchase_id': purchaseId,
          'p_item_type': type,
        },
      );
      final resultMap = result as Map<String, dynamic>? ?? {};
      final success = resultMap['success'] as bool? ?? false;
      final equipped = resultMap['equipped'] as bool? ?? false;

      if (!success) {
        _showSnack('Não foi possível atualizar $itemName.', isError: true);
        return;
      }

      await _loadStore();
      // Invalida o cache de cosméticos para que frame/bubble apareçam imediatamente
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        ref.invalidate(userCosmeticsProvider(userId));
      }
      if (!mounted) return;

      _showSnack(
        equipped
            ? '$itemName equipado globalmente.'
            : '$itemName removido dos itens ativos.',
      );
    } catch (e) {
      _showSnack('Não foi possível atualizar $itemName.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _busyItemIds.remove(itemId));
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    final r = context.r;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? context.nexusTheme.error : context.nexusTheme.accentPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.s(10)),
        ),
      ),
    );
  }

  String _buttonLabel(Map<String, dynamic> item) {
    final type = _asString(item['type']);
    final price = _asInt(item['price_coins']);
    final owned = _isOwned(item);

    if (!owned) {
      return '$price';
    }

    if (_isEquipableType(type)) {
      return _isEquipped(item) ? 'Equipado' : 'Equipar';
    }

    if (type == 'sticker_pack') {
      return 'Adquirido';
    }

    return 'Possuído';
  }

  String _subtitle(Map<String, dynamic> item) {
    final description = _asString(item['description']);
    if (description.isNotEmpty) return description;

    final type = _asString(item['type']);
    return switch (type) {
      'avatar_frame' => 'Moldura global para o seu perfil.',
      'chat_bubble' => 'Bolha visual para conversas do app.',
      'sticker_pack' => 'Pack integrado ao ecossistema de stickers.',
      _ => 'Item exclusivo da loja.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF00B4D8),
                    Color(0xFF0096C7),
                    Color(0xFF0077B6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.s(12),
                        vertical: r.s(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            s.store,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: r.fs(20),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: r.s(12),
                              vertical: r.s(6),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(r.s(20)),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.monetization_on_rounded,
                                  color: const Color(0xFFFFD700),
                                  size: r.s(18),
                                ),
                                SizedBox(width: r.s(4)),
                                Text(
                                  formatCount(_userCoins),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: r.fs(14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: r.s(16)),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: r.s(100),
                            height: r.s(100),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: r.s(80),
                            height: r.s(80),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFFFA500),
                                  Color(0xFFFF8C00),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'AC',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r.fs(28),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${formatCount(_userCoins)} Moedas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.fs(24),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: r.s(4)),
                    Text(
                      'Compre itens exclusivos para personalizar sua identidade global.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: r.fs(12),
                      ),
                    ),
                    SizedBox(height: r.s(16)),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: r.s(16)),
                      padding: EdgeInsets.symmetric(
                        horizontal: r.s(16),
                        vertical: r.s(12),
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF8C00), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(r.s(12)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF8C00)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: r.s(36),
                            height: r.s(36),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(r.s(10)),
                            ),
                            child: Icon(
                              Icons.workspace_premium_rounded,
                              color: Colors.white,
                              size: r.s(20),
                            ),
                          ),
                          SizedBox(width: r.s(12)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.aminoPlus,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: r.fs(14),
                                  ),
                                ),
                                Text(
                                  'Catálogo real com compra por moedas e itens equipáveis.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: r.fs(11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: r.s(12),
                              vertical: r.s(6),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(r.s(20)),
                            ),
                            child: Text(
                              'Loja ativa',
                              style: TextStyle(
                                color: const Color(0xFFFF8C00),
                                fontWeight: FontWeight.w800,
                                fontSize: r.fs(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: r.s(16)),
                  ],
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: context.nexusTheme.textHint,
                indicatorColor: Colors.white,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: r.fs(13),
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: r.fs(13),
                ),
                tabs: List.generate(
                  _tabs.length,
                  (i) => Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_tabIcons[i], size: r.s(16)),
                        SizedBox(width: r.s(6)),
                        Text(_tabs[i]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: context.nexusTheme.accentPrimary,
                  strokeWidth: 2,
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: List.generate(
                  _tabs.length,
                  (i) => _buildItemGrid(_filterItems(i)),
                ),
              ),
      ),
    );
  }

  Widget _buildItemGrid(List<Map<String, dynamic>> items) {
    final s = getStrings();
    final r = context.r;

    if (items.isEmpty) {
      return RefreshIndicator(
        color: context.nexusTheme.accentPrimary,
        onRefresh: _loadStore,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: r.screenHeight * 0.18),
            Icon(
              Icons.storefront_outlined,
              size: r.s(48),
              color: Colors.grey[700],
            ),
            SizedBox(height: r.s(12)),
            Center(
              child: Text(
                s.noItemAvailable,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: context.nexusTheme.accentPrimary,
      onRefresh: _loadStore,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), r.s(80)),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: r.s(12),
          crossAxisSpacing: r.s(12),
          childAspectRatio: 0.62,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final itemId = _asString(item['id']);
          return _StoreItemCard(
            item: item,
            subtitle: _subtitle(item),
            actionLabel: _buttonLabel(item),
            isOwned: _isOwned(item),
            isEquipped: _isEquipped(item),
            isBusy: _busyItemIds.contains(itemId),
            onPressed: () => _purchaseItem(item),
          );
        },
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: context.nexusTheme.backgroundPrimary,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}

class _StoreItemCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;
  final String subtitle;
  final String actionLabel;
  final bool isOwned;
  final bool isEquipped;
  final bool isBusy;
  final VoidCallback onPressed;

  const _StoreItemCard({
    required this.item,
    required this.subtitle,
    required this.actionLabel,
    required this.isOwned,
    required this.isEquipped,
    required this.isBusy,
    required this.onPressed,
  });

  @override
  ConsumerState<_StoreItemCard> createState() => _StoreItemCardState();
}

class _StoreItemCardState extends ConsumerState<_StoreItemCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final price = _asInt(widget.item['price_coins']);
    final name = _asString(widget.item['name'], fallback: 'Item');
    final imageUrl = _previewUrl(widget.item);
    final isLimited = _asBool(widget.item['is_limited_edition']) ||
        _asInt(widget.item['max_purchases']) > 0;
    final type = _asString(widget.item['type']);
    final isSoldOut = _isSoldOut(widget.item);

    final isActionDisabled = widget.isBusy ||
        isSoldOut ||
        (widget.isOwned && !_isEquipableType(type) && !widget.isEquipped);

    return Container(
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(
          color: widget.isEquipped
              ? context.nexusTheme.accentPrimary.withValues(alpha: 0.35)
              : isLimited
                  ? context.nexusTheme.error.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: widget.isEquipped
            ? [
                BoxShadow(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        context.nexusTheme.accentPrimary.withValues(alpha: 0.08),
                        context.nexusTheme.accentSecondary.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? _buildPreviewImage(r, imageUrl, type)
                      : Center(
                          child: Icon(
                            _getTypeIcon(type),
                            color: Colors.grey[700],
                            size: r.s(40),
                          ),
                        ),
                ),
                if (isLimited)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.08),
                                  Colors.transparent,
                                ],
                                stops: [
                                  (_shimmerController.value - 0.3)
                                      .clamp(0.0, 1.0),
                                  _shimmerController.value.clamp(0.0, 1.0),
                                  (_shimmerController.value + 0.3)
                                      .clamp(0.0, 1.0),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.srcATop,
                            child: Container(color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
                if (isLimited)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _Badge(
                      label: isSoldOut ? 'ESGOTADO' : 'LIMITADO',
                      color: context.nexusTheme.error,
                    ),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _Badge(
                    label: _getTypeLabel(type),
                    color: Colors.black.withValues(alpha: 0.55),
                    icon: _getTypeIcon(type),
                  ),
                ),
                if (widget.isOwned)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: _Badge(
                      label: widget.isEquipped ? 'ATIVO' : 'SEU ITEM',
                      color: widget.isEquipped
                          ? context.nexusTheme.accentPrimary
                          : const Color(0xFF2E7D32),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(r.s(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(13),
                    color: context.nexusTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: r.s(4)),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: r.fs(10.5),
                    height: 1.25,
                    color: context.nexusTheme.textHint,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: r.s(10)),
                GestureDetector(
                  onTap: isActionDisabled ? null : widget.onPressed,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: r.s(8)),
                    decoration: BoxDecoration(
                      gradient: widget.isEquipped
                          ? null
                          : LinearGradient(
                              colors: isActionDisabled
                                  ? [
                                      Colors.grey.shade700,
                                      Colors.grey.shade800,
                                    ]
                                  : [
                                      context.nexusTheme.warning
                                          .withValues(alpha: 0.25),
                                      context.nexusTheme.warning
                                          .withValues(alpha: 0.12),
                                    ],
                            ),
                      color: widget.isEquipped
                          ? context.nexusTheme.accentPrimary.withValues(alpha: 0.18)
                          : null,
                      borderRadius: BorderRadius.circular(r.s(10)),
                      border: Border.all(
                        color: widget.isEquipped
                            ? context.nexusTheme.accentPrimary.withValues(alpha: 0.45)
                            : isActionDisabled
                                ? Colors.grey.shade700
                                : context.nexusTheme.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: widget.isBusy
                          ? SizedBox(
                              width: r.s(16),
                              height: r.s(16),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.isOwned
                                      ? (widget.isEquipped
                                          ? Icons.check_circle_rounded
                                          : Icons.auto_awesome_rounded)
                                      : Icons.monetization_on_rounded,
                                  color: widget.isEquipped
                                      ? context.nexusTheme.accentPrimary
                                      : isActionDisabled
                                          ? Colors.white70
                                          : context.nexusTheme.warning,
                                  size: r.s(14),
                                ),
                                SizedBox(width: r.s(4)),
                                Text(
                                  isSoldOut && !widget.isOwned
                                      ? 'Esgotado'
                                      : widget.actionLabel,
                                  style: TextStyle(
                                    color: widget.isEquipped
                                        ? context.nexusTheme.accentPrimary
                                        : isActionDisabled
                                            ? Colors.white70
                                            : context.nexusTheme.warning,
                                    fontWeight: FontWeight.w800,
                                    fontSize: r.fs(12.5),
                                  ),
                                ),
                                if (!widget.isOwned && price > 0) ...[
                                  SizedBox(width: r.s(2)),
                                  Text(
                                    'coins',
                                    style: TextStyle(
                                      color: context.nexusTheme.warning
                                          .withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w600,
                                      fontSize: r.fs(9),
                                    ),
                                  ),
                                ],
                              ],
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

  /// Renderiza o preview do item no card da loja.
  ///
  /// Para [chat_bubble] com [bubble_style == nine_slice], exibe um preview
  /// fiel ao balao real: a imagem em tamanho contido centralizada, com um
  /// texto de exemplo por cima para demonstrar o efeito nine-slice.
  /// Para outros tipos, usa [BoxFit.cover] padrao.
  Widget _buildPreviewImage(Responsive r, String imageUrl, String type) {
    final assetConfig = _asMap(widget.item['asset_config']);
    final isNineSlice =
        _asString(assetConfig['bubble_style']) == 'nine_slice' ||
        _asString(assetConfig['bubble_url']).isNotEmpty;

    if (type == 'chat_bubble' && isNineSlice) {
      // Preview nine-slice: mostra o balao com texto de exemplo
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(r.s(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // NineSlicePreview usa Canvas.drawImageNine — sem assertion.
              Expanded(
                child: NineSlicePreview(
                  imageUrl: imageUrl,
                  sliceInsets: const EdgeInsets.all(38),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.s(16),
                        vertical: r.s(10),
                      ),
                      child: Text(
                        'Olá! 👋',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: r.s(6)),
              Text(
                'Nine-Slice',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: r.fs(9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Preview padrao para outros tipos (avatar_frame, sticker_pack)
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorWidget: (_, __, ___) => Center(
          child: Icon(
            _getTypeIcon(type),
            color: Colors.grey[700],
            size: r.s(40),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge({
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.s(6),
        vertical: r.s(3),
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r.s(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: r.s(10), color: Colors.white70),
            SizedBox(width: r.s(3)),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: r.fs(9),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase().trim();
  return text == 'true' || text == '1';
}

bool _isEquipableType(String type) {
  return type == 'avatar_frame' || type == 'chat_bubble';
}

bool _isSoldOut(Map<String, dynamic> item) {
  final maxPurchases = _asInt(item['max_purchases']);
  if (maxPurchases <= 0) return false;
  final currentPurchases = _asInt(item['current_purchases']);
  return currentPurchases >= maxPurchases;
}

String? _previewUrl(Map<String, dynamic> item) {
  final directPreview = _asString(item['preview_url']);
  if (directPreview.isNotEmpty) return directPreview;

  final directAsset = _asString(item['asset_url']);
  if (directAsset.isNotEmpty) return directAsset;

  final assetConfig = _asMap(item['asset_config']);
  final previewFromConfig = _asString(assetConfig['preview_url']);
  if (previewFromConfig.isNotEmpty) return previewFromConfig;

  final imageFromConfig = _asString(assetConfig['image_url']);
  if (imageFromConfig.isNotEmpty) return imageFromConfig;

  return null;
}

IconData _getTypeIcon(String type) {
  switch (type) {
    case 'avatar_frame':
      return Icons.face_rounded;
    case 'chat_bubble':
      return Icons.chat_bubble_rounded;
    case 'sticker_pack':
      return Icons.emoji_emotions_rounded;
    default:
      return Icons.shopping_bag_rounded;
  }
}

String _getTypeLabel(String type) {
  switch (type) {
    case 'avatar_frame':
      return 'Frame';
    case 'chat_bubble':
      return 'Bubble';
    case 'sticker_pack':
      return 'Sticker';
    default:
      return 'Item';
  }
}
