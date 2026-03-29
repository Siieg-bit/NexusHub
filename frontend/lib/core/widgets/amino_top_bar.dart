import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../utils/responsive.dart';

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
/// Sino: branco com badge vermelho (dot para 1-9, número para 10+).
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
    final r = context.r;
    return SafeArea(
      bottom: false,
      child: Container(
        height: r.s(50),
        padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
        color: context.scaffoldBg,
        child: Row(
          children: [
            // ── Avatar circular 30px ──
            _buildAvatar(context),

            SizedBox(width: r.s(8)),

            // ── Barra de Busca (flex) ──
            _buildSearchBar(context),

            SizedBox(width: r.s(8)),

            // ── Pílula unificada: Moedas + Add ──
            _buildCoinsPill(context),

            SizedBox(width: r.s(6)),

            // ── Sino de Notificações ──
            _buildNotificationBell(context),
          ],
        ),
      ),
    );
  }

  /// Avatar — círculo 30px, fundo cinza-azulado, sem borda colorida.
  Widget _buildAvatar(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onAvatarTap ?? () => context.push('/profile'),
      child: Container(
        width: r.s(30),
        height: r.s(30),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.cardBg,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: ClipOval(
          child: (avatarUrl ?? '').isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: avatarUrl ?? '',
                  fit: BoxFit.cover,
                  memCacheWidth: 60,
                  memCacheHeight: 60,
                  placeholder: (ctx, __) => _avatarPlaceholder(ctx),
                  errorWidget: (ctx, __, ___) => _avatarPlaceholder(ctx),
                )
              : _avatarPlaceholder(context),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder(BuildContext context) {
    final r = context.r;
    return Container(
      color: context.cardBg,
      child: Icon(
        Icons.person,
        color: Colors.white.withValues(alpha: 0.30),
        size: r.s(16),
      ),
    );
  }

  /// Barra de busca — pill arredondada, fundo translúcido branco 8%.
  /// Esquerda: lupa + "Search". Direita: "EN" + seta dropdown.
  Widget _buildSearchBar(BuildContext context) {
    final r = context.r;
    return Expanded(
      child: GestureDetector(
        onTap: onSearchTap ?? () => context.push('/search'),
        child: Container(
          height: r.s(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(r.s(16)),
          ),
          padding: EdgeInsets.symmetric(horizontal: r.s(10)),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: Colors.white.withValues(alpha: 0.40),
                size: r.s(17),
              ),
              SizedBox(width: r.s(6)),
              Expanded(
                child: Text(
                  'Search',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              // Dropdown de idioma
              Container(
                padding: EdgeInsets.symmetric(horizontal: r.s(4), vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(r.s(8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'EN',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: r.fs(10),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: Colors.white.withValues(alpha: 0.45),
                      size: r.s(14),
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
  Widget _buildCoinsPill(BuildContext context) {
    final r = context.r;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r.s(13)),
      child: SizedBox(
        height: r.s(26),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Metade esquerda: azul celeste + moeda + valor ──
            GestureDetector(
              onTap: onCoinsTap ?? () => context.push('/wallet'),
              child: Container(
                height: r.s(26),
                padding: EdgeInsets.only(left: r.s(5), right: r.s(5)),
                color: const Color(0xFF4FC3F7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Moeda dourada
                    Container(
                      width: r.s(15),
                      height: r.s(15),
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
                      child: Center(
                        child: Text(
                          '\$',
                          style: TextStyle(
                            color: Color(0xFF795548),
                            fontSize: r.fs(8),
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: r.s(3)),
                    Text(
                      coins.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.fs(11),
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
                height: r.s(26),
                width: r.s(26),
                color: const Color(0xFF1565C0),
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: r.s(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sino de notificações — branco, badge vermelho com número ou dot.
  Widget _buildNotificationBell(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onNotificationTap ?? () => context.push('/notifications'),
      child: SizedBox(
        width: r.s(30),
        height: r.s(30),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.notifications_none_rounded,
                color: Colors.white.withValues(alpha: 0.85),
                size: r.s(22),
              ),
            ),
            if (notificationCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: notificationCount > 9
                    // Badge com número para 10+
                    ? Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(4), vertical: r.s(1)),
                        decoration: BoxDecoration(
                          color: AppTheme.aminoRed,
                          borderRadius: BorderRadius.circular(r.s(8)),
                          border: Border.all(
                            color: context.scaffoldBg,
                            width: 1.5,
                          ),
                        ),
                        constraints: BoxConstraints(
                          minWidth: r.s(16),
                          minHeight: r.s(14),
                        ),
                        child: Text(
                          notificationCount > 99
                              ? '99+'
                              : '$notificationCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.fs(8),
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    // Dot simples para 1-9
                    : Container(
                        width: r.s(8),
                        height: r.s(8),
                        decoration: BoxDecoration(
                          color: AppTheme.aminoRed,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.scaffoldBg,
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
