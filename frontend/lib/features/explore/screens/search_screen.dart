import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Busca Global — Pesquisa por comunidades, usuários, posts e wiki.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String _query = '';

  List<Map<String, dynamic>> _communities = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _communities = [];
        _users = [];
        _posts = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final pattern = '%${query.trim()}%';

      // Buscar comunidades
      final commRes = await SupabaseService.table('communities')
          .select()
          .ilike('name', pattern)
          .limit(20);
      _communities = List<Map<String, dynamic>>.from(commRes as List);

      // Buscar usuários
      final userRes = await SupabaseService.table('profiles')
          .select()
          .ilike('nickname', pattern)
          .limit(20);
      _users = List<Map<String, dynamic>>.from(userRes as List);

      // Buscar posts
      final postRes = await SupabaseService.table('posts')
          .select('*, profiles!posts_author_id_fkey(nickname, icon_url)')
          .ilike('title', pattern)
          .order('created_at', ascending: false)
          .limit(20);
      _posts = List<Map<String, dynamic>>.from(postRes as List);

      if (mounted) setState(() => _isSearching = false);
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (v) {
              _query = v;
              _performSearch(v);
            },
            decoration: InputDecoration(
              hintText: 'Buscar comunidades, pessoas, posts...',
              hintStyle: const TextStyle(
                  color: AppTheme.textHint, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppTheme.textHint, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: [
            Tab(text: 'Comunidades (${_communities.length})'),
            Tab(text: 'Pessoas (${_users.length})'),
            Tab(text: 'Posts (${_posts.length})'),
          ],
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _query.isEmpty
              ? _buildEmptyState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCommunityResults(),
                    _buildUserResults(),
                    _buildPostResults(),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_rounded,
              size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          const Text('Busque por comunidades, pessoas ou posts',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCommunityResults() {
    if (_communities.isEmpty) {
      return const Center(
        child: Text('Nenhuma comunidade encontrada',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _communities.length,
      itemBuilder: (context, index) {
        final c = _communities[index];
        return ListTile(
          onTap: () => context.push('/community/${c['id']}'),
          leading: CircleAvatar(
            backgroundImage: c['icon_url'] != null
                ? CachedNetworkImageProvider(c['icon_url'] as String)
                : null,
            child: c['icon_url'] == null
                ? const Icon(Icons.groups_rounded)
                : null,
          ),
          title: Text(c['name'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${c['members_count'] ?? 0} membros',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12),
          ),
        );
      },
    );
  }

  Widget _buildUserResults() {
    if (_users.isEmpty) {
      return const Center(
        child: Text('Nenhum usuário encontrado',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final u = _users[index];
        return ListTile(
          onTap: () => context.push('/user/${u['id']}'),
          leading: CircleAvatar(
            backgroundImage: u['icon_url'] != null
                ? CachedNetworkImageProvider(u['icon_url'] as String)
                : null,
            child: u['icon_url'] == null
                ? const Icon(Icons.person_rounded)
                : null,
          ),
          title: Text(u['nickname'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            'Nível ${u['level'] ?? 1}',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12),
          ),
        );
      },
    );
  }

  Widget _buildPostResults() {
    if (_posts.isEmpty) {
      return const Center(
        child: Text('Nenhum post encontrado',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final p = _posts[index];
        final author = p['profiles'] as Map<String, dynamic>?;
        return ListTile(
          onTap: () => context.push('/post/${p['id']}'),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.article_rounded,
                color: AppTheme.primaryColor, size: 22),
          ),
          title: Text(p['title'] as String? ?? 'Post',
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: Text(
            'por ${author?['nickname'] ?? 'Anônimo'}',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12),
          ),
        );
      },
    );
  }
}
