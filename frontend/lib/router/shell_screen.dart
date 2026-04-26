import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../core/providers/chat_provider.dart';
import '../core/providers/notification_provider.dart';
import '../core/providers/dm_invite_provider.dart';
import '../core/widgets/nexus_badge.dart';

/// Provider global para o ScrollController de cada aba.
/// Permite que o shell acione o scroll-to-top ao re-tocar a aba ativa.
final tabScrollControllerProvider =
    Provider.family<ScrollController, int>((ref, tabIndex) {
  final controller = ScrollController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Bottom Navigation Bar Global — réplica pixel-perfect do Amino Apps.
///
/// 4 Tabs globais:
///   1. Discover  (ícone pena/feather)
///   2. Communities (ícone grid 2x2) — badge de notificações não lidas de comunidades
///   3. Chats (ícone balão de chat) — badge de mensagens não lidas
///   4. Store (ícone prédio/loja)
///
/// Cor ativa: ciano (#00BCD4) — NÃO branco.
/// Cor inativa: cinza translúcido.
/// Fundo: azul-marinho escuro com blur.
///
/// Comportamento de re-tap:
///   - Tocar na aba já ativa aciona scroll-to-top suave via [tabScrollControllerProvider].
class ShellScreen extends ConsumerWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    if (location.startsWith('/notifications')) return -1;
    if (location.startsWith('/settings')) return -1;
    if (location.startsWith('/search')) return -1;
    if (location.startsWith('/admin')) return -1;

    if (location == '/chats' ||
        location.startsWith('/chats/') ||
        location.startsWith('/chat/') ||
        location.startsWith('/thread/') ||
        location.startsWith('/create-group-chat') ||
        location.startsWith('/create-public-chat') ||
        location.startsWith('/screening-room/')) {
      return 2;
    }

    if (location == '/communities' ||
        location.startsWith('/communities/') ||
        location.startsWith('/community/')) {
      return 1;
    }

    if (location == '/store' ||
        location.startsWith('/store/') ||
        location.startsWith('/stickers') ||
        location.startsWith('/coin-shop') ||
        location.startsWith('/free-coins') ||
        location.startsWith('/wallet') ||
        location.startsWith('/inventory')) {
      return 3;
    }

    if (location == '/' ||
        location == '/explore' ||
        location.startsWith('/explore/') ||
        location.startsWith('/feed') ||
        location.startsWith('/post/') ||
        location.startsWith('/user/') ||
        location.startsWith('/profile') ||
        location.startsWith('/wiki/') ||
        location.startsWith('/quiz/') ||
        location.startsWith('/poll/') ||
        location.startsWith('/question/') ||
        location.startsWith('/check-in') ||
        location.startsWith('/achievements') ||
        location.startsWith('/all-rankings')) {
      return 0;
    }

    return -1;
  }

  void _onItemTapped(BuildContext context, WidgetRef ref, int index) {
    final currentIndex = _getSelectedIndex(context);

    if (currentIndex == index) {
      // Re-tap na aba ativa: scroll suave para o topo
      final controller = ref.read(tabScrollControllerProvider(index));
      if (controller.hasClients) {
        controller.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

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
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final selectedIndex = _getSelectedIndex(context);

    // Badge de chats não lidos + DM invites pendentes
    final chatUnread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final dmInviteCount = ref.watch(pendingDmInvitesProvider).valueOrNull?.length ?? 0;
    final totalChatBadge = chatUnread + dmInviteCount;

    // Badge de notificações não lidas de comunidades
    final communityNotifUnread =
        ref.watch(totalUnreadCommunityNotificationsProvider).valueOrNull ?? 0;

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
                    // ── Discover
                    _AminoNavItem(
                      icon: Icons.edit_outlined,
                      activeIcon: Icons.edit,
                      label: s.discover,
                      isSelected: selectedIndex == 0,
                      onTap: () => _onItemTapped(context, ref, 0),
                    ),
                    // ── Communities — badge de notificações de comunidade
                    _AminoNavItem(
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
                      label: 'Comunidades',
                      isSelected: selectedIndex == 1,
                      onTap: () => _onItemTapped(context, ref, 1),
                      badgeCount: communityNotifUnread,
                    ),
                    // ── Chats — badge de mensagens não lidas + DM invites pendentes
                    _AminoNavItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: s.chats2,
                      isSelected: selectedIndex == 2,
                      onTap: () => _onItemTapped(context, ref, 2),
                      badgeCount: totalChatBadge,
                    ),
                    // ── Store
                    _AminoNavItem(
                      icon: Icons.store_mall_directory_outlined,
                      activeIcon: Icons.store_mall_directory,
                      label: s.shop,
                      isSelected: selectedIndex == 3,
                      onTap: () => _onItemTapped(context, ref, 3),
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
// NAV ITEM — Estilo Amino com NexusBadge moderno
// ==============================================================================
class _AminoNavItem extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final color = isSelected
        ? context.nexusTheme.accentSecondary
        : Colors.white.withValues(alpha: 0.40);
    final displayIcon = isSelected ? activeIcon : icon;

    Widget iconWidget = Icon(displayIcon, color: color, size: 24);

    // Glow sutil por trás do ícone ativo
    if (isSelected) {
      iconWidget = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: context.nexusTheme.accentSecondary.withValues(alpha: 0.30),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: iconWidget,
      );
    }

    // Badge com NexusBadge moderno
    if (badgeCount > 0) {
      iconWidget = NexusBadge(
        count: badgeCount,
        offset: const Offset(3, -3),
        child: iconWidget,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
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
