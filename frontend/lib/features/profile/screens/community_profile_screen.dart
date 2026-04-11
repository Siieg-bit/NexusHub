import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/providers/dm_invite_provider.dart';
import '../../chat/widgets/chat_bubble.dart'; // AvatarWithFrame + AminoPlusBadge
import '../../../core/widgets/amino_custom_title.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/amino_bottom_nav.dart';
import '../../communities/widgets/community_create_menu.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/providers/block_provider.dart';
import '../widgets/wall_comment_sheet.dart';
import '../../moderation/widgets/member_role_manager.dart';

/// Perfil dentro de uma Comunidade — Layout 1:1 com Amino Apps.
///
/// Estrutura:
///   SliverAppBar expandível (banner + avatar + nome + level + tags + botões
///     + conquistas/moedas bar — tudo dentro do FlexibleSpaceBar)
///   Stats 3 colunas: Reputação | Seguindo | Seguidores
///   Bio com "Membro desde..." + seta para expandir
///   Tabs: Posts | Mural | Posts Salvos
///   FAB roxo para criar publicação (apenas próprio perfil)
class CommunityProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final String communityId;

  const CommunityProfileScreen({
    super.key,
    required this.userId,
    required this.communityId,
  });

  @override
  ConsumerState<CommunityProfileScreen> createState() => _CommunityProfileScreenState();
}

class _CommunityProfileScreenState extends ConsumerState<CommunityProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserModel? _user;
  Map<String, dynamic>? _membership;
  List<Map<String, dynamic>> _userPosts = [];
  List<Map<String, dynamic>> _wikiEntries = [];
  List<Map<String, dynamic>> _savedPosts = [];
  bool _isInitialLoading = true;
  bool _savedPostsLoaded = false;
  bool _bioExpanded = false;
  bool _viewerIsTeamMember = false;
  int _followersCount = 0;
  int _followingCount = 0;
  String _communityName = '';
  String? _communityBannerUrl;

  bool get _isOwnProfile => widget.userId == SupabaseService.currentUserId;
  Map<String, dynamic>? _myMembership; // membership do usuário logado na comunidade

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

      // Nome da comunidade
      try {
        final communityRes = await SupabaseService.table('communities')
            .select('name, banner_url')
            .eq('id', widget.communityId)
            .single();
        _communityName = communityRes['name'] as String? ?? '';
        _communityBannerUrl = communityRes['banner_url'] as String?;
      } catch (e) {
        debugPrint('[community_profile_screen.dart] $e');
      }

      // Membership na comunidade (do usuário alvo)
      final memberRes = await SupabaseService.table('community_members')
          .select()
          .eq('user_id', widget.userId)
          .eq('community_id', widget.communityId)
          .maybeSingle();

      if (_isOwnProfile && memberRes != null) {
        final profileSeed = <String, dynamic>{};
        final localNickname = (memberRes['local_nickname'] as String?)?.trim();
        final localBio = (memberRes['local_bio'] as String?)?.trim();
        final localIconUrl = (memberRes['local_icon_url'] as String?)?.trim();
        final localBannerUrl = (memberRes['local_banner_url'] as String?)?.trim();

        if ((localNickname == null || localNickname.isEmpty) &&
            (_user?.nickname.trim().isNotEmpty ?? false)) {
          profileSeed['local_nickname'] = _user!.nickname.trim();
        }
        if ((localBio == null || localBio.isEmpty) &&
            (_user?.bio.trim().isNotEmpty ?? false)) {
          profileSeed['local_bio'] = _user!.bio.trim();
        }
        if ((localIconUrl == null || localIconUrl.isEmpty) &&
            (_user?.iconUrl?.trim().isNotEmpty ?? false)) {
          profileSeed['local_icon_url'] = _user!.iconUrl!.trim();
        }
        if ((localBannerUrl == null || localBannerUrl.isEmpty) &&
            (_user?.bannerUrl?.trim().isNotEmpty ?? false)) {
          profileSeed['local_banner_url'] = _user!.bannerUrl!.trim();
        }

        if (profileSeed.isNotEmpty) {
          try {
            await SupabaseService.table('community_members')
                .update(profileSeed)
                .eq('user_id', widget.userId)
                .eq('community_id', widget.communityId);
            memberRes.addAll(profileSeed);
          } catch (_) {}
        }
      }

      _membership = memberRes;

      // Contexto do usuário logado (para verificar moderação e visibilidade)
      if (!_isOwnProfile) {
        try {
          final myId = SupabaseService.currentUserId;
          if (myId != null) {
            final myMemberRes = await SupabaseService.table('community_members')
                .select('role')
                .eq('user_id', myId)
                .eq('community_id', widget.communityId)
                .maybeSingle();
            _myMembership = myMemberRes;

            final viewerProfileRes = await SupabaseService.table('profiles')
                .select('is_team_admin, is_team_moderator')
                .eq('id', myId)
                .maybeSingle();
            if (viewerProfileRes != null) {
              final viewerProfile = UserModel.fromJson({
                'id': myId,
                ...viewerProfileRes,
              });
              _viewerIsTeamMember = viewerProfile.isTeamMember;
            }
          }
        } catch (_) {}
      }

      // Posts do usuário na comunidade
      final postsRes = await SupabaseService.table('posts')
          .select('*, profiles!posts_author_id_fkey(*), original_author:profiles!posts_original_author_id_fkey(id, nickname, icon_url, online_status), original_post:original_post_id(id, title, content, type, cover_image_url, media_list, created_at, author_id, community_id, original_post_id)')
          .eq('author_id', widget.userId)
          .eq('community_id', widget.communityId)
          .eq('status', 'ok')
          .order('is_pinned_profile', ascending: false)
          .order('created_at', ascending: false)
          .limit(20);
      _userPosts = List<Map<String, dynamic>>.from(postsRes as List? ?? []);

      // Wiki entries do usuário na comunidade
      try {
        final wikiRes = await SupabaseService.table('wiki_entries')
            .select('id, title, cover_image_url')
            .eq('author_id', widget.userId)
            .eq('community_id', widget.communityId)
            .eq('status', 'ok')
            .order('created_at', ascending: false)
            .limit(10);
        _wikiEntries = List<Map<String, dynamic>>.from(wikiRes as List? ?? []);
      } catch (_) {
        _wikiEntries = [];
      }

      // Contagem de seguidores/seguindo
      final followersRes = await SupabaseService.table('follows')
          .select()
          .eq('following_id', widget.userId);
      _followersCount = (followersRes as List?)?.length ?? 0;

      final followingRes = await SupabaseService.table('follows')
          .select()
          .eq('follower_id', widget.userId);
      _followingCount = (followingRes as List?)?.length ?? 0;

      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _savedPostsLoaded = false; // força recarregar posts salvos na próxima vez
      });
    } catch (e) {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    if (_isInitialLoading) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        body: Center(
            child: CircularProgressIndicator(
                color: AppTheme.primaryColor, strokeWidth: 2)),
      );
    }

    final reputation = _membership?['local_reputation'] as int? ?? 0;
    final level =
        _membership?['local_level'] as int? ?? calculateLevel(reputation);
    final title = levelTitle(level);
    final role = _membership?['role'] as String? ?? 'member';
    final titles = (_membership?['custom_titles'] as List<dynamic>?) ?? [];
    final streak = _membership?['consecutive_checkin_days'] as int? ?? 0;
    final localNickname = _membership?['local_nickname'] as String?;
    final localIconUrl = _membership?['local_icon_url'] as String?;
    final localBannerUrl = _membership?['local_banner_url'] as String?;
    final localBio = _membership?['local_bio'] as String?;
    final localBackgroundUrl = _membership?['local_background_url'] as String?;
    final rawGallery = _membership?['local_gallery'] as List<dynamic>?;
    final displayGallery = rawGallery?.map((e) => e.toString()).toList() ?? <String>[];
    final joinedAt = _membership?['joined_at'] != null
        ? DateTime.tryParse(_membership?['joined_at'] as String? ?? '')
        : null;
    final coins = _user?.coins ?? 0;
    final canViewCoins = _isOwnProfile || _viewerIsTeamMember;
    final isOnline = _user?.isOnline ?? false;
    final isPremium = _user?.isPremium ?? false;
    final displayName =
        (localNickname?.trim().isNotEmpty ?? false) ? localNickname!.trim() : (_user?.nickname ?? s.user);
    final displayAvatar =
        (localIconUrl?.trim().isNotEmpty ?? false) ? localIconUrl!.trim() : null;
    final displayBanner =
        (localBannerUrl?.trim().isNotEmpty ?? false) ? localBannerUrl!.trim() : null;
    final displayBio =
        (localBio?.trim().isNotEmpty ?? false) ? localBio!.trim() : '';

    // Título do cargo (role title)
    String? roleTitle;
    if (role == 'leader' || role == 'agent') {
      roleTitle = s.leader;
    } else if (role == 'curator') {
      roleTitle = s.curator;
    }

    // Altura do FlexibleSpaceBar: varia conforme conteúdo
    // Base: 200 (banner) + avatar(96) + nome + level + tags + botões + conquistas
    final double expandedHeight = 420 +
        (titles.isNotEmpty ? r.s(40) : 0) +
        (roleTitle != null ? r.s(28) : 0);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.scaffoldBg,
      floatingActionButton: _isOwnProfile
          ? AminoCommunityFab(
              onTap: () => showCommunityCreateMenu(
                context,
                communityId: widget.communityId,
                communityName: _communityName,
              ),
            )
          : null,
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        backgroundColor: context.surfaceColor,
        onRefresh: _loadProfile,
        edgeOffset: 0,
        displacement: 60,
        notificationPredicate: (notification) => true,
        child: NestedScrollView(
          floatHeaderSlivers: true,
          physics: const AlwaysScrollableScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // ================================================================
            // HEADER — Banner + Avatar + Nome + Level + Tags + Botões
            //          + Conquistas/Moedas (tudo dentro do FlexibleSpaceBar)
            // ================================================================
            SliverAppBar(
              expandedHeight: expandedHeight,
              pinned: true,
              backgroundColor: context.scaffoldBg,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: r.s(20)),
                onPressed: () => context.pop(),
              ),
              actions: [
                // Online indicator — texto direto estilo Amino (sem chip)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: r.s(8),
                      height: r.s(8),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFF4CAF50)
                            : Colors.grey[500],
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: r.s(5)),
                    Text(
                      isOnline ? s.online : s.offline,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: r.s(4)),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.more_horiz_rounded,
                      color: Colors.white, size: r.s(22)),
                  onPressed: () => _showOptions(context),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ── Banner background ──────────────────────────────────
                    if (displayBanner != null)
                      CachedNetworkImage(
                        imageUrl: displayBanner,
                        fit: BoxFit.cover,
                        color: Colors.black.withValues(alpha: 0.25),
                        colorBlendMode: BlendMode.darken,
                        errorWidget: (_, __, ___) => _defaultBannerGradient(),
                      )
                    else
                      _defaultBannerGradient(),

                    // ── Gradient overlay (fade para scaffoldBg na base) ────
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: r.s(200),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              context.scaffoldBg.withValues(alpha: 0.7),
                              context.scaffoldBg,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // ── Conteúdo do perfil (sobre o banner) ────────────────
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Avatar centralizado
                          AvatarWithFrame(
                            avatarUrl: displayAvatar,
                            size: r.s(96),
                            showAminoPlus: isPremium,
                          ),
                          SizedBox(height: r.s(10)),

                          // Nome + badge Amino+
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: r.fs(22),
                                    fontWeight: FontWeight.w800,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 8,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPremium) ...[
                                SizedBox(width: r.s(6)),
                                const AminoPlusBadge(),
                              ],
                            ],
                          ),
                          SizedBox(height: r.s(6)),

                          // Level badge — dois containers separados: [lv13] [Best Wizzard]
                          // Clicável: abre tela de todos os rankings
                          GestureDetector(
                            onTap: () => context.push('/all-rankings', extra: {
                              'level': level,
                              'reputation': reputation,
                              'bannerUrl': _communityBannerUrl,
                            }),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Badge roxo/azul com "lv" + número
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(8), vertical: r.s(4)),
                                  decoration: BoxDecoration(
                                    color: AppTheme.getLevelColor(level),
                                    borderRadius: BorderRadius.circular(r.s(14)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        s.drawerLvLabel,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.85),
                                          fontSize: r.fs(10),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '$level',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: r.fs(14),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: r.s(6)),
                                // Badge cinza escuro com título do level
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(10), vertical: r.s(4)),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(r.s(14)),
                                  ),
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: r.fs(12),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Role badge (Líder/Curador) separado
                          if (roleTitle != null) ...[
                            SizedBox(height: r.s(4)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: r.s(10), vertical: r.s(4)),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(r.s(12)),
                              ),
                              child: Text(
                                roleTitle,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r.fs(11),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: r.s(8)),

                          // Custom titles (tags/chips coloridas)
                          if (titles.isNotEmpty)
                            Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: r.s(24)),
                              child: AminoCustomTitleList(
                                titles: titles,
                                maxVisible: 6,
                              ),
                            ),
                          SizedBox(height: r.s(10)),

                          // Botão Editar (próprio) / Friends + Chat (outro)
                          if (_isOwnProfile)
                            GestureDetector(
                              onTap: () => context.push(
                                  '/community/${widget.communityId}/profile/edit')
                                  .then((_) => _loadProfile()),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.s(28), vertical: r.s(9)),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(r.s(6)),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded,
                                        size: r.s(14), color: Colors.white),
                                    SizedBox(width: r.s(6)),
                                    Text(
                                      s.edit,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: r.fs(14),
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
                                // Botão Seguir/Amigos
                                GestureDetector(
                                  onTap: () => _toggleFollow(context),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: r.s(16), vertical: r.s(8)),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF9800),
                                      borderRadius:
                                          BorderRadius.circular(r.s(20)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('😊',
                                            style:
                                                TextStyle(fontSize: r.fs(14))),
                                        SizedBox(width: r.s(6)),
                                        Text(
                                          s.follow,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: r.fs(13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: r.s(10)),
                                // Botão Chat
                                GestureDetector(
                                  onTap: () => _openDm(context),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: r.s(16), vertical: r.s(8)),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(r.s(20)),
                                      border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.chat_bubble_rounded,
                                            size: r.s(14),
                                            color: Colors.grey[300]),
                                        SizedBox(width: r.s(6)),
                                        Text(
                                          s.chat,
                                          style: TextStyle(
                                            color: Colors.grey[200],
                                            fontWeight: FontWeight.w700,
                                            fontSize: r.fs(13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          SizedBox(height: r.s(12)),

                          // ── CONQUISTAS + MOEDAS BAR (dentro do banner) ──
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: r.s(12)),
                            child: Row(
                              children: [
                                // Conquistas badge
                                GestureDetector(
                                  onTap: () => context.push('/achievements', extra: {
                                    'communityId': widget.communityId,
                                    'bannerUrl': _communityBannerUrl,
                                  }),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: r.s(12), vertical: r.s(6)),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFF9800),
                                          Color(0xFFFFB74D)
                                        ],
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(r.s(16)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.emoji_events_rounded,
                                            color: Colors.white, size: r.s(14)),
                                        SizedBox(width: r.s(4)),
                                        Text(
                                          streak > 0
                                              ? s.streakDaysLabel(streak)
                                              : s.achievements,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: r.fs(11),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                // Moedas badge
                                GestureDetector(
                                  onTap: canViewCoins ? () => context.push('/wallet') : null,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: r.s(10), vertical: r.s(6)),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF2196F3),
                                          Color(0xFF42A5F5)
                                        ],
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(r.s(16)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: r.s(16),
                                          height: r.s(16),
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFFFFD700),
                                                Color(0xFFFFA500)
                                              ],
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'A',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: r.fs(9),
                                                fontWeight: FontWeight.w900,
                                                height: 1.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: r.s(4)),
                                        Text(
                                          canViewCoins
                                              ? formatCount(coins)
                                              : s.privateLabel,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: r.fs(12),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (canViewCoins) ...[
                                          SizedBox(width: r.s(4)),
                                          Container(
                                            width: r.s(16),
                                            height: r.s(16),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.3),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(Icons.add,
                                                color: Colors.white,
                                                size: r.s(11)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: r.s(12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ================================================================
            // STATS — 3 colunas: Reputação | Seguindo | Seguidores
            // ================================================================
            SliverToBoxAdapter(
              child: Container(
                color: context.scaffoldBg,
                padding: EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), r.s(8)),
                child: Row(
                  children: [
                    // Reputação
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            formatCount(reputation),
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: r.fs(28),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.reputation,
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: r.fs(12),
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    // Seguindo
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push(
                            '/user/${widget.userId}/followers?tab=following'),
                        child: Column(
                          children: [
                            Text(
                              formatCount(_followingCount),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: r.fs(28),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.following,
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: r.fs(12),
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Seguidores
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            context.push('/user/${widget.userId}/followers'),
                        child: Column(
                          children: [
                            Text(
                              formatCount(_followersCount),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: r.fs(28),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.followers,
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: r.fs(12),
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

            // ================================================================
            // BIO — "Biografia" + "Membro desde..." + texto + seta expandir
            // ================================================================
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.fromLTRB(0, r.s(4), 0, 0),
                padding:
                    EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), r.s(12)),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  border: Border(
                    top:
                        BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: "Biografia" + "Membro desde..."
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          s.biography,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: r.fs(18),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: r.s(10)),
                        if (joinedAt != null)
                          Expanded(
                            child: Text(
                              _memberSinceText(joinedAt),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: r.fs(11),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: r.s(10)),
                    // Bio text + seta para expandir
                    if (displayBio.isNotEmpty)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _bioExpanded = !_bioExpanded),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                displayBio,
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: r.fs(14),
                                  height: 1.5,
                                ),
                                maxLines: _bioExpanded ? null : 3,
                                overflow: _bioExpanded
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: r.s(8)),
                            Icon(
                              _bioExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_right_rounded,
                              color: Colors.grey[500],
                              size: r.s(20),
                            ),
                          ],
                        ),
                      )
                    else if (_isOwnProfile)
                      GestureDetector(
                        onTap: () => context.push(
                            '/community/${widget.communityId}/profile/edit')
                            .then((_) => _loadProfile()),
                        child: Text(
                          s.tapToAddBio,
                          style: TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: r.fs(13),
                          ),
                        ),
                      )
                    else
                      Text(
                        s.noBio,
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: r.fs(13)),
                      ),
                  ],
                ),
              ),
            ),

            // ================================================================
            // PLANO DE FUNDO LOCAL (se definido)
            // ================================================================
            if (localBackgroundUrl != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.fromLTRB(0, r.s(4), 0, 0),
                  height: r.s(180),
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: localBackgroundUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // ================================================================
            // GALERIA LOCAL (se houver fotos)
            // ================================================================
            if (displayGallery.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.fromLTRB(0, r.s(4), 0, 0),
                  padding: EdgeInsets.all(r.s(12)),
                  color: context.surfaceColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.gallery,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: r.fs(16),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: r.s(10)),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: r.s(4),
                          mainAxisSpacing: r.s(4),
                        ),
                        itemCount: displayGallery.length,
                        itemBuilder: (context, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(r.s(4)),
                            child: CachedNetworkImage(
                              imageUrl: displayGallery[index],
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // ================================================================
            // TABS — Posts | Mural | Posts Salvos
            // ================================================================
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey[500],
                  indicatorColor: Colors.transparent,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: r.fs(14)),
                  unselectedLabelStyle: TextStyle(
                      fontWeight: FontWeight.w500, fontSize: r.fs(14)),
                  tabs: [
                    Tab(
                      child: Text(
                          '${s.posts}${_userPosts.isNotEmpty ? ' ${_userPosts.length}' : ''}'),
                    ),
                    Tab(text: s.wall),
                    Tab(text: s.savedPosts),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPostsTab(),
              WallCommentSheet(
                wallUserId: widget.userId,
                isOwnWall: false,
                asBottomSheet: false,
              ),
              _buildSavedPostsTab(),
            ],
          ),
      ),
      ),
    );
  }

  // ============================================================================
  // POSTS TAB
  // ============================================================================
  Widget _buildPostsTab() {
    final s = getStrings();
    final r = context.r;
    final pinnedPost = _userPosts.cast<Map<String, dynamic>?>().firstWhere(
          (post) => post?['is_pinned_profile'] == true,
          orElse: () => null,
        );
    final regularPosts = _userPosts
        .where((post) => post['is_pinned_profile'] != true)
        .toList(growable: false);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // "Criar nova publicação" button
        if (_isOwnProfile)
          GestureDetector(
            onTap: () => showCommunityCreateMenu(
              context,
              communityId: widget.communityId,
              communityName: _communityName,
            ),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(14)),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                border: Border(
                  bottom:
                      BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: r.s(30),
                    height: r.s(30),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(Icons.add, color: Colors.black87, size: r.s(20)),
                  ),
                  SizedBox(width: r.s(12)),
                  Text(
                    s.createNewPost,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: r.fs(15),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Minhas Entradas Wiki — sempre visível (com botão + se próprio perfil) ──
        if (_wikiEntries.isNotEmpty || _isOwnProfile) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), r.s(8)),
            child: GestureDetector(
              onTap: () =>
                  context.push('/community/${widget.communityId}/wiki'),
              child: Row(
                children: [
                  Text(
                    s.myWikiEntries,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: r.fs(16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.grey[500], size: r.s(20)),
                ],
              ),
            ),
          ),
          SizedBox(
            height: r.s(130),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: r.s(12)),
              // Se próprio perfil, adiciona slot "+" no início
              itemCount: _wikiEntries.length + (_isOwnProfile ? 1 : 0),
              itemBuilder: (context, index) {
                // Slot "+" para criar nova entrada wiki (índice 0 se próprio)
                if (_isOwnProfile && index == 0) {
                  return GestureDetector(
                    onTap: () => context
                        .push('/community/${widget.communityId}/wiki/create'),
                    child: Container(
                      width: r.s(90),
                      margin: EdgeInsets.symmetric(horizontal: r.s(4)),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(r.s(10)),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: r.s(28)),
                        ],
                      ),
                    ),
                  );
                }
                final wikiIndex = _isOwnProfile ? index - 1 : index;
                final wiki = _wikiEntries[wikiIndex];
                final coverUrl = wiki['cover_image_url'] as String?;
                final wikiTitle = wiki['title'] as String? ?? s.wiki;
                final wikiId = wiki['id'] as String?;
                return GestureDetector(
                  onTap: () {
                    if (wikiId != null) context.push('/wiki/$wikiId');
                  },
                  child: Container(
                    width: r.s(90),
                    margin: EdgeInsets.symmetric(horizontal: r.s(4)),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(r.s(10)),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(r.s(10))),
                          child: coverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: coverUrl,
                                  width: r.s(90),
                                  height: r.s(100),
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _wikiPlaceholder(r),
                                )
                              : _wikiPlaceholder(r),
                        ),
                        Padding(
                          padding: EdgeInsets.all(r.s(5)),
                          child: Text(
                            wikiTitle,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: r.fs(10),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(
            color: Colors.white.withValues(alpha: 0.05),
            height: r.s(16),
          ),
        ],

        if (pinnedPost != null) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), r.s(6)),
            child: Text(
              'Post fixado no perfil da comunidade',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: r.fs(14),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _buildCommunityProfilePostCard(pinnedPost, highlighted: true),
          Divider(
            color: Colors.white.withValues(alpha: 0.05),
            height: r.s(20),
          ),
        ],

        // ── Lista de posts ────────────────────────────────────────────────
        if (_userPosts.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: r.s(48)),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.article_outlined,
                      size: r.s(48), color: Colors.grey[700]),
                  SizedBox(height: r.s(12)),
                  Text(s.noPostsInThisCommunity,
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )
        else if (regularPosts.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: r.s(24)),
            child: Center(
              child: Text(
                'Nenhum outro post nesta comunidade.',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else
          ...regularPosts.map((post) => _buildCommunityProfilePostCard(post)),
        SizedBox(height: r.s(80)), // espaço para o FAB
      ],
    );
  }

  Widget _buildCommunityProfilePostCard(
    Map<String, dynamic> post, {
    bool highlighted = false,
  }) {
    final r = context.r;
    final isPinnedProfile = post['is_pinned_profile'] == true;

    return GestureDetector(
      onTap: () => context.push('/post/${post["id"]}'),
      child: Container(
        margin: EdgeInsets.fromLTRB(r.s(16), r.s(6), r.s(16), r.s(6)),
        padding: EdgeInsets.all(r.s(16)),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(
            color: highlighted
                ? AppTheme.primaryColor.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.05),
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPinnedProfile)
                        Container(
                          margin: EdgeInsets.only(bottom: r.s(8)),
                          padding: EdgeInsets.symmetric(
                            horizontal: r.s(10),
                            vertical: r.s(5),
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(r.s(999)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.push_pin_rounded,
                                size: r.s(14),
                                color: AppTheme.primaryColor,
                              ),
                              SizedBox(width: r.s(6)),
                              Text(
                                'Fixado no perfil',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: r.fs(11),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if ((post['title'] as String?)?.isNotEmpty == true)
                        Text(
                          post['title'] as String,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: r.fs(15),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isOwnProfile)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.grey[400],
                      size: r.s(20),
                    ),
                    color: context.surfaceColor,
                    onSelected: (value) {
                      if (value == 'pin_profile') {
                        _toggleCommunityProfilePin(post);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'pin_profile',
                        child: Row(
                          children: [
                            Icon(
                              isPinnedProfile
                                  ? Icons.push_pin_rounded
                                  : Icons.push_pin_outlined,
                              size: r.s(18),
                              color: AppTheme.primaryColor,
                            ),
                            SizedBox(width: r.s(10)),
                            Text(
                              isPinnedProfile
                                  ? 'Desafixar do perfil'
                                  : 'Fixar no perfil',
                              style: TextStyle(color: context.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if ((post['content'] as String?)?.isNotEmpty == true) ...[
              SizedBox(height: r.s(4)),
              Text(
                post['content'] as String,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: r.fs(13),
                ),
              ),
            ],
            SizedBox(height: r.s(10)),
            Row(
              children: [
                Icon(Icons.favorite_rounded,
                    size: r.s(14), color: Colors.grey[600]),
                SizedBox(width: r.s(4)),
                Text(
                  '${post['likes_count'] ?? 0}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: r.s(14)),
                Icon(Icons.comment_rounded,
                    size: r.s(14), color: Colors.grey[600]),
                SizedBox(width: r.s(4)),
                Text(
                  '${post['comments_count'] ?? 0}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleCommunityProfilePin(Map<String, dynamic> post) async {
    final isPinnedProfile = post['is_pinned_profile'] == true;

    try {
      if (isPinnedProfile) {
        await SupabaseService.table('posts')
            .update({'is_pinned_profile': false}).eq('id', post['id']);
      } else {
        await SupabaseService.table('posts')
            .update({'is_pinned_profile': false})
            .eq('author_id', widget.userId)
            .eq('community_id', widget.communityId);
        await SupabaseService.table('posts')
            .update({'is_pinned_profile': true}).eq('id', post['id']);
      }

      if (!mounted) return;
      await _loadProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPinnedProfile
                ? 'Post desafixado do perfil da comunidade'
                : 'Post fixado no perfil da comunidade',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível atualizar o post fixado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _wikiPlaceholder(Responsive r) {
    return Container(
      width: r.s(90),
      height: r.s(70),
      color: context.scaffoldBg,
      child:
          Icon(Icons.menu_book_rounded, size: r.s(28), color: Colors.grey[700]),
    );
  }

  // ============================================================================
  // WALL TAB
  // ============================================================================


  // ============================================================================
  // SAVED POSTS TAB
  // ============================================================================
  Widget _buildSavedPostsTab() {
    final s = getStrings();
    final r = context.r;
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
            Icon(Icons.lock_outline_rounded,
                size: r.s(48), color: Colors.grey[700]),
            SizedBox(height: r.s(12)),
            Text(s.savedPostsArePrivate,
                style: TextStyle(
                    color: Colors.grey[500], fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (_savedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_outline_rounded,
                size: r.s(48), color: Colors.grey[700]),
            SizedBox(height: r.s(12)),
            Text(s.noSavedPosts,
                style: TextStyle(
                    color: Colors.grey[500], fontWeight: FontWeight.w600)),
            SizedBox(height: r.s(6)),
            Text(
              s.tapTheBookmarkIconOnPostsToSaveThem,
              style: TextStyle(color: Colors.grey[600], fontSize: r.fs(12)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(r.s(16)),
      itemCount: _savedPosts.length,
      separatorBuilder: (_, __) => SizedBox(height: r.s(10)),
      itemBuilder: (context, index) {
        final bookmark = _savedPosts[index];
        final post = bookmark['posts'] as Map<String, dynamic>? ?? {};
        final author = post['profiles'] as Map<String, dynamic>?;
        final postId = post['id'] as String?;
        final authorId = post['author_id'] as String?;
        final localSelfNickname = (_membership?['local_nickname'] as String?)?.trim();
        final displayAuthorName =
            authorId == widget.userId && (localSelfNickname?.isNotEmpty ?? false)
                ? localSelfNickname!
                : (author?['nickname'] as String? ?? s.user);

        return GestureDetector(
          onTap: () {
            if (postId != null) context.push('/post/$postId');
          },
          child: Container(
            padding: EdgeInsets.all(r.s(14)),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(r.s(14)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                if (post['cover_image_url'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(r.s(8)),
                    child: CachedNetworkImage(
                      imageUrl: post['cover_image_url'] as String? ?? '',
                      width: r.s(60),
                      height: r.s(60),
                      fit: BoxFit.cover,
                    ),
                  ),
                if (post['cover_image_url'] != null) SizedBox(width: r.s(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['title'] as String? ?? s.untitled,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(14),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: r.s(4)),
                      Text(
                        'por $displayAuthorName',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: r.fs(12)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.bookmark_rounded,
                      color: AppTheme.primaryColor, size: r.s(20)),
                  onPressed: () async {
                    try {
                      await SupabaseService.table('bookmarks')
                          .delete()
                          .eq('id', bookmark['id']);
                      if (!mounted) return;
                      setState(() => _savedPosts.removeAt(index));
                    } catch (e) {
                      debugPrint('[community_profile_screen] Erro: $e');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadSavedPosts() async {
    if (_savedPostsLoaded) return;
    try {
      final res = await SupabaseService.table('bookmarks')
          .select(
              '*, posts!bookmarks_post_id_fkey(*, profiles!posts_author_id_fkey(nickname, icon_url))')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _savedPosts = List<Map<String, dynamic>>.from(res as List? ?? []);
          _savedPostsLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _savedPostsLoaded = true);
    }
  }

  // ============================================================================
  // ACTIONS
  // ============================================================================

  Future<void> _toggleFollow(BuildContext context) async {
    final s = getStrings();
    try {
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId == null) return;
      // RPC atômica: toggle follow + reputação + contadores
      final result = await SupabaseService.rpc(
        'toggle_follow_with_reputation',
        params: {
          'p_community_id': widget.communityId,
          'p_follower_id': currentUserId,
          'p_following_id': widget.userId,
        },
      );
      final isNowFollowing =
          result is Map ? (result['following'] == true) : true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isNowFollowing ? s.followingNow : s.unfollowed)),
        );
      }
      _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.anErrorOccurredTryAgain)),
        );
      }
    }
  }

  Future<void> _openDm(BuildContext context) async {
    final s = getStrings();
    try {
      final threadId = await DmInviteService().sendInvite(widget.userId);
      if (threadId == null || threadId.isEmpty) {
        throw Exception('thread_id_not_returned');
      }

      if (!mounted) return;
      context.push('/chat/$threadId');
    } catch (e) {
      if (mounted) {
        final err = e.toString();
        String message = s.errorOpeningChatTryAgain;

        if (err.contains(s.cannotDmYourself)) {
          message = s.youCannotOpenAChatWithYourself;
        } else if (err.contains(s.doesNotAcceptDMs)) {
          message = s.thisUserDoesNotAcceptDirectMessages;
        } else if (err.contains(s.onlyAcceptsDMs)) {
          message = s.thisUserOnlyAcceptsMessagesFromAllowedProfiles;
        } else if (err
            .contains(s.cannotMessageUser)) {
          message = s.couldNotStartAConversationWithThisUser;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  // ============================================================================
  // BLOCK / UNBLOCK
  // ============================================================================
  Future<void> _handleBlockToggle(bool isCurrentlyBlocked) async {
    final s = ref.read(stringsProvider);
    final notifier = ref.read(blockedIdsProvider.notifier);
    if (isCurrentlyBlocked) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          title: Text(s.unblockUser,
              style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w800)),
          content: Text(s.confirmUnblockUser,
              style: TextStyle(color: Colors.grey[500])),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.unblock,
                  style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      final ok = await notifier.unblock(widget.userId);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.userUnblocked),
          backgroundColor: context.surfaceColor,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          title: Text(s.blockConfirmTitle,
              style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w800)),
          content: Text(s.blockConfirmMsg,
              style: TextStyle(color: Colors.grey[500])),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.block,
                  style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      final ok = await notifier.block(widget.userId);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.blockSuccess),
          backgroundColor: context.surfaceColor,
          behavior: SnackBarBehavior.floating,
        ));
        if (mounted) context.pop();
      }
    }
  }

  // ============================================================================
  // OPTIONS BOTTOM SHEET
  // ============================================================================
  void _showOptions(BuildContext context) {
    final s = getStrings();
    final r = context.r;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final myRole = _myMembership?['role'] as String? ?? 'member';
        final canManageRoles = !_isOwnProfile &&
            (myRole == 'agent' || myRole == 'leader' || myRole == 'curator');
        return Padding(
        padding: EdgeInsets.all(r.s(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: r.s(36),
              height: r.s(4),
              margin: EdgeInsets.only(bottom: r.s(16)),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (canManageRoles)
              _optionTile(
                Icons.manage_accounts_rounded,
                'Gerenciar Cargo',
                () async {
                  Navigator.pop(ctx);
                  final targetRole = _membership?['role'] as String? ?? 'member';
                  final targetName = _user?.nickname ?? 'Membro';
                  String? currentTitle;
                  try {
                    final titleRes = await SupabaseService.table('member_titles')
                        .select('title')
                        .eq('community_id', widget.communityId)
                        .eq('user_id', widget.userId)
                        .maybeSingle();
                    currentTitle = titleRes?['title'] as String?;
                  } catch (_) {}
                  if (!mounted) return;
                  final changed = await showMemberRoleManager(
                    context: context,
                    ref: ref,
                    communityId: widget.communityId,
                    targetUserId: widget.userId,
                    targetUserName: targetName,
                    currentRole: targetRole,
                    currentTitle: currentTitle,
                  );
                  if (changed == true && mounted) {
                    _loadProfile();
                  }
                },
              ),
            if (!_isOwnProfile) ...[
              _optionTile(Icons.flag_rounded, s.report, () {
                Navigator.pop(ctx);
              }, isDestructive: true),
              Consumer(
                builder: (ctx2, ref2, _) {
                  final isBlocked = ref2.watch(isBlockedProvider(widget.userId));
                  return _optionTile(
                    isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                    isBlocked ? s.unblockAction : s.block,
                    () async {
                      Navigator.pop(ctx);
                      await _handleBlockToggle(isBlocked);
                    },
                    isDestructive: true,
                  );
                },
              ),
            ],
            _optionTile(Icons.share_rounded, s.shareProfile, () {
              Navigator.pop(ctx);
              final link =
                  'https://nexushub.app/community/${widget.communityId}/profile/${widget.userId}';
              Clipboard.setData(ClipboardData(text: link));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(s.profileLinkCopied),
                    backgroundColor: AppTheme.primaryColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }),
          ],
        ),
      );
      },
    );
  }

  Widget _optionTile(IconData icon, String label, VoidCallback onTap,
      {bool isDestructive = false}) {
    final r = context.r;
    final color = isDestructive ? AppTheme.errorColor : Colors.grey[400];
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: r.s(12)),
        child: Row(
          children: [
            Icon(icon, color: color, size: r.s(20)),
            SizedBox(width: r.s(12)),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: r.fs(14),
                    fontWeight: FontWeight.w500)),
          ],
        ),
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
            context.scaffoldBg,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  String _memberSinceText(DateTime joinedAt) {
    final s = getStrings();
    final months = [
      s.january,
      s.february,
      s.march,
      s.april,
      s.may,
      s.june,
      s.july,
      s.august,
      s.september,
      s.october,
      s.november,
      s.december
    ];
    final days = DateTime.now().difference(joinedAt).inDays;
    return s.memberSinceLabel(months[joinedAt.month - 1], joinedAt.year, days);
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
      color: context.surfaceColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

