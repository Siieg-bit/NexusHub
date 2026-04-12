import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/nexus_theme_extension.dart';
import '../utils/responsive.dart';
import '../l10n/locale_provider.dart';

/// AminoBottomNavBar — Floating capsule bottom nav estilo Amino Apps.
///
/// Aparece SOMENTE nas páginas iniciais da comunidade (Home, Online, Chats, Me).
/// Nas páginas internas usa-se apenas o FAB "+" isolado [AminoCommunityFab].
///
/// Layout:
///   [Menu]  [Online c/ avatares]  [● + ●]  [Chats]  [Eu c/ avatar]
///
/// Estilo:
///   - Container flutuante, fundo escuro semi-transparente (#1A1A2E ~92%)
///   - Bordas arredondadas (cápsula), sombra suave
///   - Usado como bottomNavigationBar do Scaffold (extendBody: true)
class AminoBottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCreateTap;
  final VoidCallback onMenuTap;
  final bool showOnline;
  final bool showCreate;
  final int onlineCount;
  final bool showChatUnreadBadge;
  final String? avatarUrl;

  /// Avatares dos membros online (até 3) para exibir no botão Online
  final List<String?> onlineAvatars;

  /// Callback para abrir a sheet de membros online
  final VoidCallback? onOnlineTap;

  const AminoBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCreateTap,
    required this.onMenuTap,
    this.onOnlineTap,
    this.showOnline = true,
    this.showCreate = true,
    this.onlineCount = 0,
    this.showChatUnreadBadge = false,
    this.avatarUrl,
    this.onlineAvatars = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: r.s(20),
          right: r.s(20),
          bottom: r.s(10),
        ),
        child: Container(
          height: r.s(62),
          decoration: BoxDecoration(
            color: context.nexusTheme.bottomNavBackground.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(r.s(40)),
            boxShadow: [
              BoxShadow(
                color: context.nexusTheme.overlayColor.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: context.nexusTheme.overlayColor.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: context.nexusTheme.borderSubtle,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              // ── Home (navega para página inicial da comunidade) ──────────
              _CapsuleNavItem(
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
                child: _NavContent(
                  isSelected: currentIndex == 0,
                  icon: Icons.home_rounded,
                  label: s.home2,
                ),
              ),

              // ── Online (com avatares empilhados) ──────────────────────────
              if (showOnline)
                _CapsuleNavItem(
                  isSelected: currentIndex == 1,
                  onTap: () {
                    if (onOnlineTap != null) {
                      onOnlineTap!();
                    } else {
                      onTap(1);
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _OnlineAvatarStack(
                        avatars: onlineAvatars,
                        count: onlineCount,
                        size: r.s(28),
                        isSelected: currentIndex == 1,
                      ),
                      SizedBox(height: r.s(2)),
                      Text(
                        onlineCount > 0 ? '$onlineCount' : s.online,
                        style: TextStyle(
                          color: currentIndex == 1
                              ? context.nexusTheme.bottomNavSelectedItem
                              : context.nexusTheme.bottomNavUnselectedItem,
                          fontSize: r.fs(10),
                          fontWeight: currentIndex == 1
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Botão Central "+" ──────────────────────────────────────────
              if (showCreate)
                Expanded(
                  child: GestureDetector(
                    onTap: onCreateTap,
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Container(
                        width: r.s(48),
                        height: r.s(48),
                        decoration: BoxDecoration(
                          gradient: context.nexusTheme.accentGradient,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.nexusTheme.borderSubtle,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          color: context.nexusTheme.buttonPrimaryForeground,
                          size: r.s(22),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const Expanded(child: SizedBox()),

              // ── Chats ──────────────────────────────────────────────────────
              _CapsuleNavItem(
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.chat_bubble_rounded,
                          color: currentIndex == 3
                              ? context.nexusTheme.bottomNavSelectedItem
                              : context.nexusTheme.bottomNavUnselectedItem,
                          size: r.s(22),
                        ),
                        if (showChatUnreadBadge)
                          Positioned(
                            top: -r.s(2),
                            right: -r.s(4),
                            child: Container(
                              width: r.s(8),
                              height: r.s(8),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: r.s(2)),
                    Text(
                      s.chats,
                      style: TextStyle(
                        color: currentIndex == 3
                            ? context.nexusTheme.bottomNavSelectedItem
                            : context.nexusTheme.bottomNavUnselectedItem,
                        fontSize: r.fs(10),
                        fontWeight: currentIndex == 3
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Eu (avatar do usuário) ─────────────────────────────────────
              _CapsuleNavItem(
                isSelected: currentIndex == 4,
                onTap: () => onTap(4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: r.s(26),
                      height: r.s(26),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: currentIndex == 4
                              ? context.nexusTheme.bottomNavSelectedItem
                              : context.nexusTheme.bottomNavUnselectedItem.withValues(alpha: 0.5),
                          width: currentIndex == 4 ? 2 : 1,
                        ),
                      ),
                      child: ClipOval(
                        child: (avatarUrl ?? '').isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: avatarUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.person_rounded,
                                  size: r.s(16),
                                  color: context.nexusTheme.bottomNavUnselectedItem,
                                ),
                              )
                            : Icon(
                                Icons.person_rounded,
                                size: r.s(16),
                                color: context.nexusTheme.bottomNavUnselectedItem,
                              ),
                      ),
                    ),
                    SizedBox(height: r.s(2)),
                    Text(
                      'Eu',
                      style: TextStyle(
                        color: currentIndex == 4
                            ? context.nexusTheme.bottomNavSelectedItem
                            : context.nexusTheme.bottomNavUnselectedItem,
                        fontSize: r.fs(10),
                        fontWeight: currentIndex == 4
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB flutuante para páginas internas (perfil, chats, wiki...)
// Substitui o nav completo quando o usuário está em uma sub-página.
// ─────────────────────────────────────────────────────────────────────────────
class AminoCommunityFab extends ConsumerWidget {
  final VoidCallback onTap;

  const AminoCommunityFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return Container(
      width: r.s(56),
      height: r.s(56),
      decoration: BoxDecoration(
        gradient: context.nexusTheme.fabGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: context.nexusTheme.accentPrimary.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(Icons.add_rounded, color: context.nexusTheme.buttonPrimaryForeground, size: r.s(28)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item genérico da cápsula
// ─────────────────────────────────────────────────────────────────────────────
class _CapsuleNavItem extends ConsumerWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  const _CapsuleNavItem({
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.symmetric(horizontal: r.s(3), vertical: r.s(6)),
          decoration: BoxDecoration(
            color: isSelected
                ? context.nexusTheme.bottomNavSelectedItem.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(r.s(20)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conteúdo padrão de um item (ícone + label)
// ─────────────────────────────────────────────────────────────────────────────
class _NavContent extends ConsumerWidget {
  final bool isSelected;
  final IconData icon;
  final String label;

  const _NavContent({
    required this.isSelected,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: isSelected
              ? context.nexusTheme.bottomNavSelectedItem
              : context.nexusTheme.bottomNavUnselectedItem,
          size: r.s(22),
        ),
        SizedBox(height: r.s(2)),
        Text(
          label,
          style: TextStyle(
            color: isSelected
                ? context.nexusTheme.bottomNavSelectedItem
                : context.nexusTheme.bottomNavUnselectedItem,
            fontSize: r.fs(10),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stack de avatares dos membros online (estilo Amino)
// ─────────────────────────────────────────────────────────────────────────────
class _OnlineAvatarStack extends ConsumerWidget {
  final List<String?> avatars;
  final int count;
  final double size;
  final bool isSelected;

  const _OnlineAvatarStack({
    required this.avatars,
    required this.count,
    required this.size,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final visible = avatars.take(3).toList();

    if (visible.isEmpty) {
      return Icon(
        Icons.flash_on_rounded,
        color: isSelected
            ? context.nexusTheme.bottomNavSelectedItem
            : context.nexusTheme.bottomNavUnselectedItem,
        size: size,
      );
    }

    final avatarSize = size * 0.85;
    final overlap = avatarSize * 0.4;
    final totalWidth =
        avatarSize + (visible.length - 1) * (avatarSize - overlap);

    return SizedBox(
      width: totalWidth,
      height: avatarSize,
      child: Stack(
        children: List.generate(visible.length, (i) {
          final url = visible[i];
          return Positioned(
            left: i * (avatarSize - overlap),
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.nexusTheme.bottomNavBackground,
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: (url ?? '').isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: url!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Icon(
                          Icons.person_rounded,
                          size: r.s(10),
                                color: context.nexusTheme.bottomNavUnselectedItem,
                        ),
                    : Icon(
                        Icons.person_rounded,
                        size: r.s(10),
                        color: context.nexusTheme.bottomNavUnselectedItem,
                      ),                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
