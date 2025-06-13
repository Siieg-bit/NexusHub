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

  // Coletar todos os author_ids (post principal + original_post para republicações)
  final authorIds = <String>{};
  for (final p in posts) {
    final id = p['author_id'] as String?;
    if (id != null && id.isNotEmpty) authorIds.add(id);
    final op = p['original_post'] as Map?;
    if (op != null) {
      final opId = op['author_id'] as String?;
      if (opId != null && opId.isNotEmpty) authorIds.add(opId);
    }
  }
  if (authorIds.isEmpty) return;

  try {
    final membershipsRes = await SupabaseService.table('community_members')
        .select(
            'user_id, local_nickname, local_icon_url, local_banner_url, local_level')
        .eq('community_id', communityId)
        .inFilter('user_id', authorIds.toList());

    final memberships = {
      for (final row in (membershipsRes as List? ?? const []))
        (row['user_id'] as String): Map<String, dynamic>.from(row as Map),
    };

    for (final post in posts) {
      // Injetar identidade local do autor do post principal
      final authorId = post['author_id'] as String?;
      if (authorId != null) {
        final membership = memberships[authorId];
        if (membership != null) {
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
          final localBannerUrl = (membership['local_banner_url'] as String?)?.trim();

          currentAuthor['nickname'] = localNickname;
          currentAuthor['icon_url'] = localIconUrl;
          currentAuthor['banner_url'] = localBannerUrl;

          post['author'] = currentAuthor;
          post['profiles'] = currentAuthor;
        }
      }

      // Injetar identidade local também no original_post (para republicações/reposts)
      final opMap = post['original_post'] as Map?;
      if (opMap != null) {
        final opAuthorId = opMap['author_id'] as String?;
        if (opAuthorId != null) {
          final opMembership = memberships[opAuthorId];
          if (opMembership != null) {
            final op = Map<String, dynamic>.from(opMap);
            op['author_local_nickname'] = opMembership['local_nickname'];
            op['author_local_icon_url'] = opMembership['local_icon_url'];
            op['author_local_banner_url'] = opMembership['local_banner_url'];
            op['author_local_level'] = opMembership['local_level'];
            // Atualizar profiles aninhado do original_post
            final opAuthor = Map<String, dynamic>.from(
              (op['author'] ?? op['profiles'] ?? const <String, dynamic>{})
                  as Map,
            );
            opAuthor['nickname'] = (opMembership['local_nickname'] as String?)?.trim();
            opAuthor['icon_url'] = (opMembership['local_icon_url'] as String?)?.trim();
            op['author'] = opAuthor;
            op['profiles'] = opAuthor;
            post['original_post'] = op;
          }
        }
      }
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
  // ── Injetar poll_data para enquetes (busca opções do banco) ──────────────
  try {
    final pollPostIds = posts
        .where((p) => p['type'] == 'poll')
        .map((p) => p['id'] as String)
        .toList();
    if (pollPostIds.isNotEmpty) {
      final optionsRaw = await SupabaseService.table('poll_options')
          .select('id, post_id, text, votes_count, sort_order')
          .inFilter('post_id', pollPostIds)
          .order('sort_order', ascending: true);
      final optionsList = (optionsRaw as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final optionsByPost = <String, List<Map<String, dynamic>>>{};
      for (final o in optionsList) {
        final pid = o['post_id'] as String;
        optionsByPost.putIfAbsent(pid, () => []).add(o);
      }
      final allOptionIds =
          optionsList.map((e) => e['id'] as String).toList();
      Set<String> votedOptionIds = {};
      if (allOptionIds.isNotEmpty && userId != null) {
        final votesRes = await SupabaseService.table('poll_votes')
            .select('option_id')
            .eq('user_id', userId)
            .inFilter('option_id', allOptionIds);
        votedOptionIds = (votesRes as List)
            .map((e) => e['option_id'] as String)
            .toSet();
      }
      for (final post in posts) {
        if (post['type'] != 'poll') continue;
        final postId = post['id'] as String;
        final options = optionsByPost[postId] ?? [];
        if (options.isEmpty) continue;
        final normalizedOptions = options.map((o) {
          final vc = (o['votes_count'] as num?)?.toInt() ?? 0;
          return {
            'id': o['id'],
            'text': o['text'] ?? '',
            'votes': vc,
            'votes_count': vc,
            'sort_order': o['sort_order'] ?? 0,
          };
        }).toList();
        final totalVotes = normalizedOptions.fold<int>(
            0, (sum, o) => sum + ((o['votes'] as int?) ?? 0));
        String? userVote;
        for (final optId in votedOptionIds) {
          if (options.any((o) => o['id'] == optId)) {
            userVote = optId;
            break;
          }
        }
        final existingPollData = post['poll_data'];
        final question = existingPollData is Map
            ? existingPollData['question']?.toString()
            : null;
        post['poll_data'] = {
          if (question != null) 'question': question,
          'options': normalizedOptions,
          'total_votes': totalVotes,
          if (userVote != null) 'user_vote': userVote,
        };
      }
    }
  } catch (e) {
    debugPrint('[community_detail_providers] _injectPollData error: $e');
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
