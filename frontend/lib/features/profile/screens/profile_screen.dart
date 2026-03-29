import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/post_model.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/iap_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/widgets/chat_bubble.dart'; // AvatarWithFrame, AminoPlusBadge
import '../../feed/widgets/post_card.dart';

/// Provider para perfil de um usuário.
final userProfileProvider =
    FutureProvider.family<UserModel, String>((ref, userId) async {
  final response = await SupabaseService.rpc('get_user_profile',
      params: {'p_user_id': userId});
  return UserModel.fromJson(response as Map<String, dynamic>);
});

/// Provider para posts de um usuário (Stories).
final userPostsProvider =
    FutureProvider.family<List<PostModel>, String>((ref, userId) async {
  final response = await SupabaseService.table('posts')
      .select('*, profiles!posts_author_id_fkey(*)')
      .eq('author_id', userId)
      .eq('status', 'published')
      .order('created_at', ascending: false)
      .limit(20);

  return (response as List).map((e) {
    final map = Map<String, dynamic>.from(e);
    if (map['profiles'] != null) map['author'] = map['profiles'];
    return PostModel.fromJson(map);
  }).toList();
});

/// Provider para comunidades vinculadas (Linked Communities) de qualquer usuário.
final userLinkedCommunitiesProvider =
    FutureProvider.family<List<CommunityModel>, String>((ref, userId) async {
  final response = await SupabaseService.table('community_members')
      .select('community_id, communities(*)')
      .eq('user_id', userId)
      .eq('is_banned', false)
      .order('joined_at', ascending: false);

  return (response as List)
      .where((e) => e['communities'] != null)
      .map((e) =>
          CommunityModel.fromJson(e['communities'] as Map<String, dynamic>))
      .toList();
});

/// Provider para wall messages de um usuário (usa tabela comments com profile_wall_id).
final userWallProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, userId) async {
  try {
    final res = await SupabaseService.table('comments')
        .select(
            '*, profiles!comments_author_id_fkey(id, nickname, icon_url)')
        .eq('profile_wall_id', userId)
        .eq('status', 'ok')
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List).map((e) {
      final map = Map<String, dynamic>.from(e);
      // Normalizar: mover profiles para campo 'author' para compatibilidade
      if (map['profiles'] != null) {
        map['author'] = map['profiles'];
      }
      return map;
    }).toList();
  } catch (_) {
    return [];
  }
});

/// Provider para itens equipados (avatar frame, bubble).
final equippedItemsProvider =
    FutureProvider.family<Map<String, String?>, String>((ref, userId) async {
  try {
    final response = await SupabaseService.table('user_purchases')
        .select('*, store_items(*)')
        .eq('user_id', userId)
        .eq('is_equipped', true);
    final items = response as List;
    String? frameUrl;
    String? bubbleUrl;
    for (final item in items) {
      final storeItem = item['store_items'] as Map<String, dynamic>?;
      if (storeItem == null) continue;
      final type = storeItem['type'] as String? ?? '';
      final imageUrl = storeItem['image_url'] as String? ?? '';
      if (type == 'avatar_frame') frameUrl = imageUrl;
      if (type == 'chat_bubble') bubbleUrl = imageUrl;
    }
    return {'frame_url': frameUrl, 'bubble_url': bubbleUrl};
  } catch (_) {
    return {'frame_url': null, 'bubble_url': null};
  }
});

// =============================================================================
// PROFILE SCREEN — Layout fiel ao Amino Apps
// Top bar: [<] [Badge Moedas] [Compartilhar] [Menu]
// Avatar à esquerda + Edit Profile à direita
// Followers / Following em 2 blocos
// Bio
// Amino+ banner
// Linked Communities
// Tabs: Stories | Wall
// =============================================================================

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _wallController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _wallController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider(widget.userId));
    final equippedAsync = ref.watch(equippedItemsProvider(widget.userId));
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = currentUser?.id == widget.userId;

    return profileAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: const Center(
          child: CircularProgressIndicator(
              color: AppTheme.accentColor, strokeWidth: 2),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppTheme.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.grey[700]),
              const SizedBox(height: 12),
              Text('Erro ao carregar perfil',
                  style: TextStyle(color: Colors.grey[500], fontSize: 15)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => ref.invalidate(userProfileProvider(widget.userId)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Tentar novamente',
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
        final isAminoPlus = user.isPremium || IAPService.isAminoPlus;

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // ================================================================
              // TOP BAR — [<] [Badge Moedas Laranja] [Compartilhar] [Menu ≡]
              // ================================================================
              SliverAppBar(
                pinned: true,
                backgroundColor: AppTheme.scaffoldBg.withValues(alpha: 0.95),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => context.pop(),
                ),
                title: GestureDetector(
                  onTap: () => context.push('/wallet'),
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                          ),
                          child: const Center(
                            child: Text('A',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatCoins(user.coins),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined,
                        color: Colors.white, size: 22),
                    onPressed: () {
                      final link = 'https://nexushub.app/u/${widget.userId}';
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link do perfil copiado!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      isOwnProfile
                          ? Icons.menu_rounded
                          : Icons.more_horiz_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: isOwnProfile
                        ? () => context.push('/settings')
                        : () => _showUserOptions(context, user),
                  ),
                ],
              ),

              // ================================================================
              // AVATAR À ESQUERDA + EDIT PROFILE À DIREITA
              // ================================================================
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      AvatarWithFrame(
                        avatarUrl: user.iconUrl,
                        frameUrl: frameUrl,
                        size: 80,
                        showAminoPlus: isAminoPlus,
                      ),
                      const Spacer(),
                      // Botão Edit Profile / Seguir
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: isOwnProfile
                            ? GestureDetector(
                                onTap: () => context.push('/profile/edit'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_rounded,
                                          size: 14, color: Colors.grey[400]),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Edit Profile',
                                        style: TextStyle(
                                          color: Colors.grey[300],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: () => _toggleFollow(ref, user),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: user.isFollowing == true
                                        ? Colors.transparent
                                        : AppTheme.accentColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: user.isFollowing == true
                                        ? Border.all(
                                            color: AppTheme.accentColor)
                                        : null,
                                  ),
                                  child: Text(
                                    user.isFollowing == true
                                        ? 'Seguindo'
                                        : 'Seguir',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome + badges
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.nickname,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAminoPlus) ...[
                            const SizedBox(width: 6),
                            const AminoPlusBadge(),
                          ],
                          if (user.isNicknameVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded,
                                color: AppTheme.accentColor, size: 18),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (user.aminoId.isNotEmpty)
                        Text(
                          '@${user.aminoId}',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ),

              // ================================================================
              // FOLLOWERS / FOLLOWING — 2 blocos lado a lado
              // ================================================================
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              context.push('/followers/${widget.userId}'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _formatCount(user.followersCount),
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Followers',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              context.push('/following/${widget.userId}'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _formatCount(user.followingCount),
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Following',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 12),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: user.bio.isNotEmpty
                      ? Text(
                          user.bio,
                          style: TextStyle(
                            color: Colors.grey[300],
                            height: 1.5,
                            fontSize: 14,
                          ),
                        )
                      : isOwnProfile
                          ? GestureDetector(
                              onTap: () => context.push('/profile/edit'),
                              child: const Text(
                                'Clique aqui para adicionar sua biografia!',
                                style: TextStyle(
                                  color: AppTheme.accentColor,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                ),
              ),

              // ================================================================
              // AMINO+ BANNER — "Try Amino+ for free today!"
              // ================================================================
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GestureDetector(
                    onTap: () => context.push('/store'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Amino+',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isAminoPlus
                                  ? 'Membro Amino+'
                                  : 'Try Amino+ for free today!',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                child: _LinkedCommunitiesSection(userId: widget.userId),
              ),

              // ================================================================
              // DIVIDER
              // ================================================================
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Divider(
                    color: Colors.white.withValues(alpha: 0.08),
                    height: 1,
                  ),
                ),
              ),

              // ================================================================
              // PINNED WIKIS — Wikis fixadas no perfil
              // ================================================================
              SliverToBoxAdapter(
                child: _PinnedWikisSection(userId: widget.userId),
              ),

              // ================================================================
              // TABS — Stories | Wall
              // ================================================================
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  tabBar: TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.textPrimary,
                    unselectedLabelColor: Colors.grey[600],
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    indicatorColor: AppTheme.textPrimary,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: const [
                      Tab(text: 'Stories'),
                      Tab(text: 'Wall'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                // Tab Stories
                _StoriesTab(userId: widget.userId),
                // Tab Wall
                _WallTab(
                  userId: widget.userId,
                  wallController: _wallController,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

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

  static String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Future<void> _toggleFollow(WidgetRef ref, UserModel user) async {
    try {
      if (user.isFollowing == true) {
        await SupabaseService.table('follows')
            .delete()
            .eq('follower_id', SupabaseService.currentUserId!)
            .eq('following_id', widget.userId);
      } else {
        await SupabaseService.table('follows').insert({
          'follower_id': SupabaseService.currentUserId,
          'following_id': widget.userId,
        });
      }
      ref.invalidate(userProfileProvider(widget.userId));
    } catch (e) {
      // Silenciar
    }
  }

  void _showUserOptions(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _optionTile(Icons.comment_rounded, 'Ver Mural', () {
              Navigator.pop(ctx);
              context.push('/user/${widget.userId}/wall');
            }),
            _optionTile(Icons.people_rounded, 'Seguidores', () {
              Navigator.pop(ctx);
              context.push('/user/${widget.userId}/followers');
            }),
            _optionTile(Icons.flag_rounded, 'Denunciar', () {
              Navigator.pop(ctx);
            }, isDestructive: true),
            _optionTile(Icons.block_rounded, 'Bloquear', () {
              Navigator.pop(ctx);
            }, isDestructive: true),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(IconData icon, String label, VoidCallback onTap,
      {bool isDestructive = false}) {
    final color = isDestructive ? AppTheme.errorColor : Colors.grey[400];
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// LINKED COMMUNITIES SECTION
// =============================================================================
class _LinkedCommunitiesSection extends ConsumerWidget {
  final String userId;
  const _LinkedCommunitiesSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communitiesAsync = ref.watch(userLinkedCommunitiesProvider(userId));

    return communitiesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
              color: AppTheme.accentColor, strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (communities) {
        if (communities.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Linked Communities',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: communities.map((community) {
                  return GestureDetector(
                    onTap: () =>
                        context.push('/community/${community.id}'),
                    child: SizedBox(
                      width: (MediaQuery.of(context).size.width - 48) / 2,
                      child: Row(
                        children: [
                          // Ícone da comunidade
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: community.iconUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: community.iconUrl!,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _communityPlaceholder(community),
                                  )
                                : _communityPlaceholder(community),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  community.name,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (community.endpoint != null)
                                  Text(
                                    'ID:${community.endpoint}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 10,
                                    ),
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
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _communityPlaceholder(CommunityModel community) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          community.name.isNotEmpty ? community.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// STORIES TAB — Posts do usuário
// =============================================================================
class _StoriesTab extends ConsumerWidget {
  final String userId;
  const _StoriesTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(userPostsProvider(userId));

    return postsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
            color: AppTheme.accentColor, strokeWidth: 2),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to load data.',
                style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => ref.invalidate(userPostsProvider(userId)),
              child: Icon(Icons.refresh_rounded,
                  color: Colors.grey[500], size: 32),
            ),
          ],
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined,
                    size: 48, color: Colors.grey[700]),
                const SizedBox(height: 12),
                Text('Nenhum post ainda',
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: posts.length,
          itemBuilder: (context, index) => PostCard(post: posts[index]),
        );
      },
    );
  }
}

// =============================================================================
// WALL TAB — Mural de mensagens
// =============================================================================
class _WallTab extends ConsumerWidget {
  final String userId;
  final TextEditingController wallController;

  const _WallTab({required this.userId, required this.wallController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallAsync = ref.watch(userWallProvider(userId));
    final isOwnWall = userId == SupabaseService.currentUserId;

    return Column(
      children: [
        // Input para nova mensagem
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: wallController,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Escreva no mural...',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _postMessage(ref, context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
        // Lista de mensagens
        Expanded(
          child: wallAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.accentColor, strokeWidth: 2),
            ),
            error: (_, __) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Failed to load data.',
                      style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => ref.invalidate(userWallProvider(userId)),
                    child: Icon(Icons.refresh_rounded,
                        color: Colors.grey[500], size: 32),
                  ),
                ],
              ),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Text('Nenhum comentário no mural',
                      style: TextStyle(color: Colors.grey[500])),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final profile =
                      (msg['author'] ?? msg['profiles']) as Map<String, dynamic>? ?? {};
                  final authorId = msg['author_id'] as String? ?? '';
                  final createdAt =
                      DateTime.tryParse(msg['created_at'] as String? ?? '') ??
                          DateTime.now();
                  final canDelete =
                      isOwnWall || authorId == SupabaseService.currentUserId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  context.push('/user/$authorId'),
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    AppTheme.primaryColor.withValues(alpha: 0.2),
                                backgroundImage:
                                    profile['icon_url'] != null
                                        ? CachedNetworkImageProvider(
                                            profile['icon_url'] as String)
                                        : null,
                                child: profile['icon_url'] == null
                                    ? Text(
                                        ((profile['nickname'] as String?) ??
                                                '?')[0]
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile['nickname'] as String? ??
                                        'Usuário',
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    _timeAgo(createdAt),
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (canDelete)
                              GestureDetector(
                                onTap: () => _deleteMessage(
                                    ref, msg['id'] as String),
                                child: Icon(Icons.close_rounded,
                                    color: Colors.grey[600], size: 16),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          msg['content'] as String? ?? '',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
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

  Future<void> _postMessage(WidgetRef ref, BuildContext context) async {
    final text = wallController.text.trim();
    if (text.isEmpty) return;
    try {
      await SupabaseService.table('comments').insert({
        'profile_wall_id': userId,
        'author_id': SupabaseService.currentUserId,
        'content': text,
      });
      wallController.clear();
      ref.invalidate(userWallProvider(userId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  Future<void> _deleteMessage(WidgetRef ref, String messageId) async {
    try {
      await SupabaseService.table('comments')
          .delete()
          .eq('id', messageId);
      ref.invalidate(userWallProvider(userId));
    } catch (_) {}
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 365) return '${diff.inDays ~/ 365}a';
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}m';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}min';
    return 'agora';
  }
}

// =============================================================================
// PINNED WIKIS SECTION — Wikis fixadas no perfil (via bookmarks.wiki_id)
// =============================================================================
class _PinnedWikisSection extends StatefulWidget {
  final String userId;
  const _PinnedWikisSection({required this.userId});

  @override
  State<_PinnedWikisSection> createState() => _PinnedWikisSectionState();
}

class _PinnedWikisSectionState extends State<_PinnedWikisSection> {
  List<Map<String, dynamic>> _pinnedWikis = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPinnedWikis();
  }

  Future<void> _loadPinnedWikis() async {
    try {
      final res = await SupabaseService.table('bookmarks')
          .select('wiki_id, wiki_entries!bookmarks_wiki_id_fkey(id, title, cover_image_url, category)')
          .eq('user_id', widget.userId)
          .not('wiki_id', 'is', null)
          .order('created_at', ascending: false)
          .limit(10);
      final list = (res as List).where((e) => e['wiki_entries'] != null).toList();
      if (mounted) {
        setState(() {
          _pinnedWikis = List<Map<String, dynamic>>.from(list);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    if (_pinnedWikis.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.push_pin_rounded, size: 14, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(
                'Pinned Wikis',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pinnedWikis.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final bookmark = _pinnedWikis[index];
                final wiki = bookmark['wiki_entries'] as Map<String, dynamic>;
                final title = wiki['title'] as String? ?? 'Wiki';
                final coverUrl = wiki['cover_image_url'] as String?;
                final category = wiki['category'] as String?;
                final wikiId = wiki['id'] as String;

                return GestureDetector(
                  onTap: () => context.push('/wiki/$wikiId'),
                  child: Container(
                    width: 140,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          child: coverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: coverUrl,
                                  height: 50,
                                  width: 140,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    height: 50,
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.15),
                                    child: const Center(
                                      child: Icon(Icons.auto_stories_rounded,
                                          color: AppTheme.primaryColor,
                                          size: 20),
                                    ),
                                  ),
                                )
                              : Container(
                                  height: 50,
                                  width: 140,
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.15),
                                  child: const Center(
                                    child: Icon(Icons.auto_stories_rounded,
                                        color: AppTheme.primaryColor,
                                        size: 20),
                                  ),
                                ),
                        ),
                        // Title + category
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (category != null && category.isNotEmpty)
                                  Text(
                                    category,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 9,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
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
// TAB BAR DELEGATE — Para SliverPersistentHeader
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
      color: AppTheme.scaffoldBg,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}
