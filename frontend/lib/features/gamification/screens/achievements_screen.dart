import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/checkin_heatmap.dart';
import '../../../core/widgets/level_progress_bar.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

/// Conquistas / Achievements — Layout estilo Amino Apps.
///
/// Estrutura (de cima para baixo):
///   1. Badge de nível (LV) + nome do nível
///   2. Barra de progresso REP (X/Y REP)
///   3. Texto motivacional + "Ver Todos os Rankings"
///   4. Atividade de Check-In (heatmap)
///   5. Minhas Estatísticas (tempo online circular)
///   6. Conquistas desbloqueadas / Em progresso
class AchievementsScreen extends ConsumerStatefulWidget {
  final String? userId;
  final String? communityId;
  final String? communityBannerUrl;

  const AchievementsScreen({
    super.key,
    this.userId,
    this.communityId,
    this.communityBannerUrl,
  });

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allAchievements = [];
  Set<String> _unlockedIds = {};
  Map<String, int> _progressMap = {};
  List<Map<String, dynamic>> _newlyUnlocked = [];

  // Dados do heatmap de check-in
  Map<String, int> _checkinData = {};
  int _totalCheckins = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;

  // Dados de nível/reputação
  int _reputation = 0;
  int _level = 1;
  int _onlineMinutes = 0;
  String? _communityBannerUrl;

  @override
  void initState() {
    super.initState();
    _communityBannerUrl = widget.communityBannerUrl;
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = widget.userId ?? SupabaseService.currentUserId;
      final currentUserId = SupabaseService.currentUserId;
      if (userId == null) return;

      // Carregar dados de reputação/nível do membership
      await _loadLevelData(userId);

      // Validar e desbloquear conquistas automaticamente apenas
      // quando o usuário estiver visualizando o próprio perfil.
      if (currentUserId != null && userId == currentUserId) {
        try {
          final rpcRes =
              await SupabaseService.rpc('check_achievements', params: {
            'p_user_id': userId,
          });
          _newlyUnlocked =
              List<Map<String, dynamic>>.from(rpcRes as List? ?? []);
        } catch (_) {
          _newlyUnlocked = [];
        }
      } else {
        _newlyUnlocked = [];
      }

      // Carregar todas as conquistas disponíveis
      final allRes = await SupabaseService.table('achievements')
          .select()
          .order('sort_order');
      _allAchievements = List<Map<String, dynamic>>.from(allRes as List? ?? []);

      // Carregar conquistas desbloqueadas pelo usuário
      final unlockedRes = await SupabaseService.table('user_achievements')
          .select('achievement_id, unlocked_at')
          .eq('user_id', userId);
      final unlocked =
          List<Map<String, dynamic>>.from(unlockedRes as List? ?? []);

      _unlockedIds = unlocked
          .map((u) => (u['achievement_id'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      _progressMap = {
        for (final u in unlocked)
          if ((u['achievement_id'] as String?)?.isNotEmpty == true)
            u['achievement_id'] as String: 100,
      };

      // Carregar dados de check-in para o heatmap
      await _loadCheckinHeatmap(userId);

      // Carregar tempo online (últimas 24h)
      await _loadOnlineMinutes(userId);

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Carrega dados de nível e reputação do usuário.
  Future<void> _loadLevelData(String userId) async {
    try {
      // Tentar carregar do membership da comunidade
      if (widget.communityId != null) {
        final memberRes = await SupabaseService.table('community_members')
            .select('local_reputation, local_level')
            .eq('user_id', userId)
            .eq('community_id', widget.communityId!)
            .maybeSingle();
        if (memberRes != null) {
          _reputation = memberRes['local_reputation'] as int? ?? 0;
          _level = memberRes['local_level'] as int? ?? calculateLevel(_reputation);

          // Também carregar banner da comunidade se não foi passado
          if (_communityBannerUrl == null) {
            try {
              final comRes = await SupabaseService.table('communities')
                  .select('banner_url')
                  .eq('id', widget.communityId!)
                  .single();
              _communityBannerUrl = comRes['banner_url'] as String?;
            } catch (_) {}
          }
          return;
        }
      }

      // Sem communityId: nível/reputação são dados de comunidade, não globais.
      // Manter valores padrão (0/1) — o widget de conquistas pode ser exibido
      // sem dados de nível quando não há contexto de comunidade.
      _reputation = 0;
      _level = 1;
    } catch (_) {
      // Silenciar — dados de nível são opcionais
    }
  }

  /// Carrega o histórico de check-ins para o heatmap.
  Future<void> _loadCheckinHeatmap(String userId) async {
    try {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      final checkins = await SupabaseService.table('checkins')
          .select('checkin_date')
          .eq('user_id', userId)
          .gte('checkin_date', oneYearAgo.toIso8601String().split('T')[0])
          .order('checkin_date');

      final data = <String, int>{};
      int streak = 0;
      int maxStreak = 0;
      DateTime? lastDate;

      for (final row
          in List<Map<String, dynamic>>.from(checkins as List? ?? [])) {
        final dateStr = (row['checkin_date'] as String?) ?? '';
        data[dateStr] = 1;

        final date = DateTime.parse(dateStr);
        if (lastDate != null) {
          final diff = date.difference(lastDate).inDays;
          if (diff == 1) {
            streak++;
            if (streak >= 30) {
              data[dateStr] = 4;
            } else if (streak >= 14) {
              data[dateStr] = 3;
            } else if (streak >= 7) {
              data[dateStr] = 2;
            }
          } else {
            streak = 1;
          }
        } else {
          streak = 1;
        }
        if (streak > maxStreak) maxStreak = streak;
        lastDate = date;
      }

      _checkinData = data;
      _totalCheckins = data.length;
      _currentStreak = streak;
      _longestStreak = maxStreak;
    } catch (_) {
      // Silenciar erro — heatmap é opcional
    }
  }

  /// Carrega minutos online nas últimas 24h.
  Future<void> _loadOnlineMinutes(String userId) async {
    try {
      final res = await SupabaseService.table('profiles')
          .select('online_minutes_today')
          .eq('id', userId)
          .maybeSingle();
      _onlineMinutes = (res?['online_minutes_today'] as int?) ?? 0;
    } catch (_) {
      _onlineMinutes = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final unlocked =
        _allAchievements.where((a) => _unlockedIds.contains(a['id'])).toList();
    final locked =
        _allAchievements.where((a) => !_unlockedIds.contains(a['id'])).toList();

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        title: Text(
          s.achievements,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.nexusTheme.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: context.nexusTheme.accentPrimary),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: r.s(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: r.s(8)),

                  // ═══════════════════════════════════════════════════════
                  // 1. SEÇÃO DE NÍVEL (Badge + nome + barra REP + link)
                  // ═══════════════════════════════════════════════════════
                  LevelProgressBar(
                    reputation: _reputation,
                    level: _level,
                    s: s,
                    onLevelTap: () => context.push('/all-rankings', extra: {
                      'level': _level,
                      'reputation': _reputation,
                      'bannerUrl': _communityBannerUrl,
                    }),
                    onViewAllRankings: () =>
                        context.push('/all-rankings', extra: {
                      'level': _level,
                      'reputation': _reputation,
                      'bannerUrl': _communityBannerUrl,
                    }),
                  ),

                  SizedBox(height: r.s(28)),

                  // ═══════════════════════════════════════════════════════
                  // 2. ATIVIDADE DE CHECK-IN (heatmap)
                  // ═══════════════════════════════════════════════════════
                  Text(
                    s.checkInActivity,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: r.fs(16),
                      color: context.nexusTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: r.s(12)),
                  CheckinHeatmap(
                    checkinData: _checkinData,
                    totalCheckins: _totalCheckins,
                    currentStreak: _currentStreak,
                    longestStreak: _longestStreak,
                  ),

                  SizedBox(height: r.s(28)),

                  // ═══════════════════════════════════════════════════════
                  // 3. MINHAS ESTATÍSTICAS (tempo online circular)
                  // ═══════════════════════════════════════════════════════
                  Text(
                    s.myStatistics,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: r.fs(16),
                      color: context.nexusTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: r.s(4)),
                  Text(
                    s.statsUpdatedWithDelay,
                    style: TextStyle(
                      color: context.nexusTheme.textSecondary,
                      fontSize: r.fs(12),
                    ),
                  ),
                  SizedBox(height: r.s(16)),
                  _buildOnlineMinutesCircle(r, context),

                  SizedBox(height: r.s(28)),

                  // ═══════════════════════════════════════════════════════
                  // 4. NOVAS CONQUISTAS DESBLOQUEADAS (se houver)
                  // ═══════════════════════════════════════════════════════
                  if (_newlyUnlocked.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(r.s(16)),
                      decoration: BoxDecoration(
                        color: context.nexusTheme.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(r.s(16)),
                        border: Border.all(
                          color:
                              context.nexusTheme.success.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.emoji_events_rounded,
                                color: context.nexusTheme.success,
                                size: r.s(22),
                              ),
                              SizedBox(width: r.s(10)),
                              Expanded(
                                child: Text(
                                  s.newAchievementsUnlocked,
                                  style: TextStyle(
                                    color: context.nexusTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: r.fs(15),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: r.s(10)),
                          ..._newlyUnlocked.map(
                            (achievement) => Padding(
                              padding: EdgeInsets.only(bottom: r.s(6)),
                              child: Text(
                                '• ${achievement['achievement_name'] ?? s.achievements}'
                                '${((achievement['reward_coins'] as int?) ?? 0) > 0 ? ' · +${achievement['reward_coins']} coins' : ''}',
                                style: TextStyle(
                                  color: context.nexusTheme.textSecondary,
                                  fontSize: r.fs(13),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: r.s(24)),
                  ],

                  // ═══════════════════════════════════════════════════════
                  // 5. STATS CARD (X / Y conquistas)
                  // ═══════════════════════════════════════════════════════
                  if (_allAchievements.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(r.s(20)),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.nexusTheme.warning,
                            context.nexusTheme.warning.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(r.s(16)),
                        boxShadow: [
                          BoxShadow(
                            color:
                                context.nexusTheme.warning.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events_rounded,
                              color: Colors.white, size: r.s(36)),
                          SizedBox(width: r.s(12)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${unlocked.length} / ${_allAchievements.length}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r.fs(28),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                s.achievementsUnlocked,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: r.fs(13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: r.s(24)),
                  ],

                  // ═══════════════════════════════════════════════════════
                  // 6. CONQUISTAS DESBLOQUEADAS
                  // ═══════════════════════════════════════════════════════
                  if (unlocked.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        s.achievementsUnlocked,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: r.fs(16),
                          color: context.nexusTheme.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(height: r.s(12)),
                    ...unlocked.map((a) => _AchievementTile(
                          achievement: a,
                          isUnlocked: true,
                          progress: 100,
                        )),
                    SizedBox(height: r.s(24)),
                  ],

                  // ═══════════════════════════════════════════════════════
                  // 7. EM PROGRESSO
                  // ═══════════════════════════════════════════════════════
                  if (locked.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        s.inProgress,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: r.fs(16),
                          color: context.nexusTheme.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(height: r.s(12)),
                    ...locked.map((a) => _AchievementTile(
                          achievement: a,
                          isUnlocked: false,
                          progress: _progressMap[a['id'] as String?] ?? 0,
                        )),
                  ],

                  SizedBox(height: r.s(32)),
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGET: Círculo de minutos online (estilo Amino)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildOnlineMinutesCircle(Responsive r, BuildContext context) {
    final s = ref.watch(stringsProvider);
    // Normalizar para 0-1 (máximo 1440 min = 24h)
    final progress = (_onlineMinutes / 1440).clamp(0.0, 1.0);

    return SizedBox(
      width: r.s(160),
      height: r.s(160),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anel de fundo
          SizedBox(
            width: r.s(150),
            height: r.s(150),
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: r.s(8),
              color: Colors.white.withValues(alpha: 0.08),
              strokeCap: StrokeCap.round,
            ),
          ),
          // Anel de progresso
          SizedBox(
            width: r.s(150),
            height: r.s(150),
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: r.s(8),
              color: const Color(0xFF00E5A0), // Verde Amino
              backgroundColor: Colors.transparent,
              strokeCap: StrokeCap.round,
            ),
          ),
          // Texto central
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_onlineMinutes',
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(36),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                s.minutesLabel,
                style: TextStyle(
                  color: const Color(0xFF00E5A0),
                  fontSize: r.fs(14),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                s.last24Hours,
                style: TextStyle(
                  color: context.nexusTheme.textSecondary,
                  fontSize: r.fs(11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: Tile de conquista individual
// ═══════════════════════════════════════════════════════════════════════════════

class _AchievementTile extends ConsumerWidget {
  final Map<String, dynamic> achievement;
  final bool isUnlocked;
  final int progress;

  const _AchievementTile({
    required this.achievement,
    required this.isUnlocked,
    required this.progress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final name = achievement['name'] as String? ?? 'Achievement';
    final description = achievement['description'] as String? ?? '';
    final reward = achievement['coin_reward'] as int? ?? 0;
    final rarity = achievement['rarity'] as String? ?? 'common';

    Color rarityColor;
    switch (rarity) {
      case 'legendary':
        rarityColor = const Color(0xFFFFD700);
        break;
      case 'epic':
        rarityColor = const Color(0xFF9C27B0);
        break;
      case 'rare':
        rarityColor = const Color(0xFF2196F3);
        break;
      default:
        rarityColor = (Colors.grey[500] ?? Colors.grey);
    }

    return Container(
      margin: EdgeInsets.only(bottom: r.s(10)),
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(
          color: isUnlocked
              ? context.nexusTheme.warning.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: context.nexusTheme.warning.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          // Ícone
          Container(
            width: r.s(48),
            height: r.s(48),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? context.nexusTheme.warning.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: isUnlocked ? context.nexusTheme.warning : Colors.grey[600],
              size: r.s(24),
            ),
          ),
          SizedBox(width: r.s(12)),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(14),
                          color: isUnlocked
                              ? context.nexusTheme.textPrimary
                              : Colors.grey[500],
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(8), vertical: r.s(4)),
                      decoration: BoxDecoration(
                        color: rarityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(r.s(20)),
                      ),
                      child: Text(
                        rarity.toUpperCase(),
                        style: TextStyle(
                          color: rarityColor,
                          fontSize: r.fs(9),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.s(4)),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
                  maxLines: 2,
                ),
                if (!isUnlocked && progress > 0) ...[
                  SizedBox(height: r.s(8)),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(r.s(20)),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.05),
                            valueColor: const AlwaysStoppedAnimation(
                                context.nexusTheme.accentPrimary),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      SizedBox(width: r.s(8)),
                      Text(
                        '$progress%',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: r.fs(10),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (reward > 0) ...[
            SizedBox(width: r.s(8)),
            Column(
              children: [
                Icon(Icons.monetization_on_rounded,
                    color: context.nexusTheme.warning, size: r.s(16)),
                Text(
                  '+$reward',
                  style: TextStyle(
                    color: context.nexusTheme.warning,
                    fontSize: r.fs(10),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
