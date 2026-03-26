import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../config/app_theme.dart';
import '../../../core/models/message_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Tela de chat em tempo real usando Supabase Realtime.
class ChatRoomScreen extends ConsumerStatefulWidget {
  final String threadId;

  const ChatRoomScreen({super.key, required this.threadId});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<MessageModel> _messages = [];
  RealtimeChannel? _channel;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  /// Carregar mensagens históricas.
  Future<void> _loadMessages() async {
    try {
      final response = await SupabaseService.table('chat_messages')
          .select('*, profiles!chat_messages_author_id_fkey(*)')
          .eq('thread_id', widget.threadId)
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _messages.clear();
        _messages.addAll(
          (response as List).map((e) {
            final map = Map<String, dynamic>.from(e);
            if (map['profiles'] != null) map['sender'] = map['profiles'];
            return MessageModel.fromJson(map);
          }).toList(),
        );
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// Inscrever-se no canal Realtime para novas mensagens.
  void _subscribeToRealtime() {
    _channel = SupabaseService.client
        .channel('chat:${widget.threadId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: widget.threadId,
          ),
          callback: (payload) async {
            final newMessage = payload.newRecord;
            // Buscar dados do sender
            final senderData = await SupabaseService.table('profiles')
                .select()
                .eq('id', newMessage['author_id'])
                .single();

            newMessage['sender'] = senderData;
            final message = MessageModel.fromJson(newMessage);

            if (mounted) {
              setState(() {
                _messages.insert(0, message);
              });
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Enviar mensagem.
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      await SupabaseService.table('chat_messages').insert({
        'thread_id': widget.threadId,
        'author_id': SupabaseService.currentUserId,
        'content': text,
        'type': 'text',
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseService.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline_rounded),
            onPressed: () {/* TODO: Lista de membros */},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {/* TODO: Opções do chat */},
          ),
        ],
      ),
      body: Column(
        children: [
          // ================================================================
          // LISTA DE MENSAGENS
          // ================================================================
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 64, color: AppTheme.textHint),
                            SizedBox(height: 16),
                            Text('Nenhuma mensagem ainda',
                                style: TextStyle(color: AppTheme.textSecondary)),
                            Text('Comece a conversa!',
                                style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message.authorId == currentUserId;
                          final showAvatar = index == _messages.length - 1 ||
                              _messages[index + 1].authorId != message.authorId;

                          return _MessageBubble(
                            message: message,
                            isMe: isMe,
                            showAvatar: showAvatar,
                          );
                        },
                      ),
          ),

          // ================================================================
          // INPUT DE MENSAGEM
          // ================================================================
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(top: BorderSide(color: AppTheme.dividerColor)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Botão de mídia
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        color: AppTheme.primaryLight),
                    onPressed: () => _showMediaOptions(context),
                  ),

                  // Input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Mensagem...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              maxLines: 4,
                              minLines: 1,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          // Emoji
                          IconButton(
                            icon: const Icon(Icons.emoji_emotions_outlined,
                                color: AppTheme.textHint, size: 22),
                            onPressed: () {/* TODO: Emoji picker */},
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Botão enviar
                  Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMediaOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_rounded, color: AppTheme.primaryColor),
              ),
              title: const Text('Enviar Imagem'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.gif_box_rounded, color: AppTheme.accentColor),
              ),
              title: const Text('Enviar GIF'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sticky_note_2_rounded, color: AppTheme.warningColor),
              ),
              title: const Text('Enviar Sticker'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bolha de mensagem no chat.
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showAvatar;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isSystemMessage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.cardColorLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content ?? '',
              style: const TextStyle(color: AppTheme.textHint, fontSize: 12),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: showAvatar ? 8 : 2,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (apenas para outros)
          if (!isMe && showAvatar)
            GestureDetector(
              onTap: () => context.push('/user/${message.authorId}'),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.3),
                backgroundImage: message.author?.iconUrl != null
                    ? CachedNetworkImageProvider(message.author!.iconUrl!)
                    : null,
                child: message.author?.iconUrl == null
                    ? Text(
                        (message.author?.nickname ?? '?')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor),
                      )
                    : null,
              ),
            )
          else if (!isMe)
            const SizedBox(width: 32),

          const SizedBox(width: 8),

          // Bolha
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryColor : AppTheme.cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : (showAvatar ? 4 : 16)),
                  bottomRight: Radius.circular(isMe ? (showAvatar ? 4 : 16) : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome do sender (apenas em grupos)
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.author?.nickname ?? 'Usuário',
                        style: TextStyle(
                          color: isMe ? Colors.white70 : AppTheme.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // Conteúdo
                  if (message.isImageMessage && message.mediaUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: message.mediaUrl!,
                        width: 200,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Text(
                      message.content ?? '',
                      style: TextStyle(
                        color: isMe ? Colors.white : AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),

                  // Hora
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        color: isMe ? Colors.white54 : AppTheme.textHint,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
