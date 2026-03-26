import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Provider para leaderboard de uma comunidade.
final leaderboardProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, communityId) async {
  final result = await SupabaseService.rpc('get_community_leaderboard', params: {
    'p_community_id': communityId,
    'p_limit': 50,
  });

  if (result == null) return [];
  return (result as List).map((e) => e as Map<String, dynamic>).toList();
});

/// Tela de leaderboard/ranking de uma comunidade.
class LeaderboardScreen extends ConsumerWidget {
  final String communityId;

  const LeaderboardScreen({super.key, required this.communityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider(communityId));

    return Scaffold(
      appBar: AppBar(title: const Text('Ranking')),
      body: leaderboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (members) {
          if (members.isEmpty) {
            return const Center(
              child: Text('Nenhum membro no ranking ainda',
                  style: TextStyle(color: AppTheme.textSecondary)),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ============================================================
              // TOP 3 PODIUM
              // ============================================================
              if (members.length >= 3)
                SizedBox(
                  height: 220,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 2o lugar
                      _PodiumItem(
                        rank: 2,
                        data: members[1],
                        height: 140,
                        color: const Color(0xFFC0C0C0),
                      ),
                      const SizedBox(width: 8),
                      // 1o lugar
                      _PodiumItem(
                        rank: 1,
                        data: members[0],
                        height: 180,
                        color: const Color(0xFFFFD700),
                      ),
                      const SizedBox(width: 8),
                      // 3o lugar
                      _PodiumItem(
                        rank: 3,
                        data: members[2],
                        height: 110,
                        color: const Color(0xFFCD7F32),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // ============================================================
              // LISTA RESTANTE
              // ============================================================
              ...members.skip(3).map((member) => _LeaderboardTile(data: member)),
            ],
          );
        },
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> data;
  final double height;
  final Color color;

  const _PodiumItem({
    required this.rank,
    required this.data,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Avatar
          CircleAvatar(
            radius: rank == 1 ? 32 : 24,
            backgroundColor: color.withOpacity(0.3),
            backgroundImage: data['avatar_url'] != null
                ? CachedNetworkImageProvider(data['avatar_url'] as String)
                : null,
            child: data['avatar_url'] == null
                ? Text(
                    ((data['nickname'] as String?) ?? '?')[0].toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            data['nickname'] as String? ?? 'Usuário',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${data['community_reputation'] ?? 0} rep',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // Podium
          Container(
            height: height * 0.5,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: rank == 1 ? 24 : 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const _LeaderboardTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final rank = data['rank'] as num? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          // Avatar
          GestureDetector(
            onTap: () => context.push('/user/${data['user_id']}'),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
              backgroundImage: data['avatar_url'] != null
                  ? CachedNetworkImageProvider(data['avatar_url'] as String)
                  : null,
              child: data['avatar_url'] == null
                  ? Text(
                      ((data['nickname'] as String?) ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.primaryColor, fontSize: 14),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(data['nickname'] as String? ?? 'Usuário',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.getLevelColor(data['global_level'] as int? ?? 1)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Lv.${data['global_level'] ?? 1}',
                        style: TextStyle(
                          color: AppTheme.getLevelColor(data['global_level'] as int? ?? 1),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (data['role'] != null && data['role'] != 'member')
                  Text(
                    (data['role'] as String).toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          // Reputation
          Text(
            '${data['community_reputation'] ?? 0}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.warningColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, color: AppTheme.warningColor, size: 16),
        ],
      ),
    );
  }
}
