import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Botão unificado para o input bar de comentários.
/// Ao ser tocado, abre um menu popup com as opções:
/// - Emoji (abre o emoji picker)
/// - Figurinha (abre o sticker picker)
/// - Mídia (abre o seletor de imagem/vídeo)
class CommentMediaMenuButton extends StatelessWidget {
  final bool isUploadingMedia;
  final bool showEmojiPicker;
  final VoidCallback onToggleEmoji;
  final Future<void> Function() onOpenSticker;
  final VoidCallback? onPickMedia;

  const CommentMediaMenuButton({
    super.key,
    required this.isUploadingMedia,
    required this.showEmojiPicker,
    required this.onToggleEmoji,
    required this.onOpenSticker,
    required this.onPickMedia,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: SizedBox(
        width: r.s(30),
        height: r.s(30),
        child: Icon(
          showEmojiPicker
              ? Icons.add_reaction
              : Icons.add_reaction_outlined,
          size: r.s(22),
          color: showEmojiPicker
              ? context.nexusTheme.accentPrimary
              : Colors.grey[500],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final r = context.r;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      elevation: 8,
      color: const Color(0xFF1A2332),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'emoji',
          padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(4)),
          child: Row(
            children: [
              Icon(Icons.emoji_emotions_outlined,
                  color: Colors.amber[400], size: r.s(20)),
              SizedBox(width: r.s(10)),
              Text(
                'Emoji',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.s(14),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'sticker',
          padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(4)),
          child: Row(
            children: [
              Icon(Icons.sticky_note_2_outlined,
                  color: Colors.purple[300], size: r.s(20)),
              SizedBox(width: r.s(10)),
              Text(
                'Figurinha',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.s(14),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'media',
          enabled: !isUploadingMedia,
          padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(4)),
          child: Row(
            children: [
              isUploadingMedia
                  ? SizedBox(
                      width: r.s(20),
                      height: r.s(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.nexusTheme.accentPrimary,
                      ),
                    )
                  : Icon(Icons.perm_media_outlined,
                      color: Colors.blue[300], size: r.s(20)),
              SizedBox(width: r.s(10)),
              Text(
                'Mídia',
                style: TextStyle(
                  color: isUploadingMedia ? Colors.grey[600] : Colors.white,
                  fontSize: r.s(14),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'emoji') {
        onToggleEmoji();
      } else if (value == 'sticker') {
        onOpenSticker();
      } else if (value == 'media' && onPickMedia != null) {
        onPickMedia!();
      }
    });
  }
}
