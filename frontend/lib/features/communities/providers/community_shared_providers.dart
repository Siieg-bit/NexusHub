import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';

// =============================================================================
// PROVIDERS COMPARTILHADOS — Comunidades
//
// Extraídos de community_list_screen.dart para eliminar acoplamento circular.
// Qualquer tela/widget que precise de userCommunities ou checkInStatus deve
// importar este arquivo, não a tela.
// =============================================================================

/// Provider para comunidades do usuário.
final userCommunitiesProvider =
    FutureProvider<List<CommunityModel>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final response = await SupabaseService.table('community_members')
      .select('community_id, communities(*)')
      .eq('user_id', userId)
      .eq('is_banned', false)
      .order('joined_at', ascending: false);

  return (response as List? ?? [])
      .where((e) => e['communities'] != null)
      .map((e) =>
          CommunityModel.fromJson(e['communities'] as Map<String, dynamic>))
      .toList();
});

/// Provider para status de check-in de todas as comunidades do usuário.
/// Retorna Map<communityId, {has_checkin_today, consecutive_checkin_days}>.
final checkInStatusProvider =
    FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return {};

  final response = await SupabaseService.table('community_members')
      .select(
          'community_id, has_checkin_today, consecutive_checkin_days, last_checkin_at')
      .eq('user_id', userId)
      .eq('is_banned', false);

  final Map<String, Map<String, dynamic>> result = {};
  for (final row in ((response as List? ?? []))) {
    final communityId = (row['community_id'] as String?) ?? '';
    final lastCheckin = row['last_checkin_at'] as String?;
    // Derivar has_checkin_today comparando last_checkin_at com data UTC atual.
    // O campo has_checkin_today pode estar stale se não há cron de reset,
    // então usamos last_checkin_at como fonte de verdade.
    bool checkedInToday = false;
    if (lastCheckin != null) {
      final lastDate = DateTime.parse(lastCheckin).toUtc();
      final nowUtc = DateTime.now().toUtc();
      checkedInToday = lastDate.year == nowUtc.year &&
          lastDate.month == nowUtc.month &&
          lastDate.day == nowUtc.day;
    }
    result[communityId] = {
      'has_checkin_today': checkedInToday,
      'consecutive_checkin_days': row['consecutive_checkin_days'] as int? ?? 0,
    };
  }
  return result;
});

/// Provider para comunidades sugeridas.
final suggestedCommunitiesProvider =
    FutureProvider<List<CommunityModel>>((ref) async {
  final response = await SupabaseService.table('communities')
      .select()
      .eq('is_active', true)
      .eq('is_searchable', true)
      .order('members_count', ascending: false)
      .limit(50);

  return (response as List? ?? [])
      .map((e) => CommunityModel.fromJson(e as Map<String, dynamic>))
      .toList();
});
