import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:badges/badges.dart' as badges;
import '../config/app_theme.dart';

/// Tela principal com Bottom Navigation Bar — réplica 1:1 do Amino Apps.
/// Tabs: Discover, Communities, Live (botão central), Chats, Store.
/// Fundo com blur translúcido, ícones com animação de escala.
class ShellScreen extends StatelessWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/explore' || location == '/') return 0;
    if (location == '/communities') return 1;
    if (location == '/live') return 2;
    if (location == '/chats') return 3;
    if (location == '/store') return 4;
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
        context.go('/live');
        break;
      case 3:
        context.go('/chats');
        break;
      case 4:
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
              color: AppTheme.bottomNavBg.withValues(alpha: 0.92),
              border: Border(
                top: BorderSide(
                  color: AppTheme.dividerColor.withValues(alpha: 0.3),
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
                    _AminoNavItem(
                      icon: Icons.explore_rounded,
                      activeIcon: Icons.explore,
                      label: 'Discover',
                      isSelected: selectedIndex == 0,
                      onTap: () => _onItemTapped(context, 0),
                    ),
                    _AminoNavItem(
                      icon: Icons.groups_outlined,
                      activeIcon: Icons.groups_rounded,
                      label: 'Comunidades',
                      isSelected: selectedIndex == 1,
                      onTap: () => _onItemTapped(context, 1),
                    ),
                    // Botão central LIVE (destaque rosa/magenta como no Amino)
                    _AminoLiveButton(
                      isSelected: selectedIndex == 2,
                      onTap: () => _onItemTapped(context, 2),
                    ),
                    _AminoNavItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: 'Chats',
                      isSelected: selectedIndex == 3,
                      onTap: () => _onItemTapped(context, 3),
                      badgeCount: 0, // TODO: conectar com provider de unread
                    ),
                    _AminoNavItem(
                      icon: Icons.storefront_outlined,
                      activeIcon: Icons.storefront_rounded,
                      label: 'Store',
                      isSelected: selectedIndex == 4,
                      onTap: () => _onItemTapped(context, 4),
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
// NAV ITEM — Ícone + Label com animação de escala
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
    final color = isSelected ? AppTheme.primaryColor : AppTheme.textHint;
    final displayIcon = isSelected ? activeIcon : icon;

    Widget iconWidget = AnimatedScale(
      scale: isSelected ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Icon(displayIcon, color: color, size: 24),
    );

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
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
              child: Text(label),
            ),
            // Indicador ativo (bolinha verde Amino)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 3),
              width: isSelected ? 4 : 0,
              height: isSelected ? 4 : 0,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// LIVE BUTTON — Botão central destacado (estilo Amino rosa/magenta)
// ==============================================================================

class _AminoLiveButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _AminoLiveButton({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSelected
                    ? [const Color(0xFFFF4081), const Color(0xFFE040FB)]
                    : [
                        const Color(0xFFFF4081).withValues(alpha: 0.3),
                        const Color(0xFFE040FB).withValues(alpha: 0.3),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF4081).withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              Icons.live_tv_rounded,
              color: isSelected ? Colors.white : Colors.white70,
              size: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Live',
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFFFF4081)
                  : AppTheme.textHint,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(top: 3),
            width: isSelected ? 4 : 0,
            height: isSelected ? 4 : 0,
            decoration: const BoxDecoration(
              color: Color(0xFFFF4081),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
