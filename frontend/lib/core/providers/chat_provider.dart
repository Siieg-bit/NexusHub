import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/message_model.dart';

/// ============================================================================
/// ChatProvider — State Management com AsyncNotifier para chat.
///
/// Gerencia:
/// - Lista de threads do usuário
/// - Mensagens de uma thread (paginadas)
/// - Envio de mensagens
/// - Realtime subscription
/// - Unread count
/// ============================================================================

// ── Chat Threads ──
class ChatThreadsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return _fetch();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    final res = await SupabaseService.table('chat_members')
        .select(
            'thread_id, chat_threads!inner(*, chat_messages(content, created_at, author_id))')
        .eq('user_id', userId)
        .order('updated_at', referencedTable: 'chat_threads', ascending: false)
        .limit(50);

    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final chatThreadsProvider =
    AsyncNotifierProvider<ChatThreadsNotifier, List<Map<String, dynamic>>>(
        ChatThreadsNotifier.new);

// ── Mapeamento de tipos de mensagem para o enum do banco ──
/// O enum `chat_message_type` no banco aceita apenas estes valores:
/// text, strike, voice_note, sticker, video, share_url, share_user,
/// system_deleted, system_join, system_leave, system_voice_start,
/// system_voice_end, system_screen_start, system_screen_end,
/// system_tip, system_pin, system_unpin, system_removed, system_admin_delete
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
    case 'image':
      return 'text';
    case 'gif':
      return 'text';
    case 'audio':
      return 'voice_note';
    case 'reply':
      return 'text';
    case 'voice_chat':
      return 'system_voice_start';
    case 'video_chat':
      return 'system_voice_start';
    case 'screening_room':
      return 'system_screen_start';
    case 'poll':
      return 'text';
    case 'link':
      return 'share_url';
    case 'tip':
      return 'system_tip';
    case 'forward':
      return 'text';
    case 'file':
      return 'text';
    default:
      return 'text';
  }
}

// ── Thread Messages ──
class ThreadMessagesNotifier
    extends FamilyAsyncNotifier<List<MessageModel>, String> {
  int _page = 0;
  bool _hasMore = true;
  static const _pageSize = 50;
  RealtimeChannel? _channel;

  @override
  Future<List<MessageModel>> build(String threadId) async {
    _page = 0;
    _hasMore = true;

    // Inscrever no Realtime
    _subscribeRealtime(threadId);

    // Cleanup quando o provider é descartado
    ref.onDispose(() {
      _channel?.unsubscribe();
    });

    return _fetchPage(threadId, 0);
  }

  Future<List<MessageModel>> _fetchPage(String threadId, int page) async {
    final res = await SupabaseService.table('chat_messages')
        .select('*, profiles!chat_messages_author_id_fkey(id, nickname, icon_url)')
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .range(page * _pageSize, (page + 1) * _pageSize - 1);

    final list = res as List;
    final messages = list.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      // Normalizar o campo de autor para que MessageModel.fromJson encontre
      if (map['profiles'] != null) {
        map['sender'] = map['profiles'];
        map['author'] = map['profiles'];
      }
      return MessageModel.fromJson(map);
    }).toList().reversed.toList();

    _hasMore = list.length >= _pageSize;
    return messages;
  }

  void _subscribeRealtime(String threadId) {
    _channel?.unsubscribe();
    _channel = SupabaseService.client
        .channel('messages:$threadId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) async {
            final newMsg = Map<String, dynamic>.from(payload.newRecord);

            // Buscar perfil do autor para evitar crash no render
            try {
              final authorId = newMsg['author_id'] as String?;
              if (authorId != null) {
                final profile = await SupabaseService.table('profiles')
                    .select('id, nickname, icon_url')
                    .eq('id', authorId)
                    .single();
                newMsg['sender'] = profile;
                newMsg['author'] = profile;
              }
            } catch (_) {
              // Se não conseguir buscar o perfil, continua sem ele
            }

            final message = MessageModel.fromJson(newMsg);
            final current = state.valueOrNull ?? [];

            // Evitar duplicatas (a mensagem pode já ter sido adicionada pelo insert local)
            if (current.any((m) => m.id == message.id)) return;

            state = AsyncData([...current, message]);
          },
        )
        .subscribe();
  }

  Future<void> loadOlder() async {
    if (!_hasMore) return;
    final current = state.valueOrNull ?? [];
    _page++;
    try {
      final older = await _fetchPage(arg, _page);
      state = AsyncData([...older, ...current]);
    } catch (e) {
      _page--;
    }
  }

  Future<bool> sendMessage({
    required String content,
    String type = 'text',
    String? mediaUrl,
    String? mediaType,
    String? replyToId,
    String? stickerId,
    String? stickerUrl,
    String? sharedUrl,
    int? tipAmount,
  }) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return false;

      final mappedType = _mapMessageType(type);

      final payload = <String, dynamic>{
        'thread_id': arg,
        'author_id': userId,
        'content': content.isNotEmpty ? content : '',
        'type': mappedType,
      };

      // Campos opcionais — só adicionar se não null
      if (mediaUrl != null) payload['media_url'] = mediaUrl;
      if (mediaType != null) payload['media_type'] = mediaType;
      if (replyToId != null) payload['reply_to_id'] = replyToId;
      if (stickerId != null) payload['sticker_id'] = stickerId;
      if (stickerUrl != null) payload['sticker_url'] = stickerUrl;
      if (sharedUrl != null) payload['shared_url'] = sharedUrl;
      if (tipAmount != null) payload['tip_amount'] = tipAmount;

      await SupabaseService.table('chat_messages').insert(payload);

      // Atualizar last_message da thread
      await SupabaseService.table('chat_threads').update({
        'updated_at': DateTime.now().toIso8601String(),
        'last_message_at': DateTime.now().toIso8601String(),
        'last_message_preview': content.isNotEmpty
            ? (content.length > 100 ? '${content.substring(0, 100)}...' : content)
            : (type == 'image' ? '📷 Imagem' : type == 'sticker' ? '🎨 Sticker' : ''),
      }).eq('id', arg);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    try {
      await SupabaseService.table('chat_messages').update({
        'type': 'system_deleted',
        'content': 'Mensagem apagada',
      }).eq('id', messageId);

      final current = state.valueOrNull ?? [];
      final index = current.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        final updated = [...current];
        updated.removeAt(index);
        state = AsyncData(updated);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  bool get hasMore => _hasMore;
}

final threadMessagesProvider = AsyncNotifierProvider.family<
    ThreadMessagesNotifier,
    List<MessageModel>,
    String>(ThreadMessagesNotifier.new);

// ── Unread Count ──
final unreadCountProvider = FutureProvider<int>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return 0;

  try {
    final res = await SupabaseService.table('notifications')
        .select()
        .eq('user_id', userId)
        .eq('is_read', false)
        .eq('notification_type', 'chat')
        .count(CountOption.exact);

    return res.count;
  } catch (_) {
    return 0;
  }
});
