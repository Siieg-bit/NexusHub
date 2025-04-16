import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_model.dart';
import '../../../core/models/post_model.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';

const _kProfilePostSelect =
    '*, profiles!posts_author_id_fkey(*), '
    'original_author:profiles!posts_original_author_id_fkey(id, nickname, icon_url), '
    'original_post:original_post_id(id, title, content, type, cover_image_url, media_list, created_at, author_id, community_id, original_post_id)';

PostModel _mapProfilePost(dynamic raw) {
  final map = Map<String, dynamic>.from(raw as Map);
  if (map['profiles'] != null) {
    map['author'] = map['profiles'];
  }
  if (map['original_post'] != null) {
    final originalPost = Map<String, dynamic>.from(map['original_post'] as Map);
    if (originalPost['profiles'] != null) {
      originalPost['author'] = originalPost['profiles'];
    }
    map['original_post'] = originalPost;
  }
  return PostModel.fromJson(map);
}

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

/// Provider legado para posts de um usuário.
final userPostsProvider =
    FutureProvider.family<List<PostModel>, String>((ref, userId) async {
  final response = await SupabaseService.table('posts')
      .select(_kProfilePostSelect)
      .eq('author_id', userId)
      .eq('status', 'ok')
      .order('created_at', ascending: false)
      .limit(20);

  return (response as List? ?? []).map(_mapProfilePost).toList();
});

/// Blogs publicados de um usuário para a aba de perfil.
final userBlogsProvider =
    FutureProvider.family<List<PostModel>, String>((ref, userId) async {
  final response = await SupabaseService.table('posts')
      .select(_kProfilePostSelect)
      .eq('author_id', userId)
      .eq('type', 'blog')
      .eq('status', 'ok')
      .order('is_pinned_profile', ascending: false)
      .order('created_at', ascending: false)
      .limit(50);

  return (response as List? ?? []).map(_mapProfilePost).toList();
});

/// Blog fixado no perfil do usuário, se existir.
final pinnedProfileBlogProvider =
    FutureProvider.family<PostModel?, String>((ref, userId) async {
  final response = await SupabaseService.table('posts')
      .select(_kProfilePostSelect)
      .eq('author_id', userId)
      .eq('type', 'blog')
      .eq('status', 'ok')
      .eq('is_pinned_profile', true)
      .order('updated_at', ascending: false)
      .limit(1)
      .maybeSingle();

  if (response == null) {
    return null;
  }

  return _mapProfilePost(response);
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

/// Provider que verifica se um usuário específico tem stories ativos (não expirados).
/// Usado para exibir o anel de story ao redor do avatar do usuário.
final userHasActiveStoryProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  if (userId.isEmpty) return false;
  try {
    final response = await SupabaseService.table('stories')
        .select('id')
        .eq('author_id', userId)
        .eq('is_active', true)
        .gte('expires_at', DateTime.now().toUtc().toIso8601String())
        .limit(1);
    return ((response as List?) ?? []).isNotEmpty;
  } catch (_) {
    return false;
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

/// Provider para itens equipados (avatar frame, bubble, sticker_packs).
/// Lê corretamente o asset_config de cada item para extrair as URLs reais.
final equippedItemsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  String _str(dynamic v) => v?.toString().trim() ?? '';
  String? _first(List<String> vals) {
    for (final v in vals) {
      if (v.isNotEmpty) return v;
    }
    return null;
  }
  Map<String, dynamic> _toMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  try {
    final response = await SupabaseService.table('user_purchases')
        .select('*, store_items(*)')
        .eq('user_id', userId)
        .eq('is_equipped', true);
    final items = response as List;
    String? frameUrl;
    bool frameIsAnimated = false;
    String? bubbleId;
    String? bubbleStyle;
    String? bubbleColor;
    String? bubbleImageUrl;
    final List<String> equippedPackIds = [];

    for (final raw in items) {
      final item = _toMap(raw);
      final si = _toMap(item['store_items']);
      if (si.isEmpty) continue;
      final type = _str(si['type']);
      final ac = _toMap(si['asset_config']);

      if (type == 'avatar_frame') {
        frameUrl = _first([
          _str(ac['frame_url']),
          _str(ac['image_url']),
          _str(si['asset_url']),
          _str(si['preview_url']),
        ]);
        // Lê is_animated do asset_config para propagar ao widget
        frameIsAnimated = ac['is_animated'] as bool? ?? false;
      } else if (type == 'chat_bubble') {
        bubbleId = _str(si['id']);
        bubbleStyle = _first([_str(ac['style']), _str(ac['bubble_style'])]);
        bubbleColor = _first([_str(ac['color']), _str(ac['bubble_color'])]);
        bubbleImageUrl = _first([
          _str(ac['image_url']),
          _str(ac['bubble_image_url']),
          _str(si['asset_url']),
          _str(si['preview_url']),
        ]);
      } else if (type == 'sticker_pack') {
        final packId = _first([_str(ac['pack_id']), _str(si['pack_id'])]);
        if (packId != null && packId.isNotEmpty) {
          equippedPackIds.add(packId);
        }
      }
    }
    return {
      'frame_url': frameUrl,
      'frame_is_animated': frameIsAnimated,
      'bubble_id': bubbleId,
      'bubble_style': bubbleStyle,
      'bubble_color': bubbleColor,
      'bubble_image_url': bubbleImageUrl,
      'equipped_pack_ids': equippedPackIds,
    };
  } catch (_) {
    return {
      'frame_url': null,
      'frame_is_animated': false,
      'bubble_id': null,
      'bubble_style': null,
      'bubble_color': null,
      'bubble_image_url': null,
      'equipped_pack_ids': <String>[],
    };
  }
});
