import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cosmetics_provider.dart';
import 'avatar_with_frame.dart';

/// Widget de Avatar com cosméticos equipados — carrega automaticamente
/// o frame do Provider Global de Cosméticos.
///
/// Drop-in replacement para CircleAvatar em qualquer lugar do app.
/// Basta fornecer o userId e o avatarUrl — o frame é carregado
/// automaticamente do cache do Provider.
///
/// Molduras animadas (GIF / WebP animado) são renderizadas automaticamente
/// quando [UserCosmetics.isAvatarFrameAnimated] é `true`.
///
/// Uso:
/// ```dart
/// CosmeticAvatar(
///   userId: user.id,
///   avatarUrl: user.iconUrl,
///   size: r.s(40),
/// )
/// ```
class CosmeticAvatar extends ConsumerWidget {
  final String? userId;
  final String? avatarUrl;
  final double size;
  final bool showOnline;
  final VoidCallback? onTap;

  /// Frame URL explícito — se fornecido, ignora o Provider.
  final String? frameUrlOverride;

  /// Indica se o frame override é animado (GIF / WebP animado).
  /// Só relevante quando [frameUrlOverride] é fornecido.
  final bool isFrameOverrideAnimated;

  const CosmeticAvatar({
    super.key,
    this.userId,
    this.avatarUrl,
    this.size = 40,
    this.showOnline = false,
    this.onTap,
    this.frameUrlOverride,
    this.isFrameOverrideAnimated = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Se não tem userId, renderizar avatar simples sem frame
    if (userId == null || (userId ?? '').isEmpty) {
      return AvatarWithFrame(
        avatarUrl: avatarUrl,
        frameUrl: frameUrlOverride,
        size: size,
        showOnline: showOnline,
        onTap: onTap,
        isFrameAnimated: isFrameOverrideAnimated,
      );
    }

    // Se tem override explícito, usar direto
    if (frameUrlOverride != null) {
      return AvatarWithFrame(
        avatarUrl: avatarUrl,
        frameUrl: frameUrlOverride,
        size: size,
        showOnline: showOnline,
        onTap: onTap,
        isFrameAnimated: isFrameOverrideAnimated,
      );
    }

    // Buscar cosméticos do Provider
    final cosmeticsAsync = ref.watch(userCosmeticsProvider(userId ?? ''));

    return cosmeticsAsync.when(
      data: (cosmetics) => AvatarWithFrame(
        avatarUrl: avatarUrl,
        frameUrl: cosmetics.avatarFrameUrl,
        size: size,
        showAminoPlus: cosmetics.isAminoPlus,
        showOnline: showOnline,
        onTap: onTap,
        // Propaga is_animated do asset_config para renderizar GIF/WebP animado
        isFrameAnimated: cosmetics.isAvatarFrameAnimated,
      ),
      loading: () => AvatarWithFrame(
        avatarUrl: avatarUrl,
        size: size,
        showOnline: showOnline,
        onTap: onTap,
      ),
      error: (_, __) => AvatarWithFrame(
        avatarUrl: avatarUrl,
        size: size,
        showOnline: showOnline,
        onTap: onTap,
      ),
    );
  }
}
