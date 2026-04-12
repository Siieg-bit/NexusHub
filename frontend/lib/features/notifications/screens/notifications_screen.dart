import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../config/app_theme.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../config/nexus_theme_extension.dart';

// =============================================================================
// TELA DE ALERTAS — Estilo Amino Apps
// =============================================================================

class NotificationsScreen extends ConsumerStatefulWidget {
  final String? communityId;

  const NotificationsScreen({super.key, this.communityId});

  bool get isCommunityScoped => communityId != null;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();
  Timer? _scrollDebounce;
  final Set<String> _acceptingInviteIds = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (_scrollDebounce?.isActive ?? false) return;
      _scrollDebounce = Timer(const Duration(milliseconds: 100), () {
        if (widget.isCommunityScoped) {
          ref
              .read(communityNotificationProvider(widget.communityId!).notifier)
              .loadMore();
        } else {
          ref.read(notificationProvider.notifier).loadMore();
        }
      });
    }
  }

  Future<void> _confirmClearAll() async {
    final s = getStrings();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Limpar todos os alertas?',
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: Text(
          s.actionCannotBeUndone,
          style: TextStyle(color: context.nexusTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel,
                style: TextStyle(color: context.nexusTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.clear,
                style: TextStyle(
                    color: context.nexusTheme.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (widget.isCommunityScoped) {
        await ref
            .read(communityNotificationProvider(widget.communityId!).notifier)
            .deleteAll();
      } else {
        await ref.read(notificationProvider.notifier).deleteAll();
      }
    }
  }

  void _onCategoryChanged(NotificationCategory category) {
    if (widget.isCommunityScoped) {
      ref
          .read(communityNotificationProvider(widget.communityId!).notifier)
          .setCategory(category);
    } else {
      ref.read(notificationProvider.notifier).setCategory(category);
    }
  }

  Future<void> _deleteNotification(String id) async {
    if (widget.isCommunityScoped) {
      await ref
          .read(communityNotificationProvider(widget.communityId!).notifier)
          .deleteNotification(id);
    } else {
      await ref.read(notificationProvider.notifier).deleteNotification(id);
    }
  }

  Map<String, dynamic> _notificationData(Map<String, dynamic> notification) {
    final payload = notification['data'];
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return <String, dynamic>{};
  }

  String? _inviteCodeFromNotification(Map<String, dynamic> notification) {
    final payload = _notificationData(notification);
    final inviteCode = payload['invite_code'] as String?;
    if (inviteCode == null || inviteCode.trim().isEmpty) return null;
    return inviteCode.trim();
  }

  String? _communityIdFromNotification(Map<String, dynamic> notification) {
    final payload = _notificationData(notification);
    return notification['community_id'] as String? ??
        payload['community_id'] as String?;
  }

  Future<void> _acceptCommunityInvite(Map<String, dynamic> notification) async {
    final s = getStrings();
    final notificationId = notification['id'] as String?;
    final inviteCode = _inviteCodeFromNotification(notification);
    final fallbackCommunityId = _communityIdFromNotification(notification);

    if (inviteCode == null) {
      if (fallbackCommunityId != null) {
        context.push('/community/$fallbackCommunityId');
      }
      return;
    }

    if (notificationId != null &&
        _acceptingInviteIds.contains(notificationId)) {
      return;
    }

    if (notificationId != null && mounted) {
      setState(() => _acceptingInviteIds.add(notificationId));
    }

    try {
      final response = await SupabaseService.rpc('accept_invite', params: {
        'p_invite_code': inviteCode,
      });
      final result = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      final error = result['error'] as String?;
      final communityId =
          result['community_id'] as String? ?? fallbackCommunityId;

      if (error == null || error == 'already_member') {
        if (notificationId != null) {
          if (widget.isCommunityScoped) {
            await ref
                .read(communityNotificationProvider(widget.communityId!).notifier)
                .markAsRead(notificationId);
          } else {
            await ref
                .read(notificationProvider.notifier)
                .markAsRead(notificationId);
          }
        }
        if (widget.isCommunityScoped) {
          await ref
              .read(communityNotificationProvider(widget.communityId!).notifier)
              .refresh();
        } else {
          await ref.read(notificationProvider.notifier).refresh();
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error == 'already_member'
                  ? s.alreadyInCommunity
                  : 'Convite aceito com sucesso!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (communityId != null) {
          context.push('/community/$communityId');
        }
        return;
      }

      String message;
      if (error == 'invalid_invite_code') {
        message = s.inviteInvalidOrExpired;
      } else if (error == 'not_authenticated') {
        message = s.loginToAcceptInvite;
      } else {
        message = s.couldNotAcceptInvite;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text(s.couldNotAcceptInvite),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (notificationId != null && mounted) {
        setState(() => _acceptingInviteIds.remove(notificationId));
      }
    }
  }

  Future<void> _handleTap(Map<String, dynamic> notification) async {
    final notifId = notification['id'] as String?;
    final isRead = notification['is_read'] as bool? ?? false;
    if (!isRead && notifId != null) {
      if (widget.isCommunityScoped) {
        ref
            .read(communityNotificationProvider(widget.communityId!).notifier)
            .markAsRead(notifId);
      } else {
        ref.read(notificationProvider.notifier).markAsRead(notifId);
      }
    }

    final type = notification['type'] as String? ?? '';
    final payload = _notificationData(notification);
    final postId = notification['post_id'] as String? ?? payload['post_id'] as String?;
    final communityId = notification['community_id'] as String? ?? payload['community_id'] as String?;
    final actorId = notification['actor_id'] as String? ?? payload['actor_id'] as String?;
    final chatId = payload['chat_id'] as String? ?? payload['thread_id'] as String?;
    final userId = payload['user_id'] as String? ?? actorId;

    switch (type) {
      case 'like':
      case 'comment':
      case 'mention':
        if (postId != null) {
          context.push('/post/$postId');
        } else if (communityId != null) {
          context.push('/community/$communityId');
        }
        break;
      case 'follow':
        if (userId != null) {
          context.push('/user/$userId');
        }
        break;
      case 'community_invite':
      case 'community_update':
        final cId = _communityIdFromNotification(notification);
        if (cId != null) {
          context.push('/community/$cId');
        } else if (type == 'community_invite') {
          await _acceptCommunityInvite(notification);
        }
        break;
      case 'chat_message':
      case 'chat_mention':
        final target = chatId ?? communityId;
        if (target != null) context.push('/chat/$target');
        break;
      case 'dm_invite':
        context.push('/chats');
        break;
      case 'level_up':
      case 'achievement':
      case 'check_in_streak':
        context.push('/profile');
        break;
      case 'wall_post':
        if (userId != null) {
          context.push('/user/$userId');
        }
        break;
      case 'moderation':
      case 'strike':
      case 'ban':
        if (communityId != null) {
          context.push('/community/$communityId');
        }
        break;
      default:
        // Fallback: tentar navegar para o recurso mais relevante
        if (postId != null) {
          context.push('/post/$postId');
        } else if (communityId != null) {
          context.push('/community/$communityId');
        } else if (userId != null) {
          context.push('/user/$userId');
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final notifAsync = widget.isCommunityScoped
        ? ref.watch(communityNotificationProvider(widget.communityId!))
        : ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      // ── AppBar estilo Amino: título centralizado + "Limpar Tudo" vermelho ──
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: context.nexusTheme.textPrimary, size: r.s(20)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.isCommunityScoped ? 'Alertas da comunidade' : s.alerts,
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: r.fs(18),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _confirmClearAll,
            child: Container(
              margin: EdgeInsets.only(right: r.s(12)),
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(7)),
              decoration: BoxDecoration(
                color: context.nexusTheme.error,
                borderRadius: BorderRadius.circular(r.s(20)),
              ),
              child: Text(
                'Limpar Tudo',
                style: TextStyle(
                  color: Colors.white,
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
          child: CircularProgressIndicator(color: context.nexusTheme.accentPrimary),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: r.s(48), color: context.nexusTheme.error),
              SizedBox(height: r.s(12)),
              Text(
                s.errorLoadingNotifications,
                style: TextStyle(
                    color: context.nexusTheme.textSecondary,
                    fontSize: r.fs(15),
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: r.s(12)),
              GestureDetector(
                onTap: () {
                  if (widget.isCommunityScoped) {
                    ref
                        .read(communityNotificationProvider(widget.communityId!).notifier)
                        .refresh();
                  } else {
                    ref.read(notificationProvider.notifier).refresh();
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(20), vertical: r.s(10)),
                  decoration: BoxDecoration(
                    color: context.nexusTheme.accentPrimary,
                    borderRadius: BorderRadius.circular(r.s(12)),
                  ),
                  child: Text(
                    s.retry,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        data: (notifState) {
          final notifications = notifState.notifications;

          return RefreshIndicator(
            color: context.nexusTheme.accentPrimary,
            onRefresh: () async {
              if (widget.isCommunityScoped) {
                await ref
                    .read(communityNotificationProvider(widget.communityId!).notifier)
                    .refresh();
              } else {
                await ref.read(notificationProvider.notifier).refresh();
              }
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Link para configurações de push ──────────────────────
                if (!widget.isCommunityScoped)
                  SliverToBoxAdapter(
                    child: InkWell(
                      onTap: () => context.push('/settings/notifications'),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(16), vertical: r.s(14)),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: context.dividerClr.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.settings_rounded,
                                color: context.nexusTheme.textSecondary, size: r.s(18)),
                            SizedBox(width: r.s(10)),
                            Text(
                              s.pushNotificationSettings,
                              style: TextStyle(
                                color: context.nexusTheme.textSecondary,
                                fontSize: r.fs(13),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right_rounded,
                                color: context.nexusTheme.textSecondary, size: r.s(18)),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(16), vertical: r.s(14)),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: context.dividerClr.withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.campaign_rounded,
                              color: context.nexusTheme.textSecondary, size: r.s(18)),
                          SizedBox(width: r.s(10)),
                          Expanded(
                            child: Text(
                              'Aqui aparecem apenas alertas desta comunidade.',
                              style: TextStyle(
                                color: context.nexusTheme.textSecondary,
                                fontSize: r.fs(13),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Filtros de categoria ─────────────────────────────────
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: r.s(44),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(12), vertical: r.s(6)),
                      children: NotificationCategory.values.map((cat) {
                        final isSelected = notifState.category == cat;
                        return GestureDetector(
                          onTap: () => _onCategoryChanged(cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(right: r.s(8)),
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(14), vertical: r.s(4)),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? context.nexusTheme.accentPrimary
                                  : context.surfaceColor,
                              borderRadius: BorderRadius.circular(r.s(20)),
                              border: Border.all(
                                color: isSelected
                                    ? context.nexusTheme.accentPrimary
                                    : context.dividerClr.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              cat.label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : context.nexusTheme.textSecondary,
                                fontSize: r.fs(12),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // ── Lista vazia ──────────────────────────────────────────
                if (notifications.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_rounded,
                              size: r.s(64), color: Colors.grey[600]),
                          SizedBox(height: r.s(16)),
                          Text(
                            'Nenhum alerta',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: r.fs(16),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: r.s(6)),
                          Text(
                            s.interactionsAppearHere,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: r.fs(12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // ── Tiles de notificação ─────────────────────────────
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final notification = notifications[index];
                        final notificationId = notification['id'] as String?;
                        final hasInviteAction = notification['type'] ==
                                'community_invite' &&
                            _inviteCodeFromNotification(notification) != null;

                        return Dismissible(
                          key: Key(notificationId ?? index.toString()),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.only(right: r.s(20)),
                            color: context.nexusTheme.error.withValues(alpha: 0.85),
                            child: Icon(
                              Icons.delete_rounded,
                              color: Colors.white,
                              size: r.s(24),
                            ),
                          ),
                          onDismissed: (_) {
                            if (notificationId != null) {
                              _deleteNotification(notificationId);
                            }
                          },
                          child: _NotificationTile(
                            data: notification,
                            onTap: () {
                              _handleTap(notification);
                            },
                            onPrimaryAction: hasInviteAction
                                ? () {
                                    _acceptCommunityInvite(notification);
                                  }
                                : null,
                            isActionLoading: notificationId != null &&
                                _acceptingInviteIds.contains(notificationId),
                          ),
                        );
                      },
                      childCount: notifications.length,
                    ),
                  ),

                  // ── Footer: loading / retry ──────────────────────────
                  SliverToBoxAdapter(
                    child: notifState.loadMoreError != null
                        ? _RetryBanner(
                            onRetry: () {
                              if (widget.isCommunityScoped) {
                                ref
                                    .read(communityNotificationProvider(widget.communityId!).notifier)
                                    .retryLoadMore();
                              } else {
                                ref
                                    .read(notificationProvider.notifier)
                                    .retryLoadMore();
                              }
                            },
                          )
                        : notifState.hasMore
                            ? Padding(
                                padding:
                                    EdgeInsets.symmetric(vertical: r.s(20)),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: context.nexusTheme.accentPrimary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : SizedBox(height: r.s(40)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// TILE DE NOTIFICAÇÃO — Estilo Amino (simples e limpo)
// =============================================================================

class _NotificationTile extends ConsumerWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onTap;
  final VoidCallback? onPrimaryAction;
  final bool isActionLoading;

  const _NotificationTile({
    required this.data,
    this.onTap,
    this.onPrimaryAction,
    this.isActionLoading = false,
  });

  // Ícone pequeno sobreposto ao avatar (canto inferior direito)
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

  Color _getIconColor(String type) {
    switch (type) {
      case 'like':
        return context.nexusTheme.error;
      case 'comment':
        return context.nexusTheme.accentSecondary;
      case 'follow':
        return context.nexusTheme.accentPrimary;
      case 'mention':
      case 'chat_mention':
        return context.nexusTheme.warning;
      case 'level_up':
        return context.nexusTheme.success;
      case 'achievement':
        return context.nexusTheme.warning;
      case 'chat_message':
        return const Color(0xFF4CAF50);
      case 'dm_invite':
        return const Color(0xFF9C27B0);
      case 'wall_post':
        return const Color(0xFF2196F3);
      case 'moderation':
      case 'strike':
      case 'ban':
        return context.nexusTheme.error;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final type = data['type'] as String? ?? 'general';
    final isRead = data['is_read'] as bool? ?? false;
    final actor = data['profiles'] as Map<String, dynamic>?;
    final content =
        data['body'] as String? ?? data['title'] as String? ?? s.notificationLabel;
    final createdAt = DateTime.tryParse(data['created_at'] as String? ?? '') ??
        DateTime.now();

    final iconColor = _getIconColor(type);
    final avatarUrl = actor?['icon_url'] as String?;
    final nickname = actor?['nickname'] as String? ?? '';
    final hasPrimaryAction =
        type == 'community_invite' && onPrimaryAction != null;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
        decoration: BoxDecoration(
          // Fundo levemente destacado para não lidas
          color: isRead
              ? Colors.transparent
              : context.nexusTheme.accentPrimary.withValues(alpha: 0.05),
          border: Border(
            bottom: BorderSide(
              color: context.dividerClr.withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar com ícone de tipo sobreposto ──────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Avatar do ator
                Container(
                  width: r.s(46),
                  height: r.s(46),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor.withValues(alpha: 0.15),
                  ),
                  child: ClipOval(
                    child: avatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Icon(
                              _getIcon(type),
                              color: iconColor,
                              size: r.s(22),
                            ),
                          )
                        : Icon(
                            _getIcon(type),
                            color: iconColor,
                            size: r.s(22),
                          ),
                  ),
                ),
                // Ícone de tipo no canto inferior direito
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: r.s(18),
                    height: r.s(18),
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.nexusTheme.backgroundPrimary, width: 1.5),
                    ),
                    child: Icon(
                      _getIcon(type),
                      color: Colors.white,
                      size: r.s(10),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(width: r.s(12)),

            // ── Conteúdo ─────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome em negrito + conteúdo inline (estilo Amino)
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(14),
                        height: 1.35,
                      ),
                      children: [
                        if (nickname.isNotEmpty)
                          TextSpan(
                            text: '$nickname ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        TextSpan(
                          text: content,
                          style: TextStyle(
                            fontWeight:
                                isRead ? FontWeight.w400 : FontWeight.w500,
                            color: isRead
                                ? context.nexusTheme.textSecondary
                                : context.nexusTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.s(3)),
                  // Timestamp
                  Text(
                    timeago.format(createdAt, locale: 'pt_BR'),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: r.fs(11),
                    ),
                  ),
                  if (hasPrimaryAction) ...[
                    SizedBox(height: r.s(8)),
                    GestureDetector(
                      onTap: isActionLoading ? null : onPrimaryAction,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: r.s(12),
                          vertical: r.s(8),
                        ),
                        decoration: BoxDecoration(
                          color: context.nexusTheme.accentPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(r.s(10)),
                          border: Border.all(
                            color:
                                context.nexusTheme.accentPrimary.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isActionLoading)
                              SizedBox(
                                width: r.s(14),
                                height: r.s(14),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.nexusTheme.accentPrimary,
                                ),
                              )
                            else
                              Icon(
                                Icons.check_circle_rounded,
                                color: context.nexusTheme.accentPrimary,
                                size: r.s(16),
                              ),
                            SizedBox(width: r.s(6)),
                            Text(
                              isActionLoading
                                  ? 'Aceitando...'
                                  : s.acceptInvite,
                              style: TextStyle(
                                color: context.nexusTheme.accentPrimary,
                                fontSize: r.fs(12),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(width: r.s(8)),

            // ── Indicador de não lida (ponto verde) ──────────────────
            if (!isRead)
              Container(
                width: r.s(8),
                height: r.s(8),
                decoration: const BoxDecoration(
                  color: context.nexusTheme.accentPrimary,
                  shape: BoxShape.circle,
                ),
              )
            else
              SizedBox(width: r.s(8)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// BANNER DE RETRY (erro ao carregar mais)
// =============================================================================

class _RetryBanner extends ConsumerWidget {
  final VoidCallback onRetry;
  const _RetryBanner({required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Container(
      margin: EdgeInsets.all(r.s(16)),
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(r.s(10)),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.red[300], size: r.s(20)),
          SizedBox(width: r.s(10)),
          Expanded(
            child: Text(
              s.errorLoadingMoreNotifications,
              style: TextStyle(
                  color: Colors.red[300],
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(r.s(8)),
              ),
              child: Text(
                s.retry,
                style: TextStyle(
                    color: Colors.red[300],
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
