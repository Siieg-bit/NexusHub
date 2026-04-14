import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

/// Provider para gerenciar convites de DM.
final dmInviteProvider = Provider<DmInviteService>((ref) => DmInviteService());

/// Provider que lista os convites pendentes do usuário.
final pendingDmInvitesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final data = await SupabaseService.table('chat_members')
      .select('''
        id,
        thread_id,
        status,
        joined_at,
        chat_threads!inner (
          id,
          type,
          host_id,
          last_message_preview,
          last_message_author,
          created_at
        )
      ''')
      .eq('user_id', userId)
      .eq('status', 'invite_sent')
      .order('joined_at', ascending: false);

  return (data as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

class DmInviteService {
  /// Enviar convite de DM para um usuário.
  /// Retorna o thread_id criado ou existente.
  ///
  /// [communityId] quando fornecido, garante que o DM criado/encontrado
  /// pertence ao escopo daquela comunidade, evitando redirecionar para
  /// chats de outras comunidades.
  Future<String?> sendInvite(String targetUserId,
      {String? initialMessage, String? communityId}) async {
    try {
      final result = await SupabaseService.rpc('send_dm_invite', params: {
        'p_target_user_id': targetUserId,
        if (initialMessage != null) 'p_initial_message': initialMessage,
        if (communityId != null && communityId.isNotEmpty)
          'p_community_id': communityId,
      });
      return result as String?;
    } catch (e) {
      rethrow;
    }
  }

  /// Aceitar um convite de DM.
  Future<bool> acceptInvite(String threadId) async {
    try {
      await SupabaseService.rpc('respond_dm_invite', params: {
        'p_thread_id': threadId,
        'p_accept': true,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Recusar um convite de DM.
  Future<bool> declineInvite(String threadId) async {
    try {
      await SupabaseService.rpc('respond_dm_invite', params: {
        'p_thread_id': threadId,
        'p_accept': false,
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
