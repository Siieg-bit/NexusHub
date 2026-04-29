import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show CountOption, PostgrestResponse;
import '../../../core/services/community_profile_service.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/providers/dm_invite_provider.dart';
import '../../chat/widgets/chat_bubble.dart'; // AvatarWithFrame + AminoPlusBadge
import '../../../core/widgets/amino_custom_title.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/amino_bottom_nav.dart';
import '../../communities/widgets/community_create_menu.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/providers/block_provider.dart';
import '../providers/profile_providers.dart';
import '../widgets/wall_comment_sheet.dart';
import '../widgets/rich_bio.dart';
import '../../moderation/widgets/member_role_manager.dart';
import '../../moderation/widgets/manage_member_titles_sheet.dart';
import '../../moderation/widgets/report_dialog.dart';
import '../../../core/widgets/image_viewer.dart';
import 'bio_and_wall_screen.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

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
  ConsumerState<CommunityProfileScreen> createState() =>
      _CommunityProfileScreenState();
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
  bool _viewerIsTeamMember = false;
  bool _isUpdatingManualPresence = false;
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false; // estado real do botão Seguir/Seguindo
  bool _isFollowingMe = false; // o outro usuário me segue (amizade mútua)
  bool _isTogglingFollow = false; // evita double-tap
  bool _hasActiveStory = false; // usuário tem story ativo nesta comunidade
  String _communityName = '';
  String? _communityBannerUrl;

  bool get _isOwnProfile => widget.userId == SupabaseService.currentUserId;
  Map<String, dynamic>?
      _myMembership; // membership do usuário logado na comunidade

  // Key para calcular a posição do dropdown de opções
  final GlobalKey _optionsButtonKey = GlobalKey();

  // Banner rotativo
  int _bannerIndex = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  void _startBannerTimer(List<String> gallery) {
    _bannerTimer?.cancel();
    if (gallery.length <= 1) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        setState(() {
          _bannerIndex = (_bannerIndex + 1) % gallery.length;
        });
      }
    });
  }

  List<String> _buildProfileMediaUrls({
    String? avatarUrl,
    String? bannerUrl,
    List<String> gallery = const [],
  }) {
    final urls = <String>[];

    void addUrl(String? rawUrl) {
      final normalized = rawUrl?.trim();
      if (normalized == null ||
          normalized.isEmpty ||
          urls.contains(normalized)) {
        return;
      }
      urls.add(normalized);
    }

    addUrl(avatarUrl);
    addUrl(bannerUrl);
    for (final imageUrl in gallery) {
      addUrl(imageUrl);
    }
    return urls;
  }

  void _openProfileMediaViewer(
    BuildContext context, {
    required List<String> mediaUrls,
    String? initialUrl,
    String? heroTag,
  }) {
    if (mediaUrls.isEmpty) return;
    final normalizedInitialUrl = initialUrl?.trim();
    final initialIndex = normalizedInitialUrl == null
        ? 0
        : mediaUrls.indexOf(normalizedInitialUrl);

    showMediaViewer(
      context,
      mediaUrls: mediaUrls,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
      heroTag: heroTag,
    );
  }

  Future<void> _loadProfile() async {
    try {
      final currentUserId = SupabaseService.currentUserId;

      // -----------------------------------------------------------------------
      // GRUPO 1: Queries totalmente independentes — disparadas em PARALELO.
      // Antes: 8+ awaits sequenciais (~2.5s). Agora: 1 Future.wait (~350ms).
      // -----------------------------------------------------------------------
      final group1 = await Future.wait<dynamic>([
        // [0] Perfil global do usuário alvo
        SupabaseService.table('profiles')
            .select()
            .eq('id', widget.userId)
            .single(),
        // [1] Nome e banner da comunidade
        SupabaseService.table('communities')
            .select('name, banner_url')
            .eq('id', widget.communityId)
            .single()
            .catchError((_) => <String, dynamic>{}),
        // [2] Membership do usuário alvo na comunidade
        SupabaseService.table('community_members')
            .select()
            .eq('user_id', widget.userId)
            .eq('community_id', widget.communityId)
            .maybeSingle(),
        // [3] Posts do usuário na comunidade
        SupabaseService.table('posts')
            .select(
                '*, profiles!posts_author_id_fkey(*), original_author:profiles!posts_original_author_id_fkey(id, nickname, icon_url, online_status), original_post:original_post_id(id, title, content, type, cover_image_url, media_list, created_at, author_id, community_id, original_post_id)')
            .eq('author_id', widget.userId)
            .eq('community_id', widget.communityId)
            .eq('status', 'ok')
            .order('is_pinned_profile', ascending: false)
            .order('created_at', ascending: false)
            .limit(20),
        // [4] Wiki entries do usuário na comunidade
        SupabaseService.table('wiki_entries')
            .select('id, title, cover_image_url')
            .eq('author_id', widget.userId)
            .eq('community_id', widget.communityId)
            .eq('status', 'ok')
            .order('created_at', ascending: false)
            .limit(10)
            .catchError((_) => <dynamic>[]),
        // [5] Story ativo
        SupabaseService.table('stories')
            .select('id')
            .eq('author_id', widget.userId)
            .eq('community_id', widget.communityId)
            .gt('expires_at', DateTime.now().toUtc().toIso8601String())
            .limit(1),
      ]);

      _user = UserModel.fromJson(group1[0] as Map<String, dynamic>);
      final communityRes = group1[1] as Map<String, dynamic>?;
      _communityName = communityRes?['name'] as String? ?? '';
      _communityBannerUrl = communityRes?['banner_url'] as String?;
      _membership = group1[2];
      _userPosts = List<Map<String, dynamic>>.from(group1[3] as List? ?? []);
      _wikiEntries = List<Map<String, dynamic>>.from(group1[4] as List? ?? []);
      _hasActiveStory = ((group1[5] as List?)?.length ?? 0) > 0;

      if (_isOwnProfile) {
        await CommunityProfileService.ensureMyCommunityProfile(
            widget.communityId);
      }

      // -----------------------------------------------------------------------
      // GRUPO 2: Queries que dependem do currentUserId — paralelas entre si.
      // -----------------------------------------------------------------------
      if (currentUserId != null) {
        final group2Futures = <Future<dynamic>>[
          // [0] Contagem de seguidores via count exato (sem transferir linhas)
          SupabaseService.table('follows')
              .select('id')
              .eq('community_id', widget.communityId)
              .eq('following_id', widget.userId)
              .count(CountOption.exact),
          // [1] Contagem de seguindo via count exato
          SupabaseService.table('follows')
              .select('id')
              .eq('community_id', widget.communityId)
              .eq('follower_id', widget.userId)
              .count(CountOption.exact),
        ];

        if (!_isOwnProfile) {
          group2Futures.addAll([
            // [2] Minha membership na comunidade
            SupabaseService.table('community_members')
                .select('role')
                .eq('user_id', currentUserId)
                .eq('community_id', widget.communityId)
                .maybeSingle(),
            // [3] Meu perfil global (para verificar team admin/mod)
            SupabaseService.table('profiles')
                .select('is_team_admin, is_team_moderator')
                .eq('id', currentUserId)
                .maybeSingle(),
            // [4] Verificar se já sigo este perfil
            SupabaseService.table('follows')
                .select('id')
                .eq('community_id', widget.communityId)
                .eq('follower_id', currentUserId)
                .eq('following_id', widget.userId)
                .limit(1),
            // [5] Verificar se o outro me segue
            SupabaseService.table('follows')
                .select('id')
                .eq('community_id', widget.communityId)
                .eq('follower_id', widget.userId)
                .eq('following_id', currentUserId)
                .limit(1),
          ]);
        }

        final group2 = await Future.wait(group2Futures);

        // Contagens de seguidores/seguindo
        final followersRes = group2[0] as PostgrestResponse;
        _followersCount = followersRes.count ?? 0;
        final followingRes = group2[1] as PostgrestResponse;
        _followingCount = followingRes.count ?? 0;

        if (_isOwnProfile) {
          // No próprio perfil: _membership já é o membership do viewer;
          // reutilizá-lo como _myMembership e buscar is_team_* do próprio perfil.
          _myMembership = _membership;
          // _user já foi carregado no grupo 1 com o perfil global do usuário.
          if (_user != null) {
            _viewerIsTeamMember = _user!.isTeamMember;
          }
        } else if (group2.length > 2) {
          _myMembership = group2[2] as Map<String, dynamic>?;
          final viewerProfileRes = group2[3] as Map<String, dynamic>?;
          if (viewerProfileRes != null) {
            final viewerProfile = UserModel.fromJson({
              'id': currentUserId,
              ...viewerProfileRes,
            });
            _viewerIsTeamMember = viewerProfile.isTeamMember;
          }
          _isFollowing = ((group2[4] as List?)?.length ?? 0) > 0;
          _isFollowingMe = ((group2[5] as List?)?.length ?? 0) > 0;
        }
      } else {
        // Usuário não autenticado: apenas contagens
        final countResults = await Future.wait<PostgrestResponse>([
          SupabaseService.table('follows')
              .select('id')
              .eq('community_id', widget.communityId)
              .eq('following_id', widget.userId)
              .count(CountOption.exact),
          SupabaseService.table('follows')
              .select('id')
              .eq('community_id', widget.communityId)
              .eq('follower_id', widget.userId)
              .count(CountOption.exact),
        ]);
        _followersCount = countResults[0].count ?? 0;
        _followingCount = countResults[1].count ?? 0;
      }
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _savedPostsLoaded =
            false; // força recarregar posts salvos na próxima vez
        _bannerIndex = 0; // reinicia o índice ao recarregar
      });
      // Iniciar timer de banner rotativo se houver galeria
      final rawGallery = _membership?['local_gallery'] as List<dynamic>?;
      final gallery =
          rawGallery?.map((e) => e.toString()).toList() ?? <String>[];
      _startBannerTimer(gallery);
    } catch (e) {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _toggleManualPresence() async {
    if (!_isOwnProfile || _user == null || _isUpdatingManualPresence) return;

    final s = ref.read(stringsProvider);
    final nextOffline = !_user!.isGhostMode;

    setState(() => _isUpdatingManualPresence = true);
    try {
      await PresenceService.instance.setManualOfflineMode(nextOffline);
      await _loadProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextOffline
                ? 'Status alterado para offline'
                : 'Status alterado para online',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.anErrorOccurredTryAgain)),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingManualPresence = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    if (_isInitialLoading) {
      return Scaffold(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        body: Center(
            child: CircularProgressIndicator(
                color: context.nexusTheme.accentPrimary, strokeWidth: 2)),
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
    final localBackgroundUrl =
        (_membership?['local_background_url'] as String?)?.trim();
    final localBackgroundColor =
        (_membership?['local_background_color'] as String?)?.trim();
    final rawGallery = _membership?['local_gallery'] as List<dynamic>?;
    final displayGallery =
        rawGallery?.map((e) => e.toString()).toList() ?? <String>[];

    Color? parseProfileBackgroundColor(String? rawColor) {
      if (rawColor == null || rawColor.trim().isEmpty) return null;
      final normalized = rawColor.trim().toUpperCase();
      try {
        if (normalized.startsWith('#')) {
          final hex = normalized.substring(1);
          if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
          if (hex.length == 8) return Color(int.parse(hex, radix: 16));
        }
        if (normalized.startsWith('0X')) {
          return Color(int.parse(normalized.substring(2), radix: 16));
        }
        if (normalized.length == 6) {
          return Color(int.parse('FF$normalized', radix: 16));
        }
        if (normalized.length == 8) {
          return Color(int.parse(normalized, radix: 16));
        }
      } catch (_) {}
      return null;
    }

    final dynamicBgColor = parseProfileBackgroundColor(localBackgroundColor);
    final profileBackgroundImage =
        (localBackgroundUrl?.isNotEmpty ?? false) ? localBackgroundUrl : null;
    final hasProfileBackgroundImage = profileBackgroundImage != null;

    // Banner ativo da galeria (rotativo)
    final activeBannerUrl = displayGallery.isNotEmpty
        ? displayGallery[_bannerIndex.clamp(0, displayGallery.length - 1)]
        : null;
    final joinedAt = _membership?['joined_at'] != null
        ? DateTime.tryParse(_membership?['joined_at'] as String? ?? '')
        : null;
    final coins = _user?.coins ?? 0;
    final canViewCoins = _isOwnProfile;
    final isOnline = _user?.isOnline ?? false;
    final isManualOffline = _user?.isGhostMode ?? false;
    final presenceLabel = _user?.gradualPresenceLabel ?? s.offline;
    final isPremium = _user?.isPremium ?? false;
    final displayName = (localNickname?.trim().isNotEmpty ?? false)
        ? localNickname!.trim()
        : s.user;
    final displayAvatar = (localIconUrl?.trim().isNotEmpty ?? false)
        ? localIconUrl!.trim()
        : null;
    final displayBanner = (localBannerUrl?.trim().isNotEmpty ?? false)
        ? localBannerUrl!.trim()
        : null;
    final displayBio =
        (localBio?.trim().isNotEmpty ?? false) ? localBio!.trim() : '';
    final profileMediaUrls = _buildProfileMediaUrls(
      avatarUrl: displayAvatar,
      bannerUrl: displayBanner,
      gallery: displayGallery,
    );

    final viewerRole = (_myMembership?['role'] as String? ?? '').toLowerCase();
    final canViewHiddenProfile =
        _isOwnProfile || _viewerIsTeamMember || viewerRole == 'agent' || viewerRole == 'leader' || viewerRole == 'curator';
    final isHiddenProfile = _membership?['is_hidden'] == true;
    final isBlocked = ref.watch(isBlockedProvider(widget.userId));

    // ── Perfil de usuário bloqueado ─────────────────────────────────────────
    if (isBlocked && !_isOwnProfile) {
      return Scaffold(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: context.nexusTheme.backgroundPrimary,
          foregroundColor: context.nexusTheme.textPrimary,
          title: Text(displayName),
          actions: [
            IconButton(
              key: _optionsButtonKey,
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showOptions(context),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(r.s(32)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block_rounded,
                    size: r.s(64), color: context.nexusTheme.textSecondary),
                SizedBox(height: r.s(20)),
                Text(
                  'Usuário bloqueado',
                  style: TextStyle(
                    fontSize: r.fs(20),
                    fontWeight: FontWeight.bold,
                    color: context.nexusTheme.textPrimary,
                  ),
                ),
                SizedBox(height: r.s(8)),
                Text(
                  'Você bloqueou este usuário. O conteúdo dele não está disponível.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.fs(14),
                    color: context.nexusTheme.textSecondary,
                  ),
                ),
                SizedBox(height: r.s(24)),
                OutlinedButton.icon(
                  onPressed: () => _handleBlockToggle(true),
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Desbloquear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.nexusTheme.accentPrimary,
                    side: BorderSide(color: context.nexusTheme.accentPrimary),
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(24), vertical: r.s(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isHiddenProfile && !canViewHiddenProfile) {
      // Perfil oculto: exibe layout temático com banner/avatar borrados e ícone de olho riscado
      return Scaffold(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: context.nexusTheme.backgroundPrimary,
          foregroundColor: context.nexusTheme.textPrimary,
          title: Text(displayName),
        ),
        body: Column(
          children: [
            // ── Banner temático de oculto ────────────────────────────────────
            Stack(
              children: [
                // Banner com filtro escurecido
                SizedBox(
                  width: double.infinity,
                  height: r.s(140),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.72),
                      BlendMode.darken,
                    ),
                    child: displayBanner != null
                        ? Image.network(
                            displayBanner,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: context.nexusTheme.surfaceSecondary,
                            ),
                          )
                        : Container(
                            color: context.nexusTheme.surfaceSecondary,
                          ),
                  ),
                ),
                // Avatar com filtro escurecido + ícone sobreposto
                Positioned(
                  bottom: -r.s(36),
                  left: r.s(20),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: r.s(72),
                        height: r.s(72),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.nexusTheme.backgroundPrimary,
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.65),
                              BlendMode.darken,
                            ),
                            child: displayAvatar != null
                                ? Image.network(
                                    displayAvatar,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: context.nexusTheme.surfaceSecondary,
                                    ),
                                  )
                                : Container(
                                    color: context.nexusTheme.surfaceSecondary,
                                  ),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.visibility_off_rounded,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: r.s(22),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: r.s(44)),
            // ── Mensagem de perfil oculto ────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.s(24)),
              child: Column(
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontSize: r.fs(18),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: r.s(12)),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(16), vertical: r.s(10)),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_off_rounded,
                            size: r.s(16),
                            color: context.nexusTheme.textSecondary),
                        SizedBox(width: r.s(8)),
                        Flexible(
                          child: Text(
                            'Perfil ocultado pela moderação',
                            style: TextStyle(
                              color: context.nexusTheme.textSecondary,
                              fontSize: r.fs(13),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Altura do FlexibleSpaceBar: varia conforme conteúdo
    // Base: 200 (banner) + avatar(96) + nome + level + tags + botões + conquistas
    // O role badge agora faz parte de titles (is_role_badge), não precisa de espaço extra.
    final double expandedHeight = 420 +
        (titles.isNotEmpty ? r.s(40) : 0);

    final effectiveBgColor =
        dynamicBgColor ?? context.nexusTheme.backgroundPrimary;
    final layeredBgColor = hasProfileBackgroundImage
        ? effectiveBgColor.withValues(alpha: 0.84)
        : effectiveBgColor;
    final bannerFadeColor = hasProfileBackgroundImage
        ? layeredBgColor.withValues(alpha: 0.92)
        : effectiveBgColor;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: layeredBgColor,
      floatingActionButton: _isOwnProfile
          ? AminoCommunityFab(
              onTap: () => showCommunityCreateMenu(
                context,
                communityId: widget.communityId,
                communityName: _communityName,
              ),
            )
          : null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasProfileBackgroundImage)
            CachedNetworkImage(
              imageUrl: profileBackgroundImage,
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.35),
              colorBlendMode: BlendMode.darken,
              errorWidget: (_, __, ___) => Container(color: effectiveBgColor),
            )
          else
            Container(color: effectiveBgColor),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: hasProfileBackgroundImage
                    ? [
                        Colors.black.withValues(alpha: 0.08),
                        layeredBgColor.withValues(alpha: 0.30),
                        layeredBgColor,
                      ]
                    : [effectiveBgColor, effectiveBgColor],
              ),
            ),
          ),
          RefreshIndicator(
            color: context.nexusTheme.accentPrimary,
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
                  backgroundColor: layeredBgColor,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white, size: r.s(20)),
                    onPressed: () => context.pop(),
                  ),
                  actions: [
                    // Online indicator — clicável para alternar presença (apenas perfil próprio)
                    GestureDetector(
                      onTap: _isOwnProfile
                          ? (_isUpdatingManualPresence ? null : _toggleManualPresence)
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(_isOwnProfile ? 8 : 0),
                            vertical: r.s(_isOwnProfile ? 4 : 0)),
                        decoration: _isOwnProfile
                            ? BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(r.s(20)),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.28),
                                  width: 1,
                                ),
                              )
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isUpdatingManualPresence && _isOwnProfile)
                              SizedBox(
                                width: r.s(8),
                                height: r.s(8),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.white,
                                ),
                              )
                            else
                              Container(
                                width: r.s(8),
                                height: r.s(8),
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF4CAF50)
                                      : Colors.grey[500],
                                  shape: BoxShape.circle,
                                  boxShadow: isOnline
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF4CAF50)
                                                .withValues(alpha: 0.7),
                                            blurRadius: 5,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                            SizedBox(width: r.s(5)),
                            Text(
                              presenceLabel,
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
                            if (_isOwnProfile) ...[  
                              SizedBox(width: r.s(3)),
                              Icon(
                                Icons.unfold_more_rounded,
                                color: Colors.white.withValues(alpha: 0.65),
                                size: r.s(13),
                              ),
                            ],
                            SizedBox(width: r.s(4)),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: _optionsButtonKey,
                      icon: Icon(Icons.more_horiz_rounded,
                          color: Colors.white, size: r.s(22)),
                      onPressed: () => _showOptions(context),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // ── Banner background (galeria rotativa ou banner estático) ──
                        // A galeria tem prioridade: cada imagem é exibida como capa
                        // alternando com fade a cada 20 segundos.
                        if (activeBannerUrl != null)
                          GestureDetector(
                            onTap: () => _openProfileMediaViewer(
                              context,
                              mediaUrls: profileMediaUrls,
                              initialUrl: activeBannerUrl,
                              heroTag:
                                  'community-profile-media-${widget.communityId}-${widget.userId}',
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 800),
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                      opacity: animation, child: child),
                              child: CachedNetworkImage(
                                key: ValueKey(activeBannerUrl),
                                imageUrl: activeBannerUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                color: Colors.black.withValues(alpha: 0.20),
                                colorBlendMode: BlendMode.darken,
                                errorWidget: (_, __, ___) =>
                                    displayBanner != null
                                        ? CachedNetworkImage(
                                            imageUrl: displayBanner,
                                            fit: BoxFit.cover,
                                            color: Colors.black
                                                .withValues(alpha: 0.25),
                                            colorBlendMode: BlendMode.darken,
                                            errorWidget: (_, __, ___) =>
                                                _defaultBannerGradient(),
                                          )
                                        : _defaultBannerGradient(),
                              ),
                            ),
                          )
                        else if (displayBanner != null)
                          GestureDetector(
                            onTap: () => _openProfileMediaViewer(
                              context,
                              mediaUrls: profileMediaUrls,
                              initialUrl: displayBanner,
                              heroTag:
                                  'community-profile-media-${widget.communityId}-${widget.userId}',
                            ),
                            child: CachedNetworkImage(
                              imageUrl: displayBanner,
                              fit: BoxFit.cover,
                              color: Colors.black.withValues(alpha: 0.25),
                              colorBlendMode: BlendMode.darken,
                              errorWidget: (_, __, ___) =>
                                  _defaultBannerGradient(),
                            ),
                          )
                        else
                          _defaultBannerGradient(),

                        // ── Gradient overlay (fade para effectiveBgColor na base) ──
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
                                  bannerFadeColor.withValues(alpha: 0.7),
                                  bannerFadeColor,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),

                        // ── Aviso de perfil oculto (visível apenas para moderadores) ──
                        // Posicionado abaixo da AppBar para não conflitar com a status bar Android
                        if (isHiddenProfile && canViewHiddenProfile)
                          Positioned(
                            top: kToolbarHeight + MediaQuery.of(context).padding.top + r.s(8),
                            left: 0,
                            right: 0,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                r.s(12),
                                0,
                                r.s(12),
                                0,
                              ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626)
                                        .withValues(alpha: 0.88),
                                    borderRadius: BorderRadius.circular(r.s(14)),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: r.s(10),
                                    horizontal: r.s(14),
                                  ),
                                  child: Row(
                                  children: [
                                    const Icon(Icons.visibility_off_rounded,
                                        color: Colors.white, size: 14),
                                    const SizedBox(width: 6),
                                    const Flexible(
                                      child: Text(
                                        'Perfil oculto pela moderação',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Desocultar perfil'),
                                            content: const Text(
                                                'Deseja restaurar a visibilidade deste perfil para todos os membros?'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancelar')),
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('Desocultar')),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true && mounted) {
                                          try {
                                            await SupabaseService.table(
                                                    'community_members')
                                                .update({'is_hidden': false})
                                                .eq('community_id',
                                                    widget.communityId)
                                                .eq('user_id', widget.userId);
                                            if (mounted) _loadProfile();
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: Text(
                                                    'Erro ao desocultar: $e'),
                                                backgroundColor: Colors.red,
                                              ));
                                            }
                                          }
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.5)),
                                        ),
                                        child: const Text(
                                          'Desocultar',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // ── Conteúdo do perfil (sobre o banner) ──────────────────────
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Avatar centralizado
                              // Moldura é 100% global: usa equippedItemsProvider
                              // (is_equipped em user_purchases) como única fonte.
                              Builder(builder: (context) {
                                final frameData = ref
                                        .watch(equippedItemsProvider(widget.userId))
                                        .valueOrNull ??
                                    {};
                                return AvatarWithFrame(
                                  avatarUrl: displayAvatar,
                                  frameUrl: frameData['frame_url'] as String?,
                                  isFrameAnimated:
                                      frameData['frame_is_animated'] as bool? ?? false,
                                  size: r.s(96),
                                  showAminoPlus: isPremium,
                                  hasActiveStory: _hasActiveStory,
                                  onTap: profileMediaUrls.isEmpty
                                      ? null
                                      : () => _openProfileMediaViewer(
                                            context,
                                            mediaUrls: profileMediaUrls,
                                            initialUrl: displayAvatar,
                                            heroTag:
                                                'community-profile-media-${widget.communityId}-${widget.userId}',
                                          ),
                                );
                              }),
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

                              // Level badge — estilo Amino: [🔷 12] + [Mítico]
                              GestureDetector(
                                onTap: () =>
                                    context.push('/all-rankings', extra: {
                                  'level': level,
                                  'reputation': reputation,
                                  'bannerUrl': _communityBannerUrl,
                                }),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Ícone quadrado colorido com número do nível
                                    Container(
                                      width: r.s(28),
                                      height: r.s(28),
                                      decoration: BoxDecoration(
                                        color: AppTheme.getLevelColor(level),
                                        borderRadius: BorderRadius.circular(r.s(6)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.getLevelColor(level)
                                                .withValues(alpha: 0.55),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$level',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: r.fs(13),
                                          fontWeight: FontWeight.w900,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: r.s(6)),
                                    // Pill com nome do nível
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: r.s(10), vertical: r.s(5)),
                                      decoration: BoxDecoration(
                                        color: AppTheme.getLevelColor(level)
                                            .withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(r.s(14)),
                                        border: Border.all(
                                          color: AppTheme.getLevelColor(level)
                                              .withValues(alpha: 0.50),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        title,
                                        style: TextStyle(
                                          color: AppTheme.getLevelColor(level),
                                          fontSize: r.fs(12),
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Badges e títulos customizados (inclui role badge via is_role_badge)
                              // O sync_role_badge já insere o badge de cargo (Líder/Curador/Agente)
                              // em custom_titles com is_role_badge=true — não renderizar manualmente.
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
                                Center(
                                  child: GestureDetector(
                                    onTap: () => context
                                        .push(
                                            '/community/${widget.communityId}/profile/edit')
                                        .then((_) => _loadProfile()),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: r.s(32),
                                          vertical: r.s(9)),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(r.s(6)),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.35),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.edit_rounded,
                                              size: r.s(14),
                                              color: Colors.white),
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
                                  ),
                                )
                              else
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Botão Seguir/Seguindo
                                    GestureDetector(
                                      onTap: _isTogglingFollow
                                          ? null
                                          : () => _toggleFollow(context),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: r.s(16),
                                            vertical: r.s(8)),
                                        decoration: BoxDecoration(
                                          color: _isFollowing
                                              ? Colors.transparent
                                              : const Color(0xFFFF9800),
                                          borderRadius:
                                              BorderRadius.circular(r.s(20)),
                                          border: _isFollowing
                                              ? Border.all(
                                                  color:
                                                      const Color(0xFFFF9800),
                                                  width: 1.5)
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_isTogglingFollow)
                                              SizedBox(
                                                width: r.s(14),
                                                height: r.s(14),
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: _isFollowing
                                                      ? const Color(0xFFFF9800)
                                                      : Colors.white,
                                                ),
                                              )
                                            else
                                              Text(
                                                _isFollowing && _isFollowingMe
                                                    ? '😸'
                                                    : _isFollowing
                                                        ? '✓'
                                                        : '😊',
                                                style: TextStyle(
                                                    fontSize: r.fs(14)),
                                              ),
                                            SizedBox(width: r.s(6)),
                                            Text(
                                              _isFollowing && _isFollowingMe
                                                  ? 'Amigos'
                                                  : _isFollowing
                                                      ? 'Seguindo'
                                                      : 'Seguir',
                                              style: TextStyle(
                                                color: _isFollowing
                                                    ? const Color(0xFFFF9800)
                                                    : Colors.white,
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
                                            horizontal: r.s(16),
                                            vertical: r.s(8)),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(r.s(20)),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.3),
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
                                padding:
                                    EdgeInsets.symmetric(horizontal: r.s(12)),
                                child: Row(
                                  children: [
                                    // Conquistas badge
                                    GestureDetector(
                                      onTap: () =>
                                          context.push('/achievements', extra: {
                                        'communityId': widget.communityId,
                                        'bannerUrl': _communityBannerUrl,
                                      }),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: r.s(12),
                                            vertical: r.s(6)),
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
                                                color: Colors.white,
                                                size: r.s(14)),
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
                                    if (canViewCoins)
                                      GestureDetector(
                                        onTap: () => context.push('/wallet'),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: r.s(10),
                                              vertical: r.s(6)),
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
                    color: layeredBgColor,
                    padding:
                        EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), r.s(8)),
                    child: Row(
                      children: [
                        // Reputação
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                formatCount(reputation),
                                style: TextStyle(
                                  color: context.nexusTheme.textPrimary,
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
                          child: InkWell(
                            onTap: () => context.push(
                                '/community/${widget.communityId}/profile/${widget.userId}/followers?tab=following'),
                            borderRadius: BorderRadius.circular(r.s(8)),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: r.s(8), horizontal: r.s(4)),
                              child: Column(
                                children: [
                                  Text(
                                    formatCount(_followingCount),
                                    style: TextStyle(
                                      color: context.nexusTheme.textPrimary,
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
                        ),
                        // Seguidores
                        Expanded(
                          child: InkWell(
                            onTap: () => context
                                .push('/community/${widget.communityId}/profile/${widget.userId}/followers'),
                            borderRadius: BorderRadius.circular(r.s(8)),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: r.s(8), horizontal: r.s(4)),
                              child: Column(
                                children: [
                                  Text(
                                    formatCount(_followersCount),
                                    style: TextStyle(
                                      color: context.nexusTheme.textPrimary,
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
                        top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.05)),
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
                                color: context.nexusTheme.textPrimary,
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
                        // Bio text + seta para abrir BioAndWallScreen
                        if (displayBio.isNotEmpty)
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BioAndWallScreen(
                                  userId: widget.userId,
                                  communityId: widget.communityId,
                                  displayName: displayName,
                                  avatarUrl: displayAvatar,
                                  bio: displayBio,
                                  isOwnProfile: _isOwnProfile,
                                ),
                              ),
                            ),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: r.s(12),
                                vertical: r.s(10),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(r.s(16)),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: RichBioRenderer(
                                      rawContent: displayBio,
                                      fontSize: r.fs(14),
                                      fallbackTextColor: Colors.grey[300],
                                      maxPreviewLines: 3,
                                    ),
                                  ),
                                  SizedBox(width: r.s(8)),
                                  Icon(
                                    Icons.keyboard_arrow_right_rounded,
                                    color: Colors.grey[500],
                                    size: r.s(20),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_isOwnProfile)
                          GestureDetector(
                            onTap: () => context
                                .push(
                                    '/community/${widget.communityId}/profile/edit')
                                .then((_) => _loadProfile()),
                            child: Text(
                              s.tapToAddBio,
                              style: TextStyle(
                                color: context.nexusTheme.accentSecondary,
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

                // A galeria definida na edição do perfil local é usada apenas
                // como fonte para a capa/banner rotativo do topo. Ela não deve
                // ser exibida como seção própria abaixo da biografia.

                // ================================================================
                // TABS — Posts | Mural | Posts Salvos
                // ================================================================
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: context.nexusTheme.accentPrimary,
                      unselectedLabelColor: Colors.grey[500],
                      indicatorColor: Colors.transparent,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(r.s(8)),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(14),
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: r.fs(14),
                      ),
                      tabs: [
                        Tab(
                          child: Text(
                            '${s.posts}${_userPosts.isNotEmpty ? ' ${_userPosts.length}' : ''}',
                          ),
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
                    isOwnWall: widget.userId == SupabaseService.currentUserId,
                    asBottomSheet: false,
                    // communityId garante que o mural é separado por comunidade
                    communityId: widget.communityId,
                  ),
                  _buildSavedPostsTab(),
                ],
              ),
            ),
          ),
        ],
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
                      color: context.nexusTheme.textPrimary,
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
                      color: context.nexusTheme.textPrimary,
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
                    onTap: () async {
                      final created = await context.push<bool>(
                        '/community/${widget.communityId}/wiki/create',
                      );
                      if (created == true && mounted) {
                        await _loadProfile();
                      }
                    },
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
                              color: context.nexusTheme.textPrimary,
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
                color: context.nexusTheme.textPrimary,
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
                ? context.nexusTheme.accentPrimary.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.05),
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: context.nexusTheme.accentPrimary
                        .withValues(alpha: 0.14),
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
                            color: context.nexusTheme.accentPrimary
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(r.s(999)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.push_pin_rounded,
                                size: r.s(14),
                                color: context.nexusTheme.accentPrimary,
                              ),
                              SizedBox(width: r.s(6)),
                              Text(
                                'Fixado no perfil',
                                style: TextStyle(
                                  color: context.nexusTheme.accentPrimary,
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
                            color: context.nexusTheme.textPrimary,
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
                              color: context.nexusTheme.accentPrimary,
                            ),
                            SizedBox(width: r.s(10)),
                            Text(
                              isPinnedProfile
                                  ? 'Desafixar do perfil'
                                  : 'Fixar no perfil',
                              style: TextStyle(
                                  color: context.nexusTheme.textPrimary),
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
            GestureDetector(
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  _buildCommunityPostAction(
                    icon: (post['is_liked'] == true)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: '${post['likes_count'] ?? 0}',
                    activeColor: context.nexusTheme.error,
                    isActive: post['is_liked'] == true,
                    onTap: () => _toggleCommunityProfilePostLike(post),
                  ),
                  SizedBox(width: r.s(16)),
                  _buildCommunityPostAction(
                    icon: Icons.comment_rounded,
                    label: '${post['comments_count'] ?? 0}',
                    onTap: () => context.push('/post/${post["id"]}'),
                  ),
                  SizedBox(width: r.s(16)),
                  _buildCommunityPostAction(
                    icon: Icons.repeat_rounded,
                    label: '${post['reposts_count'] ?? 0}',
                    onTap: () => _repostCommunityProfilePost(post),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityPostAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? activeColor,
    bool isActive = false,
  }) {
    final r = context.r;
    final color = isActive
        ? (activeColor ?? context.nexusTheme.accentPrimary)
        : Colors.grey[600];

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: r.s(16), color: color),
          SizedBox(width: r.s(4)),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: r.fs(12),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCommunityProfilePostLike(
      Map<String, dynamic> post) async {
    final postId = post['id'] as String?;
    final currentUserId = SupabaseService.currentUserId;
    if (postId == null || currentUserId == null) {
      debugPrint(
        '[community_profile_screen][like] aborted: missing identifiers '
        'postId=$postId userId=$currentUserId',
      );
      return;
    }

    final currentIndex = _userPosts.indexWhere((item) => item['id'] == postId);
    if (currentIndex == -1) {
      debugPrint(
        '[community_profile_screen][like] aborted: post not found in local list '
        'postId=$postId',
      );
      return;
    }

    Map<String, dynamic>? previousPost;

    try {
      final existingLike = await SupabaseService.table('likes')
          .select('id')
          .eq('user_id', currentUserId)
          .eq('post_id', postId)
          .maybeSingle();

      final wasLiked = existingLike != null;
      final currentPost = Map<String, dynamic>.from(_userPosts[currentIndex]);
      previousPost = Map<String, dynamic>.from(currentPost);
      final currentLikes = (currentPost['likes_count'] as num?)?.toInt() ?? 0;
      final params = {
        'p_community_id': currentPost['community_id'] ?? widget.communityId,
        'p_user_id': currentUserId,
        'p_post_id': postId,
      };

      debugPrint(
        '[community_profile_screen][like] start postId=$postId '
        'communityId=${params['p_community_id']} userId=$currentUserId '
        'wasLiked=$wasLiked currentLikes=$currentLikes',
      );

      setState(() {
        _userPosts[currentIndex] = {
          ...currentPost,
          'is_liked': !wasLiked,
          'likes_count': wasLiked
              ? (currentLikes > 0 ? currentLikes - 1 : 0)
              : currentLikes + 1,
        };
      });

      final result = await SupabaseService.rpc(
        'toggle_like_with_reputation',
        params: params,
      );
      debugPrint(
        '[community_profile_screen][like] success postId=$postId result=$result',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[community_profile_screen][like] error postId=$postId error=$e',
      );
      debugPrint('[community_profile_screen][like] stackTrace=$stackTrace');
      if (previousPost != null && mounted) {
        setState(() {
          _userPosts[currentIndex] = previousPost!;
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível atualizar a curtida deste blog.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _repostCommunityProfilePost(Map<String, dynamic> post) async {
    final postId = post['id'] as String?;
    final currentUserId = SupabaseService.currentUserId;
    if (postId == null || currentUserId == null) {
      debugPrint(
        '[community_profile_screen][repost] aborted: missing identifiers '
        'postId=$postId userId=$currentUserId',
      );
      return;
    }

    debugPrint(
      '[community_profile_screen][repost] start postId=$postId '
      'communityId=${post['community_id'] ?? widget.communityId} '
      'authorId=${post['author_id']} currentUserId=$currentUserId '
      'type=${post['type']}',
    );

    if ((post['author_id'] as String?) == currentUserId) {
      debugPrint(
          '[community_profile_screen][repost] aborted: own post postId=$postId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não é possível republicar seu próprio post.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if ((post['type'] as String?) == 'repost') {
      debugPrint(
          '[community_profile_screen][repost] aborted: post already is repost postId=$postId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não é possível republicar um repost.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final params = {
      'p_original_post_id': postId,
      'p_community_id': post['community_id'] ?? widget.communityId,
    };

    try {
      final result = await SupabaseService.rpc('repost_post', params: params);
      debugPrint(
        '[community_profile_screen][repost] success postId=$postId result=$result',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blog republicado com sucesso.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[community_profile_screen][repost] error postId=$postId '
        'params=$params error=$e',
      );
      debugPrint('[community_profile_screen][repost] stackTrace=$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível republicar este blog.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
      color: context.nexusTheme.backgroundPrimary,
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
      return Center(
        child:
            CircularProgressIndicator(color: context.nexusTheme.accentPrimary),
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
        final localSelfNickname =
            (_membership?['local_nickname'] as String?)?.trim();
        final displayAuthorName = authorId == widget.userId &&
                (localSelfNickname?.isNotEmpty ?? false)
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
                          color: context.nexusTheme.textPrimary,
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
                      color: context.nexusTheme.accentPrimary, size: r.s(20)),
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
    if (_isTogglingFollow) return;
    final s = getStrings();
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return;

    // Atualização otimista — muda visualmente antes da resposta do servidor
    setState(() {
      _isTogglingFollow = true;
      _isFollowing = !_isFollowing;
      if (_isFollowing) {
        _followersCount++;
      } else {
        _followersCount = (_followersCount - 1).clamp(0, 999999);
      }
    });

    try {
      final result = await SupabaseService.rpc(
        'toggle_follow_with_reputation',
        params: {
          'p_community_id': widget.communityId,
          'p_follower_id': currentUserId,
          'p_following_id': widget.userId,
        },
      );
      // Reconciliar com o estado real retornado pelo servidor
      final isNowFollowing =
          result is Map ? (result['following'] == true) : _isFollowing;
      if (mounted) {
        setState(() {
          _isFollowing = isNowFollowing;
          // Recarregar contagem real do servidor
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNowFollowing ? s.followingNow : s.unfollowed),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Recarregar contagem real
        final followersRes = await SupabaseService.table('follows')
            .select()
            .eq('community_id', widget.communityId)
            .eq('following_id', widget.userId);
        if (mounted) {
          setState(() {
            _followersCount = (followersRes as List?)?.length ?? 0;
          });
        }
      }
    } catch (e) {
      // Reverter atualização otimista em caso de erro
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          if (_isFollowing) {
            _followersCount++;
          } else {
            _followersCount = (_followersCount - 1).clamp(0, 999999);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.anErrorOccurredTryAgain)),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingFollow = false);
    }
  }

  Future<void> _openDm(BuildContext context) async {
    final s = getStrings();
    try {
      final threadId = await DmInviteService()
          .sendInvite(widget.userId, communityId: widget.communityId);
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
        } else if (err.contains(s.cannotMessageUser)) {
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
              style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontWeight: FontWeight.w800)),
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
                  style: TextStyle(
                      color: context.nexusTheme.error,
                      fontWeight: FontWeight.w800)),
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
              style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontWeight: FontWeight.w800)),
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
                  style: TextStyle(
                      color: context.nexusTheme.error,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      // Mostrar loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.nexusTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Text(s.block + '...'),
            ],
          ),
          backgroundColor: context.surfaceColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 10),
        ));
      }
      final ok = await notifier.block(widget.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (ok) {
        // Atualizar estado local: remover follows mútuos
        setState(() {
          _isFollowing = false;
          _isFollowingMe = false;
          if (_followersCount > 0) _followersCount--;
        });
        // Navegar de volta ANTES de mostrar o snackbar para evitar que seja descartado
        if (mounted) {
          context.pop();
          // Mostrar snackbar na tela anterior usando o rootScaffoldMessenger
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(s.blockSuccess),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao bloquear usuário. Tente novamente.'),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ============================================================================
  // OPTIONS BOTTOM SHEET
  // ============================================================================
  // Calcula a posição do botão de opções para o dropdown
  RelativeRect _optionsButtonRect() {
    final renderBox =
        _optionsButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      // Fallback: canto superior direito
      return const RelativeRect.fromLTRB(1000, 60, 8, 0);
    }
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()
        as RenderBox;
    return RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(Offset.zero, ancestor: overlay),
        renderBox.localToGlobal(
            renderBox.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
  }

  Future<void> _showOptions(BuildContext context) async {
    final s = getStrings();
    final r = context.r;

    final myRole = _myMembership?['role'] as String? ?? 'member';
    // team_member (is_team_admin / is_team_moderator) é superior a qualquer
    // role de comunidade e tem acesso total de moderação.
    // O menu de moderação aparece também no próprio perfil do moderador.
    final canManageRoles =
        _viewerIsTeamMember ||
        myRole == 'agent' ||
        myRole == 'leader' ||
        myRole == 'curator';
    final canManageTitles =
        _viewerIsTeamMember || myRole == 'agent' || myRole == 'leader';

    // Itens do menu: cada item é um Map com icon, label, value e isDestructive
    // Usamos showMenu nativo do Flutter para o estilo dropdown.
    final items = <PopupMenuEntry<String>>[];

    // ── AÇÕES SOCIAIS ──────────────────────────────────────────────────
    if (!_isOwnProfile) {
      items.add(_menuItem(
        value: 'dm',
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Enviar mensagem',
        r: r,
      ));
    }
    items.add(_menuItem(
      value: 'share',
      icon: Icons.share_rounded,
      label: s.shareProfile,
      r: r,
    ));

    // ── MODERAÇÃO ───────────────────────────────────────────────────
    if (canManageRoles) {
      items.add(const PopupMenuDivider(height: 1));
      items.add(_menuItem(
        value: 'moderation',
        icon: Icons.manage_accounts_rounded,
        label: 'Opções de moderação',
        r: r,
      ));
      if (canManageTitles) {
        items.add(_menuItem(
          value: 'titles',
          icon: Icons.label_rounded,
          label: 'Gerenciar títulos',
          r: r,
        ));
      }
      if ((_membership?['is_hidden'] as bool?) == true) {
        items.add(_menuItem(
          value: 'unhide',
          icon: Icons.visibility_rounded,
          label: 'Desocultar perfil',
          r: r,
        ));
      }
    }

    // ── AÇÕES DESTRUTIVAS ─────────────────────────────────────────────
    if (!_isOwnProfile) {
      items.add(const PopupMenuDivider(height: 1));
      items.add(_menuItem(
        value: 'report',
        icon: Icons.flag_rounded,
        label: s.report,
        r: r,
        isDestructive: true,
      ));
      final isBlocked = ref.read(isBlockedProvider(widget.userId));
      items.add(_menuItem(
        value: 'block',
        icon: isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
        label: isBlocked ? s.unblockAction : s.block,
        r: r,
        isDestructive: true,
      ));
    }

    final selected = await showMenu<String>(
      context: context,
      position: _optionsButtonRect(),
      elevation: 10,
      color: context.nexusTheme.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r.s(14)),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      items: items,
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case 'dm':
        _openDm(context);
        break;

      case 'share':
        final link =
            'https://nexushub.app/community/${widget.communityId}/profile/${widget.userId}';
        Clipboard.setData(ClipboardData(text: link));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(s.profileLinkCopied),
            backgroundColor: context.nexusTheme.accentPrimary,
            behavior: SnackBarBehavior.floating,
          ));
        }
        break;

      case 'moderation':
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
          membershipData: Map<String, dynamic>.from(_membership ?? {}),
          callerRole: _viewerIsTeamMember ? 'agent' : myRole,
        );
        if (changed == true && mounted) _loadProfile();
        break;

      case 'titles':
        final titleTargetName = _user?.nickname ?? 'Membro';
        final titlesChanged = await showManageMemberTitlesSheet(
          context: context,
          ref: ref,
          communityId: widget.communityId,
          targetUserId: widget.userId,
          targetUserName: titleTargetName,
          callerRole: _viewerIsTeamMember ? 'agent' : myRole,
        );
        if (titlesChanged == true && mounted) _loadProfile();
        break;

      case 'unhide':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: context.surfaceColor,
            title: Text('Desocultar perfil',
                style: TextStyle(color: context.nexusTheme.textPrimary)),
            content: Text(
              'Deseja restaurar a visibilidade deste perfil para todos os membros?',
              style: TextStyle(color: context.nexusTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: Text('Cancelar',
                    style: TextStyle(color: Colors.grey[500])),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Desocultar'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        try {
          await SupabaseService.table('community_members')
              .update({'is_hidden': false})
              .eq('community_id', widget.communityId)
              .eq('user_id', widget.userId);
          await _loadProfile();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Perfil desocultado com sucesso'),
            backgroundColor: context.nexusTheme.accentPrimary,
            behavior: SnackBarBehavior.floating,
          ));
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao desocultar: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
        break;

      case 'report':
        ReportDialog.show(
          context,
          communityId: widget.communityId,
          targetUserId: widget.userId,
        );
        break;

      case 'block':
        final isBlocked = ref.read(isBlockedProvider(widget.userId));
        await _handleBlockToggle(isBlocked);
        break;
    }
  }

  /// Constrói um item de menu com ícone e label no estilo do projeto.
  PopupMenuItem<String> _menuItem({
    required String value,
    required IconData icon,
    required String label,
    required Responsive r,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? context.nexusTheme.error
        : context.nexusTheme.textPrimary;
    return PopupMenuItem<String>(
      value: value,
      padding: EdgeInsets.symmetric(
          horizontal: r.s(16), vertical: r.s(4)),
      child: Row(
        children: [
          Icon(icon, color: color, size: r.s(20)),
          SizedBox(width: r.s(12)),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: r.fs(14),
              fontWeight: FontWeight.w500,
            ),
          ),
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
            context.nexusTheme.accentPrimary.withValues(alpha: 0.6),
            context.nexusTheme.backgroundPrimary,
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
