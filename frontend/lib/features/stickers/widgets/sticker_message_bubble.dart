import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/sticker_model.dart';
import '../providers/sticker_providers.dart';
import '../screens/sticker_pack_screen.dart';

/// Widget para exibir um sticker dentro de uma mensagem ou comentário.
/// Ao segurar, exibe opções: favoritar, salvar pack, ver pack.
class StickerMessageBubble extends ConsumerWidget {
  final String stickerId;
  final String stickerUrl;
  final String stickerName;
  final String? packId;
  final bool isSentByMe;
  final double size;

  const StickerMessageBubble({
    super.key,
    required this.stickerId,
    required this.stickerUrl,
    this.stickerName = '',
    this.packId,
    this.isSentByMe = false,
    this.size = 120,
  });

  /// Cria a partir de um mapa de payload de mensagem.
  factory StickerMessageBubble.fromPayload(
    Map<String, dynamic> payload, {
    bool isSentByMe = false,
    double size = 120,
  }) {
    return StickerMessageBubble(
      stickerId: payload['sticker_id'] as String? ?? '',
      stickerUrl: payload['sticker_url'] as String? ?? '',
      stickerName: payload['sticker_name'] as String? ?? '',
      packId: payload['pack_id'] as String?,
      isSentByMe: isSentByMe,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final pickerState = ref.watch(stickerPickerProvider);
    final isFav = pickerState.isFavorite(stickerId);

    return GestureDetector(
      onLongPress: () => _showOptions(context, ref, isFav),
      child: Stack(
        children: [
          // Imagem do sticker
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: stickerUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: stickerUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(r.s(12)),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: r.s(20),
                          height: r.s(20),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(r.s(12)),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: Colors.grey[700],
                          size: r.s(32),
                        ),
                      ),
                    ),
                  )
                : Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(r.s(12)),
                    ),
                    child: Center(
                      child: Text(
                        stickerName.isNotEmpty ? stickerName : '?',
                        style: TextStyle(fontSize: r.fs(14)),
                      ),
                    ),
                  ),
          ),

          // Indicador de favorito
          if (isFav)
            Positioned(
              top: r.s(4),
              right: r.s(4),
              child: Container(
                padding: EdgeInsets.all(r.s(3)),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  size: r.s(10),
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref, bool isFav) {
    final r = context.r;
    final pickerState = ref.read(stickerPickerProvider);
    final isPackSaved = packId != null && pickerState.isPackSaved(packId!);

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: r.s(36),
                height: r.s(4),
                margin: EdgeInsets.only(bottom: r.s(12)),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(r.s(2)),
                ),
              ),
            ),

            // Preview do sticker
            if (stickerUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: stickerUrl,
                height: r.s(100),
                fit: BoxFit.contain,
              ),
            if (stickerName.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: r.s(8), bottom: r.s(4)),
                child: Text(
                  stickerName,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: r.fs(14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

            Divider(color: Colors.white.withValues(alpha: 0.05), height: r.s(20)),

            // Favoritar
            ListTile(
              leading: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? AppTheme.primaryColor : context.textPrimary,
                size: r.s(20),
              ),
              title: Text(
                isFav ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
                style: TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final sticker = StickerModel(
                  id: stickerId,
                  packId: packId ?? '',
                  name: stickerName,
                  imageUrl: stickerUrl,
                );
                await ref.read(stickerPickerProvider.notifier).toggleFavorite(sticker);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isFav ? 'Removido dos favoritos' : 'Adicionado aos favoritos!'),
                      backgroundColor: isFav ? Colors.grey[700] : AppTheme.primaryColor,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),

            // Salvar pack (apenas se não for o dono)
            if (packId != null && !isSentByMe)
              ListTile(
                leading: Icon(
                  isPackSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isPackSaved ? AppTheme.accentColor : context.textPrimary,
                  size: r.s(20),
                ),
                title: Text(
                  isPackSaved ? 'Pack já salvo' : 'Salvar pack de figurinhas',
                  style: TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
                ),
                subtitle: isPackSaved
                    ? null
                    : Text(
                        'Salve o pack completo para usar nas suas mensagens',
                        style: TextStyle(color: Colors.grey[600], fontSize: r.fs(12)),
                      ),
                onTap: isPackSaved
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        final saved = await ref
                            .read(stickerPickerProvider.notifier)
                            .toggleSavePack(StickerPackModel(
                              id: packId!,
                              name: '',
                              createdAt: DateTime.now(),
                            ));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(saved ? 'Pack salvo!' : 'Pack removido dos salvos'),
                              backgroundColor: saved ? AppTheme.primaryColor : Colors.grey[700],
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
              ),

            // Ver pack
            if (packId != null)
              ListTile(
                leading: Icon(
                  Icons.collections_rounded,
                  color: context.textPrimary,
                  size: r.s(20),
                ),
                title: Text(
                  'Ver pack completo',
                  style: TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StickerPackScreen(packId: packId!, isOwner: isSentByMe),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
