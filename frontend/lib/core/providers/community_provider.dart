import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/community_model.dart';
import '../../features/auth/providers/auth_provider.dart';

/// ============================================================================
/// CommunityProvider — State Management com AsyncNotifier para comunidades.
///
/// Gerencia:
/// - Lista de comunidades do usuário (My Communities)
/// - Lista de comunidades do Discover
/// - Detalhes de uma comunidade
/// - Join/Leave
/// - Busca
/// ============================================================================

// ── My Communities ──
class MyCommunitiesNotifier extends AsyncNotifier<List<CommunityModel>> {
  @override
  Future<List<CommunityModel>> build() async {
    return _fetchMyCommunities();
  }

  Future<List<CommunityModel>> _fetchMyCommunities() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    final res = await SupabaseService.table('community_members')
        .select('community_id, communities!inner(*)')
        .eq('user_id', userId)
        .order('joined_at', ascending: false);

    final list = res as List;
    return list.map((e) {
      final c = e['communities'] as Map<String, dynamic>;
      return CommunityModel.fromJson(c);
    }).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchMyCommunities);
  }

  Future<bool> joinCommunity(String communityId) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return false;

      // Usa currentUserProvider (já em memória) para copiar o perfil global
      // como ponto de partida do perfil local da comunidade.
      // Após o join, o usuário pode editar livremente o perfil local
      // sem nenhuma sincronização com o global.
      final currentUser = ref.read(currentUserProvider);

      await SupabaseService.table('community_members').insert({
        'community_id': communityId,
        'user_id': userId,
        'role': 'member',
        'local_nickname': currentUser?.nickname,
        'local_bio': currentUser?.bio,
        'local_icon_url': currentUser?.iconUrl,
        'local_banner_url': currentUser?.bannerUrl,
      });

      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> leaveCommunity(String communityId) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return false;

      await SupabaseService.table('community_members')
          .delete()
          .eq('community_id', communityId)
          .eq('user_id', userId);

      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final myCommunitiesProvider =
    AsyncNotifierProvider<MyCommunitiesNotifier, List<CommunityModel>>(
        MyCommunitiesNotifier.new);

// ── Discover Communities ──
class DiscoverCommunitiesNotifier extends AsyncNotifier<List<CommunityModel>> {
  String _searchQuery = '';
  String _category = '';

  @override
  Future<List<CommunityModel>> build() async {
    return _fetch();
  }

  Future<List<CommunityModel>> _fetch() async {
    var query = SupabaseService.table('communities').select();

    if (_category.isNotEmpty) {
      query = query.contains('tags', [_category]);
    }

    if (_searchQuery.isNotEmpty) {
      query = query.ilike('name', '%$_searchQuery%');
    }

    final res = await query.order('member_count', ascending: false).limit(50);

    final list = res as List;
    return list
        .map((e) => CommunityModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> filterByCategory(String category) async {
    _category = category;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final discoverCommunitiesProvider =
    AsyncNotifierProvider<DiscoverCommunitiesNotifier, List<CommunityModel>>(
        DiscoverCommunitiesNotifier.new);

// ── Community Detail ──
final communityDetailProvider = FutureProvider.family<CommunityModel?, String>(
  (ref, communityId) async {
    final res = await SupabaseService.table('communities')
        .select()
        .eq('id', communityId)
        .maybeSingle();

    if (res == null) return null;
    return CommunityModel.fromJson(res);
  },
);

// ── Community Members Count ──
final communityMemberCountProvider = FutureProvider.family<int, String>(
  (ref, communityId) async {
    final res = await SupabaseService.table('community_members')
        .select()
        .eq('community_id', communityId)
        .count(CountOption.exact);

    return res.count;
  },
);

// ── Is Member ──
final isMemberProvider = FutureProvider.family<bool, String>(
  (ref, communityId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;

    final res = await SupabaseService.table('community_members')
        .select()
        .eq('community_id', communityId)
        .eq('user_id', userId)
        .maybeSingle();

    return res != null;
  },
);
