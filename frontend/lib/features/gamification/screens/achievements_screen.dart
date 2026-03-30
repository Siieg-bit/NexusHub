import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/checkin_heatmap.dart';
import '../../../core/utils/responsive.dart';

/// Conquistas / Achievements — Badges desbloqueáveis com progresso.
class AchievementsScreen extends StatefulWidget {
  final String? userId;
  const AchievementsScreen({super.key, this.userId});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allAchievements = [];
  Set<String> _unlockedIds = {};
  Map<String, int> _progressMap = {};

  // Dados do heatmap de check-in
  Map<String, int> _checkinData = {};
  int _totalCheckins = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = widget.userId ?? SupabaseService.currentUserId;
      if (userId == null) return;

      // Carregar todas as conquistas disponíveis
      final allRes = await SupabaseService.table('achievements')
          .select()
          .order('sort_order');
      _allAchievements = List<Map<String, dynamic>>.from(allRes as List? ?? []);

      // Carregar conquistas desbloqueadas pelo usuário
      final unlockedRes = await SupabaseService.table('user_achievements')
          .select('achievement_id, unlocked_at')
          .eq('user_id', userId);
      final unlocked = List<Map<String, dynamic>>.from(unlockedRes as List? ?? []);

      _unlockedIds = unlocked
          .map((u) => (u['achievement_id'] as String?) ?? '').toSet();
      _progressMap = {
        for (final u in unlocked)
          u['achievement_id'] as String: 100,
      };

      // Carregar dados de check-in para o heatmap
      await _loadCheckinHeatmap(userId);

      if (!mounted) return;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Carrega o histórico de check-ins para o heatmap.
  Future<void> _loadCheckinHeatmap(String userId) async {
    try {
      // Buscar check-ins dos últimos 12 meses
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      final checkins = await SupabaseService.table('daily_checkins')
          .select('checkin_date')
          .eq('user_id', userId)
          .gte('checkin_date', oneYearAgo.toIso8601String().split('T')[0])
          .order('checkin_date');

      final data = <String, int>{};
      int streak = 0;
      int maxStreak = 0;
      DateTime? lastDate;

      for (final row in List<Map<String, dynamic>>.from(checkins as List? ?? [])) {
        final dateStr = (row['checkin_date'] as String?) ?? '';
        data[dateStr] = 1; // Nível 1 para check-in simples

        // Calcular streaks
        final date = DateTime.parse(dateStr);
        if (lastDate != null) {
          final diff = date.difference(lastDate).inDays;
          if (diff == 1) {
            streak++;
            // Aumentar nível baseado na streak
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

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final unlocked =
        _allAchievements.where((a) => _unlockedIds.contains(a['id'])).toList();
    final locked =
        _allAchievements.where((a) => !_unlockedIds.contains(a['id'])).toList();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          'Conquistas',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _allAchievements.isEmpty
              ? Center(
                  child: Text(
                    'Nenhuma conquista disponível',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(r.s(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Heatmap de Check-in
                      CheckinHeatmap(
                        checkinData: _checkinData,
                        totalCheckins: _totalCheckins,
                        currentStreak: _currentStreak,
                        longestStreak: _longestStreak,
                      ),
                      SizedBox(height: r.s(24)),

                      // Stats
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(r.s(20)),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.warningColor,
                              AppTheme.warningColor.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(r.s(16)),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.warningColor.withValues(alpha: 0.3),
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
                                  'Conquistas desbloqueadas',
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

                      // Desbloqueadas
                      if (unlocked.isNotEmpty) ...[
                        Text(
                          'Desbloqueadas',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: r.fs(16),
                            color: context.textPrimary,
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

                      // Bloqueadas
                      if (locked.isNotEmpty) ...[
                        Text(
                          'Em progresso',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: r.fs(16),
                            color: context.textPrimary,
                          ),
                        ),
                        SizedBox(height: r.s(12)),
                        ...locked.map((a) => _AchievementTile(
                              achievement: a,
                              isUnlocked: false,
                              progress: _progressMap[a['id'] as String?] ?? 0,
                            )),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Map<String, dynamic> achievement;
  final bool isUnlocked;
  final int progress;

  const _AchievementTile({
    required this.achievement,
    required this.isUnlocked,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final name = achievement['name'] as String? ?? 'Conquista';
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
        rarityColor = Colors.grey[500]!;
    }

    return Container(
      margin: EdgeInsets.only(bottom: r.s(10)),
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(
          color: isUnlocked
              ? AppTheme.warningColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
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
                  ? AppTheme.warningColor.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: isUnlocked ? AppTheme.warningColor : Colors.grey[600],
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
                              ? context.textPrimary
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
                                AppTheme.primaryColor),
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
                    color: AppTheme.warningColor, size: r.s(16)),
                Text(
                  '+$reward',
                  style: TextStyle(
                    color: AppTheme.warningColor,
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
