import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post_editor_model.dart';
import '../models/post_model.dart';
import '../services/supabase_service.dart';

/// ============================================================================
/// PostProvider — State Management com AsyncNotifier para posts/feed.
///
/// Gerencia:
/// - Feed de uma comunidade (paginado)
/// - Detalhes de um post
/// - Criar, editar, deletar post
/// - Like/Unlike
/// - Posts fixados e destaques
///
/// Agora também centraliza a superfície do editor unificado para criação e
/// edição rica, com suporte a variantes, metadados visuais e payloads avançados.
/// ============================================================================

const _kPostSelect =
    '*, profiles!posts_author_id_fkey(id, nickname, icon_url), '
    'original_author:profiles!posts_original_author_id_fkey(id, nickname, icon_url), '
    'original_post:original_post_id('
    'id, title, content, type, cover_image_url, media_list, created_at, '
    'author_id, community_id, original_post_id, post_variant, '
    'editor_metadata, editor_state, story_data, chat_data, wiki_data'
    ')';

Map<String, dynamic> _normalizePostMap(Map<String, dynamic> map) {
  if (map['profiles'] != null) {
    map['author'] = map['profiles'];
  }
  if (map['original_post'] != null) {
    final op = Map<String, dynamic>.from(map['original_post'] as Map);
    if (op['profiles'] != null) {
      op['author'] = op['profiles'];
    }
    map['original_post'] = op;
  }
  return map;
}

Future<List<Map<String, dynamic>>> _injectIsLiked(
  List<Map<String, dynamic>> posts,
) async {
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
  }

  return posts;
}

List<Map<String, dynamic>> _normalizeMediaList(dynamic rawMediaList) {
  if (rawMediaList is List) {
    return rawMediaList.map((item) {
      if (item is Map<String, dynamic>) {
        return Map<String, dynamic>.from(item);
      }
      if (item is Map) {
        return Map<String, dynamic>.from(item);
      }
      final url = item?.toString() ?? '';
      return {
        'url': url,
        'type': 'image',
      };
    }).where((item) => (item['url'] as String?)?.isNotEmpty == true).toList();
  }
  return const [];
}

List<Map<String, dynamic>> _extractPollOptions(Map<String, dynamic> postData) {
  final direct = postData['poll_options'];
  if (direct is List) {
    return direct
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  final pollData = postData['poll_data'];
  if (pollData is Map && pollData['options'] is List) {
    return (pollData['options'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  final editorMetadata = postData['editor_metadata'];
  if (editorMetadata is Map && editorMetadata['poll_options'] is List) {
    return (editorMetadata['poll_options'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  final metadataObject = postData['editorMetadata'];
  if (metadataObject is PostEditorModel) {
    return metadataObject.pollOptions
        .map((e) => e.toJson())
        .toList(growable: false);
  }

  return const [];
}

Map<String, dynamic> _normalizeEditorPayload(Map<String, dynamic> postData) {
  final editorMetadataObject = postData['editorMetadata'];
  final editorMetadataMap = editorMetadataObject is PostEditorModel
      ? editorMetadataObject.toJson()
      : Map<String, dynamic>.from(
          postData['editor_metadata'] as Map? ?? const {},
        );

  final editorType = (postData['editor_type'] ??
          postData['editorType'] ??
          editorMetadataMap['editor_type'] ??
          postData['post_variant'] ??
          postData['variant'] ??
          postData['type'] ??
          PostEditorType.normal)
      .toString();

  final variant = (postData['post_variant'] ??
          postData['variant'] ??
          editorMetadataMap['variant'])
      ?.toString();

  final mediaList = _normalizeMediaList(postData['media_list']);
  final coverImageUrl = (postData['cover_image_url'] ??
          postData['coverImageUrl'] ??
          editorMetadataMap['cover_style']?['cover_image_url'] ??
          (mediaList.isNotEmpty ? mediaList.first['url'] : null))
      ?.toString();

  final backgroundUrl = (postData['background_url'] ??
          postData['backgroundUrl'] ??
          editorMetadataMap['cover_style']?['background_image_url'])
      ?.toString();

  return {
    'title': postData['title'] ?? '',
    'content': postData['content'],
    'type': postData['type'] ?? 'normal',
    'media_list': mediaList,
    'category_id': postData['category_id'],
    'poll_options': _extractPollOptions(postData),
    'tags': List<String>.from(postData['tags'] as List? ?? const []),
    'cover_image_url': coverImageUrl,
    'background_url': backgroundUrl,
    'external_url': postData['external_url'] ?? postData['externalUrl'],
    'gif_url': postData['gif_url'],
    'music_url': postData['music_url'],
    'music_title': postData['music_title'],
    'visibility': postData['visibility'] ?? 'public',
    'comments_blocked': postData['comments_blocked'] ?? false,
    'original_post_id': postData['original_post_id'],
    'original_community_id': postData['original_community_id'],
    'content_blocks': postData['content_blocks'] ?? const [],
    'is_pinned_profile': postData['is_pinned_profile'] ?? false,
    'editor_type': editorType,
    'post_variant': variant,
    'editor_metadata': editorMetadataMap,
    'editor_state': postData['editor_state'],
    'story_data': postData['story_data'],
    'chat_data': postData['chat_data'],
    'wiki_data': postData['wiki_data'],
  };
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
        .select(_kPostSelect)
        .eq('community_id', communityId)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .range(page * _pageSize, (page + 1) * _pageSize - 1);

    final list = (res as List)
        .map((e) => _normalizePostMap(Map<String, dynamic>.from(e as Map)))
        .toList();

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
    } catch (_) {
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

      final payload = _normalizeEditorPayload(postData);

      await SupabaseService.rpc('create_post_with_reputation', params: {
        'p_community_id': arg,
        'p_title': payload['title'],
        'p_content': payload['content'],
        'p_type': payload['type'],
        'p_media_list': payload['media_list'],
        'p_category_id': payload['category_id'],
        'p_poll_options': payload['poll_options'],
        'p_tags': payload['tags'],
        'p_cover_image_url': payload['cover_image_url'],
        'p_background_url': payload['background_url'],
        'p_external_url': payload['external_url'],
        'p_gif_url': payload['gif_url'],
        'p_music_url': payload['music_url'],
        'p_music_title': payload['music_title'],
        'p_visibility': payload['visibility'],
        'p_comments_blocked': payload['comments_blocked'],
        'p_original_post_id': payload['original_post_id'],
        'p_original_community_id': payload['original_community_id'],
        'p_content_blocks': payload['content_blocks'],
        'p_is_pinned_profile': payload['is_pinned_profile'],
        'p_editor_type': payload['editor_type'],
        'p_post_variant': payload['post_variant'],
        'p_editor_metadata': payload['editor_metadata'],
        'p_editor_state': payload['editor_state'],
        'p_story_data': payload['story_data'],
        'p_chat_data': payload['chat_data'],
        'p_wiki_data': payload['wiki_data'],
      });

      await refresh();
      return true;
    } catch (e) {
      debugPrint('[post_provider] createPost error: $e');
      return false;
    }
  }

  Future<bool> editPost(String postId, Map<String, dynamic> postData) async {
    try {
      final payload = _normalizeEditorPayload(postData);

      await SupabaseService.rpc('edit_post', params: {
        'p_post_id': postId,
        'p_title': payload['title'],
        'p_content': payload['content'],
        'p_type': payload['type'],
        'p_media_list': payload['media_list'],
        'p_category_id': payload['category_id'],
        'p_poll_options': payload['poll_options'],
        'p_tags': payload['tags'],
        'p_cover_image_url': payload['cover_image_url'],
        'p_background_url': payload['background_url'],
        'p_external_url': payload['external_url'],
        'p_gif_url': payload['gif_url'],
        'p_music_url': payload['music_url'],
        'p_music_title': payload['music_title'],
        'p_visibility': payload['visibility'],
        'p_comments_blocked': payload['comments_blocked'],
        'p_content_blocks': payload['content_blocks'],
        'p_is_pinned_profile': payload['is_pinned_profile'],
        'p_editor_type': payload['editor_type'],
        'p_post_variant': payload['post_variant'],
        'p_editor_metadata': payload['editor_metadata'],
        'p_editor_state': payload['editor_state'],
        'p_story_data': payload['story_data'],
        'p_chat_data': payload['chat_data'],
        'p_wiki_data': payload['wiki_data'],
      });

      await refresh();
      return true;
    } catch (e) {
      debugPrint('[post_provider] editPost error: $e');
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
      debugPrint('[post_provider] deletePost error: $e');
      return false;
    }
  }

  Future<void> toggleLike(String postId) async {
    try {
      await SupabaseService.client.rpc('toggle_post_like', params: {
        'p_post_id': postId,
      });
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
      debugPrint('[post_provider] toggleLike error: $e');
    }
  }

  bool get hasMore => _hasMore;
}

final communityFeedProvider = AsyncNotifierProvider.family<
    CommunityFeedNotifier, List<PostModel>, String>(CommunityFeedNotifier.new);

final postDetailProvider = FutureProvider.family<PostModel?, String>(
  (ref, postId) async {
    final res = await SupabaseService.table('posts')
        .select(_kPostSelect)
        .eq('id', postId)
        .maybeSingle();

    if (res == null) return null;

    final map = _normalizePostMap(Map<String, dynamic>.from(res));
    await _injectIsLiked([map]);
    return PostModel.fromJson(map);
  },
);

final pinnedPostsProvider = FutureProvider.family<List<PostModel>, String>(
  (ref, communityId) async {
    final res = await SupabaseService.table('posts')
        .select(_kPostSelect)
        .eq('community_id', communityId)
        .eq('is_pinned', true)
        .eq('status', 'ok')
        .order('created_at', ascending: false)
        .limit(5);

    final list = (res as List)
        .map((e) => _normalizePostMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    await _injectIsLiked(list);
    return list.map((e) => PostModel.fromJson(e)).toList();
  },
);

final activeFeaturedPostsProvider = FutureProvider.family<List<PostModel>, String>(
  (ref, communityId) async {
    final now = DateTime.now().toUtc().toIso8601String();

    final res = await SupabaseService.table('posts')
        .select(_kPostSelect)
        .eq('community_id', communityId)
        .eq('is_featured', true)
        .eq('status', 'ok')
        .or('featured_until.is.null,featured_until.gt.$now')
        .order('featured_at', ascending: false)
        .limit(12);

    final list = (res as List)
        .map((e) => _normalizePostMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    await _injectIsLiked(list);

    final posts = list.map((e) => PostModel.fromJson(e)).toList();
    return posts.where((p) => p.isFeaturedActive).toList();
  },
);

final latestPostsProvider = FutureProvider.family<List<PostModel>, String>(
  (ref, communityId) async {
    final res = await SupabaseService.table('posts')
        .select(_kPostSelect)
        .eq('community_id', communityId)
        .eq('status', 'ok')
        .eq('is_pinned', false)
        .order('created_at', ascending: false)
        .limit(20);

    final list = (res as List)
        .map((e) => _normalizePostMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    await _injectIsLiked(list);
    return list.map((e) => PostModel.fromJson(e)).toList();
  },
);

final featuredPostsProvider = FutureProvider.family<List<PostModel>, String>(
  (ref, communityId) => ref.watch(activeFeaturedPostsProvider(communityId).future),
);
