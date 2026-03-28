import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:badges/badges.dart' as badges;
import '../config/app_theme.dart';

/// Tela principal com Bottom Navigation Bar — réplica 1:1 do Amino Apps.
/// 4 Tabs: Descubra, Comunidades, Chats, Loja (sem Live central).
/// Ícones outlined, labels em português, cor ativa branca.
class ShellScreen extends StatelessWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/explore' || location == '/') return 0;
    if (location == '/communities') return 1;
    if (location == '/chats') return 2;
    if (location == '/store') return 3;
    // Rota /live redireciona para Descubra (tab removida)
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/explore');
        break;
      case 1:
        context.go('/communities');
        break;
      case 2:
        context.go('/chats');
        break;
      case 3:
        context.go('/store');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);

    return Scaffold(
      body: child,
      extendBody: true,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bottomNavBg.withValues(alpha: 0.95),
              border: Border(
                top: BorderSide(
                  color: AppTheme.dividerColor.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _AminoNavItem(
                      icon: Icons.explore_outlined,
                      activeIcon: Icons.explore_outlined,
                      label: 'Descubra',
                      isSelected: selectedIndex == 0,
                      onTap: () => _onItemTapped(context, 0),
                    ),
                    _AminoNavItem(
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
                      label: 'Comunidades',
                      isSelected: selectedIndex == 1,
                      onTap: () => _onItemTapped(context, 1),
                    ),
                    _AminoNavItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: 'Chats',
                      isSelected: selectedIndex == 2,
                      onTap: () => _onItemTapped(context, 2),
                      badgeCount: 0,
                    ),
                    _AminoNavItem(
                      icon: Icons.storefront_outlined,
                      activeIcon: Icons.storefront_rounded,
                      label: 'Loja',
                      isSelected: selectedIndex == 3,
                      onTap: () => _onItemTapped(context, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// NAV ITEM — Ícone outlined + Label, cor ativa branca (estilo Amino)
// ==============================================================================

class _AminoNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  const _AminoNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Amino original: ativo = branco, inativo = cinza
    final color = isSelected ? Colors.white : AppTheme.textHint;
    final displayIcon = isSelected ? activeIcon : icon;

    Widget iconWidget = Icon(displayIcon, color: color, size: 24);

    if (badgeCount > 0) {
      iconWidget = badges.Badge(
        badgeContent: Text(
          badgeCount > 99 ? '99+' : badgeCount.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 9),
        ),
        badgeStyle: const badges.BadgeStyle(
          badgeColor: AppTheme.aminoRed,
          padding: EdgeInsets.all(4),
        ),
        child: iconWidget,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
