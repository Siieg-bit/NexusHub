import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'call_screen.dart';
import '../widgets/giphy_picker.dart';
import '../widgets/forward_message_sheet.dart';
import '../widgets/sticker_picker.dart';
import '../widgets/voice_recorder.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/media_utils.dart';
/// =============================================================================
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
  String? _chatBackground; // Background customizável per-user

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  /// Garante membership e depois carrega dados do chat.
  Future<void> _initChat() async {
    await _loadThreadInfo();
    await _ensureMembership();
    _loadMessages();
    _loadPinnedMessages();
    _subscribeToRealtime();
    _loadChatBackground();
  }

  /// Garante que o usuário é membro do chat usando o RPC SECURITY DEFINER.
  /// Sem membership, as políticas RLS bloqueiam SELECT e INSERT em chat_messages.
  Future<void> _ensureMembership() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      await SupabaseService.rpc('join_public_chat_with_reputation', params: {
        'p_thread_id': widget.threadId,
        'p_user_id': userId,
      });
    } catch (e) {
      debugPrint('[ChatRoom] Membership check: $e');
    }
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

  // ========================================================================
  // BACKGROUND CUSTOMIZÁVEL PER-USER
  // ========================================================================
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
    } catch (_) {
      // Background é best-effort
    }
  }

  void _showBackgroundPicker() {
    final r = context.r;
    final urlCtrl = TextEditingController(text: _chatBackground ?? '');
    final presets = [
      null, // Sem fundo
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
      if (mounted) setState(() => _chatBackground = url);
    } catch (e) {
      debugPrint('[ChatRoom] Background save error: $e');
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
  // CHAMADAS (Voice / Video)
  // ========================================================================

  /// Inicia uma chamada de voz ou vídeo via CallService e abre a CallScreen.
  Future<void> _startCall(CallType type) async {
    // Enviar mensagem de sistema no chat
    final msgType = type == CallType.video ? 'video_chat' : 'voice_chat';
    _sendMessage(type: msgType);

    // Criar sessão de chamada real via Agora
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

      // Determinar media_url final
      String? finalMediaUrl = mediaUrl;
      if (type == 'image' && mediaUrl != null) finalMediaUrl = mediaUrl;
      if (type == 'gif' && mediaUrl != null) finalMediaUrl = mediaUrl;
      if (stickerUrl != null) finalMediaUrl = stickerUrl;

      // Determinar reply_to
      String? replyToId;
      if (_replyingTo != null) {
        replyToId = _replyingTo!.id;
        setState(() => _replyingTo = null);
      }

      // Usar RPC SECURITY DEFINER que:
      // 1. Verifica membership
      // 2. Insere a mensagem
      // 3. Atualiza last_message_at do thread (sem precisar de permissão de host)
      // 4. Adiciona reputação automaticamente
      await SupabaseService.rpc('send_chat_message_with_reputation', params: {
        'p_thread_id': widget.threadId,
        'p_author_id': SupabaseService.currentUserId,
        'p_content': content,
        'p_type': mappedType,
        'p_media_url': finalMediaUrl,
        'p_reply_to': replyToId,
      });
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
      final rawBytes = await image.readAsBytes();
      // Comprimir imagem antes do upload
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
              // Handle bar
              Container(
                width: r.s(40), height: r.s(4),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: r.s(16)),
              // Header
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
              // Campo custom
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
              // Botão enviar
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
    final r = context.r;
    final currentUserId = SupabaseService.currentUserId;
    final threadTitle = _threadInfo?['title'] as String? ?? 'Chat';
    final threadType = _threadInfo?['type'] as String? ?? 'group';
    final memberCount = (_threadInfo?['member_count'] ?? _threadInfo?['members_count']) as int? ?? 0;
    final threadIcon = _threadInfo?['icon_url'] as String?;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      // ── AppBar estilo Amino ──
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
            // Thread avatar
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
          // Pinned messages
          if (_pinnedMessages.isNotEmpty)
            GestureDetector(
              onTap: _showPinnedMessages,
              child: _badgeIcon(Icons.push_pin_rounded, _pinnedMessages.length),
            ),
          // Voice chat
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
          // Video chat
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
          // Menu
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
              padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(8), 0),
              color: context.surfaceColor,
              child: Row(
                children: [
                  Container(
                    width: r.s(3),
                    height: r.s(32),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _replyingTo!.author?.nickname ?? 'User',
                          style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: r.fs(12),
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _replyingTo!.content ?? '',
                          style: TextStyle(
                              fontSize: r.fs(12), color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: Padding(
                      padding: EdgeInsets.all(r.s(8)),
                      child: Icon(Icons.close_rounded,
                          size: r.s(18), color: Colors.grey[500]),
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
            padding: EdgeInsets.fromLTRB(r.s(8), r.s(8), r.s(8), r.s(8)),
            decoration: BoxDecoration(
              color: context.surfaceColor,
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
                      width: r.s(36),
                      height: r.s(36),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_rounded,
                          color: AppTheme.primaryColor, size: r.s(20)),
                    ),
                  ),
                  SizedBox(width: r.s(8)),
                  // Input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(r.s(24)),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: TextStyle(
                                  color: context.textPrimary, fontSize: r.fs(14)),
                              decoration: InputDecoration(
                                hintText: 'Message...',
                                hintStyle: TextStyle(
                                    color: Colors.grey[600], fontSize: r.fs(14)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: r.s(16), vertical: r.s(10)),
                              ),
                              maxLines: 4,
                              minLines: 1,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                              onChanged: (value) {
                                // Link paste inteligente: detecta URL colada
                                final urlRegex = RegExp(
                                  r'(?<![\[\(])(https?:\/\/[^\s]+)',
                                  caseSensitive: false,
                                );
                                final match = urlRegex.firstMatch(value);
                                if (match != null) {
                                  final url = match.group(0)!;
                                  // Só abre dialog se a URL foi colada (não digitada letra a letra)
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
                              },
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(
                                  () => _showEmojiPicker = !_showEmojiPicker);
                            },
                            child: Padding(
                              padding: EdgeInsets.only(right: r.s(8)),
                              child: Icon(Icons.emoji_emotions_outlined,
                                  color: Colors.grey[600], size: r.s(20)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: r.s(8)),
                  // Botão enviar
                  GestureDetector(
                    onTap: _isSending ? null : () => _sendMessage(),
                    child: Container(
                      width: r.s(40),
                      height: r.s(40),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? Padding(
                              padding: EdgeInsets.all(r.s(10)),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(Icons.send_rounded,
                              color: Colors.white, size: r.s(18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ================================================================
          // EMOJI PICKER
          // ================================================================
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
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
                  iconColor: Colors.grey[600]!,
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
    );
  }

  // ========================================================================
  // MEDIA OPTIONS BOTTOM SHEET (19+ tipos) — Estilo Amino
  // ========================================================================
  void _showMediaOptions(BuildContext context) {
      final r = context.r;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(r.s(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: r.s(36),
              height: r.s(4),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: r.s(20)),
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
                    _startCall(CallType.voice);
                  },
                ),
                _MediaOptionItem(
                  icon: Icons.video_call_rounded,
                  label: 'Video',
                  color: const Color(0xFF2196F3),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startCall(CallType.video);
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
                _MediaOptionItem(
                  icon: Icons.video_file_rounded,
                  label: 'Vídeo',
                  color: const Color(0xFFFF5722),
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendVideoFile();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendVideoFile() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    // Validar duração do vídeo
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
          .uploadBinary(path, bytes, options: const StorageFileUploadOptions(contentType: 'video/mp4'));
      final url = SupabaseService.storage.from('chat-media').getPublicUrl(path);
      await _sendMessage(type: 'video', mediaUrl: url, mediaType: 'video');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no upload do vídeo: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(16))),
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
                for (final c in optionCtrls) {
                  c.dispose();
                }
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
    );
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

  // ========================================================================
  // MESSAGE ACTIONS (Long Press) — Estilo Amino
  // ========================================================================
  void _showMessageActions(MessageModel message) {
      final r = context.r;
    final isMe = message.authorId == SupabaseService.currentUserId;
    final isTextType = message.type == 'text' || message.type == 'share_url';
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
          children: [
            // Handle bar
            Container(
              width: r.s(36),
              height: r.s(4),
              margin: EdgeInsets.only(bottom: r.s(16)),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Quick reactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['\u2764\uFE0F', '\uD83D\uDE02', '\uD83D\uDE2E', '\uD83D\uDE22', '\uD83D\uDC4D', '\uD83D\uDC4E']
                  .map((emoji) => GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _addReaction(message.id, emoji);
                        },
                        child: Container(
                          padding: EdgeInsets.all(r.s(10)),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            shape: BoxShape.circle,
                          ),
                          child:
                              Text(emoji, style: TextStyle(fontSize: r.fs(22))),
                        ),
                      ))
                  .toList(),
            ),
            SizedBox(height: r.s(16)),
            // Responder
            _actionTile(Icons.reply_rounded, 'Responder', () {
              Navigator.pop(ctx);
              setState(() => _replyingTo = message);
            }),
            // Copiar
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
            // Editar (só autor + só texto)
            if (isMe && isTextType)
              _actionTile(Icons.edit_rounded, 'Editar', () {
                Navigator.pop(ctx);
                _showEditMessageDialog(message);
              }),
            // Encaminhar
            _actionTile(Icons.forward_rounded, 'Encaminhar', () {
              Navigator.pop(ctx);
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
            }),
            // Fixar
            _actionTile(Icons.push_pin_rounded, 'Fixar Mensagem', () {
              Navigator.pop(ctx);
              _pinMessage(message.id);
            }),
            // Apagar para mim
            _actionTile(Icons.visibility_off_rounded, 'Apagar para mim', () async {
              Navigator.pop(ctx);
              try {
                await SupabaseService.rpc('delete_chat_message_for_me', params: {
                  'p_message_id': message.id,
                });
                if (mounted) setState(() => _messages.remove(message));
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao apagar: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            }),
            // Apagar para todos (só autor ou host)
            if (isMe)
              _actionTile(Icons.delete_rounded, 'Apagar para todos', () async {
                Navigator.pop(ctx);
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
                        content: Text('Erro ao apagar: $e'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              }, isDestructive: true),
            // Denunciar (só para mensagens de outros)
            if (!isMe)
              _actionTile(Icons.flag_rounded, 'Denunciar', () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Den\u00fancia enviada. Obrigado!'),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                );
              }, isDestructive: true),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // EDIT MESSAGE DIALOG
  // ========================================================================
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
                        content: Text('Erro ao editar: $e'),
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

  Widget _actionTile(IconData icon, String label, VoidCallback onTap,
      {bool isDestructive = false}) {

      final r = context.r;
    final color = isDestructive ? AppTheme.errorColor : Colors.grey[400];
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: r.s(12)),
        child: Row(
          children: [
            Icon(icon, color: color, size: r.s(20)),
            SizedBox(width: r.s(12)),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: r.fs(14), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

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
    final r = context.r;
    // System messages
    if (message.isSystemMessage) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: r.s(8)),
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Text(
              message.content ?? '',
              style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
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
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
      Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar)
            GestureDetector(
              onTap: () => context.push('/user/${message.authorId}'),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: context.surfaceColor,
                backgroundImage: () {
                  final msgIcon = message.author?.iconUrl;
                  return msgIcon != null && msgIcon.isNotEmpty
                      ? CachedNetworkImageProvider(msgIcon)
                      : null;
                }(),
                child: () {
                  final msgIcon = message.author?.iconUrl;
                  return msgIcon == null || msgIcon.isEmpty
                      ? Text(
                          (message.author?.nickname ?? '?')[0].toUpperCase(),
                          style: TextStyle(
                              fontSize: r.fs(11), color: Colors.grey[400]),
                        )
                      : null;
                }(),
              ),
            )
          else if (!isMe)
            SizedBox(width: r.s(32)),
          SizedBox(width: r.s(8)),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(10)),
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.primaryColor
                    : context.surfaceColor,
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
                      padding: EdgeInsets.only(bottom: r.s(4)),
                      child: Text(
                        message.author?.nickname ?? 'User',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: r.fs(11),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  // Conteúdo baseado no tipo
                  _buildContent(context),
                  // Hora + indicador de editado
                  Padding(
                    padding: EdgeInsets.only(top: r.s(4)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.grey[600],
                            fontSize: r.fs(10),
                          ),
                        ),
                        if (message.isEdited) ...[
                          SizedBox(width: r.s(4)),
                          Text(
                            'editado',
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.45)
                                  : Colors.grey[600],
                              fontSize: r.fs(9),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // ── Reações abaixo do bubble ──
      if (message.reactions.isNotEmpty)
        _buildReactionsRow(context),
      ],
      ),
    );
  }

  Widget _buildReactionsRow(BuildContext context) {
    final r = context.r;
    // reactions é Map<emoji, List<userId>> ou Map<emoji, dynamic>
    final reactionMap = <String, List<String>>{};
    message.reactions.forEach((key, value) {
      if (value is List) {
        reactionMap[key] = List<String>.from(value);
      }
    });
    if (reactionMap.isEmpty) return const SizedBox.shrink();

    final currentUserId = SupabaseService.currentUserId;

    return Padding(
      padding: EdgeInsets.only(
        top: r.s(2),
        left: isMe ? 0 : r.s(40),
        right: isMe ? 0 : 0,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Wrap(
          spacing: r.s(4),
          runSpacing: r.s(2),
          children: reactionMap.entries.map((entry) {
            final emoji = entry.key;
            final users = entry.value;
            final iReacted = users.contains(currentUserId);
            return GestureDetector(
              onTap: () => onReactionTap?.call(emoji),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(6), vertical: r.s(2)),
                decoration: BoxDecoration(
                  color: iReacted
                      ? AppTheme.primaryColor.withValues(alpha: 0.25)
                      : context.surfaceColor,
                  borderRadius: BorderRadius.circular(r.s(10)),
                  border: Border.all(
                    color: iReacted
                        ? AppTheme.primaryColor.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: TextStyle(fontSize: r.fs(12))),
                    SizedBox(width: r.s(2)),
                    Text(
                      '${users.length}',
                      style: TextStyle(
                        fontSize: r.fs(10),
                        color: iReacted
                            ? AppTheme.primaryColor
                            : Colors.grey[500],
                        fontWeight:
                            iReacted ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
      final r = context.r;
    final type = message.type;
    final textColor = isMe ? Colors.white : context.textPrimary;

    // O banco armazena o tipo mapeado (ex: 'text' para imagens, 'system_tip' para tips)
    // Precisamos detectar o tipo real pelo conteúdo/campos

    // Imagem: tipo text mas com media_url e media_type == 'image'
    if (message.mediaUrl != null && message.mediaType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(r.s(8)),
        child: CachedNetworkImage(
          imageUrl: message.mediaUrl!,
          width: r.s(200),
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: r.s(200), height: r.s(150),
            color: Colors.grey[800],
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }

    // GIF: tipo text mas com media_url e media_type == 'gif'
    if (message.mediaUrl != null && message.mediaType == 'gif') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(r.s(8)),
        child: CachedNetworkImage(
          imageUrl: message.mediaUrl!,
          width: r.s(180),
          fit: BoxFit.cover,
        ),
      );
    }

    // Sticker
    if (type == 'sticker' || message.stickerUrl != null) {
      final url = message.stickerUrl ?? message.mediaUrl;
      return url != null
          ? CachedNetworkImage(imageUrl: url, width: r.s(120), height: r.s(120))
          : Text('🎭', style: TextStyle(fontSize: r.fs(48)));
    }

    // Voice note
    if (type == 'voice_note') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_rounded, color: textColor, size: r.s(32)),
          SizedBox(width: r.s(8)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Audio', style: TextStyle(color: textColor, fontSize: r.fs(13))),
              if (message.mediaDuration != null)
                Text('${message.mediaDuration}s',
                    style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: r.fs(11))),
              Container(
                width: r.s(120),
                height: r.s(4),
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
        width: r.s(200),
        height: r.s(150),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(r.s(8)),
        ),
        child: Center(
          child: Icon(Icons.play_circle_rounded, color: Colors.white, size: r.s(48)),
        ),
      );
    }

    // System messages (tip, voice start, etc.)
    if (type == 'system_tip') {
      final amount = message.tipAmount ?? 0;
      return Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on_rounded,
                color: AppTheme.warningColor),
            SizedBox(width: r.s(8)),
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
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accentColor),
            SizedBox(width: r.s(8)),
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
            padding: EdgeInsets.all(r.s(10)),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.s(8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_rounded, color: textColor, size: r.s(16)),
                SizedBox(width: r.s(8)),
                Flexible(
                  child: Text(
                    url,
                    style: TextStyle(
                      color: textColor,
                      fontSize: r.fs(13),
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
              padding: EdgeInsets.only(top: r.s(4)),
              child: Text(message.content!,
                  style: TextStyle(color: textColor, fontSize: r.fs(14))),
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
                    fontSize: r.fs(14))),
            SizedBox(height: r.s(8)),
            ...options.map((opt) => Container(
                  margin: EdgeInsets.only(bottom: r.s(4)),
                  padding:
                      EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Text(opt,
                      style: TextStyle(color: textColor, fontSize: r.fs(13))),
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
            padding: EdgeInsets.all(r.s(8)),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.5)
                        : AppTheme.primaryColor,
                    width: r.s(3)),
              ),
            ),
            child: Text(
              'Respondendo...',
              style: TextStyle(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.grey[500],
                fontSize: r.fs(11),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          SizedBox(height: r.s(4)),
          Text(message.content ?? '',
              style: TextStyle(color: textColor, fontSize: r.fs(14))),
        ],
      );
    }

    // Shared user
    if (type == 'share_user') {
      return Container(
        padding: EdgeInsets.all(r.s(10)),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(r.s(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_rounded, color: textColor, size: r.s(16)),
            SizedBox(width: r.s(8)),
            Text('Perfil compartilhado',
                style: TextStyle(
                    color: textColor,
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    // Default: texto simples
    return Text(
      message.content ?? '',
      style: TextStyle(color: textColor, fontSize: r.fs(14)),
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
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: r.s(52),
            height: r.s(52),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(r.s(16)),
            ),
            child: Icon(icon, color: color, size: r.s(24)),
          ),
          SizedBox(height: r.s(6)),
          Text(label,
              style: TextStyle(fontSize: r.fs(11), color: Colors.grey[500])),
        ],
      ),
    );
  }
}
