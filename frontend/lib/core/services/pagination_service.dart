import 'supabase_service.dart';

/// ============================================================================
/// PaginationService — Helpers para paginação padronizada com Supabase.
///
/// Usa range-based pagination (offset/limit) que é nativa do PostgREST.
/// Todas as queries retornam listas paginadas com ordenação consistente.
/// ============================================================================

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
        .select('*, profiles!posts_author_id_fkey(nickname, icon_url)')
        .eq('community_id', communityId);

    if (postType != null) {
      query = query.eq('post_type', postType);
    }

    final res = await query
        .order(orderBy, ascending: ascending)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return List<Map<String, dynamic>>.from(res as List? ?? []);
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
        .select('*, profiles!chat_messages_author_id_fkey(nickname, icon_url)')
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
    var query = SupabaseService.table('community_members')
        .select('*, profiles!community_members_user_id_fkey(*)')
        .eq('community_id', communityId);

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
        .select('*, profiles!wiki_entries_author_id_fkey(nickname, icon_url)')
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
        .select('*, profiles!comments_author_id_fkey(nickname, icon_url)')
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
        .select('*, profiles!flags_reporter_id_fkey(nickname, icon_url)')
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
    final res = await SupabaseService.table('community_members')
        .select('*, profiles!community_members_user_id_fkey(*)')
        .eq('community_id', communityId)
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
          .select('*, profiles!posts_author_id_fkey(nickname)')
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
