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

/// Tela de lista de chats do usuário.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatListProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            floating: true,
            title: const Text('Chats'),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () {/* TODO: Buscar chats */},
              ),
            ],
          ),

          // Lista de chats
          chatsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(child: Text('Erro: $error')),
            ),
            data: (chatRooms) {
              if (chatRooms.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 64, color: AppTheme.textHint),
                        SizedBox(height: 16),
                        Text('Nenhum chat ainda',
                            style: TextStyle(color: AppTheme.textSecondary)),
                        SizedBox(height: 8),
                        Text('Entre em uma comunidade e comece a conversar!',
                            style: TextStyle(
                                color: AppTheme.textHint, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ChatRoomTile(chatRoom: chatRooms[index]),
                  childCount: chatRooms.length,
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {/* TODO: Criar novo chat */},
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.chat_rounded, color: Colors.white),
      ),
    );
  }
}

class _ChatRoomTile extends StatelessWidget {
  final ChatRoomModel chatRoom;

  const _ChatRoomTile({required this.chatRoom});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => context.push('/chat/${chatRoom.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
        backgroundImage: chatRoom.iconUrl != null
            ? CachedNetworkImageProvider(chatRoom.iconUrl!)
            : null,
        child: chatRoom.iconUrl == null
            ? Icon(
                chatRoom.type == 'direct'
                    ? Icons.person_rounded
                    : Icons.group_rounded,
                color: AppTheme.primaryColor,
              )
            : null,
      ),
      title: Text(
        chatRoom.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: chatRoom.lastMessagePreview != null
          ? Text(
              chatRoom.lastMessagePreview!,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : const Text(
              'Sem mensagens',
              style: TextStyle(color: AppTheme.textHint, fontSize: 13),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (chatRoom.lastMessageAt != null)
            Text(
              timeago.format(chatRoom.lastMessageAt!, locale: 'pt_BR'),
              style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
            ),
          const SizedBox(height: 4),
          if (chatRoom.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                chatRoom.unreadCount > 99 ? '99+' : '${chatRoom.unreadCount}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
