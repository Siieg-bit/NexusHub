import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';

/// Tela Store — Loja de itens virtuais (Avatar Frames, Chat Bubbles, Sticker Packs).
/// Estilo visual Amino Apps.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  int _userCoins = 0;

  final _tabs = const [
    'All',
    'Frames',
    'Bubbles',
    'Stickers',
    'Backgrounds',
  ];

  final _tabIcons = const [
    Icons.storefront_rounded,
    Icons.face_rounded,
    Icons.chat_bubble_rounded,
    Icons.emoji_emotions_rounded,
    Icons.wallpaper_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadStore();
  }

  Future<void> _loadStore() async {
    try {
      final userId = SupabaseService.currentUserId;

      // Carregar moedas do usuário
      if (userId != null) {
        final profile = await SupabaseService.table('profiles')
            .select('coins_count')
            .eq('id', userId)
            .single();
        _userCoins = profile['coins_count'] as int? ?? 0;
      }

      // Carregar itens da loja
      final res = await SupabaseService.table('store_items')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);
      _items = List<Map<String, dynamic>>.from(res as List);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _filterItems(int tabIndex) {
    if (tabIndex == 0) return _items;
    final types = [
      '',
      'avatar_frame',
      'chat_bubble',
      'sticker_pack',
      'profile_background'
    ];
    return _items.where((i) => i['type'] == types[tabIndex]).toList();
  }

  Future<void> _purchaseItem(Map<String, dynamic> item) async {
    final price = item['price'] as int? ?? 0;
    if (_userCoins < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Not enough coins!'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    try {
      await SupabaseService.client.rpc('purchase_store_item', params: {
        'p_item_id': item['id'],
      });
      setState(() => _userCoins -= price);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item['name']} purchased!'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase error: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── AppBar estilo Amino ──
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppTheme.scaffoldBg,
            elevation: 0,
            title: const Text('Store',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppTheme.textPrimary)),
            actions: [
              // Saldo de moedas
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.warningColor.withValues(alpha: 0.2),
                      AppTheme.warningColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.warningColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on_rounded,
                        color: AppTheme.warningColor, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      formatCount(_userCoins),
                      style: const TextStyle(
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: List.generate(
                    _tabs.length,
                    (i) => Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_tabIcons[i], size: 16),
                          const SizedBox(width: 6),
                          Text(_tabs[i]),
                        ],
                      ),
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
                    color: AppTheme.primaryColor, strokeWidth: 2))
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
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text('No items available',
                style: TextStyle(
                    color: Colors.grey[500], fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _StoreItemCard(
          item: item,
          onPurchase: () => _purchaseItem(item),
        );
      },
    );
  }
}

// =============================================================================
// STORE ITEM CARD — Estilo Amino
// =============================================================================

class _StoreItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onPurchase;

  const _StoreItemCard({required this.item, required this.onPurchase});

  @override
  State<_StoreItemCard> createState() => _StoreItemCardState();
}

class _StoreItemCardState extends State<_StoreItemCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

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
    final price = widget.item['price'] as int? ?? 0;
    final name = widget.item['name'] as String? ?? 'Item';
    final imageUrl = widget.item['image_url'] as String?;
    final isLimited = widget.item['is_limited'] as bool? ?? false;
    final type = widget.item['type'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLimited
              ? AppTheme.errorColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: isLimited
            ? [
                BoxShadow(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagem do item
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.08),
                        AppTheme.accentColor.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: imageUrl != null
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : Center(
                          child: Icon(
                            _getTypeIcon(type),
                            color: Colors.grey[700],
                            size: 40,
                          ),
                        ),
                ),
                // Shimmer effect for limited items
                if (isLimited)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                          child: ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.08),
                                  Colors.transparent,
                                ],
                                stops: [
                                  _shimmerController.value - 0.3,
                                  _shimmerController.value,
                                  _shimmerController.value + 0.3,
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
                // LIMITED badge
                if (isLimited)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.errorColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Text(
                        'LIMITED',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5),
                      ),
                    ),
                  ),
                // Type badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getTypeIcon(type),
                            size: 10, color: Colors.white70),
                        const SizedBox(width: 3),
                        Text(
                          _getTypeLabel(type),
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Info + Purchase
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: widget.onPurchase,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.warningColor.withValues(alpha: 0.2),
                          AppTheme.warningColor.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.warningColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.monetization_on_rounded,
                            color: AppTheme.warningColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          price.toString(),
                          style: const TextStyle(
                            color: AppTheme.warningColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
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

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'avatar_frame':
        return Icons.face_rounded;
      case 'chat_bubble':
        return Icons.chat_bubble_rounded;
      case 'sticker_pack':
        return Icons.emoji_emotions_rounded;
      case 'profile_background':
        return Icons.wallpaper_rounded;
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
      case 'profile_background':
        return 'BG';
      default:
        return 'Item';
    }
  }
}
