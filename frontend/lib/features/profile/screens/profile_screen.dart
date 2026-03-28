import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/iap_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/widgets/chat_bubble.dart'; // AvatarWithFrame, AminoPlusBadge, StreakBar
import '../../feed/widgets/post_card.dart';

/// Provider para perfil de um usuário.
final userProfileProvider =
    FutureProvider.family<UserModel, String>((ref, userId) async {
  final response = await SupabaseService.rpc('get_user_profile',
      params: {'p_user_id': userId});
  return UserModel.fromJson(response as Map<String, dynamic>);
});

/// Provider para posts de um usuário.
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

/// Provider para streak do check-in.
final userStreakProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  try {
    final response = await SupabaseService.table('check_ins')
        .select()
        .eq('user_id', userId)
        .single();
    return response;
  } catch (_) {
    return {'current_streak': 0, 'max_streak': 0, 'total_check_ins': 0};
  }
});

/// Provider para itens equipados (avatar frame, bubble).
final equippedItemsProvider =
    FutureProvider.family<Map<String, String?>, String>((ref, userId) async {
  try {
    final response = await SupabaseService.table('user_inventory')
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
// PROFILE SCREEN — Estilo Amino Apps
// =============================================================================

class ProfileScreen extends ConsumerWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));
    final postsAsync = ref.watch(userPostsProvider(userId));
    final streakAsync = ref.watch(userStreakProvider(userId));
    final equippedAsync = ref.watch(equippedItemsProvider(userId));
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = currentUser?.id == userId;

    return profileAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: const Center(
          child: CircularProgressIndicator(
              color: AppTheme.primaryColor, strokeWidth: 2),
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
              Text('Error loading profile',
                  style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            ],
          ),
        ),
      ),
      data: (user) {
        final frameUrl = equippedAsync.valueOrNull?['frame_url'];
        final isAminoPlus = user.isPremium || IAPService.isAminoPlus;

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          body: CustomScrollView(
            slivers: [
              // ================================================================
              // HEADER DO PERFIL — Estilo Amino
              // ================================================================
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: AppTheme.scaffoldBg,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white, size: 18),
                    onPressed: () => context.pop(),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: isOwnProfile
                        ? IconButton(
                            icon: const Icon(Icons.settings_rounded,
                                color: Colors.white, size: 18),
                            onPressed: () => context.push('/settings'),
                          )
                        : IconButton(
                            icon: const Icon(Icons.more_horiz_rounded,
                                color: Colors.white, size: 18),
                            onPressed: () => _showUserOptions(context, user),
                          ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Banner
                      if (user.bannerUrl != null)
                        CachedNetworkImage(
                            imageUrl: user.bannerUrl!, fit: BoxFit.cover)
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.primaryDark,
                                AppTheme.scaffoldBg,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              AppTheme.scaffoldBg.withValues(alpha: 0.7),
                              AppTheme.scaffoldBg,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.3, 0.7, 1.0],
                          ),
                        ),
                      ),
                      // Profile info
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          children: [
                            // Avatar com Frame e Amino+ badge — gradient ring
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // Gradient ring
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppTheme.primaryColor,
                                        AppTheme.accentColor,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.4),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                // Avatar or Frame
                                AvatarWithFrame(
                                  avatarUrl: user.iconUrl,
                                  frameUrl: frameUrl,
                                  size: 88,
                                  showAminoPlus: isAminoPlus,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Nome + badges
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                if (user.isNicknameVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded,
                                      color: AppTheme.accentColor, size: 20),
                                ],
                                if (isAminoPlus) ...[
                                  const SizedBox(width: 8),
                                  const AminoPlusBadge(),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('@${user.aminoId}',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ================================================================
              // LEVEL & XP BAR — Estilo Amino
              // ================================================================
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _LevelBar(user: user),
                ),
              ),

              // ================================================================
              // STATS — Estilo Amino
              // ================================================================
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatItem(label: 'Posts', value: user.postsCount),
                        _divider(),
                        _StatItem(
                            label: 'Followers', value: user.followersCount),
                        _divider(),
                        _StatItem(
                            label: 'Following', value: user.followingCount),
                        _divider(),
                        _StatItem(label: 'Rep', value: user.reputation),
                      ],
                    ),
                  ),
                ),
              ),

              // ================================================================
              // AÇÕES: Editar / Seguir + Free Coins — Estilo Amino
              // ================================================================
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: isOwnProfile
                      ? Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => context.push('/profile/edit'),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.08)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.edit_rounded,
                                          size: 16, color: Colors.grey[400]),
                                      const SizedBox(width: 8),
                                      Text('Edit Profile',
                                          style: TextStyle(
                                              color: Colors.grey[300],
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _FreeCoinsBadge(
                              onTap: () => context.push('/wallet'),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _toggleFollow(ref, user),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: user.isFollowing == true
                                        ? AppTheme.surfaceColor
                                        : AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: user.isFollowing == true
                                        ? Border.all(
                                            color: AppTheme.primaryColor
                                                .withValues(alpha: 0.3))
                                        : null,
                                    boxShadow: user.isFollowing == true
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: AppTheme.primaryColor
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      user.isFollowing == true
                                          ? 'Following'
                                          : 'Follow',
                                      style: TextStyle(
                                        color: user.isFollowing == true
                                            ? AppTheme.primaryColor
                                            : Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _actionCircle(
                              Icons.chat_bubble_outline_rounded,
                              () {/* TODO: DM */},
                            ),
                            const SizedBox(width: 8),
                            _actionCircle(
                              Icons.comment_rounded,
                              () => context.push('/profile/$userId/wall'),
                            ),
                          ],
                        ),
                ),
              ),

              // ================================================================
              // BIO
              // ================================================================
              if (user.bio.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Text(user.bio,
                          style: TextStyle(
                              color: Colors.grey[400],
                              height: 1.5,
                              fontSize: 13)),
                    ),
                  ),
                ),

              // ================================================================
              // STREAK BAR (se for próprio perfil)
              // ================================================================
              if (isOwnProfile)
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: streakAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (streak) => StreakBar(
                        currentStreak: streak['current_streak'] as int? ?? 0,
                        maxStreak: streak['max_streak'] as int? ?? 0,
                        checkInDays: streak['total_check_ins'] as int? ?? 0,
                      ),
                    ),
                  ),
                ),

              // ================================================================
              // POSTS DO USUÁRIO — Estilo Amino
              // ================================================================
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Text('Posts',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 18)),
                      const Spacer(),
                      if (isOwnProfile)
                        GestureDetector(
                          onTap: () => context.push('/followers/$userId'),
                          child: Row(
                            children: [
                              Icon(Icons.people_outline_rounded,
                                  size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text('Followers',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              postsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primaryColor, strokeWidth: 2)),
                  ),
                ),
                error: (error, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: $error',
                        style: TextStyle(color: Colors.grey[500])),
                  ),
                ),
                data: (posts) {
                  if (posts.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.article_outlined,
                                  size: 48, color: Colors.grey[700]),
                              const SizedBox(height: 12),
                              Text('No posts yet',
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => PostCard(post: posts[index]),
                      childCount: posts.length,
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }

  Widget _actionCircle(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: Colors.grey[400], size: 18),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }

  Future<void> _toggleFollow(WidgetRef ref, UserModel user) async {
    try {
      if (user.isFollowing == true) {
        await SupabaseService.table('follows')
            .delete()
            .eq('follower_id', SupabaseService.currentUserId!)
            .eq('following_id', userId);
      } else {
        await SupabaseService.table('follows').insert({
          'follower_id': SupabaseService.currentUserId,
          'following_id': userId,
        });
      }
      ref.invalidate(userProfileProvider(userId));
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
            // Handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _optionTile(Icons.comment_rounded, 'View Wall', () {
              Navigator.pop(ctx);
              context.push('/profile/$userId/wall');
            }),
            _optionTile(Icons.people_rounded, 'Followers', () {
              Navigator.pop(ctx);
              context.push('/followers/$userId');
            }),
            _optionTile(Icons.flag_rounded, 'Report', () {
              Navigator.pop(ctx);
            }, isDestructive: true),
            _optionTile(Icons.block_rounded, 'Block', () {
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
// FREE COINS BADGE — Estilo Amino
// =============================================================================

class _FreeCoinsBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _FreeCoinsBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on_rounded, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text(
              'Free Coins',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// LEVEL BAR — Estilo Amino
// =============================================================================

class _LevelBar extends StatelessWidget {
  final UserModel user;
  const _LevelBar({required this.user});

  @override
  Widget build(BuildContext context) {
    final levelColor = AppTheme.getLevelColor(user.level);
    final progress = (user.reputation % 500) / 500.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: levelColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Level badge — gradient ring
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  levelColor,
                  levelColor.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: levelColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${user.level}',
                    style: TextStyle(
                        color: levelColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 18),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Level ${user.level}',
                        style: TextStyle(
                            color: levelColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    Text('${user.reputation} Rep',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Coins
          GestureDetector(
            onTap: () => context.push('/wallet'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on_rounded,
                      color: AppTheme.warningColor, size: 16),
                  const SizedBox(width: 4),
                  Text('${user.coins}',
                      style: const TextStyle(
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// STAT ITEM — Estilo Amino
// =============================================================================

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _formatCount(value),
          style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: Colors.grey[600], fontSize: 11)),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
