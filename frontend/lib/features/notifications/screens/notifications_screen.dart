import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Provider para notificações do usuário.
final notificationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final response = await SupabaseService.table('notifications')
      .select('*, profiles!notifications_actor_id_fkey(nickname, icon_url)')
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(50);

  return (response as List).map((e) => e as Map<String, dynamic>).toList();
});

/// Tela de notificações.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        title: const Text(
          'Notificações',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => _markAllAsRead(ref),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              margin: EdgeInsets.only(right: r.s(16)),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(r.s(20)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: const Text(
                'Marcar todas',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (error, _) => Center(
          child: Text(
            'Erro: $error',
            style: const TextStyle(color: AppTheme.errorColor),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_rounded,
                    size: r.s(64),
                    color: Colors.grey[600],
                  ),
                  SizedBox(height: r.s(16)),
                  Text(
                    'Nenhuma notificação',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: r.fs(16),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              await Future.delayed(const Duration(milliseconds: 300));
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(r.s(16)),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => SizedBox(height: r.s(12)),
              itemBuilder: (context, index) =>
                  _NotificationTile(data: notifications[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _markAllAsRead(WidgetRef ref) async {
    try {
      await SupabaseService.table('notifications')
          .update({'is_read': true})
          .eq('user_id', SupabaseService.currentUserId!)
          .eq('is_read', false);
      ref.invalidate(notificationsProvider);
    } catch (_) {}
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const _NotificationTile({required this.data});

  IconData _getIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.chat_bubble_rounded;
      case 'follow':
        return Icons.person_add_rounded;
      case 'mention':
        return Icons.alternate_email_rounded;
      case 'community_invite':
        return Icons.group_add_rounded;
      case 'level_up':
        return Icons.arrow_upward_rounded;
      case 'achievement':
        return Icons.emoji_events_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'like':
        return AppTheme.errorColor;
      case 'comment':
        return AppTheme.accentColor;
      case 'follow':
        return AppTheme.primaryColor;
      case 'mention':
        return AppTheme.warningColor;
      case 'level_up':
        return AppTheme.successColor;
      case 'achievement':
        return AppTheme.warningColor;
      default:
        return Colors.grey[500]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final type = data['notification_type'] as String? ?? 'general';
    final isRead = data['is_read'] as bool? ?? false;
    final actor = data['profiles'] as Map<String, dynamic>?;
    final createdAt = DateTime.tryParse(data['created_at'] as String? ?? '') ??
        DateTime.now();

    final iconColor = _getColor(type);

    return GestureDetector(
      onTap: () {
        // Marcar como lida e navegar
        if (!isRead) {
          SupabaseService.table('notifications')
              .update({'is_read': true}).eq('id', data['id']);
        }
        // Navegar baseado no tipo
        final targetId = data['target_id'] as String?;
        if (targetId != null) {
          switch (type) {
            case 'like':
            case 'comment':
              context.push('/post/$targetId');
              break;
            case 'follow':
              context.push('/user/$targetId');
              break;
            case 'community_invite':
              context.push('/community/$targetId');
              break;
          }
        }
      },
      child: Container(
        padding: EdgeInsets.all(r.s(16)),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(
            color: isRead
                ? Colors.white.withValues(alpha: 0.05)
                : AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
          boxShadow: isRead
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: r.s(48),
                  height: r.s(48),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor.withValues(alpha: 0.15),
                    image: actor?['icon_url'] != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(
                                actor!['icon_url'] as String),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: actor?['icon_url'] == null
                      ? Icon(_getIcon(type), color: iconColor, size: r.s(24))
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(r.s(4)),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.surfaceColor,
                        width: 2,
                      ),
                    ),
                    child: Icon(_getIcon(type), color: iconColor, size: r.s(12)),
                  ),
                ),
              ],
            ),
            SizedBox(width: r.s(16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['content'] as String? ?? 'Notificação',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: r.fs(14),
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: r.s(6)),
                  Text(
                    timeago.format(createdAt, locale: 'pt_BR'),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: r.fs(12),
                    ),
                  ),
                ],
              ),
            ),
            if (!isRead) ...[
              SizedBox(width: r.s(12)),
              Container(
                width: r.s(10),
                height: r.s(10),
                margin: EdgeInsets.only(top: r.s(6)),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
