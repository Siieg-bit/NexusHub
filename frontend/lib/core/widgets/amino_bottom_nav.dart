import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// AminoBottomNavBar — Bottom Navigation Bar customizada com CustomPainter.
///
/// Replica pixel-perfect a barra inferior do Amino dentro de uma comunidade:
/// - 5 itens: Menu | Online | FAB Rosa (+) | Chats | Me
/// - O FAB central é desenhado como um "notch" invertido no CustomPainter
/// - Cor ativa: ciano (#00BCD4), inativa: cinza
/// - Fundo: surfaceColor com borda superior sutil
class AminoBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCreateTap;
  final VoidCallback onMenuTap;
  final bool showOnline;
  final bool showCreate;
  final int onlineCount;
  final String? avatarUrl;

  const AminoBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCreateTap,
    required this.onMenuTap,
    this.showOnline = true,
    this.showCreate = true,
    this.onlineCount = 0,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: CustomPaint(
          painter: _NavBarPainter(
            color: context.surfaceColor,
            borderColor: context.dividerClr.withValues(alpha: 0.3),
            showNotch: showCreate,
          ),
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                // ── Menu ──
                _NavItem(
                  icon: Icons.menu_rounded,
                  label: 'Menu',
                  isSelected: currentIndex == 0,
                  onTap: () {
                    if (currentIndex == 0) {
                      onMenuTap();
                    } else {
                      onTap(0);
                    }
                  },
                ),

                // ── Online ──
                if (showOnline)
                  _NavItem(
                    icon: Icons.flash_on_rounded,
                    label: onlineCount > 0 ? '$onlineCount' : 'Online',
                    isSelected: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),

                // ── FAB Central Rosa ──
                if (showCreate)
                  Expanded(
                    child: GestureDetector(
                      onTap: onCreateTap,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFE91E63),
                                  Color(0xFFFF5252),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.fabPink
                                      .withValues(alpha: 0.5),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: Colors.white, size: 28),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),

                // ── Chats ──
                _NavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chats',
                  isSelected: currentIndex == 3,
                  onTap: () => onTap(3),
                ),

                // ── Me (avatar) ──
                _NavItemAvatar(
                  avatarUrl: avatarUrl,
                  label: 'Eu',
                  isSelected: currentIndex == 4,
                  onTap: () => onTap(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav Item padrão
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.accentColor : const Color(0xFF6B7B8D);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Indicador ativo (linha ciano no topo)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: isSelected ? 20 : 0,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav Item com Avatar (para "Me")
// ─────────────────────────────────────────────────────────────────────────────
class _NavItemAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItemAvatar({
    required this.avatarUrl,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.accentColor : const Color(0xFF6B7B8D);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Indicador ativo
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: isSelected ? 20 : 0,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.accentColor : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? Image.network(avatarUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.person, size: 14, color: color))
                    : Icon(Icons.person, size: 14, color: color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter para a barra com notch central
// ─────────────────────────────────────────────────────────────────────────────
class _NavBarPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final bool showNotch;

  _NavBarPainter({
    required this.color,
    required this.borderColor,
    this.showNotch = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final path = Path();
    final midX = size.width / 2;
    const notchRadius = 30.0;
    const notchDepth = 6.0;

    if (showNotch) {
      path.moveTo(0, 0);
      path.lineTo(midX - notchRadius - 10, 0);
      // Curva suave para o notch
      path.cubicTo(
        midX - notchRadius, 0,
        midX - notchRadius + 5, -notchDepth,
        midX, -notchDepth,
      );
      path.cubicTo(
        midX + notchRadius - 5, -notchDepth,
        midX + notchRadius, 0,
        midX + notchRadius + 10, 0,
      );
      path.lineTo(size.width, 0);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _NavBarPainter oldDelegate) =>
      color != oldDelegate.color ||
      borderColor != oldDelegate.borderColor ||
      showNotch != oldDelegate.showNotch;
}
