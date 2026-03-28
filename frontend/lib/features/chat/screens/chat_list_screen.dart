import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../config/app_theme.dart';
import '../../../core/models/chat_room_model.dart';
import '../../../core/services/supabase_service.dart';

/// Provider para lista de chats do usuário.
final chatListProvider = FutureProvider<List<ChatRoomModel>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final response = await SupabaseService.table('chat_members')
      .select('thread_id, chat_threads(*)')
      .eq('user_id', userId)
      .order('joined_at', ascending: false);

  return (response as List)
      .where((e) => e['chat_threads'] != null)
      .map((e) =>
          ChatRoomModel.fromJson(e['chat_threads'] as Map<String, dynamic>))
      .toList()
    ..sort((a, b) => (b.lastMessageAt ?? b.createdAt)
        .compareTo(a.lastMessageAt ?? a.createdAt));
});

/// Tela de lista de chats — estilo Amino Apps.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatListProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // ── Header estilo Amino ──
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppTheme.scaffoldBg,
            elevation: 0,
            toolbarHeight: 56,
            title: const Text(
              'My Chats',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () {/* TODO: Buscar chats */},
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.search_rounded,
                      color: Colors.grey[500], size: 18),
                ),
              ),
              GestureDetector(
                onTap: () {/* TODO: Novo chat */},
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),

          // ── Online friends bar (placeholder) ──
          SliverToBoxAdapter(
            child: Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ONLINE',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 6,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 48,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppTheme.surfaceColor,
                                    child: Icon(Icons.person_rounded,
                                        color: Colors.grey[600], size: 18),
                                  ),
                                  // Online indicator
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppTheme.scaffoldBg,
                                            width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Divider ──
          SliverToBoxAdapter(
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),

          // ── Chat list ──
          chatsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 2,
                ),
              ),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48, color: Colors.grey[700]),
                    const SizedBox(height: 12),
                    Text('Error loading chats',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                  ],
                ),
              ),
            ),
            data: (chatRooms) {
              if (chatRooms.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.chat_bubble_outline_rounded,
                              size: 36, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 16),
                        Text('No chats yet',
                            style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text('Join a community and start chatting!',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _AminoChatTile(chatRoom: chatRooms[index]),
                  childCount: chatRooms.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Chat tile — estilo Amino (avatar grande, online indicator, unread badge).
class _AminoChatTile extends StatelessWidget {
  final ChatRoomModel chatRoom;

  const _AminoChatTile({required this.chatRoom});

  @override
  Widget build(BuildContext context) {
    final hasUnread = chatRoom.unreadCount > 0;

    return GestureDetector(
      onTap: () => context.push('/chat/${chatRoom.id}'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // ── Avatar com online indicator ──
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.surfaceColor,
                  backgroundImage: chatRoom.iconUrl != null
                      ? CachedNetworkImageProvider(chatRoom.iconUrl!)
                      : null,
                  child: chatRoom.iconUrl == null
                      ? Icon(
                          chatRoom.type == 'direct'
                              ? Icons.person_rounded
                              : Icons.group_rounded,
                          color: Colors.grey[500],
                          size: 22,
                        )
                      : null,
                ),
                // Online indicator (for direct chats)
                if (chatRoom.type == 'direct')
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.scaffoldBg, width: 2),
                      ),
                    ),
                  ),
                // Group icon overlay
                if (chatRoom.type == 'group')
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.scaffoldBg, width: 2),
                      ),
                      child: const Icon(Icons.groups_rounded,
                          size: 8, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // ── Content ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + time
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chatRoom.title,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chatRoom.lastMessageAt != null)
                        Text(
                          timeago.format(chatRoom.lastMessageAt!,
                              locale: 'pt_BR'),
                          style: TextStyle(
                            color: hasUnread
                                ? AppTheme.primaryColor
                                : Colors.grey[600],
                            fontSize: 10,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Last message + unread badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chatRoom.lastMessagePreview ?? 'No messages yet',
                          style: TextStyle(
                            color: hasUnread
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontSize: 12,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          height: 20,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              chatRoom.unreadCount > 99
                                  ? '99+'
                                  : '${chatRoom.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
