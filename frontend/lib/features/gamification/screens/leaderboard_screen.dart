import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/cosmetic_avatar.dart';

/// Provider para leaderboard de uma comunidade.
final leaderboardProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, communityId) async {
  final result =
      await SupabaseService.rpc('get_community_leaderboard', params: {
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
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Ranking',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: leaderboardAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (error, _) => Center(
          child: Text(
            'Erro: $error',
            style: const TextStyle(color: AppTheme.errorColor),
          ),
        ),
        data: (members) {
          if (members.isEmpty) {
            return Center(
              child: Text(
                'Nenhum membro no ranking ainda',
                style: TextStyle(color: Colors.grey[500]),
              ),
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
              // LISTA RESTANTE (rank = index + 1)
              // ============================================================
              ...members.asMap().entries.skip(3).map((entry) =>
                  _LeaderboardTile(data: entry.value, rank: entry.key + 1)),
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
    final rep = data['reputation'] as int? ?? 0;
    final lvl = data['level'] as int? ?? calculateLevel(rep);

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Avatar
          CosmeticAvatar(
            userId: data['user_id'] as String?,
            avatarUrl: data['icon_url'] as String?,
            size: rank == 1 ? 64 : 48,
          ),
          const SizedBox(height: 8),
          Text(
            data['nickname'] as String? ?? 'Usuário',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Level badge
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.getLevelColor(lvl).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Lv.$lvl ${levelTitle(lvl)}',
              style: TextStyle(
                color: AppTheme.getLevelColor(lvl),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${formatCount(rep)} rep',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          // Podium
          Container(
            height: height * 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
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
  final int rank;

  const _LeaderboardTile({required this.data, required this.rank});

  @override
  Widget build(BuildContext context) {
    final rep = data['reputation'] as int? ?? 0;
    final lvl = data['level'] as int? ?? calculateLevel(rep);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
          ),
          // Avatar
          CosmeticAvatar(
            userId: data['user_id'] as String?,
            avatarUrl: data['icon_url'] as String?,
            size: 48,
            onTap: () => context.push('/user/${data['user_id']}'),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['nickname'] as String? ?? 'Usuário',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.getLevelColor(lvl)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.getLevelColor(lvl)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Lv.$lvl ${levelTitle(lvl)}',
                        style: TextStyle(
                          color: AppTheme.getLevelColor(lvl),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (data['role'] != null && data['role'] != 'member') ...[
                  const SizedBox(height: 4),
                  Text(
                    (data['role'] as String).toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Reputation
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatCount(rep),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.warningColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.star_rounded,
                    color: AppTheme.warningColor,
                    size: 18,
                  ),
                ],
              ),
              Text(
                'REP',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
