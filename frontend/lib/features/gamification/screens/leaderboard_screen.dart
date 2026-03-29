import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/utils/responsive.dart';

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
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Ranking',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: IconThemeData(color: context.textPrimary),
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
            padding: EdgeInsets.all(r.s(16)),
            children: [
              // ============================================================
              // TOP 3 PODIUM
              // ============================================================
              if (members.length >= 3)
                SizedBox(
                  height: r.s(220),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 2o lugar
                      _PodiumItem(
                        rank: 2,
                        data: members[1],
                        height: r.s(140),
                        color: const Color(0xFFC0C0C0),
                      ),
                      SizedBox(width: r.s(8)),
                      // 1o lugar
                      _PodiumItem(
                        rank: 1,
                        data: members[0],
                        height: r.s(180),
                        color: const Color(0xFFFFD700),
                      ),
                      SizedBox(width: r.s(8)),
                      // 3o lugar
                      _PodiumItem(
                        rank: 3,
                        data: members[2],
                        height: r.s(110),
                        color: const Color(0xFFCD7F32),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: r.s(24)),

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
    final r = context.r;
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
          SizedBox(height: r.s(8)),
          Text(
            data['nickname'] as String? ?? 'Usuário',
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: r.fs(12),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Level badge
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: EdgeInsets.symmetric(horizontal: r.s(6), vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.getLevelColor(lvl).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(r.s(8)),
            ),
            child: Text(
              'Lv.$lvl ${levelTitle(lvl)}',
              style: TextStyle(
                color: AppTheme.getLevelColor(lvl),
                fontSize: r.fs(9),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${formatCount(rep)} rep',
            style: TextStyle(
              color: color,
              fontSize: r.fs(11),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: r.s(8)),
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
    final r = context.r;
    final rep = data['reputation'] as int? ?? 0;
    final lvl = data['level'] as int? ?? calculateLevel(rep);

    return Container(
      margin: EdgeInsets.only(bottom: r.s(12)),
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: r.s(32),
            child: Text(
              '#$rank',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.grey[500],
                fontSize: r.fs(16),
              ),
            ),
          ),
          // Avatar
          CosmeticAvatar(
            userId: data['user_id'] as String?,
            avatarUrl: data['icon_url'] as String?,
            size: r.s(48),
            onTap: () => context.push('/user/${data['user_id']}'),
          ),
          SizedBox(width: r.s(16)),
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
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(16),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: r.s(8)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.s(8),
                        vertical: r.s(4),
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.getLevelColor(lvl)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(r.s(20)),
                        border: Border.all(
                          color: AppTheme.getLevelColor(lvl)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Lv.$lvl ${levelTitle(lvl)}',
                        style: TextStyle(
                          color: AppTheme.getLevelColor(lvl),
                          fontSize: r.fs(10),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (data['role'] != null && data['role'] != 'member') ...[
                  SizedBox(height: r.s(4)),
                  Text(
                    (data['role'] as String).toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.accentColor,
                      fontSize: r.fs(11),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: r.s(12)),
          // Reputation
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatCount(rep),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.warningColor,
                      fontSize: r.fs(16),
                    ),
                  ),
                  SizedBox(width: r.s(4)),
                  Icon(
                    Icons.star_rounded,
                    color: AppTheme.warningColor,
                    size: r.s(18),
                  ),
                ],
              ),
              Text(
                'REP',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: r.fs(10),
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
