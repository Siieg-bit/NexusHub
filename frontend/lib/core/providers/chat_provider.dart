import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/realtime_service.dart';
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

// ── Mapeamento de tipos de mensagem para o enum do banco ──
// NOTA: chatThreadsProvider foi removido (Etapa 1 — dead code).
// A lista de chats do usuário é gerenciada exclusivamente pelo chatListProvider
// em chat_list_screen.dart, que é a fonte de verdade para "Meus chats".
// Não confundir com "Chats públicos disponíveis" (descoberta), que é um
// conceito separado a ser implementado em etapa futura.
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

  @override
  Future<List<MessageModel>> build(String threadId) async {
    _page = 0;
    _hasMore = true;

    // Inscrever no Realtime
    _subscribeRealtime(threadId);

    // Cleanup quando o provider é descartado
    ref.onDispose(() {
      RealtimeService.instance.unsubscribe('messages:$threadId');
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
    // Usar RealtimeService para reconexão automática com backoff
    RealtimeService.instance.subscribeWithRetry(
      channelName: 'messages:$threadId',
      configure: (channel) {
        channel.onPostgresChanges(
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
        );
      },
    );
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

      // Determinar media_url final
      String? finalMediaUrl = mediaUrl ?? stickerUrl;

      // Usar RPC SECURITY DEFINER que:
      // 1. Verifica membership
      // 2. Insere a mensagem
      // 3. Atualiza last_message_at do thread (sem precisar de permissão de host)
      // 4. Adiciona reputação automaticamente
      await SupabaseService.rpc('send_chat_message_with_reputation', params: {
        'p_thread_id': arg,
        'p_author_id': userId,
        'p_content': content.isNotEmpty ? content : '',
        'p_type': mappedType,
        'p_media_url': finalMediaUrl,
        'p_reply_to': replyToId,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Editar mensagem (apenas o autor, apenas texto)
  Future<bool> editMessage(String messageId, String newContent) async {
    try {
      await SupabaseService.rpc('edit_chat_message', params: {
        'p_message_id': messageId,
        'p_new_content': newContent,
      });

      // Atualizar localmente
      final current = state.valueOrNull ?? [];
      final index = current.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        final updated = [...current];
        updated[index] = updated[index].copyWith(
          content: newContent,
          editedAt: DateTime.now(),
        );
        state = AsyncData(updated);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deletar mensagem para todos (autor, host ou co-host)
  Future<bool> deleteForAll(String messageId) async {
    try {
      await SupabaseService.rpc('delete_chat_message_for_all', params: {
        'p_message_id': messageId,
      });

      // Atualizar localmente — transformar em system_deleted
      final current = state.valueOrNull ?? [];
      final index = current.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        final updated = [...current];
        updated[index] = updated[index].copyWith(
          type: 'system_deleted',
          content: 'Mensagem apagada',
          isDeleted: true,
        );
        state = AsyncData(updated);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deletar mensagem apenas para o usuário atual
  Future<bool> deleteForMe(String messageId) async {
    try {
      await SupabaseService.rpc('delete_chat_message_for_me', params: {
        'p_message_id': messageId,
      });

      // Remover da lista local
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

  /// Deletar mensagem (legacy — redireciona para deleteForAll)
  Future<bool> deleteMessage(String messageId) async {
    return deleteForAll(messageId);
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
