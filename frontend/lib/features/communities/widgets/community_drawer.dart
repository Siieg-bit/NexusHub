import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../providers/community_shared_providers.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/amino_drawer.dart';
import '../../../core/widgets/avatar_with_frame.dart';
import '../../profile/providers/profile_providers.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/level_up_dialog.dart';
import '../../../core/widgets/level_badge.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/widgets/nexus_badge.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../../core/services/haptic_service.dart';

// Provider de flags pendentes por comunidade (visível apenas para moderadores)
final _pendingFlagsCountProvider =
    FutureProvider.family<int, String>((ref, communityId) async {
  try {
    final res = await SupabaseService.table('flags')
        .select('id')
        .eq('community_id', communityId)
        .eq('status', 'pending');
    return (res as List?)?.length ?? 0;
  } catch (_) {
    return 0;
  }
});

// =============================================================================
// COMMUNITY DRAWER — Painel lateral da comunidade
// Totalmente tematizado via NexusThemeData
// =============================================================================

class CommunityDrawer extends ConsumerStatefulWidget {
  final CommunityModel community;
  final UserModel? currentUser;
  final String? userRole;
  final Map<String, dynamic>? membership;

  const CommunityDrawer({
    super.key,
    required this.community,
    this.currentUser,
    this.userRole,
    this.membership,
  });

  @override
  ConsumerState<CommunityDrawer> createState() => _CommunityDrawerState();
}

class _CommunityDrawerState extends ConsumerState<CommunityDrawer> {
  bool _isCheckingIn = false;
  // Controla se a seção "Ver mais" está expandida
  bool _seeMoreExpanded = false;

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return context.nexusTheme.accentPrimary;
    }
  }

  bool get _isTeamMember => widget.currentUser?.isTeamMember ?? false;

  bool get _isStaff =>
      _isTeamMember ||
      widget.userRole == 'agent' ||
      widget.userRole == 'leader' ||
      widget.userRole == 'curator' ||
      widget.userRole == 'moderator' ||
      widget.userRole == 'admin';

  bool get _isLeader =>
      _isTeamMember ||
      widget.userRole == 'agent' ||
      widget.userRole == 'leader';

  // ── Check-in ──────────────────────────────────────────────────────────────

  Future<void> _doCheckIn() async {
    if (_isCheckingIn) return;
    final s = ref.read(stringsProvider);
    setState(() => _isCheckingIn = true);
    try {
      final result = await SupabaseService.rpc('daily_checkin', params: {
        'p_community_id': widget.community.id,
      });
      if (!mounted) return;
      ref.invalidate(checkInStatusProvider);
      final data = result as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        final streak = data['streak'] as int? ?? 1;
        final coins = data['coins_earned'] as int? ?? 0;
        final levelUp = data['level_up'] as bool? ?? false;
        final newLevel = data['new_level'] as int? ?? 0;
        HapticService.action();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.checkInStreakMsg(streak, coins)),
          backgroundColor: context.nexusTheme.accentSecondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
        if (levelUp && newLevel > 0 && mounted) {
          LevelUpDialog.show(context, newLevel: newLevel);
        }
      } else if (data != null && data['error'] == 'already_checked_in') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.alreadyCheckedInCommunity),
          backgroundColor: context.nexusTheme.warning,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.errorCheckIn),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  // ── Navegação ─────────────────────────────────────────────────────────────

  void _closeAndNavigate(VoidCallback action) {
    final ctrl = AminoDrawerController.of(context);
    if (ctrl != null && ctrl.isOpen) {
      ctrl.close();
    } else {
      Navigator.maybePop(context);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    final themeColor = _parseColor(widget.community.themeColor);
    final checkInStatus = ref.watch(checkInStatusProvider);
    final statusMap = checkInStatus.valueOrNull ?? {};
    final myStatus = statusMap[widget.community.id];
    final hasCheckedIn = myStatus?['has_checkin_today'] as bool? ?? false;
    final streak = myStatus?['consecutive_checkin_days'] as int? ?? 0;
    final userCommunitiesAsync = ref.watch(userCommunitiesProvider);

    return Container(
      color: theme.drawerBackground,
      child: SafeArea(
        child: Row(
          children: [
            // ══════════════════════════════════════════════════════════════
            // SIDEBAR ESQUERDA — Comunidades do usuário (~52px)
            // ══════════════════════════════════════════════════════════════
            _buildLeftSidebar(r, theme, userCommunitiesAsync),

            // ══════════════════════════════════════════════════════════════
            // PAINEL PRINCIPAL
            // ══════════════════════════════════════════════════════════════
            Expanded(
              child: RefreshIndicator(
                color: theme.accentPrimary,
                onRefresh: () async {
                  ref.invalidate(checkInStatusProvider);
                  ref.invalidate(userCommunitiesProvider);
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  child: Column(
                    children: [
                      _buildHeader(r, theme, themeColor, hasCheckedIn, streak),
                      _buildMenuArea(r, theme),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SIDEBAR ESQUERDA
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLeftSidebar(
    Responsive r,
    dynamic theme,
    AsyncValue<List<CommunityModel>> userCommunitiesAsync,
  ) {
    final s = ref.read(stringsProvider);
    return Container(
      width: r.s(52),
      color: theme.drawerSidebarBackground,
      child: Column(
        children: [
          SizedBox(height: r.s(6)),
          // ── Botão Exit ──────────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              final ctrl = AminoDrawerController.of(context);
              if (ctrl != null && ctrl.isOpen) ctrl.close();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/communities');
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: r.s(4)),
              child: Column(
                children: [
                  Icon(
                    Icons.door_front_door_outlined,
                    color: theme.iconSecondary,
                    size: r.s(18),
                  ),
                  SizedBox(height: r.s(1)),
                  Text(
                    s.drawerExit,
                    style: TextStyle(
                      color: theme.textHint,
                      fontSize: r.fs(8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: r.s(6)),
          // ── Lista de comunidades ─────────────────────────────────────────
          Expanded(
            child: userCommunitiesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (communities) => SingleChildScrollView(
                child: Column(
                  children: communities.map((community) {
                    final isCurrent = community.id == widget.community.id;
                    return _buildSidebarCommunityIcon(r, theme, community, isCurrent);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarCommunityIcon(
    Responsive r,
    dynamic theme,
    CommunityModel community,
    bool isCurrent,
  ) {
    final unreadMap = ref.watch(unreadCountByCommunityProvider).valueOrNull ?? {};
    final unreadCount = unreadMap[community.id] ?? 0;
    return GestureDetector(
      onTap: () {
        if (!isCurrent) {
          final ctrl = AminoDrawerController.of(context);
          if (ctrl != null && ctrl.isOpen) ctrl.close();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/community/${community.id}');
            }
          });
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: r.s(4), horizontal: r.s(6)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: r.s(38),
              height: r.s(38),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r.s(10)),
                border: isCurrent
                    ? Border.all(color: theme.accentPrimary, width: 2)
                    : null,
                image: community.iconUrl != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(community.iconUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: theme.overlayColor.withValues(alpha: 0.2),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: r.s(14),
                  height: r.s(14),
                  decoration: BoxDecoration(
                    color: theme.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.drawerSidebarBackground,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(
    Responsive r,
    dynamic theme,
    Color themeColor,
    bool hasCheckedIn,
    int streak,
  ) {
    final s = ref.read(stringsProvider);
    final user = widget.currentUser;

    return Stack(
      children: [
        // ── Fundo (banner ou cor sólida) — preenche toda a altura do Stack ───────
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.85),
              image: widget.community.bannerUrl != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(
                          widget.community.bannerUrl!),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    )
                  : null,
            ),
          ),
        ),

        // ── Gradiente escuro adaptativo ao tema ──────────────────────────────────
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.7, 1.0],
                colors: [
                  theme.drawerHeaderBackground.withValues(alpha: 0.10),
                  theme.drawerHeaderBackground.withValues(alpha: 0.30),
                  theme.drawerHeaderBackground.withValues(alpha: 0.60),
                  theme.drawerHeaderBackground.withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
        ),

        // ── Conteúdo do header ───────────────────────────────────────────
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: r.s(44)),
            SizedBox(height: r.s(6)),
            _buildCommunityBanner(r, theme),
            SizedBox(height: r.s(12)),
            _buildUserAvatar(r, user, themeColor),
            SizedBox(height: r.s(6)),
            // local_nickname sempre preenchido desde o join (migration 093)
            Text(
              (widget.membership?['local_nickname'] as String?)?.trim().isNotEmpty == true
                  ? (widget.membership!['local_nickname'] as String).trim()
                  : s.drawerVisitor,
              style: TextStyle(
                color: const Color(0xFFFFFFFF),
                fontSize: r.fs(20),
                fontWeight: FontWeight.w800,
                shadows: const [
                  Shadow(color: Color(0xCC000000), blurRadius: 8),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: r.s(4)),
            if (user != null)
              GestureDetector(
                onTap: () {
                  final localLevel =
                      widget.membership?['local_level'] as int? ?? 0;
                  final localRep =
                      widget.membership?['local_reputation'] as int? ?? 0;
                  context.push('/all-rankings', extra: {
                    'level': localLevel,
                    'reputation': localRep,
                    'bannerUrl': widget.community.bannerUrl,
                  });
                },
                child: _buildLevelBadge(r, theme, user),
              ),
            SizedBox(height: r.s(8)),
            _buildStreakDots(r, theme, streak, hasCheckedIn),
            SizedBox(height: r.s(4)),
            _buildCheckInMessage(r, theme, hasCheckedIn),
            SizedBox(height: r.s(8)),
          ],
        ),

        // ── Ícone de busca no topo direito ───────────────────────────────
        Positioned(
          top: r.s(6),
          right: r.s(8),
          child: GestureDetector(
            onTap: () => _closeAndNavigate(() {
              context.push('/community/${widget.community.id}/search');
            }),
            child: Container(
              width: r.s(32),
              height: r.s(32),
              decoration: BoxDecoration(
                color: theme.overlayColor.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_rounded,
                color: const Color(0xFFFFFFFF),
                size: r.s(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityBanner(Responsive r, dynamic theme) {
    final drawerBanner = widget.community.bannerForContext('drawer');
    if (widget.community.iconUrl == null && drawerBanner == null) {
      return SizedBox(height: r.s(10));
    }
    return Container(
      height: r.s(55),
      margin: EdgeInsets.fromLTRB(r.s(12), r.s(6), r.s(12), 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r.s(8)),
        color: theme.overlayColor.withValues(alpha: 0.08),
        image: (drawerBanner ?? widget.community.iconUrl) != null
            ? DecorationImage(
                image: CachedNetworkImageProvider(
                    drawerBanner ?? widget.community.iconUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
    );
  }

  Widget _buildUserAvatar(Responsive r, UserModel? user, Color themeColor) {
    final userId = user?.id ?? SupabaseService.currentUserId;
    final equippedData = userId != null
        ? ref.watch(equippedItemsProvider(userId)).valueOrNull
        : null;
    final frameUrl = equippedData?['frame_url'] as String?;
    final frameIsAnimated =
        equippedData?['frame_is_animated'] as bool? ?? false;
    // local_icon_url sempre preenchido desde o join (migration 093)
    final localIconUrl = (widget.membership?['local_icon_url'] as String?)?.trim();
    final effectiveAvatarUrl = (localIconUrl != null && localIconUrl.isNotEmpty)
        ? localIconUrl
        : null;
    return AvatarWithFrame(
      avatarUrl: effectiveAvatarUrl,
      frameUrl: frameUrl,
      size: r.s(72),
      showAminoPlus: user?.isPremium ?? false,
      isFrameAnimated: frameIsAnimated,
      onTap: userId != null
          ? () => _closeAndNavigate(() {
                context.push(
                  '/community/${widget.community.id}/profile/$userId',
                );
              })
          : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BADGE DE NÍVEL + BARRA DE REPUTAÇÃO
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLevelBadge(Responsive r, dynamic theme, UserModel user) {
    final level = widget.membership?['local_level'] as int? ?? 0;
    return LevelBadge(
      level: level,
      size: LevelBadgeSize.medium,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAK DOTS (7 dias)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStreakDots(
      Responsive r, dynamic theme, int streak, bool hasCheckedIn) {
    const totalDots = 7;
    final doneDots = (streak % 7).clamp(0, totalDots);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalDots, (i) {
          final done = i < doneDots;
          final isNext = i == doneDots && !hasCheckedIn;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(2)),
            child: Column(
              children: [
                Container(
                  width: r.s(22),
                  height: r.s(22),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? theme.success
                        : isNext
                            ? theme.success.withValues(alpha: 0.20)
                            : const Color(0xFFFFFFFF).withValues(alpha: 0.08),
                    border: isNext
                        ? Border.all(
                            color: theme.success.withValues(alpha: 0.60),
                            width: 1.5,
                          )
                        : done
                            ? null
                            : Border.all(
                                color: const Color(0xFFFFFFFF)
                                    .withValues(alpha: 0.12),
                                width: 1,
                              ),
                    boxShadow: done
                        ? [
                            BoxShadow(
                              color: theme.success.withValues(alpha: 0.30),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: done
                      ? Icon(Icons.check_rounded,
                          color: const Color(0xFFFFFFFF), size: r.s(12))
                      : null,
                ),
                SizedBox(height: r.s(2)),
                Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: done
                        ? theme.success
                        : const Color(0xFFFFFFFF).withValues(alpha: 0.30),
                    fontSize: r.fs(7),
                    fontWeight: done ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTÃO DE CHECK-IN
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCheckInMessage(Responsive r, dynamic theme, bool hasCheckedIn) {
    final s = ref.read(stringsProvider);
    if (hasCheckedIn) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _isCheckingIn ? null : _doCheckIn,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: r.s(24)),
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.success,
              theme.success.withValues(alpha: 0.80),
            ],
          ),
          borderRadius: BorderRadius.circular(r.s(20)),
          boxShadow: [
            BoxShadow(
              color: theme.success.withValues(alpha: 0.30),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isCheckingIn)
              SizedBox(
                width: r.s(14),
                height: r.s(14),
                child: CircularProgressIndicator(
                  color: theme.buttonPrimaryForeground,
                  strokeWidth: 2,
                ),
              )
            else ...[
              Icon(Icons.local_fire_department_rounded,
                  color: theme.buttonPrimaryForeground, size: r.s(14)),
              SizedBox(width: r.s(4)),
              Text(
                s.doCheckIn2,
                style: TextStyle(
                  color: theme.buttonPrimaryForeground,
                  fontSize: r.fs(11),
                  fontWeight: FontWeight.w700,
                  shadows: const [
                    Shadow(color: Color(0x40000000), blurRadius: 2),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ÁREA DO MENU — estrutura reorganizada
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMenuArea(Responsive r, dynamic theme) {
    return Container(
      color: theme.drawerBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: r.s(2)),
          // ── 1. Itens principais ──────────────────────────────────────────
          _buildMainMenu(r, theme),
          // ── 2. Botão "Ver mais" + seção expansível ───────────────────────
          _buildSeeMoreSection(r, theme),
          // ── 3. Separador + itens pessoais do usuário ─────────────────────
          _buildUserSection(r, theme),
          // ── 4. Seção de gerenciamento (só staff) ─────────────────────────
          if (_isStaff) _buildStaffSection(r, theme),
          SizedBox(height: r.s(40)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. MENU PRINCIPAL — itens sempre visíveis
  //    Home · Meus Chats · Ranking · Membros · Wiki · Stories
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMainMenu(Responsive r, dynamic theme) {
    final s = ref.read(stringsProvider);
    return Column(
      children: [
        // Home
        _AminoDrawerTile(
          icon: Icons.home_rounded,
          iconColor: theme.accentPrimary,
          label: s.home2,
          onTap: () => _closeAndNavigate(() {}),
        ),
        // Meus Chats
        _AminoDrawerTile(
          icon: Icons.chat_bubble_rounded,
          iconColor: theme.success,
          label: s.drawerMyChats,
          badgeCount: ref.watch(unreadCountProvider).valueOrNull,
          onTap: () => _closeAndNavigate(() {
            context.push(
              '/community/${widget.community.id}/my-chats',
              extra: {'communityName': widget.community.name},
            );
          }),
        ),
        // Ranking
        _AminoDrawerTile(
          icon: Icons.leaderboard_rounded,
          iconColor: theme.accentSecondary,
          label: s.drawerLeaderboards,
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/leaderboard');
          }),
        ),
        // Membros
        _AminoDrawerTile(
          icon: Icons.group_rounded,
          iconColor: theme.accentPrimary,
          label: s.drawerMembers,
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/members');
          }),
        ),
        // Wiki
        _AminoDrawerTile(
          icon: Icons.auto_stories_rounded,
          iconColor: theme.accentSecondary,
          label: s.wiki,
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/wiki');
          }),
        ),
        // Stories
        _AminoDrawerTile(
          icon: Icons.amp_stories_rounded,
          iconColor: theme.accentSecondary,
          label: s.stories,
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/stories');
          }),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. "VER MAIS" — botão que expande inline com AnimatedSize
  //    Shared Folder · Salas Públicas · Roles RPG · Meu Título
  //    Posts Salvos · Informações da Comunidade
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSeeMoreSection(Responsive r, dynamic theme) {
    final s = ref.read(stringsProvider);
    return Column(
      children: [
        // ── Divider sutil ────────────────────────────────────────────────
        Container(
          margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(4)),
          height: 0.5,
          color: theme.divider,
        ),
        // ── Botão "Ver mais / Ver menos" ─────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _seeMoreExpanded = !_seeMoreExpanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: r.s(16),
              vertical: r.s(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _seeMoreExpanded ? s.less : s.more,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _seeMoreExpanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: theme.iconSecondary,
                    size: r.s(22),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Seção expansível com AnimatedSize ────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _seeMoreExpanded
              ? Column(
                  children: [
                    // Shared Folder
                    _AminoDrawerTile(
                      icon: Icons.folder_shared_rounded,
                      iconColor: theme.accentPrimary,
                      label: s.sharedFolder,
                      onTap: () => _closeAndNavigate(() {
                        context.push(
                            '/community/${widget.community.id}/shared-folder');
                      }),
                    ),
                    // Salas Públicas
                    _AminoDrawerTile(
                      icon: Icons.forum_rounded,
                      iconColor: theme.success,
                      label: s.drawerPublicChatrooms,
                      onTap: () => _closeAndNavigate(() {
                        context.push(
                          '/community/${widget.community.id}/public-chats',
                          extra: {
                            'communityId': widget.community.id,
                            'communityName': widget.community.name,
                          },
                        );
                      }),
                    ),
                    // Roles RPG — só quando modo RPG ativo
                    if (widget.community.rpgModeEnabled)
                      _AminoDrawerTile(
                        icon: Icons.shield_rounded,
                        iconColor: theme.accentPrimary,
                        label: 'Roles RPG',
                        onTap: () => _closeAndNavigate(() {
                          context.push(
                              '/community/${widget.community.id}/rpg-roles');
                        }),
                      ),
                    // Meu Título: removido do drawer — já disponível na edição de perfil da comunidade
                    // Posts Salvos — abre diretamente na aba Saved Posts (index 2)
                    _AminoDrawerTile(
                      icon: Icons.bookmark_rounded,
                      iconColor: theme.error,
                      label: s.savedPosts,
                      onTap: () => _closeAndNavigate(() {
                        context.push(
                          '/community/${widget.community.id}/my-profile',
                          extra: {'initialTab': 2},
                        );
                      }),
                    ),
                    // Informações da Comunidade
                    _AminoDrawerTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: theme.textSecondary,
                      label: s.communityInfo,
                      onTap: () => _closeAndNavigate(() {
                        context.push(
                          '/community/${widget.community.id}/info',
                          extra: {'readOnly': true},
                        );
                      }),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. SEÇÃO PESSOAL — Notificações · Configurações
  //    Sempre visível, separada por divider
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildUserSection(Responsive r, dynamic theme) {
    final s = ref.read(stringsProvider);
    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(4)),
          height: 0.5,
          color: theme.divider,
        ),
        // Notificações
        Consumer(builder: (ctx, cref, _) {
          final communityUnread = cref.watch(
            unreadCommunityNotificationCountProvider(widget.community.id),
          );
          return _AminoDrawerTile(
            icon: communityUnread > 0
                ? Icons.notifications_rounded
                : Icons.notifications_outlined,
            iconColor:
                communityUnread > 0 ? theme.error : theme.textSecondary,
            label: s.notifications,
            onTap: () => _closeAndNavigate(() {
              context.push('/settings/notifications');
            }),
            badgeCount: communityUnread,
          );
        }),
        // Configurações
        _AminoDrawerTile(
          icon: Icons.manage_accounts_rounded,
          iconColor: theme.textSecondary,
          label: s.settings,
          onTap: () => _closeAndNavigate(() {
            context.push('/settings');
          }),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. STAFF / GERENCIAMENTO — só para staff
  //    Editar Comunidade · Transferir Liderança · Central de Denúncias
  //    Estatísticas · Usuários Bloqueados
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStaffSection(Responsive r, dynamic theme) {
    final s = ref.read(stringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: r.s(16)),
          height: 0.5,
          color: theme.divider,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(r.s(20), r.s(14), r.s(20), r.s(4)),
          child: Text(
            s.management,
            style: TextStyle(
              color: theme.textHint,
              fontSize: r.fs(10),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        // Editar Comunidade (leader)
        if (_isLeader)
          _AminoDrawerTile(
            icon: Icons.settings_rounded,
            iconColor: theme.iconSecondary,
            label: s.drawerEditCommunity,
            onTap: () => _closeAndNavigate(() {
              context.push('/community/${widget.community.id}/acm');
            }),
          ),
        // Transferir Liderança (leader)
        if (_isLeader)
          _AminoDrawerTile(
            icon: Icons.swap_horiz_rounded,
            iconColor: theme.warning,
            label: s.transferLeadership,
            onTap: () => _closeAndNavigate(() {
              _showTransferOwnershipDialog(context);
            }),
          ),
        // Central de Denúncias (staff, com badge)
        if (_isStaff)
          Consumer(builder: (ctx, cref, _) {
            final pendingFlags = cref.watch(
              _pendingFlagsCountProvider(widget.community.id),
            );
            final count = pendingFlags.valueOrNull ?? 0;
            return _AminoDrawerTile(
              icon: Icons.flag_rounded,
              iconColor:
                  count > 0 ? theme.error : theme.error.withValues(alpha: 0.70),
              label: s.drawerFlagCenter,
              onTap: () => _closeAndNavigate(() {
                context.push('/community/${widget.community.id}/flags');
              }),
              badgeCount: count > 0 ? count : null,
            );
          }),
        // Logs de Moderação (apenas líder e acima)
        if (_isLeader)
          _AminoDrawerTile(
            icon: Icons.history_rounded,
            iconColor: theme.textSecondary,
            label: s.managementLogsTitle,
            onTap: () => _closeAndNavigate(() {
              context.push('/community/${widget.community.id}/management-logs');
            }),
          ),
        // Estatísticas (staff)
        _AminoDrawerTile(
          icon: Icons.analytics_rounded,
          iconColor: theme.accentPrimary,
          label: s.drawerStatistics,
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/acm');
          }),
        ),
        // Usuários Bloqueados (leader)
        if (_isLeader)
          _AminoDrawerTile(
            icon: Icons.block_rounded,
            iconColor: theme.textSecondary,
            label: s.blockedUsers,
            onTap: () => _closeAndNavigate(() {
              context.push('/settings/blocked-users');
            }),
          ),
        // Gerenciar Equipe (apenas Team Admin+)
        if (widget.currentUser?.canManageTeamRoles ?? false)
          _AminoDrawerTile(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFFFFD700),
            label: 'Gerenciar Equipe',
            onTap: () => _closeAndNavigate(() {
              context.push('/staff-management');
            }),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TRANSFER OWNERSHIP DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  void _showTransferOwnershipDialog(BuildContext context) async {
    final r = context.r;
    final theme = context.nexusTheme;

    // Carregar membros da comunidade (exceto o líder atual)
    final currentUserId = SupabaseService.currentUserId;
    List<Map<String, dynamic>> members = [];
    String? selectedUserId;
    String? selectedUserName;

    try {
      final res = await SupabaseService.table('community_members')
          .select('user_id, role, profiles(id, display_name, username, avatar_url)')
          .eq('community_id', widget.community.id)
          .eq('status', 'active')
          .neq('user_id', currentUserId ?? '');
      members = (res as List).cast<Map<String, dynamic>>();
    } catch (_) {}

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.surfaceColor,
          title: Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: theme.warning, size: r.s(22)),
              SizedBox(width: r.s(8)),
              Text('Transferir Liderança',
                  style: TextStyle(
                      color: theme.textPrimary, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selecione um membro para se tornar o novo líder. Você será rebaixado para Co-Líder.',
                  style: TextStyle(
                      color: theme.warning.withValues(alpha: 0.9),
                      fontSize: r.fs(12)),
                ),
                SizedBox(height: r.s(12)),
                if (members.isEmpty)
                  Text('Nenhum membro disponível.',
                      style: TextStyle(color: theme.textSecondary))
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: r.s(240)),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: members.length,
                      itemBuilder: (_, i) {
                        final profile = members[i]['profiles'] as Map<String, dynamic>?;
                        final uid = profile?['id'] as String? ?? '';
                        final name = profile?['display_name'] as String? ??
                            profile?['username'] as String? ?? 'Usuário';
                        final avatar = profile?['avatar_url'] as String?;
                        final role = members[i]['role'] as String? ?? 'member';
                        final isSelected = selectedUserId == uid;
                        return ListTile(
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: r.s(4), vertical: 0),
                          leading: CircleAvatar(
                            radius: r.s(18),
                            backgroundImage: avatar != null
                                ? CachedNetworkImageProvider(avatar)
                                : null,
                            backgroundColor: theme.accentPrimary.withValues(alpha: 0.3),
                            child: avatar == null
                                ? Text(name[0].toUpperCase(),
                                    style: TextStyle(
                                        color: theme.textPrimary,
                                        fontSize: r.fs(14)))
                                : null,
                          ),
                          title: Text(name,
                              style: TextStyle(
                                  color: theme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: r.fs(14))),
                          subtitle: Text(role,
                              style: TextStyle(
                                  color: theme.textSecondary, fontSize: r.fs(11))),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded,
                                  color: theme.accentPrimary, size: r.s(20))
                              : null,
                          selected: isSelected,
                          selectedTileColor:
                              theme.accentPrimary.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(r.s(8))),
                          onTap: () => setDialogState(() {
                            selectedUserId = uid;
                            selectedUserName = name;
                          }),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.swap_horiz_rounded, size: r.s(16)),
              label: const Text('Transferir'),
              onPressed: selectedUserId == null
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (_) => AlertDialog(
                          backgroundColor: theme.surfaceColor,
                          title: Text('Confirmar Transferência',
                              style: TextStyle(color: theme.textPrimary)),
                          content: Text(
                            'Tem certeza que deseja transferir a liderança de "${widget.community.name}" para $selectedUserName? Esta ação não pode ser desfeita facilmente.',
                            style: TextStyle(color: theme.textSecondary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.warning,
                                  foregroundColor: Colors.black),
                              child: const Text('Confirmar'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      try {
                        await SupabaseService.rpc(
                          'transfer_community_ownership',
                          params: {
                            'p_community_id': widget.community.id,
                            'p_new_leader_id': selectedUserId,
                          },
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '✅ Liderança transferida para $selectedUserName.'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: theme.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro: ${e.toString()}'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: theme.error,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.warning,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _AminoDrawerTile — Item de menu estilo Amino — totalmente tematizado
// =============================================================================

class _AminoDrawerTile extends ConsumerWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final int? badgeCount;

  const _AminoDrawerTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: r.s(14),
          vertical: r.s(9),
        ),
        child: Row(
          children: [
            // Ícone circular colorido (42px)
            Container(
              width: r.s(42),
              height: r.s(42),
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: theme.buttonPrimaryForeground,
                size: r.s(20),
              ),
            ),
            SizedBox(width: r.s(14)),
            // Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: r.fs(16),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Badge de notificação — NexusBadge moderno com 9+
            if (badgeCount != null && badgeCount! > 0)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.s(7),
                  vertical: r.s(3),
                ),
                decoration: BoxDecoration(
                  color: theme.error,
                  borderRadius: BorderRadius.circular(r.s(10)),
                  boxShadow: [
                    BoxShadow(
                      color: theme.error.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  badgeCount! > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
