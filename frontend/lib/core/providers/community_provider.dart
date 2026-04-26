import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/cache_service.dart';
import '../models/community_model.dart';

/// ============================================================================
/// CommunityProvider — State Management com AsyncNotifier para comunidades.
///
/// Estratégia de cache: Stale-While-Revalidate (SWR)
/// - Exibe dados do cache local (Hive) imediatamente ao abrir a tela
/// - Dispara revalidação em background via Future.microtask
/// - Atualiza o estado quando dados frescos chegam da rede
/// - keepAlive mantém o estado em memória entre navegações
/// ============================================================================

// ── My Communities ──
class MyCommunitiesNotifier extends AsyncNotifier<List<CommunityModel>> {
  @override
  Future<List<CommunityModel>> build() async {
    // Mantém o estado em memória entre navegações para evitar re-fetch
    ref.keepAlive();

    // SWR: exibe cache imediatamente e atualiza em background
    final cached = CacheService.getCachedMyCommunities();
    if (cached != null && cached.isNotEmpty) {
      Future.microtask(() async {
        try {
          final fresh = await _fetchMyCommunities();
          state = AsyncData(fresh);
        } catch (_) {}
      });
      return cached.map((e) => CommunityModel.fromJson(e)).toList();
    }

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
    final communities = list.map((e) {
      final c = e['communities'] as Map<String, dynamic>;
      return CommunityModel.fromJson(c);
    }).toList();

    // Persiste no cache para próxima abertura
    await CacheService.cacheMyCommunities(
      communities.map((c) => c.toJson()).toList(),
    );

    return communities;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchMyCommunities);
  }

  Future<bool> joinCommunity(String communityId) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return false;

      await SupabaseService.rpc('join_community', params: {
        'p_community_id': communityId,
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

      await SupabaseService.rpc('leave_community', params: {
        'p_community_id': communityId,
      });

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
    // SWR: exibe cache da listagem padrão imediatamente
    final cached = CacheService.getCachedCommunity('discover:default');
    if (cached != null) {
      final rawList = cached['list'];
      if (rawList is List && rawList.isNotEmpty) {
        final list = rawList
            .map((e) => CommunityModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        Future.microtask(() async {
          try {
            final fresh = await _fetch();
            state = AsyncData(fresh);
          } catch (_) {}
        });
        return list;
      }
    }
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
    final communities = list
        .map((e) => CommunityModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Persiste no cache apenas para a listagem padrão (sem filtros ativos)
    if (_searchQuery.isEmpty && _category.isEmpty) {
      await CacheService.cacheCommunity('discover:default', {
        'list': communities.map((c) => c.toJson()).toList(),
      });
    }

    return communities;
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
    // Mantém em memória entre navegações
    ref.keepAlive();

    // SWR: exibe cache imediatamente e revalida em background
    final cached = CacheService.getCachedCommunity(communityId);
    if (cached != null && !cached.containsKey('list')) {
      Future.microtask(() async {
        try {
          final res = await SupabaseService.table('communities')
              .select()
              .eq('id', communityId)
              .maybeSingle();
          if (res != null) {
            await CacheService.cacheCommunity(
                communityId, Map<String, dynamic>.from(res));
          }
        } catch (_) {}
      });
      return CommunityModel.fromJson(cached);
    }

    final res = await SupabaseService.table('communities')
        .select()
        .eq('id', communityId)
        .maybeSingle();

    if (res == null) return null;
    final map = Map<String, dynamic>.from(res);
    await CacheService.cacheCommunity(communityId, map);
    return CommunityModel.fromJson(map);
  },
);

// ── Community Members Count ──
final communityMemberCountProvider = FutureProvider.family<int, String>(
  (ref, communityId) async {
    ref.keepAlive();
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
    ref.keepAlive();
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
