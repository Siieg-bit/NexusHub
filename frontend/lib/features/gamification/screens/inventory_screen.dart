import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/providers/cosmetics_provider.dart';

/// Inventário — Itens comprados pelo usuário (Avatar Frames, Chat Bubbles, etc).
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];
  Set<String> _equippedIds = {};

  List<String> get _tabs {
    final s = getStrings();
    return [s.everyone, 'Avatar Frames', 'Chat Bubbles', s.stickers];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final res = await SupabaseService.table('user_purchases')
          .select('*, store_items(*)')
          .eq('user_id', userId)
          .order('purchased_at', ascending: false);
      _items = List<Map<String, dynamic>>.from(res as List? ?? []);

      _equippedIds = _items
          .where((i) => i['is_equipped'] == true)
          .map((i) => (i['id'] as String?) ?? '')
          .toSet();

      if (!mounted) return;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _filterItems(int tabIndex) {
    if (tabIndex == 0) return _items;
    const types = ['', 'avatar_frame', 'chat_bubble', 'sticker_pack'];
    if (tabIndex >= types.length) return [];
    return _items
        .where((i) =>
            (i['store_items'] as Map<String, dynamic>?)?['type'] ==
            types[tabIndex])
        .toList();
  }

  Future<void> _toggleEquip(Map<String, dynamic> item) async {
    final s = getStrings();
    final r = context.r;
    final purchaseId = (item['id'] as String?) ?? '';
    final storeItem = (item['store_items'] as Map<String, dynamic>?) ?? {};
    final itemType = (storeItem['type'] as String?) ?? '';
    if (purchaseId.isEmpty) return;

    try {
      // Usa o RPC equip_store_item (SECURITY DEFINER) — atômico e seguro
      final result = await SupabaseService.client.rpc(
        'equip_store_item',
        params: {'p_purchase_id': purchaseId, 'p_item_type': itemType},
      );
      final payload = result as Map<String, dynamic>? ?? {};
      final success = payload['success'] as bool? ?? false;
      final equipped = payload['equipped'] as bool? ?? false;

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.anErrorOccurredTryAgain,
                  style: const TextStyle(color: Colors.white)),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(12))),
            ),
          );
        }
        return;
      }

      // Atualiza estado local e invalida cache de cosméticos
      if (!mounted) return;
      setState(() {
        if (equipped) {
          // Desequipa outros do mesmo tipo localmente
          for (final i in _items) {
            final si = (i['store_items'] as Map<String, dynamic>?) ?? {};
            if ((si['type'] as String?) == itemType && (i['id'] as String?) != purchaseId) {
              _equippedIds.remove((i['id'] as String?) ?? '');
            }
          }
          _equippedIds.add(purchaseId);
        } else {
          _equippedIds.remove(purchaseId);
        }
      });

      // Invalida o cache de cosméticos para atualização imediata
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        ref.invalidate(userCosmeticsProvider(userId));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(equipped ? 'Item equipado!' : 'Item desequipado'),
            backgroundColor: context.surfaceColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.s(12)),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.anErrorOccurredTryAgain,
                style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
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
      final s = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          s.inventory,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: AppTheme.primaryColor,
          dividerColor: Colors.transparent,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: List.generate(
                _tabs.length,
                (i) => _buildGrid(_filterItems(i)),
              ),
            ),
    );
  }

  Widget _buildGrid(List<Map<String, dynamic>> items) {
    final s = getStrings();
    final r = context.r;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_rounded,
              size: r.s(64),
              color: Colors.grey[600],
            ),
            SizedBox(height: r.s(16)),
            Text(
              s.noItems,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: r.fs(16),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: r.s(24)),
            GestureDetector(
              onTap: () {
                // Navegar para a loja
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(24), vertical: r.s(12)),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(r.s(24)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'Ir para a Loja',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(r.s(16)),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final storeItem = item['store_items'] as Map<String, dynamic>? ?? {};
        final name = storeItem['name'] as String? ?? 'Item';
        final imageUrl = storeItem['image_url'] as String?;
        final isEquipped = _equippedIds.contains(item['id']);

        return GestureDetector(
          onTap: () => _toggleEquip(item),
          child: Container(
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(r.s(16)),
              border: isEquipped
                  ? Border.all(color: AppTheme.primaryColor, width: 2)
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
              boxShadow: isEquipped
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        ),
                        child: imageUrl != null
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.grey[600],
                                size: r.s(32),
                              ),
                      ),
                      if (isEquipped)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: EdgeInsets.all(r.s(4)),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.accentColor
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: r.s(12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(r.s(8)),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: r.fs(12),
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
