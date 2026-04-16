import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

/// Provider para gerenciar convites de DM.
final dmInviteProvider = Provider<DmInviteService>((ref) => DmInviteService());

/// Provider que lista os convites pendentes do usuário.
final pendingDmInvitesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  String? normalizedString(dynamic value) {
    final text = value as String?;
    if (text == null) return null;
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

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
          community_id,
          last_message_preview,
          last_message_author,
          created_at
        )
      ''')
      .eq('user_id', userId)
      .eq('status', 'invite_sent')
      .order('joined_at', ascending: false);

  final invites = (data as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  final threadIds = invites
      .map((e) => normalizedString(e['thread_id']))
      .whereType<String>()
      .toList();

  if (threadIds.isEmpty) return invites;

  try {
    final members = await SupabaseService.table('chat_members').select(
        'thread_id, user_id, profiles!chat_members_user_id_fkey(id, nickname, icon_url, banner_url)')
      .inFilter('thread_id', threadIds)
      .neq('user_id', userId);

    final memberRows = (members as List? ?? [])
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    final counterpartUserIds = memberRows
        .map((row) => normalizedString(row['user_id']))
        .whereType<String>()
        .toSet();

    final communityIds = invites
        .map((invite) => normalizedString(
            (invite['chat_threads'] as Map<String, dynamic>?)?['community_id']))
        .whereType<String>()
        .toSet();

    final Map<String, Map<String, dynamic>> localMemberships = {};
    if (counterpartUserIds.isNotEmpty && communityIds.isNotEmpty) {
      final memberships = await SupabaseService.table('community_members').select(
          'community_id, user_id, local_nickname, local_icon_url, local_banner_url')
        .inFilter('community_id', communityIds.toList())
        .inFilter('user_id', counterpartUserIds.toList());

      for (final row in (memberships as List? ?? [])) {
        final membership = Map<String, dynamic>.from(row as Map);
        final communityId = normalizedString(membership['community_id']);
        final memberUserId = normalizedString(membership['user_id']);
        if (communityId == null || memberUserId == null) continue;
        localMemberships['$communityId:$memberUserId'] = membership;
      }
    }

    final counterpartsByThread = <String, Map<String, dynamic>>{};
    for (final row in memberRows) {
      final threadId = normalizedString(row['thread_id']);
      final counterpartUserId = normalizedString(row['user_id']);
      final rawProfile = row['profiles'];
      if (threadId == null || counterpartUserId == null || rawProfile == null) {
        continue;
      }

      final profile = rawProfile is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawProfile)
          : Map<String, dynamic>.from(rawProfile as Map);
      profile['user_id'] = counterpartUserId;

      final invite = invites.cast<Map<String, dynamic>?>().firstWhere(
            (item) => normalizedString(item?['thread_id']) == threadId,
            orElse: () => null,
          );
      final communityId = normalizedString(
          (invite?['chat_threads'] as Map<String, dynamic>?)?['community_id']);
      final membership = communityId == null
          ? null
          : localMemberships['$communityId:$counterpartUserId'];

      if (membership != null) {
        profile['nickname'] = normalizedString(membership['local_nickname']);
        profile['icon_url'] = normalizedString(membership['local_icon_url']);
        profile['banner_url'] = normalizedString(membership['local_banner_url']);
      }

      counterpartsByThread[threadId] = profile;
    }

    for (final invite in invites) {
      final threadId = normalizedString(invite['thread_id']);
      final counterpart = threadId == null ? null : counterpartsByThread[threadId];
      if (counterpart == null) continue;
      invite['sender_profile'] = counterpart;
      invite['sender_id'] = counterpart['id'] ?? counterpart['user_id'];
    }
  } catch (_) {}

  return invites;
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
