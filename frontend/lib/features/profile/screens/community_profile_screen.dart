import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/comment_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../chat/widgets/chat_bubble.dart';
import '../../../core/widgets/amino_custom_title.dart';

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

    final reputation = _membership?['local_reputation'] as int? ?? 0;
    final level = _membership?['local_level'] as int? ?? calculateLevel(reputation);
    final progress = levelProgress(reputation);
    final repToNext = reputationToNextLevel(reputation);
    final title = levelTitle(level);
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

                        // Level badge + Level title (estilo Amino: Lv13 Best Wizzard)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Level number badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
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
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '$level',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Level title (ex: Explorador, Mestre)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Role badge (Líder/Curador) separado
                        if (roleTitle != null) ...[                          
                          const SizedBox(height: 4),
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
                        const SizedBox(height: 8),

                        // Custom titles (tags/chips)
                        if (titles.isNotEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            child: AminoCustomTitleList(
                              titles: titles,
                              maxVisible: 6,
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
                                onTap: () async {
                                  // Toggle follow
                                  try {
                                    final currentUserId = SupabaseService.currentUserId;
                                    if (currentUserId == null) return;
                                    final existing = await SupabaseService.table('follows')
                                        .select('id')
                                        .eq('follower_id', currentUserId)
                                        .eq('following_id', widget.userId)
                                        .maybeSingle();
                                    if (existing != null) {
                                      await SupabaseService.table('follows')
                                          .delete()
                                          .eq('follower_id', currentUserId)
                                          .eq('following_id', widget.userId);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Deixou de seguir')),
                                        );
                                      }
                                    } else {
                                      await SupabaseService.table('follows').insert({
                                        'follower_id': currentUserId,
                                        'following_id': widget.userId,
                                      });
                                      try {
                                        await SupabaseService.rpc('add_reputation', params: {
                                          'p_community_id': widget.communityId,
                                          'p_user_id': currentUserId,
                                          'p_action': 'follow',
                                          'p_source_id': widget.userId,
                                        });
                                      } catch (_) {}
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Seguindo!')),
                                        );
                                      }
                                    }
                                    _loadProfile();
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Erro: $e')),
                                      );
                                    }
                                  }
                                },
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
                                onTap: () async {
                                  // Criar ou abrir DM com o usuário
                                  try {
                                    final currentUserId = SupabaseService.currentUserId;
                                    if (currentUserId == null) return;
                                    // Verificar se já existe DM
                                    final existing = await SupabaseService.table('chat_threads')
                                        .select('id')
                                        .eq('type', 'dm')
                                        .eq('community_id', widget.communityId)
                                        .or('created_by.eq.$currentUserId,created_by.eq.${widget.userId}')
                                        .maybeSingle();
                                    if (existing != null) {
                                      if (mounted) context.push('/community/${widget.communityId}/chat/${existing['id']}');
                                    } else {
                                      // Criar novo DM
                                      final newThread = await SupabaseService.table('chat_threads')
                                          .insert({
                                            'community_id': widget.communityId,
                                            'type': 'dm',
                                            'created_by': currentUserId,
                                            'title': 'DM',
                                          })
                                          .select()
                                          .single();
                                      // Adicionar ambos como membros
                                      await SupabaseService.table('chat_members').insert([
                                        {'thread_id': newThread['id'], 'user_id': currentUserId},
                                        {'thread_id': newThread['id'], 'user_id': widget.userId},
                                      ]);
                                      if (mounted) context.push('/community/${widget.communityId}/chat/${newThread['id']}');
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Erro ao abrir chat: $e')),
                                      );
                                    }
                                  }
                                },
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
                    onTap: () {
                      // Navegar para tela de conquistas
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Conquistas em breve!'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
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
  List<Map<String, dynamic>> _savedPosts = [];
  bool _savedPostsLoaded = false;

  Future<void> _loadSavedPosts() async {
    if (_savedPostsLoaded) return;
    try {
      final res = await SupabaseService.table('bookmarks')
          .select('*, posts!bookmarks_post_id_fkey(*, profiles!posts_author_id_fkey(nickname, icon_url))')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _savedPosts = List<Map<String, dynamic>>.from(res as List);
          _savedPostsLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _savedPostsLoaded = true);
    }
  }

  Widget _buildSavedPostsTab() {
    if (!_savedPostsLoaded) {
      _loadSavedPosts();
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (!_isOwnProfile) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text('Posts salvos são privados',
                style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (_savedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_outline_rounded, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text('Nenhum post salvo',
                style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Toque no ícone de bookmark nos posts para salvá-los',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _savedPosts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final bookmark = _savedPosts[index];
        final post = bookmark['posts'] as Map<String, dynamic>? ?? {};
        final author = post['profiles'] as Map<String, dynamic>?;
        final postId = post['id'] as String?;

        return GestureDetector(
          onTap: () {
            if (postId != null) context.push('/post/$postId');
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                if (post['cover_image_url'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: post['cover_image_url'] as String,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (post['cover_image_url'] != null) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['title'] as String? ?? 'Sem título',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'por ${author?['nickname'] ?? 'Usuário'}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark_rounded,
                      color: AppTheme.primaryColor, size: 20),
                  onPressed: () async {
                    try {
                      await SupabaseService.table('bookmarks')
                          .delete()
                          .eq('id', bookmark['id']);
                      setState(() => _savedPosts.removeAt(index));
                    } catch (_) {}
                  },
                ),
              ],
            ),
          ),
        );
      },
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
