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

    final res = await SupabaseService.table('thread_participants')
        .select(
            'thread_id, chat_threads!inner(*, messages(content, created_at, sender_id))')
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
    final res = await SupabaseService.table('messages')
        .select('*, profiles!messages_sender_id_fkey(nickname, icon_url)')
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .range(page * _pageSize, (page + 1) * _pageSize - 1);

    final list = res as List;
    final messages = list
        .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();

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
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) {
            final newMsg = MessageModel.fromJson(payload.newRecord);
            final current = state.valueOrNull ?? [];
            state = AsyncData([...current, newMsg]);
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
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return false;

      await SupabaseService.table('messages').insert({
        'thread_id': arg,
        'sender_id': userId,
        'content': content,
        'message_type': type,
        if (metadata != null) 'metadata': metadata,
      });

      // Atualizar updated_at da thread
      await SupabaseService.table('chat_threads').update(
          {'updated_at': DateTime.now().toIso8601String()}).eq('id', arg);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    try {
      await SupabaseService.table('messages').update({
        'message_type': 'deleted',
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

  // Contar mensagens não lidas (simplificado)
  final res = await SupabaseService.table('notifications')
      .select()
      .eq('user_id', userId)
      .eq('is_read', false)
      .eq('notification_type', 'chat')
      .count(CountOption.exact);

  return res.count;
});
