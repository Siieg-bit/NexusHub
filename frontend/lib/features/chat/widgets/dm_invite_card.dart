import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/dm_invite_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Card que mostra um convite de DM pendente com botões aceitar/recusar.
class DmInviteCard extends ConsumerWidget {
  final Map<String, dynamic> invite;
  final VoidCallback? onResponded;

  const DmInviteCard({
    super.key,
    required this.invite,
    this.onResponded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final thread = invite['chat_threads'] as Map<String, dynamic>? ?? {};
    final senderProfile = invite['sender_profile'] as Map<String, dynamic>? ?? {};
    final threadId = invite['thread_id'] as String? ?? '';
    final senderId = invite['sender_id'] as String? ??
        senderProfile['id'] as String? ??
        senderProfile['user_id'] as String? ??
        thread['host_id'] as String? ??
        '';
    final senderName = ((senderProfile['nickname'] as String?)?.trim().isNotEmpty ?? false)
        ? (senderProfile['nickname'] as String).trim()
        : ((thread['last_message_author'] as String?)?.trim().isNotEmpty ?? false)
            ? (thread['last_message_author'] as String).trim()
            : s.someone;
    final senderAvatar = senderProfile['icon_url'] as String?;
    final preview = thread['last_message_preview'] as String?;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(r.s(14)),
        onTap: threadId.isEmpty ? null : () => context.push('/chat/$threadId'),
        child: Container(
          margin: EdgeInsets.only(bottom: r.s(12)),
          padding: EdgeInsets.all(r.s(16)),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(14)),
            border: Border.all(
              color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CosmeticAvatar(
                    userId: senderId,
                    avatarUrl: senderAvatar,
                    size: r.s(42),
                  ),
                  Positioned(
                    right: -r.s(2),
                    bottom: -r.s(2),
                    child: Container(
                      padding: EdgeInsets.all(r.s(4)),
                      decoration: BoxDecoration(
                        color: context.nexusTheme.accentPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.surfaceColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(Icons.mail_rounded,
                          color: Colors.white, size: r.s(10)),
                    ),
                  ),
                ],
              ),
              SizedBox(width: r.s(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Convite de $senderName',
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (preview != null && preview.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: r.s(2)),
                        child: Text(
                          preview,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: r.fs(12),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      Padding(
                        padding: EdgeInsets.only(top: r.s(2)),
                        child: Text(
                          'Toque para ver a conversa antes de aceitar.',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: r.fs(12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r.s(12)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: threadId.isEmpty
                      ? null
                      : () => context.push('/chat/$threadId'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: context.nexusTheme.accentPrimary
                          .withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.s(10))),
                    padding: EdgeInsets.symmetric(vertical: r.s(10)),
                  ),
                  child: Text('Ver mensagens',
                      style: TextStyle(
                          color: context.nexusTheme.accentPrimary,
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w600)),
                ),
              ),
              SizedBox(width: r.s(8)),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final service = ref.read(dmInviteProvider);
                    final success = await service.declineInvite(threadId);
                    if (success) {
                      ref.invalidate(pendingDmInvitesProvider);
                      onResponded?.call();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: (Colors.grey[700] ?? Colors.grey)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.s(10))),
                    padding: EdgeInsets.symmetric(vertical: r.s(10)),
                  ),
                  child: Text(s.decline,
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: r.fs(13))),
                ),
              ),
              SizedBox(width: r.s(8)),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final service = ref.read(dmInviteProvider);
                    final success = await service.acceptInvite(threadId);
                    if (success) {
                      ref.invalidate(pendingDmInvitesProvider);
                      onResponded?.call();
                      if (context.mounted) {
                        context.push('/chat/$threadId');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.nexusTheme.accentPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.s(10))),
                    padding: EdgeInsets.symmetric(vertical: r.s(10)),
                  ),
                  child: Text(s.accept,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }
}
