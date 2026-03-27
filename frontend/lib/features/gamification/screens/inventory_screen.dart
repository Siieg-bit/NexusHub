import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Inventário — Itens comprados pelo usuário (Avatar Frames, Chat Bubbles, etc).
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];
  Set<String> _equippedIds = {};

  final _tabs = const [
    'Todos',
    'Avatar Frames',
    'Chat Bubbles',
    'Stickers',
    'Backgrounds'
  ];

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

      final res = await SupabaseService.table('user_inventory')
          .select('*, store_items(*)')
          .eq('user_id', userId)
          .order('purchased_at', ascending: false);
      _items = List<Map<String, dynamic>>.from(res as List);

      _equippedIds = _items
          .where((i) => i['is_equipped'] == true)
          .map((i) => i['id'] as String)
          .toSet();

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
    return _items
        .where((i) =>
            (i['store_items'] as Map<String, dynamic>?)?['type'] ==
            types[tabIndex])
        .toList();
  }

  Future<void> _toggleEquip(Map<String, dynamic> item) async {
    final itemId = item['id'] as String;
    final isEquipped = _equippedIds.contains(itemId);

    try {
      await SupabaseService.table('user_inventory')
          .update({'is_equipped': !isEquipped}).eq('id', itemId);

      setState(() {
        if (isEquipped) {
          _equippedIds.remove(itemId);
        } else {
          _equippedIds.add(itemId);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isEquipped ? 'Item desequipado' : 'Item equipado!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
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
      appBar: AppBar(
        title: const Text('Inventário',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_rounded,
                size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            const Text('Nenhum item',
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                // Navegar para a loja
              },
              child: const Text('Ir para a Loja'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final storeItem =
            item['store_items'] as Map<String, dynamic>? ?? {};
        final name = storeItem['name'] as String? ?? 'Item';
        final imageUrl = storeItem['image_url'] as String?;
        final isEquipped = _equippedIds.contains(item['id']);

        return GestureDetector(
          onTap: () => _toggleEquip(item),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: isEquipped
                  ? Border.all(color: AppTheme.primaryColor, width: 2)
                  : Border.all(
                      color: AppTheme.dividerColor.withValues(alpha: 0.3)),
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
                              top: Radius.circular(14)),
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        ),
                        child: imageUrl != null
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(14)),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.auto_awesome_rounded,
                                    color: AppTheme.textHint, size: 32)),
                      ),
                      if (isEquipped)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 11),
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
