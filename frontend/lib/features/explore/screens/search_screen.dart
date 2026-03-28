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
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        titleSpacing: 0,
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary),
            onChanged: (v) {
              _query = v;
              _performSearch(v);
            },
            decoration: InputDecoration(
              hintText: 'Buscar comunidades, pessoas, posts...',
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.grey[500], size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey[500]),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Comunidades (${_communities.length})'),
            Tab(text: 'Pessoas (${_users.length})'),
            Tab(text: 'Posts (${_posts.length})'),
          ],
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
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
          Icon(Icons.search_rounded, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text('Busque por comunidades, pessoas ou posts',
              style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildCommunityResults() {
    if (_communities.isEmpty) {
      return Center(
        child: Text('Nenhuma comunidade encontrada',
            style: TextStyle(color: Colors.grey[500])),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _communities.length,
      itemBuilder: (context, index) {
        final c = _communities[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () => context.push('/community/${c['id']}'),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                image: c['icon_url'] != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(c['icon_url'] as String),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: c['icon_url'] == null
                  ? const Icon(Icons.groups_rounded, color: AppTheme.primaryColor)
                  : null,
            ),
            title: Text(c['name'] as String? ?? '',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${c['members_count'] ?? 0} membros',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserResults() {
    if (_users.isEmpty) {
      return Center(
        child: Text('Nenhum usuário encontrado',
            style: TextStyle(color: Colors.grey[500])),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final u = _users[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () => context.push('/user/${u['id']}'),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              backgroundImage: u['icon_url'] != null
                  ? CachedNetworkImageProvider(u['icon_url'] as String)
                  : null,
              child: u['icon_url'] == null
                  ? const Icon(Icons.person_rounded, color: AppTheme.primaryColor)
                  : null,
            ),
            title: Text(u['nickname'] as String? ?? '',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Nível ${u['level'] ?? 1}',
                style: const TextStyle(color: AppTheme.accentColor, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostResults() {
    if (_posts.isEmpty) {
      return Center(
        child: Text('Nenhum post encontrado',
            style: TextStyle(color: Colors.grey[500])),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final p = _posts[index];
        final author = p['profiles'] as Map<String, dynamic>?;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () => context.push('/post/${p['id']}'),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.article_rounded,
                  color: AppTheme.primaryColor, size: 24),
            ),
            title: Text(p['title'] as String? ?? 'Post',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'por ${author?['nickname'] ?? 'Anônimo'}',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          ),
        );
      },
    );
  }
}
