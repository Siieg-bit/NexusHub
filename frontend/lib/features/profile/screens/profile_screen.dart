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
// PROFILE SCREEN
// =============================================================================

/// Tela de perfil do usuário (próprio ou de outro).
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Erro: $error')),
      ),
      data: (user) {
        final frameUrl = equippedAsync.valueOrNull?['frame_url'];
        final isAminoPlus = user.isPremium || IAPService.isAminoPlus;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // ================================================================
              // HEADER DO PERFIL
              // ================================================================
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                actions: [
                  if (isOwnProfile)
                    IconButton(
                      icon: const Icon(Icons.settings_rounded),
                      onPressed: () => context.push('/settings'),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded),
                      onPressed: () => _showUserOptions(context, user),
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
                                AppTheme.primaryDark
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppTheme.scaffoldBg.withValues(alpha: 0.5),
                              AppTheme.scaffoldBg,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.2, 0.6, 1.0],
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
                            // Avatar com Frame e Amino+ badge
                            AvatarWithFrame(
                              avatarUrl: user.iconUrl,
                              frameUrl: frameUrl,
                              size: 88,
                              showAminoPlus: isAminoPlus,
                            ),
                            const SizedBox(height: 12),
                            // Nome + badges
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    user.nickname,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
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
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ================================================================
              // LEVEL & XP BAR
              // ================================================================
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _LevelBar(user: user),
                ),
              ),

              // ================================================================
              // STATS
              // ================================================================
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(label: 'Posts', value: user.postsCount),
                      _StatItem(
                          label: 'Seguidores', value: user.followersCount),
                      _StatItem(label: 'Seguindo', value: user.followingCount),
                      _StatItem(label: 'Reputação', value: user.reputation),
                    ],
                  ),
                ),
              ),

              // ================================================================
              // AÇÕES: Editar / Seguir + Free Coins
              // ================================================================
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: isOwnProfile
                      ? Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        context.push('/profile/edit'),
                                    icon: const Icon(Icons.edit_rounded,
                                        size: 18),
                                    label: const Text('Editar Perfil'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.cardColorLight,
                                      foregroundColor: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // FREE COINS BUTTON
                                _FreeCoinsBadge(
                                  onTap: () => context.push('/wallet'),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _toggleFollow(ref, user),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: user.isFollowing == true
                                      ? AppTheme.cardColorLight
                                      : AppTheme.primaryColor,
                                ),
                                child: Text(user.isFollowing == true
                                    ? 'Seguindo'
                                    : 'Seguir'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () {/* TODO: DM */},
                              child:
                                  const Icon(Icons.chat_bubble_outline_rounded),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () =>
                                  context.push('/profile/$userId/wall'),
                              child: const Icon(Icons.comment_rounded),
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
                    padding: const EdgeInsets.all(16),
                    child: Text(user.bio,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, height: 1.5)),
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
              // POSTS DO USUÁRIO
              // ================================================================
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text('Posts',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      if (isOwnProfile)
                        TextButton.icon(
                          onPressed: () => context.push('/followers/$userId'),
                          icon: const Icon(Icons.people_outline_rounded,
                              size: 16),
                          label: const Text('Seguidores'),
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
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                ),
                error: (error, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Erro: $error'),
                  ),
                ),
                data: (posts) {
                  if (posts.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('Nenhum post publicado',
                              style: TextStyle(color: AppTheme.textHint)),
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
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.comment_rounded),
              title: const Text('Ver Wall'),
              onTap: () {
                Navigator.pop(context);
                context.push('/profile/$userId/wall');
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_rounded),
              title: const Text('Seguidores'),
              onTap: () {
                Navigator.pop(context);
                context.push('/followers/$userId');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.flag_rounded, color: AppTheme.errorColor),
              title: const Text('Denunciar',
                  style: TextStyle(color: AppTheme.errorColor)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading:
                  const Icon(Icons.block_rounded, color: AppTheme.errorColor),
              title: const Text('Bloquear',
                  style: TextStyle(color: AppTheme.errorColor)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// FREE COINS BADGE
// =============================================================================

class _FreeCoinsBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _FreeCoinsBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            ),
            borderRadius: BorderRadius.circular(20),
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
              Icon(Icons.monetization_on_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 4),
              Text(
                'Free Coins',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// LEVEL BAR
// =============================================================================

class _LevelBar extends StatelessWidget {
  final UserModel user;
  const _LevelBar({required this.user});

  @override
  Widget build(BuildContext context) {
    final levelColor = AppTheme.getLevelColor(user.level);
    final progress = (user.reputation % 500) / 500.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: levelColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Level badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: levelColor, width: 2),
            ),
            child: Center(
              child: Text(
                '${user.level}',
                style: TextStyle(
                    color: levelColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
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
                    Text('Nível ${user.level}',
                        style: TextStyle(
                            color: levelColor, fontWeight: FontWeight.w600)),
                    Text('${user.reputation} Rep',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.dividerColor,
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
                color: AppTheme.warningColor.withValues(alpha: 0.15),
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
                          fontWeight: FontWeight.bold,
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
// STAT ITEM
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(label,
            style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
