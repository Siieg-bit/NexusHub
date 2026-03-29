import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/models/post_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/amino_animations.dart';
import '../../feed/widgets/post_card.dart';
import '../widgets/community_drawer.dart';
import '../../../core/widgets/amino_drawer.dart';
import '../../../core/widgets/amino_bottom_nav.dart';
import '../../../core/widgets/level_up_dialog.dart';
import '../../stories/widgets/story_carousel.dart';
import 'community_list_screen.dart'; // para checkInStatusProvider

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

final currentUserProfileProvider = FutureProvider<UserModel?>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return null;
  try {
    final response = await SupabaseService.table('profiles')
        .select()
        .eq('id', userId)
        .single();
    return UserModel.fromJson(response);
  } catch (_) {
    return null;
  }
});

final communityHomeLayoutProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, communityId) async {
  try {
    final response = await SupabaseService.table('communities')
        .select('home_layout')
        .eq('id', communityId)
        .single();
    return response['home_layout'] as Map<String, dynamic>? ?? _defaultLayout;
  } catch (_) {
    return _defaultLayout;
  }
});

final onlineMembersCountProvider =
    FutureProvider.family<int, String>((ref, communityId) async {
  try {
    final response = await SupabaseService.table('community_members')
        .select('user_id, profiles!community_members_user_id_fkey(online_status)')
        .eq('community_id', communityId);
    final list = response as List;
    return list.where((m) {
      final p = m['profiles'] as Map<String, dynamic>?;
      return (p?['online_status'] as int? ?? 2) == 1;
    }).length;
  } catch (_) {
    return 0;
  }
});

const Map<String, dynamic> _defaultLayout = {
  'sections_order': ['header', 'check_in', 'live_chats', 'tabs'],
  'sections_visible': {
    'check_in': true,
    'live_chats': true,
    'featured_posts': true,
    'latest_feed': true,
    'public_chats': true,
    'guidelines': true,
  },
  'featured_type': 'list',
  'welcome_banner': {
    'enabled': false,
    'image_url': null,
    'text': null,
    'link': null,
  },
  'pinned_chat_ids': [],
  'bottom_bar': {
    'show_online_count': true,
    'show_create_button': true,
  },
};

// =============================================================================
// MAIN SCREEN — Estilo Amino Apps
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
  int _bottomIndex = 0; // 0=Home, 1=Online, 2=Create, 3=Chats, 4=Me

  List<String> _activeTabs = [];

  @override
  void initState() {
    super.initState();
    _activeTabs = ['Regras', 'Destaque', 'Recentes', 'Chats Públicos'];
    _tabController = TabController(length: _activeTabs.length, vsync: this);
    _tabController.index = 1; // Featured como padrão
  }

  void _rebuildTabs(Map<String, dynamic> layout) {
    final visible =
        layout['sections_visible'] as Map<String, dynamic>? ?? {};
    final tabs = <String>[];
    if (visible['guidelines'] != false) tabs.add('Regras');
    if (visible['featured_posts'] != false) tabs.add('Destaque');
    if (visible['latest_feed'] != false) tabs.add('Recentes');
    if (visible['public_chats'] != false) tabs.add('Chats Públicos');

    if (tabs.length != _activeTabs.length ||
        !_listEquals(tabs, _activeTabs)) {
      _activeTabs = tabs;
      _tabController.dispose();
      _tabController = TabController(length: tabs.length, vsync: this);
      if (tabs.contains('Destaque')) {
        _tabController.index = tabs.indexOf('Destaque');
      }
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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

  @override
  Widget build(BuildContext context) {
    final communityAsync =
        ref.watch(communityDetailProvider(widget.communityId));
    final membershipAsync =
        ref.watch(communityMembershipProvider(widget.communityId));
    final layoutAsync =
        ref.watch(communityHomeLayoutProvider(widget.communityId));

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
        final layout = layoutAsync.valueOrNull ?? _defaultLayout;

        // Rebuild tabs based on layout
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _rebuildTabs(layout);
        });

        final visible =
            layout['sections_visible'] as Map<String, dynamic>? ?? {};
        final bottomBar =
            layout['bottom_bar'] as Map<String, dynamic>? ?? {};
        final showOnline = bottomBar['show_online_count'] != false;
        final showCreate = bottomBar['show_create_button'] != false;
        final welcomeBanner =
            layout['welcome_banner'] as Map<String, dynamic>? ?? {};

        return AminoDrawerController(
          drawer: CommunityDrawer(
            community: community,
            currentUser: ref.watch(currentUserProfileProvider).valueOrNull,
            userRole: userRole,
          ),
          child: Scaffold(
            backgroundColor: AppTheme.scaffoldBg,
          body: _bottomIndex == 0
              ? _buildHomePage(
                  community, themeColor, isMember, userRole, layout,
                  visible, welcomeBanner)
              : _bottomIndex == 1
                  ? _buildOnlinePage(community)
                  : _bottomIndex == 3
                      ? _buildChatsPage(community)
                      : _bottomIndex == 4
                          ? _buildMePage(community)
                          : _buildHomePage(
                              community, themeColor, isMember, userRole,
                              layout, visible, welcomeBanner),
          // ================================================================
          // BOTTOM NAVIGATION BAR — CustomPainter pixel-perfect do Amino
          // ================================================================
          bottomNavigationBar: isMember
              ? AminoBottomNavBar(
                  currentIndex: _bottomIndex,
                  showOnline: showOnline,
                  showCreate: showCreate,
                  onlineCount: ref.watch(onlineMembersCountProvider(widget.communityId)).valueOrNull ?? 0,
                  avatarUrl: ref.watch(currentUserProfileProvider).valueOrNull?.iconUrl,
                  onMenuTap: () => AminoDrawerController.of(context)?.toggle(),
                  onCreateTap: () => context.push(
                      '/community/${widget.communityId}/create-post'),
                  onTap: (index) => setState(() => _bottomIndex = index),
                )
              : null,
          // Join FAB for non-members
          floatingActionButton: !isMember
              ? AminoAnimations.pulseGlow(
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
                )
              : null,
          ),
        ); // fecha AminoDrawerController
      },
    );
  }

  // ================================================================
  // HOME PAGE (main community content)
  // ================================================================
  Widget _buildHomePage(
    CommunityModel community,
    Color themeColor,
    bool isMember,
    String? userRole,
    Map<String, dynamic> layout,
    Map<String, dynamic> visible,
    Map<String, dynamic> welcomeBanner,
  ) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        // HEADER
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          backgroundColor: AppTheme.scaffoldBg,
          elevation: 0,
          leading: Builder(
            builder: (ctx) => Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => AminoDrawerController.of(ctx)?.toggle(),
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
            // Claim gifts
            GestureDetector(
              onTap: () {
                // Presentes diários da comunidade
                showModalBottomSheet(
                  context: context,
                  backgroundColor: AppTheme.surfaceColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('\uD83C\uDF81 Presentes Di\u00e1rios',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 16),
                        Text('Fa\u00e7a check-in para ganhar reputa\u00e7\u00e3o e moedas!',
                            style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('Entendi'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🎁 ', style: TextStyle(fontSize: 11)),
                    Text('Presentes',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Gallery
            GestureDetector(
              onTap: () {
                // Galeria da comunidade - mostra posts com mídia
                context.push('/community/${widget.communityId}/wiki');
              },
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_outlined,
                    color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 6),
            // Notifications
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
                // Gradient overlay
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
                                    '${formatCount(community.membersCount)} Membros',
                                    style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => context.push(
                                        '/community/${widget.communityId}/leaderboard'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Ranking',
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

        // WELCOME BANNER (customizável pelo líder)
        if (welcomeBanner['enabled'] == true)
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () {
                final link = welcomeBanner['link'] as String?;
                if (link != null && link.isNotEmpty) {
                  context.push(link);
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: themeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    if (welcomeBanner['image_url'] != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: welcomeBanner['image_url'] as String,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        welcomeBanner['text'] as String? ??
                            'Bem-vindo à comunidade!',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.textHint, size: 20),
                  ],
                ),
              ),
            ),
          ),

        // CHECK-IN BAR
        if (isMember && visible['check_in'] != false)
          SliverToBoxAdapter(
            child: _CheckInBar(
              communityId: widget.communityId,
              themeColor: themeColor,
            ),
          ),

        // LIVE CHATROOMS
        if (visible['live_chats'] != false)
          SliverToBoxAdapter(
            child: _LiveChatroomsSection(
              communityId: widget.communityId,
              community: community,
            ),
          ),

        // TABS
        if (_activeTabs.isNotEmpty)
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
                tabs: _activeTabs.map((t) => Tab(text: t)).toList(),
              ),
            ),
          ),
      ],
      body: _activeTabs.isNotEmpty
          ? TabBarView(
              controller: _tabController,
              children: _activeTabs.map((tab) {
                switch (tab) {
                  case 'Regras':
                    return _GuidelinesTab(community: community);
                  case 'Destaque':
                    return _FeedTab(
                        communityId: widget.communityId,
                        ref: ref,
                        isFeatured: true);
                  case 'Recentes':
                    return _FeedTab(
                        communityId: widget.communityId,
                        ref: ref,
                        isFeatured: false);
                  case 'Chats Públicos':
                    return _ChatTab(communityId: widget.communityId);
                  default:
                    return const SizedBox.shrink();
                }
              }).toList(),
            )
          : const Center(
              child: Text('Nenhuma seção habilitada',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
    );
  }

  // ================================================================
  // ONLINE PAGE — Membros online
  // ================================================================
  Widget _buildOnlinePage(CommunityModel community) {
    final membersAsync = ref.watch(communityMembersProvider(widget.communityId));

    return Column(
      children: [
        // App bar
        SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _bottomIndex = 0),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 12),
                const Text('Membros Online',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        Expanded(
          child: membersAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primaryColor, strokeWidth: 2.5),
            ),
            error: (e, _) => Center(
                child: Text('Erro: $e',
                    style: const TextStyle(color: AppTheme.textSecondary))),
            data: (members) {
              final onlineMembers = members.where((m) {
                final p = m['profiles'] as Map<String, dynamic>? ?? {};
                return (p['online_status'] as int? ?? 2) == 1;
              }).toList();

              if (onlineMembers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 48, color: Colors.grey[600]),
                      const SizedBox(height: 12),
                      Text('Nenhum membro online',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: onlineMembers.length,
                itemBuilder: (context, index) {
                  final m = onlineMembers[index];
                  final p = m['profiles'] as Map<String, dynamic>? ?? {};
                  final nickname = p['nickname'] as String? ?? 'Usuário';
                  final avatarUrl = p['icon_url'] as String?;
                  final userId = p['id'] as String? ?? m['user_id'] as String?;
                  final reputation = m['local_reputation'] as int? ?? 0;
                  final level = m['local_level'] as int? ?? calculateLevel(reputation);

                  return AminoAnimations.staggerItem(
                    index: index,
                    child: AminoAnimations.cardPress(
                      onTap: () {
                        if (userId != null) {
                          context.push(
                              '/community/${widget.communityId}/profile/$userId');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  AppTheme.dividerColor.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppTheme.primaryColor
                                      .withValues(alpha: 0.2),
                                  backgroundImage: avatarUrl != null
                                      ? CachedNetworkImageProvider(avatarUrl)
                                      : null,
                                  child: avatarUrl == null
                                      ? Text(nickname[0].toUpperCase(),
                                          style: const TextStyle(
                                              color: AppTheme.primaryColor,
                                              fontWeight: FontWeight.w700))
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AppTheme.onlineColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppTheme.scaffoldBg, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nickname,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppTheme.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(
                                      'Lv.$level ${levelTitle(level)}',
                                      style: TextStyle(
                                          color:
                                              AppTheme.getLevelColor(level),
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ================================================================
  // CHATS PAGE — Lista de chats da comunidade
  // ================================================================
  Widget _buildChatsPage(CommunityModel community) {
    return Column(
      children: [
        SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _bottomIndex = 0),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 12),
                const Text('Chats',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.go('/chats'),
                  child: Text('Meus Chats',
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _ChatTab(communityId: widget.communityId),
        ),
      ],
    );
  }

  // ================================================================
  // ME PAGE — Perfil do usuário na comunidade
  // ================================================================
  Widget _buildMePage(CommunityModel community) {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      return const Center(
          child: Text('Faça login para ver seu perfil',
              style: TextStyle(color: AppTheme.textSecondary)));
    }

    return Column(
      children: [
        SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _bottomIndex = 0),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 12),
                const Text('Meu Perfil',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: Text('Perfil Global',
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_rounded,
                    size: 48, color: AppTheme.textHint),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.push(
                      '/community/${widget.communityId}/profile/$userId'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Ver Meu Perfil na Comunidade'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}





// =============================================================================
// CHECK-IN BAR — Estilo Amino (streak progress + botão verde)
// =============================================================================
class _CheckInBar extends ConsumerStatefulWidget {
  final String communityId;
  final Color themeColor;

  const _CheckInBar({required this.communityId, required this.themeColor});

  @override
  ConsumerState<_CheckInBar> createState() => _CheckInBarState();
}

class _CheckInBarState extends ConsumerState<_CheckInBar> {
  bool _loading = false;

  Future<void> _doCheckIn() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final result = await SupabaseService.rpc('perform_checkin', params: {
        'p_user_id': userId,
        'p_community_id': widget.communityId,
      });
      if (result != null && result['success'] == true) {
        final repEarned = result['reputation_earned'] as int? ?? 0;
        final newStreak = result['streak'] as int? ?? 0;
        final levelUp = result['level_up'] as bool? ?? false;
        final newLevel = result['new_level'] as int? ?? 0;
        if (mounted) {
          ref.invalidate(checkInStatusProvider);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              'Check-in! +$repEarned rep | Streak: $newStreak dias',
            ),
            backgroundColor: AppTheme.primaryColor,
          ));
          if (levelUp && newLevel > 0) {
            LevelUpDialog.show(context, newLevel: newLevel);
          }
        }
      } else {
        final error = result?['error'] ?? 'Erro desconhecido';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$error'),
            backgroundColor: AppTheme.errorColor,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkInStatus = ref.watch(checkInStatusProvider);
    final statusMap = checkInStatus.valueOrNull ?? {};
    final myStatus = statusMap[widget.communityId];
    final hasCheckedIn = myStatus?['has_checkin_today'] as bool? ?? false;
    final streak = myStatus?['consecutive_checkin_days'] as int? ?? 0;

    if (hasCheckedIn) return const SizedBox.shrink();

    return Container(
      color: AppTheme.cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Text(
            'Faça Check In para ganhar +${ReputationRewards.checkIn} rep',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // 7-day streak bar
          Row(
            children: List.generate(7, (i) {
              final filled = i < (streak % 7);
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: i < 6 ? 3 : 0),
                  decoration: BoxDecoration(
                    color: filled
                        ? AppTheme.primaryColor
                        : AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: filled
                      ? null
                      : Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.dividerColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.grey[700]!, width: 1),
                            ),
                          ),
                        ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: _loading ? null : _doCheckIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Check In'),
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
          .limit(6);
      if (mounted) {
        setState(() {
          _chats = List<Map<String, dynamic>>.from(response as List);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_chats.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        height: 130,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _chats.length,
          itemBuilder: (context, index) {
            final chat = _chats[index];
            final membersCount = chat['members_count'] as int? ?? 0;

            return AminoAnimations.cardPress(
              onTap: () => context.push('/chat/${chat['id']}'),
              child: Container(
                width: 150,
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
                                  const Text('Ao Vivo',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                          // Members count
                          Positioned(
                            bottom: 6,
                            right: 6,
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
                                  const Icon(Icons.people_rounded,
                                      color: Colors.white, size: 10),
                                  const SizedBox(width: 3),
                                  Text('$membersCount',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600)),
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
                      child: Text(
                        chat['title'] as String? ?? 'Chat',
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
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
                  : 'Nenhuma diretriz foi definida para esta comunidade ainda.',
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
                  'Nenhum post ainda. Seja o primeiro a postar!',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          );
        }

        // Featured mode: compact list style (like Amino)
        if (isFeatured) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return AminoAnimations.staggerItem(
                index: index,
                child: AminoAnimations.cardPress(
                  onTap: () => context.push('/post/${post.id}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color:
                              AppTheme.dividerColor.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            post.title ?? '',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (post.mediaUrls.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedNetworkImage(
                                imageUrl: post.mediaUrls.first,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        // Latest mode: full post cards with Story Carousel on top
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: posts.length + 1, // +1 para o carrossel de stories
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: StoryCarousel(communityId: communityId),
              );
            }
            final postIndex = index - 1;
            return AminoAnimations.staggerItem(
              index: postIndex,
              child: PostCard(
                post: posts[postIndex],
                showCommunity: false,
              ),
            );
          },
        );
      },
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
            Text('Nenhum chat público ainda',
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
                          '${chat['members_count'] ?? 0} membros',
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
