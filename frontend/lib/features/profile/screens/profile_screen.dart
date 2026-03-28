import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/iap_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/widgets/chat_bubble.dart'; // AvatarWithFrame, AminoPlusBadge, StreakBar
import '../../feed/widgets/post_card.dart';
import '../../../core/widgets/amino_particles_bg.dart';

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
// PROFILE SCREEN — Estilo Amino Apps (layout fiel ao original)
// Avatar à ESQUERDA, sem anel verde, stats em 2 cards translúcidos,
// top bar com moedas + compartilhar + menu
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
            ],
          ),
        ),
      ),
      data: (user) {
        final frameUrl = equippedAsync.valueOrNull?['frame_url'];
        final isAminoPlus = user.isPremium || IAPService.isAminoPlus;

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          body: AminoParticlesBg(
            child: CustomScrollView(
              slivers: [
                // ==============================================================
                // TOP BAR — Estilo Amino original
                // [<] [Badge Moedas Laranja] [Compartilhar] [Menu ≡]
                // ==============================================================
                SliverAppBar(
                  pinned: true,
                  backgroundColor: AppTheme.scaffoldBg.withValues(alpha: 0.9),
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => context.pop(),
                  ),
                  title: // Badge de moedas laranja centralizada
                      GestureDetector(
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
                      onPressed: () {/* TODO: Share profile */},
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

                // ==============================================================
                // PROFILE HEADER — Avatar à ESQUERDA + Editar Perfil à direita
                // Estilo Amino original: sem anel verde, sem SliverAppBar expandida
                // ==============================================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar à ESQUERDA (sem gradient ring)
                        AvatarWithFrame(
                          avatarUrl: user.iconUrl,
                          frameUrl: frameUrl,
                          size: 80,
                          showAminoPlus: isAminoPlus,
                        ),
                        const SizedBox(width: 16),
                        // Info + Botão Editar à direita
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              // Nome + badges
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.nickname,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20,
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
                              Text(
                                '@${user.aminoId}',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              // Botão Editar Perfil / Seguir
                              if (isOwnProfile)
                                GestureDetector(
                                  onTap: () => context.push('/profile/edit'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_rounded,
                                            size: 14, color: Colors.grey[400]),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Editar Perfil',
                                          style: TextStyle(
                                            color: Colors.grey[300],
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                GestureDetector(
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
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
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

                // ==============================================================
                // STATS — 2 cards translúcidos lado a lado (Seguidores / Seguindo)
                // Estilo Amino original
                // ==============================================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                context.push('/followers/$userId'),
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
                                    'Seguidores',
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
                                context.push('/followers/$userId'),
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
                                    'Seguindo',
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

                // ==============================================================
                // BIO — Estilo Amino (texto ciano/azul claro se vazio)
                // ==============================================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: user.bio.isNotEmpty
                        ? Text(
                            user.bio,
                            style: TextStyle(
                              color: Colors.grey[400],
                              height: 1.5,
                              fontSize: 13,
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

                // ==============================================================
                // AMINO+ BANNER (se aplicável)
                // ==============================================================
                if (isAminoPlus)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
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
                                'A+',
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
                                'Membro Amino+',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ==============================================================
                // STREAK BAR (se for próprio perfil)
                // ==============================================================
                if (isOwnProfile)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: streakAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (streak) => StreakBar(
                          currentStreak:
                              streak['current_streak'] as int? ?? 0,
                          maxStreak: streak['max_streak'] as int? ?? 0,
                          checkInDays:
                              streak['total_check_ins'] as int? ?? 0,
                        ),
                      ),
                    ),
                  ),

                // ==============================================================
                // POSTS DO USUÁRIO
                // ==============================================================
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
                            onTap: () =>
                                context.push('/followers/$userId'),
                            child: Row(
                              children: [
                                Icon(Icons.people_outline_rounded,
                                    size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text('Seguidores',
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12)),
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
                              color: AppTheme.accentColor, strokeWidth: 2)),
                    ),
                  ),
                  error: (error, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Erro: $error',
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
                                Text('Nenhum post ainda',
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
            _optionTile(Icons.comment_rounded, 'Ver Mural', () {
              Navigator.pop(ctx);
              context.push('/user/$userId/wall');
            }),
            _optionTile(Icons.people_rounded, 'Seguidores', () {
              Navigator.pop(ctx);
              context.push('/user/$userId/followers');
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
