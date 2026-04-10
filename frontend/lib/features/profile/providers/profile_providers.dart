import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_model.dart';
import '../../../core/models/post_model.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';

// =============================================================================
// PROVIDERS — Profile Screen
// =============================================================================

/// Provider para perfil de um usuário.
/// Tenta RPC get_user_profile primeiro; se falhar, busca direto da tabela.
final userProfileProvider =
    FutureProvider.family<UserModel, String>((ref, userId) async {
  // ── Tentativa 1: RPC (retorna JSONB com followers_count, is_following, etc.) ──
  try {
    final response = await SupabaseService.rpc('get_user_profile',
        params: {'p_user_id': userId});
    if (response != null) {
      final Map<String, dynamic> data;
      if (response is Map<String, dynamic>) {
        data = response;
      } else if (response is Map) {
        data = Map<String, dynamic>.from(response);
      } else {
        throw Exception(
            'Unexpected RPC response type: ${response.runtimeType}');
      }
      if (data.containsKey('error')) {
        throw Exception(data['error']);
      }
      return UserModel.fromJson(data);
    }
  } catch (_) {
    // Fallback abaixo
  }

  // ── Tentativa 2: Query direta na tabela profiles ──
  try {
    final profile = await SupabaseService.table('profiles')
        .select()
        .eq('id', userId)
        .single();

    final map = Map<String, dynamic>.from(profile);

    // Buscar contagens de followers/following
    try {
      final followersRes = await SupabaseService.table('follows')
          .select('id')
          .eq('following_id', userId);
      map['followers_count'] = (followersRes as List?)?.length;
    } catch (_) {
      map['followers_count'] = 0;
    }

    try {
      final followingRes = await SupabaseService.table('follows')
          .select('id')
          .eq('follower_id', userId);
      map['following_count'] = (followingRes as List?)?.length;
    } catch (_) {
      map['following_count'] = 0;
    }

    // Buscar contagem de posts
    try {
      final postsRes = await SupabaseService.table('posts')
          .select('id')
          .eq('author_id', userId)
          .eq('status', 'ok');
      map['posts_count'] = (postsRes as List?)?.length;
    } catch (_) {
      map['posts_count'] = 0;
    }

    // Verificar se o viewer segue este usuário
    final viewerId = SupabaseService.currentUserId;
    if (viewerId != null && viewerId != userId) {
      try {
        final followCheck = await SupabaseService.table('follows')
            .select('id')
            .eq('follower_id', viewerId)
            .eq('following_id', userId);
        map['is_following'] = (followCheck as List?)?.isNotEmpty;
      } catch (_) {
        map['is_following'] = false;
      }
    }

    return UserModel.fromJson(map);
  } catch (e) {
    throw Exception('Falha ao carregar perfil: $e');
  }
});

/// Provider para posts de um usuário (Stories).
final userPostsProvider =
    FutureProvider.family<List<PostModel>, String>((ref, userId) async {
  final response = await SupabaseService.table('posts')
      .select('*, profiles!posts_author_id_fkey(*), original_author:profiles!posts_original_author_id_fkey(id, nickname, icon_url), original_post:original_post_id(id, title, content, type, cover_image_url, media_list, created_at, author_id, community_id, original_post_id)')
      .eq('author_id', userId)
      .eq('status', 'ok')
      .order('created_at', ascending: false)
      .limit(20);

  return (response as List? ?? []).map((e) {
    final map = Map<String, dynamic>.from(e);
    if (map['profiles'] != null) map['author'] = map['profiles'];
    if (map['original_post'] != null) {
      final op = Map<String, dynamic>.from(map['original_post'] as Map);
      if (op['profiles'] != null) op['author'] = op['profiles'];
      map['original_post'] = op;
    }
    return PostModel.fromJson(map);
  }).toList();
});

/// Provider para stories do usuário (tabela stories, NÃO posts).
final userStoriesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, userId) async {
  try {
    final response = await SupabaseService.table('stories')
        .select('*, profiles!author_id(*)')
        .eq('author_id', userId)
        .eq('is_active', true)
        .gte('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(30);
    return List<Map<String, dynamic>>.from(response as List? ?? []);
  } catch (e) {
    // Tabela stories pode não existir ainda em ambientes sem a migration 024
    return [];
  }
});

/// Provider para comunidades vinculadas (Linked Communities) de qualquer usuário.
final userLinkedCommunitiesProvider =
    FutureProvider.family<List<CommunityModel>, String>((ref, userId) async {
  final response = await SupabaseService.table('community_members')
      .select('community_id, communities(*)')
      .eq('user_id', userId)
      .eq('is_banned', false)
      .order('joined_at', ascending: false);

  return (response as List? ?? [])
      .where((e) => e['communities'] != null)
      .map((e) =>
          CommunityModel.fromJson(e['communities'] as Map<String, dynamic>))
      .toList();
});

/// Provider para wall messages de um usuário (usa tabela comments com profile_wall_id).
final userWallProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, userId) async {
  try {
    final res = await SupabaseService.table('comments')
        .select('*, profiles!comments_author_id_fkey(id, nickname, icon_url)')
        .eq('profile_wall_id', userId)
        .eq('status', 'ok')
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List? ?? []).map((e) {
      final map = Map<String, dynamic>.from(e);
      if (map['profiles'] != null) {
        map['author'] = map['profiles'];
      }
      return map;
    }).toList();
  } catch (_) {
    return [];
  }
});

/// Provider para itens equipados (avatar frame, bubble).
final equippedItemsProvider =
    FutureProvider.family<Map<String, String?>, String>((ref, userId) async {
  try {
    final response = await SupabaseService.table('user_purchases')
        .select('*, store_items(*)')
        .eq('user_id', userId)
        .eq('is_equipped', true);
    final items = response as List;
    String? frameUrl;
    String? bubbleUrl;
    for (final item in items) {
      final storeItem = item['store_items'] as Map<String, dynamic>?;
      if (storeItem == null) continue;
      final type = storeItem['type'] as String? ?? '';
      final imageUrl = storeItem['image_url'] as String? ?? '';
      if (type == 'avatar_frame') frameUrl = imageUrl;
      if (type == 'chat_bubble') bubbleUrl = imageUrl;
    }
    return {'frame_url': frameUrl, 'bubble_url': bubbleUrl};
  } catch (_) {
    return {'frame_url': null, 'bubble_url': null};
  }
});
