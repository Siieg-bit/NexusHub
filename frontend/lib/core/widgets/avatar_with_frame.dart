import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_theme.dart';
import '../../core/l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget de Avatar com Frame decorativo — réplica pixel-perfect do Amino.
///
/// O frame é uma imagem PNG com transparência que envolve o avatar circular.
/// O frame é renderizado 40% maior que o avatar e centralizado sobre ele
/// usando [Align] dentro de um [Stack] com [Clip.none].
class AvatarWithFrame extends ConsumerWidget {
  /// URL da imagem do avatar do usuário.
  final String? avatarUrl;

  /// URL da imagem do frame decorativo (PNG com transparência).
  final String? frameUrl;

  /// Tamanho do avatar em pixels (diâmetro do círculo interno).
  final double size;

  /// Se deve mostrar o badge de Amino+ no canto inferior direito.
  final bool showAminoPlus;

  /// Se deve mostrar o indicador de online (ponto verde).
  final bool showOnline;

  /// Callback ao tocar no avatar.
  final VoidCallback? onTap;

  const AvatarWithFrame({
    super.key,
    this.avatarUrl,
    this.frameUrl,
    this.size = 48,
    this.showAminoPlus = false,
    this.showOnline = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final hasFrame = (frameUrl ?? '').isNotEmpty;
    // Frame é 40% maior que o avatar para acomodar decorações externas
    final frameSize = size * 1.4;
    // O SizedBox total tem o tamanho do frame para não cortar as bordas
    final totalSize = hasFrame ? frameSize : size;

    final widget = GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: totalSize,
        height: totalSize,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // ── Avatar circular (camada base, centralizado) ──
            Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.surfaceColor,
                  border: !hasFrame
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                          width: 1.5,
                        )
                      : null,
                ),
                child: ClipOval(
                  child: (avatarUrl ?? '').isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl ?? '',
                          fit: BoxFit.cover,
                          width: size,
                          height: size,
                          memCacheWidth: (size * 2).toInt(),
                          memCacheHeight: (size * 2).toInt(),
                          placeholder: (ctx, __) => _avatarPlaceholder(ctx),
                          errorWidget: (ctx, __, ___) => _avatarPlaceholder(ctx),
                        )
                      : _avatarPlaceholder(context),
                ),
              ),
            ),

            // ── Frame decorativo (camada overlay, centralizado sobre o avatar) ──
            if (hasFrame)
              Center(
                child: IgnorePointer(
                  child: SizedBox(
                    width: frameSize,
                    height: frameSize,
                    child: CachedNetworkImage(
                      imageUrl: frameUrl ?? '',
                      fit: BoxFit.contain,
                      memCacheWidth: (frameSize * 2).toInt(),
                      memCacheHeight: (frameSize * 2).toInt(),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      placeholder: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),

            // ── Badge Amino+ (canto inferior direito do avatar) ──
            if (showAminoPlus)
              Positioned(
                bottom: hasFrame ? (frameSize - size) / 2 - 2 : -2,
                right: hasFrame ? (frameSize - size) / 2 - 2 : -2,
                child: Container(
                  width: size * 0.32,
                  height: size * 0.32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: context.scaffoldBg, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: size * 0.18,
                    color: Colors.white,
                  ),
                ),
              ),

            // ── Indicador Online (ponto verde, canto inferior direito) ──
            if (showOnline && !showAminoPlus)
              Positioned(
                bottom: hasFrame ? (frameSize - size) / 2 : 0,
                right: hasFrame ? (frameSize - size) / 2 : 0,
                child: Container(
                  width: size * 0.25,
                  height: size * 0.25,
                  decoration: BoxDecoration(
                    color: AppTheme.onlineColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.scaffoldBg, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return Semantics(
        label: s.profilePicture,
        button: true,
        child: widget,
      );
    }
    return widget;
  }

  Widget _avatarPlaceholder(BuildContext context) {
    return Container(
      color: context.surfaceColor,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: size * 0.45,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
