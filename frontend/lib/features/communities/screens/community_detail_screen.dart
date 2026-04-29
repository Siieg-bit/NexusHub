import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/amino_animations.dart';
import '../widgets/community_drawer.dart';
import '../../../core/widgets/amino_drawer.dart';
import '../../../core/widgets/amino_bottom_nav.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/providers/presence_provider.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/widgets/nexus_badge.dart';

// Extracted providers & widgets
import '../providers/community_detail_providers.dart';
import '../widgets/community_live_projections.dart';
import '../widgets/community_voice_rooms.dart';
import '../widgets/community_guidelines_tab.dart';
import '../widgets/community_feed_tab.dart';
import '../widgets/community_online_tab.dart';
import '../widgets/community_chat_tab.dart';
import '../widgets/community_create_menu.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/deep_link_service.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import 'package:amino_clone/features/auth/providers/auth_provider.dart';
import 'package:amino_clone/config/nexus_theme_data.dart';
import 'package:amino_clone/core/providers/nexus_theme_provider.dart';

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
    final s = getStrings();
    _activeTabs = [
      s.guidelines,
      s.featured,
      s.latest,
      s.chats,
    ];
    _tabController = TabController(length: _activeTabs.length, vsync: this);
    _tabController.index = 1; // Featured como padrão

    // Presença é gerenciada exclusivamente pelo communityPresenceProvider
    // (joinChannel no build, leaveChannel no ref.onDispose).
    // NÃO chamar PresenceService manualmente aqui — causa double-dispose
    // e assertion '_dependents.isEmpty'.

    // Registrar comunidade ativa para acúmulo de minutos online.
    PresenceService.instance.setActiveCommunity(widget.communityId);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tabController.dispose();
    // Presença é limpa automaticamente pelo ref.onDispose do
    // communityPresenceProvider — NÃO chamar leaveChannel aqui.
    // Limpar comunidade ativa ao sair.
    PresenceService.instance.setActiveCommunity(null);
    super.dispose();
  }

  bool _pendingTabRebuild = false;

  Future<void> _handleInvite(String communityName) async {
    try {
      final response = await SupabaseService.client
          .rpc('get_or_create_community_invite', params: {
        'p_community_id': widget.communityId,
      });

      if (response != null) {
        final code = response.toString();
        // No NexusHub, os links de convite seguem o padrão /join/CODE
        final inviteUrl = 'https://nexushub.app/join/$code';

        await DeepLinkService.shareUrl(
          type: 'community_invite',
          targetId: widget.communityId,
          title: communityName,
          text: 'Junte-se à comunidade $communityName no NexusHub!\n$inviteUrl',
        );
      }
    } catch (e) {
      debugPrint('Erro ao gerar convite: $e');
    }
  }

  void _rebuildTabsIfNeeded(Map<String, dynamic> layout) {
    if (_isDisposed || !mounted) return;
    // Evitar múltiplos rebuilds agendados no mesmo frame
    if (_pendingTabRebuild) return;
    final s = getStrings();
    final visible = layout['sections_visible'] as Map<String, dynamic>? ?? {};
    final tabs = <String>[];
    if (visible['guidelines'] != false) tabs.add(s.guidelines);
    if (visible['featured_posts'] != false) {
      tabs.add(s.featured);
    }
    if (visible['latest_feed'] != false) tabs.add(s.latest);
    if (visible['public_chats'] != false) tabs.add(s.chats);

    // Guard: se a lista de tabs não mudou, não recriar o controller
    if (tabs.length == _activeTabs.length && _listEquals(tabs, _activeTabs))
      return;

    _pendingTabRebuild = true;

    // Agendar rebuild para o próximo frame (fora do build)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingTabRebuild = false;
      if (_isDisposed || !mounted) return;

      final oldController = _tabController;
      final newController = TabController(length: tabs.length, vsync: this);
      if (tabs.contains(s.featured)) {
        newController.index = tabs.indexOf(s.featured);
      }

      setState(() {
        _activeTabs = tabs;
        _tabController = newController;
      });

      // Dispose do antigo após o frame de rebuild ter sido processado
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          oldController.dispose();
        } catch (e) {
          debugPrint('[community_detail_screen.dart] $e');
        }
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
      return context.nexusTheme.accentPrimary;
    }
  }

  Future<void> _joinCommunity() async {
    final r = context.r;
    final s = getStrings();
    HapticService.action(); // Feedback tátil ao entrar na comunidade
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      // Capturar welcomeMessage ANTES de invalidar o provider
      final communityState = ref.read(communityDetailProvider(widget.communityId));
      final welcomeMsg = communityState.valueOrNull?.welcomeMessage;
      // Usa currentUserProvider (já em memória) como ponto de partida do perfil local.
      // Após o join, o usuário edita livremente o perfil da comunidade sem sincronização.
      final currentUser = ref.read(currentUserProvider);
      final result = await SupabaseService.rpc('join_community', params: {
        'p_community_id': widget.communityId,
      }) as Map<String, dynamic>?;
      ref.invalidate(communityMembershipProvider(widget.communityId));
      ref.invalidate(communityDetailProvider(widget.communityId));
      if (mounted) {
        final displayMsg = (result?['welcome_message'] as String?)?.trim().isNotEmpty == true
            ? result!['welcome_message'] as String
            : s.joinedCommunity;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMsg),
            backgroundColor: context.nexusTheme.accentPrimary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(10))),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.anErrorOccurredTryAgain)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
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
        backgroundColor: context.nexusTheme.backgroundPrimary,
        body: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: const CommunityHeaderSkeleton(),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        appBar: AppBar(backgroundColor: context.nexusTheme.backgroundPrimary),
        body: Center(
            child: Text(s.errorGeneric(error.toString()),
                style: TextStyle(color: context.nexusTheme.textSecondary))),
      ),
      data: (community) {
        // ── Redirect para não-membros ──────────────────────────────────────────
        // Se o membership ainda está carregando, aguarda sem redirecionar.
        // Quando carregado: se não é membro, redireciona para /info.
        // Isso garante que qualquer deep link ou tap em card que caia em
        // /community/:id primeiro mostre a tela de informações para quem
        // ainda não ingressou na comunidade.
        if (membershipAsync.isLoading) {
          return Scaffold(
            backgroundColor: context.nexusTheme.backgroundPrimary,
            body: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: const CommunityHeaderSkeleton(),
            ),
          );
        }
        final membership = membershipAsync.valueOrNull;
        final isMember = membership != null;
        if (!isMember) {
          // Usar WidgetsBinding para redirecionar após o frame atual
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.replace('/community/${widget.communityId}/info');
            }
          });
          // Exibe skeleton enquanto aguarda o redirect
          return Scaffold(
            backgroundColor: context.nexusTheme.backgroundPrimary,
            body: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: const CommunityHeaderSkeleton(),
            ),
          );
        }
        // ── Membro confirmado: renderiza a tela completa ───────────────────────
        // Prioridade de tema: cor da comunidade só sobrescreve se o usuário
        // estiver usando o tema padrão (principal). Se ele selecionou outro
        // tema, esse tema deve ser priorizado.
        final currentTheme = ref.watch(nexusThemeProvider);
        final isDefaultTheme = currentTheme.id == NexusThemeId.principal;
        final themeColor = isDefaultTheme
            ? _parseColor(community.themeColor)
            : context.nexusTheme.accentPrimary;
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
        final bottomBar = layout['bottom_bar'] as Map<String, dynamic>? ?? {};
        final showOnline = bottomBar['show_online_count'] != false;
        final showCreate = bottomBar['show_create_button'] != false;
        final welcomeBanner =
            layout['welcome_banner'] as Map<String, dynamic>? ?? {};

        final screenWidth = MediaQuery.of(context).size.width;
        return AminoDrawerController(
          maxSlide: screenWidth * 0.92,
          drawer: CommunityDrawer(
            community: community,
            currentUser: ref.watch(currentUserProvider),
            userRole: userRole,
            membership: membership,
          ),
          child: Scaffold(
            backgroundColor: context.nexusTheme.backgroundPrimary,
            // extendBody: true faz o conteúdo passar por baixo do nav flutuante
            extendBody: true,
            body: _bottomIndex == 0
                ? _buildHomePage(community, themeColor, isMember, userRole,
                    layout, visible, welcomeBanner)
                : _bottomIndex == 1
                    ? CommunityOnlineTab(community: community)
                    : _buildHomePage(community, themeColor, isMember, userRole,
                        layout, visible, welcomeBanner),
            // Floating capsule nav — só aparece nas páginas iniciais (membro)
            bottomNavigationBar: isMember
                ? AminoBottomNavBar(
                    currentIndex: _bottomIndex,
                    showOnline: showOnline,
                    showCreate: showCreate,
                    onlineCount:
                        ref.watch(onlineCountProvider(widget.communityId)),
                    // Avatares dos membros online (até 3)
                    onlineAvatars: () {
                      final membersAsync = ref
                          .watch(communityMembersProvider(widget.communityId));
                      final onlineIds = ref
                              .watch(
                                  communityPresenceProvider(widget.communityId))
                              .valueOrNull ??
                          {};
                      final members = membersAsync.valueOrNull ?? [];
                      return members
                          .where((m) =>
                              onlineIds.contains(m['user_id'] as String?))
                          .take(3)
                          .map((m) {
                        final p = m['profiles'] as Map<String, dynamic>? ?? {};
                        return p['icon_url'] as String?;
                      }).toList();
                    }(),
                    showChatUnreadBadge: (ref
                                .watch(unreadCountByCommunityProvider)
                                .valueOrNull?[widget.communityId] ??
                            0) >
                        0,
                    // Usa o avatar local da comunidade se o usuário tiver
                    // definido um, senão cai no avatar global.
                    avatarUrl: ref
                            .watch(communityLocalAvatarProvider(
                                widget.communityId))
                            .valueOrNull ??
                        ref.watch(currentUserAvatarProvider),
                    onMenuTap: () =>
                        AminoDrawerController.of(context)?.toggle(),
                    onOnlineTap: () => _showOnlineMembersSheet(
                      context,
                      ref,
                      widget.communityId,
                      community.name,
                    ),
                    onCreateTap: () => showCommunityCreateMenu(
                      context,
                      communityId: widget.communityId,
                      communityName: community.name,
                    ),
                    onTap: (index) {
                      if (index == 3) {
                        context.push(
                          '/community/${widget.communityId}/my-chats',
                          extra: {'communityName': community.name},
                        );
                      } else if (index == 4) {
                        context.push(
                            '/community/${widget.communityId}/my-profile');
                      } else if (index == 0) {
                        // Home: volta para a página principal com aba Destaque
                        setState(() => _bottomIndex = 0);
                        final destIdx = _activeTabs.indexOf(s.featured);
                        if (destIdx >= 0 &&
                            _tabController.index != destIdx) {
                          _tabController.animateTo(destIdx);
                        }
                      } else {
                        setState(() => _bottomIndex = index);
                      }
                    },
                  )
                : null,
            // FAB "Entrar" para não-membros; nenhum FAB para membros
            // (o FAB de criar post está no próprio nav capsule)
            floatingActionButton: !isMember
                ? AminoAnimations.pulseGlow(
                    glowColor: context.nexusTheme.accentPrimary,
                    child: FloatingActionButton.extended(
                      onPressed: _joinCommunity,
                      backgroundColor: context.nexusTheme.accentPrimary,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.s(16))),
                      icon: Icon(Icons.group_add_rounded,
                          color: Colors.white, size: r.s(20)),
                      label: Text(s.login,
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
    final s = getStrings();
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        // HEADER
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          backgroundColor: context.nexusTheme.backgroundPrimary,
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
            // Botão de Convite Destacado (Estilo Kyodo)
            if (isMember)
              Padding(
                padding: EdgeInsets.symmetric(vertical: r.s(10)),
                child: GestureDetector(
                  onTap: () => _handleInvite(community.name),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: r.s(12)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          themeColor,
                          themeColor.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(r.s(20)),
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add_alt_1_rounded,
                            color: Colors.white, size: r.s(16)),
                        SizedBox(width: r.s(4)),
                        Text(
                          'CONVIDAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: r.fs(11),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SizedBox(width: r.s(8)),
            // Share
            GestureDetector(
              onTap: () => DeepLinkService.shareUrl(
                type: 'community',
                targetId: widget.communityId,
                title: community.name,
                text: community.name,
              ),
              child: Container(
                width: r.s(34),
                height: r.s(34),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.share_outlined,
                    color: Colors.white, size: r.s(18)),
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
            // Notifications — badge de não lidas da comunidade
            Builder(builder: (ctx) {
              final communityUnread = ref.watch(
                unreadCommunityNotificationCountProvider(widget.communityId),
              );
              return GestureDetector(
                onTap: () => context.push('/community/${widget.communityId}/notifications'),
                child: Container(
                  width: r.s(34),
                  height: r.s(34),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: NexusBadge(
                      count: communityUnread,
                      offset: const Offset(3, -3),
                      child: Icon(
                        communityUnread > 0
                            ? Icons.notifications_rounded
                            : Icons.notifications_outlined,
                        color: Colors.white,
                        size: r.s(18),
                      ),
                    ),
                  ),
                ),
              );
            }),
            SizedBox(width: r.s(12)),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Cover image — usa banner do header ou fallback
                Builder(builder: (ctx) {
                  final headerBanner = community.bannerForContext('header');
                  if ((headerBanner ?? '').isNotEmpty) {
                    return CachedNetworkImage(
                      imageUrl: headerBanner!,
                      fit: BoxFit.cover,
                    );
                  }
                  // Sem banner: aplica cor predominante conforme themeApplyMode
                  switch (community.themeApplyMode) {
                    case 'full':
                      return Container(color: themeColor);
                    case 'gradient':
                      final gradEnd = community.themeGradientEnd != null
                          ? Color(int.tryParse(community.themeGradientEnd!.replaceFirst('#', '0xFF')) ?? 0xFF2196F3)
                          : themeColor.withValues(alpha: 0.3);
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [themeColor, gradEnd],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      );
                    default: // accent
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [themeColor, themeColor.withValues(alpha: 0.3)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      );
                  }
                }),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        context.nexusTheme.backgroundPrimary,
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
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              themeColor.withValues(alpha: 0.9),
                              themeColor.withValues(alpha: 0.65),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.35),
                              blurRadius: r.s(20),
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(r.s(2)),
                          child: GestureDetector(
                            onTap: () => context.push(
                              '/community/${widget.communityId}/info',
                            ),
                            child: Container(
                              width: r.s(62),
                              height: r.s(62),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(r.s(14)),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
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
                                            color: Colors.white70,
                                            size: r.s(32)),
                                      ),
                              ),
                            ),
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
                              GestureDetector(
                                onTap: () => context.push(
                                  '/community/${widget.communityId}/info',
                                ),
                                child: Text(
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
                              ),
                              SizedBox(height: r.s(4)),
                              Row(
                                children: [
                                  Flexible(
                                    child: GestureDetector(
                                      onTap: () => context.push(
                                        '/community/${widget.communityId}/members',
                                      ),
                                      child: Text(
                                        '${formatCount(community.membersCount)} Membros',
                                        style: TextStyle(
                                          color: Colors.grey[300],
                                          fontSize: r.fs(11),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                                        color: context.nexusTheme.accentPrimary,
                                        borderRadius:
                                            BorderRadius.circular(r.s(12)),
                                      ),
                                      child: Text(
                                        s.ranking,
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
                margin:
                    EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
                padding: EdgeInsets.all(r.s(12)),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.s(12)),
                  border: Border.all(color: themeColor.withValues(alpha: 0.3)),
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
                            s.welcomeToCommunity,
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: context.nexusTheme.textHint, size: r.s(20)),
                  ],
                ),
              ),
            ),
          ),

        // LIVE PROJECTIONS (chats públicos com projeção de tela ativa)
        if (visible['live_chats'] != false)
          SliverToBoxAdapter(
            child: CommunityLiveProjections(
              communityId: widget.communityId,
            ),
          ),

        // VOICE ROOMS (salas de voz e palco ativas)
        if (visible['live_chats'] != false)
          SliverToBoxAdapter(
            child: CommunityVoiceRooms(
              communityId: widget.communityId,
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
                unselectedLabelColor: context.nexusTheme.textHint,
                indicatorColor: Colors.white,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: r.fs(12)),
                unselectedLabelStyle:
                    TextStyle(fontWeight: FontWeight.w500, fontSize: r.fs(12)),
                dividerColor: Colors.transparent,
                tabs: _activeTabs.map((t) => Tab(text: t)).toList(),
              ),
            ),
          ),
      ],
      body: _activeTabs.isNotEmpty
          ? TabBarView(
              controller: _tabController,
              // Física personalizada: swipe mais rápido e responsivo
              physics: const _FastSwipePhysics(),
              children: _activeTabs.map((tab) {
                if (tab == s.guidelines) {
                    return CommunityGuidelinesTab(communityId: widget.communityId);
                  } else if (tab == s.featured) {
                    return CommunityFeedTab(
                        communityId: widget.communityId, isFeatured: true);
                  } else if (tab == s.latest) {
                    return CommunityFeedTab(
                        communityId: widget.communityId, isFeatured: false);
                  } else if (tab == s.chats) {
                    return CommunityChatTab(communityId: widget.communityId);
                  } else {
                    return const SizedBox.shrink();
                  }
              }).toList(),
            )
          : Center(
              child: Text(s.noSectionsEnabled,
                  style: TextStyle(color: context.nexusTheme.textSecondary)),
            ),
    );
  }

  // ================================================================
  // ONLINE PAGE — Membros online
  // ================================================================

  // ================================================================
  // SHEET DE MEMBROS ONLINE (CommunityOnlineTab como overlay)
  // ================================================================
  void _showOnlineMembersSheet(
    BuildContext ctx,
    WidgetRef ref,
    String communityId,
    String communityName,
  ) {
    // Usa showGeneralDialog para ter controle total sobre o overlay escuro.
    // showModalBottomSheet ignora barrierColor quando há um Scaffold pai.
    final s = getStrings();
    showGeneralDialog(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: s.online,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
      pageBuilder: (dialogCtx, _, __) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: MediaQuery.of(dialogCtx).size.height * 0.87,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: dialogCtx.scaffoldBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20.0),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle de arrasto
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
                      child: Container(
                        width: 40.0,
                        height: 4.0,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2.0),
                        ),
                      ),
                    ),
                    // Página Online completa
                    Expanded(
                      child: CommunityOnlineTab(
                        community: _communityForSheet(ref, communityId),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Obtém o CommunityModel atual para passar ao CommunityOnlineTab.
  CommunityModel _communityForSheet(WidgetRef ref, String communityId) {
    final detailAsync = ref.read(communityDetailProvider(communityId));
    return detailAsync.valueOrNull ?? CommunityModel(
      id: communityId,
      name: '',
      agentId: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
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
      color: context.nexusTheme.backgroundPrimary,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) =>
      tabBar.controller != oldDelegate.tabBar.controller;
}

// =============================================================================
// FÍSICA: Swipe rápido e responsivo para o TabBarView
// =============================================================================
/// Física personalizada que reduz a resistência do swipe entre abas.
/// - `minFlingVelocity` menor → basta um toque rápido para trocar de aba
/// - `minFlingDistance` menor → distância mínima de arrasto reduzida
/// - `springDescription` mais rígida → snap mais rápido ao soltar
class _FastSwipePhysics extends PageScrollPhysics {
  const _FastSwipePhysics({super.parent});

  @override
  _FastSwipePhysics applyTo(ScrollPhysics? ancestor) {
    return _FastSwipePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 80,
        stiffness: 100,
        damping: 1,
      );
}
