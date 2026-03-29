import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../services/supabase_service.dart';

/// Top Bar do Amino original — réplica pixel-perfect.
///
/// Layout exato: [Avatar 30px] [8px] [SearchBar flex] [8px] [CoinsPill] [6px] [Bell]
///
/// A pílula de moedas é um ÚNICO container com ClipRRect:
///   - Metade esquerda: azul celeste (#4FC3F7) com moeda dourada + saldo
///   - Metade direita: azul cobalto escuro (#1565C0) com ícone "+"
///   - Separação de cor nítida, sem gap
///   - Altura: 26px, borderRadius: 13px
///
/// Barra de busca: fundo translúcido, lupa à esquerda, "Search" placeholder,
/// dropdown "EN ▼" à direita.
///
/// Sino: branco com badge vermelho dot (sem número).
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
  Size get preferredSize => const Size.fromHeight(50);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: AppTheme.scaffoldBg,
        child: Row(
          children: [
            // ── Avatar circular 30px ──
            _buildAvatar(context),

            const SizedBox(width: 8),

            // ── Barra de Busca (flex) ──
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

  /// Avatar — círculo 30px, fundo cinza-azulado, sem borda colorida.
  Widget _buildAvatar(BuildContext context) {
    return GestureDetector(
      onTap: onAvatarTap ?? () => context.push('/profile'),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.cardColor,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: ClipOval(
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: avatarUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 60,
                  memCacheHeight: 60,
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
      color: AppTheme.cardColor,
      child: Icon(
        Icons.person,
        color: Colors.white.withValues(alpha: 0.30),
        size: 16,
      ),
    );
  }

  /// Barra de busca — pill arredondada, fundo translúcido branco 8%.
  /// Esquerda: lupa + "Search". Direita: "EN" + seta dropdown.
  Widget _buildSearchBar(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onSearchTap ?? () => context.push('/search'),
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: Colors.white.withValues(alpha: 0.40),
                size: 17,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'EN',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: Colors.white.withValues(alpha: 0.45),
                      size: 14,
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

  /// Pílula unificada de moedas + botão add — pixel-perfect do Amino.
  ///
  /// Uma ÚNICA pílula com ClipRRect (borderRadius 13):
  ///   - Esquerda: azul celeste (#4FC3F7) com moeda dourada + saldo
  ///   - Direita: azul cobalto (#1565C0) com "+"
  ///   - Sem gap entre as metades
  ///   - Altura: 26px
  Widget _buildCoinsPill(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        height: 26,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Metade esquerda: azul celeste + moeda + valor ──
            GestureDetector(
              onTap: onCoinsTap ?? () => context.push('/wallet'),
              child: Container(
                height: 26,
                padding: const EdgeInsets.only(left: 5, right: 5),
                color: const Color(0xFF4FC3F7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Moeda dourada
                    Container(
                      width: 15,
                      height: 15,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x30000000),
                            blurRadius: 1,
                            offset: Offset(0, 0.5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '\$',
                          style: TextStyle(
                            color: Color(0xFF795548),
                            fontSize: 8,
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
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Metade direita: azul cobalto + "+" ──
            GestureDetector(
              onTap: onAddTap ?? () => context.push('/store'),
              child: Container(
                height: 26,
                width: 26,
                color: const Color(0xFF1565C0),
                child: const Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sino de notificações — branco, badge vermelho dot (sem número).
  Widget _buildNotificationBell(BuildContext context) {
    return GestureDetector(
      onTap: onNotificationTap ?? () => context.push('/notifications'),
      child: SizedBox(
        width: 26,
        height: 26,
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.notifications_none_rounded,
                color: Colors.white.withValues(alpha: 0.85),
                size: 22,
              ),
            ),
            if (notificationCount > 0)
              Positioned(
                right: 3,
                top: 2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppTheme.aminoRed,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.scaffoldBg,
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
