import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:badges/badges.dart' as badges;
import '../core/l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../core/providers/chat_provider.dart';

/// Bottom Navigation Bar Global — réplica pixel-perfect do Amino Apps.
///
/// 4 Tabs globais:
///   1. Discover  (ícone pena/feather)
///   2. Communities (ícone grid 2x2)
///   3. Chats (ícone balão de chat)
///   4. Store (ícone prédio/loja)
///
/// Alertas permanecem acessíveis apenas dentro das comunidades e por entradas contextuais,
/// não pela navegação global inferior.
///
/// Cor ativa: ciano (#00BCD4) — NÃO branco.
/// Cor inativa: cinza translúcido.
/// Fundo: azul-marinho escuro com blur, sem borda branca visível.
/// O ícone ativo tem um leve glow ciano por trás.
class ShellScreen extends ConsumerWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  /// Determina a aba ativa com base na rota atual usando correspondência por prefixo.
  ///
  /// Retorna -1 para rotas que não pertencem a nenhuma aba (ex: /notifications),
  /// evitando que "Discover" apareça ativo em contextos incorretos.
  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    // Rotas que não pertencem a nenhuma aba da navegação global
    if (location.startsWith('/notifications')) return -1;
    if (location.startsWith('/settings')) return -1;
    if (location.startsWith('/search')) return -1;
    if (location.startsWith('/admin')) return -1;

    // Aba 2 — Chats: prefixos de chat e thread
    if (location == '/chats' ||
        location.startsWith('/chats/') ||
        location.startsWith('/chat/') ||
        location.startsWith('/thread/') ||
        location.startsWith('/create-group-chat') ||
        location.startsWith('/create-public-chat') ||
        location.startsWith('/screening-room/')) {
      return 2;
    }

    // Aba 1 — Communities: prefixos de comunidade
    if (location == '/communities' ||
        location.startsWith('/communities/') ||
        location.startsWith('/community/')) {
      return 1;
    }

    // Aba 3 — Store: prefixos de loja, stickers e moedas
    if (location == '/store' ||
        location.startsWith('/store/') ||
        location.startsWith('/stickers') ||
        location.startsWith('/coin-shop') ||
        location.startsWith('/free-coins') ||
        location.startsWith('/wallet') ||
        location.startsWith('/inventory')) {
      return 3;
    }

    // Aba 0 — Discover: raiz, explore, feed e demais rotas não mapeadas
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

    // Fallback: nenhuma aba ativa para rotas não reconhecidas
    return -1;
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
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final selectedIndex = _getSelectedIndex(context);

    // Badge real de chats não lidos via unreadCountProvider
    final unreadAsync = ref.watch(unreadCountProvider);
    final unreadCount = unreadAsync.valueOrNull ?? 0;

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
                      onTap: () => _onItemTapped(context, 0),
                    ),
                    // ── Communities
                    _AminoNavItem(
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
                      label: 'Comunidades',
                      isSelected: selectedIndex == 1,
                      onTap: () => _onItemTapped(context, 1),
                    ),
                    // ── Chats (com badge real de não lidas)
                    _AminoNavItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: s.chats2,
                      isSelected: selectedIndex == 2,
                      onTap: () => _onItemTapped(context, 2),
                      badgeCount: unreadCount,
                    ),
                    // ── Store
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
    // Amino: ativo = ciano brilhante, inativo = cinza claro translúcido
    final color = isSelected
        ? context.nexusTheme.accentSecondary // #00BCD4 ciano
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
              color: context.nexusTheme.accentSecondary.withValues(alpha: 0.30),
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
        badgeStyle: badges.BadgeStyle(
          badgeColor: context.nexusTheme.error,
          padding: const EdgeInsets.all(4),
        ),
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
