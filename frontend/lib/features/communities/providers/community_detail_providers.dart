import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/community_model.dart';
import '../../../core/models/post_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_service.dart';

// =============================================================================
// PROVIDERS — Community Detail
// =============================================================================

final communityDetailProvider =
    FutureProvider.family<CommunityModel, String>((ref, id) async {
  final response =
      await SupabaseService.table('communities').select().eq('id', id).single();
  return CommunityModel.fromJson(response);
});

final communityFeedProvider =
    FutureProvider.family<List<PostModel>, String>((ref, communityId) async {
  final response = await SupabaseService.table('posts')
      .select(
          '*, profiles!posts_author_id_fkey(*), original_author:profiles!posts_original_author_id_fkey(id, nickname, icon_url, online_status), original_post:original_post_id(id, title, content, type, cover_image_url, media_list, created_at, author_id, community_id, original_post_id)')
      .eq('community_id', communityId)
      .eq('status', 'ok')
      .order('is_pinned', ascending: false)
      .order('created_at', ascending: false)
      .limit(30);

  final maps = (response as List? ?? []).map((e) {
    final map = Map<String, dynamic>.from(e);
    if (map['profiles'] != null) {
      map['author'] = map['profiles'];
    }
    // original_author is already keyed correctly from the join alias
    // Process original_post nested data
    if (map['original_post'] != null) {
      final op = Map<String, dynamic>.from(map['original_post'] as Map);
      if (op['profiles'] != null) {
        op['author'] = op['profiles'];
      }
      map['original_post'] = op;
    }
    return map;
  }).toList();

  await _injectCommunityAuthorIdentity(maps, communityId);

  // Injetar is_liked para o usuário atual
  await _injectIsLikedCommunity(maps);

  return maps.map((map) => PostModel.fromJson(map)).toList();
});

/// Provider para posts em Destaque (is_featured = true) — legado, redireciona para activeFeaturedFeedProvider.
final communityFeaturedFeedProvider =
    FutureProvider.family<List<PostModel>, String>((ref, communityId) async {
  return ref.watch(activeFeaturedFeedProvider(communityId).future);
});

/// Posts FIXADOS (is_pinned = true) — seção 1 da aba Destaque.
final pinnedFeedProvider =
    FutureProvider.family<List<PostModel>, String>((ref, communityId) async {
  final response = await SupabaseService.table('posts')
      .select(
          '*, profiles!posts_author_id_fkey(*), original_author:profiles!posts_original_author_id_fkey(id, nickname, icon_url, online_status), original_post:original_post_id(id, title, content, type, cover_image_url, media_list, created_at, author_id, community_id, original_post_id)')
      .eq('community_id', communityId)
      .eq('status', 'ok')
      .eq('is_pinned', true)
      .order('created_at', ascending: false)
      .limit(5);

  final maps = (response as List? ?? []).map((e) {
    final map = Map<String, dynamic>.from(e);
    if (map['profiles'] != null) map['author'] = map['profiles'];
    return map;
  }).toList();

  await _injectCommunityAuthorIdentity(maps, communityId);
  await _injectIsLikedCommunity(maps);
  return maps.map((map) => PostModel.fromJson(map)).toList();
});

/// Posts em DESTAQUE ATIVOS (is_featured=true) — seção 2 da aba Destaque.
final activeFeaturedFeedProvider =
    FutureProvider.family<List<PostModel>, String>((ref, communityId) async {
  final response = await SupabaseService.table('posts')
      .select(
          '*, profiles!posts_author_id_fkey(*), original_author:profiles!posts_original_author_id_fkey(id, nickname, icon_url, online_status), original_post:original_post_id(id, title, content, type, cover_image_url, media_list, created_at, author_id, community_id, original_post_id)')
      .eq('community_id', communityId)
      .eq('status', 'ok')
      .eq('is_featured', true)
      .order('featured_at', ascending: false)
      .limit(100);

  final maps = (response as List? ?? []).map((e) {
    final map = Map<String, dynamic>.from(e);
    if (map['profiles'] != null) map['author'] = map['profiles'];
    return map;
  }).toList();

  await _injectCommunityAuthorIdentity(maps, communityId);
  await _injectIsLikedCommunity(maps);

  final posts = maps.map((map) => PostModel.fromJson(map)).toList();
  return posts.where((p) => p.isFeatured).toList();
});

/// Posts que já passaram pela vitrine, mas saíram da rotação ativa.
///
/// O cleanup do backend desmarca `is_featured` e zera `featured_at`/`featured_until`
/// quando o destaque expira, mas preserva `featured_by`. Por isso, o histórico que
/// alimenta o carrossel precisa usar `featured_by IS NOT NULL` em vez de depender
/// de `featured_at`, que já não existe mais após a rotação.
final archivedFeaturedFeedProvider =
    FutureProvider.family<List<PostModel>, String>((ref, communityId) async {
  final response = await SupabaseService.table('posts')
      .select(
          '*, profiles!posts_author_id_fkey(*), original_author:profiles!posts_original_author_id_fkey(id, nickname, icon_url, online_status), original_post:original_post_id(id, title, content, type, cover_image_url, media_list, created_at, author_id, community_id, original_post_id)')
      .eq('community_id', communityId)
      .eq('status', 'ok')
      .eq('is_pinned', false)
      .eq('is_featured', false)
      .not('featured_by', 'is', null)
      .order('updated_at', ascending: false)
      .limit(50);

  final maps = (response as List? ?? []).map((e) {
    final map = Map<String, dynamic>.from(e);
    if (map['profiles'] != null) map['author'] = map['profiles'];
    return map;
  }).toList();

  await _injectCommunityAuthorIdentity(maps, communityId);
  await _injectIsLikedCommunity(maps);
  return maps.map((map) => PostModel.fromJson(map)).toList();
});

/// Posts RECENTES (excluindo fixados e históricos de destaque) — seção 3 da aba Destaque.
final latestFeedProvider =
    FutureProvider.family<List<PostModel>, String>((ref, communityId) async {
  final response = await SupabaseService.table('posts')
      .select(
          '*, profiles!posts_author_id_fkey(*), original_author:profiles!posts_original_author_id_fkey(id, nickname, icon_url, online_status), original_post:original_post_id(id, title, content, type, cover_image_url, media_list, created_at, author_id, community_id, original_post_id)')
      .eq('community_id', communityId)
      .eq('status', 'ok')
      .eq('is_pinned', false)
      .eq('is_featured', false)
      .isFilter('featured_by', null)
      .order('created_at', ascending: false)
      .limit(20);

  final maps = (response as List? ?? []).map((e) {
    final map = Map<String, dynamic>.from(e);
    if (map['profiles'] != null) map['author'] = map['profiles'];
    return map;
  }).toList();

  await _injectCommunityAuthorIdentity(maps, communityId);
  await _injectIsLikedCommunity(maps);
  return maps.map((map) => PostModel.fromJson(map)).toList();
});

Future<void> _injectCommunityAuthorIdentity(
  List<Map<String, dynamic>> posts,
  String communityId,
) async {
  if (posts.isEmpty) return;

  final authorIds = posts
      .map((p) => p['author_id'] as String?)
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();
  if (authorIds.isEmpty) return;

  try {
    final membershipsRes = await SupabaseService.table('community_members')
        .select(
            'user_id, local_nickname, local_icon_url, local_banner_url, local_level')
        .eq('community_id', communityId)
        .inFilter('user_id', authorIds);

    final memberships = {
      for (final row in (membershipsRes as List? ?? const []))
        (row['user_id'] as String): Map<String, dynamic>.from(row as Map),
    };

    for (final post in posts) {
      final authorId = post['author_id'] as String?;
      if (authorId == null) continue;
      final membership = memberships[authorId];
      if (membership == null) continue;

      post['author_local_level'] = membership['local_level'];
      post['author_local_nickname'] = membership['local_nickname'];
      post['author_local_icon_url'] = membership['local_icon_url'];
      post['author_local_banner_url'] = membership['local_banner_url'];

      final currentAuthor = Map<String, dynamic>.from(
        (post['author'] ?? post['profiles'] ?? const <String, dynamic>{})
            as Map,
      );
      // local_nickname/local_icon_url sempre preenchidos desde o join (migration 093)
      final localNickname = (membership['local_nickname'] as String?)?.trim();
      final localIconUrl = (membership['local_icon_url'] as String?)?.trim();
      final localBannerUrl =
          (membership['local_banner_url'] as String?)?.trim();

      currentAuthor['nickname'] = localNickname;
      currentAuthor['icon_url'] = localIconUrl;
      currentAuthor['banner_url'] = localBannerUrl;

      post['author'] = currentAuthor;
      post['profiles'] = currentAuthor;
    }
  } catch (e) {
    debugPrint(
      '[community_detail_providers] _injectCommunityAuthorIdentity error: $e',
    );
  }
}

/// Helper: injeta is_liked em uma lista de maps de posts para o usuário atual.
Future<void> _injectIsLikedCommunity(List<Map<String, dynamic>> posts) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null || posts.isEmpty) return;

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
    debugPrint(
        '[community_detail_providers] _injectIsLikedCommunity error: $e');
  }
}

final communityMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, communityId) async {
  final response = await SupabaseService.table('community_members')
      .select(
          '*, profiles!community_members_user_id_fkey(id, nickname, icon_url, banner_url, online_status)')
      .eq('community_id', communityId)
      .order('role', ascending: false)
      .limit(50);

  final members = List<Map<String, dynamic>>.from(response as List? ?? []);
  for (final member in members) {
    if (member['profiles'] is! Map) continue;
    final profile = Map<String, dynamic>.from(member['profiles'] as Map);
    // local_nickname/local_icon_url sempre preenchidos desde o join (migration 093)
    final localNickname = (member['local_nickname'] as String?)?.trim();
    final localIconUrl = (member['local_icon_url'] as String?)?.trim();
    final localBannerUrl = (member['local_banner_url'] as String?)?.trim();

    profile['nickname'] = localNickname;
    profile['icon_url'] = localIconUrl;
    profile['banner_url'] = localBannerUrl;

    member['profiles'] = profile;
  }

  return members;
});

final communityChatProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, communityId) async {
  final response = await SupabaseService.table('chat_threads')
      .select('*, chat_members(count)')
      .eq('community_id', communityId)
      .order('last_message_at', ascending: false)
      .limit(20);
  return List<Map<String, dynamic>>.from(response as List? ?? []);
});

final communityMembershipProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, communityId) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return null;
  final response = await SupabaseService.table('community_members')
      .select()
      .eq('community_id', communityId)
      .eq('user_id', userId)
      .maybeSingle();
  return response;
});

final currentUserProfileProvider = FutureProvider<UserModel?>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return null;
  try {
    final response = await SupabaseService.table('profiles')
        .select()
        .eq('id', userId)
        .single();
    return UserModel.fromJson(response);
  } catch (_) {
    return null;
  }
});

final communityHomeLayoutProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, communityId) async {
  try {
    final response = await SupabaseService.table('communities')
        .select('home_layout')
        .eq('id', communityId)
        .single();
    return response['home_layout'] as Map<String, dynamic>? ?? defaultLayout;
  } catch (_) {
    return defaultLayout;
  }
});

/// Default layout configuration for community home page.
const Map<String, dynamic> defaultLayout = {
  'sections_order': ['header', 'check_in', 'live_chats', 'tabs'],
  'sections_visible': {
    'check_in': true,
    'live_chats': true,
    'featured_posts': true,
    'latest_feed': true,
    'public_chats': true,
    'guidelines': true,
  },
  'featured_type': 'list',
  'welcome_banner': {
    'enabled': false,
    'image_url': null,
    'text': null,
    'link': null,
  },
  'pinned_chat_ids': [],
  'bottom_bar': {
    'show_online_count': true,
    'show_create_button': true,
  },
};

/// Guidelines da comunidade (tabela guidelines)
final guidelinesProvider = FutureProvider.family<Map<String, dynamic>?, String>(
    (ref, communityId) async {
  try {
    final response = await SupabaseService.table('guidelines')
        .select('title, content, updated_at')
        .eq('community_id', communityId)
        .maybeSingle();
    return response;
  } catch (_) {
    return null;
  }
});
