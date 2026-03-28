import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../services/supabase_service.dart';

/// Top Bar persistente do Amino original.
/// Layout: [Avatar] [Barra de Busca + Seletor PT] [Badge Moedas] [+] [Sino]
class AminoTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? avatarUrl;
  final String? username;
  final int coins;
  final int notificationCount;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onCoinsTap;
  final VoidCallback? onAddTap;
  final VoidCallback? onNotificationTap;

  const AminoTopBar({
    super.key,
    this.avatarUrl,
    this.username,
    this.coins = 0,
    this.notificationCount = 0,
    this.onAvatarTap,
    this.onSearchTap,
    this.onCoinsTap,
    this.onAddTap,
    this.onNotificationTap,
  });

  /// Formata moedas com separador de milhar (ex: 882.947)
  static String _formatCoins(int coins) {
    if (coins >= 1000000) {
      return '${(coins / 1000000).toStringAsFixed(1)}M';
    }
    if (coins >= 1000) {
      final str = coins.toString();
      final buffer = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
        buffer.write(str[i]);
      }
      return buffer.toString();
    }
    return coins.toString();
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // ── Avatar do usuário ──
            GestureDetector(
              onTap: onAvatarTap ?? () => context.push('/profile/${SupabaseService.currentUserId ?? ""}'),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppTheme.cardColor,
                            child: const Icon(Icons.person, color: AppTheme.textHint, size: 18),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.cardColor,
                            child: const Icon(Icons.person, color: AppTheme.textHint, size: 18),
                          ),
                        )
                      : Container(
                          color: AppTheme.cardColor,
                          child: const Icon(Icons.person, color: AppTheme.textHint, size: 18),
                        ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // ── Barra de Busca ──
            Expanded(
              child: GestureDetector(
                onTap: onSearchTap ?? () => context.push('/search'),
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: AppTheme.textHint, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Procurar',
                          style: TextStyle(
                            color: AppTheme.textHint,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      // Seletor de idioma (visual apenas)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'PT',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // ── Badge de Moedas (LARANJA/DOURADO — Amino original) ──
            GestureDetector(
              onTap: onCoinsTap ?? () => context.push('/wallet'),
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Amino Coin icon — círculo com "A"
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'A',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatCoins(coins),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 6),

            // ── Botão + (criar) ──
            GestureDetector(
              onTap: onAddTap,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),

            const SizedBox(width: 6),

            // ── Sino de Notificações ──
            GestureDetector(
              onTap: onNotificationTap ?? () => context.push('/notifications'),
              child: Stack(
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    color: AppTheme.textPrimary,
                    size: 26,
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppTheme.aminoRed,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            notificationCount > 9 ? '9+' : notificationCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
