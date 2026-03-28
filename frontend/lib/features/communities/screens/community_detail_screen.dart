import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/amino_animations.dart';
import '../../feed/widgets/post_card.dart';
import '../widgets/community_drawer.dart';

// =============================================================================
// PROVIDERS
// =============================================================================

final communityDetailProvider =
    FutureProvider.family<CommunityModel, String>((ref, id) async {
  final response =
      await SupabaseService.table('communities').select().eq('id', id).single();
  return CommunityModel.fromJson(response);
});

final communityFeedProvider =
    FutureProvider.family<List<PostModel>, String>((ref, communityId) async {
  final response = await SupabaseService.table('posts')
      .select('*, profiles!posts_author_id_fkey(*)')
      .eq('community_id', communityId)
      .eq('status', 'ok')
      .order('is_pinned', ascending: false)
      .order('created_at', ascending: false)
      .limit(30);

  return (response as List).map((e) {
    final map = Map<String, dynamic>.from(e);
    if (map['profiles'] != null) {
      map['author'] = map['profiles'];
    }
    return PostModel.fromJson(map);
  }).toList();
});

final communityMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, communityId) async {
  final response = await SupabaseService.table('community_members')
      .select(
          '*, profiles!community_members_user_id_fkey(id, nickname, icon_url, level, online_status)')
      .eq('community_id', communityId)
      .order('role', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(response as List);
});

final communityChatProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, communityId) async {
  final response = await SupabaseService.table('chat_threads')
      .select('*, chat_members(count)')
      .eq('community_id', communityId)
      .order('last_message_at', ascending: false)
      .limit(20);
  return List<Map<String, dynamic>>.from(response as List);
});

final communityMembershipProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, communityId) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return null;
  final response = await SupabaseService.table('community_members')
      .select()
      .eq('community_id', communityId)
      .eq('user_id', userId)
      .maybeSingle();
  return response;
});

// =============================================================================
// MAIN SCREEN — Estilo Amino Apps (web-preview)
// =============================================================================

class CommunityDetailScreen extends ConsumerStatefulWidget {
  final String communityId;

  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  ConsumerState<CommunityDetailScreen> createState() =>
      _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tabs = const [
    'Guidelines',
    'Featured',
    'Latest',
    'Chats',
    'Members',
    'Wiki',
    'Leaderboard',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.index = 1; // Featured como padrão (igual web-preview)
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  Future<void> _joinCommunity() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      await SupabaseService.table('community_members').insert({
        'community_id': widget.communityId,
        'user_id': userId,
        'role': 'member',
      });
      ref.invalidate(communityMembershipProvider(widget.communityId));
      ref.invalidate(communityDetailProvider(widget.communityId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Você entrou na comunidade!'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  // ignore: unused_element
  Future<void> _leaveCommunity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sair da comunidade?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Você pode entrar novamente a qualquer momento.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sair',
                  style: TextStyle(color: AppTheme.errorColor))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await SupabaseService.table('community_members')
          .delete()
          .eq('community_id', widget.communityId)
          .eq('user_id', SupabaseService.currentUserId!);
      ref.invalidate(communityMembershipProvider(widget.communityId));
      ref.invalidate(communityDetailProvider(widget.communityId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final communityAsync =
        ref.watch(communityDetailProvider(widget.communityId));
    final membershipAsync =
        ref.watch(communityMembershipProvider(widget.communityId));

    return communityAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: Center(
          child: CircularProgressIndicator(
              color: AppTheme.primaryColor, strokeWidth: 2.5),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(backgroundColor: AppTheme.scaffoldBg),
        body: Center(
            child: Text('Erro: $error',
                style: const TextStyle(color: AppTheme.textSecondary))),
      ),
      data: (community) {
        final themeColor = _parseColor(community.themeColor);
        final membership = membershipAsync.valueOrNull;
        final isMember = membership != null;
        final userRole = membership?['role'] as String?;

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          drawer: CommunityDrawer(
            community: community,
            currentUser: null,
            userRole: userRole,
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // ============================================================
              // HEADER — Estilo Amino (cover + gradient + info overlay)
              // ============================================================
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: AppTheme.scaffoldBg,
                elevation: 0,
                leading: Builder(
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: GestureDetector(
                      onTap: () => Scaffold.of(ctx).openDrawer(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.menu_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
                actions: [
                  // Claim gifts (estilo web-preview)
                  GestureDetector(
                    onTap: () {/* TODO: claim gifts */},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🎁 ',
                              style: TextStyle(fontSize: 11)),
                          Text('Claim gifts',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_outlined,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Cover image
                      if (community.bannerUrl != null)
                        CachedNetworkImage(
                          imageUrl: community.bannerUrl!,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                themeColor,
                                themeColor.withValues(alpha: 0.3)
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      // Gradient overlay (web-preview: from-black/40 to-[#0f0f1e])
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              AppTheme.scaffoldBg,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 1.0],
                          ),
                        ),
                      ),
                      // Community info overlay
                      Positioned(
                        bottom: 8,
                        left: 12,
                        right: 12,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Community icon
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: community.iconUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: community.iconUrl!,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: themeColor,
                                        child: const Icon(Icons.groups_rounded,
                                            color: Colors.white70, size: 32),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Name + members + leaderboard
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      community.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        height: 1.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${formatCount(community.membersCount)} Members',
                                          style: TextStyle(
                                            color: Colors.grey[300],
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Leaderboards pill
                                        GestureDetector(
                                          onTap: () {
                                            _tabController.animateTo(6);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'Leaderboards',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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
              // CHECK-IN BAR (se não fez check-in)
              // ============================================================
              if (isMember)
                SliverToBoxAdapter(
                  child: _CheckInBar(
                    communityId: widget.communityId,
                    themeColor: themeColor,
                  ),
                ),

              // ============================================================
              // LIVE CHATROOMS (horizontal scroll)
              // ============================================================
              SliverToBoxAdapter(
                child: _LiveChatroomsSection(
                  communityId: widget.communityId,
                  community: community,
                ),
              ),

              // ============================================================
              // TABS — Estilo Amino (scrollable, white indicator)
              // ============================================================
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textHint,
                    indicatorColor: Colors.white,
                    indicatorWeight: 2,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 12),
                    dividerColor: Colors.transparent,
                    tabs: _tabs.map((t) {
                      if (t == 'Chats') return const Tab(text: 'Public Chatrooms');
                      if (t == 'Latest') return const Tab(text: 'Latest Feed');
                      return Tab(text: t);
                    }).toList(),
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _GuidelinesTab(community: community),
                _FeedTab(
                    communityId: widget.communityId,
                    ref: ref,
                    isFeatured: true),
                _FeedTab(
                    communityId: widget.communityId,
                    ref: ref,
                    isFeatured: false),
                _ChatTab(communityId: widget.communityId),
                _MembersTab(
                    communityId: widget.communityId, themeColor: themeColor),
                _WikiTab(communityId: widget.communityId),
                _LeaderboardTab(communityId: widget.communityId),
              ],
            ),
          ),
          // FAB — Estilo Amino (verde, pencil)
          floatingActionButton: isMember
              ? AminoAnimations.scaleIn(
                  child: FloatingActionButton(
                    onPressed: () => context
                        .push('/community/${widget.communityId}/create-post'),
                    backgroundColor: AppTheme.primaryColor,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child:
                        const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                  ),
                )
              : // Botão Join se não é membro
              AminoAnimations.pulseGlow(
                  glowColor: AppTheme.primaryColor,
                  child: FloatingActionButton.extended(
                    onPressed: _joinCommunity,
                    backgroundColor: AppTheme.primaryColor,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    icon: const Icon(Icons.group_add_rounded,
                        color: Colors.white, size: 20),
                    label: const Text('Entrar',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                ),
        );
      },
    );
  }
}

// =============================================================================
// CHECK-IN BAR — Estilo Amino (streak progress + botão verde)
// =============================================================================
class _CheckInBar extends StatelessWidget {
  final String communityId;
  final Color themeColor;

  const _CheckInBar({required this.communityId, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          const Text(
            'Check In to earn a prize',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // 7-day streak bar
          Row(
            children: List.generate(7, (i) {
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: i < 6 ? 3 : 0),
                  decoration: BoxDecoration(
                    color: i < 3
                        ? AppTheme.primaryColor
                        : AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          // Check In button
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: () => context.push('/check-in'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
              child: const Text('Check In'),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// LIVE CHATROOMS SECTION — Estilo Amino (horizontal scroll cards)
// =============================================================================
class _LiveChatroomsSection extends StatefulWidget {
  final String communityId;
  final CommunityModel community;

  const _LiveChatroomsSection(
      {required this.communityId, required this.community});

  @override
  State<_LiveChatroomsSection> createState() => _LiveChatroomsSectionState();
}

class _LiveChatroomsSectionState extends State<_LiveChatroomsSection> {
  List<Map<String, dynamic>> _chats = [];

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final response = await SupabaseService.table('chat_threads')
          .select()
          .eq('community_id', widget.communityId)
          .order('last_message_at', ascending: false)
          .limit(4);
      if (mounted) setState(() {
        _chats = List<Map<String, dynamic>>.from(response as List);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_chats.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _chats.length,
          itemBuilder: (context, index) {
            final chat = _chats[index];
            return AminoAnimations.cardPress(
              onTap: () => context.push('/chat/${chat['id']}'),
              child: Container(
                width: 140,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            child: chat['icon_url'] != null
                                ? CachedNetworkImage(
                                    imageUrl: chat['icon_url'] as String,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: AppTheme.surfaceColor,
                                    child: const Icon(Icons.chat_rounded,
                                        color: AppTheme.textHint, size: 24),
                                  ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12)),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppTheme.cardColor,
                                ],
                              ),
                            ),
                          ),
                          // Live indicator
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Text('Live',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Info
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chat['title'] as String? ?? 'Chat',
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// TAB: Guidelines — Estilo Amino
// =============================================================================
class _GuidelinesTab extends StatelessWidget {
  final CommunityModel community;
  const _GuidelinesTab({required this.community});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public_rounded,
                    color: const Color(0xFFFF9800), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Community Guidelines',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              community.description.isNotEmpty
                  ? community.description
                  : 'No guidelines have been set for this community yet.',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TAB: Feed (Featured / Latest)
// =============================================================================
class _FeedTab extends StatelessWidget {
  final String communityId;
  final WidgetRef ref;
  final bool isFeatured;

  const _FeedTab(
      {required this.communityId, required this.ref, this.isFeatured = false});

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(communityFeedProvider(communityId));

    return feedAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
            color: AppTheme.primaryColor, strokeWidth: 2.5),
      ),
      error: (error, _) => Center(
          child: Text('Erro: $error',
              style: const TextStyle(color: AppTheme.textSecondary))),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.article_outlined,
                    size: 48, color: AppTheme.textHint),
                const SizedBox(height: 12),
                Text(
                  'No posts yet. Be the first to post!',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: posts.length,
          itemBuilder: (context, index) => AminoAnimations.staggerItem(
            index: index,
            child: PostCard(
              post: posts[index],
              showCommunity: false,
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// TAB: Featured (placeholder — usa FeedTab com isFeatured)
// =============================================================================

// =============================================================================
// TAB: Wiki
// =============================================================================
class _WikiTab extends StatefulWidget {
  final String communityId;
  const _WikiTab({required this.communityId});

  @override
  State<_WikiTab> createState() => _WikiTabState();
}

class _WikiTabState extends State<_WikiTab> {
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      final response = await SupabaseService.table('wiki_entries')
          .select('*, profiles!wiki_entries_author_id_fkey(nickname, icon_url)')
          .eq('community_id', widget.communityId)
          .eq('status', 'ok')
          .order('created_at', ascending: false)
          .limit(30);
      _entries = List<Map<String, dynamic>>.from(response as List);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
            color: AppTheme.primaryColor, strokeWidth: 2.5),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_rounded,
                size: 48, color: AppTheme.textHint),
            const SizedBox(height: 12),
            Text('Catálogo vazio',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () =>
                  context.push('/community/${widget.communityId}/wiki/create'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Criar Wiki Entry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_entries.length} entradas',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
              GestureDetector(
                onTap: () => context
                    .push('/community/${widget.communityId}/wiki/create'),
                child: Row(
                  children: [
                    Icon(Icons.add_rounded,
                        size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                    Text('Criar',
                        style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              final author = entry['profiles'] as Map<String, dynamic>?;

              return AminoAnimations.staggerItem(
                index: index,
                child: AminoAnimations.cardPress(
                  onTap: () => context.push('/wiki/${entry['id']}'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: entry['cover_image_url'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl:
                                        entry['cover_image_url'] as String,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.auto_stories_rounded,
                                  color: AppTheme.primaryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry['title'] as String? ?? 'Wiki Entry',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppTheme.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'por ${author?['nickname'] ?? 'Anônimo'}',
                                style: const TextStyle(
                                    color: AppTheme.textHint, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppTheme.textHint, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TAB: Chat
// =============================================================================
class _ChatTab extends StatefulWidget {
  final String communityId;
  const _ChatTab({required this.communityId});

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final response = await SupabaseService.table('chat_threads')
          .select()
          .eq('community_id', widget.communityId)
          .order('last_message_at', ascending: false)
          .limit(30);
      _chats = List<Map<String, dynamic>>.from(response as List);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
            color: AppTheme.primaryColor, strokeWidth: 2.5),
      );
    }

    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 48, color: AppTheme.textHint),
            const SizedBox(height: 12),
            Text('No public chatrooms yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        return AminoAnimations.staggerItem(
          index: index,
          child: AminoAnimations.cardPress(
            onTap: () => context.push('/chat/${chat['id']}'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.dividerColor.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      shape: BoxShape.circle,
                    ),
                    child: chat['icon_url'] != null
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: chat['icon_url'] as String,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.tag_rounded,
                            color: AppTheme.textHint, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chat['title'] as String? ?? 'Chat',
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${chat['members_count'] ?? 0} members',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.grey[600], size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// TAB: Members
// =============================================================================
class _MembersTab extends ConsumerWidget {
  final String communityId;
  final Color themeColor;

  const _MembersTab({required this.communityId, required this.themeColor});

  String _roleLabel(String role) {
    switch (role) {
      case 'agent':
        return 'Agent';
      case 'leader':
        return 'Leader';
      case 'curator':
        return 'Curator';
      case 'moderator':
        return 'Moderator';
      default:
        return '';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'agent':
        return AppTheme.warningColor;
      case 'leader':
        return AppTheme.errorColor;
      case 'curator':
        return AppTheme.accentColor;
      case 'moderator':
        return AppTheme.primaryColor;
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(communityMembersProvider(communityId));

    return membersAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
            color: AppTheme.primaryColor, strokeWidth: 2.5),
      ),
      error: (error, _) => Center(child: Text('Erro: $error')),
      data: (members) {
        if (members.isEmpty) {
          return const Center(
            child: Text('Nenhum membro',
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }

        final staff = members
            .where((m) =>
                m['role'] == 'agent' ||
                m['role'] == 'leader' ||
                m['role'] == 'curator')
            .toList();
        final regular = members
            .where((m) =>
                m['role'] != 'agent' &&
                m['role'] != 'leader' &&
                m['role'] != 'curator')
            .toList();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (staff.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
                child: Text(
                  'STAFF (${staff.length})',
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              ...staff.map((m) => _MemberTile(
                  member: m,
                  roleLabel: _roleLabel,
                  roleColor: _roleColor,
                  communityId: communityId)),
              const SizedBox(height: 16),
            ],
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'MEMBROS (${regular.length})',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            ...regular.map((m) => _MemberTile(
                member: m,
                roleLabel: _roleLabel,
                roleColor: _roleColor,
                communityId: communityId)),
          ],
        );
      },
    );
  }
}

// =============================================================================
// TAB: Leaderboard
// =============================================================================
class _LeaderboardTab extends StatelessWidget {
  final String communityId;
  const _LeaderboardTab({required this.communityId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.leaderboard_rounded,
              size: 48, color: AppTheme.textHint),
          const SizedBox(height: 12),
          Text('Leaderboard',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () =>
                context.push('/community/$communityId/leaderboard'),
            child: Text('Ver Leaderboard Completo',
                style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MEMBER TILE — Estilo Amino
// =============================================================================
class _MemberTile extends StatelessWidget {
  final Map<String, dynamic> member;
  final String Function(String) roleLabel;
  final Color Function(String) roleColor;
  final String communityId;

  const _MemberTile({
    required this.member,
    required this.roleLabel,
    required this.roleColor,
    required this.communityId,
  });

  @override
  Widget build(BuildContext context) {
    final profile = member['profiles'] as Map<String, dynamic>? ?? {};
    final userId = profile['id'] as String? ?? member['user_id'] as String?;
    final nickname = profile['nickname'] as String? ?? 'Usuário';
    final avatarUrl = profile['icon_url'] as String?;
    final level = profile['level'] as int? ?? 1;
    final isOnline = (profile['online_status'] as int? ?? 2) == 1;
    final role = member['role'] as String? ?? 'member';

    return AminoAnimations.cardPress(
      onTap: () {
        if (userId != null) {
          context.push('/community/$communityId/profile/$userId');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.dividerColor.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar com indicador online
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.2),
                  backgroundImage: avatarUrl != null
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Text(nickname[0].toUpperCase(),
                          style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 16))
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.onlineColor,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppTheme.scaffoldBg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(nickname,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppTheme.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (role != 'member') ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor(role).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            roleLabel(role),
                            style: TextStyle(
                              color: roleColor(role),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Lv.$level',
                      style: TextStyle(
                          color: AppTheme.getLevelColor(level), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DELEGATE: SliverTabBar
// =============================================================================
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

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
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
