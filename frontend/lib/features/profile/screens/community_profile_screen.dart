import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/comment_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../chat/widgets/chat_bubble.dart';

/// Perfil da Comunidade — exibe Nível, Reputação, Títulos Customizados,
/// Streak Bar e The Wall (mural de comentários).
class CommunityProfileScreen extends StatefulWidget {
  final String userId;
  final String communityId;

  const CommunityProfileScreen({
    super.key,
    required this.userId,
    required this.communityId,
  });

  @override
  State<CommunityProfileScreen> createState() => _CommunityProfileScreenState();
}

class _CommunityProfileScreenState extends State<CommunityProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserModel? _user;
  Map<String, dynamic>? _membership;
  List<CommentModel> _wallComments = [];
  List<Map<String, dynamic>> _userPosts = [];
  bool _isLoading = true;
  final _wallController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      // Carregar perfil do usuário
      final userRes = await SupabaseService.table('profiles')
          .select()
          .eq('id', widget.userId)
          .single();
      _user = UserModel.fromJson(userRes);

      // Carregar membership na comunidade
      final memberRes = await SupabaseService.table('community_members')
          .select()
          .eq('user_id', widget.userId)
          .eq('community_id', widget.communityId)
          .maybeSingle();
      _membership = memberRes;

      // Carregar posts do usuário na comunidade
      final postsRes = await SupabaseService.table('posts')
          .select('*, profiles(*)')
          .eq('author_id', widget.userId)
          .eq('community_id', widget.communityId)
          .order('created_at', ascending: false)
          .limit(20);
      _userPosts = List<Map<String, dynamic>>.from(postsRes as List);

      // Carregar comentários do mural (The Wall)
      final wallRes = await SupabaseService.table('comments')
          .select('*, profiles(*)')
          .eq('profile_wall_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(30);
      _wallComments =
          (wallRes as List).map((e) => CommentModel.fromJson(e)).toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    final xp = _membership?['xp'] as int? ?? 0;
    final reputation = _membership?['reputation'] as int? ?? 0;
    final level = calculateLevel(xp);
    final progress = levelProgress(xp);
    final role = _membership?['role'] as String? ?? 'member';
    final titles = (_membership?['custom_titles'] as List<dynamic>?) ?? [];
    final streak = _membership?['check_in_streak'] as int? ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // ============================================================
          // HEADER
          // ============================================================
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.scaffoldBg,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.8),
                          AppTheme.scaffoldBg,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Conteúdo do perfil
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      children: [
                        // Avatar com Frame
                        AvatarWithFrame(
                          avatarUrl: _user?.iconUrl,
                          size: 88,
                          showAminoPlus: _user?.isPremium ?? false,
                        ),
                        const SizedBox(height: 12),
                        // Nome + Role badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _user?.nickname ?? 'Usuário',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (role != 'member') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  role.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Títulos customizados
                        if (titles.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            children: titles
                                .map((t) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceColor,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                      ),
                                      child: Text(
                                        t.toString(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        const SizedBox(height: 12),
                        // Level + Reputation + Streak
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatBadge(label: 'Nível', value: level.toString()),
                            _StatBadge(
                                label: 'Reputação',
                                value: formatCount(reputation)),
                            _StatBadge(label: 'Streak', value: '$streak dias'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Level progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            valueColor:
                                const AlwaysStoppedAnimation(AppTheme.primaryColor),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ============================================================
          // STREAK BAR
          // ============================================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: StreakBar(
                currentStreak: streak,
                maxStreak: _membership?['max_streak'] as int? ?? 0,
                checkInDays: _membership?['total_check_ins'] as int? ?? 0,
              ),
            ),
          ),

          // ============================================================
          // TABS
          // ============================================================
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.grey[500],
                indicatorColor: AppTheme.primaryColor,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Posts'),
                  Tab(text: 'The Wall'),
                  Tab(text: 'Sobre'),
                ],
              ),
            ),
          ),

          // ============================================================
          // TAB CONTENT
          // ============================================================
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(),
                _buildWallTab(),
                _buildAboutTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab() {
    if (_userPosts.isEmpty) {
      return Center(
        child: Text('Nenhum post nesta comunidade',
            style: TextStyle(color: Colors.grey[500])),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        return GestureDetector(
          onTap: () => context.push('/post/${post['id']}'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post['title'] != null)
                  Text(
                    post['title'] as String,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700, 
                        fontSize: 15),
                  ),
                const SizedBox(height: 4),
                Text(
                  post['content'] as String? ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.favorite_rounded,
                        size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('${post['likes_count'] ?? 0}',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    Icon(Icons.comment_rounded,
                        size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('${post['comments_count'] ?? 0}',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWallTab() {
    return Column(
      children: [
        // Input para novo comentário
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wallController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Escreva no mural...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppTheme.primaryColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _postWallComment(),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.accentColor],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
        // Lista de comentários
        Expanded(
          child: _wallComments.isEmpty
              ? Center(
                  child: Text('Nenhum comentário no mural',
                      style: TextStyle(color: Colors.grey[500])),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _wallComments.length,
                  itemBuilder: (context, index) {
                    final comment = _wallComments[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.scaffoldBg,
                            backgroundImage: comment.author?.iconUrl != null
                                ? CachedNetworkImageProvider(
                                    comment.author!.iconUrl!)
                                : null,
                            child: comment.author?.iconUrl == null
                                ? const Icon(Icons.person_rounded, size: 20, color: AppTheme.textPrimary)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment.author?.nickname ?? 'Anônimo',
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(comment.content,
                                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAboutTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_user != null && _user!.bio.isNotEmpty) ...[
          const Text('Bio', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(_user!.bio,
              style:
                  TextStyle(color: Colors.grey[500], height: 1.5, fontSize: 14)),
          const SizedBox(height: 24),
        ],
        const Text('Informações', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              _InfoRow(label: 'Amino ID', value: _user?.aminoId ?? 'Não definido'),
              const Divider(color: Colors.white10, height: 24),
              _InfoRow(
                  label: 'Entrou em',
                  value: _membership?['joined_at'] != null
                      ? _formatDate(
                          DateTime.parse(_membership!['joined_at'] as String))
                      : '--'),
              const Divider(color: Colors.white10, height: 24),
              _InfoRow(label: 'Posts', value: _userPosts.length.toString()),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _postWallComment() async {
    final text = _wallController.text.trim();
    if (text.isEmpty) return;
    try {
      await SupabaseService.table('comments').insert({
        'author_id': SupabaseService.currentUserId,
        'profile_wall_id': widget.userId,
        'content': text,
      });
      _wallController.clear();
      // Reload wall comments
      final wallRes = await SupabaseService.table('comments')
          .select('*, profiles(*)')
          .eq('profile_wall_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(30);
      setState(() {
        _wallComments =
            (wallRes as List).map((e) => CommentModel.fromJson(e)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// ============================================================================
// WIDGETS AUXILIARES
// ============================================================================

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.scaffoldBg,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
