import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/amino_animations.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/providers/presence_provider.dart';
import '../../../core/providers/dm_invite_provider.dart';
import '../providers/community_detail_providers.dart';
import '../../../core/l10n/locale_provider.dart';

// =============================================================================
// COMMUNITY ONLINE TAB — Estilo Amino Apps
//
// Seções:
//   1. ⚡ What's happening now  — posts em destaque ativos (carrossel)
//   2. 🟢 Members online        — avatares dos membros online
//   3. 👁 Browsing              — card com contagem + stack de avatares
//   4. 👥 All Members           — Leaders → Recently Joined
// =============================================================================
class CommunityOnlineTab extends ConsumerStatefulWidget {
  final CommunityModel community;
  const CommunityOnlineTab({super.key, required this.community});

  @override
  ConsumerState<CommunityOnlineTab> createState() => _CommunityOnlineTabState();
}

class _CommunityOnlineTabState extends ConsumerState<CommunityOnlineTab> {
  bool _happeningExpanded = true;

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final communityId = widget.community.id;

    final presenceAsync = ref.watch(communityPresenceProvider(communityId));
    final onlineUserIds = presenceAsync.valueOrNull ?? {};

    final membersAsync = ref.watch(communityMembersProvider(communityId));
    final featuredAsync = ref.watch(activeFeaturedFeedProvider(communityId));

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        ref.invalidate(communityPresenceProvider(communityId));
        ref.invalidate(communityMembersProvider(communityId));
        ref.invalidate(activeFeaturedFeedProvider(communityId));
      },
      child: CustomScrollView(
        slivers: [
          // ── 1. What's happening now ────────────────────────────────────
          SliverToBoxAdapter(
            child: _HappeningSection(
              communityId: communityId,
              featuredAsync: featuredAsync,
              expanded: _happeningExpanded,
              onToggle: () =>
                  setState(() => _happeningExpanded = !_happeningExpanded),
            ),
          ),

          // ── 2. Members Online ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: membersAsync.when(
              data: (members) => _MembersOnlineSection(
                communityId: communityId,
                members: members,
                onlineUserIds: onlineUserIds,
              ),
              loading: () => _sectionShimmer(r),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // ── 3. Browsing ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: membersAsync.when(
              data: (members) => _BrowsingSection(
                communityId: communityId,
                members: members,
                onlineUserIds: onlineUserIds,
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // ── 4. All Members ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: membersAsync.when(
              data: (members) => _AllMembersSection(
                community: widget.community,
                members: members,
                onlineUserIds: onlineUserIds,
              ),
              loading: () => _sectionShimmer(r),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: r.s(100))),
        ],
      ),
    );
  }

  Widget _sectionShimmer(Responsive r) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
      height: r.s(80),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(r.s(12)),
      ),
    );
  }
}

// =============================================================================
// SEÇÃO 1 — What's happening now (posts em destaque)
// =============================================================================
class _HappeningSection extends ConsumerWidget {
  final String communityId;
  final AsyncValue<List<PostModel>> featuredAsync;
  final bool expanded;
  final VoidCallback onToggle;

  const _HappeningSection({
    required this.communityId,
    required this.featuredAsync,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;

    return Container(
      margin: EdgeInsets.only(
          left: r.s(12), right: r.s(12), top: r.s(12), bottom: r.s(4)),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(r.s(14)),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.07), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header clicável
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(r.s(14)),
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(12)),
              child: Row(
                children: [
                  Icon(Icons.flash_on_rounded,
                      color: const Color(0xFFFFD700), size: r.s(18)),
                  SizedBox(width: r.s(6)),
                  Text(
                    'What\'s happening now!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(14),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: r.s(20)),
                  ),
                ],
              ),
            ),
          ),

          // Conteúdo expansível
          AnimatedCrossFade(
            firstChild: featuredAsync.when(
              data: (posts) {
                final postList = posts;
                if (postList.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.only(
                        left: r.s(14), right: r.s(14), bottom: r.s(14)),
                    child: Text(
                      'Nenhum destaque ativo no momento.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: r.fs(12)),
                    ),
                  );
                }
                return SizedBox(
                  height: r.s(90),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.only(
                        left: r.s(10), right: r.s(10), bottom: r.s(12)),
                    itemCount: postList.length,
                    itemBuilder: (context, i) {
                      final post = postList[i];
                      final title = post.title ?? '';
                      final cover = post.coverImageUrl;
                      final postId = post.id;
                      return AminoAnimations.cardPress(
                        onTap: () {
                          context.push('/post/$postId');
                        },
                        child: Container(
                          width: r.s(220),
                          margin: EdgeInsets.only(right: r.s(8)),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(r.s(10)),
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.15),
                            border: Border.all(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.3),
                                width: 0.5),
                          ),
                          child: Row(
                            children: [
                              if (cover != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(r.s(10)),
                                    bottomLeft: Radius.circular(r.s(10)),
                                  ),
                                  child: Image.network(
                                    cover,
                                    width: r.s(70),
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        SizedBox(width: r.s(70)),
                                  ),
                                ),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.all(r.s(8)),
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: r.fs(12),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => SizedBox(
                height: r.s(50),
                child: Center(
                  child: SizedBox(
                    width: r.s(20),
                    height: r.s(20),
                    child: const CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryColor),
                  ),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState:
                expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SEÇÃO 2 — Members Online (avatares com indicador verde)
// =============================================================================
class _MembersOnlineSection extends ConsumerWidget {
  final String communityId;
  final List<Map<String, dynamic>> members;
  final Set<String> onlineUserIds;

  const _MembersOnlineSection({
    required this.communityId,
    required this.members,
    required this.onlineUserIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;

    final onlineMembers = members.where((m) {
      final userId =
          (m['profiles'] as Map?)?['id'] as String? ?? m['user_id'] as String?;
      return userId != null && onlineUserIds.contains(userId);
    }).toList();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(4)),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(r.s(14)),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.07), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(12)),
            child: Row(
              children: [
                Container(
                  width: r.s(10),
                  height: r.s(10),
                  decoration: const BoxDecoration(
                    color: AppTheme.onlineColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: r.s(6)),
                Text(
                  'Members online (${onlineMembers.length})',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(14),
                  ),
                ),
              ],
            ),
          ),

          if (onlineMembers.isEmpty)
            Padding(
              padding: EdgeInsets.only(
                  left: r.s(14), right: r.s(14), bottom: r.s(14)),
              child: Text(
                'Nenhum membro online agora.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: r.fs(12)),
              ),
            )
          else
            SizedBox(
              height: r.s(90),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(
                    left: r.s(12), right: r.s(12), bottom: r.s(12)),
                itemCount: onlineMembers.length,
                itemBuilder: (context, i) {
                  final m = onlineMembers[i];
                  final p = m['profiles'] as Map<String, dynamic>? ?? {};
                  final nickname = p['nickname'] as String? ?? s.user;
                  final avatarUrl = p['icon_url'] as String?;
                  final userId = p['id'] as String? ?? m['user_id'] as String?;

                  return AminoAnimations.cardPress(
                    onTap: () => _showMemberSheet(
                        context, communityId, m, onlineUserIds),
                    child: Container(
                      width: r.s(64),
                      margin: EdgeInsets.only(right: r.s(8)),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: r.s(24),
                                backgroundColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.2),
                                backgroundImage: avatarUrl != null
                                    ? CachedNetworkImageProvider(avatarUrl)
                                    : null,
                                child: avatarUrl == null
                                    ? Text(
                                        nickname[0].toUpperCase(),
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: r.fs(16),
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: r.s(14),
                                  height: r.s(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.onlineColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFF0D0D1A),
                                        width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: r.s(4)),
                          Text(
                            nickname.length > 8
                                ? '${nickname.substring(0, 7)}…'
                                : nickname,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: r.fs(10),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// SEÇÃO 3 — Browsing (navegando agora)
// =============================================================================
class _BrowsingSection extends ConsumerWidget {
  final String communityId;
  final List<Map<String, dynamic>> members;
  final Set<String> onlineUserIds;

  const _BrowsingSection({
    required this.communityId,
    required this.members,
    required this.onlineUserIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;

    final onlineMembers = members.where((m) {
      final userId =
          (m['profiles'] as Map?)?['id'] as String? ?? m['user_id'] as String?;
      return userId != null && onlineUserIds.contains(userId);
    }).toList();

    final count = onlineMembers.length;
    final avatars = onlineMembers
        .take(3)
        .map((m) => (m['profiles'] as Map?)?['icon_url'] as String?)
        .toList();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(4)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.25),
            const Color(0xFF1A1A2E).withValues(alpha: 0.6),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(r.s(14)),
        border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(14)),
        child: Row(
          children: [
            // Contagem
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: r.fs(28),
                    height: 1.0,
                  ),
                ),
                Text(
                  count == 1 ? 'Member' : 'Members',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(width: r.s(16)),

            // Ícone olho + label
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.remove_red_eye_rounded,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: r.s(16)),
                  SizedBox(width: r.s(4)),
                  Text(
                    'Browsing',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(14),
                    ),
                  ),
                ],
              ),
            ),

            // Stack de avatares
            if (count > 0) _AvatarStack(avatars: avatars, size: r.s(32)),

            // Seta
            SizedBox(width: r.s(8)),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.5), size: r.s(20)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SEÇÃO 4 — All Members (Leaders + Recently Joined)
// =============================================================================
class _AllMembersSection extends ConsumerWidget {
  final CommunityModel community;
  final List<Map<String, dynamic>> members;
  final Set<String> onlineUserIds;

  const _AllMembersSection({
    required this.community,
    required this.members,
    required this.onlineUserIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final communityId = community.id;

    final leaders = members
        .where((m) => m['role'] == 'leader' || m['role'] == 'curator')
        .toList();
    final regular = members
        .where((m) => m['role'] != 'leader' && m['role'] != 'curator')
        .toList();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(4)),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(r.s(14)),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.07), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(12)),
            child: Row(
              children: [
                Icon(Icons.people_rounded,
                    color: Colors.white.withValues(alpha: 0.7), size: r.s(16)),
                SizedBox(width: r.s(6)),
                Text(
                  'All Members (${members.length})',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(14),
                  ),
                ),
              ],
            ),
          ),

          // Leaders
          if (leaders.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(left: r.s(14), bottom: r.s(8)),
              child: Text(
                'Leaders',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: r.fs(11),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...leaders.map((m) => _MemberRow(
                  communityId: communityId,
                  member: m,
                  onlineUserIds: onlineUserIds,
                )),
            SizedBox(height: r.s(8)),
          ],

          // Recently Joined
          if (regular.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(left: r.s(14), bottom: r.s(8)),
              child: Text(
                'Recently Joined',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: r.fs(11),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...regular.take(20).map((m) => _MemberRow(
                  communityId: communityId,
                  member: m,
                  onlineUserIds: onlineUserIds,
                )),
          ],

          SizedBox(height: r.s(8)),
        ],
      ),
    );
  }
}

// =============================================================================
// ROW de membro individual
// =============================================================================
class _MemberRow extends ConsumerWidget {
  final String communityId;
  final Map<String, dynamic> member;
  final Set<String> onlineUserIds;

  const _MemberRow({
    required this.communityId,
    required this.member,
    required this.onlineUserIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final p = member['profiles'] as Map<String, dynamic>? ?? {};
    final nickname = p['nickname'] as String? ?? s.user;
    final avatarUrl = p['icon_url'] as String?;
    final userId = p['id'] as String? ?? member['user_id'] as String?;
    final role = member['role'] as String? ?? 'member';
    final reputation = member['local_reputation'] as int? ?? 0;
    final level = member['local_level'] as int? ?? calculateLevel(reputation);
    final isOnline = userId != null && onlineUserIds.contains(userId);

    return AminoAnimations.cardPress(
      onTap: () =>
          _showMemberSheet(context, communityId, member, onlineUserIds),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(8)),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: r.s(22),
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  backgroundImage: avatarUrl != null
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Text(
                          nickname[0].toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: r.fs(14),
                          ),
                        )
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: r.s(12),
                      height: r.s(12),
                      decoration: BoxDecoration(
                        color: AppTheme.onlineColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF0D0D1A), width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: r.s(12)),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          nickname,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: r.fs(13),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (role == 'leader' || role == 'curator') ...[
                        SizedBox(width: r.s(4)),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(5), vertical: r.s(1)),
                          decoration: BoxDecoration(
                            color: role == 'leader'
                                ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                                : AppTheme.primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(r.s(4)),
                          ),
                          child: Text(
                            role == 'leader' ? 'L' : 'C',
                            style: TextStyle(
                              color: role == 'leader'
                                  ? const Color(0xFFFFD700)
                                  : AppTheme.primaryColor,
                              fontSize: r.fs(9),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: r.s(2)),
                  Text(
                    s.levelLabel,
                    style: TextStyle(
                      color: AppTheme.getLevelColor(level),
                      fontSize: r.fs(11),
                    ),
                  ),
                ],
              ),
            ),

            // Botão Follow
            _FollowButton(
              communityId: communityId,
              targetUserId: userId ?? '',
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// BOTÃO FOLLOW
// =============================================================================
class _FollowButton extends ConsumerStatefulWidget {
  final String communityId;
  final String targetUserId;

  const _FollowButton({
    required this.communityId,
    required this.targetUserId,
  });

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool _following = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkFollowing();
  }

  Future<void> _checkFollowing() async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null || currentUserId == widget.targetUserId) return;
    try {
      final res = await SupabaseService.table('follows')
          .select('id')
          .eq('follower_id', currentUserId)
          .eq('following_id', widget.targetUserId)
          .maybeSingle();
      if (mounted) setState(() => _following = res != null);
    } catch (e) {
      debugPrint('[community_online_tab.dart] $e');
    }
  }

  Future<void> _toggle() async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null || _loading) return;
    setState(() => _loading = true);
    try {
      // RPC atômica: toggle follow + reputação + contadores
      final result = await SupabaseService.rpc(
        'toggle_follow_with_reputation',
        params: {
          'p_community_id': widget.communityId,
          'p_follower_id': currentUserId,
          'p_following_id': widget.targetUserId,
        },
      );
      if (mounted) {
        final isNowFollowing =
            result is Map ? (result['following'] == true) : !_following;
        setState(() => _following = isNowFollowing);
      }
    } catch (e) {
      debugPrint('[community_online_tab.dart] $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == widget.targetUserId || widget.targetUserId.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(5)),
        decoration: BoxDecoration(
          color: _following
              ? Colors.transparent
              : AppTheme.primaryColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(r.s(20)),
          border: Border.all(
            color: _following
                ? Colors.white.withValues(alpha: 0.2)
                : AppTheme.primaryColor.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: _loading
            ? SizedBox(
                width: r.s(14),
                height: r.s(14),
                child: const CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppTheme.primaryColor),
              )
            : Text(
                _following ? 'Following' : '+ Follow',
                style: TextStyle(
                  color: _following
                      ? Colors.white.withValues(alpha: 0.5)
                      : AppTheme.primaryColor,
                  fontSize: r.fs(11),
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

// =============================================================================
// AVATAR STACK (3 avatares sobrepostos)
// =============================================================================
class _AvatarStack extends ConsumerWidget {
  final List<String?> avatars;
  final double size;

  const _AvatarStack({required this.avatars, required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final visible = avatars.take(3).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    final overlap = size * 0.35;
    final totalWidth = size + (visible.length - 1) * (size - overlap);

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: List.generate(visible.length, (i) {
          final url = visible[i];
          return Positioned(
            left: i * (size - overlap),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0D0D1A), width: 1.5),
              ),
              child: ClipOval(
                child: (url ?? '').isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: url!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          child: Icon(Icons.person_rounded,
                              size: size * 0.5,
                              color: Colors.white.withValues(alpha: 0.5)),
                        ),
                      )
                    : Container(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        child: Icon(Icons.person_rounded,
                            size: size * 0.5,
                            color: Colors.white.withValues(alpha: 0.5)),
                      ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// =============================================================================
// BOTTOM SHEET — Perfil do membro (Currently Online + Start Chat + Profile)
// =============================================================================
void _showMemberSheet(
  BuildContext context,
  String communityId,
  Map<String, dynamic> member,
  Set<String> onlineUserIds,
) {
  final s = getStrings();
  final p = member['profiles'] as Map<String, dynamic>? ?? {};
  final nickname = p['nickname'] as String? ?? s.user;
  final avatarUrl = p['icon_url'] as String?;
  final userId = p['id'] as String? ?? member['user_id'] as String?;
  final isOnline = userId != null && onlineUserIds.contains(userId);
  final currentUserId = SupabaseService.currentUserId;
  final isSelf = userId == currentUserId;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: false,
    builder: (_) => _MemberBottomSheet(
      communityId: communityId,
      userId: userId ?? '',
      nickname: nickname,
      avatarUrl: avatarUrl,
      isOnline: isOnline,
      isSelf: isSelf,
    ),
  );
}

class _MemberBottomSheet extends ConsumerWidget {
  final String communityId;
  final String userId;
  final String nickname;
  final String? avatarUrl;
  final bool isOnline;
  final bool isSelf;

  const _MemberBottomSheet({
    required this.communityId,
    required this.userId,
    required this.nickname,
    required this.avatarUrl,
    required this.isOnline,
    required this.isSelf,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.symmetric(horizontal: r.s(24), vertical: r.s(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: r.s(36),
            height: r.s(4),
            margin: EdgeInsets.only(bottom: r.s(20)),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: r.s(42),
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                backgroundImage: avatarUrl != null
                    ? CachedNetworkImageProvider(avatarUrl!)
                    : null,
                child: avatarUrl == null
                    ? Text(
                        nickname[0].toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(28),
                        ),
                      )
                    : null,
              ),
              if (isOnline)
                Container(
                  width: r.s(18),
                  height: r.s(18),
                  decoration: BoxDecoration(
                    color: AppTheme.onlineColor,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF1A1A2E), width: 2.5),
                  ),
                ),
            ],
          ),

          SizedBox(height: r.s(12)),

          // Nome
          Text(
            nickname,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: r.fs(18),
            ),
          ),

          SizedBox(height: r.s(4)),

          // Status
          Text(
            isOnline ? 'Currently Online' : s.offline,
            style: TextStyle(
              color: isOnline
                  ? AppTheme.onlineColor
                  : Colors.white.withValues(alpha: 0.4),
              fontSize: r.fs(13),
            ),
          ),

          SizedBox(height: r.s(24)),

          // Botões
          if (!isSelf) ...[
            Row(
              children: [
                // Start Chat
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _openDm(context, communityId, userId);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.onlineColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.s(24))),
                      padding: EdgeInsets.symmetric(vertical: r.s(12)),
                    ),
                    child: Text(
                      'Start Chat',
                      style: TextStyle(
                        color: AppTheme.onlineColor,
                        fontWeight: FontWeight.w600,
                        fontSize: r.fs(14),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: r.s(12)),
                // Profile
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/community/$communityId/profile/$userId');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.s(24))),
                      padding: EdgeInsets.symmetric(vertical: r.s(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: r.fs(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Próprio perfil
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/community/$communityId/profile/$userId');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(24))),
                  padding: EdgeInsets.symmetric(vertical: r.s(12)),
                  elevation: 0,
                ),
                child: Text(
                  'Meu Perfil',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: r.fs(14),
                  ),
                ),
              ),
            ),
          ],

          SizedBox(height: r.s(8)),
        ],
      ),
    );
  }

  Future<void> _openDm(
      BuildContext context, String communityId, String targetId) async {
    try {
      final threadId = await DmInviteService().sendInvite(targetId);
      if (threadId == null || threadId.isEmpty) {
        throw Exception('thread_id_not_returned');
      }

      if (!context.mounted) return;
      context.push('/chat/$threadId');
    } catch (e) {
      if (context.mounted) {
        final s = getStrings();
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
}
