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
/// - Pinned posts (is_pinned = true)
/// - Featured posts ativos (is_featured = true AND featured_until > now())
///
/// IMPORTANTE: Todos os providers injetam `is_liked` consultando a
/// tabela `likes` para o usuário atual, garantindo persistência visual.
/// ============================================================================

/// Helper: dado uma lista de maps de posts, consulta a tabela likes
/// para o usuário atual e injeta `is_liked` em cada map.
Future<List<Map<String, dynamic>>> _injectIsLiked(
    List<Map<String, dynamic>> posts) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null || posts.isEmpty) return posts;

  final postIds = posts.map((p) => p['id'] as String).toList();

  try {
    final likesRes = await SupabaseService.table('likes')
        .select('post_id')
        .eq('user_id', userId)
        .inFilter('post_id', postIds);

    final likedPostIds =
        (likesRes as List).map((e) => e['post_id'] as String).toSet();

    for (final post in posts) {
      post['is_liked'] = likedPostIds.contains(post['id']);
    }
  } catch (e) {
    debugPrint('[post_provider] _injectIsLiked error: $e');
    // Fallback: manter is_liked como false (default do PostModel)
  }

  return posts;
}

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
        .select('*, profiles!posts_author_id_fkey(id, nickname, icon_url)')
        .eq('community_id', communityId)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .range(page * _pageSize, (page + 1) * _pageSize - 1);

    final list =
        (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    // Injetar is_liked para o usuário atual
    await _injectIsLiked(list);

    final posts = list.map((e) => PostModel.fromJson(e)).toList();
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

      // Usa RPC server-side para validação, reputação e atomicidade
      await SupabaseService.rpc('create_post_with_reputation', params: {
        'p_community_id': arg,
        'p_title': postData['title'] ?? '',
        'p_content': postData['content'],
        'p_type': postData['type'] ?? 'normal',
        'p_media_list': postData['media_list'] ?? [],
        'p_cover_image_url': postData['cover_image_url'],
        'p_background_url': postData['background_url'],
        'p_external_url': postData['external_url'],
        'p_gif_url': postData['gif_url'],
        'p_music_url': postData['music_url'],
        'p_music_title': postData['music_title'],
        'p_visibility': postData['visibility'] ?? 'public',
        'p_comments_blocked': postData['comments_blocked'] ?? false,
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
        .select('*, profiles!posts_author_id_fkey(id, nickname, icon_url)')
        .eq('id', postId)
        .maybeSingle();

    if (res == null) return null;

    final map = Map<String, dynamic>.from(res);
    // Injetar is_liked
    await _injectIsLiked([map]);
    return PostModel.fromJson(map);
  },
);

// ── Pinned Posts (posts fixados no topo da aba Destaque) ──
final pinnedPostsProvider = FutureProvider.family<List<PostModel>, String>(
  (ref, communityId) async {
    final res = await SupabaseService.table('posts')
        .select('*, profiles!posts_author_id_fkey(id, nickname, icon_url)')
        .eq('community_id', communityId)
        .eq('is_pinned', true)
        .eq('status', 'ok')
        .order('created_at', ascending: false)
        .limit(5);

    final list =
        (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    await _injectIsLiked(list);
    return list.map((e) => PostModel.fromJson(e)).toList();
  },
);

// ── Featured Posts ativos (is_featured=true e não expirados) ──
final activeFeaturedPostsProvider =
    FutureProvider.family<List<PostModel>, String>(
  (ref, communityId) async {
    final now = DateTime.now().toUtc().toIso8601String();

    // Busca posts com is_featured=true onde featured_until é NULL (sem expiração)
    // OU featured_until > agora (ainda dentro do prazo)
    final res = await SupabaseService.table('posts')
        .select('*, profiles!posts_author_id_fkey(id, nickname, icon_url)')
        .eq('community_id', communityId)
        .eq('is_featured', true)
        .eq('status', 'ok')
        .or('featured_until.is.null,featured_until.gt.$now')
        .order('featured_at', ascending: false)
        .limit(12);

    final list =
        (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    await _injectIsLiked(list);

    // Filtro extra no cliente para garantir (caso o Supabase não suporte o .or corretamente)
    final posts = list.map((e) => PostModel.fromJson(e)).toList();
    return posts.where((p) => p.isFeaturedActive).toList();
  },
);

// ── Latest Posts (posts recentes, excluindo fixados e destaques) ──
final latestPostsProvider = FutureProvider.family<List<PostModel>, String>(
  (ref, communityId) async {
    final res = await SupabaseService.table('posts')
        .select('*, profiles!posts_author_id_fkey(id, nickname, icon_url)')
        .eq('community_id', communityId)
        .eq('status', 'ok')
        .eq('is_pinned', false)
        .order('created_at', ascending: false)
        .limit(20);

    final list =
        (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    await _injectIsLiked(list);
    return list.map((e) => PostModel.fromJson(e)).toList();
  },
);

// ── Featured Posts (legado — mantido para compatibilidade) ──
final featuredPostsProvider = FutureProvider.family<List<PostModel>, String>(
  (ref, communityId) =>
      ref.watch(activeFeaturedPostsProvider(communityId).future),
);
