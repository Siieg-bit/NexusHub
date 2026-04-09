import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_providers.dart';
import '../../../core/l10n/locale_provider.dart';

// =============================================================================
// WALL TAB — Mural de mensagens
// =============================================================================

class ProfileWallTab extends ConsumerWidget {
  final String userId;
  final TextEditingController wallController;

  const ProfileWallTab({
    super.key,
    required this.userId,
    required this.wallController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final wallAsync = ref.watch(userWallProvider(userId));
    final isOwnWall = userId == SupabaseService.currentUserId;

    return Column(
      children: [
        // Input para nova mensagem
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: wallController,
                  style:
                      TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
                  decoration: InputDecoration(
                    hintText: s.writeOnTheWall,
                    hintStyle:
                        TextStyle(color: Colors.grey[600], fontSize: r.fs(14)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: r.s(12), vertical: r.s(8)),
                  ),
                ),
              ),
              SizedBox(width: r.s(8)),
              GestureDetector(
                onTap: () => _postMessage(ref, context),
                child: Container(
                  padding: EdgeInsets.all(r.s(8)),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Icon(Icons.send_rounded,
                      color: Colors.white, size: r.s(18)),
                ),
              ),
            ],
          ),
        ),
        // Lista de mensagens
        Expanded(
          child: wallAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.accentColor, strokeWidth: 2),
            ),
            error: (_, __) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.failedToLoadData,
                      style: TextStyle(color: Colors.grey[500])),
                  SizedBox(height: r.s(12)),
                  GestureDetector(
                    onTap: () => ref.invalidate(userWallProvider(userId)),
                    child: Icon(Icons.refresh_rounded,
                        color: Colors.grey[500], size: r.s(32)),
                  ),
                ],
              ),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Text(s.noWallComments,
                      style: TextStyle(color: Colors.grey[500])),
                );
              }

              return RefreshIndicator(
                color: AppTheme.primaryColor,
                onRefresh: () async {
                  ref.invalidate(userProfileProvider);
                  ref.invalidate(equippedItemsProvider);
                  ref.invalidate(currentUserProvider);
                  ref.invalidate(userLinkedCommunitiesProvider);
                  ref.invalidate(userPostsProvider);
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: ListView.builder(
                  padding: EdgeInsets.all(r.s(16)),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final profile = (msg['author'] ?? msg['profiles'])
                            as Map<String, dynamic>? ??
                        {};
                    final authorId = msg['author_id'] as String? ?? '';
                    final createdAt =
                        DateTime.tryParse(msg['created_at'] as String? ?? '') ??
                            DateTime.now();
                    final canDelete =
                        isOwnWall || authorId == SupabaseService.currentUserId;

                    return Container(
                      margin: EdgeInsets.only(bottom: r.s(12)),
                      padding: EdgeInsets.all(r.s(14)),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(r.s(12)),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => context.push('/user/$authorId'),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppTheme.primaryColor
                                      .withValues(alpha: 0.2),
                                  backgroundImage: profile['icon_url'] != null
                                      ? CachedNetworkImageProvider(
                                          profile['icon_url'] as String? ?? '')
                                      : null,
                                  child: profile['icon_url'] == null
                                      ? Text(
                                          ((profile['nickname'] as String?) ??
                                                  '?')[0]
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: r.fs(12),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              SizedBox(width: r.s(8)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile['nickname'] as String? ??
                                          s.user,
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: r.fs(13),
                                      ),
                                    ),
                                    Text(
                                      _timeAgo(createdAt),
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: r.fs(11)),
                                    ),
                                  ],
                                ),
                              ),
                              if (canDelete)
                                GestureDetector(
                                  onTap: () => _deleteMessage(
                                      ref, msg['id'] as String? ?? ''),
                                  child: Icon(Icons.close_rounded,
                                      color: Colors.grey[600], size: r.s(16)),
                                ),
                            ],
                          ),
                          SizedBox(height: r.s(8)),
                          Text(
                            msg['content'] as String? ?? '',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: r.fs(13),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _postMessage(WidgetRef ref, BuildContext context) async {
    final s = ref.read(stringsProvider);
    final text = wallController.text.trim();
    if (text.isEmpty) return;
    try {
      await SupabaseService.table('comments').insert({
        'profile_wall_id': userId,
        'author_id': SupabaseService.currentUserId,
        'content': text,
      });
      wallController.clear();
      ref.invalidate(userWallProvider(userId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.anErrorOccurredTryAgain)),
        );
      }
    }
  }

  Future<void> _deleteMessage(WidgetRef ref, String messageId) async {
    try {
      await SupabaseService.table('comments').delete().eq('id', messageId);
      ref.invalidate(userWallProvider(userId));
    } catch (e) {
      debugPrint('[profile_wall_tab] Erro: $e');
    }
  }

  String _timeAgo(DateTime dt) {
    final s = ref.read(stringsProvider);
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 365) return '${diff.inDays ~/ 365}a';
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}m';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}min';
    return s.now;
  }
}
