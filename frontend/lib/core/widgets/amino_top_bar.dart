import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../services/supabase_service.dart';

/// Top Bar do Amino original — clone pixel-perfect.
/// Layout: [Avatar] [Barra de Busca (Search + EN▼)] [Pílula Moedas+Add] [Sino]
///
/// O widget de moedas e o botão "+" formam uma ÚNICA pílula de cor dupla:
/// - Metade esquerda: azul celeste com ícone de moeda dourada + valor
/// - Metade direita: azul cobalto escuro com ícone "+"
/// A separação de cores é nítida e vertical dentro da pílula.
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

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            // ── Avatar (placeholder neutro, sem borda colorida) ──
            _buildAvatar(context),

            const SizedBox(width: 8),

            // ── Barra de Busca ──
            _buildSearchBar(context),

            const SizedBox(width: 8),

            // ── Pílula unificada: Moedas + Add ──
            _buildCoinsPill(context),

            const SizedBox(width: 6),

            // ── Sino de Notificações ──
            _buildNotificationBell(context),
          ],
        ),
      ),
    );
  }

  /// Avatar — círculo esbranquiçado/cinza, placeholder neutro sem borda colorida.
  Widget _buildAvatar(BuildContext context) {
    return GestureDetector(
      onTap: onAvatarTap ?? () => context.push('/profile'),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF3A3A5E),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: ClipOval(
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: avatarUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 64,
                  memCacheHeight: 64,
                  placeholder: (_, __) => _avatarPlaceholder(),
                  errorWidget: (_, __, ___) => _avatarPlaceholder(),
                )
              : _avatarPlaceholder(),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: const Color(0xFF3A3A5E),
      child: Icon(
        Icons.person,
        color: Colors.white.withValues(alpha: 0.35),
        size: 18,
      ),
    );
  }

  /// Barra de busca — retangular arredondada, cinza escuro translúcido.
  /// Esquerda: lupa + "Search". Direita: "EN" + seta dropdown.
  Widget _buildSearchBar(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onSearchTap ?? () => context.push('/search'),
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Search',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              // Dropdown de idioma
              Text(
                'EN',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: Colors.white.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pílula unificada de moedas + botão add.
  /// Uma ÚNICA pílula com duas metades de cor diferente:
  /// - Esquerda: azul celeste (#4FC3F7) com ícone de moeda dourada + número
  /// - Direita: azul cobalto (#1976D2) com ícone "+"
  /// Separação de cor nítida e vertical.
  Widget _buildCoinsPill(BuildContext context) {
    return GestureDetector(
      onTap: onCoinsTap ?? () => context.push('/wallet'),
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Metade esquerda — azul celeste com moeda + valor
            Container(
              height: 28,
              padding: const EdgeInsets.only(left: 6, right: 4),
              color: const Color(0xFF4FC3F7), // azul celeste
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícone de moeda dourada
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '\$',
                        style: TextStyle(
                          color: Color(0xFF795548),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    coins.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            // Metade direita — azul cobalto com "+"
            GestureDetector(
              onTap: onAddTap,
              child: Container(
                height: 28,
                width: 28,
                color: const Color(0xFF1565C0), // azul cobalto escuro
                child: const Center(
                  child: Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sino de notificações — branco, com badge vermelho se houver notificações.
  Widget _buildNotificationBell(BuildContext context) {
    return GestureDetector(
      onTap: onNotificationTap ?? () => context.push('/notifications'),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.notifications_none_rounded,
                color: Colors.white.withValues(alpha: 0.85),
                size: 24,
              ),
            ),
            if (notificationCount > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.aminoRed,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0F0F1E),
                      width: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
