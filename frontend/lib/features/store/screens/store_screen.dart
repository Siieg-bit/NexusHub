import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/responsive.dart';

/// Tela Store — Loja de itens virtuais (Avatar Frames, Chat Bubbles, Sticker Packs).
/// Design fiel ao Amino Apps: header azul celeste com moeda dourada, banner Amino+.
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

  // Amino original: tabs com ícones
  final _tabs = const ['Todos', 'Frames', 'Bolhas', 'Stickers', 'Fundos'];
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
      if (userId != null) {
        final profile = await SupabaseService.table('profiles')
            .select('coins_count')
            .eq('id', userId)
            .single();
        _userCoins = profile['coins_count'] as int? ?? 0;
      }
      final res = await SupabaseService.table('store_items')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);
      _items = List<Map<String, dynamic>>.from(res as List?);
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

      final r = context.r;
    final price = item['price'] as int? ?? 0;
    if (_userCoins < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Moedas insuficientes!'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(10))),
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
            content: Text('${item['name']} comprado!'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(10))),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na compra: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(10))),
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
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ================================================================
          // HEADER AZUL CELESTE — Estilo Amino original
          // Amino usa um header azul brilhante com moeda dourada grande
          // ================================================================
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF00B4D8), // Azul celeste brilhante
                    Color(0xFF0096C7), // Azul celeste mais escuro
                    Color(0xFF0077B6), // Azul profundo
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Top row: back + title + saldo
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(12), vertical: r.s(8)),
                      child: Row(
                        children: [
                          Text(
                            'Loja',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: r.fs(20),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          // Saldo de moedas — pill dourada
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(12), vertical: r.s(6)),
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
                                Icon(Icons.monetization_on_rounded,
                                    color: Color(0xFFFFD700), size: r.s(18)),
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

                    // Moeda dourada grande central — ícone do Amino Store
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: r.s(16)),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow effect
                          Container(
                            width: r.s(100),
                            height: r.s(100),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFFFD700).withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          // Moeda
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

                    // Saldo grande
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
                      'Compre itens exclusivos para personalizar seu perfil',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: r.fs(12),
                      ),
                    ),
                    SizedBox(height: r.s(16)),

                    // ========================================================
                    // BANNER AMINO+ — laranja/dourado
                    // ========================================================
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: r.s(16)),
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(16), vertical: r.s(12)),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF8C00), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(r.s(12)),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFF8C00).withValues(alpha: 0.3),
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
                            child: Icon(Icons.workspace_premium_rounded,
                                color: Colors.white, size: r.s(20)),
                          ),
                          SizedBox(width: r.s(12)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Amino+',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: r.fs(14),
                                  ),
                                ),
                                Text(
                                  'Itens exclusivos e moedas b\u00f4nus!',
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
                                horizontal: r.s(12), vertical: r.s(6)),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(r.s(20)),
                            ),
                            child: Text(
                              'Assinar',
                              style: TextStyle(
                                color: Color(0xFFFF8C00),
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

          // ================================================================
          // TABS — Estilo Amino (scrollable, dentro do body escuro)
          // ================================================================
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: context.textHint,
                indicatorColor: Colors.white,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelStyle:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: r.fs(13)),
                unselectedLabelStyle:
                    TextStyle(fontWeight: FontWeight.w500, fontSize: r.fs(13)),
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
      final r = context.r;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: r.s(48), color: Colors.grey[700]),
            SizedBox(height: r.s(12)),
            Text('Nenhum item dispon\u00edvel',
                style: TextStyle(
                    color: Colors.grey[500], fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        setState(() => _isLoading = true);
        await _loadStore();
      },
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(r.s(16)),
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
      ),
    );
  }
}

// =============================================================================
// SLIVER TAB BAR DELEGATE
// =============================================================================
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
      color: context.scaffoldBg,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
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
    final r = context.r;
    final price = widget.item['price'] as int? ?? 0;
    final name = widget.item['name'] as String? ?? 'Item';
    final imageUrl = widget.item['image_url'] as String?;
    final isLimited = widget.item['is_limited'] as bool? ?? false;
    final type = widget.item['type'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(16)),
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
                            size: r.s(40),
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
                // LIMITADO badge
                if (isLimited)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(8), vertical: r.s(3)),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(r.s(6)),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.errorColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        'LIMITADO',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: r.fs(9),
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
                        EdgeInsets.symmetric(horizontal: r.s(6), vertical: r.s(3)),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(r.s(6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getTypeIcon(type),
                            size: r.s(10), color: Colors.white70),
                        SizedBox(width: r.s(3)),
                        Text(
                          _getTypeLabel(type),
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: r.fs(9),
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
            padding: EdgeInsets.all(r.s(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(13),
                      color: context.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: r.s(8)),
                GestureDetector(
                  onTap: widget.onPurchase,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: r.s(8)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.warningColor.withValues(alpha: 0.2),
                          AppTheme.warningColor.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(r.s(10)),
                      border: Border.all(
                          color: AppTheme.warningColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.monetization_on_rounded,
                            color: AppTheme.warningColor, size: r.s(14)),
                        SizedBox(width: r.s(4)),
                        Text(
                          price.toString(),
                          style: TextStyle(
                            color: AppTheme.warningColor,
                            fontWeight: FontWeight.w800,
                            fontSize: r.fs(13),
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
        return 'Bolha';
      case 'sticker_pack':
        return 'Sticker';
      case 'profile_background':
        return 'Fundo';
      default:
        return 'Item';
    }
  }
}
