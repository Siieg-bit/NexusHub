import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/responsive.dart';

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
class AminoBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCreateTap;
  final VoidCallback onMenuTap;
  final bool showOnline;
  final bool showCreate;
  final int onlineCount;
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
    this.avatarUrl,
    this.onlineAvatars = const [],
  });

  @override
  Widget build(BuildContext context) {
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
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(r.s(40)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              // ── Menu (sempre abre o drawer lateral) ─────────────────────────
              _CapsuleNavItem(
                isSelected: false,
                onTap: onMenuTap,
                child: _NavContent(
                  isSelected: false,
                  icon: Icons.menu_rounded,
                  label: 'Menu',
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
                        size: r.s(24),
                        isSelected: currentIndex == 1,
                      ),
                      SizedBox(height: r.s(2)),
                      Text(
                        onlineCount > 0 ? '$onlineCount' : 'Online',
                        style: TextStyle(
                          color: currentIndex == 1
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
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
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF2D2D4E),
                              Color(0xFF1A1A35),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
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
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          size: r.s(22),
                        ),
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
                      'Chats',
                      style: TextStyle(
                        color: currentIndex == 3
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
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
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.25),
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
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              )
                            : Icon(
                                Icons.person_rounded,
                                size: r.s(16),
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                      ),
                    ),
                    SizedBox(height: r.s(2)),
                    Text(
                      'Eu',
                      style: TextStyle(
                        color: currentIndex == 4
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
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
class AminoCommunityFab extends StatelessWidget {
  final VoidCallback onTap;

  const AminoCommunityFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return FloatingActionButton(
      onPressed: onTap,
      backgroundColor: const Color(0xFF7B2FBE),
      elevation: 6,
      shape: const CircleBorder(),
      child: Icon(Icons.add_rounded, color: Colors.white, size: r.s(28)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item genérico da cápsula
// ─────────────────────────────────────────────────────────────────────────────
class _CapsuleNavItem extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  const _CapsuleNavItem({
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
                ? Colors.white.withValues(alpha: 0.1)
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
class _NavContent extends StatelessWidget {
  final bool isSelected;
  final IconData icon;
  final String label;

  const _NavContent({
    required this.isSelected,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color:
              isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
          size: r.s(22),
        ),
        SizedBox(height: r.s(2)),
        Text(
          label,
          style: TextStyle(
            color:
                isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
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
class _OnlineAvatarStack extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final r = context.r;
    final visible = avatars.take(3).toList();

    if (visible.isEmpty) {
      return Icon(
        Icons.flash_on_rounded,
        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
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
                  color: const Color(0xFF1A1A2E),
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
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      )
                    : Icon(
                        Icons.person_rounded,
                        size: r.s(10),
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
