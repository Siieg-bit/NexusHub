import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/message_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/giphy_picker.dart';
import '../widgets/sticker_picker.dart';

/// ============================================================================
/// 19+ TIPOS DE MENSAGEM (mapeados do Amino original):
///
///  0  text           - Texto simples
///  1  image          - Imagem (single)
///  2  audio          - Áudio / Voice Note
///  3  video          - Vídeo
///  4  sticker        - Sticker
///  5  gif            - GIF animado
///  6  file           - Arquivo genérico
///  7  link           - Link com preview
///  8  reply          - Resposta a outra mensagem
///  9  forward        - Mensagem encaminhada
/// 10  poll           - Mini-enquete inline
/// 11  quiz           - Mini-quiz inline
/// 12  voice_chat     - Convite para Voice Chat
/// 13  video_chat     - Convite para Video Chat
/// 14  screening_room - Convite para Screening Room
/// 15  tip            - Gorjeta (coins)
/// 16  shared_post    - Post compartilhado
/// 17  shared_user    - Perfil compartilhado
/// 18  shared_community - Comunidade compartilhada
/// 19  system         - Mensagem do sistema
/// ============================================================================

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
  Map<String, dynamic>? _threadInfo;
  MessageModel? _replyingTo;
  bool _showEmojiPicker = false;
  List<Map<String, dynamic>> _pinnedMessages = [];

  @override
  void initState() {
    super.initState();
    _loadThreadInfo();
    _loadMessages();
    _loadPinnedMessages();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadThreadInfo() async {
    try {
      final res = await SupabaseService.table('chat_threads')
          .select()
          .eq('id', widget.threadId)
          .single();
      if (mounted) setState(() => _threadInfo = res);
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final response = await SupabaseService.table('chat_messages')
          .select('*, profiles!chat_messages_author_id_fkey(*)')
          .eq('thread_id', widget.threadId)
          .order('created_at', ascending: false)
          .limit(100);

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

  Future<void> _loadPinnedMessages() async {
    try {
      final res = await SupabaseService.table('chat_messages')
          .select('*, profiles!chat_messages_author_id_fkey(*)')
          .eq('thread_id', widget.threadId)
          .eq('is_pinned', true)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _pinnedMessages = List<Map<String, dynamic>>.from(res as List);
        });
      }
    } catch (_) {}
  }

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
            try {
              final senderData = await SupabaseService.table('profiles')
                  .select()
                  .eq('id', newMessage['author_id'])
                  .single();
              newMessage['sender'] = senderData;
            } catch (_) {}
            final message = MessageModel.fromJson(newMessage);
            if (mounted) {
              setState(() => _messages.insert(0, message));
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  // ========================================================================
  // ENVIAR MENSAGEM (suporta todos os tipos)
  // ========================================================================
  Future<void> _sendMessage({
    String type = 'text',
    String? mediaUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && type == 'text') return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      final payload = <String, dynamic>{
        'thread_id': widget.threadId,
        'author_id': SupabaseService.currentUserId,
        'content': text.isNotEmpty ? text : null,
        'type': type,
        'media_url': mediaUrl,
        'metadata': metadata,
      };

      // Se respondendo a outra mensagem
      if (_replyingTo != null) {
        payload['reply_to_id'] = _replyingTo!.id;
        payload['type'] = 'reply';
        setState(() => _replyingTo = null);
      }

      await SupabaseService.table('chat_messages').insert(payload);
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

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path =
          'chat/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await image.readAsBytes();
      await SupabaseService.storage
          .from('chat-media')
          .uploadBinary(path, bytes);
      final url =
          SupabaseService.storage.from('chat-media').getPublicUrl(path);
      await _sendMessage(type: 'image', mediaUrl: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no upload: $e')),
        );
      }
    }
  }

  Future<void> _sendTip(String targetUserId) async {
    final amountController = TextEditingController(text: '10');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar Gorjeta'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantidade de moedas',
            prefixIcon: Icon(Icons.monetization_on_rounded),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(amountController.text)),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    amountController.dispose();
    if (result == null || result <= 0) return;

    await _sendMessage(
      type: 'tip',
      metadata: {
        'amount': result,
        'target_user_id': targetUserId,
      },
    );
  }

  Future<void> _addReaction(String messageId, String emoji) async {
    try {
      await SupabaseService.table('message_reactions').upsert({
        'message_id': messageId,
        'user_id': SupabaseService.currentUserId,
        'emoji': emoji,
      });
      // Recarregar mensagens para atualizar reações
      await _loadMessages();
    } catch (_) {}
  }

  Future<void> _pinMessage(String messageId) async {
    try {
      await SupabaseService.table('chat_messages')
          .update({'is_pinned': true}).eq('id', messageId);
      await _loadPinnedMessages();
    } catch (_) {}
  }

  // ========================================================================
  // BUILD
  // ========================================================================
  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseService.currentUserId;
    final threadTitle = _threadInfo?['title'] as String? ?? 'Chat';
    final threadType = _threadInfo?['type'] as String? ?? 'group';
    final memberCount = _threadInfo?['member_count'] as int? ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(threadTitle,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            if (threadType == 'group')
              Text('$memberCount membros',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          // Pinned messages
          if (_pinnedMessages.isNotEmpty)
            IconButton(
              icon: badges_icon(Icons.push_pin_rounded, _pinnedMessages.length),
              onPressed: () => _showPinnedMessages(),
            ),
          // Voice chat
          IconButton(
            icon: const Icon(Icons.mic_rounded),
            onPressed: () => _sendMessage(
              type: 'voice_chat',
              metadata: {'status': 'invite'},
            ),
          ),
          // Menu
          PopupMenuButton<String>(
            onSelected: (val) {
              switch (val) {
                case 'members':
                  break; // TODO
                case 'settings':
                  break; // TODO
                case 'leave':
                  break; // TODO
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                  value: 'members', child: Text('Membros')),
              const PopupMenuItem(
                  value: 'settings', child: Text('Configurações')),
              const PopupMenuItem(
                  value: 'leave',
                  child: Text('Sair do Chat',
                      style: TextStyle(color: AppTheme.errorColor))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Pinned message banner
          if (_pinnedMessages.isNotEmpty)
            GestureDetector(
              onTap: _showPinnedMessages,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin_rounded,
                        size: 14, color: AppTheme.warningColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pinnedMessages.first['content'] as String? ??
                            'Mensagem fixada',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
                                style: TextStyle(
                                    color: AppTheme.textSecondary)),
                            Text('Comece a conversa!',
                                style: TextStyle(
                                    color: AppTheme.textHint, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe =
                              message.authorId == currentUserId;
                          final showAvatar =
                              index == _messages.length - 1 ||
                                  _messages[index + 1].authorId !=
                                      message.authorId;

                          return GestureDetector(
                            onLongPress: () =>
                                _showMessageActions(message),
                            child: _MessageBubble(
                              message: message,
                              isMe: isMe,
                              showAvatar: showAvatar,
                              onReactionTap: (emoji) =>
                                  _addReaction(message.id, emoji),
                            ),
                          );
                        },
                      ),
          ),

          // ================================================================
          // REPLY PREVIEW
          // ================================================================
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              color: AppTheme.cardColor,
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 32,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _replyingTo!.author?.nickname ?? 'Usuário',
                          style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _replyingTo!.content ?? '',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () =>
                        setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),

          // ================================================================
          // INPUT DE MENSAGEM
          // ================================================================
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border:
                  Border(top: BorderSide(color: AppTheme.dividerColor)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Botão de mídia (+)
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
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              maxLines: 4,
                              minLines: 1,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                                Icons.emoji_emotions_outlined,
                                color: AppTheme.textHint,
                                size: 22),
                            onPressed: () {
                              setState(() =>
                                  _showEmojiPicker = !_showEmojiPicker);
                            },
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
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
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

  // ========================================================================
  // MEDIA OPTIONS BOTTOM SHEET (19+ tipos)
  // ========================================================================
  void _showMediaOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MediaOptionItem(
                  icon: Icons.image_rounded,
                  label: 'Imagem',
                  color: AppTheme.primaryColor,
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendImage();
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.gif_box_rounded,
                  label: 'GIF',
                  color: AppTheme.accentColor,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final gifUrl = await GiphyPicker.show(context);
                    if (gifUrl != null && gifUrl.isNotEmpty) {
                      await _sendMessage(
                          type: 'gif',
                          mediaUrl: gifUrl,
                          metadata: {'source': 'giphy'});
                    }
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.sticky_note_2_rounded,
                  label: 'Sticker',
                  color: AppTheme.warningColor,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final sticker = await StickerPicker.show(context,
                        communityId: _threadInfo?['community_id'] as String?);
                    if (sticker != null) {
                      final emoji = sticker['emoji'];
                      if (emoji != null && emoji.isNotEmpty) {
                        await _sendMessage(
                            type: 'sticker',
                            metadata: {'emoji': emoji, 'sticker_id': sticker['sticker_id']});
                      } else {
                        await _sendMessage(
                            type: 'sticker',
                            mediaUrl: sticker['sticker_url'],
                            metadata: {'sticker_id': sticker['sticker_id']});
                      }
                    }
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.mic_rounded,
                  label: 'Áudio',
                  color: const Color(0xFFE91E63),
                  onTap: () {
                    Navigator.pop(ctx);
                    // TODO: Voice recorder
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MediaOptionItem(
                  icon: Icons.videocam_rounded,
                  label: 'Vídeo',
                  color: const Color(0xFF9C27B0),
                  onTap: () {
                    Navigator.pop(ctx);
                    // TODO: Video picker
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.attach_file_rounded,
                  label: 'Arquivo',
                  color: const Color(0xFF607D8B),
                  onTap: () {
                    Navigator.pop(ctx);
                    // TODO: File picker
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.poll_rounded,
                  label: 'Enquete',
                  color: const Color(0xFF00BCD4),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showInlinePollCreator();
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.monetization_on_rounded,
                  label: 'Gorjeta',
                  color: AppTheme.warningColor,
                  onTap: () {
                    Navigator.pop(ctx);
                    // TODO: Select user then tip
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MediaOptionItem(
                  icon: Icons.headset_mic_rounded,
                  label: 'Voice Chat',
                  color: const Color(0xFFFF4081),
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendMessage(
                        type: 'voice_chat',
                        metadata: {'status': 'invite'});
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.video_call_rounded,
                  label: 'Video Chat',
                  color: const Color(0xFF4CAF50),
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendMessage(
                        type: 'video_chat',
                        metadata: {'status': 'invite'});
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.live_tv_rounded,
                  label: 'Screening',
                  color: const Color(0xFFFF5722),
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendMessage(
                        type: 'screening_room',
                        metadata: {'status': 'invite'});
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.link_rounded,
                  label: 'Link',
                  color: const Color(0xFF3F51B5),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showLinkInput();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showInlinePollCreator() {
    final questionCtrl = TextEditingController();
    final optionCtrls = [TextEditingController(), TextEditingController()];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Criar Enquete'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Pergunta'),
                ),
                const SizedBox(height: 8),
                ...List.generate(optionCtrls.length, (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: TextField(
                        controller: optionCtrls[i],
                        decoration: InputDecoration(
                            labelText: 'Opção ${i + 1}'),
                      ),
                    )),
                TextButton.icon(
                  onPressed: () => setDialogState(
                      () => optionCtrls.add(TextEditingController())),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Opção'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _sendMessage(type: 'poll', metadata: {
                  'question': questionCtrl.text,
                  'options': optionCtrls
                      .map((c) => c.text)
                      .where((t) => t.isNotEmpty)
                      .toList(),
                });
                questionCtrl.dispose();
                for (final c in optionCtrls) {
                  c.dispose();
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkInput() {
    final linkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Compartilhar Link'),
        content: TextField(
          controller: linkCtrl,
          decoration: const InputDecoration(
            hintText: 'https://...',
            prefixIcon: Icon(Icons.link_rounded),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendMessage(
                  type: 'link',
                  metadata: {'url': linkCtrl.text});
              linkCtrl.dispose();
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // MESSAGE ACTIONS (Long Press)
  // ========================================================================
  void _showMessageActions(MessageModel message) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick reactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️', '😂', '😮', '😢', '👍', '👎']
                  .map((emoji) => GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _addReaction(message.id, emoji);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 22)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Responder'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingTo = message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copiar'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(
                    ClipboardData(text: message.content ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copiado!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward_rounded),
              title: const Text('Encaminhar'),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: Forward message
              },
            ),
            ListTile(
              leading: const Icon(Icons.push_pin_rounded),
              title: const Text('Fixar Mensagem'),
              onTap: () {
                Navigator.pop(ctx);
                _pinMessage(message.id);
              },
            ),
            if (message.authorId == SupabaseService.currentUserId)
              ListTile(
                leading: const Icon(Icons.delete_rounded,
                    color: AppTheme.errorColor),
                title: const Text('Apagar',
                    style: TextStyle(color: AppTheme.errorColor)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await SupabaseService.table('chat_messages')
                      .delete()
                      .eq('id', message.id);
                  setState(() => _messages.remove(message));
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showPinnedMessages() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mensagens Fixadas',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ..._pinnedMessages.map((m) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(m['content'] as String? ?? '',
                      style: const TextStyle(fontSize: 13)),
                )),
          ],
        ),
      ),
    );
  }

  Widget badges_icon(IconData icon, int count) {
    return Stack(
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppTheme.warningColor,
                shape: BoxShape.circle,
              ),
              constraints:
                  const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                count.toString(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// MESSAGE BUBBLE (suporta todos os 19+ tipos)
// ============================================================================

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showAvatar;
  final void Function(String emoji)? onReactionTap;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
    this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    // System messages
    if (message.isSystemMessage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.cardColorLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content ?? '',
              style:
                  const TextStyle(color: AppTheme.textHint, fontSize: 12),
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
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar)
            GestureDetector(
              onTap: () => context.push('/user/${message.authorId}'),
              child: CircleAvatar(
                radius: 16,
                backgroundColor:
                    AppTheme.primaryColor.withValues(alpha: 0.3),
                backgroundImage: message.author?.iconUrl != null
                    ? CachedNetworkImageProvider(
                        message.author!.iconUrl!)
                    : null,
                child: message.author?.iconUrl == null
                    ? Text(
                        (message.author?.nickname ?? '?')[0]
                            .toUpperCase(),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryColor),
                      )
                    : null,
              ),
            )
          else if (!isMe)
            const SizedBox(width: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryColor : AppTheme.cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(
                      isMe ? 16 : (showAvatar ? 4 : 16)),
                  bottomRight: Radius.circular(
                      isMe ? (showAvatar ? 4 : 16) : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.author?.nickname ?? 'Usuário',
                        style: TextStyle(
                          color: isMe
                              ? Colors.white70
                              : AppTheme.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  // Conteúdo baseado no tipo
                  _buildContent(context),
                  // Hora
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        color:
                            isMe ? Colors.white54 : AppTheme.textHint,
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

  Widget _buildContent(BuildContext context) {
    final type = message.type;
    final textColor = isMe ? Colors.white : AppTheme.textPrimary;

    switch (type) {
      case 'image':
        if (message.mediaUrl != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: message.mediaUrl!,
              width: 200,
              fit: BoxFit.cover,
            ),
          );
        }
        return Text(message.content ?? '[Imagem]',
            style: TextStyle(color: textColor, fontSize: 14));

      case 'gif':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.mediaUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: message.mediaUrl!,
                  width: 180,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 180,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                    child: Text('GIF',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20))),
              ),
          ],
        );

      case 'sticker':
        return message.mediaUrl != null
            ? CachedNetworkImage(
                imageUrl: message.mediaUrl!, width: 120, height: 120)
            : const Text('🎭', style: TextStyle(fontSize: 48));

      case 'audio':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_rounded,
                color: textColor, size: 32),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Áudio', style: TextStyle(color: textColor, fontSize: 13)),
                Container(
                  width: 120,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'video':
        return Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_rounded,
                color: Colors.white, size: 48),
          ),
        );

      case 'voice_chat':
      case 'video_chat':
      case 'screening_room':
        final isVoice = type == 'voice_chat';
        final isVideo = type == 'video_chat';
        final icon = isVoice
            ? Icons.headset_mic_rounded
            : isVideo
                ? Icons.video_call_rounded
                : Icons.live_tv_rounded;
        final label = isVoice
            ? 'Voice Chat'
            : isVideo
                ? 'Video Chat'
                : 'Screening Room';
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4081).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFFFF4081)),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF4081))),
            ],
          ),
        );

      case 'tip':
        final amount = message.metadata?['amount'] ?? 0;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on_rounded,
                  color: AppTheme.warningColor),
              const SizedBox(width: 8),
              Text('$amount moedas',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warningColor)),
            ],
          ),
        );

      case 'poll':
        final question = message.metadata?['question'] ?? '';
        final options =
            (message.metadata?['options'] as List<dynamic>?) ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 $question',
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const SizedBox(height: 8),
            ...options.map((opt) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(opt.toString(),
                      style: TextStyle(color: textColor, fontSize: 13)),
                )),
          ],
        );

      case 'link':
        final url = message.metadata?['url'] ?? message.content ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_rounded, color: textColor, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      url.toString(),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (message.content != null && message.content!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(message.content!,
                    style: TextStyle(color: textColor, fontSize: 14)),
              ),
          ],
        );

      case 'reply':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                      color: isMe ? Colors.white54 : AppTheme.primaryColor,
                      width: 3),
                ),
              ),
              child: Text(
                'Em resposta...',
                style: TextStyle(
                  color: isMe ? Colors.white54 : AppTheme.textSecondary,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(message.content ?? '',
                style: TextStyle(color: textColor, fontSize: 14)),
          ],
        );

      case 'shared_post':
      case 'shared_user':
      case 'shared_community':
        final sharedType = type == 'shared_post'
            ? 'Post'
            : type == 'shared_user'
                ? 'Perfil'
                : 'Comunidade';
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.share_rounded, color: textColor, size: 16),
              const SizedBox(width: 8),
              Text('$sharedType compartilhado',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        );

      case 'text':
      default:
        return Text(
          message.content ?? '',
          style: TextStyle(color: textColor, fontSize: 14),
        );
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// MEDIA OPTION ITEM
// ============================================================================

class _MediaOptionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MediaOptionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
