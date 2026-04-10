import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/l10n/locale_provider.dart';

/// Tela de busca dentro de uma comunidade específica.
/// Permite pesquisar posts, membros e wiki com filtros e autocomplete.
class CommunitySearchScreen extends ConsumerStatefulWidget {
  final String communityId;
  final String communityName;

  const CommunitySearchScreen({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  ConsumerState<CommunitySearchScreen> createState() => _CommunitySearchScreenState();
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
    _tabController = TabController(length: 3, vsync: this);
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
          .ilike('title', pattern)
          .limit(5);
      final suggestions = (postRes as List? ?? [])
          .map((e) => (e['title'] as String?) ?? '')
          .toList();
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('[community_search_screen] Erro: $e');
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

      // Buscar posts com filtros
      dynamic postQuery = SupabaseService.table('posts')
          .select(
              '*, profiles!posts_author_id_fkey(id, nickname, icon_url, level)')
          .eq('community_id', widget.communityId)
          .ilike('title', pattern);

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
      _posts = List<Map<String, dynamic>>.from(postRes as List? ?? []);

      // Buscar membros
      final memberRes = await SupabaseService.table('community_members')
          .select(
              '*, profiles!community_members_user_id_fkey(id, nickname, icon_url, level, reputation)')
          .eq('community_id', widget.communityId)
          .eq('is_banned', false)
          .ilike('profiles.nickname', pattern)
          .limit(20);
      _members = (memberRes as List? ?? [])
          .where((e) => e['profiles'] != null)
          .map((e) => e['profiles'] as Map<String, dynamic>)
          .toList();

      // Buscar wiki
      final wikiRes = await SupabaseService.table('wiki_entries')
          .select(
              'id, title, content, author_id, created_at, profiles!wiki_entries_author_id_fkey(nickname, icon_url)')
          .eq('community_id', widget.communityId)
          .eq('status', 'approved')
          .ilike('title', pattern)
          .order('created_at', ascending: false)
          .limit(20);
      _wikis = List<Map<String, dynamic>>.from(wikiRes as List? ?? []);

      if (mounted) setState(() => _isSearching = false);
    } catch (e) {
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
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: _buildSearchField(r),
        titleSpacing: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: context.textSecondary,
          labelStyle:
              TextStyle(fontSize: r.fs(13), fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: s.posts),
            Tab(text: s.members),
            Tab(text: s.wiki),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildPostsTab(r),
              _buildMembersTab(r),
              _buildWikiTab(r),
            ],
          ),
          // Overlay de sugestões
          if (_showSuggestions &&
              (_suggestions.isNotEmpty || _recentSearches.isNotEmpty))
            _buildSuggestionsOverlay(r),
        ],
      ),
    );
  }

  Widget _buildSearchField(Responsive r) {
    return Container(
      height: r.s(40),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(20)),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        autofocus: true,
        style: TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
        decoration: InputDecoration(
          hintText: 'Buscar em ${widget.communityName}...',
          hintStyle: TextStyle(color: context.textHint, fontSize: r.fs(14)),
          prefixIcon: Icon(Icons.search_rounded,
              color: context.textHint, size: r.s(18)),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: context.textHint, size: r.s(16)),
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
        color: context.cardBg,
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
                color: context.textHint,
                size: r.s(18),
              ),
              title: Text(
                items[index],
                style:
                    TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
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
        // Barra de filtros
        _buildPostFilters(r),
        Expanded(
          child: _query.isEmpty
              ? _buildEmptySearch(r, 'Busque posts nesta comunidade')
              : _isSearching
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor))
                  : _posts.isEmpty
                      ? _buildNoResults(r, s.noPostFound)
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(vertical: r.s(8)),
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
          // Filtro de ordenação
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
          // Filtro de tipo
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
      backgroundColor: context.cardBg,
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
                    color: context.textPrimary,
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
      backgroundColor: context.cardBg,
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
                    color: context.textPrimary,
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
    final thumbnailUrl = post['thumbnail_url'] as String?;

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
            // Thumbnail
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
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
                      color: context.textPrimary,
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
                        Text(
                          author['nickname'] as String? ?? '',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: r.fs(11),
                          ),
                        ),
                        SizedBox(width: r.s(8)),
                      ],
                      Icon(Icons.favorite_rounded,
                          color: context.textHint, size: r.s(11)),
                      SizedBox(width: r.s(2)),
                      Text(
                        '$likesCount',
                        style: TextStyle(
                            color: context.textHint, fontSize: r.fs(11)),
                      ),
                      SizedBox(width: r.s(8)),
                      Icon(Icons.comment_rounded,
                          color: context.textHint, size: r.s(11)),
                      SizedBox(width: r.s(2)),
                      Text(
                        '$commentsCount',
                        style: TextStyle(
                            color: context.textHint, fontSize: r.fs(11)),
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
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : _members.isEmpty
                ? _buildNoResults(r, s.noMemberFound)
                : ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: r.s(8)),
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

    return InkWell(
      onTap: () => context.push('/user/${member["id"]}'),
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
                  Text(
                    nickname,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: r.s(2)),
                  Text(
                    s.levelAndRep(level, reputation),
                    style: TextStyle(
                        color: context.textSecondary, fontSize: r.fs(12)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: context.textHint, size: r.s(20)),
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
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : _wikis.isEmpty
                ? _buildNoResults(r, 'Nenhum artigo wiki encontrado')
                : ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: r.s(8)),
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
        content.length > 80 ? '${content.substring(0, 80)}...' : content;

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
            Container(
              width: r.s(40),
              height: r.s(40),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(r.s(8)),
              ),
              child: Icon(Icons.article_rounded,
                  color: AppTheme.primaryColor, size: r.s(20)),
            ),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: r.s(4)),
                  Text(
                    preview,
                    style: TextStyle(
                        color: context.textSecondary, fontSize: r.fs(12)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (author != null) ...[
                    SizedBox(height: r.s(4)),
                    Text(
                      'por ${author?["nickname"] ?? ""}',
                      style: TextStyle(
                          color: context.textHint, fontSize: r.fs(11)),
                    ),
                  ],
                ],
              ),
            ),
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
          Icon(Icons.search_rounded, color: context.textHint, size: r.s(48)),
          SizedBox(height: r.s(12)),
          Text(
            message,
            style: TextStyle(color: context.textSecondary, fontSize: r.fs(14)),
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
                      color: context.textPrimary,
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
                        .map((s) => GestureDetector(
                              onTap: () => _selectSuggestion(s),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.s(12), vertical: r.s(6)),
                                decoration: BoxDecoration(
                                  color: context.cardBg,
                                  borderRadius: BorderRadius.circular(r.s(16)),
                                ),
                                child: Text(
                                  s,
                                  style: TextStyle(
                                      color: context.textSecondary,
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
              color: context.textHint, size: r.s(48)),
          SizedBox(height: r.s(12)),
          Text(
            message,
            style: TextStyle(color: context.textSecondary, fontSize: r.fs(14)),
          ),
          SizedBox(height: r.s(6)),
          Text(
            'para "$_query"',
            style: TextStyle(
                color: context.textHint,
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

class _FilterChip extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(4)),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: r.s(14)),
            SizedBox(width: r.s(4)),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: r.fs(12),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: r.s(2)),
            Icon(Icons.arrow_drop_down_rounded,
                color: AppTheme.primaryColor, size: r.s(16)),
          ],
        ),
      ),
    );
  }
}

class _SortOption extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    return ListTile(
      dense: true,
      leading: Icon(icon,
          color: selected ? AppTheme.primaryColor : context.textSecondary,
          size: r.s(20)),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppTheme.primaryColor : context.textPrimary,
          fontSize: r.fs(14),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_rounded,
              color: AppTheme.primaryColor, size: r.s(18))
          : null,
      onTap: onTap,
    );
  }
}

class _PostTypeBadge extends ConsumerWidget {
  final String type;
  final Responsive r;

  const _PostTypeBadge({required this.type, required this.r});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
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
