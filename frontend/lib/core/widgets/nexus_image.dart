import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:blurhash_dart/blurhash_dart.dart' as bh;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// ============================================================================
/// NexusImage — Substituto do CachedNetworkImage com suporte a BlurHash.
///
/// Quando [blurhash] é fornecido, exibe um placeholder visual gerado pelo
/// BlurHash enquanto a imagem real é baixada. Isso elimina os "quadrados
/// cinzas" de carregamento, melhorando significativamente a percepção de
/// velocidade do app.
///
/// Uso:
/// ```dart
/// NexusImage(
///   imageUrl: post.mediaUrl,
///   blurhash: post.mediaBlurhash,
///   width: double.infinity,
///   fit: BoxFit.cover,
/// )
/// ```
/// ============================================================================
class NexusImage extends StatelessWidget {
  final String imageUrl;
  final String? blurhash;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;

  const NexusImage({
    super.key,
    required this.imageUrl,
    this.blurhash,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = _buildPlaceholder(context);

    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: context.nexusTheme.surfaceSecondary,
            child: Icon(
              Icons.broken_image_rounded,
              color: context.nexusTheme.textHint,
            ),
          ),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (blurhash == null || blurhash!.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: context.nexusTheme.surfaceSecondary,
        child: Center(
          child: CircularProgressIndicator(
            color: context.nexusTheme.accentPrimary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    try {
      // Decodificar BlurHash para uma imagem 32×32 usando o pacote `image`.
      // IMPORTANTE: MemoryImage espera bytes codificados (PNG/JPEG), não pixels
      // raw RGBA. Por isso codificamos o resultado como PNG antes de passar.
      final blurImage = bh.BlurHash.decode(blurhash!).toImage(32, 32);
      final Uint8List pngBytes =
          Uint8List.fromList(img.encodePng(blurImage));
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          image: DecorationImage(
            image: MemoryImage(pngBytes),
            fit: fit,
          ),
        ),
      );
    } catch (_) {
      // Fallback para placeholder simples se o BlurHash for inválido
      return Container(
        width: width,
        height: height,
        color: context.nexusTheme.surfaceSecondary,
      );
    }
  }
}
