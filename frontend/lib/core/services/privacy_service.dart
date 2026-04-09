import '../services/supabase_service.dart';
import '../l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Serviço de Privacy Levels — implementa os 3 níveis de privacidade do Amino.
///
/// **Nível 1 (Público):** Qualquer um pode ver perfil, posts, wall.
/// **Nível 2 (Semi-privado):** Apenas membros da mesma comunidade podem ver.
/// **Nível 3 (Privado):** Apenas amigos/seguidores aprovados podem ver.
///
/// Cada campo do perfil pode ter seu próprio nível de privacidade:
/// - online_status_level: quem vê se está online
/// - wall_level: quem pode postar no mural
/// - following_level: quem vê a lista de seguindo
/// - profile_level: quem vê o perfil completo
class PrivacyService {
  PrivacyService._();

  /// Verifica se o viewer tem permissão para ver o conteúdo do target.
  ///
  /// Retorna `true` se o viewer pode ver, `false` se não pode.
  static Future<bool> canView({
    required String targetUserId,
    required String field,
  }) async {
    try {
      final viewerId = SupabaseService.currentUserId;
      if (viewerId == null) return false;

      // Mesmo usuário sempre pode ver seus próprios dados
      if (viewerId == targetUserId) return true;

      final result =
          await SupabaseService.rpc('check_privacy_permission', params: {
        'p_viewer_id': viewerId,
        'p_target_user_id': targetUserId,
        'p_field': field,
      });

      return result == true;
    } catch (e) {
      // Em caso de erro, permitir acesso (fail-open para UX)
      return true;
    }
  }

  /// Busca as configurações de privacidade do usuário atual.
  static Future<Map<String, int>> getMyPrivacySettings() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return _defaultSettings;

      final res = await SupabaseService.table('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (res == null) return _defaultSettings;

      return {
        'profile_level': res['profile_level'] as int? ?? 1,
        'online_status_level': res['online_status_level'] as int? ?? 1,
        'wall_level': res['wall_level'] as int? ?? 1,
        'following_level': res['following_level'] as int? ?? 1,
        'chat_invite_level': res['chat_invite_level'] as int? ?? 1,
        'comment_level': res['comment_level'] as int? ?? 1,
      };
    } catch (e) {
      return _defaultSettings;
    }
  }

  /// Atualiza uma configuração de privacidade.
  static Future<void> updatePrivacySetting(String field, int level) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      await SupabaseService.table('user_settings').upsert({
        'user_id': userId,
        field: level,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Configurações padrão (tudo público).
  static const Map<String, int> _defaultSettings = {
    'profile_level': 1,
    'online_status_level': 1,
    'wall_level': 1,
    'following_level': 1,
    'chat_invite_level': 1,
    'comment_level': 1,
  };

  /// Labels para os níveis de privacidade.
  static String levelLabel(int level) {
    final s = getStrings();
    switch (level) {
      final s = getStrings();
      case 1:
        return s.publicLabel;
      case 2:
        return 'Membros da comunidade';
      case 3:
        return s.friendsOnly;
      default:
        return s.publicLabel;
    }
  }

  /// Ícones para os níveis de privacidade.
  static String levelIcon(int level) {
    switch (level) {
      case 1:
        return '🌐';
      case 2:
        return '👥';
      case 3:
        return '🔒';
      default:
        return '🌐';
    }
  }
}
