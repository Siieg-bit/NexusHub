import 'supabase_service.dart';
import 'package:flutter/foundation.dart';

/// Serviço de System Accounts — gerencia contas de sistema para broadcasts.
///
/// System accounts são contas especiais que enviam mensagens oficiais,
/// notificações de moderação, e anúncios da comunidade.
///
/// Tipos de system accounts:
/// - **NexusHub Official**: Anúncios globais do app
/// - **Community Bot**: Mensagens automáticas da comunidade
/// - **Moderation Bot**: Notificações de ações de moderação
/// - **Welcome Bot**: Mensagens de boas-vindas para novos membros
class SystemAccountService {
  SystemAccountService._();

  /// ID fixo do system account global (definido no seed do banco).
  static const String globalSystemId = '00000000-0000-0000-0000-000000000000';

  /// Verifica se um userId é uma system account.
  static Future<bool> isSystemAccount(String userId) async {
    try {
      final res = await SupabaseService.table('profiles')
          .select('is_system_account')
          .eq('id', userId)
          .maybeSingle();
      return res?['is_system_account'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Envia uma mensagem de broadcast para todos os membros de uma comunidade.
  ///
  /// Apenas system accounts e admins podem enviar broadcasts.
  static Future<void> sendCommunityBroadcast({
    required String communityId,
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    try {
      // Buscar o chat "announcements" da comunidade
      final chat = await SupabaseService.table('chat_threads')
          .select('id')
          .eq('community_id', communityId)
          .eq('type', 'announcements')
          .maybeSingle();

      String chatId;
      if (chat != null) {
        chatId = chat['id'] as String? ?? '';
      } else {
        // Criar chat de anúncios se não existir
        final newChat = await SupabaseService.table('chat_threads')
            .insert({
              'community_id': communityId,
              'title': 'Anúncios',
              'type': 'announcements',
              'host_id': globalSystemId,
            })
            .select('id')
            .single();
        chatId = newChat['id'] as String? ?? '';
      }

      // Enviar mensagem de broadcast
      await SupabaseService.table('chat_messages').insert({
        'thread_id': chatId,
        'author_id': globalSystemId,
        'content': '📢 **$title**\n\n$content',
        'type': 'system_announcement',
        'metadata': {
          'title': title,
          'image_url': imageUrl,
          'is_broadcast': true,
        },
      });

      // Criar notificações para todos os membros
      final members = await SupabaseService.table('community_members')
          .select('user_id')
          .eq('community_id', communityId);

      final notifications = (members as List? ?? [])
          .map((m) => {
                'user_id': m['user_id'],
                'type': 'broadcast',
                'title': 'Broadcast',
                'body': title,
                'community_id': communityId,
              })
          .toList();

      if (notifications.isNotEmpty) {
        // Inserir em lotes de 100
        for (var i = 0; i < notifications.length; i += 100) {
          final batch = notifications.sublist(
            i,
            i + 100 > notifications.length ? notifications.length : i + 100,
          );
          await SupabaseService.table('notifications').insert(batch);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Envia mensagem de boas-vindas para um novo membro.
  static Future<void> sendWelcomeMessage({
    required String communityId,
    required String userId,
    required String communityName,
  }) async {
    try {
      await SupabaseService.table('notifications').insert({
        'user_id': userId,
        'type': 'welcome',
        'title': 'Bem-vindo(a)!',
        'body': 'Bem-vindo(a) à comunidade $communityName! 🎉 '
            'Explore os posts, participe dos chats e faça check-in diário para ganhar moedas.',
        'community_id': communityId,
      });
    } catch (e) {
      debugPrint('[system_account_service] Erro: $e');
    }
  }

  /// Envia notificação de ação de moderação.
  static Future<void> sendModerationNotice({
    required String userId,
    required String action,
    required String reason,
    String? communityName,
    int? durationHours,
  }) async {
    try {
      String content;
      switch (action) {
        case 'warn':
          content = '⚠️ Você recebeu um aviso'
              '${communityName != null ? ' em $communityName' : ''}: $reason';
          break;
        case 'mute':
          content = '🔇 Você foi silenciado'
              '${communityName != null ? ' em $communityName' : ''}'
              '${durationHours != null ? ' por ${durationHours}h' : ''}: $reason';
          break;
        case 'ban':
          content = '🚫 Você foi banido'
              '${communityName != null ? ' de $communityName' : ''}'
              '${durationHours != null ? ' por ${durationHours}h' : ' permanentemente'}: $reason';
          break;
        case 'strike':
          content = '⛔ Você recebeu um strike'
              '${communityName != null ? ' em $communityName' : ''}: $reason';
          break;
        default:
          content = 'Ação de moderação: $action - $reason';
      }

      await SupabaseService.table('notifications').insert({
        'user_id': userId,
        'type': 'moderation',
        'title': 'Ação de moderação',
        'body': content,
      });
    } catch (e) {
      debugPrint('[system_account_service] Erro: $e');
    }
  }
}
