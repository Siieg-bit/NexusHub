import 'supabase_service.dart';

/// Serviço utilitário para garantir que o perfil local do usuário dentro de uma
/// comunidade foi inicializado a partir do perfil global exatamente uma vez.
///
/// Depois que o backend marca `local_profile_initialized = true`, nenhuma tela
/// deve tentar reidratar o perfil local a partir de `profiles`.
class CommunityProfileService {
  const CommunityProfileService._();

  static Future<bool> ensureMyCommunityProfile(String communityId) async {
    try {
      final result = await SupabaseService.client.rpc(
        'ensure_my_community_profile',
        params: {'p_community_id': communityId},
      );

      if (result is Map<String, dynamic>) {
        return result['success'] == true;
      }
      if (result is Map) {
        return result['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
