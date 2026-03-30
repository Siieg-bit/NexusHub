import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/message_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Ações disponíveis ao fazer long-press em uma mensagem.
enum ChatMessageAction {
  reply,
  copy,
  edit,
  forward,
  pin,
  deleteForMe,
  deleteForAll,
  report,
}

/// Bottom sheet de ações de mensagem (long press) — Estilo Amino.
///
/// Retorna a ação selecionada via Navigator.pop para que o caller
/// execute a lógica correspondente.
///
/// Extraído de chat_room_screen.dart para isolar a UI de ações.
class ChatMessageActionsSheet extends StatelessWidget {
  final MessageModel message;
  final void Function(String emoji) onReaction;

  const ChatMessageActionsSheet({
    super.key,
    required this.message,
    required this.onReaction,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final isMe = message.authorId == SupabaseService.currentUserId;
    final isTextType = message.type == 'text' || message.type == 'share_url';

    return Padding(
      padding: EdgeInsets.all(r.s(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: r.s(36),
            height: r.s(4),
            margin: EdgeInsets.only(bottom: r.s(16)),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Quick reactions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['\u2764\uFE0F', '\uD83D\uDE02', '\uD83D\uDE2E', '\uD83D\uDE22', '\uD83D\uDC4D', '\uD83D\uDC4E']
                .map((emoji) => GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        onReaction(emoji);
                      },
                      child: Container(
                        padding: EdgeInsets.all(r.s(10)),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          shape: BoxShape.circle,
                        ),
                        child:
                            Text(emoji, style: TextStyle(fontSize: r.fs(22))),
                      ),
                    ))
                .toList(),
          ),
          SizedBox(height: r.s(16)),
          // Responder
          _actionTile(context, r, Icons.reply_rounded, 'Responder', () {
            Navigator.pop(context, ChatMessageAction.reply);
          }),
          // Copiar
          _actionTile(context, r, Icons.copy_rounded, 'Copiar', () {
            Clipboard.setData(ClipboardData(text: message.content ?? ''));
            Navigator.pop(context, ChatMessageAction.copy);
          }),
          // Editar (só autor + só texto)
          if (isMe && isTextType)
            _actionTile(context, r, Icons.edit_rounded, 'Editar', () {
              Navigator.pop(context, ChatMessageAction.edit);
            }),
          // Encaminhar
          _actionTile(context, r, Icons.forward_rounded, 'Encaminhar', () {
            Navigator.pop(context, ChatMessageAction.forward);
          }),
          // Fixar
          _actionTile(context, r, Icons.push_pin_rounded, 'Fixar Mensagem', () {
            Navigator.pop(context, ChatMessageAction.pin);
          }),
          // Apagar para mim
          _actionTile(context, r, Icons.visibility_off_rounded, 'Apagar para mim', () {
            Navigator.pop(context, ChatMessageAction.deleteForMe);
          }, isDestructive: true),
          // Apagar para todos (só autor)
          if (isMe)
            _actionTile(context, r, Icons.delete_forever_rounded, 'Apagar para todos', () {
              Navigator.pop(context, ChatMessageAction.deleteForAll);
            }, isDestructive: true),
          // Denunciar (só para mensagens de outros)
          if (!isMe)
            _actionTile(context, r, Icons.flag_rounded, 'Denunciar', () {
              Navigator.pop(context, ChatMessageAction.report);
            }, isDestructive: true),
        ],
      ),
    );
  }

  Widget _actionTile(BuildContext context, Responsive r, IconData icon,
      String label, VoidCallback onTap,
      {bool isDestructive = false}) {
    final color = isDestructive ? AppTheme.errorColor : Colors.grey[400];
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: r.s(12)),
        child: Row(
          children: [
            Icon(icon, color: color, size: r.s(20)),
            SizedBox(width: r.s(12)),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: r.fs(14), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  /// Mostra o bottom sheet de ações e retorna a ação selecionada.
  static Future<ChatMessageAction?> show(
    BuildContext context, {
    required MessageModel message,
    required void Function(String emoji) onReaction,
  }) {
    return showModalBottomSheet<ChatMessageAction>(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChatMessageActionsSheet(
        message: message,
        onReaction: onReaction,
      ),
    );
  }
}
