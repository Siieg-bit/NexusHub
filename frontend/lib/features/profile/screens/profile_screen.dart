import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/iap_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/widgets/chat_bubble.dart'; // AvatarWithFrame, AminoPlusBadge
import '../../../core/utils/responsive.dart';

// Extracted providers & widgets
import '../providers/profile_providers.dart';
import '../widgets/profile_linked_communities.dart';
import '../widgets/profile_stories_tab.dart';
import '../widgets/profile_wall_tab.dart';
import '../widgets/profile_pinned_wikis.dart';
import '../widgets/rich_bio.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/providers/block_provider.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/widgets/image_viewer.dart';
import '../../../core/widgets/user_status_badge.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/services/haptic_service.dart';
import '../widgets/profile_visitors_section.dart';

// =============================================================================
// PROFILE SCREEN — Layout fiel ao Amino Apps
// =============================================================================

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _followController;
  final _wallController = TextEditingController();
  bool? _followOverride;
  bool _isTogglingFollow = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _followController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Registrar visita ao perfil (se não for o próprio perfil)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId != null && currentUserId != widget.userId) {
        SupabaseService.rpc('record_profile_visit', params: {
          'p_visited_id': widget.userId,
        }).catchError((_) {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _followController.dispose();
    _wallController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final profileAsync = ref.watch(userProfileProvider(widget.userId));
    final equippedAsync = ref.watch(equippedItemsProvider(widget.userId));
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = currentUser?.id == widget.userId;
    final isBlocked = ref.watch(isBlockedProvider(widget.userId));

    return profileAsync.when(
      loading: () => Scaffold(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        body: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: const ProfileScreenSkeleton(),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded,
                color: context.nexusTheme.textPrimary, size: r.s(20)),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: r.s(48), color: Colors.grey[700]),
              SizedBox(height: r.s(12)),
              Text(s.errorLoadingProfile,
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: r.fs(15))),
              SizedBox(height: r.s(16)),
              GestureDetector(
                onTap: () => ref.invalidate(userProfileProvider(widget.userId)),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(20), vertical: r.s(10)),
                  decoration: BoxDecoration(
                    color: context.nexusTheme.accentPrimary,
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Text(s.retry,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (user) {
        final frameUrl = equippedAsync.valueOrNull?['frame_url'];
        final frameIsAnimated =
            equippedAsync.valueOrNull?['frame_is_animated'] as bool? ?? false;
        final isAminoPlus = user.isPremium || IAPService.isAminoPlus;
        final displayedIsFollowing = _followOverride ?? (user.isFollowing == true);

        if (isBlocked && !isOwnProfile) {
          final displayName = user.nickname.isNotEmpty ? user.nickname : s.user;
          return Scaffold(
            backgroundColor: context.nexusTheme.backgroundPrimary,
            appBar: AppBar(
              backgroundColor: context.nexusTheme.backgroundPrimary,
              foregroundColor: context.nexusTheme.textPrimary,
              title: Text(displayName),
              actions: [
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showUserOptions(context, user),
                  tooltip: 'Opções',
                ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(r.s(32)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.block_rounded,
                      size: r.s(64),
                      color: context.nexusTheme.textSecondary,
                    ),
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
                      'Você bloqueou este usuário. Posts, mural e outras informações do perfil foram ocultados.',
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
                          horizontal: r.s(24),
                          vertical: r.s(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: context.nexusTheme.backgroundPrimary,
          body: RefreshIndicator(
            color: context.nexusTheme.accentPrimary,
            onRefresh: () async {
              ref.invalidate(userProfileProvider(widget.userId));
              ref.invalidate(equippedItemsProvider(widget.userId));
              await Future.delayed(const Duration(milliseconds: 300));
            },
            child: NestedScrollView(
              floatHeaderSlivers: true,
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                // ================================================================
                // TOP BAR
                // ================================================================
                SliverAppBar(
                  pinned: true,
                  backgroundColor: context.nexusTheme.backgroundPrimary.withValues(alpha: 0.95),
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white, size: r.s(20)),
                    onPressed: () => context.pop(),
                  ),
                  title: isOwnProfile
                      ? _ProfileCoinsPill(
                          coins: user.coins,
                          onTap: () => context.push('/wallet'),
                          onAddTap: () => context.push('/coin-shop'),
                        )
                      : const SizedBox.shrink(),
                  centerTitle: true,
                  actions: [
                    IconButton(
                      icon: Icon(Icons.share_outlined,
                          color: Colors.white, size: r.s(22)),
                      tooltip: 'Compartilhar perfil',
                      onPressed: () => DeepLinkService.shareUrl(
                        type: 'user',
                        targetId: widget.userId,
                        title: s.shareProfile,
                        text: s.shareProfile,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isOwnProfile
                            ? Icons.menu_rounded
                            : Icons.more_horiz_rounded,
                        color: Colors.white,
                        size: r.s(22),
                      ),
                      onPressed: isOwnProfile
                          ? () => context.push('/settings')
                          : () => _showUserOptions(context, user),
                    ),
                  ],
                ),

                // ================================================================
                // AVATAR + EDIT PROFILE
                // ================================================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AvatarWithFrame(
                          avatarUrl: user.iconUrl,
                          frameUrl: frameUrl,
                          size: r.s(80),
                          showAminoPlus: isAminoPlus,
                          isFrameAnimated: frameIsAnimated,
                          onTap: (user.iconUrl?.trim().isNotEmpty ?? false)
                              ? () => showMediaViewer(
                                    context,
                                    mediaUrls: [user.iconUrl!.trim()],
                                    initialIndex: 0,
                                    heroTag: 'profile-avatar-${user.id}',
                                  )
                              : null,
                        ),
                        const Spacer(),
                        Padding(
                          padding: EdgeInsets.only(top: r.s(16)),
                          child: isOwnProfile
                              ? GestureDetector(
                                  onTap: () async {
                                    await context.push('/profile/edit');
                                    if (mounted) {
                                      ref.invalidate(userProfileProvider(widget.userId));
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: r.s(16), vertical: r.s(8)),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                      borderRadius:
                                          BorderRadius.circular(r.s(8)),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_rounded,
                                            size: r.s(14),
                                            color: Colors.grey[400]),
                                        SizedBox(width: r.s(6)),
                                        Text(
                                          s.editProfile,
                                          style: TextStyle(
                                            color: Colors.grey[300],
                                            fontWeight: FontWeight.w600,
                                            fontSize: r.fs(13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ScaleTransition(
                                  scale: Tween<double>(begin: 1.0, end: 0.93)
                                      .chain(CurveTween(curve: Curves.easeInOut))
                                      .animate(_followController)
                                      ..addStatusListener((status) {
                                        if (status == AnimationStatus.completed) {
                                          _followController.reverse();
                                        }
                                      }),
                                  child: GestureDetector(
                                    onTap: _isTogglingFollow
                                        ? null
                                        : () => _toggleFollow(ref, user),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: r.s(20), vertical: r.s(8)),
                                      decoration: BoxDecoration(
                                        color: displayedIsFollowing
                                            ? Colors.transparent
                                            : context.nexusTheme.accentSecondary,
                                        borderRadius:
                                            BorderRadius.circular(r.s(8)),
                                        border: displayedIsFollowing
                                            ? Border.all(
                                                color: context.nexusTheme.accentSecondary)
                                            : null,
                                      ),
                                      child: _isTogglingFollow
                                          ? SizedBox(
                                              width: r.s(16),
                                              height: r.s(16),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: displayedIsFollowing
                                                    ? context.nexusTheme.accentSecondary
                                                    : Colors.white,
                                              ),
                                            )
                                          : AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 200),
                                              child: Text(
                                                displayedIsFollowing
                                                    ? s.following
                                                    : s.follow,
                                                key: ValueKey(displayedIsFollowing),
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: r.fs(13),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ================================================================
                // NOME + BADGES + @USERNAME
                // ================================================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.nickname,
                                style: TextStyle(
                                  color: context.nexusTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: r.fs(22),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAminoPlus) ...[
                              SizedBox(width: r.s(6)),
                              const AminoPlusBadge(),
                            ],
                            if (user.isNicknameVerified) ...[
                              SizedBox(width: r.s(4)),
                              Icon(Icons.verified_rounded,
                                  color: context.nexusTheme.accentSecondary, size: r.s(18)),
                            ],
                          ],
                        ),
                         const SizedBox(height: 2),
                        if (user.aminoId.isNotEmpty)
                          Text(
                            '@${user.aminoId}',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: r.fs(13)),
                          ),
                        // Mood/Status
                        if (user.hasStatus) ...[  
                          SizedBox(height: r.s(6)),
                          GestureDetector(
                            onTap: isOwnProfile
                                ? () => EditStatusSheet.show(
                                      context,
                                      currentEmoji: user.statusEmoji,
                                      currentText: user.statusText,
                                      onSaved: (_, __) => ref.invalidate(
                                          userProfileProvider(widget.userId)),
                                    )
                                : null,
                            child: UserStatusBadge(
                              emoji: user.statusEmoji,
                              text: user.statusText,
                            ),
                          ),
                        ] else if (isOwnProfile) ...[  
                          SizedBox(height: r.s(6)),
                          GestureDetector(
                            onTap: () => EditStatusSheet.show(
                              context,
                              onSaved: (_, __) => ref.invalidate(
                                  userProfileProvider(widget.userId)),
                            ),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: r.s(8), vertical: r.s(3)),
                              decoration: BoxDecoration(
                                color: context.nexusTheme.backgroundSecondary
                                    .withValues(alpha: 0.6),
                                borderRadius:
                                    BorderRadius.circular(r.s(12)),
                                border: Border.all(
                                  color: Colors.grey[700]!,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded,
                                      size: r.s(12),
                                      color: Colors.grey[500]),
                                  SizedBox(width: r.s(4)),
                                  Text(
                                    'Definir status',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: r.fs(11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // ================================================================
                // FOLLOWING / FOLLOWERS
                // ================================================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(16), vertical: r.s(12)),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push(
                                '/user/${widget.userId}/followers?tab=following'),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: r.s(14)),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(r.s(12)),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _formatCount(user.followingCount),
                                    style: TextStyle(
                                      color: context.nexusTheme.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: r.fs(20),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.following,
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: r.fs(12)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: r.s(12)),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context
                                .push('/user/${widget.userId}/followers'),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: r.s(14)),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(r.s(12)),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _formatCount(user.followersCount),
                                    style: TextStyle(
                                      color: context.nexusTheme.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: r.fs(20),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.followers,
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: r.fs(12)),
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
                // BIO
                // ================================================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.s(16),
                      vertical: r.s(4),
                    ),
                    child: user.bio.isNotEmpty
                        ? RichBioRenderer(
                            rawContent: user.bio,
                            fontSize: r.fs(14),
                            fallbackTextColor: Colors.grey[300],
                          )
                        : isOwnProfile
                            ? GestureDetector(
                                onTap: () async {
                                  await context.push('/profile/edit');
                                  if (mounted) {
                                    ref.invalidate(userProfileProvider(widget.userId));
                                  }
                                },
                                child: Text(
                                  s.tapToAddBio,
                                  style: TextStyle(
                                    color: context.nexusTheme.accentSecondary,
                                    fontSize: r.fs(13),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                  ),
                ),

                // ================================================================
                // VERIFIED BADGE REQUEST (apenas para o próprio perfil não verificado)
                // ================================================================
                if (isOwnProfile && !user.isNicknameVerified)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(16), vertical: r.s(4)),
                      child: GestureDetector(
                        onTap: () => context.push('/profile/verified-badge'),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(14), vertical: r.s(10)),
                          decoration: BoxDecoration(
                            color: context.nexusTheme.accentSecondary
                                .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(r.s(10)),
                            border: Border.all(
                              color: context.nexusTheme.accentSecondary
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.verified_outlined,
                                  color: context.nexusTheme.accentSecondary,
                                  size: r.s(18)),
                              SizedBox(width: r.s(10)),
                              Expanded(
                                child: Text(
                                  'Solicitar verificação de nickname',
                                  style: TextStyle(
                                    color: context.nexusTheme.accentSecondary,
                                    fontSize: r.fs(13),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  color: context.nexusTheme.accentSecondary
                                      .withValues(alpha: 0.6),
                                  size: r.s(14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // ================================================================
                // VISITANTES RECENTES (apenas para o próprio perfil)
                // ================================================================
                if (isOwnProfile)
                  const SliverToBoxAdapter(
                    child: ProfileVisitorsSection(),
                  ),
                // ================================================================
                // AMINO+ BANNER
                // ================================================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(16), vertical: r.s(8)),
                    child: GestureDetector(
                      onTap: () => context.go('/store'),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(14), vertical: r.s(12)),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(r.s(12)),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: r.s(8), vertical: r.s(4)),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700),
                                borderRadius: BorderRadius.circular(r.s(6)),
                              ),
                              child: Text(
                                s.aminoPlus,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: r.fs(11),
                                ),
                              ),
                            ),
                            SizedBox(width: r.s(10)),
                            Expanded(
                              child: Text(
                                isAminoPlus
                                    ? 'Membro Amino+'
                                    : 'Try Amino+ for free today!',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: r.fs(13),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ================================================================
                // DIVIDER
                // ================================================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(16), vertical: r.s(4)),
                    child: Divider(
                      color: Colors.white.withValues(alpha: 0.08),
                      height: 1,
                    ),
                  ),
                ),

                // ================================================================
                // LINKED COMMUNITIES
                // ================================================================
                SliverToBoxAdapter(
                  child: ProfileLinkedCommunities(userId: widget.userId),
                ),

                // ================================================================
                // DIVIDER
                // ================================================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(16), vertical: r.s(4)),
                    child: Divider(
                      color: Colors.white.withValues(alpha: 0.08),
                      height: 1,
                    ),
                  ),
                ),

                // ================================================================
                // PINNED WIKIS
                // ================================================================
                SliverToBoxAdapter(
                  child: ProfilePinnedWikis(userId: widget.userId),
                ),

                // ================================================================
                // TABS — Stories | Wall
                // ================================================================
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    tabBar: TabBar(
                      controller: _tabController,
                      labelColor: context.nexusTheme.textPrimary,
                      unselectedLabelColor: Colors.grey[600],
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: r.fs(16),
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: r.fs(16),
                      ),
                      indicatorColor: context.nexusTheme.textPrimary,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.label,
                      tabs: [
                        Tab(text: s.stories),
                        Tab(text: user.wallCommentsCount > 0 ? '${s.wall} ${user.wallCommentsCount}' : s.wall),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  ProfileStoriesTab(userId: widget.userId),
                  ProfileWallTab(
                    userId: widget.userId,
                    wallController: _wallController,
                  ),
                ],
              ),
            ),
          ), // RefreshIndicator
        );
      },
    );
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  static String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Future<void> _toggleFollow(WidgetRef ref, UserModel user) async {
    if (_isTogglingFollow) return;

    final previous = _followOverride ?? (user.isFollowing == true);
    // Haptic + animação de fill ao seguir
    if (!previous) {
      HapticService.success();
      _followController.forward(from: 0);
    } else {
      HapticService.buttonPress();
      _followController.reverse();
    }

    setState(() {
      _isTogglingFollow = true;
      _followOverride = !previous;
    });

    try {
      final result = await SupabaseService.rpc(
        'toggle_follow_with_reputation',
        params: {
          'p_community_id': null,
          'p_follower_id': SupabaseService.currentUserId ?? '',
          'p_following_id': widget.userId,
        },
      );

      final resolved = result is Map
          ? (result['following'] == true)
          : (_followOverride ?? !previous);

      if (!mounted) return;
      setState(() {
        _followOverride = resolved;
        _isTogglingFollow = false;
      });
      ref.invalidate(userProfileProvider(widget.userId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _followOverride = previous;
        _isTogglingFollow = false;
      });
    }
  }

  Future<void> _handleBlockToggle(bool isCurrentlyBlocked) async {
    final s = ref.read(stringsProvider);
    final notifier = ref.read(blockedIdsProvider.notifier);
    if (isCurrentlyBlocked) {
      // Desbloquear
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          title: Text(s.unblockUser,
              style: TextStyle(color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w800)),
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
                  style: TextStyle(color: context.nexusTheme.error, fontWeight: FontWeight.w800)),
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
        ref.invalidate(userProfileProvider(widget.userId));
      }
    } else {
      // Bloquear
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          title: Text(s.blockConfirmTitle,
              style: TextStyle(color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w800)),
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
                  style: TextStyle(color: context.nexusTheme.error, fontWeight: FontWeight.w800)),
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
        ref.invalidate(userProfileProvider(widget.userId));
        if (mounted) context.pop();
      }
    }
  }

  void _showUserOptions(BuildContext context, UserModel user) {
    final s = getStrings();
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
            _optionTile(Icons.comment_rounded, 'Ver Mural', () {
              Navigator.pop(ctx);
              context.push('/user/${widget.userId}/wall');
            }),
            _optionTile(Icons.people_rounded, s.followers, () {
              Navigator.pop(ctx);
              context.push('/user/${widget.userId}/followers');
            }),
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
        ),
      ),
    );
  }

  Widget _optionTile(IconData icon, String label, VoidCallback onTap,
      {bool isDestructive = false}) {
    final r = context.r;
    final color = isDestructive ? context.nexusTheme.error : Colors.grey[400];
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
}

// =============================================================================
// TAB BAR DELEGATE
// =============================================================================
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate({required this.tabBar});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: context.nexusTheme.backgroundPrimary,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}

// =============================================================================
// COINS PILL — Unificado com o sistema do AminoTopBar
// Usa tokens do NexusTheme e formato pontuado (ex: 96.806)
// =============================================================================
class _ProfileCoinsPill extends ConsumerWidget {
  final int coins;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;

  const _ProfileCoinsPill({
    required this.coins,
    this.onTap,
    this.onAddTap,
  });

  static String _formatCoins(int coins) {
    if (coins >= 1000000) {
      return '${(coins / 1000000).toStringAsFixed(1)}M';
    }
    if (coins >= 1000) {
      final str = coins.toString();
      final buffer = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
        buffer.write(str[i]);
      }
      return buffer.toString();
    }
    return coins.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r.s(13)),
      child: SizedBox(
        height: r.s(26),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Metade esquerda: fundo walletGradient + moeda + valor ──
            GestureDetector(
              onTap: onTap,
              child: Container(
                height: r.s(26),
                padding: EdgeInsets.symmetric(horizontal: r.s(8)),
                color: theme.walletGradient.colors.first,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: r.s(15),
                      height: r.s(15),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.coinColor,
                        boxShadow: [
                          BoxShadow(
                            color: theme.overlayColor.withValues(alpha: 0.2),
                            blurRadius: 1,
                            offset: const Offset(0, 0.5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '\$',
                          style: TextStyle(
                            color: theme.buttonPrimaryForeground,
                            fontSize: r.fs(8),
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: r.s(4)),
                    Text(
                      _formatCoins(coins),
                      style: TextStyle(
                        color: theme.buttonPrimaryForeground,
                        fontSize: r.fs(12),
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Metade direita: accentPrimary + "+" ──
            GestureDetector(
              onTap: onAddTap,
              child: Container(
                height: r.s(26),
                width: r.s(26),
                color: theme.accentPrimary,
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: theme.buttonPrimaryForeground,
                    size: r.s(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
