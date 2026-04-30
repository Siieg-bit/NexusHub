import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/message_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

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
  moderate,
}

/// Ação de moderação rápida selecionada no ModerationQuickSheet.
enum ModerationQuickAction {
  warn,
  mute,
  deleteMessage,
  ban,
}

/// Bottom sheet de ações de mensagem (long press) — Estilo Amino.
///
/// Retorna a ação selecionada via Navigator.pop para que o caller
/// execute a lógica correspondente.
///
/// [canModerate] — exibe a opção "Moderar" para host, co-host e staff da
/// comunidade. O caller é responsável por passar o valor correto.
class ChatMessageActionsSheet extends ConsumerWidget {
  final MessageModel message;
  final void Function(String emoji) onReaction;
  final String? hostId;
  final List<String> coHostIds;
  final bool canModerate;

  const ChatMessageActionsSheet({
    super.key,
    required this.message,
    required this.onReaction,
    this.hostId,
    this.coHostIds = const [],
    this.canModerate = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
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
            children: [
              '❤️', '😂', '😮', '😢', '👍', '👎'
            ]
                .map((emoji) => GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        onReaction(emoji);
                      },
                      child: Container(
                        padding: EdgeInsets.all(r.s(10)),
                        decoration: BoxDecoration(
                          color: context.nexusTheme.surfacePrimary,
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
          _actionTile(context, r, Icons.reply_rounded, s.reply, () {
            Navigator.pop(context, ChatMessageAction.reply);
          }),

          // Copiar
          _actionTile(context, r, Icons.copy_rounded, s.copy, () {
            Clipboard.setData(ClipboardData(text: message.content ?? ''));
            Navigator.pop(context, ChatMessageAction.copy);
          }),

          // Editar (só autor + só texto)
          if (isMe && isTextType)
            _actionTile(context, r, Icons.edit_rounded, s.edit, () {
              Navigator.pop(context, ChatMessageAction.edit);
            }),

          // Encaminhar
          _actionTile(context, r, Icons.forward_rounded, 'Encaminhar', () {
            Navigator.pop(context, ChatMessageAction.forward);
          }),

          // Fixar (apenas host, co-hosts ou team)
          if (_canPin())
            _actionTile(context, r, Icons.push_pin_rounded, 'Fixar Mensagem',
                () {
              Navigator.pop(context, ChatMessageAction.pin);
            }),

          // Apagar para mim
          _actionTile(
              context, r, Icons.visibility_off_rounded, 'Apagar para mim', () {
            Navigator.pop(context, ChatMessageAction.deleteForMe);
          }, isDestructive: true),

          // Apagar para todos (só autor)
          if (isMe)
            _actionTile(
                context, r, Icons.delete_forever_rounded, 'Apagar para todos',
                () {
              Navigator.pop(context, ChatMessageAction.deleteForAll);
            }, isDestructive: true),

          // Denunciar (só para mensagens de outros)
          if (!isMe)
            _actionTile(context, r, Icons.flag_rounded, s.report, () {
              Navigator.pop(context, ChatMessageAction.report);
            }, isDestructive: true),

          // ── Moderação (staff only, mensagens de outros) ──────────────────
          if (canModerate && !isMe) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: r.s(6)),
              child: Divider(
                color: Colors.white.withValues(alpha: 0.08),
                height: 1,
              ),
            ),
            _actionTile(
              context,
              r,
              Icons.shield_rounded,
              'Moderar usuário',
              () => Navigator.pop(context, ChatMessageAction.moderate),
              isDestructive: false,
              isMod: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionTile(
    BuildContext context,
    Responsive r,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
    bool isMod = false,
  }) {
    final Color color;
    if (isMod) {
      color = const Color(0xFF7C4DFF);
    } else if (isDestructive) {
      color = context.nexusTheme.error;
    } else {
      color = Colors.grey[400]!;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: r.s(12)),
        child: Row(
          children: [
            Icon(icon, color: color, size: r.s(20)),
            SizedBox(width: r.s(12)),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: r.fs(14),
                fontWeight: isMod ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (isMod) ...[
              const Spacer(),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(8), vertical: r.s(3)),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.s(12)),
                  border: Border.all(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  'STAFF',
                  style: TextStyle(
                    color: const Color(0xFF7C4DFF),
                    fontSize: r.fs(9),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _canPin() {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;
    return userId == hostId || coHostIds.contains(userId);
  }

  /// Mostra o bottom sheet de ações e retorna a ação selecionada.
  static Future<ChatMessageAction?> show(
    BuildContext context, {
    required MessageModel message,
    required void Function(String emoji) onReaction,
    String? hostId,
    List<String> coHostIds = const [],
    bool canModerate = false,
  }) {
    return showModalBottomSheet<ChatMessageAction>(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: context.surfaceColor.withValues(alpha: 0.7),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: ChatMessageActionsSheet(
              message: message,
              onReaction: onReaction,
              hostId: hostId,
              coHostIds: coHostIds,
              canModerate: canModerate,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ModerationQuickSheet — Bottom sheet de ações rápidas de moderação
// Abre após selecionar "Moderar usuário" no ChatMessageActionsSheet.
// ============================================================================

class ModerationQuickSheet extends StatelessWidget {
  final String targetUserId;
  final String targetUserNickname;
  final String messageId;
  final String? communityId;

  const ModerationQuickSheet({
    super.key,
    required this.targetUserId,
    required this.targetUserNickname,
    required this.messageId,
    this.communityId,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;

    final actions = [
      _ModAction(
        icon: Icons.warning_amber_rounded,
        label: 'Avisar',
        description: 'Enviar um aviso formal ao usuário',
        color: const Color(0xFFFFA726),
        action: ModerationQuickAction.warn,
      ),
      _ModAction(
        icon: Icons.volume_off_rounded,
        label: 'Silenciar',
        description: 'Impedir temporariamente de enviar mensagens',
        color: const Color(0xFF42A5F5),
        action: ModerationQuickAction.mute,
      ),
      _ModAction(
        icon: Icons.delete_sweep_rounded,
        label: 'Remover mensagem',
        description: 'Apagar esta mensagem para todos',
        color: const Color(0xFF78909C),
        action: ModerationQuickAction.deleteMessage,
      ),
      _ModAction(
        icon: Icons.block_rounded,
        label: 'Banir da comunidade',
        description: 'Remover e impedir o acesso à comunidade',
        color: const Color(0xFFF44336),
        action: ModerationQuickAction.ban,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: r.s(36),
                height: r.s(4),
                margin: EdgeInsets.only(bottom: r.s(16)),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header com badge STAFF
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(r.s(8)),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(r.s(10)),
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    color: const Color(0xFF7C4DFF),
                    size: r.s(18),
                  ),
                ),
                SizedBox(width: r.s(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Moderar usuário',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: r.fs(15),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '@$targetUserNickname',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: r.fs(12),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(8), vertical: r.s(3)),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(r.s(12)),
                    border: Border.all(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'STAFF',
                    style: TextStyle(
                      color: const Color(0xFF7C4DFF),
                      fontSize: r.fs(9),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: r.s(16)),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            SizedBox(height: r.s(8)),

            // Ações
            ...actions.map((a) => _buildActionTile(context, r, theme, a)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    Responsive r,
    NexusThemeData theme,
    _ModAction a,
  ) {
    return InkWell(
      onTap: () => Navigator.pop(context, a.action),
      borderRadius: BorderRadius.circular(r.s(12)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: r.s(10), horizontal: r.s(4)),
        child: Row(
          children: [
            Container(
              width: r.s(40),
              height: r.s(40),
              decoration: BoxDecoration(
                color: a.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(r.s(10)),
              ),
              child: Icon(a.icon, color: a.color, size: r.s(20)),
            ),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.label,
                    style: TextStyle(
                      color: a.action == ModerationQuickAction.ban
                          ? a.color
                          : theme.textPrimary,
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    a.description,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: r.fs(11),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.textHint,
              size: r.s(18),
            ),
          ],
        ),
      ),
    );
  }

  /// Mostra o ModerationQuickSheet e retorna a ação selecionada.
  static Future<ModerationQuickAction?> show(
    BuildContext context, {
    required String targetUserId,
    required String targetUserNickname,
    required String messageId,
    String? communityId,
  }) {
    return showModalBottomSheet<ModerationQuickAction>(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ModerationQuickSheet(
        targetUserId: targetUserId,
        targetUserNickname: targetUserNickname,
        messageId: messageId,
        communityId: communityId,
      ),
    );
  }
}

class _ModAction {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final ModerationQuickAction action;

  const _ModAction({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.action,
  });
}
