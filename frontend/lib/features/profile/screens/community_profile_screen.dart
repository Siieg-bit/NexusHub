import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/comment_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../chat/widgets/chat_bubble.dart';

/// Perfil da Comunidade — Layout fiel ao Amino Apps.
/// Banner + Avatar centralizado + Nome + Nível/Título + Tags + Editar
/// Conquistas + Moedas + Stats (Reputação/Seguindo/Seguidores)
/// Bio com "Membro desde..." + Tabs: Posts | Mural | Posts Salvos
class CommunityProfileScreen extends StatefulWidget {
  final String userId;
  final String communityId;

  const CommunityProfileScreen({
    super.key,
    required this.userId,
    required this.communityId,
  });

  @override
  State<CommunityProfileScreen> createState() =>
      _CommunityProfileScreenState();
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
  int _followersCount = 0;
  int _followingCount = 0;

  bool get _isOwnProfile =>
      widget.userId == SupabaseService.currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      // Perfil global
      final userRes = await SupabaseService.table('profiles')
          .select()
          .eq('id', widget.userId)
          .single();
      _user = UserModel.fromJson(userRes);

      // Membership na comunidade
      final memberRes = await SupabaseService.table('community_members')
          .select()
          .eq('user_id', widget.userId)
          .eq('community_id', widget.communityId)
          .maybeSingle();
      _membership = memberRes;

      // Posts do usuário na comunidade
      final postsRes = await SupabaseService.table('posts')
          .select('*, profiles(*)')
          .eq('author_id', widget.userId)
          .eq('community_id', widget.communityId)
          .eq('status', 'published')
          .order('created_at', ascending: false)
          .limit(20);
      _userPosts = List<Map<String, dynamic>>.from(postsRes as List);

      // Mural (wall comments)
      final wallRes = await SupabaseService.table('comments')
          .select('*, profiles(*)')
          .eq('profile_wall_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(30);
      _wallComments =
          (wallRes as List).map((e) => CommentModel.fromJson(e)).toList();

      // Contagem de seguidores/seguindo
      final followersRes = await SupabaseService.table('follows')
          .select()
          .eq('following_id', widget.userId);
      _followersCount = (followersRes as List).length;

      final followingRes = await SupabaseService.table('follows')
          .select()
          .eq('follower_id', widget.userId);
      _followingCount = (followingRes as List).length;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _wallController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: Center(
            child: CircularProgressIndicator(
                color: AppTheme.primaryColor, strokeWidth: 2)),
      );
    }

    final xp = _membership?['xp'] as int? ?? 0;
    final reputation = _membership?['local_reputation'] as int? ?? 0;
    final level = _membership?['local_level'] as int? ?? calculateLevel(xp);
    final role = _membership?['role'] as String? ?? 'member';
    final titles = (_membership?['custom_titles'] as List<dynamic>?) ?? [];
    final streak = _membership?['consecutive_checkin_days'] as int? ?? 0;
    final localNickname = _membership?['local_nickname'] as String?;
    final localIconUrl = _membership?['local_icon_url'] as String?;
    final localBannerUrl = _membership?['local_banner_url'] as String?;
    final localBio = _membership?['local_bio'] as String?;
    final joinedAt = _membership?['joined_at'] != null
        ? DateTime.tryParse(_membership!['joined_at'] as String)
        : null;
    final coins = _user?.coins ?? 0;
    final isOnline = _user?.isOnline ?? false;
    final displayName = localNickname ?? _user?.nickname ?? 'Usuário';
    final displayAvatar = localIconUrl ?? _user?.iconUrl;
    final displayBanner = localBannerUrl ?? _user?.bannerUrl;
    final displayBio = localBio ?? _user?.bio ?? '';

    // Título do cargo (role title)
    String? roleTitle;
    if (role == 'leader' || role == 'agent') {
      roleTitle = 'Líder';
    } else if (role == 'curator') {
      roleTitle = 'Curador';
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ==================================================================
          // HEADER — Banner + Avatar + Nome + Level + Tags + Editar
          // ==================================================================
          SliverAppBar(
            expandedHeight: 420,
            pinned: true,
            backgroundColor: AppTheme.scaffoldBg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => context.pop(),
            ),
            actions: [
              // Online indicator
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey[600],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline ? Colors.white : Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded,
                    color: Colors.white, size: 22),
                onPressed: () => _showOptions(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Banner background
                  if (displayBanner != null)
                    CachedNetworkImage(
                      imageUrl: displayBanner,
                      fit: BoxFit.cover,
                      color: Colors.black.withValues(alpha: 0.3),
                      colorBlendMode: BlendMode.darken,
                      errorWidget: (_, __, ___) => _defaultBannerGradient(),
                    )
                  else
                    _defaultBannerGradient(),

                  // Gradient overlay (fade to scaffoldBg at bottom)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 180,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppTheme.scaffoldBg.withValues(alpha: 0.8),
                            AppTheme.scaffoldBg,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Profile content over banner
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        // Avatar centralizado
                        AvatarWithFrame(
                          avatarUrl: displayAvatar,
                          size: 96,
                          showAminoPlus: _user?.isPremium ?? false,
                        ),
                        const SizedBox(height: 10),

                        // Nome
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),

                        // Level badge + Role title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Level badge (hexagonal style)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.getLevelColor(level),
                                    AppTheme.getLevelColor(level)
                                        .withValues(alpha: 0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Lv',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '$level',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (roleTitle != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  roleTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Custom titles (tags/chips)
                        if (titles.isNotEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              alignment: WrapAlignment.center,
                              children: [
                                ...titles.take(6).map((t) {
                                  final titleText =
                                      t is Map ? (t['title'] ?? '') : t.toString();
                                  final titleColor = t is Map && t['color'] != null
                                      ? _parseColor(t['color'] as String)
                                      : AppTheme.primaryColor
                                          .withValues(alpha: 0.3);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: titleColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      titleText,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }),
                                if (titles.length > 6)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.more_horiz,
                                        color: Colors.white, size: 14),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),

                        // Botão Editar / Friends+Chat
                        if (_isOwnProfile)
                          GestureDetector(
                            onTap: () => context.push(
                                '/community/${widget.communityId}/profile/edit'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_rounded,
                                      size: 14, color: Colors.grey[300]),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Editar',
                                    style: TextStyle(
                                      color: Colors.grey[200],
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () {/* TODO: Add friend */},
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9800),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('😊',
                                          style: TextStyle(fontSize: 14)),
                                      SizedBox(width: 6),
                                      Text(
                                        'Friends',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () {/* TODO: Open chat */},
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.chat_bubble_rounded,
                                          size: 14,
                                          color: Colors.grey[300]),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Chat',
                                        style: TextStyle(
                                          color: Colors.grey[200],
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ==================================================================
          // CONQUISTAS + MOEDAS BAR
          // ==================================================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Conquistas badge
                  GestureDetector(
                    onTap: () {/* TODO: Achievements */},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🏆',
                              style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          const Text(
                            'Conquistas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (streak > 0) ...[
                            const SizedBox(width: 4),
                            const Text('❗',
                                style: TextStyle(fontSize: 10)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Moedas badge
                  GestureDetector(
                    onTap: () => context.push('/wallet'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2196F3), Color(0xFF42A5F5)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFFFA500)
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Text('A',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      height: 1.0)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatCount(coins),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add,
                                color: Colors.white, size: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ==================================================================
          // STATS — 3 colunas: Reputação | Seguindo | Seguidores
          // ==================================================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          formatCount(reputation),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Reputação',
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          context.push('/following/${widget.userId}'),
                      child: Column(
                        children: [
                          Text(
                            formatCount(_followingCount),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Seguindo',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          context.push('/followers/${widget.userId}'),
                      child: Column(
                        children: [
                          Text(
                            formatCount(_followersCount),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Seguidores',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ==================================================================
          // BIO SECTION — "Biografia" + "Membro desde..."
          // ==================================================================
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(
                  top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "Biografia" + "Membro desde..."
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text(
                        'Biografia',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (joinedAt != null)
                        Expanded(
                          child: Text(
                            _memberSinceText(joinedAt),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Bio text
                  if (displayBio.isNotEmpty)
                    Text(
                      displayBio,
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                        height: 1.5,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (_isOwnProfile)
                    GestureDetector(
                      onTap: () => context.push(
                          '/community/${widget.communityId}/profile/edit'),
                      child: const Text(
                        'Clique aqui para adicionar sua biografia!',
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    Text(
                      'Sem biografia',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13),
                    ),
                ],
              ),
            ),
          ),

          // ==================================================================
          // TABS — Posts | Mural | Posts Salvos
          // ==================================================================
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.grey[500],
                indicatorColor: AppTheme.primaryColor,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14),
                tabs: [
                  Tab(
                    child: Text(
                        'Posts ${_userPosts.isNotEmpty ? _userPosts.length : ''}'),
                  ),
                  Tab(
                    child: Text(
                        'Mural ${_wallComments.isNotEmpty ? _wallComments.length : ''}'),
                  ),
                  const Tab(text: 'Posts Salvos'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostsTab(),
            _buildWallTab(),
            _buildSavedPostsTab(),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // POSTS TAB
  // ============================================================================
  Widget _buildPostsTab() {
    return Column(
      children: [
        // "Criar nova publicação" button
        if (_isOwnProfile)
          GestureDetector(
            onTap: () => context.push('/community/${widget.communityId}/post/create'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(
                  bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Criar nova publicação',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Posts list
        Expanded(
          child: _userPosts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined,
                          size: 48, color: Colors.grey[700]),
                      const SizedBox(height: 12),
                      Text('Nenhum post nesta comunidade',
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : ListView.builder(
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
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  Colors.white.withValues(alpha: 0.05)),
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
                            if (post['content'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                post['content'] as String,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.favorite_rounded,
                                    size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                    '${post['likes_count'] ?? 0}',
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 14),
                                Icon(Icons.comment_rounded,
                                    size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                    '${post['comments_count'] ?? 0}',
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ============================================================================
  // WALL TAB
  // ============================================================================
  Widget _buildWallTab() {
    return Column(
      children: [
        // Input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(
              bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wallController,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Escreva no mural...',
                    hintStyle:
                        TextStyle(color: Colors.grey[600], fontSize: 14),
                    filled: true,
                    fillColor: AppTheme.scaffoldBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _postWallComment,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
        // Comments list
        Expanded(
          child: _wallComments.isEmpty
              ? Center(
                  child: Text('Nenhum comentário no mural',
                      style: TextStyle(color: Colors.grey[500])),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _wallComments.length,
                  itemBuilder: (context, index) {
                    final comment = _wallComments[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => context.push(
                                '/user/${comment.authorId}'),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppTheme.scaffoldBg,
                              backgroundImage:
                                  comment.author?.iconUrl != null
                                      ? CachedNetworkImageProvider(
                                          comment.author!.iconUrl!)
                                      : null,
                              child: comment.author?.iconUrl == null
                                  ? const Icon(Icons.person_rounded,
                                      size: 18,
                                      color: AppTheme.textPrimary)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment.author?.nickname ?? 'Anônimo',
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  comment.content,
                                  style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: 13,
                                      height: 1.4),
                                ),
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

  // ============================================================================
  // SAVED POSTS TAB
  // ============================================================================
  Widget _buildSavedPostsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_outline_rounded,
              size: 48, color: Colors.grey[700]),
          const SizedBox(height: 12),
          Text('Posts salvos aparecerão aqui',
              style: TextStyle(
                  color: Colors.grey[500], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  Widget _defaultBannerGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.6),
            AppTheme.scaffoldBg,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  String _memberSinceText(DateTime joinedAt) {
    final months = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
    ];
    final days = DateTime.now().difference(joinedAt).inDays;
    return 'Membro desde ${months[joinedAt.month - 1]} ${joinedAt.year} ($days dias)';
  }

  Color _parseColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return AppTheme.primaryColor.withValues(alpha: 0.3);
    }
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
      final wallRes = await SupabaseService.table('comments')
          .select('*, profiles(*)')
          .eq('profile_wall_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(30);
      setState(() {
        _wallComments = (wallRes as List)
            .map((e) => CommentModel.fromJson(e))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (!_isOwnProfile) ...[
              _optionTile(Icons.flag_rounded, 'Denunciar', () {
                Navigator.pop(ctx);
              }, isDestructive: true),
              _optionTile(Icons.block_rounded, 'Bloquear', () {
                Navigator.pop(ctx);
              }, isDestructive: true),
            ],
            _optionTile(Icons.share_rounded, 'Compartilhar Perfil', () {
              Navigator.pop(ctx);
            }),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(IconData icon, String label, VoidCallback onTap,
      {bool isDestructive = false}) {
    final color = isDestructive ? AppTheme.errorColor : Colors.grey[400];
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TAB BAR DELEGATE
// =============================================================================
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
      color: AppTheme.surfaceColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
