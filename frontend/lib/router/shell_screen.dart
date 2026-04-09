import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:badges/badges.dart' as badges;
import '../config/app_theme.dart';
import '../core/l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom Navigation Bar Global — réplica pixel-perfect do Amino Apps.
///
/// 4 Tabs exatas do Amino original:
///   1. Discover  (ícone pena/feather — edit_outlined / edit)
///   2. Communities (ícone grid 2x2 — grid_view_outlined / grid_view)
///   3. Chats (ícone balão — chat_bubble_outline / chat_bubble)
///   4. Store (ícone prédio/loja — store_mall_directory_outlined / store_mall_directory)
///
/// Cor ativa: ciano (#00BCD4) — NÃO branco.
/// Cor inativa: cinza translúcido.
/// Fundo: azul-marinho escuro com blur, sem borda branca visível.
/// O ícone ativo tem um leve glow ciano por trás.
class ShellScreen extends StatelessWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/explore' || location == '/') return 0;
    if (location == '/communities') return 1;
    if (location == '/chats') return 2;
    if (location == '/store') return 3;
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
      final s = ref.watch(stringsProvider);
    final selectedIndex = _getSelectedIndex(context);

    return Scaffold(
      body: child,
      extendBody: true,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: context.bottomNavBg.withValues(alpha: 0.95),
              border: const Border(
                top: BorderSide(
                  color: Color(0x10FFFFFF),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // ── Discover (ícone pena/feather — Amino usa ícone de pena)
                    _AminoNavItem(
                      icon: Icons.edit_outlined,
                      activeIcon: Icons.edit,
                      label: s.discover,
                      isSelected: selectedIndex == 0,
                      onTap: () => _onItemTapped(context, 0),
                    ),
                    // ── Communities (ícone grid 2x2)
                    _AminoNavItem(
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
                      label: 'Comunidades',
                      isSelected: selectedIndex == 1,
                      onTap: () => _onItemTapped(context, 1),
                    ),
                    // ── Chats (ícone balão de chat)
                    _AminoNavItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: s.chats2,
                      isSelected: selectedIndex == 2,
                      onTap: () => _onItemTapped(context, 2),
                      badgeCount: 0,
                    ),
                    // ── Store (ícone prédio/loja — Amino usa store_mall_directory)
                    _AminoNavItem(
                      icon: Icons.store_mall_directory_outlined,
                      activeIcon: Icons.store_mall_directory,
                      label: s.shop,
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
// NAV ITEM — Estilo Amino: ativo = ciano (#00BCD4) com glow, inativo = cinza
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
      final s = ref.watch(stringsProvider);
    // Amino: ativo = ciano brilhante, inativo = cinza claro translúcido
    final color = isSelected
        ? AppTheme.accentColor // #00BCD4 ciano
        : Colors.white.withValues(alpha: 0.40);
    final displayIcon = isSelected ? activeIcon : icon;

    Widget iconWidget = Icon(displayIcon, color: color, size: 24);

    // Glow sutil por trás do ícone ativo (estilo Amino)
    if (isSelected) {
      iconWidget = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentColor.withValues(alpha: 0.30),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: iconWidget,
      );
    }

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
            const SizedBox(height: 2),
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
