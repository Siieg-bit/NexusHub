import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Provider para notificações do usuário.
final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
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
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          TextButton(
            onPressed: () => _markAllAsRead(ref),
            child: const Text('Marcar todas', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_rounded, size: 64, color: AppTheme.textHint),
                  SizedBox(height: 16),
                  Text('Nenhuma notificação',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) => _NotificationTile(data: notifications[index]),
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
      case 'like': return Icons.favorite_rounded;
      case 'comment': return Icons.chat_bubble_rounded;
      case 'follow': return Icons.person_add_rounded;
      case 'mention': return Icons.alternate_email_rounded;
      case 'community_invite': return Icons.group_add_rounded;
      case 'level_up': return Icons.arrow_upward_rounded;
      case 'achievement': return Icons.emoji_events_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'like': return AppTheme.errorColor;
      case 'comment': return AppTheme.accentColor;
      case 'follow': return AppTheme.primaryColor;
      case 'mention': return AppTheme.warningColor;
      case 'level_up': return AppTheme.successColor;
      case 'achievement': return AppTheme.warningColor;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = data['notification_type'] as String? ?? 'general';
    final isRead = data['is_read'] as bool? ?? false;
    final actor = data['profiles'] as Map<String, dynamic>?;
    final createdAt = DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now();

    return Container(
      color: isRead ? null : AppTheme.primaryColor.withValues(alpha: 0.05),
      child: ListTile(
        onTap: () {
          // Marcar como lida e navegar
          if (!isRead) {
            SupabaseService.table('notifications')
                .update({'is_read': true})
                .eq('id', data['id']);
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
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _getColor(type).withValues(alpha: 0.15),
              backgroundImage: actor?['icon_url'] != null
                  ? CachedNetworkImageProvider(actor!['icon_url'] as String)
                  : null,
              child: actor?['icon_url'] == null
                  ? Icon(_getIcon(type), color: _getColor(type), size: 20)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppTheme.scaffoldBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIcon(type), color: _getColor(type), size: 12),
              ),
            ),
          ],
        ),
        title: Text(
          data['content'] as String? ?? 'Notificação',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          timeago.format(createdAt, locale: 'pt_BR'),
          style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
        ),
        trailing: !isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }
}
