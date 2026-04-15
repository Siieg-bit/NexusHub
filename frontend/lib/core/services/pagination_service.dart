import 'supabase_service.dart';

/// ============================================================================
/// PaginationService — Helpers para paginação padronizada com Supabase.
///
/// Usa range-based pagination (offset/limit) que é nativa do PostgREST.
/// Todas as queries retornam listas paginadas com ordenação consistente.
/// ============================================================================

void _applyLocalProfileToPost(
  Map<String, dynamic> post,
  Map<String, Map<String, dynamic>> memberships,
) {
  void applyOnMap(Map<String, dynamic> target) {
    final authorId = target['author_id']?.toString();
    if (authorId == null || authorId.isEmpty) return;

    final membership = memberships[authorId];
    if (membership == null) return;

    final localNickname = membership['local_nickname']?.toString().trim();
    final localIconUrl = membership['local_icon_url']?.toString().trim();
    final localBannerUrl = membership['local_banner_url']?.toString().trim();

    target['author_local_nickname'] = localNickname;
    target['author_local_icon_url'] = localIconUrl;
    target['author_local_banner_url'] = localBannerUrl;
    target['author_local_level'] ??= membership['local_level'];

    final currentProfile = Map<String, dynamic>.from(
      (target['profiles'] ?? target['author'] ?? const <String, dynamic>{}) as Map,
    );
    currentProfile['nickname'] = localNickname;
    currentProfile['icon_url'] = localIconUrl;
    currentProfile['banner_url'] = localBannerUrl;

    target['profiles'] = currentProfile;
    target['author'] = currentProfile;
  }

  applyOnMap(post);

  final originalPostRaw = post['original_post'];
  if (originalPostRaw is Map) {
    final originalPost = Map<String, dynamic>.from(originalPostRaw);
    applyOnMap(originalPost);
    post['original_post'] = originalPost;

    final originalAuthor = originalPost['author'] ?? originalPost['profiles'];
    if (originalAuthor is Map) {
      post['original_author'] = Map<String, dynamic>.from(originalAuthor);
    }
  }
}

Future<bool> _canCurrentUserViewHiddenProfiles(String communityId) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return false;

  try {
    final membership = await SupabaseService.table('community_members')
        .select('role')
        .eq('community_id', communityId)
        .eq('user_id', userId)
        .maybeSingle();
    final role = (membership?['role'] as String? ?? '').toLowerCase();
    if (role == 'agent' || role == 'leader' || role == 'curator') {
      return true;
    }

    final profile = await SupabaseService.table('profiles')
        .select('is_team_admin, is_team_moderator')
        .eq('id', userId)
        .maybeSingle();
    return (profile?['is_team_admin'] == true) ||
        (profile?['is_team_moderator'] == true);
  } catch (_) {
    return false;
  }
}

class PaginationService {
  /// Busca posts paginados de uma comunidade
  static Future<List<Map<String, dynamic>>> fetchPosts({
    required String communityId,
    required int page,
    int pageSize = 20,
    String orderBy = 'created_at',
    bool ascending = false,
    String? postType,
  }) async {
    var query = SupabaseService.table('posts')
        .select('*, profiles!posts_author_id_fkey(id, nickname, icon_url), original_author:profiles!posts_original_author_id_fkey(id, nickname, icon_url), original_post:original_post_id(id, title, content, type, cover_image_url, media_list, created_at, author_id, community_id, original_post_id, profiles!posts_author_id_fkey(id, nickname, icon_url))')
        .eq('community_id', communityId);

    if (postType != null) {
      query = query.eq('post_type', postType);
    }

    final res = await query
        .order(orderBy, ascending: ascending)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    final posts = List<Map<String, dynamic>>.from(res as List? ?? []);
    if (posts.isEmpty) return posts;

    final authorIds = <String>{};
    for (final post in posts) {
      final authorId = post['author_id']?.toString();
      if (authorId != null && authorId.isNotEmpty) {
        authorIds.add(authorId);
      }
      final originalPost = post['original_post'];
      if (originalPost is Map) {
        final originalAuthorId = originalPost['author_id']?.toString();
        if (originalAuthorId != null && originalAuthorId.isNotEmpty) {
          authorIds.add(originalAuthorId);
        }
      }
    }

    if (authorIds.isEmpty) return posts;

    final membershipsRes = await SupabaseService.table('community_members')
        .select('user_id, local_nickname, local_icon_url, local_banner_url, local_level')
        .eq('community_id', communityId)
        .inFilter('user_id', authorIds.toList());

    final memberships = <String, Map<String, dynamic>>{};
    for (final row in List<Map<String, dynamic>>.from(membershipsRes as List? ?? [])) {
      final userId = row['user_id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        memberships[userId] = row;
      }
    }

    for (final post in posts) {
      _applyLocalProfileToPost(post, memberships);
    }

    return posts;
  }

  /// Busca comunidades paginadas (para Discover)
  static Future<List<Map<String, dynamic>>> fetchCommunities({
    required int page,
    int pageSize = 20,
    String? category,
    String? searchQuery,
    String orderBy = 'member_count',
    bool ascending = false,
  }) async {
    var query = SupabaseService.table('communities').select();

    if (category != null && category.isNotEmpty) {
      query = query.contains('tags', [category]);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('name', '%$searchQuery%');
    }

    final res = await query
        .order(orderBy, ascending: ascending)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return List<Map<String, dynamic>>.from(res as List? ?? []);
  }

  /// Busca mensagens de chat paginadas (ordem inversa — mais recentes primeiro)
  static Future<List<Map<String, dynamic>>> fetchMessages({
    required String threadId,
    required int page,
    int pageSize = 50,
  }) async {
    final res = await SupabaseService.table('chat_messages')
        .select(
            '*, profiles!chat_messages_author_id_fkey(id, nickname, icon_url)')
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return List<Map<String, dynamic>>.from(res as List? ?? []);
  }

  /// Busca threads de chat paginadas
  static Future<List<Map<String, dynamic>>> fetchChatThreads({
    required int page,
    int pageSize = 20,
    String? communityId,
  }) async {
    var query = SupabaseService.table('chat_threads').select();

    if (communityId != null) {
      query = query.eq('community_id', communityId);
    }

    final res = await query
        .order('updated_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return List<Map<String, dynamic>>.from(res as List? ?? []);
  }

  /// Busca membros de uma comunidade paginados
  static Future<List<Map<String, dynamic>>> fetchMembers({
    required String communityId,
    required int page,
    int pageSize = 30,
    String? role,
  }) async {
    final canViewHidden = await _canCurrentUserViewHiddenProfiles(communityId);

    var query = SupabaseService.table('community_members')
        .select('*, profiles!community_members_user_id_fkey(*)')
        .eq('community_id', communityId);

    if (!canViewHidden) {
      query = query.neq('is_hidden', true);
    }

    if (role != null) {
      query = query.eq('role', role);
    }

    final res = await query
        .order('joined_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return List<Map<String, dynamic>>.from(res as List? ?? []);
  }

  /// Busca wiki entries paginadas
  static Future<List<Map<String, dynamic>>> fetchWikiEntries({
    required String communityId,
    required int page,
    int pageSize = 20,
    String? category,
    String? status,
  }) async {
    var query = SupabaseService.table('wiki_entries')
        .select(
            '*, profiles!wiki_entries_author_id_fkey(id, nickname, icon_url)')
        .eq('community_id', communityId);

    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }

    if (status != null) {
      query = query.eq('status', status);
    }

    final res = await query
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return List<Map<String, dynamic>>.from(res as List? ?? []);
  }

  /// Busca notificações paginadas
  static Future<List<Map<String, dynamic>>> fetchNotifications({
    required int page,
    int pageSize = 20,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    final res = await SupabaseService.table('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return List<Map<String, dynamic>>.from(res as List? ?? []);
  }

  /// Busca itens da loja paginados
  static Future<List<Map<String, dynamic>>> fetchStoreItems({
    required int page,
    int pageSize = 20,
    String? category,
    String? communityId,
  }) async {
    var query = SupabaseService.table('store_items').select();

    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }

    if (communityId != null) {
      query = query.eq('community_id', communityId);
    }

    final res = await query
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return List<Map<String, dynamic>>.from(res as List? ?? []);
  }

  /// Busca transações da wallet paginadas
  static Future<List<Map<String, dynamic>>> fetchTransactions({
    required int page,
    int pageSize = 20,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    final res = await SupabaseService.table('coin_transactions')
        .select()
        .or('user_id.eq.$userId,target_user_id.eq.$userId')
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return List<Map<String, dynamic>>.from(res as List? ?? []);
  }

  /// Busca comentários de um post paginados
  static Future<List<Map<String, dynamic>>> fetchComments({
    required String postId,
    required int page,
    int pageSize = 20,
  }) async {
    final res = await SupabaseService.table('comments')
        .select('*, profiles!comments_author_id_fkey(id, nickname, icon_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return List<Map<String, dynamic>>.from(res as List? ?? []);
  }

  /// Busca flags/reports paginados (moderação)
  static Future<List<Map<String, dynamic>>> fetchFlags({
    required String communityId,
    required int page,
    int pageSize = 20,
    String? status,
  }) async {
    var query = SupabaseService.table('flags')
        .select('*, profiles!flags_reporter_id_fkey(id, nickname, icon_url)')
        .eq('community_id', communityId);

    if (status != null) {
      query = query.eq('status', status);
    }

    final res = await query
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return List<Map<String, dynamic>>.from(res as List? ?? []);
  }

  /// Busca seguidores/seguindo paginados
  static Future<List<Map<String, dynamic>>> fetchFollows({
    required String userId,
    required bool followers,
    required int page,
    int pageSize = 30,
  }) async {
    final column = followers ? 'following_id' : 'follower_id';
    final joinColumn = followers
        ? 'profiles!follows_follower_id_fkey(*)'
        : 'profiles!follows_following_id_fkey(*)';

    final res = await SupabaseService.table('follows')
        .select('*, $joinColumn')
        .eq(column, userId)
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return List<Map<String, dynamic>>.from(res as List? ?? []);
  }

  /// Busca leaderboard paginado
  static Future<List<Map<String, dynamic>>> fetchLeaderboard({
    required String communityId,
    required int page,
    int pageSize = 50,
  }) async {
    final canViewHidden = await _canCurrentUserViewHiddenProfiles(communityId);

    var query = SupabaseService.table('community_members')
        .select('*, profiles!community_members_user_id_fkey(*)')
        .eq('community_id', communityId);

    if (!canViewHidden) {
      query = query.neq('is_hidden', true);
    }

    final res = await query
        .order('local_reputation', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return List<Map<String, dynamic>>.from(res as List? ?? []);
  }

  /// Busca resultados de pesquisa global
  static Future<Map<String, List<Map<String, dynamic>>>> searchGlobal({
    required String query,
    int limit = 10,
  }) async {
    final results = await Future.wait([
      SupabaseService.table('communities')
          .select()
          .ilike('name', '%$query%')
          .limit(limit),
      SupabaseService.table('profiles')
          .select()
          .ilike('nickname', '%$query%')
          .limit(limit),
      SupabaseService.table('posts')
          .select('*, profiles!posts_author_id_fkey(id, nickname)')
          .ilike('title', '%$query%')
          .limit(limit),
      SupabaseService.table('wiki_entries')
          .select()
          .ilike('title', '%$query%')
          .limit(limit),
    ]);

    return {
      'communities': List<Map<String, dynamic>>.from(results[0] as List? ?? []),
      'users': List<Map<String, dynamic>>.from(results[1] as List? ?? []),
      'posts': List<Map<String, dynamic>>.from(results[2] as List? ?? []),
      'wiki': List<Map<String, dynamic>>.from(results[3] as List? ?? []),
    };
  }
}
