import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/comment_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/providers/dm_invite_provider.dart';
import '../../chat/widgets/chat_bubble.dart'; // AvatarWithFrame + AminoPlusBadge
import '../../../core/widgets/amino_custom_title.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/amino_bottom_nav.dart';
import '../../communities/widgets/community_create_menu.dart';

/// Perfil dentro de uma Comunidade — Layout 1:1 com Amino Apps.
///
/// Estrutura:
///   SliverAppBar expandível (banner + avatar + nome + level + tags + botões
///     + conquistas/moedas bar — tudo dentro do FlexibleSpaceBar)
///   Stats 3 colunas: Reputação | Seguindo | Seguidores
///   Bio com "Membro desde..." + seta para expandir
///   Tabs: Posts | Mural | Posts Salvos
///   FAB roxo para criar publicação (apenas próprio perfil)
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
  List<Map<String, dynamic>> _wikiEntries = [];
  List<Map<String, dynamic>> _savedPosts = [];
  bool _isLoading = true;
  bool _savedPostsLoaded = false;
  bool _bioExpanded = false;
  final _wallController = TextEditingController();
  int _followersCount = 0;
  int _followingCount = 0;
  String _communityName = '';

  bool get _isOwnProfile => widget.userId == SupabaseService.currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) setState(() => _isLoading = true);
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
            .select('name')
            .eq('id', widget.communityId)
            .single();
        _communityName = communityRes['name'] as String? ?? '';
      } catch (e) {
        debugPrint('[community_profile_screen.dart] $e');
      }

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
          .eq('status', 'ok')
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

      // Mural (wall comments)
      final wallRes = await SupabaseService.table('comments')
          .select('*, profiles(*)')
          .eq('profile_wall_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(30);
      _wallComments = (wallRes as List? ?? [])
          .map((e) => CommentModel.fromJson(e))
          .toList();

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
      setState(() => _isLoading = false);
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
    final r = context.r;
    if (_isLoading) {
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
    final joinedAt = _membership?['joined_at'] != null
        ? DateTime.tryParse(_membership?['joined_at'] as String? ?? '')
        : null;
    final coins = _user?.coins ?? 0;
    final isOnline = _user?.isOnline ?? false;
    final isPremium = _user?.isPremium ?? false;
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

    // Altura do FlexibleSpaceBar: varia conforme conteúdo
    // Base: 200 (banner) + avatar(96) + nome + level + tags + botões + conquistas
    final double expandedHeight = 420 +
        (titles.isNotEmpty ? r.s(40) : 0) +
        (roleTitle != null ? r.s(28) : 0);

    return Scaffold(
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
                      isOnline ? 'Online' : 'Offline',
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
                          Row(
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
                                      'lv',
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
                                  '/community/${widget.communityId}/profile/edit'),
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
                                      'Editar',
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
                                          'Seguir',
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
                                          'Chat',
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
                                  onTap: () => context.push('/achievements'),
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
                                              ? '$streak Dias na Sequência'
                                              : 'Conquistas',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: r.fs(11),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        // Badge "!" vermelho (notificação) — sempre visível
                                        SizedBox(width: r.s(4)),
                                        Container(
                                          width: r.s(16),
                                          height: r.s(16),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '!',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: r.fs(10),
                                                fontWeight: FontWeight.w900,
                                                height: 1.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                // Moedas badge
                                GestureDetector(
                                  onTap: () => context.push('/wallet'),
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
                                          formatCount(coins),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: r.fs(12),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
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
                            'Reputação',
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
                              'Seguindo',
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
                              'Seguidores',
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
                          'Biografia',
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
                            '/community/${widget.communityId}/profile/edit'),
                        child: Text(
                          'Clique aqui para adicionar sua biografia!',
                          style: TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: r.fs(13),
                          ),
                        ),
                      )
                    else
                      Text(
                        'Sem biografia',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: r.fs(13)),
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
                          'Posts${_userPosts.isNotEmpty ? ' ${_userPosts.length}' : ''}'),
                    ),
                    Tab(
                      child: Text(
                          'Mural${_wallComments.isNotEmpty ? ' ${_wallComments.length}' : ''}'),
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
      ),
    );
  }

  // ============================================================================
  // POSTS TAB
  // ============================================================================
  Widget _buildPostsTab() {
    final r = context.r;
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
                    'Criar nova publicação',
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
                    'Minhas Entradas Wiki',
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
                final wikiTitle = wiki['title'] as String? ?? 'Wiki';
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
                  Text('Nenhum post nesta comunidade',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )
        else
          ...List.generate(_userPosts.length, (index) {
            final post = _userPosts[index];
            return GestureDetector(
              onTap: () => context.push('/post/${post['id']}'),
              child: Container(
                margin: EdgeInsets.fromLTRB(r.s(16), r.s(6), r.s(16), r.s(6)),
                padding: EdgeInsets.all(r.s(16)),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(r.s(12)),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post['title'] != null)
                      Text(
                        post['title'] as String? ?? '',
                        style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: r.fs(15)),
                      ),
                    if (post['content'] != null) ...[
                      SizedBox(height: r.s(4)),
                      Text(
                        post['content'] as String? ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: r.fs(13)),
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
                              fontWeight: FontWeight.w600),
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
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        SizedBox(height: r.s(80)), // espaço para o FAB
      ],
    );
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
  Widget _buildWallTab() {
    final r = context.r;
    return Column(
      children: [
        // Input
        Container(
          padding: EdgeInsets.all(r.s(12)),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wallController,
                  style:
                      TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
                  decoration: InputDecoration(
                    hintText: 'Escreva no mural...',
                    hintStyle:
                        TextStyle(color: Colors.grey[600], fontSize: r.fs(14)),
                    filled: true,
                    fillColor: context.scaffoldBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(r.s(20)),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: r.s(14), vertical: r.s(8)),
                  ),
                ),
              ),
              SizedBox(width: r.s(8)),
              GestureDetector(
                onTap: _postWallComment,
                child: Container(
                  padding: EdgeInsets.all(r.s(10)),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.send_rounded,
                      color: Colors.white, size: r.s(18)),
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
                  padding: EdgeInsets.all(r.s(12)),
                  itemCount: _wallComments.length,
                  itemBuilder: (context, index) {
                    final comment = _wallComments[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: r.s(10)),
                      padding: EdgeInsets.all(r.s(14)),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(r.s(12)),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                context.push('/user/${comment.authorId}'),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: context.scaffoldBg,
                              backgroundImage: () {
                                final authorIcon = comment.author?.iconUrl;
                                return authorIcon != null &&
                                        authorIcon.isNotEmpty
                                    ? CachedNetworkImageProvider(authorIcon)
                                    : null;
                              }(),
                              child: () {
                                final authorIcon = comment.author?.iconUrl;
                                return authorIcon == null || authorIcon.isEmpty
                                    ? Icon(Icons.person_rounded,
                                        size: r.s(18),
                                        color: context.textPrimary)
                                    : null;
                              }(),
                            ),
                          ),
                          SizedBox(width: r.s(10)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment.author?.nickname ?? 'Anônimo',
                                  style: TextStyle(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: r.fs(13)),
                                ),
                                SizedBox(height: r.s(3)),
                                Text(
                                  comment.content,
                                  style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: r.fs(13),
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
            Text('Posts salvos são privados',
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
            Text('Nenhum post salvo',
                style: TextStyle(
                    color: Colors.grey[500], fontWeight: FontWeight.w600)),
            SizedBox(height: r.s(6)),
            Text(
              'Toque no ícone de bookmark nos posts para salvá-los',
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
                        post['title'] as String? ?? 'Sem título',
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
                        'por ${author?['nickname'] ?? 'Usuário'}',
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
              content: Text(isNowFollowing ? 'Seguindo!' : 'Deixou de seguir')),
        );
      }
      _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ocorreu um erro. Tente novamente.')),
        );
      }
    }
  }

  Future<void> _openDm(BuildContext context) async {
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
        String message = 'Erro ao abrir chat. Tente novamente.';

        if (err.contains('Não é possível enviar DM para si mesmo')) {
          message = 'Você não pode abrir um chat consigo mesmo.';
        } else if (err.contains('não aceita mensagens diretas')) {
          message = 'Este usuário não aceita mensagens diretas.';
        } else if (err.contains('só aceita DMs')) {
          message = 'Este usuário só aceita mensagens de perfis permitidos.';
        } else if (err
            .contains('Não é possível enviar mensagem para este usuário')) {
          message = 'Não foi possível iniciar conversa com este usuário.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  Future<void> _postWallComment() async {
    final text = _wallController.text.trim();
    if (text.isEmpty) return;
    try {
      // RPC server-side: validação + auth.uid()
      await SupabaseService.rpc('post_wall_comment', params: {
        'p_profile_user_id': widget.userId,
        'p_community_id': widget.communityId,
        'p_content': text,
      });
      _wallController.clear();
      final wallRes = await SupabaseService.table('comments')
          .select('*, profiles(*)')
          .eq('profile_wall_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(30);
      if (!mounted) return;
      setState(() {
        _wallComments = (wallRes as List? ?? [])
            .map((e) => CommentModel.fromJson(e))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ocorreu um erro. Tente novamente.')),
        );
      }
    }
  }

  // ============================================================================
  // OPTIONS BOTTOM SHEET
  // ============================================================================
  void _showOptions(BuildContext context) {
    final r = context.r;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
              final link =
                  'https://nexushub.app/community/${widget.communityId}/profile/${widget.userId}';
              Clipboard.setData(ClipboardData(text: link));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Link do perfil copiado!'),
                    backgroundColor: AppTheme.primaryColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }),
          ],
        ),
      ),
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
    const months = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro'
    ];
    final days = DateTime.now().difference(joinedAt).inDays;
    return 'Membro desde ${months[joinedAt.month - 1]} ${joinedAt.year} ($days dias)';
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
