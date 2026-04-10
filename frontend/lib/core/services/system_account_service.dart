import 'package:flutter/foundation.dart';

import 'supabase_service.dart';
import '../l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Serviço de System Accounts — encapsula fluxos sistêmicos que agora são
/// centralizados no backend via RPCs.
///
/// Mantém uma API simples para o Flutter enquanto evita mutações diretas em
/// `chat_threads`, `chat_messages` e `notifications` no cliente.
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

  /// Envia um broadcast comunitário por meio da RPC autoritativa do backend.
  static Future<void> sendCommunityBroadcast({
    required String communityId,
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    try {
      final normalizedContent = imageUrl != null && imageUrl.trim().isNotEmpty
          ? '$content\n\n$imageUrl'
          : content;

      final response = await SupabaseService.rpc(
        'send_broadcast',
        params: {
          'p_title': title,
          'p_content': normalizedContent,
          'p_scope': 'community',
          'p_community_id': communityId,
          'p_action_url': '/community/$communityId',
        },
      );

      final result = response is Map<String, dynamic>
          ? response
          : Map<String, dynamic>.from(response as Map);

      if (result['success'] != true) {
        final error = result['error'] as String? ?? 'unknown_error';
        throw Exception(error);
      }
    } catch (e) {
      debugPrint('[system_account_service] Falha ao enviar broadcast: $e');
      rethrow;
    }
  }

  /// Envia mensagem de boas-vindas via backend.
  static Future<void> sendWelcomeMessage({
    required String communityId,
    required String userId,
    required String communityName,
  }) async {
    try {
      final response = await SupabaseService.rpc(
        'send_system_notification',
        params: {
          'p_user_id': userId,
          'p_type': 'welcome',
          'p_title': 'Bem-vindo(a)!',
          'p_body': 'Bem-vindo(a) à comunidade $communityName! 🎉 '
              'Explore os posts, participe dos chats e faça check-in diário para ganhar moedas.',
          'p_community_id': communityId,
          'p_action_url': '/community/$communityId',
        },
      );

      final result = response is Map<String, dynamic>
          ? response
          : Map<String, dynamic>.from(response as Map);

      if (result['success'] != true) {
        final error = result['error'] as String? ?? 'unknown_error';
        throw Exception(error);
      }
    } catch (e) {
      debugPrint('[system_account_service] Erro ao enviar boas-vindas: $e');
    }
  }

  /// Envia notificação de ação de moderação via backend.
  static Future<void> sendModerationNotice({
    required String userId,
    required String action,
    required String reason,
    String? communityId,
    String? communityName,
    int? durationHours,
  }) async {
    try {
      final s = getStrings();
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

      final response = await SupabaseService.rpc(
        'send_system_notification',
        params: {
          'p_user_id': userId,
          'p_type': 'moderation',
          'p_title': s.moderationActionLower,
          'p_body': content,
          if (communityId != null) 'p_community_id': communityId,
          if (communityId != null) 'p_action_url': '/community/$communityId',
        },
      );

      final result = response is Map<String, dynamic>
          ? response
          : Map<String, dynamic>.from(response as Map);

      if (result['success'] != true) {
        final error = result['error'] as String? ?? 'unknown_error';
        throw Exception(error);
      }
    } catch (e) {
      debugPrint(
          '[system_account_service] Erro ao enviar aviso de moderação: $e');
    }
  }
}
