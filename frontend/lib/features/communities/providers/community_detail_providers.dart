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
      .select('*, profiles!posts_author_id_fkey(*)')
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
    return map;
  }).toList();

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
      .select('*, profiles!posts_author_id_fkey(*)')
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

  await _injectIsLikedCommunity(maps);
  return maps.map((map) => PostModel.fromJson(map)).toList();
});

/// Posts em DESTAQUE ATIVOS (is_featured=true e não expirados) — seção 2 da aba Destaque.
final activeFeaturedFeedProvider =
    FutureProvider.family<List<PostModel>, String>((ref, communityId) async {
  final now = DateTime.now().toUtc().toIso8601String();

  final response = await SupabaseService.table('posts')
      .select('*, profiles!posts_author_id_fkey(*)')
      .eq('community_id', communityId)
      .eq('status', 'ok')
      .eq('is_featured', true)
      .or('featured_until.is.null,featured_until.gt.$now')
      .order('featured_at', ascending: false)
      .limit(12);

  final maps = (response as List? ?? []).map((e) {
    final map = Map<String, dynamic>.from(e);
    if (map['profiles'] != null) map['author'] = map['profiles'];
    return map;
  }).toList();

  await _injectIsLikedCommunity(maps);

  // Filtro extra no cliente para garantir expiração correta
  final posts = maps.map((map) => PostModel.fromJson(map)).toList();
  return posts.where((p) => p.isFeaturedActive).toList();
});

/// Posts RECENTES (excluindo fixados) — seção 3 da aba Destaque.
final latestFeedProvider =
    FutureProvider.family<List<PostModel>, String>((ref, communityId) async {
  final response = await SupabaseService.table('posts')
      .select('*, profiles!posts_author_id_fkey(*)')
      .eq('community_id', communityId)
      .eq('status', 'ok')
      .eq('is_pinned', false)
      .order('created_at', ascending: false)
      .limit(20);

  final maps = (response as List? ?? []).map((e) {
    final map = Map<String, dynamic>.from(e);
    if (map['profiles'] != null) map['author'] = map['profiles'];
    return map;
  }).toList();

  await _injectIsLikedCommunity(maps);
  return maps.map((map) => PostModel.fromJson(map)).toList();
});

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
          '*, profiles!community_members_user_id_fkey(id, nickname, icon_url, level, online_status)')
      .eq('community_id', communityId)
      .order('role', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(response as List? ?? []);
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
