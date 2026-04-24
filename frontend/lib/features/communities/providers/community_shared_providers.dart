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
///
/// Bug corrigido: o campo [consecutive_checkin_days] no banco só é atualizado
/// quando o usuário faz check-in. Se o usuário ficou dias sem entrar, o valor
/// armazenado ainda reflete o streak anterior — que tecnicamente está quebrado.
/// A correção calcula o "streak efetivo" no cliente:
///   - Se o último check-in foi hoje → streak = valor do banco (válido).
///   - Se o último check-in foi ontem → streak = valor do banco (ainda válido,
///     o usuário pode fazer check-in hoje para continuar).
///   - Se o último check-in foi há 2+ dias → streak = 0 (quebrado).
/// Isso garante que a barra de streak exiba 0 imediatamente ao abrir o app
/// após dias de ausência, sem precisar esperar o próximo check-in.
final checkInStatusProvider =
    FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return {};

  // Buscar dados de check-in e o horário atual do servidor em paralelo
  final results = await Future.wait<dynamic>([
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
  // Data de hoje no fuso de Brasília (UTC-3), que é o fuso operacional do app
  final brasiliaOffset = const Duration(hours: -3);
  final serverBrasilia = serverNow.toUtc().add(brasiliaOffset);
  final todayBrasilia = DateTime(
    serverBrasilia.year,
    serverBrasilia.month,
    serverBrasilia.day,
  );

  final Map<String, Map<String, dynamic>> result = {};
  for (final row in rows) {
    final communityId = (row['community_id'] as String?) ?? '';
    final lastCheckinRaw = row['last_checkin_at'] as String?;
    final storedStreak = row['consecutive_checkin_days'] as int? ?? 0;

    bool checkedInToday = false;
    int effectiveStreak = storedStreak;

    if (lastCheckinRaw != null) {
      // Converter last_checkin_at para o fuso de Brasília para comparação
      final lastCheckinUtc = DateTime.parse(lastCheckinRaw).toUtc();
      final lastCheckinBrasilia = lastCheckinUtc.add(brasiliaOffset);
      final lastCheckinDay = DateTime(
        lastCheckinBrasilia.year,
        lastCheckinBrasilia.month,
        lastCheckinBrasilia.day,
      );

      final daysDiff = todayBrasilia.difference(lastCheckinDay).inDays;

      // Check-in feito hoje
      checkedInToday = daysDiff == 0;

      // Calcular streak efetivo:
      // - daysDiff == 0: check-in hoje → streak válido (banco está correto)
      // - daysDiff == 1: check-in ontem → streak ainda válido (pode continuar hoje)
      // - daysDiff >= 2: ficou 2+ dias sem entrar → streak quebrado, exibir 0
      if (daysDiff >= 2) {
        effectiveStreak = 0;
      }
    } else {
      // Nunca fez check-in nesta comunidade
      effectiveStreak = 0;
    }

    result[communityId] = {
      'has_checkin_today': checkedInToday,
      'consecutive_checkin_days': effectiveStreak,
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
