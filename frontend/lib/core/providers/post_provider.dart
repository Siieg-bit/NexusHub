import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../models/post_model.dart';
import 'package:flutter/foundation.dart';

/// ============================================================================
/// PostProvider — State Management com AsyncNotifier para posts/feed.
///
/// Gerencia:
/// - Feed de uma comunidade (paginado)
/// - Detalhes de um post
/// - Criar, editar, deletar post
/// - Like/Unlike
/// - Featured posts
/// ============================================================================

class CommunityFeedNotifier
    extends FamilyAsyncNotifier<List<PostModel>, String> {
  int _page = 0;
  bool _hasMore = true;
  static const _pageSize = 20;

  @override
  Future<List<PostModel>> build(String communityId) async {
    _page = 0;
    _hasMore = true;
    return _fetchPage(communityId, 0);
  }

  Future<List<PostModel>> _fetchPage(String communityId, int page) async {
    final res = await SupabaseService.table('posts')
        .select('*, profiles!posts_author_id_fkey(nickname, icon_url)')
        .eq('community_id', communityId)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .range(page * _pageSize, (page + 1) * _pageSize - 1);

    final list = res as List;
    final posts =
        list.map((e) => PostModel.fromJson(e as Map<String, dynamic>)).toList();
    _hasMore = posts.length >= _pageSize;
    return posts;
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final current = state.valueOrNull ?? [];
    _page++;
    try {
      final more = await _fetchPage(arg, _page);
      state = AsyncData([...current, ...more]);
    } catch (e) {
      _page--;
    }
  }

  Future<void> refresh() async {
    _page = 0;
    _hasMore = true;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPage(arg, 0));
  }

  Future<bool> createPost(Map<String, dynamic> postData) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return false;

      await SupabaseService.table('posts').insert({
        ...postData,
        'community_id': arg,
        'author_id': userId,
      });

      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      await SupabaseService.table('posts').delete().eq('id', postId);
      final current = state.valueOrNull ?? [];
      state = AsyncData(current.where((p) => p.id != postId).toList());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> toggleLike(String postId) async {
    try {
      await SupabaseService.client.rpc('toggle_post_like', params: {
        'p_post_id': postId,
      });
      // Atualizar o post localmente usando copyWith
      final current = state.valueOrNull ?? [];
      final index = current.indexWhere((p) => p.id == postId);
      if (index >= 0) {
        final post = current[index];
        final updated = post.copyWith(
          likesCount: post.isLiked ? post.likesCount - 1 : post.likesCount + 1,
          isLiked: !post.isLiked,
        );
        final newList = [...current];
        newList[index] = updated;
        state = AsyncData(newList);
      }
    } catch (e) {
      debugPrint('[post_provider] Erro: $e');
    }
  }

  bool get hasMore => _hasMore;
}

final communityFeedProvider = AsyncNotifierProvider.family<
    CommunityFeedNotifier, List<PostModel>, String>(CommunityFeedNotifier.new);

// ── Post Detail ──
final postDetailProvider = FutureProvider.family<PostModel?, String>(
  (ref, postId) async {
    final res = await SupabaseService.table('posts')
        .select('*, profiles!posts_author_id_fkey(nickname, icon_url)')
        .eq('id', postId)
        .maybeSingle();

    if (res == null) return null;
    return PostModel.fromJson(res);
  },
);

// ── Featured Posts ──
final featuredPostsProvider = FutureProvider.family<List<PostModel>, String>(
  (ref, communityId) async {
    final res = await SupabaseService.table('posts')
        .select('*, profiles!posts_author_id_fkey(nickname, icon_url)')
        .eq('community_id', communityId)
        .eq('is_featured', true)
        .order('created_at', ascending: false)
        .limit(10);

    final list = res as List;
    return list
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);
