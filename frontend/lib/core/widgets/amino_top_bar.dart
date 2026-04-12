import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../l10n/locale_provider.dart';
import '../utils/responsive.dart';
import '../l10n/app_strings.dart';

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
/// Barra de busca: fundo translúcido, lupa à esquerda, placeholder localizado,
/// dropdown com idioma atual à direita.
///
/// Sino: branco com badge vermelho (dot para 1-9, número para 10+).
class AminoTopBar extends ConsumerWidget implements PreferredSizeWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final s = ref.watch(stringsProvider);
    final currentLocale = ref.watch(localeProvider);

    return SafeArea(
      bottom: false,
      child: Container(
        height: r.s(50),
        padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
        color: context.nexusTheme.backgroundPrimary,
        child: Row(
          children: [
            // ── Avatar circular 30px ──
            _buildAvatar(context),

            SizedBox(width: r.s(8)),

            // ── Barra de Busca (flex) ──
            _buildSearchBar(context, ref, s, currentLocale),

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
          color: context.nexusTheme.surfacePrimary,
          border: Border.all(
            color: context.nexusTheme.borderSubtle,
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
      color: context.nexusTheme.surfacePrimary,
      child: Icon(
        Icons.person,
        color: context.nexusTheme.iconSecondary,
        size: r.s(16),
      ),
    );
  }

  /// Barra de busca — pill arredondada, fundo translúcido branco 8%.
  /// Esquerda: lupa + placeholder localizado. Direita: código do idioma atual + seta dropdown.
  Widget _buildSearchBar(
      BuildContext context, WidgetRef ref, AppStrings s, AppLocale currentLocale) {
    final s = getStrings();
    final r = context.r;
    return Expanded(
      child: Container(
        height: r.s(32),
        decoration: BoxDecoration(
          color: context.nexusTheme.inputBackground.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(r.s(16)),
        ),
        padding: EdgeInsets.symmetric(horizontal: r.s(10)),
        child: Row(
          children: [
            // ── Parte clicavel para busca (lupa + placeholder) ──
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSearchTap ?? () => context.push('/search'),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: context.nexusTheme.textHint,
                      size: r.s(17),
                    ),
                    SizedBox(width: r.s(6)),
                    Expanded(
                      child: Text(
                        s.search,
                        style: TextStyle(
                          color: context.nexusTheme.textHint,
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Chip de idioma (separado, com seu próprio GestureDetector) ──
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showLanguagePopup(context, ref, currentLocale),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: r.s(4), vertical: 2),
                decoration: BoxDecoration(
                  color: context.nexusTheme.surfaceSecondary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(r.s(8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentLocale.code.toUpperCase(),
                      style: TextStyle(
                        color: context.nexusTheme.textSecondary,
                        fontSize: r.fs(10),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: context.nexusTheme.textHint,
                      size: r.s(14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Popup de seleção de idioma — exibe opções disponíveis e aplica a troca.
  void _showLanguagePopup(
      BuildContext context, WidgetRef ref, AppLocale currentLocale) {
    final r = context.r;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + box.size.width - r.s(120),
        offset.dy + box.size.height,
        offset.dx + box.size.width,
        0,
      ),
      color: context.nexusTheme.surfacePrimary,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(10))),
      items: AppLocale.values.map((locale) {
        final isSelected = locale == currentLocale;
        return PopupMenuItem<String>(
          value: locale.code,
          child: Row(
            children: [
              Text(
                locale.flag,
                style: TextStyle(fontSize: r.fs(16)),
              ),
              SizedBox(width: r.s(8)),
              Expanded(
                child: Text(
                  locale.label,
                  style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(13),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, color: context.nexusTheme.accentPrimary, size: r.s(16)),
            ],
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null && value != currentLocale.code) {
        final newLocale = AppLocale.fromCode(value);
        ref.read(localeProvider.notifier).setLocale(newLocale);
      }
    });
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
                color: context.nexusTheme.walletGradient.colors.first,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Moeda — usa coinColor do tema (dourado escuro no GreenLeaf)
                    Container(
                      width: r.s(15),
                      height: r.s(15),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.nexusTheme.coinColor,
                        boxShadow: [
                          BoxShadow(
                            color: context.nexusTheme.overlayColor.withValues(alpha: 0.2),
                            blurRadius: 1,
                            offset: const Offset(0, 0.5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '\$',
                          style: TextStyle(
                            color: context.nexusTheme.buttonPrimaryForeground,
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
                        color: context.nexusTheme.buttonPrimaryForeground,
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
                color: context.nexusTheme.accentPrimary,
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: context.nexusTheme.buttonPrimaryForeground,
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
                color: context.nexusTheme.appBarForeground.withValues(alpha: 0.85),
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
                          color: context.nexusTheme.error,
                          borderRadius: BorderRadius.circular(r.s(8)),
                          border: Border.all(
                            color: context.nexusTheme.backgroundPrimary,
                            width: 1.5,
                          ),
                        ),
                        constraints: BoxConstraints(
                          minWidth: r.s(16),
                          minHeight: r.s(14),
                        ),
                          child: Text(
                          notificationCount > 99 ? '99+' : '$notificationCount',
                          style: TextStyle(
                            color: context.nexusTheme.buttonDestructiveForeground,
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
                          color: context.nexusTheme.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.nexusTheme.backgroundPrimary,
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
