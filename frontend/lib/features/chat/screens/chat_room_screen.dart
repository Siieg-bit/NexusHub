
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/message_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/call_service.dart';
import '../../../core/services/realtime_service.dart';
import 'call_screen.dart';
import '../widgets/giphy_picker.dart';
import '../widgets/forward_message_sheet.dart';
import '../widgets/sticker_picker.dart';
import '../widgets/voice_recorder.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_reply_preview.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_media_sheet.dart';
import '../widgets/chat_message_actions.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/media_utils.dart';

/// =============================================================================
/// ChatRoomScreen — Tela principal de chat.
///
/// Responsabilidades restantes após extração Sprint 3A:
/// - Lifecycle (init, dispose, membership)
/// - Data loading (thread info, messages, pinned, background)
/// - Realtime subscription
/// - Message sending (todos os tipos)
/// - Media upload (image, video, voice)
/// - Dialogs (tip, poll, link, edit, background)
/// - Orquestração do build (AppBar, body, input)
///
/// Widgets extraídos:
/// - MessageBubble (message_bubble.dart)
/// - MediaOptionItem (message_bubble.dart)
/// - ChatReplyPreview (chat_reply_preview.dart)
/// - ChatInputBar (chat_input_bar.dart)
/// - ChatMediaSheet (chat_media_sheet.dart)
/// - ChatMessageActionsSheet (chat_message_actions.dart)
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
  bool _isLoading = true;
  bool _realtimeConnected = true;
  bool _isSending = false;
  bool _membershipConfirmed = false;
  Map<String, dynamic>? _threadInfo;
  MessageModel? _replyingTo;
  bool _showEmojiPicker = false;
  bool _isRecordingVoice = false;
  List<Map<String, dynamic>> _pinnedMessages = [];
  String? _chatBackground;

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    await _loadThreadInfo();
    if (!mounted) return;
    await _ensureMembership();
    if (!mounted) return;
    _loadMessages();
    _loadPinnedMessages();
    _subscribeToRealtime();
    _loadChatBackground();
  }

  Future<void> _ensureMembership() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        debugPrint('[ChatRoom] _ensureMembership: userId is null');
        return;
      }
      final result = await SupabaseService.rpc('join_public_chat_with_reputation', params: {
        'p_thread_id': widget.threadId,
        'p_user_id': userId,
      });
      // RPC retorna {joined: true} ou {joined: false, reason: 'already_member'}
      // Ambos significam que o usuário é membro agora.
      _membershipConfirmed = true;
      debugPrint('[ChatRoom] Membership confirmed: $result');
    } catch (e) {
      debugPrint('[ChatRoom] Membership check FAILED: $e');
      // Tentar verificar membership diretamente como fallback
      try {
        final userId = SupabaseService.currentUserId;
        if (userId == null) return;
        final check = await SupabaseService.table('chat_members')
            .select('id')
            .eq('thread_id', widget.threadId)
            .eq('user_id', userId)
            .maybeSingle();
        if (check != null) {
          _membershipConfirmed = true;
          debugPrint('[ChatRoom] Membership confirmed via direct check');
        }
      } catch (e2) {
        debugPrint('[ChatRoom] Fallback membership check also failed: $e2');
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    RealtimeService.instance.unsubscribe('chat:${widget.threadId}');
    RealtimeService.instance.connectionStatus
        .removeListener(_onRealtimeStatusChanged);
    super.dispose();
  }

  void _onRealtimeStatusChanged() {
    if (!mounted) return;
    final status = RealtimeService.instance.connectionStatus.value;
    final connected = status == RealtimeConnectionStatus.connected;
    if (connected != _realtimeConnected) {
      setState(() => _realtimeConnected = connected);
    }
  }

  // ==========================================================================
  // DATA LOADING
  // ==========================================================================

  Future<void> _loadThreadInfo() async {
    try {
      final res = await SupabaseService.table('chat_threads')
          .select()
          .eq('id', widget.threadId)
          .single();
      if (!mounted) return;
      if (mounted) setState(() => _threadInfo = res);
    } catch (_) {}
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
            (response as List? ?? []).map((e) {
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
      if (!mounted) return;
      final pinnedId = threadData['pinned_message_id'] as String?;
      if (pinnedId == null) {
        if (!mounted) return;
        if (mounted) setState(() => _pinnedMessages = []);
        return;
      }
      final res = await SupabaseService.table('chat_messages')
          .select('*, profiles!chat_messages_author_id_fkey(id, nickname, icon_url)')
          .eq('id', pinnedId)
          .limit(1);
      if (mounted) {
        setState(() {
          _pinnedMessages = List<Map<String, dynamic>>.from(res as List? ?? []);
        });
      }
    } catch (_) {}
  }

  // ==========================================================================
  // BACKGROUND CUSTOMIZÁVEL
  // ==========================================================================

  Future<void> _loadChatBackground() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final res = await SupabaseService.table('chat_backgrounds')
          .select('background_url')
          .eq('thread_id', widget.threadId)
          .eq('user_id', userId)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() => _chatBackground = res['background_url'] as String?);
      }
    } catch (_) {}
  }

  void _showBackgroundPicker() {
    final r = context.r;
    final urlCtrl = TextEditingController(text: _chatBackground ?? '');
    final presets = [
      null,
      'https://images.unsplash.com/photo-1518655048521-f130df041f66?w=800',
      'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
      'https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?w=800',
      'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800',
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: r.s(16), right: r.s(16), top: r.s(20),
            bottom: MediaQuery.of(ctx).viewInsets.bottom + r.s(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fundo do Chat', style: TextStyle(fontSize: r.fs(18), fontWeight: FontWeight.w800, color: context.textPrimary)),
              SizedBox(height: r.s(16)),
              SizedBox(
                height: r.s(80),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: presets.length,
                  itemBuilder: (_, i) {
                    final url = presets[i];
                    final isSelected = _chatBackground == url;
                    return GestureDetector(
                      onTap: () async {
                        await _saveChatBackground(url);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Container(
                        width: r.s(80),
                        height: r.s(80),
                        margin: EdgeInsets.only(right: r.s(8)),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(r.s(10)),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                            width: 2,
                          ),
                          color: url == null ? context.cardBg : null,
                          image: url != null ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
                        ),
                        child: url == null
                            ? Icon(Icons.block_rounded, color: Colors.grey[500], size: r.s(28))
                            : null,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: r.s(12)),
              TextField(
                controller: urlCtrl,
                style: TextStyle(color: context.textPrimary, fontSize: r.fs(13)),
                decoration: InputDecoration(
                  hintText: 'URL personalizada do fundo...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: context.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(10)),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.link_rounded, size: r.s(18), color: Colors.grey[600]),
                ),
              ),
              SizedBox(height: r.s(12)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(12))),
                    padding: EdgeInsets.symmetric(vertical: r.s(12)),
                  ),
                  onPressed: () async {
                    final url = urlCtrl.text.trim().isNotEmpty ? urlCtrl.text.trim() : null;
                    await _saveChatBackground(url);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text('Aplicar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: r.fs(14))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveChatBackground(String? url) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      await SupabaseService.table('chat_backgrounds').upsert({
        'thread_id': widget.threadId,
        'user_id': userId,
        'background_url': url,
      });
      if (!mounted) return;
      if (mounted) setState(() => _chatBackground = url);
    } catch (e) {
      debugPrint('[ChatRoom] Background save error: $e');
    }
  }

  // ==========================================================================
  // REALTIME
  // ==========================================================================

  void _subscribeToRealtime() {
    // Usar RealtimeService para reconexão automática com backoff
    RealtimeService.instance.subscribeWithRetry(
      channelName: 'chat:${widget.threadId}',
      configure: (channel) {
        channel.onPostgresChanges(
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
              if (_messages.any((m) => m.id == newMessage['id'])) return;
              try {
                final authorId = newMessage['author_id'] as String?;
                if (authorId != null) {
                  final senderData = await SupabaseService.table('profiles')
                      .select('id, nickname, icon_url')
                      .eq('id', authorId)
                      .single();
                  if (!mounted) return;
                  newMessage['sender'] = senderData;
                  newMessage['author'] = senderData;
                }
              } catch (_) {}
              final message = MessageModel.fromJson(newMessage);
              if (mounted) {
                setState(() => _messages.insert(0, message));
                _scrollToBottom();
              }
            } catch (e) {
              debugPrint('Realtime message error: $e');
            }
          },
        );
      },
    );

    // Escutar mudanças de status de conexão
    RealtimeService.instance.connectionStatus
        .addListener(_onRealtimeStatusChanged);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ==========================================================================
  // CHAMADAS (Voice / Video)
  // ==========================================================================

  Future<void> _startCall(CallType type) async {
    final msgType = type == CallType.video ? 'video_chat' : 'voice_chat';
    _sendMessage(type: msgType);
    final session = await CallService.createCall(
      threadId: widget.threadId,
      type: type,
    );
    if (session != null && mounted) {
      await CallScreen.show(context, session);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Não foi possível iniciar a chamada. Verifique as permissões.'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ==========================================================================
  // ENVIAR MENSAGEM (suporta todos os tipos)
  // ==========================================================================

  String _mapMessageType(String type) {
    const validTypes = {
      'text', 'strike', 'voice_note', 'sticker', 'video',
      'share_url', 'share_user', 'system_deleted', 'system_join',
      'system_leave', 'system_voice_start', 'system_voice_end',
      'system_screen_start', 'system_screen_end', 'system_tip',
      'system_pin', 'system_unpin', 'system_removed', 'system_admin_delete',
    };
    if (validTypes.contains(type)) return type;
    switch (type) {
      case 'image': return 'text';
      case 'gif':   return 'text';
      case 'audio': return 'voice_note';
      case 'reply': return 'text';
      case 'voice_chat': return 'system_voice_start';
      case 'video_chat': return 'system_voice_start';
      case 'screening_room': return 'system_screen_start';
      case 'poll': return 'text';
      case 'link': return 'share_url';
      case 'tip': return 'system_tip';
      case 'forward': return 'text';
      case 'file': return 'text';
      default: return 'text';
    }
  }

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

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sessão expirada. Faça login novamente.'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    _messageController.clear();
    setState(() => _isSending = true);

    // Se membership não foi confirmada, tentar novamente antes de enviar
    if (!_membershipConfirmed) {
      await _ensureMembership();
      if (!_membershipConfirmed && mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível confirmar sua participação neste chat.'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    try {
      final mappedType = _mapMessageType(type);

      String content;
      if (type == 'poll' && pollQuestion != null) {
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

      String? finalMediaUrl = mediaUrl;
      if (type == 'image' && mediaUrl != null) finalMediaUrl = mediaUrl;
      if (type == 'gif' && mediaUrl != null) finalMediaUrl = mediaUrl;
      if (stickerUrl != null) finalMediaUrl = stickerUrl;

      String? replyToId;
      if (_replyingTo != null) {
        replyToId = _replyingTo!.id;
        setState(() => _replyingTo = null);
      }

      await SupabaseService.rpc('send_chat_message_with_reputation', params: {
        'p_thread_id': widget.threadId,
        'p_author_id': userId,
        'p_content': content,
        'p_type': mappedType,
        'p_media_url': finalMediaUrl,
        'p_reply_to': replyToId,
      });
    } catch (e) {
      debugPrint('[ChatRoom] Send message error: $e');
      if (mounted) {
        // Mostrar mensagem de erro mais específica
        String errorMsg = 'Erro ao enviar. Tente novamente.';
        final errorStr = e.toString();
        if (errorStr.contains('not a member')) {
          errorMsg = 'Você não é membro deste chat. Tente sair e entrar novamente.';
          _membershipConfirmed = false; // Resetar para re-tentar join
        } else if (errorStr.contains('null') || errorStr.contains('session')) {
          errorMsg = 'Sessão expirada. Faça login novamente.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ==========================================================================
  // MEDIA UPLOAD
  // ==========================================================================

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path = 'chat/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);
      await SupabaseService.storage
          .from('chat-media')
          .uploadBinary(path, bytes);
      final url = SupabaseService.storage.from('chat-media').getPublicUrl(path);
      await _sendMessage(type: 'image', mediaUrl: url, mediaType: 'image');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no upload. Tente novamente.'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _sendVideoFile() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    final error = await MediaUtils.validateVideoDuration(video.path);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final ext = video.path.split('.').last.toLowerCase();
      final path = 'chat/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await video.readAsBytes();
      await SupabaseService.storage
          .from('chat-media')
          .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'video/mp4'));
      final url = SupabaseService.storage.from('chat-media').getPublicUrl(path);
      await _sendMessage(type: 'video', mediaUrl: url, mediaType: 'video');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no upload do vídeo. Tente novamente.'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ==========================================================================
  // REACTIONS & PIN
  // ==========================================================================

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
    } catch (e) {
      debugPrint('[chat_room_screen] Erro: $e');
    }
  }

  Future<void> _pinMessage(String messageId) async {
    try {
      await SupabaseService.table('chat_threads')
          .update({'pinned_message_id': messageId}).eq('id', widget.threadId);
      await _loadPinnedMessages();
    } catch (e) {
      debugPrint('[chat_room_screen] Erro: $e');
    }
  }

  // ==========================================================================
  // DIALOGS (Tip, Poll, Link, Edit)
  // ==========================================================================

  Future<void> _showTipDialog() async {
    final r = context.r;
    final customController = TextEditingController();
    int? selectedAmount;

    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.all(r.s(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: r.s(40), height: r.s(4),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: r.s(16)),
              Row(
                children: [
                  Container(
                    width: r.s(44), height: r.s(44),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.monetization_on_rounded,
                        color: AppTheme.warningColor, size: r.s(24)),
                  ),
                  SizedBox(width: r.s(12)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Enviar Gorjeta',
                          style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: r.fs(18))),
                      Text('Envie moedas para este chat',
                          style: TextStyle(color: Colors.grey, fontSize: r.fs(13))),
                    ],
                  ),
                ],
              ),
              SizedBox(height: r.s(20)),
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
                      width: r.s(72), height: r.s(72),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.warningColor.withValues(alpha: 0.15)
                            : context.cardBg,
                        borderRadius: BorderRadius.circular(r.s(14)),
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
                              size: r.s(22)),
                          SizedBox(height: r.s(4)),
                          Text('$amount',
                              style: TextStyle(
                                color: isSelected
                                    ? AppTheme.warningColor
                                    : context.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: r.fs(15),
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: r.s(16)),
              TextField(
                controller: customController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: context.textPrimary),
                onChanged: (val) => setModalState(() {
                  selectedAmount = int.tryParse(val);
                }),
                decoration: InputDecoration(
                  hintText: 'Ou digite um valor...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(Icons.edit_rounded,
                      color: AppTheme.warningColor, size: r.s(18)),
                  filled: true,
                  fillColor: context.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(12)),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: r.s(16), vertical: r.s(12)),
                ),
              ),
              SizedBox(height: r.s(20)),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: selectedAmount != null && selectedAmount! > 0
                      ? () => Navigator.pop(ctx, selectedAmount)
                      : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: r.s(14)),
                    decoration: BoxDecoration(
                      color: selectedAmount != null && selectedAmount! > 0
                          ? AppTheme.warningColor
                          : Colors.grey[800],
                      borderRadius: BorderRadius.circular(r.s(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded,
                            color: Colors.white, size: r.s(18)),
                        SizedBox(width: r.s(8)),
                        Text(
                          selectedAmount != null && selectedAmount! > 0
                              ? 'Enviar $selectedAmount moedas'
                              : 'Selecione um valor',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: r.fs(15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: r.s(8)),
            ],
          ),
        ),
      ),
    );
    customController.dispose();
    if (result == null || result <= 0) return;

    try {
      await SupabaseService.rpc('transfer_coins', params: {
        'p_receiver_id': _threadInfo?['host_id'] ?? '',
        'p_amount': result,
      });
    } catch (_) {}

    await _sendMessage(type: 'tip', tipAmount: result);
  }

  void _showInlinePollCreator() {
    final r = context.r;
    final questionCtrl = TextEditingController();
    final optionCtrls = [TextEditingController(), TextEditingController()];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(16))),
          title: Text('Criar Enquete',
              style: TextStyle(
                  color: context.textPrimary, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogInput(questionCtrl, 'Pergunta'),
                SizedBox(height: r.s(8)),
                ...List.generate(
                    optionCtrls.length,
                    (i) => Padding(
                          padding: EdgeInsets.only(bottom: r.s(4)),
                          child: _dialogInput(optionCtrls[i], 'Option ${i + 1}'),
                        )),
                GestureDetector(
                  onTap: () => setDialogState(
                      () => optionCtrls.add(TextEditingController())),
                  child: Padding(
                    padding: EdgeInsets.only(top: r.s(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            size: r.s(16), color: AppTheme.primaryColor),
                        SizedBox(width: r.s(4)),
                        Text('Adicionar Opção',
                            style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: r.fs(13),
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
                for (final c in optionCtrls) { c.dispose(); }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(10))),
              ),
              child: const Text('Enviar',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    ).then((_) {
      questionCtrl.dispose();
      for (final c in optionCtrls) { c.dispose(); }
    });
  }

  void _showLinkInput() {
    final r = context.r;
    final linkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(16))),
        title: Text('Compartilhar Link',
            style: TextStyle(
                color: context.textPrimary, fontWeight: FontWeight.w700)),
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
                  borderRadius: BorderRadius.circular(r.s(10))),
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
    final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(10)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: context.textPrimary, fontSize: r.fs(13)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[700], fontSize: r.fs(13)),
          prefixIcon:
              icon != null ? Icon(icon, size: r.s(18), color: Colors.grey[600]) : null,
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(12)),
        ),
      ),
    );
  }

  void _showEditMessageDialog(MessageModel message) {
    final r = context.r;
    final editController = TextEditingController(text: message.content ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(16))),
        title: Text('Editar Mensagem',
            style: TextStyle(
                color: context.textPrimary, fontWeight: FontWeight.w700)),
        content: Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(r.s(10)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: TextField(
            controller: editController,
            autofocus: true,
            style: TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
            decoration: InputDecoration(
              hintText: 'Editar mensagem...',
              hintStyle: TextStyle(color: Colors.grey[700], fontSize: r.fs(14)),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(12)),
            ),
            maxLines: 6,
            minLines: 1,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              editController.dispose();
            },
            child: Text('Cancelar',
                style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () async {
              final newContent = editController.text.trim();
              Navigator.pop(ctx);
              if (newContent.isNotEmpty && newContent != message.content) {
                try {
                  await SupabaseService.rpc('edit_chat_message', params: {
                    'p_message_id': message.id,
                    'p_new_content': newContent,
                  });
                  if (mounted) {
                    final idx = _messages.indexWhere((m) => m.id == message.id);
                    if (idx >= 0) {
                      setState(() {
                        _messages[idx] = _messages[idx].copyWith(
                          content: newContent,
                          editedAt: DateTime.now(),
                        );
                      });
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao editar. Tente novamente.'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              }
              editController.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(10))),
            ),
            child: const Text('Salvar',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MESSAGE ACTIONS — Delegação para ChatMessageActionsSheet
  // ==========================================================================

  void _showMessageActions(MessageModel message) async {
    final action = await ChatMessageActionsSheet.show(
      context,
      message: message,
      onReaction: (emoji) => _addReaction(message.id, emoji),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case ChatMessageAction.reply:
        setState(() => _replyingTo = message);
        break;
      case ChatMessageAction.copy:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copiado!'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
        break;
      case ChatMessageAction.edit:
        _showEditMessageDialog(message);
        break;
      case ChatMessageAction.forward:
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ForwardMessageSheet(
            messageContent: message.content ?? '',
            mediaUrl: message.mediaUrl,
            mediaType: message.mediaType,
          ),
        );
        break;
      case ChatMessageAction.pin:
        _pinMessage(message.id);
        break;
      case ChatMessageAction.deleteForMe:
        try {
          await SupabaseService.rpc('delete_chat_message_for_me', params: {
            'p_message_id': message.id,
          });
          if (mounted) setState(() => _messages.remove(message));
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao apagar. Tente novamente.'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
        break;
      case ChatMessageAction.deleteForAll:
        try {
          await SupabaseService.rpc('delete_chat_message_for_all', params: {
            'p_message_id': message.id,
          });
          if (mounted) {
            final idx = _messages.indexWhere((m) => m.id == message.id);
            if (idx >= 0) {
              setState(() {
                _messages[idx] = _messages[idx].copyWith(
                  type: 'system_deleted',
                  content: 'Mensagem apagada',
                  isDeleted: true,
                );
              });
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao apagar. Tente novamente.'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
        break;
      case ChatMessageAction.report:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Denúncia enviada. Obrigado!'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
        break;
    }
  }

  // ==========================================================================
  // PINNED MESSAGES SHEET
  // ==========================================================================

  void _showPinnedMessages() {
    final r = context.r;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(r.s(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: r.s(36),
              height: r.s(4),
              margin: EdgeInsets.only(bottom: r.s(16)),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Mensagens Fixadas',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(16),
                    color: context.textPrimary)),
            SizedBox(height: r.s(12)),
            ..._pinnedMessages.map((m) => Container(
                  margin: EdgeInsets.only(bottom: r.s(8)),
                  padding: EdgeInsets.all(r.s(12)),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(r.s(12)),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Text(m['content'] as String? ?? '',
                      style: TextStyle(
                          fontSize: r.fs(13), color: Colors.grey[300])),
                )),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final currentUserId = SupabaseService.currentUserId;
    final threadTitle = _threadInfo?['title'] as String? ?? 'Chat';
    final threadType = _threadInfo?['type'] as String? ?? 'group';
    final memberCount = (_threadInfo?['member_count'] ?? _threadInfo?['members_count']) as int? ?? 0;
    final threadIcon = _threadInfo?['icon_url'] as String?;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: context.textPrimary, size: r.s(20)),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: context.surfaceColor,
              backgroundImage: threadIcon != null
                  ? CachedNetworkImageProvider(threadIcon)
                  : null,
              child: threadIcon == null
                  ? Icon(
                      threadType == 'dm'
                          ? Icons.person_rounded
                          : Icons.group_rounded,
                      color: Colors.grey[500],
                      size: r.s(16),
                    )
                  : null,
            ),
            SizedBox(width: r.s(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(threadTitle,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(15),
                          color: context.textPrimary)),
                  if (threadType != 'dm')
                    Text('$memberCount members',
                        style: TextStyle(
                            fontSize: r.fs(11), color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_pinnedMessages.isNotEmpty)
            GestureDetector(
              onTap: _showPinnedMessages,
              child: _badgeIcon(Icons.push_pin_rounded, _pinnedMessages.length),
            ),
          GestureDetector(
            onTap: () => _startCall(CallType.voice),
            child: Container(
              width: r.s(34),
              height: r.s(34),
              margin: EdgeInsets.only(right: r.s(4)),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mic_rounded, color: Colors.grey[500], size: r.s(16)),
            ),
          ),
          GestureDetector(
            onTap: () => _startCall(CallType.video),
            child: Container(
              width: r.s(34),
              height: r.s(34),
              margin: EdgeInsets.only(right: r.s(4)),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.videocam_rounded, color: Colors.grey[500], size: r.s(16)),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: Colors.grey[500]),
            color: context.surfaceColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(12))),
            onSelected: (val) {
              switch (val) {
                case 'members':
                  break;
                case 'settings':
                  break;
                case 'background':
                  _showBackgroundPicker();
                  break;
                case 'leave':
                  break;
              }
            },
            itemBuilder: (ctx) => [
              _buildPopupItem(r, 'members', Icons.people_rounded, 'Membros'),
              _buildPopupItem(r, 'settings', Icons.settings_rounded, 'Configurações'),
              _buildPopupItem(r, 'background', Icons.wallpaper_rounded, 'Fundo do Chat'),
              _buildPopupItem(
                  r, 'leave', Icons.exit_to_app_rounded, 'Sair do Chat',
                  isDestructive: true),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: _chatBackground != null
            ? BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(_chatBackground!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.45),
                    BlendMode.darken,
                  ),
                ),
              )
            : null,
        child: Column(
        children: [
          // ── Connection status banner ──
          if (!_realtimeConnected)
            Container(
              width: double.infinity,
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(6)),
              color: AppTheme.warningColor.withValues(alpha: 0.12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: r.s(12),
                    height: r.s(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppTheme.warningColor,
                    ),
                  ),
                  SizedBox(width: r.s(8)),
                  Text(
                    'Reconectando...',
                    style: TextStyle(
                      fontSize: r.fs(12),
                      color: AppTheme.warningColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // ── Pinned message banner ──
          if (_pinnedMessages.isNotEmpty)
            GestureDetector(
              onTap: _showPinnedMessages,
              child: Container(
                width: double.infinity,
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.08),
                  border: Border(
                    bottom: BorderSide(
                        color: AppTheme.warningColor.withValues(alpha: 0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.push_pin_rounded,
                        size: r.s(14), color: AppTheme.warningColor),
                    SizedBox(width: r.s(8)),
                    Expanded(
                      child: Text(
                        _pinnedMessages.first['content'] as String? ??
                            'Mensagem fixada',
                        style: TextStyle(
                            fontSize: r.fs(12), color: Colors.grey[400]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_right_rounded,
                        size: r.s(16), color: Colors.grey[600]),
                  ],
                ),
              ),
            ),

          // ── Message list ──
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
                              width: r.s(72),
                              height: r.s(72),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.chat_bubble_outline_rounded,
                                  size: r.s(32), color: Colors.grey[700]),
                            ),
                            SizedBox(height: r.s(16)),
                            Text('Nenhuma mensagem ainda',
                                style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: r.fs(15),
                                    fontWeight: FontWeight.w600)),
                            SizedBox(height: r.s(6)),
                            Text('Comece a conversa!',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: r.fs(12))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(12), vertical: r.s(8)),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message.authorId == currentUserId;
                          final showAvatar = index == _messages.length - 1 ||
                              _messages[index + 1].authorId != message.authorId;

                          return RepaintBoundary(
                            child: GestureDetector(
                              onLongPress: () => _showMessageActions(message),
                              child: MessageBubble(
                                message: message,
                                isMe: isMe,
                                showAvatar: showAvatar,
                                onReactionTap: (emoji) =>
                                    _addReaction(message.id, emoji),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // ── Reply preview ──
          if (_replyingTo != null)
            ChatReplyPreview(
              replyingTo: _replyingTo!,
              onDismiss: () => setState(() => _replyingTo = null),
            ),

          // ── Voice recorder / Input bar ──
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
                    if (!mounted) return;
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
                          content: Text('Erro ao enviar áudio. Tente novamente.'),
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
            ChatInputBar(
              controller: _messageController,
              isSending: _isSending,
              onMediaTap: () => _showMediaOptions(context),
              onSend: () => _sendMessage(),
              onEmojiToggle: () =>
                  setState(() => _showEmojiPicker = !_showEmojiPicker),
              onTextChanged: _onTextChanged,
            ),

          // ── Emoji picker ──
          if (_showEmojiPicker)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.3 > 250 ? 250 : MediaQuery.of(context).size.height * 0.3,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _messageController.text += emoji.emoji;
                  _messageController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _messageController.text.length),
                  );
                },
                config: Config(
                  columns: 8,
                  emojiSizeMax: 28,
                  bgColor: context.scaffoldBg,
                  indicatorColor: AppTheme.primaryColor,
                  iconColorSelected: AppTheme.primaryColor,
                  iconColor: (Colors.grey[600] ?? Colors.grey),
                  checkPlatformCompatibility: true,
                  recentTabBehavior: RecentTabBehavior.RECENT,
                  recentsLimit: 20,
                  noRecents: Text(
                    'Nenhum emoji recente',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }

  // ==========================================================================
  // MEDIA OPTIONS — Delegação para ChatMediaSheet
  // ==========================================================================

  void _showMediaOptions(BuildContext context) {
    ChatMediaSheet.show(
      context,
      onImage: _sendImage,
      onGif: () async {
        final gifUrl = await GiphyPicker.show(context);
        if (gifUrl != null) {
          _sendMessage(type: 'gif', mediaUrl: gifUrl, mediaType: 'gif');
        }
      },
      onSticker: () async {
        final sticker = await StickerPicker.show(context);
        if (!mounted) return;
        if (sticker != null) {
          _sendMessage(
            type: 'sticker',
            mediaUrl: sticker['sticker_url'],
            stickerId: sticker['sticker_id'],
            stickerUrl: sticker['sticker_url'],
          );
        }
      },
      onAudio: () => setState(() => _isRecordingVoice = true),
      onPoll: _showInlinePollCreator,
      onTip: _showTipDialog,
      onVoiceCall: () => _startCall(CallType.voice),
      onVideoCall: () => _startCall(CallType.video),
      onScreening: () => _sendMessage(type: 'screening_room'),
      onLink: _showLinkInput,
      onVideoFile: _sendVideoFile,
    );
  }

  // ==========================================================================
  // LINK DETECTION (onTextChanged)
  // ==========================================================================

  void _onTextChanged(String value) {
    final urlRegex = RegExp(
      r'(?<![\[\(])(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(value);
    if (match != null) {
      final url = match.group(0)!;
      if (url.length > 10 && !value.contains('](')) {
        final nameCtrl = TextEditingController();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.surfaceColor,
            title: Text('Nomear link',
                style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Dê um nome ao link (opcional):',
                    style: TextStyle(color: context.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Ex: Clique aqui',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
              ),
              TextButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final replacement = name.isNotEmpty
                      ? '[$name]($url)'
                      : url;
                  final newText = value.replaceFirst(url, replacement);
                  _messageController.text = newText;
                  _messageController.selection = TextSelection.fromPosition(
                    TextPosition(offset: newText.length),
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Confirmar',
                    style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }
    }
  }

  // ==========================================================================
  // HELPER WIDGETS
  // ==========================================================================

  Widget _badgeIcon(IconData icon, int count) {
    final r = context.r;
    return Container(
      width: r.s(34),
      height: r.s(34),
      margin: EdgeInsets.only(right: r.s(4)),
      child: Stack(
        children: [
          Container(
            width: r.s(34),
            height: r.s(34),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.grey[500], size: r.s(16)),
          ),
          if (count > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: EdgeInsets.all(r.s(3)),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.scaffoldBg, width: 1.5),
                ),
                constraints:
                    const BoxConstraints(minWidth: 14, minHeight: 14),
                child: Text(
                  '$count',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(8),
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
      Responsive r, String value, IconData icon, String label,
      {bool isDestructive = false}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: r.s(18),
              color: isDestructive ? AppTheme.errorColor : Colors.grey[400]),
          SizedBox(width: r.s(10)),
          Text(label,
              style: TextStyle(
                  color:
                      isDestructive ? AppTheme.errorColor : Colors.grey[300],
                  fontSize: r.fs(13))),
        ],
      ),
    );
  }
}
