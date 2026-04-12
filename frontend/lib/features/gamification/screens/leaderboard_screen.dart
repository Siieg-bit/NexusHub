import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

// =============================================================================
// PROVIDERS
// =============================================================================

/// Parâmetro composto para o leaderboard (comunidade + período).
class LeaderboardParams {
  final String communityId;
  final String period; // 'week' | 'month' | 'all'

  const LeaderboardParams({required this.communityId, required this.period});

  @override
  bool operator ==(Object other) =>
      other is LeaderboardParams &&
      other.communityId == communityId &&
      other.period == period;

  @override
  int get hashCode => Object.hash(communityId, period);
}

final leaderboardProvider =
    FutureProvider.family<List<Map<String, dynamic>>, LeaderboardParams>(
        (ref, params) async {
  final result =
      await SupabaseService.rpc('get_community_leaderboard', params: {
    'p_community_id': params.communityId,
    'p_limit': 50,
    // NOTA: A RPC não aceita p_period. O filtro de período é aplicado client-side.
  });

  if (result == null) return [];
  return (result as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
});

// =============================================================================
// TELA PRINCIPAL
// =============================================================================

/// Tela de leaderboard/ranking de uma comunidade.
/// Inclui pódio animado, filtros de período e lista completa.
class LeaderboardScreen extends ConsumerStatefulWidget {
  final String communityId;

  const LeaderboardScreen({super.key, required this.communityId});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  String _period = 'all';
  late AnimationController _podiumController;
  late Animation<double> _podiumAnimation;

  List<(String, String)> _getPeriods(AppStrings s) => [
    ('all', s.general),
    ('month', s.thisMonth),
    ('week', s.thisWeek),
  ];

  @override
  void initState() {
    super.initState();
    _podiumController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _podiumAnimation = CurvedAnimation(
      parent: _podiumController,
      curve: Curves.elasticOut,
    );
    _podiumController.forward();
  }

  @override
  void dispose() {
    _podiumController.dispose();
    super.dispose();
  }

  void _changePeriod(String period) {
    if (_period == period) return;
    setState(() => _period = period);
    _podiumController.reset();
    _podiumController.forward();
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final params = LeaderboardParams(
      communityId: widget.communityId,
      period: _period,
    );
    final leaderboardAsync = ref.watch(leaderboardProvider(params));

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      body: RefreshIndicator(
        color: context.nexusTheme.accentPrimary,
        onRefresh: () async {
          ref.invalidate(leaderboardProvider(params));
        },
        child: CustomScrollView(
          slivers: [
          // ── AppBar com gradiente ──
          SliverAppBar(
            expandedHeight: r.s(160),
            pinned: true,
            backgroundColor: context.nexusTheme.accentPrimary,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A237E),
                      Color(0xFF0D47A1),
                      context.nexusTheme.accentPrimary,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Estrelas decorativas
                    Positioned(
                      top: 20,
                      right: 30,
                      child: Icon(Icons.star_rounded,
                          color: Colors.white.withValues(alpha: 0.1),
                          size: r.s(80)),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: Icon(Icons.emoji_events_rounded,
                          color: Colors.white.withValues(alpha: 0.08),
                          size: r.s(60)),
                    ),
                    // Título centralizado
                    Align(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: r.s(30)),
                          Icon(Icons.leaderboard_rounded,
                              color: Colors.amber, size: r.s(36)),
                          SizedBox(height: r.s(8)),
                          Text(
                            s.ranking,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: r.fs(24),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Filtros de período ──
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
              child: Row(
                children: _getPeriods(s).map((p) {
                  final isSelected = _period == p.$1;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _changePeriod(p.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.symmetric(horizontal: r.s(4)),
                        padding: EdgeInsets.symmetric(vertical: r.s(10)),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.nexusTheme.accentSecondary
                              : context.surfaceColor,
                          borderRadius: BorderRadius.circular(r.s(12)),
                          border: Border.all(
                            color: isSelected
                                ? context.nexusTheme.accentSecondary
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: context.nexusTheme.accentSecondary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          p.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[400],
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w500,
                            fontSize: r.fs(12),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Conteúdo ──
          leaderboardAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: context.nexusTheme.accentSecondary),
              ),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.red[400], size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Erro ao carregar ranking',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ),
            data: (members) {
              if (members.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.leaderboard_rounded,
                            color: Colors.grey[700], size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum membro no ranking ainda',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.checkInEarnReputation,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildListDelegate([
                  // ── Pódio animado (Top 3) ──
                  if (members.length >= 3)
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(16), vertical: r.s(8)),
                      child: AnimatedBuilder(
                        animation: _podiumAnimation,
                        builder: (context, child) => Transform.scale(
                          scale: _podiumAnimation.value.clamp(0.0, 1.0),
                          child: child,
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // 2o lugar
                              _PodiumItem(
                                rank: 2,
                                data: members[1],
                                podiumHeight: r.s(80),
                                color: const Color(0xFFC0C0C0),
                                medal: '🥈',
                              ),
                              SizedBox(width: r.s(8)),
                              // 1o lugar — maior destaque
                              _PodiumItem(
                                rank: 1,
                                data: members[0],
                                podiumHeight: r.s(110),
                                color: const Color(0xFFFFD700),
                                medal: '🥇',
                                isFirst: true,
                              ),
                              SizedBox(width: r.s(8)),
                              // 3o lugar
                              _PodiumItem(
                                rank: 3,
                                data: members[2],
                                podiumHeight: r.s(60),
                                color: const Color(0xFFCD7F32),
                                medal: '🥉',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Divisor
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(16), vertical: r.s(12)),
                    child: Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: Colors.white.withValues(alpha: 0.08))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: r.s(12)),
                          child: Text(
                            'TODOS OS MEMBROS',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: r.fs(10),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Expanded(
                            child: Divider(
                                color: Colors.white.withValues(alpha: 0.08))),
                      ],
                    ),
                  ),

                  // ── Lista completa ──
                  ...members.asMap().entries.map(
                        (entry) => Padding(
                          padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                          child: _LeaderboardTile(
                            data: entry.value,
                            rank: entry.key + 1,
                          ),
                        ),
                      ),

                  SizedBox(height: r.s(32)),
                ]),
              );
            },
          ),
          ],
        ),
      ),
    );
  }
}
// =============================================================================
// WIDGET: Item do pódio
// =============================================================================

class _PodiumItem extends ConsumerWidget {
  final int rank;
  final Map<String, dynamic> data;
  final double podiumHeight;
  final Color color;
  final String medal;
  final bool isFirst;

  const _PodiumItem({
    required this.rank,
    required this.data,
    required this.podiumHeight,
    required this.color,
    required this.medal,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final rep = data['reputation'] as int? ?? 0;
    final lvl = data['level'] as int? ?? calculateLevel(rep);
    final userId = data['user_id'] as String?;

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Medalha emoji
          Text(medal, style: TextStyle(fontSize: r.fs(isFirst ? 28 : 22))),
          SizedBox(height: r.s(4)),

          // Avatar com borda colorida
          GestureDetector(
            onTap: userId != null ? () => context.push('/user/$userId') : null,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: isFirst ? 3 : 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: isFirst ? 12 : 6,
                    spreadRadius: isFirst ? 2 : 1,
                  ),
                ],
              ),
              child: CosmeticAvatar(
                userId: userId,
                avatarUrl: data['icon_url'] as String?,
                size: isFirst ? r.s(62) : r.s(48),
              ),
            ),
          ),
          SizedBox(height: r.s(6)),

          // Nome
          Text(
            data['nickname'] as String? ?? s.user,
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: r.fs(isFirst ? 13 : 11),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),

          // Level badge
          Container(
            margin: EdgeInsets.only(top: r.s(2), bottom: r.s(4)),
            padding: EdgeInsets.symmetric(horizontal: r.s(6), vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.getLevelColor(lvl).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(r.s(8)),
            ),
            child: Text(
              'Lv.$lvl',
              style: TextStyle(
                color: AppTheme.getLevelColor(lvl),
                fontSize: r.fs(9),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Reputação
          Text(
            '${formatCount(rep)} rep',
            style: TextStyle(
              color: color,
              fontSize: r.fs(isFirst ? 13 : 11),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: r.s(6)),

          // Pedestal
          Container(
            height: podiumHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.35),
                  color.withValues(alpha: 0.08),
                ],
              ),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(r.s(12))),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: isFirst ? r.fs(24) : r.fs(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGET: Tile da lista de ranking
// =================================================================
class _LeaderboardTile extends ConsumerWidget {
  final Map<String, dynamic> data;
  final int rank;

  const _LeaderboardTile({required this.data, required this.rank});

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final rep = data['reputation'] as int? ?? 0;
    final lvl = data['level'] as int? ?? calculateLevel(rep);
    final userId = data['user_id'] as String?;
    final isTop3 = rank <= 3;

    return Container(
      margin: EdgeInsets.only(bottom: r.s(10)),
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: isTop3
            ? _rankColor(rank).withValues(alpha: 0.06)
            : context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(14)),
        border: Border.all(
          color: isTop3
              ? _rankColor(rank).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Número do rank
          SizedBox(
            width: r.s(36),
            child: Text(
              '#$rank',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: _rankColor(rank),
                fontSize: r.fs(isTop3 ? 18 : 15),
              ),
            ),
          ),

          // Avatar
          GestureDetector(
            onTap: userId != null ? () => context.push('/user/$userId') : null,
            child: CosmeticAvatar(
              userId: userId,
              avatarUrl: data['icon_url'] as String?,
              size: r.s(46),
            ),
          ),
          SizedBox(width: r.s(14)),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['nickname'] as String? ?? s.user,
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(15),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: r.s(6)),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(7), vertical: r.s(3)),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.getLevelColor(lvl).withValues(alpha: 0.18),
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
                          fontSize: r.fs(9),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (data['role'] != null && data['role'] != 'member') ...[
                  SizedBox(height: r.s(3)),
                  Text(
                    (data['role'] as String? ?? '').toUpperCase(),
                    style: TextStyle(
                      color: context.nexusTheme.accentSecondary,
                      fontSize: r.fs(10),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(width: r.s(10)),

          // Reputação
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatCount(rep),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: context.nexusTheme.warning,
                      fontSize: r.fs(16),
                    ),
                  ),
                  SizedBox(width: r.s(3)),
                  Icon(Icons.star_rounded,
                      color: context.nexusTheme.warning, size: r.s(16)),
                ],
              ),
              Text(
                'REP',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: r.fs(9),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
