import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../feed/widgets/post_card.dart';
import '../widgets/community_drawer.dart';

// =============================================================================
// PROVIDERS
// =============================================================================

/// Provider para detalhes de uma comunidade.
final communityDetailProvider =
    FutureProvider.family<CommunityModel, String>((ref, id) async {
  final response = await SupabaseService.table('communities')
      .select()
      .eq('id', id)
      .single();
  return CommunityModel.fromJson(response);
});

/// Provider para feed de uma comunidade.
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

/// Provider para membros da comunidade.
final communityMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, communityId) async {
  final response = await SupabaseService.table('community_members')
      .select('*, profiles!community_members_user_id_fkey(id, nickname, icon_url, level, online_status)')
      .eq('community_id', communityId)
      .order('role', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(response as List);
});

/// Provider para chats da comunidade.
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

/// Provider para verificar membership do usuário.
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
// MAIN SCREEN
// =============================================================================

class CommunityDetailScreen extends ConsumerStatefulWidget {
  final String communityId;

  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  ConsumerState<CommunityDetailScreen> createState() =>
      _CommunityDetailScreenState();
}

class _CommunityDetailScreenState
    extends ConsumerState<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
          const SnackBar(content: Text('Você entrou na comunidade!')),
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

  Future<void> _leaveCommunity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da comunidade?'),
        content: const Text('Você pode entrar novamente a qualquer momento.'),
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Erro: $error')),
      ),
      data: (community) {
        final themeColor = _parseColor(community.themeColor);
        final membership = membershipAsync.valueOrNull;
        final isMember = membership != null;
        final userRole = membership?['role'] as String?;

        return Scaffold(
          drawer: CommunityDrawer(
            community: community,
            currentUser: ref.read(
                    StateProvider((ref) => null).notifier) !=
                null
                ? null
                : null,
            userRole: userRole,
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // ============================================================
              // HEADER DA COMUNIDADE
              // ============================================================
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: AppTheme.scaffoldBg,
                leading: Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Banner
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
                              Colors.transparent,
                              AppTheme.scaffoldBg.withValues(alpha: 0.8),
                              AppTheme.scaffoldBg,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.3, 0.7, 1.0],
                          ),
                        ),
                      ),
                      // Info overlay
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: [
                            // Icon
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: themeColor, width: 2),
                              ),
                              child: community.iconUrl != null
                                  ? ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      child: CachedNetworkImage(
                                        imageUrl: community.iconUrl!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(Icons.groups_rounded,
                                      color: themeColor, size: 32),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(community.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall),
                                  if (community.tagline != null)
                                    Text(community.tagline!,
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.people_rounded,
                                          size: 14, color: themeColor),
                                      const SizedBox(width: 4),
                                      Text(
                                          '${formatCount(community.membersCount)} membros',
                                          style: TextStyle(
                                              color: themeColor,
                                              fontSize: 12)),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.circle,
                                          size: 6,
                                          color: AppTheme.onlineColor),
                                      const SizedBox(width: 4),
                                      Text(
                                          '${community.membersCount} membros',
                                          style: const TextStyle(
                                              color: AppTheme.onlineColor,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Join / Leave button
                            if (!isMember)
                              ElevatedButton(
                                onPressed: _joinCommunity,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeColor,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                ),
                                child: const Text('Entrar',
                                    style: TextStyle(fontSize: 13)),
                              )
                            else
                              OutlinedButton(
                                onPressed: _leaveCommunity,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: themeColor),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                child: Text('Membro',
                                    style: TextStyle(
                                        color: themeColor, fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () => context.push('/search'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () =>
                        _showCommunityOptions(context, community, userRole),
                  ),
                ],
              ),

              // ============================================================
              // TABS
              // ============================================================
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: themeColor,
                    labelColor: themeColor,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(text: 'Feed'),
                      Tab(text: 'Featured'),
                      Tab(text: 'Wiki'),
                      Tab(text: 'Chat'),
                      Tab(text: 'Membros'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _FeedTab(communityId: widget.communityId, ref: ref),
                _FeaturedTab(communityId: widget.communityId),
                _WikiTab(communityId: widget.communityId),
                _ChatTab(communityId: widget.communityId),
                _MembersTab(
                    communityId: widget.communityId,
                    themeColor: themeColor),
              ],
            ),
          ),
          floatingActionButton: isMember
              ? FloatingActionButton(
                  onPressed: () => context.push(
                      '/community/${widget.communityId}/create-post'),
                  backgroundColor: themeColor,
                  child:
                      const Icon(Icons.edit_rounded, color: Colors.white),
                )
              : null,
        );
      },
    );
  }

  void _showCommunityOptions(
      BuildContext context, CommunityModel community, String? userRole) {
    final isStaff = userRole == 'agent' ||
        userRole == 'leader' ||
        userRole == 'curator';

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Sobre a comunidade'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog(context, community);
              },
            ),
            ListTile(
              leading: const Icon(Icons.leaderboard_rounded),
              title: const Text('Leaderboard'),
              onTap: () {
                Navigator.pop(context);
                context
                    .push('/community/${community.id}/leaderboard');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.accentColor),
              title: const Text('Check-in Diário'),
              onTap: () {
                Navigator.pop(context);
                context.push('/check-in');
              },
            ),
            if (isStaff) ...[
              const Divider(),
              ListTile(
                leading:
                    Icon(Icons.settings_rounded, color: AppTheme.primaryColor),
                title: const Text('ACM (Configurações)'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/community/${community.id}/acm');
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_rounded,
                    color: AppTheme.errorColor),
                title: const Text('Flag Center'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/community/${community.id}/flags');
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.flag_outlined,
                  color: AppTheme.errorColor),
              title: const Text('Denunciar',
                  style: TextStyle(color: AppTheme.errorColor)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, CommunityModel community) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(community.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (community.tagline != null) ...[
                Text(community.tagline!,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 12),
              ],
              Text(community.description ?? 'Sem descrição disponível.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.people_rounded,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('${community.membersCount} membros',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                      'Criada em ${community.createdAt.day.toString().padLeft(2, '0')}/${community.createdAt.month.toString().padLeft(2, '0')}/${community.createdAt.year}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB: Feed (com posts reais)
// =============================================================================
class _FeedTab extends StatelessWidget {
  final String communityId;
  final WidgetRef ref;

  const _FeedTab({required this.communityId, required this.ref});

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(communityFeedProvider(communityId));

    return feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.article_outlined,
                    size: 64, color: AppTheme.textHint),
                const SizedBox(height: 16),
                Text('Nenhum post ainda',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                const Text('Seja o primeiro a postar!',
                    style: TextStyle(color: AppTheme.textHint)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(communityFeedProvider(communityId)),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: posts.length,
            itemBuilder: (context, index) => PostCard(post: posts[index]),
          ),
        );
      },
    );
  }
}

// =============================================================================
// TAB: Featured (posts em destaque)
// =============================================================================
class _FeaturedTab extends StatefulWidget {
  final String communityId;
  const _FeaturedTab({required this.communityId});

  @override
  State<_FeaturedTab> createState() => _FeaturedTabState();
}

class _FeaturedTabState extends State<_FeaturedTab> {
  List<PostModel> _featured = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeatured();
  }

  Future<void> _loadFeatured() async {
    try {
      final response = await SupabaseService.table('posts')
          .select('*, profiles!posts_author_id_fkey(*)')
          .eq('community_id', widget.communityId)
          .eq('is_featured', true)
          .eq('status', 'ok')
          .order('featured_at', ascending: false)
          .limit(20);

      _featured = (response as List).map((e) {
        final map = Map<String, dynamic>.from(e);
        if (map['profiles'] != null) map['author'] = map['profiles'];
        return PostModel.fromJson(map);
      }).toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_featured.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_outline_rounded,
                size: 64, color: AppTheme.warningColor),
            const SizedBox(height: 16),
            Text('Nenhum post em destaque',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            const Text('Leaders podem destacar posts aqui',
                style: TextStyle(color: AppTheme.textHint)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: _featured.length,
      itemBuilder: (context, index) => PostCard(post: _featured[index]),
    );
  }
}

// =============================================================================
// TAB: Wiki (lista inline de wiki entries)
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
    _loadWiki();
  }

  Future<void> _loadWiki() async {
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_rounded,
                size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text('Catálogo vazio',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.push(
                  '/community/${widget.communityId}/wiki/create'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Criar Wiki Entry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header com botão de criar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_entries.length} entradas',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
              TextButton.icon(
                onPressed: () => context.push(
                    '/community/${widget.communityId}/wiki/create'),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Criar', style: TextStyle(fontSize: 13)),
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
              final author =
                  entry['profiles'] as Map<String, dynamic>?;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () =>
                      context.push('/wiki/${entry['id']}'),
                  leading: Container(
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
                            color: AppTheme.primaryColor),
                  ),
                  title: Text(
                    entry['title'] as String? ?? 'Wiki Entry',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'por ${author?['nickname'] ?? 'Anônimo'}',
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 12),
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
// TAB: Chat (lista inline de chats da comunidade)
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text('Nenhum chat na comunidade',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            const Text('Participe ou crie uma conversa!',
                style: TextStyle(color: AppTheme.textHint)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        final lastMsg = chat['last_message_preview'] as String?;
        final lastMsgAt = DateTime.tryParse(
            chat['last_message_at'] as String? ?? '');

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () => context.push('/chat/${chat['id']}'),
            leading: CircleAvatar(
              backgroundColor: AppTheme.accentColor.withValues(alpha: 0.2),
              backgroundImage: chat['icon_url'] != null
                  ? CachedNetworkImageProvider(
                      chat['icon_url'] as String)
                  : null,
              child: chat['icon_url'] == null
                  ? const Icon(Icons.chat_rounded,
                      color: AppTheme.accentColor, size: 20)
                  : null,
            ),
            title: Text(
              chat['title'] as String? ?? 'Chat',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              lastMsg ?? 'Sem mensagens',
              style: const TextStyle(
                  color: AppTheme.textHint, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: lastMsgAt != null
                ? Text(
                    timeago.format(lastMsgAt, locale: 'pt_BR'),
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 10),
                  )
                : null,
          ),
        );
      },
    );
  }
}

// =============================================================================
// TAB: Membros (lista real de membros da comunidade)
// =============================================================================
class _MembersTab extends ConsumerWidget {
  final String communityId;
  final Color themeColor;

  const _MembersTab(
      {required this.communityId, required this.themeColor});

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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
      data: (members) {
        if (members.isEmpty) {
          return const Center(
            child: Text('Nenhum membro',
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }

        // Separar staff e membros comuns
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
                padding: const EdgeInsets.only(
                    left: 4, bottom: 8, top: 8),
                child: Text(
                  'STAFF (${staff.length})',
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
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
              padding:
                  const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'MEMBROS (${regular.length})',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
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
    final profile =
        member['profiles'] as Map<String, dynamic>? ?? {};
    final userId = profile['id'] as String? ?? member['user_id'] as String?;
    final nickname = profile['nickname'] as String? ?? 'Usuário';
    final avatarUrl = profile['icon_url'] as String?;
    final level = profile['level'] as int? ?? 1;
    final isOnline = (profile['online_status'] as int? ?? 2) == 1;
    final role = member['role'] as String? ?? 'member';

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: () {
          if (userId != null) {
            context.push('/community/$communityId/profile/$userId');
          }
        },
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
              backgroundImage: avatarUrl != null
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(nickname[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold))
                  : null,
            ),
            if (isOnline)
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
        title: Row(
          children: [
            Flexible(
              child: Text(nickname,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
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
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text('Lv.$level',
            style: TextStyle(
                color: AppTheme.getLevelColor(level), fontSize: 12)),
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
