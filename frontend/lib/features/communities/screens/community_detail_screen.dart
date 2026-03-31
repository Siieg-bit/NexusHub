import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/amino_animations.dart';
import '../widgets/community_drawer.dart';
import '../../../core/widgets/amino_drawer.dart';
import '../../../core/widgets/amino_bottom_nav.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/providers/presence_provider.dart';

// Extracted providers & widgets
import '../providers/community_detail_providers.dart';
import '../widgets/community_check_in_bar.dart';
import '../widgets/community_live_chats.dart';
import '../widgets/community_guidelines_tab.dart';
import '../widgets/community_feed_tab.dart';
import '../widgets/community_chat_tab.dart';

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
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _bottomIndex = 0; // 0=Home, 1=Online, 2=Create, 3=Chats, 4=Me
  bool _isDisposed = false;

  List<String> _activeTabs = [];
  Map<String, dynamic>? _lastLayout;

  @override
  void initState() {
    super.initState();
    _activeTabs = ['Regras', 'Destaque', 'Recentes', 'Chats'];
    _tabController = TabController(length: _activeTabs.length, vsync: this);
    _tabController.index = 1; // Featured como padrão

    // Presença é gerenciada exclusivamente pelo communityPresenceProvider
    // (joinChannel no build, leaveChannel no ref.onDispose).
    // NÃO chamar PresenceService manualmente aqui — causa double-dispose
    // e assertion '_dependents.isEmpty'.
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tabController.dispose();
    // Presença é limpa automaticamente pelo ref.onDispose do
    // communityPresenceProvider — NÃO chamar leaveChannel aqui.
    super.dispose();
  }

  bool _pendingTabRebuild = false;

  void _rebuildTabsIfNeeded(Map<String, dynamic> layout) {
    if (_isDisposed || !mounted) return;
    // Evitar múltiplos rebuilds agendados no mesmo frame
    if (_pendingTabRebuild) return;

    final visible =
        layout['sections_visible'] as Map<String, dynamic>? ?? {};
    final tabs = <String>[];
    if (visible['guidelines'] != false) tabs.add('Regras');
    if (visible['featured_posts'] != false) tabs.add('Destaque');
    if (visible['latest_feed'] != false) tabs.add('Recentes');
    if (visible['public_chats'] != false) tabs.add('Chats Públicos');

    // Guard: se a lista de tabs não mudou, não recriar o controller
    if (tabs.length == _activeTabs.length &&
        _listEquals(tabs, _activeTabs)) return;

    _pendingTabRebuild = true;

    // Agendar rebuild para o próximo frame (fora do build)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingTabRebuild = false;
      if (_isDisposed || !mounted) return;

      final oldController = _tabController;
      final newController = TabController(length: tabs.length, vsync: this);
      if (tabs.contains('Destaque')) {
        newController.index = tabs.indexOf('Destaque');
      }

      setState(() {
        _activeTabs = tabs;
        _tabController = newController;
      });

      // Dispose do antigo após o frame de rebuild ter sido processado
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          oldController.dispose();
        } catch (_) {}
      });
    });
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Deep equality para Maps (resolve Bug #1/#2).
  bool _deepMapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      final va = a[key];
      final vb = b[key];
      if (va is Map<String, dynamic> && vb is Map<String, dynamic>) {
        if (!_deepMapEquals(va, vb)) return false;
      } else if (va is List && vb is List) {
        if (va.length != vb.length) return false;
        for (int i = 0; i < va.length; i++) {
          if (va[i] != vb[i]) return false;
        }
      } else if (va != vb) {
        return false;
      }
    }
    return true;
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  Future<void> _joinCommunity() async {
    final r = context.r;
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
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(10))),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocorreu um erro. Tente novamente.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final communityAsync =
        ref.watch(communityDetailProvider(widget.communityId));
    final membershipAsync =
        ref.watch(communityMembershipProvider(widget.communityId));
    final layoutAsync =
        ref.watch(communityHomeLayoutProvider(widget.communityId));

    // Bug #3 fix: O communityPresenceProvider só era watchado na página "Online"
    // (~linha 735). O joinChannel só era chamado ao navegar para aquela aba.
    // Assistir aqui no build principal garante que o canal de presença é
    // criado e o track() é executado imediatamente ao entrar na tela.
    // O ref.onDispose do provider cuida do leaveChannel automaticamente.
    //
    // Bug #6 fix: Usar select para não causar rebuild do build principal
    // toda vez que o Set de usuários online muda (eventos de presença
    // chegam com frequência). O watch aqui serve apenas para instanciar
    // o provider e disparar o joinChannel — não para consumir o valor.
    ref.watch(
      communityPresenceProvider(widget.communityId)
          .select((_) => null), // ignora o valor; apenas instancia o provider
    );

    return communityAsync.when(
      loading: () => Scaffold(
        backgroundColor: context.scaffoldBg,
        body: Center(
          child: CircularProgressIndicator(
              color: AppTheme.primaryColor, strokeWidth: 2.5),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(backgroundColor: context.scaffoldBg),
        body: Center(
            child: Text('Erro: $error',
                style: TextStyle(color: context.textSecondary))),
      ),
      data: (community) {
        final themeColor = _parseColor(community.themeColor);
        final membership = membershipAsync.valueOrNull;
        final isMember = membership != null;
        final userRole = membership?['role'] as String?;
        final layout = layoutAsync.valueOrNull ?? defaultLayout;

        // Bug #1/#2 fix: Comparar por valor (deep equality) em vez de
        // referência. Cada rebuild do FutureProvider cria um novo Map,
        // então `!=` por referência era SEMPRE true, causando dispose/recreate
        // infinito do TabController.
        if (!_deepMapEquals(_lastLayout, layout)) {
          _lastLayout = layout;
          _rebuildTabsIfNeeded(layout);
        }

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
            onChatsTap: () {
              if (_isDisposed || !mounted) return;
              setState(() => _bottomIndex = 3);
            },
            onGuidelinesTap: () {
              if (_isDisposed || !mounted) return;
              setState(() {
                _bottomIndex = 0;
                final idx = _activeTabs.indexOf('Regras');
                if (idx >= 0) _tabController.animateTo(idx);
              });
            },
            onRecentFeedTap: () {
              if (_isDisposed || !mounted) return;
              setState(() {
                _bottomIndex = 0;
                final idx = _activeTabs.indexOf('Recentes');
                if (idx >= 0) _tabController.animateTo(idx);
              });
            },
          ),
          child: Scaffold(
            backgroundColor: context.scaffoldBg,
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
          bottomNavigationBar: isMember
              ? AminoBottomNavBar(
                  currentIndex: _bottomIndex,
                  showOnline: showOnline,
                  showCreate: showCreate,
                  onlineCount: ref.watch(onlineCountProvider(widget.communityId)),
                  avatarUrl: ref.watch(
                    currentUserProfileProvider.select((a) => a.valueOrNull?.iconUrl),
                  ),
                  onMenuTap: () => AminoDrawerController.of(context)?.toggle(),
                  onCreateTap: () => context.push(
                      '/community/${widget.communityId}/create-post'),
                  onTap: (index) => setState(() => _bottomIndex = index),
                )
              : null,
          floatingActionButton: !isMember
              ? AminoAnimations.pulseGlow(
                  glowColor: AppTheme.primaryColor,
                  child: FloatingActionButton.extended(
                    onPressed: _joinCommunity,
                    backgroundColor: AppTheme.primaryColor,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.s(16))),
                    icon: Icon(Icons.group_add_rounded,
                        color: Colors.white, size: r.s(20)),
                    label: Text('Entrar',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: r.fs(14))),
                  ),
                )
              : null,
          ),
        );
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
    final r = context.r;
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        // HEADER
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          backgroundColor: context.scaffoldBg,
          elevation: 0,
          leading: Builder(
            builder: (ctx) => Padding(
              padding: EdgeInsets.all(r.s(8)),
              child: GestureDetector(
                onTap: () => AminoDrawerController.of(ctx)?.toggle(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.menu_rounded,
                      color: Colors.white, size: r.s(20)),
                ),
              ),
            ),
          ),
          actions: [
            // Claim gifts
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: context.surfaceColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => Padding(
                    padding: EdgeInsets.all(r.s(24)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('\uD83C\uDF81 Presentes Di\u00e1rios',
                            style: TextStyle(
                                color: context.textPrimary,
                                fontSize: r.fs(18),
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: r.s(16)),
                        Text('Fa\u00e7a check-in para ganhar reputa\u00e7\u00e3o e moedas!',
                            style: TextStyle(color: Colors.grey[400], fontSize: r.fs(14))),
                        SizedBox(height: r.s(20)),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(r.s(20))),
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
                    EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(5)),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(r.s(20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('\uD83C\uDF81 ', style: TextStyle(fontSize: r.fs(11))),
                    Text('Presentes',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: r.fs(10),
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            SizedBox(width: r.s(6)),
            // Gallery
            GestureDetector(
              onTap: () {
                context.push('/community/${widget.communityId}/wiki');
              },
              child: Container(
                width: r.s(34),
                height: r.s(34),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.photo_library_outlined,
                    color: Colors.white, size: r.s(18)),
              ),
            ),
            SizedBox(width: r.s(6)),
            // Busca dentro da comunidade
            GestureDetector(
              onTap: () => context.push(
                '/community/${widget.communityId}/search',
                extra: {'communityName': community.name},
              ),
              child: Container(
                width: r.s(34),
                height: r.s(34),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search_rounded,
                    color: Colors.white, size: r.s(18)),
              ),
            ),
            SizedBox(width: r.s(6)),
            // Notifications
            GestureDetector(
              onTap: () => context.push('/notifications'),
              child: Container(
                width: r.s(34),
                height: r.s(34),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications_outlined,
                    color: Colors.white, size: r.s(18)),
              ),
            ),
            SizedBox(width: r.s(12)),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Cover image
                if ((community.bannerUrl ?? '').isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: community.bannerUrl ?? '',
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
                        context.scaffoldBg,
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
                        width: r.s(64),
                        height: r.s(64),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(r.s(16)),
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
                          borderRadius: BorderRadius.circular(r.s(14)),
                          child: (community.iconUrl ?? '').isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: community.iconUrl ?? '',
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: themeColor,
                                  child: Icon(Icons.groups_rounded,
                                      color: Colors.white70, size: r.s(32)),
                                ),
                        ),
                      ),
                      SizedBox(width: r.s(12)),
                      // Name + members + leaderboard
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                community.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r.fs(18),
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: r.s(4)),
                              Row(
                                children: [
                                  Text(
                                    '${formatCount(community.membersCount)} Membros',
                                    style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: r.fs(11),
                                    ),
                                  ),
                                  SizedBox(width: r.s(8)),
                                  GestureDetector(
                                    onTap: () => context.push(
                                        '/community/${widget.communityId}/leaderboard'),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: r.s(8), vertical: r.s(3)),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        borderRadius:
                                            BorderRadius.circular(r.s(12)),
                                      ),
                                      child: Text(
                                        'Ranking',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: r.fs(9),
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
                margin: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
                padding: EdgeInsets.all(r.s(12)),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.s(12)),
                  border: Border.all(
                      color: themeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    if (welcomeBanner['image_url'] != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(r.s(8)),
                        child: CachedNetworkImage(
                          imageUrl: welcomeBanner['image_url'] as String? ?? '',
                          width: r.s(40),
                          height: r.s(40),
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: r.s(10)),
                    ],
                    Expanded(
                      child: Text(
                        welcomeBanner['text'] as String? ??
                            'Bem-vindo à comunidade!',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: context.textHint, size: r.s(20)),
                  ],
                ),
              ),
            ),
          ),

        // CHECK-IN BAR
        if (isMember && visible['check_in'] != false)
          SliverToBoxAdapter(
            child: CommunityCheckInBar(
              communityId: widget.communityId,
              themeColor: themeColor,
            ),
          ),

        // LIVE CHATROOMS
        if (visible['live_chats'] != false)
          SliverToBoxAdapter(
            child: CommunityLiveChats(
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
                unselectedLabelColor: context.textHint,
                indicatorColor: Colors.white,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: r.fs(12)),
                unselectedLabelStyle: TextStyle(
                    fontWeight: FontWeight.w500, fontSize: r.fs(12)),
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
                    return CommunityGuidelinesTab(community: community);
                  case 'Destaque':
                    return CommunityFeedTab(
                        communityId: widget.communityId,
                        isFeatured: true);
                  case 'Recentes':
                    return CommunityFeedTab(
                        communityId: widget.communityId,
                        isFeatured: false);
                  case 'Chats':
                    return CommunityChatTab(communityId: widget.communityId);
                  default:
                    return const SizedBox.shrink();
                }
              }).toList(),
            )
          : Center(
              child: Text('Nenhuma seção habilitada',
                  style: TextStyle(color: context.textSecondary)),
            ),
    );
  }

  // ================================================================
  // ONLINE PAGE — Membros online
  // ================================================================
  Widget _buildOnlinePage(CommunityModel community) {
    final r = context.r;
    final membersAsync = ref.watch(communityMembersProvider(widget.communityId));
    final presenceAsync = ref.watch(communityPresenceProvider(widget.communityId));
    final onlineUserIds = presenceAsync.valueOrNull ?? {};

    return Column(
      children: [
        SafeArea(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _bottomIndex = 0),
                  child: Icon(Icons.arrow_back_rounded,
                      color: context.textPrimary),
                ),
                SizedBox(width: r.s(12)),
                Text('Membros Online (${onlineUserIds.length})',
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: r.fs(16),
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
                child: Text('Ocorreu um erro. Tente novamente.',
                    style: TextStyle(color: context.textSecondary))),
            data: (members) {
              final onlineMembers = members.where((m) {
                final userId = m['user_id'] as String?;
                return userId != null && onlineUserIds.contains(userId);
              }).toList();

              if (onlineMembers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: r.s(48), color: Colors.grey[600]),
                      SizedBox(height: r.s(12)),
                      Text('Nenhum membro online',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: r.fs(13))),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(r.s(12)),
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
                        padding: EdgeInsets.symmetric(vertical: r.s(8)),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  context.dividerClr.withValues(alpha: 0.15),
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
                                    width: r.s(12),
                                    height: r.s(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.onlineColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: context.scaffoldBg, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: r.s(12)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nickname,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: r.fs(14),
                                          color: context.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(
                                      'Lv.$level ${levelTitle(level)}',
                                      style: TextStyle(
                                          color:
                                              AppTheme.getLevelColor(level),
                                          fontSize: r.fs(11))),
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
    final r = context.r;
    return Column(
      children: [
        SafeArea(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _bottomIndex = 0),
                  child: Icon(Icons.arrow_back_rounded,
                      color: context.textPrimary),
                ),
                SizedBox(width: r.s(12)),
                Text('Chats',
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: r.fs(16),
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    context.go('/chats');
                  },
                  child: Text('Ver Todos',
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: r.fs(12),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: CommunityChatTab(communityId: widget.communityId),
        ),
      ],
    );
  }

  // ================================================================
  // ME PAGE — Perfil do usuário na comunidade
  // ================================================================
  Widget _buildMePage(CommunityModel community) {
    final r = context.r;
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      return Center(
          child: Text('Faça login para ver seu perfil',
              style: TextStyle(color: context.textSecondary)));
    }

    return Column(
      children: [
        SafeArea(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _bottomIndex = 0),
                  child: Icon(Icons.arrow_back_rounded,
                      color: context.textPrimary),
                ),
                SizedBox(width: r.s(12)),
                Text('Meu Perfil',
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: r.fs(16),
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: Text('Perfil Global',
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: r.fs(12),
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
                Icon(Icons.person_rounded,
                    size: r.s(48), color: context.textHint),
                SizedBox(height: r.s(12)),
                ElevatedButton(
                  onPressed: () => context.push(
                      '/community/${widget.communityId}/profile/$userId'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.s(12))),
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
      color: context.scaffoldBg,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) =>
      tabBar.controller != oldDelegate.tabBar.controller;
}
