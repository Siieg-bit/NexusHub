import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// =============================================================================
// Modelo: FavoriteMember
// =============================================================================
class FavoriteMember {
  final String targetUserId;
  final int sortPosition;
  final String nickname;
  final String? iconUrl;

  const FavoriteMember({
    required this.targetUserId,
    required this.sortPosition,
    required this.nickname,
    this.iconUrl,
  });

  factory FavoriteMember.fromJson(Map<String, dynamic> json) {
    return FavoriteMember(
      targetUserId: json['target_user_id'] as String,
      sortPosition: (json['sort_position'] as num?)?.toInt() ?? 0,
      nickname: (json['nickname'] as String?)?.trim().isNotEmpty == true
          ? json['nickname'] as String
          : (json['global_nickname'] as String?) ?? 'Membro',
      iconUrl: (json['icon_url'] as String?)?.trim().isNotEmpty == true
          ? json['icon_url'] as String
          : json['global_icon_url'] as String?,
    );
  }
}

// =============================================================================
// Provider: favoriteMembersProvider
// Chave: communityId (String)
// Usa o RPC get_favorite_members — sem leitura direta de tabela.
// =============================================================================
final favoriteMembersProvider =
    AsyncNotifierProvider.family<FavoriteMembersNotifier,
        List<FavoriteMember>, String>(
  FavoriteMembersNotifier.new,
);

class FavoriteMembersNotifier
    extends FamilyAsyncNotifier<List<FavoriteMember>, String> {
  String get _communityId => arg;

  @override
  Future<List<FavoriteMember>> build(String arg) async {
    return _fetch();
  }

  Future<List<FavoriteMember>> _fetch() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    try {
      final result = await SupabaseService.rpc(
        'get_favorite_members',
        params: {'p_community_id': _communityId},
      );
      final rows = List<Map<String, dynamic>>.from(result as List? ?? []);
      return rows.map(FavoriteMember.fromJson).toList();
    } catch (e, st) {
      debugPrint('[FavoriteMembersProvider] fetch error: $e\n$st');
      return [];
    }
  }

  // ── Adicionar favorito ─────────────────────────────────────────────────────
  Future<({bool success, String? error})> add(String targetUserId) async {
    try {
      final result = await SupabaseService.rpc(
        'add_favorite_member',
        params: {
          'p_community_id':   _communityId,
          'p_target_user_id': targetUserId,
        },
      );
      final data = result as Map<String, dynamic>? ?? {};
      if (data['success'] == true) {
        // Recarregar lista
        state = AsyncData(await _fetch());
        return (success: true, error: null);
      }
      return (success: false, error: data['error'] as String?);
    } catch (e) {
      debugPrint('[FavoriteMembersProvider] add error: $e');
      return (success: false, error: 'exception');
    }
  }

  // ── Remover favorito ───────────────────────────────────────────────────────
  Future<bool> remove(String targetUserId) async {
    try {
      await SupabaseService.rpc(
        'remove_favorite_member',
        params: {
          'p_community_id':   _communityId,
          'p_target_user_id': targetUserId,
        },
      );
      state = AsyncData(await _fetch());
      return true;
    } catch (e) {
      debugPrint('[FavoriteMembersProvider] remove error: $e');
      return false;
    }
  }

  // ── Verificar se um usuário já é favorito ──────────────────────────────────
  bool isFavorite(String targetUserId) {
    return state.valueOrNull?.any((f) => f.targetUserId == targetUserId) ??
        false;
  }

  // ── Forçar reload ──────────────────────────────────────────────────────────
  Future<void> reload() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetch());
  }
}
