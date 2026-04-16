import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/providers/chat_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// =============================================================================
// COMMUNITY DRAWER — Réplica fiel do painel lateral do Amino Apps
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
        HapticFeedback.mediumImpact();
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
              context.pushReplacement('/community/${community.id}');
            }
          });
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: r.s(4)),
        padding: EdgeInsets.symmetric(horizontal: r.s(4)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: r.s(42),
              height: r.s(42),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r.s(12)),
                color: theme.surfaceSecondary,
                image: community.iconUrl != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(community.iconUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                border: isCurrent
                    ? Border.all(
                        color: theme.accentPrimary,
                        width: 2,
                      )
                    : Border.all(
                        color: theme.borderSubtle,
                        width: 1,
                      ),
              ),
              child: community.iconUrl == null
                  ? Center(
                      child: Text(
                        community.name.isNotEmpty
                            ? community.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: r.fs(16),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
            ),
            // Badge de não lidas
            if (unreadCount > 0)
              Positioned(
                top: -r.s(3),
                right: -r.s(3),
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: r.s(16),
                    minHeight: r.s(16),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: r.s(4),
                    vertical: r.s(1),
                  ),
                  decoration: BoxDecoration(
                    color: theme.error,
                    borderRadius: BorderRadius.circular(r.s(10)),
                    border: Border.all(
                      color: theme.drawerSidebarBackground,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: TextStyle(
                      color: theme.buttonDestructiveForeground,
                      fontSize: r.fs(9),
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER — Fundo com imagem da comunidade
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
        // ── Fundo: imagem da comunidade ──────────────────────────────────
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.9),
              image: widget.community.bannerForContext('drawer') != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(
                          widget.community.bannerForContext('drawer')!),
                      fit: BoxFit.cover,
                    )
                  : widget.community.iconUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(
                              widget.community.iconUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
            ),
          ),
        ),

        // ── Gradiente escuro adaptativo ao tema ──────────────────────────
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
    final s = ref.read(stringsProvider);
    final level = widget.membership?['local_level'] as int? ?? 0;
    final reputation = widget.membership?['local_reputation'] as int? ?? 0;
    final levelColor = AppTheme.getLevelColor(level);
    final levelName = levelTitleFromStrings(s, level);
    final repProgress = levelProgress(reputation);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(30)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Círculo com "Lv" + número
          Container(
            width: r.s(36),
            height: r.s(36),
            decoration: BoxDecoration(
              color: levelColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFFFFFF).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: s.drawerLvLabel,
                      style: TextStyle(
                        color: const Color(0xFFFFFFFF),
                        fontSize: r.fs(9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: '$level',
                      style: TextStyle(
                        color: const Color(0xFFFFFFFF),
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: r.s(4)),
          // Pill com nome do nível + barra de progresso
          Flexible(
            child: Container(
              height: r.s(28),
              decoration: BoxDecoration(
                color: theme.overlayColor.withValues(alpha: 0.50),
                borderRadius: BorderRadius.circular(r.s(14)),
              ),
              padding: EdgeInsets.symmetric(horizontal: r.s(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    flex: 0,
                    child: Text(
                      levelName,
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(width: r.s(6)),
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: repProgress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: levelColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
  // ÁREA DO MENU
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMenuArea(Responsive r, dynamic theme) {
    return Container(
      color: theme.drawerBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: r.s(2)),
          _buildMainMenu(r, theme),
          _buildSeeMore(r, theme),
          if (_isStaff) _buildStaffSection(r, theme),
          SizedBox(height: r.s(40)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MENU PRINCIPAL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMainMenu(Responsive r, dynamic theme) {
    final s = ref.read(stringsProvider);
    return Column(
      children: [
        _AminoDrawerTile(
          icon: Icons.home_rounded,
          iconColor: theme.accentPrimary,
          label: s.home2,
          onTap: () => _closeAndNavigate(() {}),
        ),
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
        _AminoDrawerTile(
          icon: Icons.forum_rounded,
          iconColor: theme.success,
          label: s.drawerPublicChatrooms,
          onTap: () => _closeAndNavigate(() {
            context.push('/create-public-chat', extra: {
              'communityId': widget.community.id,
              'communityName': widget.community.name,
            });
          }),
        ),
        _AminoDrawerTile(
          icon: Icons.leaderboard_rounded,
          iconColor: theme.accentSecondary,
          label: s.drawerLeaderboards,
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/leaderboard');
          }),
        ),
        _AminoDrawerTile(
          icon: Icons.auto_stories_rounded,
          iconColor: theme.accentSecondary,
          label: s.wiki,
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/wiki');
          }),
        ),
        _AminoDrawerTile(
          icon: Icons.folder_shared_rounded,
          iconColor: theme.accentPrimary,
          label: 'Shared Folder',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/shared-folder');
          }),
        ),
        _AminoDrawerTile(
          icon: Icons.amp_stories_rounded,
          iconColor: theme.accentSecondary,
          label: s.stories,
          onTap: () => _closeAndNavigate(() {
            // Navega para o perfil do usuário DENTRO da comunidade
            context.push('/community/${widget.community.id}/my-profile');
          }),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEE MORE...
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSeeMore(Responsive r, dynamic theme) {
    final s = ref.read(stringsProvider);
    return Column(
      children: [
        GestureDetector(
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/info');
          }),
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
                    'See More...',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: theme.iconSecondary, size: r.s(22)),
              ],
            ),
          ),
        ),
        // Divider sutil
        Container(
          margin: EdgeInsets.symmetric(horizontal: r.s(16)),
          height: 0.5,
          color: theme.divider,
        ),
        SizedBox(height: r.s(4)),
        _AminoDrawerTile(
          icon: Icons.group_rounded,
          iconColor: theme.accentPrimary,
          label: s.drawerMembers,
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/members');
          }),
        ),
        _AminoDrawerTile(
          icon: Icons.bookmark_rounded,
          iconColor: theme.error,
          label: 'Saved Posts',
          onTap: () => _closeAndNavigate(() {
            // Navega para o perfil do usuário DENTRO da comunidade (aba Saved Posts)
            context.push('/community/${widget.community.id}/my-profile');
          }),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STAFF / GERENCIAMENTO
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
            'MANAGEMENT',
            style: TextStyle(
              color: theme.textHint,
              fontSize: r.fs(10),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (_isLeader)
          _AminoDrawerTile(
            icon: Icons.settings_rounded,
            iconColor: theme.iconSecondary,
            label: s.drawerEditCommunity,
            onTap: () => _closeAndNavigate(() {
              context.push('/community/${widget.community.id}/acm');
            }),
          ),
        _AminoDrawerTile(
          icon: Icons.flag_rounded,
          iconColor: theme.error,
          label: s.drawerFlagCenter,
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/flags');
          }),
        ),
        _AminoDrawerTile(
          icon: Icons.analytics_rounded,
          iconColor: theme.accentPrimary,
          label: s.drawerStatistics,
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/acm');
          }),
        ),
      ],
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
            // Badge de notificação
            if (badgeCount != null && badgeCount! > 0)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.s(6),
                  vertical: r.s(2),
                ),
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(r.s(10)),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: theme.buttonPrimaryForeground,
                    fontSize: r.fs(11),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
