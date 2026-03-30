import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/message_model.dart';
import '../../../core/utils/responsive.dart';

/// Preview de resposta exibido acima da barra de input quando o usuário
/// seleciona "Responder" em uma mensagem.
///
/// Extraído de chat_room_screen.dart para isolar este bloco de UI.
class ChatReplyPreview extends StatelessWidget {
  final MessageModel replyingTo;
  final VoidCallback onDismiss;

  const ChatReplyPreview({
    super.key,
    required this.replyingTo,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(8), 0),
      color: context.surfaceColor,
      child: Row(
        children: [
          Container(
            width: r.s(3),
            height: r.s(32),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: r.s(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  replyingTo.author?.nickname ?? 'User',
                  style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: r.fs(12),
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  replyingTo.content ?? '',
                  style: TextStyle(
                      fontSize: r.fs(12), color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Padding(
              padding: EdgeInsets.all(r.s(8)),
              child: Icon(Icons.close_rounded,
                  size: r.s(18), color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }
}
