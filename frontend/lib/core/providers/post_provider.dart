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
    'author_id, community_id, original_post_id, editor_type, post_variant, '
    'editor_metadata, editor_state, story_data, chat_data, wiki_data, '
    'profiles!posts_author_id_fkey(id, nickname, icon_url)'
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

bool _hasAuthorAvatar(Map<String, dynamic> map) {
  final author = map['author'];
  if (author is Map) {
    final iconUrl = author['icon_url']?.toString().trim() ?? '';
    if (iconUrl.isNotEmpty) return true;
  }

  final localIconUrl = map['author_local_icon_url']?.toString().trim() ?? '';
  return localIconUrl.isNotEmpty;
}

void _mergeResolvedAuthor(
  Map<String, dynamic> map,
  Map<String, dynamic> author,
) {
  map['profiles'] = author;
  map['author'] = author;
}

void _applyLocalAuthorData(
  Map<String, dynamic> map,
  Map<String, dynamic> member,
) {
  final localNickname = member['local_nickname']?.toString().trim();
  final localIconUrl = member['local_icon_url']?.toString().trim();
  final localBannerUrl = member['local_banner_url']?.toString().trim();

  map['author_local_nickname'] = localNickname;
  map['author_local_icon_url'] = localIconUrl;
  map['author_local_banner_url'] = localBannerUrl;
  map['author_local_level'] ??= member['local_level'];

  final currentAuthor = Map<String, dynamic>.from(
    (map['author'] ?? map['profiles'] ?? const <String, dynamic>{}) as Map,
  );
  currentAuthor['nickname'] = localNickname;
  currentAuthor['icon_url'] = localIconUrl;
  currentAuthor['banner_url'] = localBannerUrl;

  _mergeResolvedAuthor(map, currentAuthor);
}

Future<void> _enrichAuthorData(Map<String, dynamic> map) async {
  final authorId = map['author_id']?.toString();
  if (authorId == null || authorId.isEmpty) return;

  try {
    if (!_hasAuthorAvatar(map)) {
      final profile = await SupabaseService.table('profiles')
          .select('id, nickname, icon_url')
          .eq('id', authorId)
          .maybeSingle();

      if (profile != null) {
        final mergedAuthor = {
          ...(map['author'] is Map
              ? Map<String, dynamic>.from(map['author'] as Map)
              : <String, dynamic>{}),
          ...Map<String, dynamic>.from(profile),
        };
        _mergeResolvedAuthor(map, mergedAuthor);
      }
    }
  } catch (e) {
    debugPrint('[post_provider] _enrichAuthorData profile fallback error: $e');
  }

  final communityId = map['community_id']?.toString();
  if (communityId == null || communityId.isEmpty) return;

  try {
    final member = await SupabaseService.table('community_members')
        .select('local_nickname, local_icon_url, local_banner_url, local_level')
        .eq('community_id', communityId)
        .eq('user_id', authorId)
        .maybeSingle();

    if (member != null) {
      _applyLocalAuthorData(map, Map<String, dynamic>.from(member));
    }
  } catch (e) {
    debugPrint('[post_provider] _enrichAuthorData member fallback error: $e');
  }

  final originalPostRaw = map['original_post'];
  if (originalPostRaw is Map) {
    final originalPost = Map<String, dynamic>.from(originalPostRaw);
    await _enrichAuthorData(originalPost);
    map['original_post'] = originalPost;

    final originalAuthorRaw = originalPost['author'] ?? originalPost['profiles'];
    if (originalAuthorRaw is Map) {
      map['original_author'] = Map<String, dynamic>.from(originalAuthorRaw);
    }
  }
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
    debugPrint('[post_provider] _injectIsLiked error: \$e');
  }

  // Injetar user_vote para enquetes
  try {
    final pollPostIds = posts
        .where((p) => p['type'] == 'poll')
        .map((p) => p['id'] as String)
        .toList();
    if (pollPostIds.isNotEmpty) {
      // Buscar as opções de cada post de enquete
      final optionsRaw = await SupabaseService.table('poll_options')
          .select('id, post_id')
          .inFilter('post_id', pollPostIds);
      final optionsList = (optionsRaw as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final allOptionIds = optionsList.map((e) => e['id'] as String).toList();
      if (allOptionIds.isNotEmpty) {
        final votesRes = await SupabaseService.table('poll_votes')
            .select('option_id')
            .eq('user_id', userId)
            .inFilter('option_id', allOptionIds);
        final votedOptionIds = (votesRes as List)
            .map((e) => e['option_id'] as String)
            .toSet();
        // Mapear option_id -> post_id
        final optionToPost = <String, String>{
          for (final o in optionsList)
            o['id'] as String: o['post_id'] as String,
        };
        // Injetar user_vote no poll_data de cada post
        for (final post in posts) {
          if (post['type'] != 'poll') continue;
          final pollData = post['poll_data'];
          if (pollData is! Map) continue;
          final options = (pollData['options'] as List<dynamic>?) ?? [];
          for (final optId in votedOptionIds) {
            if (optionToPost[optId] == post['id']) {
              final updatedPollData = Map<String, dynamic>.from(pollData);
              updatedPollData['user_vote'] = optId;
              post['poll_data'] = updatedPollData;
              break;
            }
          }
        }
      }
    }
  } catch (e) {
    debugPrint('[post_provider] _injectPollVote error: \$e');
  }

  return posts;
}

List<Map<String, dynamic>> _normalizeMediaList(dynamic rawMediaList) {
  if (rawMediaList is List) {
    return rawMediaList
        .map((item) {
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
        })
        .where((item) => (item['url'] as String?)?.isNotEmpty == true)
        .toList();
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
    debugPrint('[post_provider][detail] loading postId=$postId');
    try {
      final res = await SupabaseService.table('posts')
          .select(_kPostSelect)
          .eq('id', postId)
          .maybeSingle();

      if (res == null) {
        debugPrint('[post_provider][detail] not_found postId=$postId');
        return null;
      }

      final map = _normalizePostMap(Map<String, dynamic>.from(res));
      await _enrichAuthorData(map);
      debugPrint(
        '[post_provider][detail] raw_loaded postId=$postId '
        'communityId=${map['community_id']} authorId=${map['author_id']} '
        'type=${map['type']} hasAuthor=${map['author'] != null} '
        'authorIcon=${(map['author'] as Map?)?['icon_url']} '
        'authorLocalIcon=${map['author_local_icon_url']}',
      );
      await _injectIsLiked([map]);
      debugPrint(
        '[post_provider][detail] normalized postId=$postId '
        'isLiked=${map['is_liked']} likesCount=${map['likes_count']}',
      );
      return PostModel.fromJson(map);
    } catch (e, stackTrace) {
      debugPrint('[post_provider][detail] error postId=$postId error=$e');
      debugPrint('[post_provider][detail] stackTrace=$stackTrace');
      rethrow;
    }
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

final activeFeaturedPostsProvider =
    FutureProvider.family<List<PostModel>, String>(
  (ref, communityId) async {
    final res = await SupabaseService.table('posts')
        .select(_kPostSelect)
        .eq('community_id', communityId)
        .eq('is_featured', true)
        .eq('status', 'ok')
        .order('featured_at', ascending: false)
        .limit(100);

    final list = (res as List)
        .map((e) => _normalizePostMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    await _injectIsLiked(list);

    final posts = list.map((e) => PostModel.fromJson(e)).toList();
    return posts.where((p) => p.isFeatured).toList();
  },
);

final latestPostsProvider = FutureProvider.family<List<PostModel>, String>(
  (ref, communityId) async {
    final res = await SupabaseService.table('posts')
        .select(_kPostSelect)
        .eq('community_id', communityId)
        .inFilter('status', ['ok', 'disabled'])
        .eq('is_pinned', false)
        .eq('is_featured', false)
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
  (ref, communityId) =>
      ref.watch(activeFeaturedPostsProvider(communityId).future),
);
