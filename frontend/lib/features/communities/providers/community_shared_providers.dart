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
///
/// Usa o horário do servidor (via RPC ou now() do Supabase) para determinar
/// se o check-in de hoje já foi feito, garantindo que o reset ocorra
/// exatamente à 00:00 UTC do servidor, independente do fuso do dispositivo.
final checkInStatusProvider =
    FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return {};

  // Buscar dados de check-in e o horário atual do servidor em paralelo
  final results = await Future.wait([
    SupabaseService.table('community_members')
        .select(
            'community_id, has_checkin_today, consecutive_checkin_days, last_checkin_at')
        .eq('user_id', userId)
        .eq('is_banned', false),
    // Pegar o horário do servidor via RPC simples (retorna timestamp UTC)
    _getServerTime(),
  ]);

  final rows = results[0] as List? ?? [];
  final serverNow = results[1] as DateTime;

  final Map<String, Map<String, dynamic>> result = {};
  for (final row in rows) {
    final communityId = (row['community_id'] as String?) ?? '';
    final lastCheckin = row['last_checkin_at'] as String?;

    // Comparar last_checkin_at com a data do servidor (não do cliente)
    bool checkedInToday = false;
    if (lastCheckin != null) {
      final lastDate = DateTime.parse(lastCheckin).toUtc();
      checkedInToday = lastDate.year == serverNow.year &&
          lastDate.month == serverNow.month &&
          lastDate.day == serverNow.day;
    }
    result[communityId] = {
      'has_checkin_today': checkedInToday,
      'consecutive_checkin_days': row['consecutive_checkin_days'] as int? ?? 0,
    };
  }
  return result;
});

/// Obtém o horário atual do servidor Supabase (UTC).
/// Usa uma query simples que retorna now() do PostgreSQL.
Future<DateTime> _getServerTime() async {
  try {
    // Tenta usar RPC get_server_time se existir
    final result = await SupabaseService.rpc('get_server_time');
    if (result is String) {
      return DateTime.parse(result).toUtc();
    }
    if (result is Map && result['now'] is String) {
      return DateTime.parse(result['now'] as String).toUtc();
    }
  } catch (_) {
    // Se a RPC não existir, faz fallback para DateTime.now().toUtc()
    // (menos preciso, mas funcional)
  }
  return DateTime.now().toUtc();
}

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
