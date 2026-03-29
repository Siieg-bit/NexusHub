import 'dart:io';
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
import '../widgets/giphy_picker.dart';
import '../widgets/sticker_picker.dart';
import '../widgets/voice_recorder.dart';

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
  bool _isRecordingVoice = false;
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
    } catch (_) {
      // Thread info is best-effort; chat still works without it
    }
  }

  Future<void> _loadMessages() async {
    try {
      final response = await SupabaseService.table('chat_messages')
          .select('*, profiles!chat_messages_author_id_fkey(id, nickname, icon_url)')
          .eq('thread_id', widget.threadId)
          .order('created_at', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(
            (response as List).map((e) {
              final map = Map<String, dynamic>.from(e as Map);
              if (map['profiles'] != null) {
                map['sender'] = map['profiles'];
                map['author'] = map['profiles'];
              }
              return MessageModel.fromJson(map);
            }).toList(),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error loading messages: $e');
    }
  }

  Future<void> _loadPinnedMessages() async {
    try {
      final threadData = await SupabaseService.table('chat_threads')
          .select('pinned_message_id')
          .eq('id', widget.threadId)
          .single();
      final pinnedId = threadData['pinned_message_id'] as String?;
      if (pinnedId == null) {
        if (mounted) setState(() => _pinnedMessages = []);
        return;
      }
      final res = await SupabaseService.table('chat_messages')
          .select('*, profiles!chat_messages_author_id_fkey(id, nickname, icon_url)')
          .eq('id', pinnedId)
          .limit(1);
      if (mounted) {
        setState(() {
          _pinnedMessages = List<Map<String, dynamic>>.from(res as List);
        });
      }
    } catch (_) {
      // Pinned messages are best-effort
    }
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
            try {
              final newMessage = Map<String, dynamic>.from(payload.newRecord);

              // Evitar duplicatas
              if (_messages.any((m) => m.id == newMessage['id'])) return;

              // Buscar perfil do autor
              try {
                final authorId = newMessage['author_id'] as String?;
                if (authorId != null) {
                  final senderData = await SupabaseService.table('profiles')
                      .select('id, nickname, icon_url')
                      .eq('id', authorId)
                      .single();
                  newMessage['sender'] = senderData;
                  newMessage['author'] = senderData;
                }
              } catch (_) {
                // Profile fetch is best-effort
              }

              final message = MessageModel.fromJson(newMessage);
              if (mounted) {
                setState(() => _messages.insert(0, message));
                _scrollToBottom();
              }
            } catch (e) {
              debugPrint('Realtime message error: $e');
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ========================================================================
  // ENVIAR MENSAGEM (suporta todos os tipos)
  // ========================================================================

  /// Mapeia tipos de mensagem do app para os valores válidos do enum
  /// `chat_message_type` no banco de dados.
  ///
  /// Valores válidos: text, strike, voice_note, sticker, video, share_url,
  /// share_user, system_deleted, system_join, system_leave, system_voice_start,
  /// system_voice_end, system_screen_start, system_screen_end, system_tip,
  /// system_pin, system_unpin, system_removed, system_admin_delete
  String _mapMessageType(String type) {
    const validTypes = {
      'text', 'strike', 'voice_note', 'sticker', 'video',
      'share_url', 'share_user', 'system_deleted', 'system_join',
      'system_leave', 'system_voice_start', 'system_voice_end',
      'system_screen_start', 'system_screen_end', 'system_tip',
      'system_pin', 'system_unpin', 'system_removed', 'system_admin_delete',
    };
    if (validTypes.contains(type)) return type;
    // Mapeamento de tipos do app para tipos válidos do enum
    switch (type) {
      case 'image': return 'text';   // imagem enviada como texto com media_url
      case 'gif':   return 'text';   // gif enviado como texto com media_url
      case 'audio': return 'voice_note';
      case 'reply': return 'text';   // reply usa reply_to_id + tipo text
      case 'voice_chat': return 'system_voice_start';
      case 'video_chat': return 'system_voice_start';
      case 'screening_room': return 'system_screen_start';
      case 'poll': return 'text';    // poll enviado como texto com conteúdo JSON
      case 'link': return 'share_url';
      case 'tip': return 'system_tip';
      case 'forward': return 'text';
      case 'file': return 'text';
      default: return 'text';
    }
  }

  /// Envia uma mensagem no chat.
  ///
  /// Todos os campos enviados correspondem exatamente às colunas da tabela
  /// `chat_messages`. Campos inexistentes como `metadata` NÃO são enviados.
  ///
  /// Para tipos especiais:
  /// - **poll**: pergunta + opções serializadas no `content` como JSON
  /// - **tip**: valor em `tip_amount`, conteúdo descritivo em `content`
  /// - **link**: URL em `shared_url`, conteúdo descritivo em `content`
  /// - **sticker**: `sticker_id` e `sticker_url` nos campos dedicados
  /// - **voice_note**: `media_url` e `media_duration` nos campos dedicados
  /// - **image/gif**: `media_url` e `media_type` nos campos dedicados
  Future<void> _sendMessage({
    String type = 'text',
    String? mediaUrl,
    String? mediaType,
    String? stickerId,
    String? stickerUrl,
    String? sharedUrl,
    int? tipAmount,
    int? mediaDuration,
    String? pollQuestion,
    List<String>? pollOptions,
  }) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && type == 'text' && mediaUrl == null) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      final mappedType = _mapMessageType(type);

      // Determinar conteúdo baseado no tipo
      String content;
      if (type == 'poll' && pollQuestion != null) {
        // Poll: serializar pergunta e opções como JSON no content
        content = '{"question":"$pollQuestion","options":${pollOptions?.map((o) => '"$o"').toList() ?? []}}';
      } else if (type == 'link' && sharedUrl != null) {
        content = text.isNotEmpty ? text : sharedUrl;
      } else if (type == 'tip' && tipAmount != null) {
        content = '$tipAmount coins';
      } else if (type == 'voice_chat' || type == 'video_chat' || type == 'screening_room') {
        content = type == 'voice_chat'
            ? 'Iniciou um Voice Chat'
            : type == 'video_chat'
                ? 'Iniciou um Video Chat'
                : 'Iniciou um Screening Room';
      } else {
        content = text;
      }

      final payload = <String, dynamic>{
        'thread_id': widget.threadId,
        'author_id': SupabaseService.currentUserId,
        'content': content,
        'type': mappedType,
      };

      // Campos opcionais — só adicionar se não null (correspondem a colunas reais)
      if (mediaUrl != null) payload['media_url'] = mediaUrl;
      if (mediaType != null) payload['media_type'] = mediaType;
      if (mediaDuration != null) payload['media_duration'] = mediaDuration;
      if (stickerId != null) payload['sticker_id'] = stickerId;
      if (stickerUrl != null) payload['sticker_url'] = stickerUrl;
      if (sharedUrl != null) payload['shared_url'] = sharedUrl;
      if (tipAmount != null) payload['tip_amount'] = tipAmount;

      // Para imagens e gifs, definir media_type
      if (type == 'image' && mediaType == null) payload['media_type'] = 'image';
      if (type == 'gif' && mediaType == null) payload['media_type'] = 'gif';

      if (_replyingTo != null) {
        payload['reply_to_id'] = _replyingTo!.id;
        setState(() => _replyingTo = null);
      }

      await SupabaseService.table('chat_messages').insert(payload);

      // Atualizar last_message da thread
      try {
        await SupabaseService.table('chat_threads').update({
          'last_message_at': DateTime.now().toIso8601String(),
          'last_message_preview': content.length > 100
              ? '${content.substring(0, 100)}...'
              : content,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.threadId);
      } catch (_) {
        // Thread update is best-effort
      }

      // Adicionar reputação por enviar mensagem (best-effort)
      try {
        final communityId = _threadInfo?['community_id'] as String?;
        if (communityId != null) {
          await SupabaseService.rpc('add_reputation', params: {
            'p_community_id': communityId,
            'p_user_id': SupabaseService.currentUserId,
            'p_action': 'chat_message',
            'p_source_id': widget.threadId,
          });
        }
      } catch (_) {
        // Reputação é best-effort
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
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
      final path = 'chat/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await image.readAsBytes();
      await SupabaseService.storage
          .from('chat-media')
          .uploadBinary(path, bytes);
      final url = SupabaseService.storage.from('chat-media').getPublicUrl(path);
      await _sendMessage(type: 'image', mediaUrl: url, mediaType: 'image');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no upload: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Diálogo de gorjeta estilo Amino — valores pré-definidos + custom.
  Future<void> _showTipDialog() async {
    final customController = TextEditingController();
    int? selectedAmount;

    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.monetization_on_rounded,
                        color: AppTheme.warningColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Enviar Gorjeta',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 18)),
                      Text('Envie moedas para este chat',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Valores pré-definidos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [10, 50, 100, 500].map((amount) {
                  final isSelected = selectedAmount == amount;
                  return GestureDetector(
                    onTap: () => setModalState(() {
                      selectedAmount = amount;
                      customController.clear();
                    }),
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.warningColor.withValues(alpha: 0.15)
                            : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.warningColor
                              : Colors.white.withValues(alpha: 0.05),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.monetization_on_rounded,
                              color: isSelected
                                  ? AppTheme.warningColor
                                  : Colors.grey[600],
                              size: 22),
                          const SizedBox(height: 4),
                          Text('$amount',
                              style: TextStyle(
                                color: isSelected
                                    ? AppTheme.warningColor
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Campo custom
              TextField(
                controller: customController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                onChanged: (val) => setModalState(() {
                  selectedAmount = int.tryParse(val);
                }),
                decoration: InputDecoration(
                  hintText: 'Ou digite um valor...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: const Icon(Icons.edit_rounded,
                      color: AppTheme.warningColor, size: 18),
                  filled: true,
                  fillColor: AppTheme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              // Botão enviar
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: selectedAmount != null && selectedAmount! > 0
                      ? () => Navigator.pop(ctx, selectedAmount)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selectedAmount != null && selectedAmount! > 0
                          ? AppTheme.warningColor
                          : Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          selectedAmount != null && selectedAmount! > 0
                              ? 'Enviar $selectedAmount moedas'
                              : 'Selecione um valor',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    customController.dispose();
    if (result == null || result <= 0) return;

    // Executar transferência via RPC
    try {
      await SupabaseService.rpc('transfer_coins', params: {
        'p_receiver_id': _threadInfo?['host_id'] ?? '',
        'p_amount': result,
      });
    } catch (_) {
      // Transferência pode falhar (saldo insuficiente)
    }

    // Enviar mensagem de tip no chat usando campos reais do banco
    await _sendMessage(
      type: 'tip',
      tipAmount: result,
    );
  }

  Future<void> _addReaction(String messageId, String emoji) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final msg = await SupabaseService.table('chat_messages')
          .select('reactions')
          .eq('id', messageId)
          .single();
      final reactions = Map<String, dynamic>.from(
          (msg['reactions'] as Map<String, dynamic>?) ?? {});
      final users = List<String>.from(reactions[emoji] ?? []);
      if (users.contains(userId)) {
        users.remove(userId);
      } else {
        users.add(userId);
      }
      if (users.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = users;
      }
      await SupabaseService.table('chat_messages')
          .update({'reactions': reactions}).eq('id', messageId);
      await _loadMessages();
    } catch (_) {}
  }

  Future<void> _pinMessage(String messageId) async {
    try {
      await SupabaseService.table('chat_threads')
          .update({'pinned_message_id': messageId}).eq('id', widget.threadId);
      await _loadPinnedMessages();
    } catch (_) {}
  }

  // ========================================================================
  // BUILD — Estilo Amino Apps
  // ========================================================================
  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseService.currentUserId;
    final threadTitle = _threadInfo?['title'] as String? ?? 'Chat';
    final threadType = _threadInfo?['type'] as String? ?? 'group';
    final memberCount = (_threadInfo?['member_count'] ?? _threadInfo?['members_count']) as int? ?? 0;
    final threadIcon = _threadInfo?['icon_url'] as String?;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      // ── AppBar estilo Amino ──
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            // Thread avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.surfaceColor,
              backgroundImage: threadIcon != null
                  ? CachedNetworkImageProvider(threadIcon)
                  : null,
              child: threadIcon == null
                  ? Icon(
                      threadType == 'dm'
                          ? Icons.person_rounded
                          : Icons.group_rounded,
                      color: Colors.grey[500],
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(threadTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.textPrimary)),
                  if (threadType != 'dm')
                    Text('$memberCount members',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Pinned messages
          if (_pinnedMessages.isNotEmpty)
            GestureDetector(
              onTap: _showPinnedMessages,
              child: _badgeIcon(Icons.push_pin_rounded, _pinnedMessages.length),
            ),
          // Voice chat
          GestureDetector(
            onTap: () => _sendMessage(type: 'voice_chat'),
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mic_rounded, color: Colors.grey[500], size: 16),
            ),
          ),
          // Menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: Colors.grey[500]),
            color: AppTheme.surfaceColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              switch (val) {
                case 'members':
                  break;
                case 'settings':
                  break;
                case 'leave':
                  break;
              }
            },
            itemBuilder: (ctx) => [
              _buildPopupItem('members', Icons.people_rounded, 'Membros'),
              _buildPopupItem('settings', Icons.settings_rounded, 'Configurações'),
              _buildPopupItem(
                  'leave', Icons.exit_to_app_rounded, 'Sair do Chat',
                  isDestructive: true),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Pinned message banner ──
          if (_pinnedMessages.isNotEmpty)
            GestureDetector(
              onTap: _showPinnedMessages,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.08),
                  border: Border(
                    bottom: BorderSide(
                        color: AppTheme.warningColor.withValues(alpha: 0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin_rounded,
                        size: 14, color: AppTheme.warningColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pinnedMessages.first['content'] as String? ??
                            'Mensagem fixada',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[400]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_right_rounded,
                        size: 16, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),

          // ================================================================
          // LISTA DE MENSAGENS
          // ================================================================
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryColor, strokeWidth: 2))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: AppTheme.surfaceColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.chat_bubble_outline_rounded,
                                  size: 32, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 16),
                            Text('Nenhuma mensagem ainda',
                                style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text('Comece a conversa!',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12)),
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
                          final isMe = message.authorId == currentUserId;
                          final showAvatar = index == _messages.length - 1 ||
                              _messages[index + 1].authorId != message.authorId;

                          return GestureDetector(
                            onLongPress: () => _showMessageActions(message),
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
              color: AppTheme.surfaceColor,
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _replyingTo!.author?.nickname ?? 'User',
                          style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _replyingTo!.content ?? '',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.close_rounded,
                          size: 18, color: Colors.grey[500]),
                    ),
                  ),
                ],
              ),
            ),

          // ================================================================
          // INPUT DE MENSAGEM — Estilo Amino
          // ================================================================
          // Voice Recorder overlay (substitui input bar durante gravação)
          if (_isRecordingVoice)
            SafeArea(
              top: false,
              child: VoiceRecorder(
                onRecordingComplete: (filePath, duration) async {
                  setState(() => _isRecordingVoice = false);
                  try {
                    final file = File(filePath);
                    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
                    final storagePath = 'chat_media/${widget.threadId}/$fileName';
                    await SupabaseService.client.storage
                        .from('media')
                        .upload(storagePath, file);
                    final url = SupabaseService.client.storage
                        .from('media')
                        .getPublicUrl(storagePath);
                    _sendMessage(
                      type: 'audio',
                      mediaUrl: url,
                      mediaType: 'audio',
                      mediaDuration: duration,
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erro ao enviar áudio: $e'),
                          backgroundColor: AppTheme.errorColor,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                onCancel: () => setState(() => _isRecordingVoice = false),
              ),
            )
          else
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Botão de mídia (+)
                  GestureDetector(
                    onTap: () => _showMediaOptions(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: AppTheme.primaryColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Message...',
                                hintStyle: TextStyle(
                                    color: Colors.grey[600], fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              maxLines: 4,
                              minLines: 1,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(
                                  () => _showEmojiPicker = !_showEmojiPicker);
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(Icons.emoji_emotions_outlined,
                                  color: Colors.grey[600], size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botão enviar
                  GestureDetector(
                    onTap: _isSending ? null : () => _sendMessage(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
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
  // MEDIA OPTIONS BOTTOM SHEET (19+ tipos) — Estilo Amino
  // ========================================================================
  void _showMediaOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MediaOptionItem(
                  icon: Icons.image_rounded,
                  label: 'Image',
                  color: AppTheme.primaryColor,
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendImage();
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.gif_rounded,
                  label: 'GIF',
                  color: const Color(0xFF9C27B0),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final gifUrl = await GiphyPicker.show(context);
                    if (gifUrl != null) {
                      _sendMessage(type: 'gif', mediaUrl: gifUrl, mediaType: 'gif');
                    }
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.emoji_emotions_rounded,
                  label: 'Sticker',
                  color: const Color(0xFFFF9800),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final sticker = await StickerPicker.show(context);
                    if (sticker != null) {
                      _sendMessage(
                        type: 'sticker',
                        mediaUrl: sticker['sticker_url'] as String?,
                        stickerId: sticker['sticker_id'] as String?,
                        stickerUrl: sticker['sticker_url'] as String?,
                      );
                    }
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.mic_rounded,
                  label: 'Audio',
                  color: const Color(0xFFE91E63),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _isRecordingVoice = true);
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.poll_rounded,
                  label: 'Poll',
                  color: const Color(0xFF00BCD4),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showInlinePollCreator();
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.monetization_on_rounded,
                  label: 'Tip',
                  color: AppTheme.warningColor,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showTipDialog();
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.headset_mic_rounded,
                  label: 'Voice',
                  color: const Color(0xFF4CAF50),
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendMessage(type: 'voice_chat');
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.video_call_rounded,
                  label: 'Video',
                  color: const Color(0xFF2196F3),
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendMessage(type: 'video_chat');
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.live_tv_rounded,
                  label: 'Screening',
                  color: const Color(0xFFFF5722),
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendMessage(type: 'screening_room');
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
          backgroundColor: AppTheme.surfaceColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Criar Enquete',
              style: TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogInput(questionCtrl, 'Pergunta'),
                const SizedBox(height: 8),
                ...List.generate(
                    optionCtrls.length,
                    (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _dialogInput(optionCtrls[i], 'Option ${i + 1}'),
                        )),
                GestureDetector(
                  onTap: () => setDialogState(
                      () => optionCtrls.add(TextEditingController())),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 4),
                        const Text('Adicionar Opção',
                            style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancelar',
                    style: TextStyle(color: Colors.grey[500]))),
            ElevatedButton(
              onPressed: () {
                final question = questionCtrl.text;
                final options = optionCtrls
                    .map((c) => c.text)
                    .where((t) => t.isNotEmpty)
                    .toList();
                Navigator.pop(ctx);
                _sendMessage(
                  type: 'poll',
                  pollQuestion: question,
                  pollOptions: options,
                );
                questionCtrl.dispose();
                for (final c in optionCtrls) {
                  c.dispose();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Enviar',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
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
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Compartilhar Link',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: _dialogInput(linkCtrl, 'https://...', icon: Icons.link_rounded),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: TextStyle(color: Colors.grey[500]))),
          ElevatedButton(
            onPressed: () {
              final url = linkCtrl.text;
              Navigator.pop(ctx);
              _sendMessage(type: 'link', sharedUrl: url);
              linkCtrl.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Enviar',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _dialogInput(TextEditingController controller, String hint,
      {IconData? icon}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[700], fontSize: 13),
          prefixIcon:
              icon != null ? Icon(icon, size: 18, color: Colors.grey[600]) : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // ========================================================================
  // MESSAGE ACTIONS (Long Press) — Estilo Amino
  // ========================================================================
  void _showMessageActions(MessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
                          decoration: const BoxDecoration(
                            color: AppTheme.cardColor,
                            shape: BoxShape.circle,
                          ),
                          child:
                              Text(emoji, style: const TextStyle(fontSize: 22)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _actionTile(Icons.reply_rounded, 'Responder', () {
              Navigator.pop(ctx);
              setState(() => _replyingTo = message);
            }),
            _actionTile(Icons.copy_rounded, 'Copiar', () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: message.content ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copiado!'),
                  backgroundColor: AppTheme.primaryColor,
                ),
              );
            }),
            _actionTile(Icons.forward_rounded, 'Encaminhar', () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: message.content ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Mensagem copiada! Cole em outro chat para encaminhar.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }),
            _actionTile(Icons.push_pin_rounded, 'Fixar Mensagem', () {
              Navigator.pop(ctx);
              _pinMessage(message.id);
            }),
            if (message.authorId == SupabaseService.currentUserId)
              _actionTile(Icons.delete_rounded, 'Excluir', () async {
                Navigator.pop(ctx);
                try {
                  await SupabaseService.table('chat_messages')
                      .delete()
                      .eq('id', message.id);
                  if (mounted) setState(() => _messages.remove(message));
                } catch (_) {}
              }, isDestructive: true),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap,
      {bool isDestructive = false}) {
    final color = isDestructive ? AppTheme.errorColor : Colors.grey[400];
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showPinnedMessages() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Mensagens Fixadas',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            ..._pinnedMessages.map((m) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Text(m['content'] as String? ?? '',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[300])),
                )),
          ],
        ),
      ),
    );
  }

  Widget _badgeIcon(IconData icon, int count) {
    return Container(
      width: 34,
      height: 34,
      margin: const EdgeInsets.only(right: 4),
      child: Stack(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.grey[500], size: 16),
          ),
          if (count > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.scaffoldBg, width: 1.5),
                ),
                constraints:
                    const BoxConstraints(minWidth: 14, minHeight: 14),
                child: Text(
                  '$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
      String value, IconData icon, String label,
      {bool isDestructive = false}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: isDestructive ? AppTheme.errorColor : Colors.grey[400]),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color:
                      isDestructive ? AppTheme.errorColor : Colors.grey[300],
                  fontSize: 13)),
        ],
      ),
    );
  }
}

// ============================================================================
// MESSAGE BUBBLE (suporta todos os 19+ tipos) — Estilo Amino
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content ?? '',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
                backgroundColor: AppTheme.surfaceColor,
                backgroundImage: message.author?.iconUrl != null
                    ? CachedNetworkImageProvider(message.author!.iconUrl!)
                    : null,
                child: message.author?.iconUrl == null
                    ? Text(
                        (message.author?.nickname ?? '?')[0].toUpperCase(),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400]),
                      )
                    : null,
              ),
            )
          else if (!isMe)
            const SizedBox(width: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.primaryColor
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      Radius.circular(isMe ? 16 : (showAvatar ? 4 : 16)),
                  bottomRight:
                      Radius.circular(isMe ? (showAvatar ? 4 : 16) : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.author?.nickname ?? 'User',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
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
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.grey[600],
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

    // O banco armazena o tipo mapeado (ex: 'text' para imagens, 'system_tip' para tips)
    // Precisamos detectar o tipo real pelo conteúdo/campos

    // Imagem: tipo text mas com media_url e media_type == 'image'
    if (message.mediaUrl != null && message.mediaType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: message.mediaUrl!,
          width: 200,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 200, height: 150,
            color: Colors.grey[800],
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }

    // GIF: tipo text mas com media_url e media_type == 'gif'
    if (message.mediaUrl != null && message.mediaType == 'gif') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: message.mediaUrl!,
          width: 180,
          fit: BoxFit.cover,
        ),
      );
    }

    // Sticker
    if (type == 'sticker' || message.stickerUrl != null) {
      final url = message.stickerUrl ?? message.mediaUrl;
      return url != null
          ? CachedNetworkImage(imageUrl: url, width: 120, height: 120)
          : const Text('🎭', style: TextStyle(fontSize: 48));
    }

    // Voice note
    if (type == 'voice_note') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_rounded, color: textColor, size: 32),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Audio', style: TextStyle(color: textColor, fontSize: 13)),
              if (message.mediaDuration != null)
                Text('${message.mediaDuration}s',
                    style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 11)),
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
    }

    // Video
    if (type == 'video') {
      return Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.play_circle_rounded, color: Colors.white, size: 48),
        ),
      );
    }

    // System messages (tip, voice start, etc.)
    if (type == 'system_tip') {
      final amount = message.tipAmount ?? 0;
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
            Text('$amount coins',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warningColor)),
          ],
        ),
      );
    }

    if (type == 'system_voice_start' || type == 'system_screen_start') {
      final isVoice = type == 'system_voice_start';
      final icon = isVoice ? Icons.headset_mic_rounded : Icons.live_tv_rounded;
      final label = isVoice ? 'Voice Chat' : 'Screening Room';
      final accentColor = isVoice
          ? const Color(0xFF4CAF50)
          : const Color(0xFFFF5722);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accentColor),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: accentColor)),
          ],
        ),
      );
    }

    // Link (share_url)
    if (type == 'share_url' || message.sharedUrl != null) {
      final url = message.sharedUrl ?? message.content ?? '';
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
                    url,
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
          if (message.content != null && message.content != url && message.content!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(message.content!,
                  style: TextStyle(color: textColor, fontSize: 14)),
            ),
        ],
      );
    }

    // Poll (armazenado como text com JSON no content)
    if (message.content != null && message.content!.startsWith('{"question"')) {
      try {
        // Tentar parsear o JSON do poll
        final content = message.content!;
        final questionMatch = RegExp(r'"question":"([^"]*)"').firstMatch(content);
        final question = questionMatch?.group(1) ?? 'Enquete';
        final optionsMatch = RegExp(r'"options":\[(.*?)\]').firstMatch(content);
        final optionsStr = optionsMatch?.group(1) ?? '';
        final options = RegExp(r'"([^"]*)"').allMatches(optionsStr).map((m) => m.group(1) ?? '').toList();

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(opt,
                      style: TextStyle(color: textColor, fontSize: 13)),
                )),
          ],
        );
      } catch (_) {
        // Se falhar o parse, mostra como texto normal
      }
    }

    // Reply (tipo text com reply_to_id)
    if (message.replyToId != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.5)
                        : AppTheme.primaryColor,
                    width: 3),
              ),
            ),
            child: Text(
              'Respondendo...',
              style: TextStyle(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.grey[500],
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
    }

    // Shared user
    if (type == 'share_user') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_rounded, color: textColor, size: 16),
            const SizedBox(width: 8),
            Text('Perfil compartilhado',
                style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    // Default: texto simples
    return Text(
      message.content ?? '',
      style: TextStyle(color: textColor, fontSize: 14),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// MEDIA OPTION ITEM — Estilo Amino
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
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
