import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_theme.dart';
import '../utils/responsive.dart';

/// Widget de Avatar com Frame decorativo — réplica pixel-perfect do Amino.
///
/// No Amino original, os Avatar Frames são imagens PNG com transparência
/// que VAZAM a borda do círculo do avatar. Exemplos:
///   - Molduras com asas que se estendem para fora
///   - Molduras com chifres, coroas, flores que ultrapassam o círculo
///   - Molduras com efeitos de brilho/partículas ao redor
///
/// A implementação usa [clipBehavior: Clip.none] no Stack para permitir
/// que o frame ultrapasse os limites do container do avatar.
///
/// O frame é renderizado com tamanho 40% maior que o avatar para
/// garantir que as decorações externas sejam visíveis.
class AvatarWithFrame extends StatelessWidget {
  /// URL da imagem do avatar do usuário.
  final String? avatarUrl;

  /// URL da imagem do frame decorativo (PNG com transparência).
  /// O frame deve ser uma imagem quadrada com o avatar centralizado
  /// e as decorações se estendendo além do círculo central.
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
  Widget build(BuildContext context) {
    final r = context.r;
    // O frame precisa de espaço extra ao redor do avatar para as
    // decorações que vazam a borda. No Amino, o frame é ~40% maior.
    final frameSize = size * 1.4;
    // O container total precisa acomodar o frame com overflow
    final totalSize = frameSize;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: totalSize,
        height: totalSize,
        child: Stack(
          // CRITICAL: Clip.none permite que o frame vaze a borda
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // ── Avatar circular (camada base) ──
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.surfaceColor,
                border: frameUrl == null || (frameUrl ?? '').isEmpty
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

            // ── Frame decorativo (camada overlay, VAZA a borda) ──
            if ((frameUrl ?? '').isNotEmpty)
              Positioned(
                // Centralizar o frame sobre o avatar
                top: -(frameSize - size) / 2,
                left: -(frameSize - size) / 2,
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

            // ── Badge Amino+ (canto inferior direito) ──
            if (showAminoPlus)
              Positioned(
                bottom: (totalSize - size) / 2 - 2,
                right: (totalSize - size) / 2 - 2,
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
                bottom: (totalSize - size) / 2,
                right: (totalSize - size) / 2,
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
