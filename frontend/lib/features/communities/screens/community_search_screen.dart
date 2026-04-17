import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Tela de busca dentro de uma comunidade específica.
/// Permite pesquisar posts, membros, wiki e chats com filtros e autocomplete.
class CommunitySearchScreen extends ConsumerStatefulWidget {
  final String communityId;
  final String communityName;

  const CommunitySearchScreen({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  ConsumerState<CommunitySearchScreen> createState() =>
      _CommunitySearchScreenState();
}

class _CommunitySearchScreenState extends ConsumerState<CommunitySearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isSearching = false;
  String _query = '';
  Timer? _suggestDebounce;
  Timer? _searchDebounce;

  // Resultados
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _wikis = [];
  List<Map<String, dynamic>> _chats = [];

  // Sugestões de autocomplete
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  // Filtros de posts
  String _postFilter = 'recent'; // recent | popular | oldest
  String _postType = 'all'; // all | text | image | poll | quiz

  // Histórico de buscas recentes (em memória)
  final List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _query.isEmpty) {
        setState(() => _showSuggestions = true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _suggestDebounce?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _suggestDebounce?.cancel();
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _posts = [];
        _members = [];
        _wikis = [];
        _chats = [];
        _suggestions = [];
        _showSuggestions = true;
        _isSearching = false;
      });
      return;
    }
    // Debounce de 300ms para autocomplete
    _suggestDebounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(value.trim());
    });
    // Debounce de 600ms para busca completa
    _searchDebounce = Timer(const Duration(milliseconds: 600), () {
      _performSearch(value.trim());
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 2) return;
    try {
      final pattern = '$query%';
      final postRes = await SupabaseService.table('posts')
          .select('title')
          .eq('community_id', widget.communityId)
          .eq('status', 'ok')
          .ilike('title', pattern)
          .limit(5);
      final suggestions = (postRes as List? ?? [])
          .map((e) => (e['title'] as String?) ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('[community_search] _fetchSuggestions erro: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _showSuggestions = false;
    });

    // Salvar no histórico
    if (!_recentSearches.contains(query)) {
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 10) _recentSearches.removeLast();
    }

    try {
      final pattern = '%$query%';

      // ── 1. POSTS ──────────────────────────────────────────────────────────
      // Busca em title E content para cobrir mais resultados
      dynamic postQuery = SupabaseService.table('posts')
          .select(
              'id, title, type, likes_count, comments_count, thumbnail_url, cover_image_url, author_id, created_at, '
              'profiles!posts_author_id_fkey(id, nickname, icon_url, level)')
          .eq('community_id', widget.communityId)
          .eq('status', 'ok')
          .or('title.ilike.$pattern,content.ilike.$pattern');

      if (_postType != 'all') {
        postQuery = postQuery.eq('type', _postType);
      }

      switch (_postFilter) {
        case 'popular':
          postQuery = postQuery.order('likes_count', ascending: false);
          break;
        case 'oldest':
          postQuery = postQuery.order('created_at', ascending: true);
          break;
        default:
          postQuery = postQuery.order('created_at', ascending: false);
      }

      final postRes = await postQuery.limit(30);
      final rawPosts =
          List<Map<String, dynamic>>.from(postRes as List? ?? []);

      // Enriquecer posts com local_nickname/local_icon_url em batch
      if (rawPosts.isNotEmpty) {
        final authorIds = rawPosts
            .map((p) => p['author_id'] as String?)
            .whereType<String>()
            .toSet()
            .toList();
        if (authorIds.isNotEmpty) {
          try {
            final memberships = await SupabaseService.table('community_members')
                .select('user_id, local_nickname, local_icon_url')
                .eq('community_id', widget.communityId)
                .inFilter('user_id', authorIds);
            final memberMap = <String, Map<String, dynamic>>{
              for (final row in (memberships as List? ?? []))
                (row['user_id'] as String):
                    Map<String, dynamic>.from(row as Map),
            };
            for (final post in rawPosts) {
              final authorId = post['author_id'] as String?;
              if (authorId == null) continue;
              final membership = memberMap[authorId];
              if (membership == null) continue;
              final localNickname =
                  (membership['local_nickname'] as String?)?.trim();
              final localIconUrl =
                  (membership['local_icon_url'] as String?)?.trim();
              final profiles = post['profiles'] as Map<String, dynamic>?;
              if (profiles != null) {
                final updated = Map<String, dynamic>.from(profiles);
                if (localNickname != null && localNickname.isNotEmpty) {
                  updated['nickname'] = localNickname;
                }
                if (localIconUrl != null && localIconUrl.isNotEmpty) {
                  updated['icon_url'] = localIconUrl;
                }
                post['profiles'] = updated;
              }
            }
          } catch (e) {
            debugPrint('[community_search] enrich posts erro: $e');
          }
        }
      }

      // ── 2. MEMBROS ────────────────────────────────────────────────────────
      // CORREÇÃO: o Supabase não suporta .ilike() em colunas de tabelas
      // relacionadas via foreign key. Usamos duas queries separadas e unimos:
      //   Query A: busca por local_nickname (coluna local da community_members)
      //   Query B: busca por nickname global (via join com profiles)
      //            — feita com OR em coluna local para cobrir ambos os casos
      //
      // Para busca por nickname global, usamos RPC search_community_members
      // que faz o JOIN no banco. Se não existir, fazemos fallback com duas queries.
      List<Map<String, dynamic>> memberResults = [];
      try {
        // Query A: busca por local_nickname
        final resA = await SupabaseService.table('community_members')
            .select(
                'user_id, local_nickname, local_icon_url, role, '
                'profiles!community_members_user_id_fkey(id, nickname, icon_url, level, reputation)')
            .eq('community_id', widget.communityId)
            .eq('is_banned', false)
            .ilike('local_nickname', pattern)
            .limit(20);

        // Query B: busca por nickname global — precisa de RPC ou subquery
        // Usamos uma abordagem alternativa: buscar IDs de profiles que batem
        // e depois buscar community_members para esses IDs
        final profileRes = await SupabaseService.table('profiles')
            .select('id')
            .ilike('nickname', pattern)
            .limit(50);
        final profileIds = (profileRes as List? ?? [])
            .map((e) => (e as Map<String, dynamic>)['id'] as String?)
            .whereType<String>()
            .toList();

        List<dynamic> resB = [];
        if (profileIds.isNotEmpty) {
          resB = await SupabaseService.table('community_members')
              .select(
                  'user_id, local_nickname, local_icon_url, role, '
                  'profiles!community_members_user_id_fkey(id, nickname, icon_url, level, reputation)')
              .eq('community_id', widget.communityId)
              .eq('is_banned', false)
              .inFilter('user_id', profileIds)
              .limit(20) as List;
        }

        // Unir e deduplicar por user_id
        final memberMap = <String, Map<String, dynamic>>{};
        for (final e in [...(resA as List? ?? []), ...resB]) {
          final uid = (e as Map<String, dynamic>)['user_id'] as String?;
          if (uid != null) memberMap[uid] = e;
        }

        memberResults = memberMap.values
            .where((e) => e['profiles'] != null)
            .map((e) {
          final profile =
              Map<String, dynamic>.from(e['profiles'] as Map);
          final localNickname = (e['local_nickname'] as String?)?.trim();
          final localIconUrl = (e['local_icon_url'] as String?)?.trim();
          // Usar local_nickname/icon_url apenas quando preenchidos
          if (localNickname != null && localNickname.isNotEmpty) {
            profile['nickname'] = localNickname;
          }
          if (localIconUrl != null && localIconUrl.isNotEmpty) {
            profile['icon_url'] = localIconUrl;
          }
          profile['role'] = e['role'];
          return profile;
        }).toList();
      } catch (e) {
        debugPrint('[community_search] members erro: $e');
      }

      // ── 3. WIKI ───────────────────────────────────────────────────────────
      // CORREÇÃO: status = 'ok' (não 'approved')
      // Busca em title E tags para cobrir mais resultados
      List<Map<String, dynamic>> wikiResults = [];
      try {
        final wikiRes = await SupabaseService.table('wiki_entries')
            .select(
                'id, title, content, cover_image_url, author_id, created_at, likes_count, views_count, '
                'profiles!wiki_entries_author_id_fkey(id, nickname, icon_url)')
            .eq('community_id', widget.communityId)
            .eq('status', 'ok') // CORRIGIDO: era 'approved'
            .or('title.ilike.$pattern,content.ilike.$pattern')
            .order('likes_count', ascending: false)
            .limit(20);
        wikiResults =
            List<Map<String, dynamic>>.from(wikiRes as List? ?? []);

        // Enriquecer autores de wiki com dados locais em batch
        if (wikiResults.isNotEmpty) {
          final wikiAuthorIds = wikiResults
              .map((w) => w['author_id'] as String?)
              .whereType<String>()
              .toSet()
              .toList();
          if (wikiAuthorIds.isNotEmpty) {
            final wikiMemberships =
                await SupabaseService.table('community_members')
                    .select('user_id, local_nickname, local_icon_url')
                    .eq('community_id', widget.communityId)
                    .inFilter('user_id', wikiAuthorIds);
            final wikiLocalMap = <String, Map<String, dynamic>>{
              for (final m in (wikiMemberships as List? ?? []))
                (m['user_id'] as String):
                    Map<String, dynamic>.from(m as Map),
            };
            for (final wiki in wikiResults) {
              final authorId = wiki['author_id'] as String?;
              if (authorId == null) continue;
              final membership = wikiLocalMap[authorId];
              if (membership == null) continue;
              final profile = wiki['profiles'] as Map<String, dynamic>?;
              if (profile == null) continue;
              final merged = Map<String, dynamic>.from(profile);
              final localNickname =
                  (membership['local_nickname'] as String?)?.trim();
              final localIconUrl =
                  (membership['local_icon_url'] as String?)?.trim();
              if (localNickname != null && localNickname.isNotEmpty) {
                merged['nickname'] = localNickname;
              }
              if (localIconUrl != null && localIconUrl.isNotEmpty) {
                merged['icon_url'] = localIconUrl;
              }
              wiki['profiles'] = merged;
            }
          }
        }
      } catch (e) {
        debugPrint('[community_search] wiki erro: $e');
      }

      // ── 4. CHATS ──────────────────────────────────────────────────────────
      // Busca chats públicos da comunidade por title e description
      List<Map<String, dynamic>> chatResults = [];
      try {
        final chatRes = await SupabaseService.table('chat_threads')
            .select(
                'id, title, description, icon_url, cover_image_url, members_count, '
                'last_message_preview, last_message_at, category, is_announcement_only')
            .eq('community_id', widget.communityId)
            .eq('type', 'public')
            .eq('status', 'ok')
            .or('title.ilike.$pattern,description.ilike.$pattern')
            .order('members_count', ascending: false)
            .limit(20);
        chatResults =
            List<Map<String, dynamic>>.from(chatRes as List? ?? []);
      } catch (e) {
        debugPrint('[community_search] chats erro: $e');
      }

      if (mounted) {
        setState(() {
          _posts = rawPosts;
          _members = memberResults;
          _wikis = wikiResults;
          _chats = chatResults;
          _isSearching = false;
        });
      }
    } catch (e, st) {
      debugPrint('[community_search] _performSearch erro: $e\n$st');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion;
    _focusNode.unfocus();
    _performSearch(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: context.nexusTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: _buildSearchField(r),
        titleSpacing: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.nexusTheme.accentPrimary,
          labelColor: context.nexusTheme.accentPrimary,
          unselectedLabelColor: context.nexusTheme.textSecondary,
          labelStyle:
              TextStyle(fontSize: r.fs(12), fontWeight: FontWeight.w700),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: s.posts),
            Tab(text: s.members),
            Tab(text: s.wiki),
            const Tab(text: 'Chats'),
          ],
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(r),
                _buildMembersTab(r),
                _buildWikiTab(r),
                _buildChatsTab(r),
              ],
            ),
            // Overlay de sugestões
            if (_showSuggestions &&
                (_suggestions.isNotEmpty || _recentSearches.isNotEmpty))
              _buildSuggestionsOverlay(r),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(Responsive r) {
    return Container(
      height: r.s(40),
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(20)),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        autofocus: true,
        style: TextStyle(
            color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
        decoration: InputDecoration(
          hintText: 'Buscar em ${widget.communityName}...',
          hintStyle:
              TextStyle(color: context.nexusTheme.textHint, fontSize: r.fs(14)),
          prefixIcon: Icon(Icons.search_rounded,
              color: context.nexusTheme.textHint, size: r.s(18)),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: context.nexusTheme.textHint, size: r.s(16)),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: r.s(10)),
        ),
        onChanged: _onSearchChanged,
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) _performSearch(v.trim());
        },
      ),
    );
  }

  Widget _buildSuggestionsOverlay(Responsive r) {
    final items = [
      if (_query.isEmpty && _recentSearches.isNotEmpty)
        ..._recentSearches.take(5),
      ..._suggestions,
    ];
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: context.nexusTheme.surfacePrimary,
        elevation: 8,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(r.s(12)),
          bottomRight: Radius.circular(r.s(12)),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final isRecent = _query.isEmpty && index < _recentSearches.length;
            return ListTile(
              dense: true,
              leading: Icon(
                isRecent ? Icons.history_rounded : Icons.search_rounded,
                color: context.nexusTheme.textHint,
                size: r.s(18),
              ),
              title: Text(
                items[index],
                style: TextStyle(
                    color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
              ),
              onTap: () => _selectSuggestion(items[index]),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TAB: POSTS
  // ─────────────────────────────────────────────
  Widget _buildPostsTab(Responsive r) {
    final s = getStrings();
    return Column(
      children: [
        _buildPostFilters(r),
        Expanded(
          child: _query.isEmpty
              ? _buildEmptySearch(r, 'Busque posts nesta comunidade')
              : _isSearching
                  ? Center(
                      child: CircularProgressIndicator(
                          color: context.nexusTheme.accentPrimary))
                  : _posts.isEmpty
                      ? _buildNoResults(r, s.noPostFound)
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(vertical: r.s(8)),
                          cacheExtent: 500,
                          itemCount: _posts.length,
                          itemBuilder: (context, index) =>
                              _buildPostTile(r, _posts[index]),
                        ),
        ),
      ],
    );
  }

  Widget _buildPostFilters(Responsive r) {
    final s = getStrings();
    return Container(
      height: r.s(44),
      padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
      child: Row(
        children: [
          _FilterChip(
            label: _postFilter == 'recent'
                ? s.latest
                : _postFilter == 'popular'
                    ? 'Populares'
                    : s.oldest,
            icon: Icons.sort_rounded,
            onTap: () => _showSortDialog(r),
            r: r,
          ),
          SizedBox(width: r.s(8)),
          _FilterChip(
            label: _postType == 'all'
                ? s.everyone
                : _postType == 'text'
                    ? s.text
                    : _postType == 'image'
                        ? s.image
                        : _postType == 'poll'
                            ? s.poll2
                            : s.quiz,
            icon: Icons.filter_list_rounded,
            onTap: () => _showTypeDialog(r),
            r: r,
          ),
        ],
      ),
    );
  }

  void _showSortDialog(Responsive r) {
    final s = getStrings();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.nexusTheme.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(16))),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(r.s(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.sortBy,
                style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(16),
                    fontWeight: FontWeight.w800)),
            SizedBox(height: r.s(12)),
            _SortOption(
              label: s.mostRecent,
              icon: Icons.access_time_rounded,
              selected: _postFilter == 'recent',
              onTap: () {
                setState(() => _postFilter = 'recent');
                Navigator.pop(ctx);
                if (_query.isNotEmpty) _performSearch(_query);
              },
              r: r,
            ),
            _SortOption(
              label: s.mostPopular,
              icon: Icons.trending_up_rounded,
              selected: _postFilter == 'popular',
              onTap: () {
                setState(() => _postFilter = 'popular');
                Navigator.pop(ctx);
                if (_query.isNotEmpty) _performSearch(_query);
              },
              r: r,
            ),
            _SortOption(
              label: s.oldest,
              icon: Icons.history_rounded,
              selected: _postFilter == 'oldest',
              onTap: () {
                setState(() => _postFilter = 'oldest');
                Navigator.pop(ctx);
                if (_query.isNotEmpty) _performSearch(_query);
              },
              r: r,
            ),
          ],
        ),
      ),
    );
  }

  void _showTypeDialog(Responsive r) {
    final s = getStrings();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.nexusTheme.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(16))),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(r.s(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.postType,
                style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(16),
                    fontWeight: FontWeight.w800)),
            SizedBox(height: r.s(12)),
            for (final type in [
              ('all', s.everyone, Icons.apps_rounded),
              ('text', s.text, Icons.article_rounded),
              ('image', s.image, Icons.image_rounded),
              ('poll', s.poll2, Icons.poll_rounded),
              ('quiz', s.quiz, Icons.quiz_rounded),
            ])
              _SortOption(
                label: type.$2,
                icon: type.$3,
                selected: _postType == type.$1,
                onTap: () {
                  setState(() => _postType = type.$1);
                  Navigator.pop(ctx);
                  if (_query.isNotEmpty) _performSearch(_query);
                },
                r: r,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostTile(Responsive r, Map<String, dynamic> post) {
    final author = post['profiles'] as Map<String, dynamic>?;
    final title = post['title'] as String? ?? '';
    final type = post['type'] as String? ?? 'text';
    final likesCount = post['likes_count'] as int? ?? 0;
    final commentsCount = post['comments_count'] as int? ?? 0;
    final thumbnailUrl = (post['thumbnail_url'] as String?)?.isNotEmpty == true
        ? post['thumbnail_url'] as String
        : (post['cover_image_url'] as String?)?.isNotEmpty == true
            ? post['cover_image_url'] as String
            : null;

    return InkWell(
      onTap: () => context.push('/post/${post["id"]}'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.dividerClr, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail ou badge de tipo
            if (thumbnailUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(r.s(8)),
                child: CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  width: r.s(64),
                  height: r.s(64),
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _PostTypeBadge(type: type, r: r),
                ),
              )
            else
              _PostTypeBadge(type: type, r: r),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: r.s(4)),
                  Row(
                    children: [
                      if (author != null) ...[
                        CosmeticAvatar(
                          userId: author['id'] as String? ?? '',
                          avatarUrl: author['icon_url'] as String?,
                          size: r.s(16),
                        ),
                        SizedBox(width: r.s(4)),
                        Flexible(
                          child: Text(
                            author['nickname'] as String? ?? '',
                            style: TextStyle(
                              color: context.nexusTheme.textSecondary,
                              fontSize: r.fs(11),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: r.s(8)),
                      ],
                      Icon(Icons.favorite_rounded,
                          color: context.nexusTheme.textHint, size: r.s(11)),
                      SizedBox(width: r.s(2)),
                      Text(
                        '$likesCount',
                        style: TextStyle(
                            color: context.nexusTheme.textHint,
                            fontSize: r.fs(11)),
                      ),
                      SizedBox(width: r.s(8)),
                      Icon(Icons.comment_rounded,
                          color: context.nexusTheme.textHint, size: r.s(11)),
                      SizedBox(width: r.s(2)),
                      Text(
                        '$commentsCount',
                        style: TextStyle(
                            color: context.nexusTheme.textHint,
                            fontSize: r.fs(11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TAB: MEMBROS
  // ─────────────────────────────────────────────
  Widget _buildMembersTab(Responsive r) {
    final s = getStrings();
    return _query.isEmpty
        ? _buildEmptySearch(r, s.searchCommunityMembers)
        : _isSearching
            ? Center(
                child: CircularProgressIndicator(
                    color: context.nexusTheme.accentPrimary))
            : _members.isEmpty
                ? _buildNoResults(r, s.noMemberFound)
                : ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: r.s(8)),
                    cacheExtent: 500,
                    itemCount: _members.length,
                    itemBuilder: (context, index) =>
                        _buildMemberTile(r, _members[index]),
                  );
  }

  Widget _buildMemberTile(Responsive r, Map<String, dynamic> member) {
    final s = getStrings();
    final nickname = member['nickname'] as String? ?? '';
    final level = member['level'] as int? ?? 1;
    final reputation = member['reputation'] as int? ?? 0;
    final role = member['role'] as String? ?? 'member';

    // Badge de papel
    final (roleLabel, roleColor) = switch (role) {
      'leader' => ('Líder', context.nexusTheme.accentPrimary),
      'curator' => ('Curador', Colors.orange),
      'moderator' => ('Moderador', Colors.blue),
      _ => ('', Colors.transparent),
    };

    return InkWell(
      onTap: () => context
          .push('/community/${widget.communityId}/profile/${member["id"]}'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.dividerClr, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            CosmeticAvatar(
              userId: member['id'] as String? ?? '',
              avatarUrl: member['icon_url'] as String?,
              size: r.s(44),
            ),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          nickname,
                          style: TextStyle(
                            color: context.nexusTheme.textPrimary,
                            fontSize: r.fs(14),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (roleLabel.isNotEmpty) ...[
                        SizedBox(width: r.s(6)),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(6), vertical: r.s(2)),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(r.s(4)),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(
                                color: roleColor,
                                fontSize: r.fs(10),
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: r.s(2)),
                  Text(
                    s.levelAndRep(level, reputation),
                    style: TextStyle(
                        color: context.nexusTheme.textSecondary,
                        fontSize: r.fs(12)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: context.nexusTheme.textHint, size: r.s(20)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TAB: WIKI
  // ─────────────────────────────────────────────
  Widget _buildWikiTab(Responsive r) {
    final s = getStrings();
    return _query.isEmpty
        ? _buildEmptySearch(r, s.searchWikiArticles)
        : _isSearching
            ? Center(
                child: CircularProgressIndicator(
                    color: context.nexusTheme.accentPrimary))
            : _wikis.isEmpty
                ? _buildNoResults(r, 'Nenhum artigo wiki encontrado')
                : ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: r.s(8)),
                    cacheExtent: 500,
                    itemCount: _wikis.length,
                    itemBuilder: (context, index) =>
                        _buildWikiTile(r, _wikis[index]),
                  );
  }

  Widget _buildWikiTile(Responsive r, Map<String, dynamic> wiki) {
    final title = wiki['title'] as String? ?? '';
    final author = wiki['profiles'] as Map<String, dynamic>?;
    final content = wiki['content'] as String? ?? '';
    final preview =
        content.length > 100 ? '${content.substring(0, 100)}...' : content;
    final coverUrl = wiki['cover_image_url'] as String?;
    final likesCount = wiki['likes_count'] as int? ?? 0;
    final viewsCount = wiki['views_count'] as int? ?? 0;

    return InkWell(
      onTap: () =>
          context.push('/community/${widget.communityId}/wiki/${wiki["id"]}'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.dividerClr, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Capa ou ícone padrão
            if (coverUrl != null && coverUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(r.s(8)),
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
                  width: r.s(56),
                  height: r.s(56),
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _WikiIconBadge(r: r),
                ),
              )
            else
              _WikiIconBadge(r: r),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: r.s(3)),
                  Text(
                    preview,
                    style: TextStyle(
                        color: context.nexusTheme.textSecondary,
                        fontSize: r.fs(12)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: r.s(4)),
                  Row(
                    children: [
                      if (author != null) ...[
                        Text(
                          'por ${author["nickname"] ?? ""}',
                          style: TextStyle(
                              color: context.nexusTheme.textHint,
                              fontSize: r.fs(11)),
                        ),
                        SizedBox(width: r.s(8)),
                      ],
                      Icon(Icons.favorite_rounded,
                          color: context.nexusTheme.textHint, size: r.s(11)),
                      SizedBox(width: r.s(2)),
                      Text('$likesCount',
                          style: TextStyle(
                              color: context.nexusTheme.textHint,
                              fontSize: r.fs(11))),
                      SizedBox(width: r.s(8)),
                      Icon(Icons.visibility_rounded,
                          color: context.nexusTheme.textHint, size: r.s(11)),
                      SizedBox(width: r.s(2)),
                      Text('$viewsCount',
                          style: TextStyle(
                              color: context.nexusTheme.textHint,
                              fontSize: r.fs(11))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TAB: CHATS
  // ─────────────────────────────────────────────
  Widget _buildChatsTab(Responsive r) {
    return _query.isEmpty
        ? _buildEmptySearch(r, 'Busque chats públicos desta comunidade')
        : _isSearching
            ? Center(
                child: CircularProgressIndicator(
                    color: context.nexusTheme.accentPrimary))
            : _chats.isEmpty
                ? _buildNoResults(r, 'Nenhum chat encontrado')
                : ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: r.s(8)),
                    cacheExtent: 500,
                    itemCount: _chats.length,
                    itemBuilder: (context, index) =>
                        _buildChatTile(r, _chats[index]),
                  );
  }

  Widget _buildChatTile(Responsive r, Map<String, dynamic> chat) {
    final title = chat['title'] as String? ?? 'Chat';
    final description = chat['description'] as String? ?? '';
    final iconUrl = chat['icon_url'] as String?;
    final membersCount = chat['members_count'] as int? ?? 0;
    final lastPreview = chat['last_message_preview'] as String?;
    final category = chat['category'] as String?;
    final isAnnouncementOnly = chat['is_announcement_only'] as bool? ?? false;

    return InkWell(
      onTap: () => context.push('/chat/${chat["id"]}'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.dividerClr, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Ícone do chat
            Container(
              width: r.s(48),
              height: r.s(48),
              decoration: BoxDecoration(
                color: context.nexusTheme.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(r.s(12)),
              ),
              clipBehavior: Clip.antiAlias,
              child: iconUrl != null && iconUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: iconUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(
                          Icons.chat_bubble_rounded,
                          color: context.nexusTheme.accentPrimary,
                          size: r.s(22)),
                    )
                  : Icon(Icons.chat_bubble_rounded,
                      color: context.nexusTheme.accentPrimary, size: r.s(22)),
            ),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: context.nexusTheme.textPrimary,
                            fontSize: r.fs(14),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAnnouncementOnly) ...[
                        SizedBox(width: r.s(6)),
                        Icon(Icons.campaign_rounded,
                            color: Colors.orange, size: r.s(14)),
                      ],
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    SizedBox(height: r.s(2)),
                    Text(
                      description,
                      style: TextStyle(
                          color: context.nexusTheme.textSecondary,
                          fontSize: r.fs(12)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (lastPreview != null && lastPreview.isNotEmpty) ...[
                    SizedBox(height: r.s(2)),
                    Text(
                      lastPreview,
                      style: TextStyle(
                          color: context.nexusTheme.textHint,
                          fontSize: r.fs(11)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: r.s(3)),
                  Row(
                    children: [
                      Icon(Icons.people_rounded,
                          color: context.nexusTheme.textHint, size: r.s(12)),
                      SizedBox(width: r.s(3)),
                      Text(
                        '$membersCount membros',
                        style: TextStyle(
                            color: context.nexusTheme.textHint,
                            fontSize: r.fs(11)),
                      ),
                      if (category != null && category.isNotEmpty) ...[
                        SizedBox(width: r.s(8)),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(6), vertical: r.s(1)),
                          decoration: BoxDecoration(
                            color: context.nexusTheme.accentPrimary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(r.s(4)),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                                color: context.nexusTheme.accentPrimary,
                                fontSize: r.fs(10),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: context.nexusTheme.textHint, size: r.s(20)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ESTADOS VAZIOS
  // ─────────────────────────────────────────────
  Widget _buildEmptySearch(Responsive r, String message) {
    final s = getStrings();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded,
              color: context.nexusTheme.textHint, size: r.s(48)),
          SizedBox(height: r.s(12)),
          Text(
            message,
            style: TextStyle(
                color: context.nexusTheme.textSecondary, fontSize: r.fs(14)),
            textAlign: TextAlign.center,
          ),
          if (_recentSearches.isNotEmpty) ...[
            SizedBox(height: r.s(24)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.s(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.recentSearches,
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: r.s(8)),
                  Wrap(
                    spacing: r.s(8),
                    runSpacing: r.s(6),
                    children: _recentSearches
                        .take(6)
                        .map((term) => GestureDetector(
                              onTap: () => _selectSuggestion(term),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.s(12), vertical: r.s(6)),
                                decoration: BoxDecoration(
                                  color: context.nexusTheme.surfacePrimary,
                                  borderRadius: BorderRadius.circular(r.s(16)),
                                ),
                                child: Text(
                                  term,
                                  style: TextStyle(
                                      color: context.nexusTheme.textSecondary,
                                      fontSize: r.fs(12)),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoResults(Responsive r, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              color: context.nexusTheme.textHint, size: r.s(48)),
          SizedBox(height: r.s(12)),
          Text(
            message,
            style: TextStyle(
                color: context.nexusTheme.textSecondary, fontSize: r.fs(14)),
          ),
          SizedBox(height: r.s(6)),
          Text(
            'para "$_query"',
            style: TextStyle(
                color: context.nexusTheme.textHint,
                fontSize: r.fs(12),
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────

class _WikiIconBadge extends StatelessWidget {
  final Responsive r;
  const _WikiIconBadge({required this.r});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: r.s(56),
      height: r.s(56),
      decoration: BoxDecoration(
        color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(r.s(8)),
      ),
      child: Icon(Icons.article_rounded,
          color: context.nexusTheme.accentPrimary, size: r.s(24)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Responsive r;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(4)),
        decoration: BoxDecoration(
          color: context.nexusTheme.accentPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(
            color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: context.nexusTheme.accentPrimary, size: r.s(14)),
            SizedBox(width: r.s(4)),
            Text(
              label,
              style: TextStyle(
                color: context.nexusTheme.accentPrimary,
                fontSize: r.fs(12),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: r.s(2)),
            Icon(Icons.arrow_drop_down_rounded,
                color: context.nexusTheme.accentPrimary, size: r.s(16)),
          ],
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Responsive r;

  const _SortOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon,
          color: selected
              ? context.nexusTheme.accentPrimary
              : context.nexusTheme.textSecondary,
          size: r.s(20)),
      title: Text(
        label,
        style: TextStyle(
          color: selected
              ? context.nexusTheme.accentPrimary
              : context.nexusTheme.textPrimary,
          fontSize: r.fs(14),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_rounded,
              color: context.nexusTheme.accentPrimary, size: r.s(18))
          : null,
      onTap: onTap,
    );
  }
}

class _PostTypeBadge extends StatelessWidget {
  final String type;
  final Responsive r;

  const _PostTypeBadge({required this.type, required this.r});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      'image' => (Icons.image_rounded, Colors.blue),
      'poll' => (Icons.poll_rounded, Colors.orange),
      'quiz' => (Icons.quiz_rounded, Colors.purple),
      _ => (Icons.article_rounded, Colors.grey),
    };
    return Container(
      width: r.s(64),
      height: r.s(64),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(r.s(8)),
      ),
      child: Icon(icon, color: color, size: r.s(28)),
    );
  }
}
