import 'dart:io';
import 'dart:async';

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
import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/cosmetics_provider.dart';
import '../../../core/services/realtime_service.dart';
// call_screen.dart removido — chamadas de voz/vídeo substituídas por projeção
import '../widgets/giphy_picker.dart';
import '../widgets/forward_message_sheet.dart';
import '../../stickers/stickers.dart';
import '../widgets/voice_recorder.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_reply_preview.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_date_separator.dart';
import '../widgets/chat_media_sheet.dart';
import '../widgets/chat_message_actions.dart';
import '../widgets/nine_slice_bubble.dart';
import '../widgets/chat_background_picker.dart';
import '../widgets/chat_cover_picker.dart';
import '../widgets/chat_moderation_sheet.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/media_utils.dart';
import 'chat_list_screen.dart' show chatListProvider, chatCommunitiesProvider;
import '../../../core/l10n/locale_provider.dart';
import '../../../core/services/deep_link_service.dart';
import 'call_screen.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
// screening_room_screen.dart — navegação via GoRouter ('/screening-room/:threadId')

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
  Map<String, dynamic>? _extractProfile(dynamic rawProfile) {
    if (rawProfile is Map<String, dynamic>) return rawProfile;
    if (rawProfile is Map) return Map<String, dynamic>.from(rawProfile);
    if (rawProfile is List && rawProfile.isNotEmpty) {
      final first = rawProfile.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  Future<Map<String, dynamic>> _normalizeMessageAuthorIdentity(
    Map<String, dynamic> rawMap,
  ) async {
    final map = Map<String, dynamic>.from(rawMap);
    final baseProfile = _extractProfile(
      map['author'] ?? map['sender'] ?? map['profiles'],
    );

    if (baseProfile != null) {
      final normalizedProfile = Map<String, dynamic>.from(baseProfile);
      map['profiles'] = normalizedProfile;
      map['sender'] = normalizedProfile;
      map['author'] = normalizedProfile;
    }

    final authorId = (map['author_id'] as String?)?.trim();
    final communityId = (_threadInfo?['community_id'] as String?)?.trim();

    if (authorId == null || authorId.isEmpty) return map;
    if (communityId == null || communityId.isEmpty) return map;

    try {
      final membership = await SupabaseService.table('community_members')
          .select('local_nickname, local_icon_url, local_banner_url')
          .eq('community_id', communityId)
          .eq('user_id', authorId)
          .maybeSingle();

      if (membership == null) return map;

      final localNickname =
          (membership['local_nickname'] as String?)?.trim();
      final localIconUrl =
          (membership['local_icon_url'] as String?)?.trim();
      final localBannerUrl =
          (membership['local_banner_url'] as String?)?.trim();

      final mergedAuthor = Map<String, dynamic>.from(
        (map['author'] ?? map['sender'] ?? map['profiles'] ?? const <String, dynamic>{})
            as Map,
      );

      if (localNickname != null && localNickname.isNotEmpty) {
        mergedAuthor['nickname'] = localNickname;
      }
      if (localIconUrl != null && localIconUrl.isNotEmpty) {
        mergedAuthor['icon_url'] = localIconUrl;
      }
      if (localBannerUrl != null && localBannerUrl.isNotEmpty) {
        mergedAuthor['banner_url'] = localBannerUrl;
      }

      map['profiles'] = mergedAuthor;
      map['sender'] = mergedAuthor;
      map['author'] = mergedAuthor;
    } catch (e) {
      debugPrint(
        '[chat_room_screen] _normalizeMessageAuthorIdentity member fallback error: $e',
      );
    }

    return map;
  }
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  final List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _realtimeConnected = true;
  bool _isSending = false;
  bool _membershipConfirmed = false;
  bool _isDisposed = false;
  Map<String, dynamic>? _threadInfo;
  MessageModel? _replyingTo;
  bool _showEmojiPicker = false;
  bool _isRecordingVoice = false;
  String? _highlightedMessageId;
  Timer? _replyHighlightTimer;
  bool _isOpeningVoiceCall = false;
  List<Map<String, dynamic>> _pinnedMessages = [];
  String? _chatBackground;
  String? _chatCoverUrl;
  String? _callerRole; // 'host', 'co_host', 'member'
  bool _isAnnouncementOnly = false;
  // Fluxo de DM invite
  // _isDmInvitePending: true quando o usuário atual é o destinatário de um convite pendente (status='invite_sent')
  // _isDmInviteSender:  true quando o usuário atual é o remetente e aguarda aceitação
  bool _isDmInvitePending = false;
  bool _isDmInviteSender = false;

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
    // Verificar mounted antes de cada operação fire-and-forget.
    // _subscribeToRealtime() adiciona um listener — se chamado após dispose(),
    // o listener fica pendurado e causa _ElementLifecycle.defunct.
    if (!mounted || _isDisposed) return;
    _loadMessages();
    if (!mounted || _isDisposed) return;
    _loadPinnedMessages();
    if (!mounted || _isDisposed) return;
    _subscribeToRealtime();
    if (!mounted || _isDisposed) return;
    _loadChatBackground();
    if (!mounted || _isDisposed) return;
    _loadChatCoverAndRole();
    if (!mounted || _isDisposed) return;
    // Marcar chat como lido ao abrir — zera unread_count no banco
    _markChatRead();
  }

  GlobalKey _messageKeyFor(String messageId) {
    return _messageKeys.putIfAbsent(
      messageId,
      () => GlobalObjectKey('chat-message-$messageId'),
    );
  }

  MessageModel? _findMessageById(String? messageId) {
    if (messageId == null || messageId.isEmpty) return null;
    for (final message in _messages) {
      if (message.id == messageId) return message;
    }
    return null;
  }

  void _setHighlightedMessage(String? messageId) {
    if (!mounted || _isDisposed) return;
    _replyHighlightTimer?.cancel();
    setState(() => _highlightedMessageId = messageId);
    if (messageId == null) return;
    _replyHighlightTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _isDisposed || _highlightedMessageId != messageId) return;
      setState(() => _highlightedMessageId = null);
    });
  }

  Future<void> _jumpToMessage(String messageId) async {
    final targetIndex = _messages.indexWhere((message) => message.id == messageId);
    if (targetIndex == -1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensagem original não encontrada nesta conversa.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _setHighlightedMessage(messageId);
    await Future<void>.delayed(Duration.zero);

    final messageKey = _messageKeyFor(messageId);
    final visibleContext = messageKey.currentContext;
    if (visibleContext != null) {
      await Scrollable.ensureVisible(
        visibleContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
      return;
    }

    if (_scrollController.hasClients) {
      final estimatedOffset = (targetIndex * context.r.s(148)).toDouble();
      final maxOffset = _scrollController.position.maxScrollExtent;
      await _scrollController.animateTo(
        estimatedOffset.clamp(0.0, maxOffset),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    final retryContext = messageKey.currentContext;
    if (retryContext != null) {
      await Scrollable.ensureVisible(
        retryContext,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível abrir a mensagem original agora.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Marca o chat como lido via RPC, zerando o unread_count no banco.
  Future<void> _markChatRead() async {
    try {
      await SupabaseService.rpc('mark_chat_read', params: {
        'p_thread_id': widget.threadId,
      });
      debugPrint('[ChatRoom] ✅ mark_chat_read OK (thread: ${widget.threadId})');
    } catch (e) {
      debugPrint('[ChatRoom] ⚠️ mark_chat_read falhou: $e');
    }
  }

  Future<void> _ensureMembership() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      debugPrint('[ChatRoom] _ensureMembership: userId is null');
      return;
    }

    // Determinar o tipo do thread para aplicar a regra correta.
    // O tipo é carregado pelo _loadThreadInfo() antes desta chamada.
    final threadType = _threadInfo?['type'] as String? ?? 'public';

    // =========================================================================
    // PASSO 1 (todos os tipos): verificar membership existente.
    // Se já existe linha em chat_members, verificar o status.
    // =========================================================================
    try {
      final check = await SupabaseService.table('chat_members')
          .select('id, status')
          .eq('thread_id', widget.threadId)
          .eq('user_id', userId)
          .maybeSingle();
      if (!mounted || _isDisposed) return;
      if (check != null) {
        final memberStatus = check['status'] as String? ?? 'active';
        if (memberStatus == 'left') {
          // Usuário saiu intencionalmente.
          // _membershipConfirmed permanece false → CTA adequado ao tipo é exibido.
          debugPrint(
              '[ChatRoom] User previously left ($threadType) — showing CTA');
          return;
        }
        if (memberStatus == 'invite_sent') {
          // Usuário é o destinatário de um convite pendente.
          // Ele pode ver as mensagens mas não pode enviar até aceitar.
          _isDmInvitePending = true;
          _membershipConfirmed = false; // Bloqueia o input bar
          debugPrint('[ChatRoom] User is invite recipient (invite_sent)');
          return;
        }
        _membershipConfirmed = true;
        debugPrint(
            '[ChatRoom] Already a member (type: $threadType, status: $memberStatus)');
        return;
      }
      // Verificar se o usuário atual é o remetente do convite (status='active' no DM)
      // e o outro membro ainda está com status='invite_sent'
      if (threadType == 'dm') {
        // Verificar se há algum membro com status='invite_sent' neste thread
        try {
          final pendingMembers = await SupabaseService.table('chat_members')
              .select('id, status, user_id')
              .eq('thread_id', widget.threadId)
              .eq('status', 'invite_sent');
          if (!mounted || _isDisposed) return;
          if ((pendingMembers as List?)?.isNotEmpty == true) {
            _isDmInviteSender = true;
            _membershipConfirmed = true; // Remetente pode enviar mensagens
            debugPrint('[ChatRoom] User is DM invite sender, waiting for acceptance');
            return;
          }
        } catch (e) {
          debugPrint('[ChatRoom] Could not check pending invite members: $e');
        }
      }
    } catch (e) {
      debugPrint('[ChatRoom] Direct membership check failed: $e');
    }

    // =========================================================================
    // PASSO 2 (apenas type == 'public'): auto-join via RPC.
    // Para 'group' e 'dm': entrada só por convite (Etapa 2+).
    // Não tentar auto-join em grupo ou DM — isso violaria o domínio.
    // =========================================================================
    if (threadType != 'public') {
      // group/dm sem membership — usuário não tem acesso a este chat.
      // _membershipConfirmed permanece false → CTA adequado ao tipo é exibido.
      debugPrint(
          '[ChatRoom] No membership for $threadType chat — access denied (invite required)');
      return;
    }

    // Chat público sem membership prévia: tentar join via RPC.
    // A RPC respeita status 'left' e retorna {joined: false, reason: 'left'}
    // se o usuário já saiu intencionalmente.
    try {
      final result = await SupabaseService.rpc(
          'join_public_chat_with_reputation',
          params: {
            'p_thread_id': widget.threadId,
          });
      if (!mounted || _isDisposed) return;
      final resultMap = result as Map?;
      final joined = resultMap?['joined'] as bool? ?? false;
      final reason = resultMap?['reason'] as String? ?? '';
      if (!joined && reason == 'left') {
        // Usuário saiu intencionalmente — não confirmar membership.
        debugPrint('[ChatRoom] RPC: user previously left this public chat');
        return;
      }
      if (joined) {
        _membershipConfirmed = true;
        debugPrint('[ChatRoom] Membership confirmed via RPC (public): $result');
        return;
      }
    } catch (e) {
      debugPrint('[ChatRoom] RPC join_public_chat_with_reputation failed: $e');
    }
    // Se a RPC falhou por erro de rede, _membershipConfirmed permanece false.
    // Não há fallback de upsert — evitar sobrescrever status='left' silenciosamente.
    debugPrint(
        '[ChatRoom] Could not confirm membership for public chat (RPC unavailable).');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _replyHighlightTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    RealtimeService.instance.unsubscribe('chat:${widget.threadId}');
    RealtimeService.instance.connectionStatus
        .removeListener(_onRealtimeStatusChanged);
    super.dispose();
  }

  void _onRealtimeStatusChanged() {
    if (!mounted || _isDisposed) return;
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

      final threadInfo = Map<String, dynamic>.from(res as Map);
      final userId = SupabaseService.currentUserId;

      if (threadInfo['type'] == 'dm' && userId != null) {
        try {
          final dmMembers = await SupabaseService.table('chat_members')
              .select(
                  'user_id, profiles!chat_members_user_id_fkey(id, nickname, icon_url, banner_url)')
              .eq('thread_id', widget.threadId)
              .neq('user_id', userId)
              .limit(1);

          final dmMemberList =
              List<Map<String, dynamic>>.from(dmMembers as List? ?? []);
          if (dmMemberList.isNotEmpty) {
            final counterpartMap = Map<String, dynamic>.from(dmMemberList.first);
            final counterpartUserId = counterpartMap['user_id'] as String?;
            final profile = _extractProfile(counterpartMap['profiles']);
            if (profile != null) {
              final mergedProfile = Map<String, dynamic>.from(profile);
              final communityId = (threadInfo['community_id'] as String?)?.trim();

              if (communityId != null &&
                  communityId.isNotEmpty &&
                  counterpartUserId != null) {
                try {
                  final membership = await SupabaseService.table('community_members')
                      .select(
                          'local_nickname, local_icon_url, local_banner_url')
                      .eq('community_id', communityId)
                      .eq('user_id', counterpartUserId)
                      .maybeSingle();

                  if (membership != null && membership is Map) {
                    final localMap = Map<String, dynamic>.from(membership as Map);
                    final localNickname =
                        (localMap['local_nickname'] as String?)?.trim();
                    final localIconUrl =
                        (localMap['local_icon_url'] as String?)?.trim();
                    final localBannerUrl =
                        (localMap['local_banner_url'] as String?)?.trim();

                    if (localNickname != null && localNickname.isNotEmpty) {
                      mergedProfile['nickname'] = localNickname;
                    }
                    if (localIconUrl != null && localIconUrl.isNotEmpty) {
                      mergedProfile['icon_url'] = localIconUrl;
                    }
                    if (localBannerUrl != null && localBannerUrl.isNotEmpty) {
                      mergedProfile['banner_url'] = localBannerUrl;
                    }
                  }
                } catch (e) {
                  debugPrint('[ChatRoom] Erro ao aplicar identidade local: $e');
                }
              }

              threadInfo['title'] = mergedProfile['nickname'] ?? threadInfo['title'];
              threadInfo['icon_url'] = mergedProfile['icon_url'];
              threadInfo['host_id'] = mergedProfile['id'] ??
                  counterpartUserId ??
                  threadInfo['host_id'];
            }
          }
        } catch (e) {
          debugPrint('[ChatRoom] Erro ao enriquecer DM: $e');
        }
      }

      if (!mounted || _isDisposed) return;
      setState(() => _threadInfo = threadInfo);
    } catch (e) {
      debugPrint('[chat_room_screen.dart] $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final response = await SupabaseService.table('chat_messages')
          .select(
              '*, profiles!chat_messages_author_id_fkey(id, nickname, icon_url)')
          .eq('thread_id', widget.threadId)
          .order('created_at', ascending: false)
          .limit(100);

      final normalizedMessages = await Future.wait(
        (response as List? ?? []).map((e) async {
          final map = Map<String, dynamic>.from(e as Map);
          if (map['profiles'] != null) {
            map['sender'] = map['profiles'];
            map['author'] = map['profiles'];
          }
          final normalizedMap = await _normalizeMessageAuthorIdentity(map);
          return MessageModel.fromJson(normalizedMap);
        }).toList(),
      );

      if (mounted && !_isDisposed) {
        setState(() {
          _messages
            ..clear()
            ..addAll(normalizedMessages);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted && !_isDisposed) setState(() => _isLoading = false);
      debugPrint('Error loading messages: $e');
    }
  }

  Future<void> _loadPinnedMessages() async {
    try {
      final threadData = await SupabaseService.table('chat_threads')
          .select('pinned_message_id')
          .eq('id', widget.threadId)
          .single();
      if (!mounted || _isDisposed) return;
      final pinnedId = threadData['pinned_message_id'] as String?;
      if (pinnedId == null) {
        if (!mounted || _isDisposed) return;
        setState(() => _pinnedMessages = []);
        return;
      }
      final res = await SupabaseService.table('chat_messages')
          .select(
              '*, profiles!chat_messages_author_id_fkey(id, nickname, icon_url)')
          .eq('id', pinnedId)
          .limit(1);
      final normalizedPinnedMessages = await Future.wait(
        (res as List? ?? []).map((e) async {
          final map = Map<String, dynamic>.from(e as Map);
          if (map['profiles'] != null) {
            map['sender'] = map['profiles'];
            map['author'] = map['profiles'];
          }
          return _normalizeMessageAuthorIdentity(map);
        }).toList(),
      );
      if (mounted && !_isDisposed) {
        setState(() {
          _pinnedMessages = normalizedPinnedMessages;
        });
      }
    } catch (e) {
      debugPrint('[chat_room_screen.dart] $e');
    }
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
      if (res != null && mounted && !_isDisposed) {
        setState(() => _chatBackground = res['background_url'] as String?);
      }
    } catch (e) {
      debugPrint('[chat_room_screen.dart] $e');
    }
  }

  void _showBackgroundPicker() {
    showChatBackgroundPicker(
      context: context,
      threadId: widget.threadId,
      currentBackground: _chatBackground,
      onChanged: (url) {
        if (mounted) setState(() => _chatBackground = url);
      },
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

  /// Carrega a capa do chat e o role do usuário atual neste thread.
  Future<void> _loadChatCoverAndRole() async {
    try {
      final userId = SupabaseService.currentUserId;
      // Capa do chat
      final threadData = await SupabaseService.table('chat_threads')
          .select('cover_image_url, is_announcement_only')
          .eq('id', widget.threadId)
          .single();
      if (mounted && !_isDisposed) {
        setState(() {
          _chatCoverUrl = threadData['cover_image_url'] as String?;
          _isAnnouncementOnly = threadData['is_announcement_only'] as bool? ?? false;
        });
      }
      // Role do usuário atual
      if (userId != null) {
        final memberData = await SupabaseService.table('chat_members')
            .select('role')
            .eq('thread_id', widget.threadId)
            .eq('user_id', userId)
            .maybeSingle();
        if (mounted && !_isDisposed) {
          // Verificar também se é host pelo host_id do thread
          final hostId = _threadInfo?['host_id'] as String?;
          final coHosts = _threadInfo?['co_hosts'] as List?;
          String? role = memberData?['role'] as String?;
          if (userId == hostId) role = 'host';
          else if (coHosts != null && coHosts.contains(userId)) role = 'co_host';
          setState(() => _callerRole = role ?? 'member');
        }
      }
    } catch (e) {
      debugPrint('[ChatRoom] _loadChatCoverAndRole error: $e');
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
            if (_isDisposed) return;
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
                  if (_isDisposed || !mounted) return;
                  newMessage['sender'] = senderData;
                  newMessage['author'] = senderData;
                  newMessage['profiles'] = senderData;
                }
              } catch (e) {
                debugPrint('[chat_room_screen.dart] $e');
              }
              final normalizedMessage =
                  await _normalizeMessageAuthorIdentity(newMessage);
              if (_isDisposed || !mounted) return;
              final message = MessageModel.fromJson(normalizedMessage);
              setState(() => _messages.insert(0, message));
              _scrollToBottom();
              // Marcar como lido automaticamente (o usuário está na tela)
              _markChatRead();
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

  // _startCall removido — chamadas de voz/vídeo foram substituídas pelo sistema de projeção.

  // ==========================================================================
  // INICIAR VOICE CHAT / PROJEÇÃO
  // ==========================================================================

  Future<void> _startVoiceChat() async {
    if (_isOpeningVoiceCall) return;

    if (mounted) {
      setState(() => _isOpeningVoiceCall = true);
    }

    try {
      final result = await CallService.openThreadCallDetailed(
        threadId: widget.threadId,
        type: CallType.voice,
      );

      if (!mounted) return;

      if (result == null) {
        final report = CallService.buildLastErrorReport(
          title: 'CHAT VOICE CALL FAILURE',
        );
        debugPrint(report);

        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Falha ao iniciar a chamada'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: SelectableText(report),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
        return;
      }

      if (!result.reusedExistingSession) {
        await _sendMessage(type: 'voice_chat');
        if (!mounted) return;
      }

      if (mounted) {
        setState(() => _isOpeningVoiceCall = false);
      }

      await CallScreen.show(context, result.session);
    } catch (e, st) {
      final report = [
        '===== CHAT VOICE CALL UNCAUGHT EXCEPTION =====',
        'threadId: ${widget.threadId}',
        'error: $e',
        'stackTrace:',
        st.toString(),
        '===== END CHAT VOICE CALL UNCAUGHT EXCEPTION =====',
      ].join('\n');
      debugPrint(report);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Exceção ao abrir chamada'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: SelectableText(report),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted && _isOpeningVoiceCall) {
        setState(() => _isOpeningVoiceCall = false);
      }
    }
  }

  Future<void> _startProjection() async {
    // Envia mensagem de sistema informando o início da projeção
    await _sendMessage(type: 'screening_room');
    if (!mounted) return;
    // Navega para a Sala de Projeção passando o threadId
    context.push('/screening-room/${widget.threadId}');
  }

  // ==========================================================================
  // ENVIAR MENSAGEM (suporta todos os tipos)
  // ==========================================================================

  String _mapMessageType(String type) {
    // Bug fix (migration 058): image, gif, audio, poll, forward e file
    // agora existem como valores nativos no enum chat_message_type do banco.
    // Não mapear esses tipos para 'text' ou 'voice_note'.
    const validTypes = {
      'text',
      'strike',
      'voice_note',
      'sticker',
      'video',
      'image',
      'gif',
      'audio',
      'poll',
      'forward',
      'file',
      'share_url',
      'share_user',
      'system_deleted',
      'system_join',
      'system_leave',
      'system_voice_start',
      'system_voice_end',
      'system_screen_start',
      'system_screen_end',
      'system_tip',
      'system_pin',
      'system_unpin',
      'system_removed',
      'system_admin_delete',
    };
    if (validTypes.contains(type)) return type;
    switch (type) {
      case 'reply':
        return 'text';
      case 'voice_chat':
        return 'system_voice_start';
      case 'video_chat':
        return 'system_voice_start';
      case 'screening_room':
        return 'system_screen_start';
      case 'link':
        return 'share_url';
      case 'tip':
        return 'system_tip';
      default:
        return 'text';
    }
  }

  Future<void> _sendMessage({
    String type = 'text',
    String? mediaUrl,
    String? mediaType,
    String? stickerId,
    String? stickerUrl,
    String? stickerName,
    String? packId,
    String? sharedUrl,
    int? tipAmount,
    int? mediaDuration,
    String? pollQuestion,
    List<String>? pollOptions,
  }) async {
    final s = getStrings();
    final text = _messageController.text.trim();
    if (text.isEmpty && type == 'text' && mediaUrl == null) return;

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.sessionExpiredPleaseLogInAgain),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Bug fix: checar mounted ANTES de chamar clear() para evitar
    // "Cannot get renderObject of inactive element" quando o widget
    // é desmontado (ex: ao fechar o chat) antes do async completar.
    if (!mounted) return;

    // Bug fix #059: separar setState(_isSending=true) do addPostFrameCallback.
    // O addPostFrameCallback agenda execução para o PRÓXIMO frame, mas o
    // bloco finally de _sendMessage executa _isSending=false ANTES disso.
    // Resultado: o callback sobrescreve o finally e _isSending fica true
    // permanentemente ao enviar imagem, sticker ou GIF (loop de loading).
    //
    // Correção: setState(_isSending=true) é chamado IMEDIATAMENTE (síncrono),
    // enquanto _messageController.clear() permanece no addPostFrameCallback
    // para evitar "Cannot get renderObject of inactive element" ao limpar
    // o campo durante o frame de desmontagem de dialogs (tip, poll, link).
    setState(() => _isSending = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _messageController.clear();
      }
    });

    // Se membership não foi confirmada, tentar novamente antes de enviar
    if (!_membershipConfirmed) {
      await _ensureMembership();
      if (!_membershipConfirmed && mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(s.couldNotConfirmParticipation),
            backgroundColor: context.nexusTheme.error,
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
        content =
            '{"question":"$pollQuestion","options":${pollOptions?.map((o) => '"$o"').toList() ?? []}}';
      } else if (type == 'link' && sharedUrl != null) {
        content = text.isNotEmpty ? text : sharedUrl;
      } else if (type == 'tip' && tipAmount != null) {
        content = '$tipAmount coins';
      } else if (type == 'voice_chat' ||
          type == 'video_chat' ||
          type == 'screening_room') {
        content = type == 'voice_chat'
            ? 'Iniciou um Voice Chat'
            : type == 'video_chat'
                ? 'Iniciou um Video Chat'
                : 'Iniciou uma Sala de Projeção';
      } else {
        content = text;
      }

      String? finalMediaUrl = mediaUrl;
      if (type == 'image' && mediaUrl != null) finalMediaUrl = mediaUrl;
      if (type == 'gif' && mediaUrl != null) finalMediaUrl = mediaUrl;
      // Filtrar URL vazia de sticker (stickers emoji padrão retornam '' do StickerPicker).
      // URL vazia passada ao CachedNetworkImage causa: No host specified in URI.
      if (stickerUrl != null && stickerUrl.isNotEmpty)
        finalMediaUrl = stickerUrl;

      String? replyToId;
      if (_replyingTo != null) {
        replyToId = _replyingTo!.id;
        setState(() => _replyingTo = null);
      }

      final rpcParams = {
        'p_thread_id': widget.threadId,
        'p_content': content,
        'p_type': mappedType,
        'p_media_url': finalMediaUrl,
        if (mediaType != null) 'p_media_type': mediaType,
        if (mediaDuration != null) 'p_media_duration': mediaDuration,
        'p_reply_to': replyToId,
        if (stickerId != null) 'p_sticker_id': stickerId,
        if (stickerUrl != null && stickerUrl.isNotEmpty) 'p_sticker_url': stickerUrl,
        if (stickerName != null && stickerName.isNotEmpty) 'p_sticker_name': stickerName,
        if (packId != null && packId.isNotEmpty) 'p_pack_id': packId,
      };

      debugPrint('[ChatRoom] 📤 RPC params: $rpcParams');
      final result = await SupabaseService.rpc(
        'send_chat_message_with_reputation',
        params: rpcParams,
      );
      debugPrint('[ChatRoom] ✅ RPC result: $result');
    } catch (e, stack) {
      debugPrint('[ChatRoom] ❌ Send message error: $e');
      debugPrint('[ChatRoom] ❌ Send message stack: $stack');
      if (mounted) {
        final errorStr = e.toString();
        String errorMsg;
        if (errorStr.contains('not a member')) {
          errorMsg = s.notMemberChatRetry;
          _membershipConfirmed = false;
        } else if (errorStr.contains('unauthenticated') || errorStr.contains('session')) {
          errorMsg = s.sessionExpiredPleaseLogInAgain;
        } else {
          // Mostrar erro técnico completo para diagnóstico
          errorMsg = '❌ Erro: $errorStr';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ==========================================================================
  // CHAT MEMBERS — Bug #6 fix
  // ==========================================================================

  void _showChatMembers() {
    showChatModerationSheet(
      context: context,
      threadId: widget.threadId,
      callerRole: _callerRole,
      isAnnouncementOnly: _isAnnouncementOnly,
      currentCover: _chatCoverUrl,
      currentTitle: _threadInfo?['title'] as String?,
      onTitleChanged: () {
        // Recarregar info do thread após renomear
        _loadThreadInfo();
      },
      onCoverChanged: (url) {
        if (mounted) setState(() => _chatCoverUrl = url);
      },
      onAnnouncementOnlyChanged: (val) {
        if (mounted) setState(() => _isAnnouncementOnly = val);
      },
    );
  }

  // ==========================================================================
  // CHAT SETTINGS — Bug #6 fix
  // ==========================================================================

  void _showChatSettings() {
    final s = getStrings();
    final r = context.r;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
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
            Text(s.chatSettingsTitle,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(16),
                    color: context.nexusTheme.textPrimary)),
            SizedBox(height: r.s(16)),
            _settingsTile(r, Icons.wallpaper_rounded, s.chatBackground, () {
              Navigator.pop(ctx);
              _showBackgroundPicker();
            }),
            if (_callerRole == 'host' || _callerRole == 'co_host')
              _settingsTile(r, Icons.image_rounded, 'Capa do chat', () {
                Navigator.pop(ctx);
                showChatCoverPicker(
                  context: context,
                  threadId: widget.threadId,
                  currentCover: _chatCoverUrl,
                  canEdit: true,
                  onChanged: (url) {
                    if (mounted) setState(() => _chatCoverUrl = url);
                  },
                );
              }),
            _settingsTile(r, Icons.chat_bubble_rounded, 'Meu Bubble', () {
              Navigator.pop(ctx);
              _showBubblePicker();
            }),
            _settingsTile(r, Icons.notifications_rounded, s.notifications, () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(
                  content: Text(s.notificationSettingsComingSoon),
                  backgroundColor: context.nexusTheme.accentPrimary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }),
            _settingsTile(r, Icons.people_rounded, 'Ver Membros', () {
              Navigator.pop(ctx);
              _showChatMembers();
            }),
            if (_threadInfo?['community_id'] != null)
              _settingsTile(r, Icons.settings_rounded, 'Config. Gerais', () {
                Navigator.pop(ctx);
                context.push('/settings');
              }),
            SizedBox(height: r.s(8)),
            // Excluir chat — visível apenas para host e team_admin/moderator
            Builder(builder: (_) {
              final userId = SupabaseService.currentUserId;
              final hostId = _threadInfo?['host_id'] as String?;
              final currentUser = ref.read(currentUserProvider);
              final canDelete = (userId != null && userId == hostId) ||
                  (currentUser?.isTeamMember ?? false);
              if (!canDelete) return const SizedBox.shrink();
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Divider(
                    color: Colors.white.withValues(alpha: 0.07),
                    height: r.s(16)),
                _settingsTile(
                  r,
                  Icons.delete_rounded,
                  s.deleteChatTitle,
                  () {
                    Navigator.pop(ctx);
                    _deleteChatConfirm();
                  },
                  isDestructive: true,
                ),
              ]);
            }),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile(
      Responsive r, IconData icon, String label, VoidCallback onTap,
      {bool isDestructive = false}) {
    final color = isDestructive ? context.nexusTheme.error : Colors.grey[400]!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: r.s(12)),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: r.s(20)),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: isDestructive
                          ? context.nexusTheme.error
                          : context.nexusTheme.textPrimary,
                      fontSize: r.fs(14))),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey[600], size: r.s(18)),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BUBBLE PICKER — Seleciona o chat bubble ativo
  // ==========================================================================

  /// Abre um bottom sheet para o usuário selecionar qual bubble equipar.
  /// Lista todos os chat_bubbles comprados pelo usuário com preview visual.
  /// Ao selecionar, chama o RPC equip_store_item e invalida o provider de
  /// cosméticos para que a mudança apareça imediatamente nas mensagens.
  void _showBubblePicker() {
    final r = context.r;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      builder: (ctx) => _BubblePickerSheet(
        onBubbleSelected: (purchaseId, itemType) async {
          try {
            debugPrint('[EquipBubble] Chamando RPC equip_store_item '
                'purchase_id=$purchaseId item_type=$itemType');
            final result = await SupabaseService.client.rpc(
              'equip_store_item',
              params: {
                // null = desequipa todos (item Padrão)
                'p_purchase_id': purchaseId.isEmpty ? null : purchaseId,
                'p_item_type': itemType,
              },
            );
            debugPrint('[EquipBubble] RPC result: $result (${result.runtimeType})');
            final resultMap = result is Map
                ? Map<String, dynamic>.from(result as Map)
                : null;
            final ok = resultMap?['success'] as bool? ?? false;
            final equipped = resultMap?['equipped'] as bool? ?? false;
            debugPrint('[EquipBubble] ok=$ok equipped=$equipped');
            final userId = SupabaseService.currentUserId;
            if (userId != null) {
              ref.invalidate(userCosmeticsProvider(userId));
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? (equipped ? 'Bubble equipado!' : 'Bubble removido.')
                      : 'Não foi possível atualizar o bubble.'),
                  backgroundColor: ok ? context.nexusTheme.accentPrimary : context.nexusTheme.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(10)),
                  ),
                ),
              );
            }
          } catch (e, st) {
            debugPrint('[EquipBubble] ERRO: $e');
            debugPrint('[EquipBubble] STACK TRACE:\n$st');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erro ao equipar bubble: $e'),
                  backgroundColor: context.nexusTheme.error,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 6),
                ),
              );
            }
          }
        },
      ),
    );
  }

  // ==========================================================================
  // LEAVE CHAT — Bug #5 fix
  // ==========================================================================

  void _leaveChatConfirm() {
    final s = getStrings();
    final r = context.r;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(16))),
        title: Text(s.leaveChatTitle,
            style: TextStyle(
                color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(s.confirmLeaveChat,
            style: TextStyle(color: Colors.grey[400], fontSize: r.fs(14))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _leaveChat();
            },
            child: Text(s.logout,
                style: TextStyle(
                    color: context.nexusTheme.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveChat() async {
    final s = getStrings();
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final result = await SupabaseService.rpc('leave_public_chat', params: {
        'p_thread_id': widget.threadId,
      });
      _membershipConfirmed = false;
      if (mounted) {
        try {
          ref.invalidate(chatListProvider);
          ref.invalidate(chatCommunitiesProvider);
        } catch (e) {
          debugPrint('[chat_room_screen.dart] $e');
        }
        // Se a RPC deletou o chat (único membro ou host saindo), mensagem diferente
        final wasDeleted =
            (result as Map<String, dynamic>?)?['deleted'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasDeleted ? s.chatDeletedMsg : s.leftChat),
            backgroundColor: context.nexusTheme.accentPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('[ChatRoom] leave_public_chat RPC error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(s.errorLeavingChat),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Deletar o chat (host ou team_admin)
  Future<void> _deleteChat() async {
    final s = getStrings();
    try {
      await SupabaseService.rpc('delete_public_chat', params: {
        'p_thread_id': widget.threadId,
      });
      if (mounted) {
        try {
          ref.invalidate(chatListProvider);
          ref.invalidate(chatCommunitiesProvider);
        } catch (e) {
          debugPrint('[chat_room_screen.dart] $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(s.chatDeletedMsg),
            backgroundColor: context.nexusTheme.accentPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('[ChatRoom] delete_public_chat RPC error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(s.errorDeletingChat),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _deleteChatConfirm() {
    final s = getStrings();
    final r = context.r;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(16))),
        title: Text(s.deleteChatTitle,
            style: TextStyle(
                color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
            s.confirmDeleteChat2,
            style: TextStyle(color: Colors.grey[400], fontSize: r.fs(14))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteChat();
            },
            child: Text(s.delete,
                style: TextStyle(
                    color: context.nexusTheme.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MEDIA UPLOAD
  // ==========================================================================

  Future<void> _sendImage() async {
    final s = getStrings();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    // Bug fix #059: setar _isSending=true antes do upload para mostrar o
    // indicador de carregamento durante o processo de compressão e envio.
    if (mounted) setState(() => _isSending = true);
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path = 'chat/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);
      debugPrint('[ChatRoom] 🖼️ Uploading image: $path');
      await SupabaseService.storage
          .from('chat-media')
          .uploadBinary(path, bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'));
      final url = SupabaseService.storage.from('chat-media').getPublicUrl(path);
      debugPrint('[ChatRoom] ✅ Image uploaded: $url');
      await _sendMessage(type: 'image', mediaUrl: url, mediaType: 'image');
    } catch (e, stack) {
      debugPrint('[ChatRoom] ❌ Image upload error: $e');
      debugPrint('[ChatRoom] ❌ Image upload stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Imagem: $e'),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      // Bug fix #059: garantir reset do _isSending mesmo se _sendMessage
      // não for chamado (ex: falha no upload antes do _sendMessage).
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendVideoFile() async {
    final s = getStrings();
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    final error = await MediaUtils.validateVideoDuration(video.path);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // Bug fix #059: setar _isSending=true antes do upload.
    if (mounted) setState(() => _isSending = true);
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final ext = video.path.split('.').last.toLowerCase();
      final path = 'chat/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await video.readAsBytes();
      await SupabaseService.storage.from('chat-media').uploadBinary(path, bytes,
          fileOptions: const FileOptions(contentType: 'video/mp4'));
      final url = SupabaseService.storage.from('chat-media').getPublicUrl(path);
      await _sendMessage(type: 'video', mediaUrl: url, mediaType: 'video');
    } catch (e, stack) {
      debugPrint('[ChatRoom] ❌ Video upload error: $e');
      debugPrint('[ChatRoom] ❌ Video upload stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Vídeo: $e'),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
  // ==========================================================================
  // REACTIONS & PIN
  // ==========================================================================

  Future<void> _addReaction(String messageId, String emoji) async {
    try {
      await SupabaseService.rpc('toggle_reaction', params: {
        'p_message_id': messageId,
        'p_emoji': emoji,
      });
      await _loadMessages();
    } catch (e) {
      debugPrint('[chat_room_screen] Erro ao reagir: $e');
    }
  }

  Future<void> _pinMessage(String messageId) async {
    final s = getStrings();
    try {
      await SupabaseService.rpc('pin_message', params: {
        'p_thread_id': widget.threadId,
        'p_message_id': messageId,
      });
      await _loadPinnedMessages();
      await _loadMessages();
    } catch (e) {
      debugPrint('[chat_room_screen] Erro ao fixar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('host')
                ? s.onlyTheHostCanPinMessages
                : s.errorPinningMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ==========================================================================
  // DIALOGS (Tip, Poll, Link, Edit)
  // ==========================================================================

  Future<void> _showTipDialog() async {
    final s = getStrings();
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
                width: r.s(40),
                height: r.s(4),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: r.s(16)),
              Row(
                children: [
                  Container(
                    width: r.s(44),
                    height: r.s(44),
                    decoration: BoxDecoration(
                      color: context.nexusTheme.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.monetization_on_rounded,
                        color: context.nexusTheme.warning, size: r.s(24)),
                  ),
                  SizedBox(width: r.s(12)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.sendTip,
                          style: TextStyle(
                              color: context.nexusTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: r.fs(18))),
                      Text(s.sendCoinsToThisChat,
                          style: TextStyle(
                              color: Colors.grey, fontSize: r.fs(13))),
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
                      width: r.s(72),
                      height: r.s(72),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.nexusTheme.warning.withValues(alpha: 0.15)
                            : context.nexusTheme.surfacePrimary,
                        borderRadius: BorderRadius.circular(r.s(14)),
                        border: Border.all(
                          color: isSelected
                              ? context.nexusTheme.warning
                              : Colors.white.withValues(alpha: 0.05),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.monetization_on_rounded,
                              color: isSelected
                                  ? context.nexusTheme.warning
                                  : Colors.grey[600],
                              size: r.s(22)),
                          SizedBox(height: r.s(4)),
                          Text('$amount',
                              style: TextStyle(
                                color: isSelected
                                    ? context.nexusTheme.warning
                                    : context.nexusTheme.textPrimary,
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
                style: TextStyle(color: context.nexusTheme.textPrimary),
                onChanged: (val) => setModalState(() {
                  selectedAmount = int.tryParse(val);
                }),
                decoration: InputDecoration(
                  hintText: s.orTypeValue,
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(Icons.edit_rounded,
                      color: context.nexusTheme.warning, size: r.s(18)),
                  filled: true,
                  fillColor: context.nexusTheme.surfacePrimary,
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
                          ? context.nexusTheme.warning
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
                              : s.selectAnAmount,
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
    } catch (e) {
      debugPrint('[chat_room_screen.dart] $e');
    }

    await _sendMessage(type: 'tip', tipAmount: result);
  }

  void _showInlinePollCreator() {
    final s = getStrings();
    final r = context.r;
    final questionCtrl = TextEditingController();
    final optionCtrls = [TextEditingController(), TextEditingController()];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.surfaceColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.s(16))),
          title: Text(s.createPoll,
              style: TextStyle(
                  color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogInput(questionCtrl, s.question),
                SizedBox(height: r.s(8)),
                ...List.generate(
                    optionCtrls.length,
                    (i) => Padding(
                          padding: EdgeInsets.only(bottom: r.s(4)),
                          child:
                              _dialogInput(optionCtrls[i], 'Option ${i + 1}'),
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
                            size: r.s(16), color: context.nexusTheme.accentPrimary),
                        SizedBox(width: r.s(4)),
                        Text(s.addOptionLabel,
                            style: TextStyle(
                                color: context.nexusTheme.accentPrimary,
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
                child: Text(s.cancel,
                    style: TextStyle(color: Colors.grey[500]))),
            ElevatedButton(
              onPressed: () {
                final question = questionCtrl.text;
                final options = optionCtrls
                    .map((c) => c.text)
                    .where((t) => t.isNotEmpty)
                    .toList();
                Navigator.pop(ctx);
                // Bug fix: usar Future.microtask para garantir que _sendMessage
                // só seja chamado após o dialog ser completamente desmontado.
                // Chamar _sendMessage diretamente após Navigator.pop causava
                // 'Tried to build dirty widget in the wrong build scope'
                // porque setState era disparado durante o frame de fechamento.
                Future.microtask(() {
                  _sendMessage(
                    type: 'poll',
                    pollQuestion: question,
                    pollOptions: options,
                  );
                });
                questionCtrl.dispose();
                for (final c in optionCtrls) {
                  c.dispose();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.nexusTheme.accentPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(10))),
              ),
              child: Text(s.send,
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    ).then((_) {
      questionCtrl.dispose();
      for (final c in optionCtrls) {
        c.dispose();
      }
    });
  }

  void _showLinkInput() {
    final s = getStrings();
    final r = context.r;
    final linkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(16))),
        title: Text(s.shareLinkTitle,
            style: TextStyle(
                color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w700)),
        content:
            _dialogInput(linkCtrl, 'https://...', icon: Icons.link_rounded),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text(s.cancel, style: TextStyle(color: Colors.grey[500]))),
          ElevatedButton(
            onPressed: () {
              final url = linkCtrl.text;
              Navigator.pop(ctx);
              // Bug fix: Future.microtask para evitar dirty widget in wrong build scope
              Future.microtask(() => _sendMessage(type: 'link', sharedUrl: url));
              linkCtrl.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.nexusTheme.accentPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(10))),
            ),
            child: Text(s.send,
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
        color: context.nexusTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(10)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(13)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[700], fontSize: r.fs(13)),
          prefixIcon: icon != null
              ? Icon(icon, size: r.s(18), color: Colors.grey[600])
              : null,
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(12)),
        ),
      ),
    );
  }

  void _showEditMessageDialog(MessageModel message) {
    final s = getStrings();
    final r = context.r;
    final editController = TextEditingController(text: message.content ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(16))),
        title: Text(s.editMessage,
            style: TextStyle(
                color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Container(
          decoration: BoxDecoration(
            color: context.nexusTheme.surfacePrimary,
            borderRadius: BorderRadius.circular(r.s(10)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: TextField(
            controller: editController,
            autofocus: true,
            style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
            decoration: InputDecoration(
              hintText: s.editMessageHint,
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
            child: Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
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
                        content: Text(s.errorEditingTryAgain),
                        backgroundColor: context.nexusTheme.error,
                      ),
                    );
                  }
                }
              }
              editController.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.nexusTheme.accentPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(10))),
            ),
            child: Text(s.save,
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
    final s = getStrings();
    final action = await ChatMessageActionsSheet.show(
      context,
      message: message,
      onReaction: (emoji) => _addReaction(message.id, emoji),
      hostId: _threadInfo?['host_id'] as String?,
      coHostIds: (_threadInfo?['co_hosts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );

    if (!mounted || action == null) return;

    switch (action) {
      case ChatMessageAction.reply:
        setState(() => _replyingTo = message);
        break;
      case ChatMessageAction.copy:
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(s.copiedMsg),
            backgroundColor: context.nexusTheme.accentPrimary,
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
                content: Text(s.errorDeletingTryAgain),
                backgroundColor: context.nexusTheme.error,
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
                  content: s.messageDeleted,
                  isDeleted: true,
                );
              });
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(s.errorDeletingTryAgain),
                backgroundColor: context.nexusTheme.error,
              ),
            );
          }
        }
        break;
      case ChatMessageAction.report:
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(s.reportSubmittedThankYou),
            backgroundColor: context.nexusTheme.accentPrimary,
          ),
        );
        break;
    }
  }

  // ==========================================================================
  // PINNED MESSAGES SHEET
  // ==========================================================================

  void _showPinnedMessages() {
    final s = getStrings();
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
            Text(s.pinnedMessages,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(16),
                    color: context.nexusTheme.textPrimary)),
            SizedBox(height: r.s(12)),
            ..._pinnedMessages.map((m) => Container(
                  margin: EdgeInsets.only(bottom: r.s(8)),
                  padding: EdgeInsets.all(r.s(12)),
                  decoration: BoxDecoration(
                    color: context.nexusTheme.surfacePrimary,
                    borderRadius: BorderRadius.circular(r.s(12)),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final currentUserId = SupabaseService.currentUserId;
    final threadTitle = _threadInfo?['title'] as String? ?? s.chat;
    final threadType = _threadInfo?['type'] as String? ?? 'group';
    final memberCount = (_threadInfo?['member_count'] ??
            _threadInfo?['members_count']) as int? ??
        0;
    final threadIcon = _threadInfo?['icon_url'] as String?;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: context.nexusTheme.textPrimary, size: r.s(20)),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: (_chatCoverUrl != null)
                  ? () => showChatCoverPicker(
                        context: context,
                        threadId: widget.threadId,
                        currentCover: _chatCoverUrl,
                        canEdit: _callerRole == 'host' || _callerRole == 'co_host',
                        onChanged: (url) {
                          if (mounted) setState(() => _chatCoverUrl = url);
                        },
                      )
                  : null,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: context.surfaceColor,
                backgroundImage: (_chatCoverUrl ?? threadIcon) != null
                    ? CachedNetworkImageProvider(_chatCoverUrl ?? threadIcon!)
                    : null,
                child: (_chatCoverUrl == null && threadIcon == null)
                    ? Icon(
                        threadType == 'dm'
                            ? Icons.person_rounded
                            : Icons.group_rounded,
                        color: Colors.grey[500],
                        size: r.s(16),
                      )
                    : null,
              ),
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
                          color: context.nexusTheme.textPrimary)),
                  if (threadType != 'dm')
                    Text(s.memberCountMembers(memberCount),
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
            onTap: _isOpeningVoiceCall ? null : _startVoiceChat,
            child: Container(
              width: r.s(34),
              height: r.s(34),
              margin: EdgeInsets.only(right: r.s(4)),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: _isOpeningVoiceCall
                  ? Padding(
                      padding: EdgeInsets.all(r.s(9)),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.nexusTheme.accentPrimary,
                      ),
                    )
                  : Icon(Icons.headset_mic_rounded,
                      color: Colors.grey[500], size: r.s(16)),
            ),
          ),
          GestureDetector(
            onTap: _startProjection,
            child: Container(
              width: r.s(34),
              height: r.s(34),
              margin: EdgeInsets.only(right: r.s(4)),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.live_tv_rounded,
                  color: Colors.grey[500], size: r.s(16)),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: Colors.grey[500]),
            color: context.surfaceColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(12))),
            onSelected: (val) {
              switch (val) {
                case 'share':
                  if (threadType == 'public') {
                    DeepLinkService.shareUrl(
                      type: 'chat',
                      targetId: widget.threadId,
                      title: threadTitle,
                      text: threadTitle,
                    );
                  }
                  break;
                case 'members':
                  _showChatMembers();
                  break;
                case 'settings':
                  _showChatSettings();
                  break;
                case 'background':
                  _showBackgroundPicker();
                  break;
                case 'bubble':
                  _showBubblePicker();
                  break;
                case 'leave':
                  _leaveChatConfirm();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              if (threadType == 'public')
                _buildPopupItem(r, 'share', Icons.share_outlined, s.share),
              _buildPopupItem(r, 'members', Icons.people_rounded, s.members),
              _buildPopupItem(
                  r, 'settings', Icons.settings_rounded, s.settings),
              _buildPopupItem(
                  r, 'background', Icons.wallpaper_rounded, s.chatBackground),
              _buildPopupItem(
                  r, 'bubble', Icons.chat_bubble_rounded, 'Meu Bubble'),
              _buildPopupItem(
                  r, 'leave', Icons.exit_to_app_rounded, s.leaveChatTitle,
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
                color: context.nexusTheme.warning.withValues(alpha: 0.12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: r.s(12),
                      height: r.s(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: context.nexusTheme.warning,
                      ),
                    ),
                    SizedBox(width: r.s(8)),
                    Text(
                      'Reconectando...',
                      style: TextStyle(
                        fontSize: r.fs(12),
                        color: context.nexusTheme.warning,
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
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(16), vertical: r.s(8)),
                  decoration: BoxDecoration(
                    color: context.nexusTheme.warning.withValues(alpha: 0.08),
                    border: Border(
                      bottom: BorderSide(
                          color: context.nexusTheme.warning.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.push_pin_rounded,
                          size: r.s(14), color: context.nexusTheme.warning),
                      SizedBox(width: r.s(8)),
                      Expanded(
                        child: Text(
                          _pinnedMessages.first['content'] as String? ??
                              s.messagePinned,
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
                  ? Center(
                      child: CircularProgressIndicator(
                          color: context.nexusTheme.accentPrimary, strokeWidth: 2))
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
                              Text(s.noMessagesYet,
                                  style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: r.fs(15),
                                      fontWeight: FontWeight.w600)),
                              SizedBox(height: r.s(6)),
                              Text(s.startConversation2,
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: r.fs(12))),
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
                            final showAvatar = !message.isSystemMessage;

                            // Separador de data: exibe quando a mensagem atual
                            // é de um dia diferente da próxima mais antiga.
                            // Como a lista é reverse: true, index+1 é mais antigo.
                            final DateTime? prevDate = index < _messages.length - 1
                                ? _messages[index + 1].createdAt
                                : null;
                            final showDateSep = shouldShowDateSeparator(
                                message.createdAt, prevDate);

                            final repliedMessage =
                                _findMessageById(message.replyToId);
                            final messageKey = _messageKeyFor(message.id);
                            final isReplyTargetHighlighted =
                                _highlightedMessageId == message.id;

                            return RepaintBoundary(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showDateSep)
                                    ChatDateSeparator(date: message.createdAt),
                                  AnimatedContainer(
                                    key: messageKey,
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    margin: EdgeInsets.symmetric(vertical: r.s(2)),
                                    padding: EdgeInsets.all(
                                      isReplyTargetHighlighted ? r.s(4) : 0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isReplyTargetHighlighted
                                          ? context.nexusTheme.accentPrimary.withValues(alpha: 0.12)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(r.s(18)),
                                      border: isReplyTargetHighlighted
                                          ? Border.all(
                                              color: context.nexusTheme.accentPrimary
                                                  .withValues(alpha: 0.35),
                                            )
                                          : null,
                                    ),
                                    child: GestureDetector(
                                      onLongPress: () => _showMessageActions(message),
                                      child: MessageBubble(
                                        message: message,
                                        isMe: isMe,
                                        showAvatar: showAvatar,
                                        onReactionTap: (emoji) =>
                                            _addReaction(message.id, emoji),
                                        communityId:
                                            _threadInfo?['community_id'] as String?,
                                        repliedMessage: repliedMessage,
                                        onReplyTap: repliedMessage == null
                                            ? null
                                            : () => _jumpToMessage(repliedMessage.id),
                                      ),
                                    ),
                                  ),
                                ],
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

            // ── Membership CTA — diferenciado por tipo de chat ──
            // public: usuário pode entrar livremente (rejoin_public_chat)
            // dm (invite_sent): destinatário vê botões de aceitar/recusar
            // dm (sender): remetente vê mensagem aguardando aceitação
            // group: acesso restrito

            // CTA: destinatário de convite DM pendente
            if (_isDmInvitePending && !_isLoading)
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(16), vertical: r.s(14)),
                decoration: BoxDecoration(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.08),
                  border: Border(
                      top: BorderSide(
                          color: context.nexusTheme.accentPrimary.withValues(alpha: 0.2))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mail_rounded,
                            color: context.nexusTheme.accentPrimary, size: r.s(18)),
                        SizedBox(width: r.s(8)),
                        Expanded(
                          child: Text(
                            'Você recebeu um convite de chat. Aceite para participar e responder.',
                            style: TextStyle(
                                color: Colors.grey[300], fontSize: r.fs(13)),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.s(10)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _isSending
                              ? null
                              : () async {
                                  setState(() => _isSending = true);
                                  try {
                                    await SupabaseService.rpc(
                                        'respond_dm_invite',
                                        params: {
                                          'p_thread_id': widget.threadId,
                                          'p_accept': false,
                                        });
                                    if (mounted) {
                                      ref.invalidate(chatListProvider);
                                      ref.invalidate(chatCommunitiesProvider);
                                      context.pop();
                                    }
                                  } catch (e) {
                                    debugPrint('[ChatRoom] decline invite error: $e');
                                    if (mounted) {
                                      setState(() => _isSending = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Erro ao recusar convite.'),
                                          backgroundColor: context.nexusTheme.error,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[400],
                            side: BorderSide(color: Colors.grey[600]!),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(r.s(10))),
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(16), vertical: r.s(8)),
                          ),
                          child: Text('Recusar',
                              style: TextStyle(fontSize: r.fs(13))),
                        ),
                        SizedBox(width: r.s(10)),
                        ElevatedButton(
                          onPressed: _isSending
                              ? null
                              : () async {
                                  setState(() => _isSending = true);
                                  try {
                                    await SupabaseService.rpc(
                                        'respond_dm_invite',
                                        params: {
                                          'p_thread_id': widget.threadId,
                                          'p_accept': true,
                                        });
                                    if (mounted) {
                                      setState(() {
                                        _isSending = false;
                                        _isDmInvitePending = false;
                                        _membershipConfirmed = true;
                                      });
                                      ref.invalidate(chatListProvider);
                                      ref.invalidate(chatCommunitiesProvider);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Convite aceito! Agora você pode conversar.'),
                                          backgroundColor: context.nexusTheme.accentPrimary,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint('[ChatRoom] accept invite error: $e');
                                    if (mounted) {
                                      setState(() => _isSending = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Erro ao aceitar convite.'),
                                          backgroundColor: context.nexusTheme.error,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.nexusTheme.accentPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(r.s(10))),
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(16), vertical: r.s(8)),
                          ),
                          child: _isSending
                              ? SizedBox(
                                  width: r.s(16),
                                  height: r.s(16),
                                  child: const CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text('Aceitar',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: r.fs(13))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // CTA: remetente aguardando aceitação
            if (_isDmInviteSender && !_isDmInvitePending && !_isLoading)
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(16), vertical: r.s(10)),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  border: Border(
                      top: BorderSide(
                          color: Colors.orange.withValues(alpha: 0.2))),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded,
                        color: Colors.orange, size: r.s(16)),
                    SizedBox(width: r.s(8)),
                    Expanded(
                      child: Text(
                        'Aguardando aceitação do convite. Suas mensagens serão entregues quando o convite for aceito.',
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: r.fs(12)),
                      ),
                    ),
                  ],
                ),
              ),

            // CTA: não membro (chat público ou acesso restrito)
            if (!_membershipConfirmed && !_isDmInvitePending && !_isLoading)
              Builder(builder: (context) {
                final threadType = _threadInfo?['type'] as String? ?? 'public';
                final isPublic = threadType == 'public';
                return Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(16), vertical: r.s(12)),
                  decoration: BoxDecoration(
                    color:
                        (isPublic ? context.nexusTheme.accentPrimary : Colors.grey[700]!)
                            .withValues(alpha: 0.08),
                    border: Border(
                        top: BorderSide(
                            color: (isPublic
                                    ? context.nexusTheme.accentPrimary
                                    : Colors.grey[700]!)
                                .withValues(alpha: 0.2))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isPublic
                              ? s.notMemberChat
                              : 'Acesso restrito. Aguarde um convite.',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: r.fs(13)),
                        ),
                      ),
                      if (isPublic) ...[
                        SizedBox(width: r.s(8)),
                        ElevatedButton(
                          onPressed: _isSending
                              ? null
                              : () async {
                                  setState(() => _isSending = true);
                                  // Chat público: re-entrar via rejoin_public_chat
                                  // (atualiza status='left' para 'active').
                                  try {
                                    await SupabaseService.rpc(
                                        'rejoin_public_chat',
                                        params: {
                                          'p_thread_id': widget.threadId,
                                        });
                                    if (mounted) {
                                      setState(() {
                                        _isSending = false;
                                        _membershipConfirmed = true;
                                      });
                                      try {
                                        ref.invalidate(chatListProvider);
                                        ref.invalidate(chatCommunitiesProvider);
                                      } catch (e) {
                                        debugPrint(
                                            '[chat_room_screen.dart] $e');
                                      }
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                         SnackBar(
                                          content: Text(s.joinedChat),
                                          backgroundColor:
                                              context.nexusTheme.accentPrimary,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint(
                                        '[ChatRoom] rejoin_public_chat error: $e');
                                    if (mounted) {
                                      setState(() => _isSending = false);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                         SnackBar(
                                          content: Text(
                                              s.errorJoiningChat),
                                          backgroundColor: context.nexusTheme.error,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.nexusTheme.accentPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(r.s(10))),
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(16), vertical: r.s(8)),
                          ),
                          child: _isSending
                              ? SizedBox(
                                  width: r.s(16),
                                  height: r.s(16),
                                  child: const CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(s.joinChat,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: r.fs(13))),
                        ),
                      ],
                    ],
                  ),
                );
              }),

            // ── Announcement-only banner (bloqueia input para não-admin) ──
            if (_isAnnouncementOnly &&
                _callerRole != 'host' &&
                _callerRole != 'co_host' &&
                _membershipConfirmed)
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(16), vertical: r.s(12)),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  border: Border(
                      top: BorderSide(
                          color: Colors.amber.withValues(alpha: 0.2))),
                ),
                child: Row(
                  children: [
                    Icon(Icons.campaign_rounded,
                        color: Colors.amber, size: r.s(18)),
                    SizedBox(width: r.s(8)),
                    Expanded(
                      child: Text(
                        'Apenas admins podem enviar mensagens neste chat.',
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: r.fs(12)),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Voice recorder / Input bar ──
            if (_isRecordingVoice)
              SafeArea(
                top: false,
                child: VoiceRecorder(
                  onRecordingComplete: (filePath, duration) async {
                    // Bug #7 fix: checar _isDisposed além de mounted para evitar
                    // setState/callbacks em widget já descartado (lifecycle defunct).
                    if (_isDisposed || !mounted) return;
                    setState(() => _isRecordingVoice = false);
                    try {
                      final file = File(filePath);
                      final fileName =
                          'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
                      final storagePath =
                          'audio/${widget.threadId}/$fileName';
                      debugPrint('[ChatRoom] 🎤 Uploading audio: $storagePath');
                      await SupabaseService.client.storage
                          .from('chat-media')
                          .upload(storagePath, file,
                              fileOptions: const FileOptions(
                                // Bug fix: audio/mp4 não era aceito pelo bucket.
                                // Usar audio/m4a que é o formato correto para .m4a
                                contentType: 'audio/m4a',
                                upsert: true,
                              ));
                      if (_isDisposed || !mounted) return;
                      final url = SupabaseService.client.storage
                          .from('chat-media')
                          .getPublicUrl(storagePath);
                      debugPrint('[ChatRoom] ✅ Audio uploaded: $url');
                      _sendMessage(
                        type: 'audio',
                        mediaUrl: url,
                        mediaType: 'audio',
                        mediaDuration: duration,
                      );
                    } catch (e, stack) {
                      debugPrint('[ChatRoom] ❌ Audio upload error: $e');
                      debugPrint('[ChatRoom] ❌ Audio upload stack: $stack');
                      if (!_isDisposed && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Áudio: $e'),
                            backgroundColor: context.nexusTheme.error,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 10),
                          ),
                        );
                      }
                    }
                  },
                  onCancel: () {
                    if (_isDisposed || !mounted) return;
                    setState(() => _isRecordingVoice = false);
                  },
                ),
              )
            else if ((_membershipConfirmed || _isLoading) &&
                !(_isAnnouncementOnly &&
                    _callerRole != 'host' &&
                    _callerRole != 'co_host'))
              ChatInputBar(
                controller: _messageController,
                isSending: _isSending,
                onMediaTap: () => _showMediaOptions(context),
                onSend: () => _sendMessage(),
                onEmojiToggle: () =>
                    setState(() => _showEmojiPicker = !_showEmojiPicker),
                onAudioTap: () =>
                    setState(() => _isRecordingVoice = true),
                onTextChanged: _onTextChanged,
              ),

            // ── Emoji picker ──
            if (_showEmojiPicker)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.3 > 250
                    ? 250
                    : MediaQuery.of(context).size.height * 0.3,
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
                    bgColor: context.nexusTheme.backgroundPrimary,
                    indicatorColor: context.nexusTheme.accentPrimary,
                    iconColorSelected: context.nexusTheme.accentPrimary,
                    iconColor: (Colors.grey[600] ?? Colors.grey),
                    checkPlatformCompatibility: true,
                    recentTabBehavior: RecentTabBehavior.RECENT,
                    recentsLimit: 20,
                    noRecents: Text(
                      s.noRecentEmoji,
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
        if (!mounted) return;
        await StickerPickerV2.show(
          context,
          onStickerSelected: (sticker) {
            _sendMessage(
              type: 'sticker',
              mediaUrl: sticker.imageUrl,
              stickerId: sticker.id,
              stickerUrl: sticker.imageUrl,
              stickerName: sticker.name,
              packId: sticker.packId.isNotEmpty ? sticker.packId : null,
            );
          },
        );
      },
      onAudio: () => setState(() => _isRecordingVoice = true),
      onPoll: _showInlinePollCreator,
      onTip: _showTipDialog,
      onScreening: _startProjection,
      onLink: _showLinkInput,
      onVideoFile: _sendVideoFile,
    );
  }

  // ==========================================================================
  // LINK DETECTION (onTextChanged)
  // ==========================================================================

  void _onTextChanged(String value) {
    final s = getStrings();
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
            title: Text(s.nameLink,
                style: TextStyle(
                    color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.nameLinkOptional,
                    style:
                        TextStyle(color: context.nexusTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: TextStyle(color: context.nexusTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: s.clickHereExample,
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
              ),
              TextButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final replacement = name.isNotEmpty ? '[$name]($url)' : url;
                  final newText = value.replaceFirst(url, replacement);
                  _messageController.text = newText;
                  _messageController.selection = TextSelection.fromPosition(
                    TextPosition(offset: newText.length),
                  );
                  Navigator.pop(ctx);
                },
                child: Text(s.confirm,
                    style: TextStyle(
                        color: context.nexusTheme.accentPrimary,
                        fontWeight: FontWeight.w700)),
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
                  color: context.nexusTheme.warning,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.nexusTheme.backgroundPrimary, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
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
              color: isDestructive ? context.nexusTheme.error : Colors.grey[400]),
          SizedBox(width: r.s(10)),
          Text(label,
              style: TextStyle(
                  color: isDestructive ? context.nexusTheme.error : Colors.grey[300],
                  fontSize: r.fs(13))),
        ],
      ),
    );
  }
}

// =============================================================================
// CHAT MEMBERS SHEET — Mostra membros do chat (Bug #6 fix)
// =============================================================================
class _ChatMembersSheet extends ConsumerStatefulWidget {
  final String threadId;
  final ScrollController scrollController;

  const _ChatMembersSheet({
    required this.threadId,
    required this.scrollController,
  });

  @override
  ConsumerState<_ChatMembersSheet> createState() => _ChatMembersSheetState();
}

class _ChatMembersSheetState extends ConsumerState<_ChatMembersSheet> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final response = await SupabaseService.table('chat_members')
          .select(
              '*, profiles!chat_members_user_id_fkey(id, nickname, icon_url)')
          .eq('thread_id', widget.threadId)
          .order('joined_at', ascending: true)
          .limit(100);
      if (mounted) {
        setState(() {
          _members = List<Map<String, dynamic>>.from(response as List? ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ChatMembersSheet] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Column(
      children: [
        Container(
          width: r.s(36),
          height: r.s(4),
          margin: EdgeInsets.only(top: r.s(12), bottom: r.s(8)),
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
          child: Row(
            children: [
              Text(s.chatMembers,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(16),
                      color: context.nexusTheme.textPrimary)),
              const Spacer(),
              Text('${_members.length}',
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: r.fs(13))),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                      color: context.nexusTheme.accentPrimary, strokeWidth: 2))
              : _members.isEmpty
                  ? Center(
                      child: Text(s.noMemberFound,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: r.fs(13))),
                    )
                  : ListView.builder(
                      controller: widget.scrollController,
                      padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final profile =
                            member['profiles'] as Map<String, dynamic>? ?? {};
                        final nickname =
                            profile['nickname'] as String? ?? s.user;
                        final iconUrl = profile['icon_url'] as String?;
                        final role = member['role'] as String?;

                        return Container(
                          padding: EdgeInsets.symmetric(vertical: r.s(8)),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.05)),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: r.s(18),
                                backgroundColor: context.nexusTheme.accentPrimary
                                    .withValues(alpha: 0.2),
                                backgroundImage: iconUrl != null
                                    ? CachedNetworkImageProvider(iconUrl)
                                    : null,
                                child: iconUrl == null
                                    ? Text(
                                        nickname.isNotEmpty
                                            ? nickname[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                            color: context.nexusTheme.accentPrimary,
                                            fontWeight: FontWeight.w700))
                                    : null,
                              ),
                              SizedBox(width: r.s(12)),
                              Expanded(
                                child: Text(nickname,
                                    style: TextStyle(
                                        color: context.nexusTheme.textPrimary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: r.fs(14))),
                              ),
                              if (role != null && role != 'member')
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(8), vertical: r.s(3)),
                                  decoration: BoxDecoration(
                                    color: context.nexusTheme.accentPrimary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(r.s(8)),
                                  ),
                                  child: Text(
                                    role.toUpperCase(),
                                    style: TextStyle(
                                      color: context.nexusTheme.accentPrimary,
                                      fontSize: r.fs(9),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// =============================================================================
// BUBBLE PICKER SHEET — Seleciona o chat bubble ativo dentro do chat
// =============================================================================

/// Bottom sheet que lista todos os chat_bubbles comprados pelo usuário,
/// com preview visual e opção de equipar/desequipar.
///
/// Usa [ConsumerStatefulWidget] para buscar as compras diretamente do Supabase
/// e refletir o estado de equipado em tempo real.
class _BubblePickerSheet extends ConsumerStatefulWidget {
  /// Callback chamado quando o usuário toca em um bubble.
  /// Recebe o [purchaseId] e o [itemType] para passar ao RPC equip_store_item.
  final Future<void> Function(String purchaseId, String itemType) onBubbleSelected;

  const _BubblePickerSheet({required this.onBubbleSelected});

  @override
  ConsumerState<_BubblePickerSheet> createState() => _BubblePickerSheetState();
}

class _BubblePickerSheetState extends ConsumerState<_BubblePickerSheet> {
  List<Map<String, dynamic>> _ownedBubbles = [];
  bool _isLoading = true;
  String? _busyPurchaseId;

  @override
  void initState() {
    super.initState();
    _loadOwnedBubbles();
  }

  Future<void> _loadOwnedBubbles() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Busca todas as compras do tipo chat_bubble com os dados do store_item
      final purchases = await SupabaseService.table('user_purchases')
          .select(
            'id, item_id, is_equipped, '
            'store_items!user_purchases_item_id_fkey('
            '  id, name, type, preview_url, asset_url, asset_config'
            ')',
          )
          .eq('user_id', userId);

      final bubbles = <Map<String, dynamic>>[];
      for (final p in (purchases as List? ?? [])) {
        final item = p['store_items'];
        if (item == null) continue;
        final type = (item['type'] ?? '').toString();
        if (type != 'chat_bubble') continue;
        bubbles.add({
          'purchase_id': p['id'] as String? ?? '',
          'item_id': item['id'] as String? ?? '',
          'name': item['name'] as String? ?? 'Bubble',
          'type': type,
          'is_equipped': p['is_equipped'] as bool? ?? false,
          'preview_url': item['preview_url'] as String? ?? '',
          'asset_url': item['asset_url'] as String? ?? '',
          'asset_config': item['asset_config'] as Map<String, dynamic>? ?? {},
        });
      }

      if (mounted) {
        setState(() {
          _ownedBubbles = bubbles;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[BubblePicker] Erro ao carregar bubbles: $e');
      debugPrint('[BubblePicker] STACK TRACE:\n$st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onTap(Map<String, dynamic> bubble) async {
    final purchaseId = bubble['purchase_id'] as String? ?? '';
    final itemType = bubble['type'] as String? ?? 'chat_bubble';
    debugPrint('[BubblePicker] _onTap purchase_id=$purchaseId type=$itemType');
    if (purchaseId.isEmpty || _busyPurchaseId != null) {
      debugPrint('[BubblePicker] _onTap ignorado: '
          'purchaseId.isEmpty=${purchaseId.isEmpty} '
          'busy=$_busyPurchaseId');
      return;
    }

    setState(() => _busyPurchaseId = purchaseId);
    try {
      await widget.onBubbleSelected(purchaseId, itemType);
      // Recarrega para refletir novo estado is_equipped
      await _loadOwnedBubbles();
    } catch (e, st) {
      debugPrint('[BubblePicker] _onTap ERRO: $e');
      debugPrint('[BubblePicker] STACK TRACE:\n$st');
    } finally {
      if (mounted) setState(() => _busyPurchaseId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Padding(
      padding: EdgeInsets.only(
        left: r.s(16),
        right: r.s(16),
        top: r.s(20),
        bottom: MediaQuery.of(context).viewInsets.bottom + r.s(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──
          Center(
            child: Container(
              width: r.s(36),
              height: r.s(4),
              margin: EdgeInsets.only(bottom: r.s(16)),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Título ──
          Row(
            children: [
              Icon(Icons.chat_bubble_rounded,
                  color: context.nexusTheme.accentPrimary, size: r.s(20)),
              SizedBox(width: r.s(8)),
              Text(
                'Meu Bubble',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: r.fs(16),
                  color: context.nexusTheme.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: r.s(4)),
          Text(
            'Selecione o bubble que aparecerá nas suas mensagens.',
            style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
          ),
          SizedBox(height: r.s(16)),

          // ── Conteúdo ──
          if (_isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: r.s(32)),
                child: CircularProgressIndicator(
                  color: context.nexusTheme.accentPrimary,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_ownedBubbles.isEmpty)
            _EmptyBubbleState(r: r)
          else
            // Lista de bubbles com preview
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: r.screenHeight * 0.55,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _ownedBubbles.length + 1, // +1 para o item "Padrão"
                separatorBuilder: (_, __) => Divider(
                  color: Colors.white.withValues(alpha: 0.05),
                  height: 1,
                ),
                itemBuilder: (ctx, i) {
                  // Primeiro item: bubble padrão (sem cosmético)
                  if (i == 0) {
                    return _BubblePickerItem(
                      r: r,
                      name: 'Padrão',
                      subtitle: 'Bubble padrão do app',
                      isEquipped: _ownedBubbles.every(
                          (b) => !(b['is_equipped'] as bool? ?? false)),
                      isBusy: false,
                      previewWidget: _DefaultBubblePreview(r: r),
                      onTap: () async {
                        // Desequipa todos os bubbles — passa purchaseId vazio
                        // para que o RPC receba null e desequipe todos
                        setState(() => _busyPurchaseId = 'default');
                        try {
                          await widget.onBubbleSelected(
                            '', // vazio = null no RPC = desequipa todos
                            'chat_bubble',
                          );
                          await _loadOwnedBubbles();
                        } finally {
                          if (mounted) setState(() => _busyPurchaseId = null);
                        }
                      },
                    );
                  }

                  final bubble = _ownedBubbles[i - 1];
                  final assetConfig =
                      bubble['asset_config'] as Map<String, dynamic>? ?? {};
                  final imageUrl = (assetConfig['bubble_url'] as String?)
                      ?.trim()
                      .isNotEmpty == true
                      ? assetConfig['bubble_url'] as String
                      : (assetConfig['image_url'] as String?)?.trim().isNotEmpty == true
                          ? assetConfig['image_url'] as String
                          : (bubble['preview_url'] as String?)?.trim().isNotEmpty == true
                              ? bubble['preview_url'] as String
                              : null;
                  final bubbleColor = _parseColor(
                      assetConfig['bubble_color'] as String? ??
                          assetConfig['color'] as String? ?? '');
                  final isEquipped = bubble['is_equipped'] as bool? ?? false;
                  final purchaseId = bubble['purchase_id'] as String? ?? '';
                  final isBusy = _busyPurchaseId == purchaseId;

                  return _BubblePickerItem(
                    r: r,
                    name: bubble['name'] as String? ?? 'Bubble',
                    subtitle: isEquipped ? 'Equipado' : 'Toque para equipar',
                    isEquipped: isEquipped,
                    isBusy: isBusy,
                    previewWidget: _BubblePreview(
                      r: r,
                      imageUrl: imageUrl,
                      bubbleColor: bubbleColor,
                    ),
                    onTap: () => _onTap(bubble),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Color? _parseColor(String hex) {
    if (hex.isEmpty) return null;
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return null;
    }
  }
}

// ─── Item de bubble na lista ────────────────────────────────────────────────

class _BubblePickerItem extends StatelessWidget {
  final Responsive r;
  final String name;
  final String subtitle;
  final bool isEquipped;
  final bool isBusy;
  final Widget previewWidget;
  final VoidCallback onTap;

  const _BubblePickerItem({
    required this.r,
    required this.name,
    required this.subtitle,
    required this.isEquipped,
    required this.isBusy,
    required this.previewWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBusy ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: r.s(12), horizontal: r.s(4)),
        child: Row(
          children: [
            // Preview do bubble
            SizedBox(
              width: r.s(120),
              height: r.s(52),
              child: previewWidget,
            ),
            SizedBox(width: r.s(12)),

            // Nome e status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: r.fs(14),
                    ),
                  ),
                  SizedBox(height: r.s(2)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isEquipped
                          ? context.nexusTheme.accentPrimary
                          : Colors.grey[500],
                      fontSize: r.fs(12),
                    ),
                  ),
                ],
              ),
            ),

            // Indicador de estado
            if (isBusy)
              SizedBox(
                width: r.s(20),
                height: r.s(20),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.nexusTheme.accentPrimary,
                ),
              )
            else if (isEquipped)
              Icon(Icons.check_circle_rounded,
                  color: context.nexusTheme.accentPrimary, size: r.s(22))
            else
              Icon(Icons.radio_button_unchecked_rounded,
                  color: Colors.grey[600], size: r.s(22)),
          ],
        ),
      ),
    );
  }
}

// ─── Preview do bubble padrão ────────────────────────────────────────────────

class _DefaultBubblePreview extends StatelessWidget {
  final Responsive r;
  const _DefaultBubblePreview({required this.r});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(12), vertical: r.s(8)),
        decoration: BoxDecoration(
          color: context.nexusTheme.accentPrimary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Text(
          'Olá!',
          style: TextStyle(
            color: Colors.white,
            fontSize: r.fs(13),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Preview de bubble com imagem ou cor ─────────────────────────────────────

class _BubblePreview extends StatelessWidget {
  final Responsive r;
  final String? imageUrl;
  final Color? bubbleColor;

  const _BubblePreview({
    required this.r,
    this.imageUrl,
    this.bubbleColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      // Preview nine-slice via CustomPainter+drawImageNine.
      // Image/DecorationImage+centerSlice lançam assertion no Flutter moderno.
      return Stack(
        children: [
          Positioned.fill(
            child: NineSlicePreview(
              imageUrl: imageUrl!,
              sliceInsets: const EdgeInsets.all(38),
            ),
          ),
          Center(
            child: Text(
              'Olá!',
              style: TextStyle(
                color: Colors.white,
                fontSize: r.fs(13),
                fontWeight: FontWeight.w500,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Preview com cor sólida
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
      decoration: BoxDecoration(
        color: bubbleColor ?? context.nexusTheme.accentPrimary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: Text(
        'Olá!',
        style: TextStyle(
          color: Colors.white,
          fontSize: r.fs(13),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _fallbackContainer(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(10)),
        border: Border.all(
          color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
    );
  }
}

// ─── Estado vazio (sem bubbles comprados) ────────────────────────────────────

class _EmptyBubbleState extends StatelessWidget {
  final Responsive r;
  const _EmptyBubbleState({required this.r});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.s(32)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.grey[700], size: r.s(40)),
            SizedBox(height: r.s(12)),
            Text(
              'Você não possui bubbles',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: r.fs(14),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: r.s(4)),
            Text(
              'Visite a Loja para adquirir novos estilos.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: r.fs(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
