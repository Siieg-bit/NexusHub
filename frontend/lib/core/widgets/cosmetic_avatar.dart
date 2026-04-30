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
/// ## Indicadores de Estado
///
/// O widget suporta dois indicadores visuais com hierarquia de prioridade:
///
/// - [hasActiveCall]: Borda glow verde pulsante — prioridade máxima.
///   Indica que o usuário está em uma call ou projeção pública ativa.
/// - [hasActiveStory]: Anel gradiente laranja/rosa — exibido apenas quando
///   não há call ativa. Indica stories não vistos.
///
/// Uso:
/// ```dart
/// CosmeticAvatar(
///   userId: user.id,
///   avatarUrl: user.iconUrl,
///   size: r.s(40),
///   hasActiveStory: hasUnviewedStory,
///   hasActiveCall: isInPublicCall,
///   isScreeningRoom: callType == 'screening_room',
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

  /// Indica se o usuário tem um story ativo não visto. Quando `true`, exibe
  /// anel gradiente. Ignorado quando [hasActiveCall] é `true`.
  final bool hasActiveStory;

  /// Indica se o usuário está em uma call ou projeção pública ativa.
  /// Quando `true`, exibe borda glow verde pulsante com prioridade máxima.
  final bool hasActiveCall;

  /// Indica se a call ativa é uma sala de projeção (screening room).
  /// Quando `true` e [hasActiveCall] também é `true`, usa ícone de projeção.
  final bool isScreeningRoom;

  const CosmeticAvatar({
    super.key,
    this.userId,
    this.avatarUrl,
    this.size = 40,
    this.showOnline = false,
    this.onTap,
    this.frameUrlOverride,
    this.isFrameOverrideAnimated = false,
    this.hasActiveStory = false,
    this.hasActiveCall = false,
    this.isScreeningRoom = false,
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
        hasActiveStory: hasActiveStory,
        hasActiveCall: hasActiveCall,
        isScreeningRoom: isScreeningRoom,
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
        hasActiveStory: hasActiveStory,
        hasActiveCall: hasActiveCall,
        isScreeningRoom: isScreeningRoom,
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
        hasActiveStory: hasActiveStory,
        hasActiveCall: hasActiveCall,
        isScreeningRoom: isScreeningRoom,
      ),
      loading: () => AvatarWithFrame(
        avatarUrl: avatarUrl,
        size: size,
        showOnline: showOnline,
        onTap: onTap,
        hasActiveStory: hasActiveStory,
        hasActiveCall: hasActiveCall,
        isScreeningRoom: isScreeningRoom,
      ),
      error: (_, __) => AvatarWithFrame(
        avatarUrl: avatarUrl,
        size: size,
        showOnline: showOnline,
        onTap: onTap,
        hasActiveStory: hasActiveStory,
        hasActiveCall: hasActiveCall,
        isScreeningRoom: isScreeningRoom,
      ),
    );
  }
}
