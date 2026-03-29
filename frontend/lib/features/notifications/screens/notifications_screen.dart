import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../config/app_theme.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/utils/responsive.dart';

/// Tela de notificações — usa o provider compartilhado com realtime,
/// paginação, contagem de não lidas e join de perfis.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final notifAsync = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: context.textPrimary, size: r.s(20)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Notificações',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () =>
                ref.read(notificationProvider.notifier).markAllAsRead(),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              margin: EdgeInsets.only(right: r.s(16)),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(r.s(20)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Text(
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
      body: notifAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: r.s(48), color: AppTheme.errorColor),
              SizedBox(height: r.s(12)),
              Text(
                'Erro ao carregar notificações',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: r.fs(15),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: r.s(8)),
              GestureDetector(
                onTap: () =>
                    ref.read(notificationProvider.notifier).refresh(),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(20), vertical: r.s(10)),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(r.s(12)),
                  ),
                  child: Text(
                    'Tentar novamente',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        data: (notifState) {
          final notifications = notifState.notifications;

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
                  SizedBox(height: r.s(6)),
                  Text(
                    'Quando alguém interagir com você, aparecerá aqui',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: r.fs(12),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () async {
              await ref.read(notificationProvider.notifier).refresh();
            },
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(r.s(16)),
              itemCount: notifications.length + (notifState.hasMore ? 1 : 0),
              separatorBuilder: (context, index) => SizedBox(height: r.s(12)),
              itemBuilder: (context, index) {
                // Loading indicator no final da lista
                if (index >= notifications.length) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: r.s(16)),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                return _NotificationTile(
                  data: notifications[index],
                  onTap: () => _handleNotificationTap(notifications[index]),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Navega para o destino correto baseado no tipo de notificação.
  void _handleNotificationTap(Map<String, dynamic> notification) {
    final notifId = notification['id'] as String?;
    final isRead = notification['is_read'] as bool? ?? false;

    // Marcar como lida
    if (!isRead && notifId != null) {
      ref.read(notificationProvider.notifier).markAsRead(notifId);
    }

    final type = notification['notification_type'] as String? ?? '';
    final targetId = notification['target_id'] as String?;

    if (targetId == null) return;

    switch (type) {
      case 'like':
      case 'comment':
      case 'mention':
        context.push('/post/$targetId');
        break;
      case 'follow':
        context.push('/user/$targetId');
        break;
      case 'community_invite':
        context.push('/community/$targetId');
        break;
      case 'chat_message':
      case 'chat_mention':
        context.push('/chat/$targetId');
        break;
      case 'dm_invite':
        // DM invites navegam para a lista de chats onde os convites aparecem
        context.push('/chats');
        break;
      case 'level_up':
      case 'achievement':
        context.push('/profile');
        break;
      case 'wall_post':
        context.push('/user/$targetId');
        break;
      default:
        break;
    }
  }
}

/// Tile individual de notificação — estilo Amino.
class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onTap;

  const _NotificationTile({required this.data, this.onTap});

  IconData _getIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.chat_bubble_rounded;
      case 'follow':
        return Icons.person_add_rounded;
      case 'mention':
      case 'chat_mention':
        return Icons.alternate_email_rounded;
      case 'community_invite':
        return Icons.group_add_rounded;
      case 'level_up':
        return Icons.arrow_upward_rounded;
      case 'achievement':
        return Icons.emoji_events_rounded;
      case 'chat_message':
        return Icons.chat_rounded;
      case 'dm_invite':
        return Icons.mail_rounded;
      case 'wall_post':
        return Icons.article_rounded;
      case 'moderation':
      case 'strike':
      case 'ban':
        return Icons.gavel_rounded;
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
      case 'chat_mention':
        return AppTheme.warningColor;
      case 'level_up':
        return AppTheme.successColor;
      case 'achievement':
        return AppTheme.warningColor;
      case 'chat_message':
        return const Color(0xFF4CAF50);
      case 'dm_invite':
        return const Color(0xFF9C27B0);
      case 'wall_post':
        return const Color(0xFF2196F3);
      case 'moderation':
      case 'strike':
      case 'ban':
        return AppTheme.errorColor;
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
      onTap: onTap,
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
            // Avatar do ator com ícone de tipo sobreposto
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
                    child:
                        Icon(_getIcon(type), color: iconColor, size: r.s(12)),
                  ),
                ),
              ],
            ),
            SizedBox(width: r.s(16)),
            // Conteúdo da notificação
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
                  Row(
                    children: [
                      Icon(
                        _getIcon(type),
                        size: r.s(11),
                        color: iconColor.withValues(alpha: 0.6),
                      ),
                      SizedBox(width: r.s(4)),
                      Text(
                        _getTypeLabel(type),
                        style: TextStyle(
                          color: iconColor.withValues(alpha: 0.7),
                          fontSize: r.fs(11),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: r.s(8)),
                      Text(
                        timeago.format(createdAt, locale: 'pt_BR'),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: r.fs(11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Indicador de não lida
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

  /// Label legível para cada tipo de notificação.
  String _getTypeLabel(String type) {
    switch (type) {
      case 'like':
        return 'Curtida';
      case 'comment':
        return 'Comentário';
      case 'follow':
        return 'Seguiu';
      case 'mention':
        return 'Menção';
      case 'chat_mention':
        return 'Menção no chat';
      case 'community_invite':
        return 'Convite';
      case 'level_up':
        return 'Level Up';
      case 'achievement':
        return 'Conquista';
      case 'chat_message':
        return 'Mensagem';
      case 'dm_invite':
        return 'Convite DM';
      case 'wall_post':
        return 'Mural';
      case 'moderation':
        return 'Moderação';
      case 'strike':
        return 'Strike';
      case 'ban':
        return 'Ban';
      default:
        return 'Notificação';
    }
  }
}
