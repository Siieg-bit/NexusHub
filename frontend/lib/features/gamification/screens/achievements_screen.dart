import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

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
      _allAchievements = List<Map<String, dynamic>>.from(allRes as List);

      // Carregar conquistas desbloqueadas pelo usuário
      final unlockedRes = await SupabaseService.table('user_achievements')
          .select('achievement_id, progress')
          .eq('user_id', userId);
      final unlocked = List<Map<String, dynamic>>.from(unlockedRes as List);

      _unlockedIds = unlocked
          .where((u) => (u['progress'] as int? ?? 0) >= 100)
          .map((u) => u['achievement_id'] as String)
          .toSet();
      _progressMap = {
        for (final u in unlocked)
          u['achievement_id'] as String: u['progress'] as int? ?? 0,
      };

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked =
        _allAchievements.where((a) => _unlockedIds.contains(a['id'])).toList();
    final locked =
        _allAchievements.where((a) => !_unlockedIds.contains(a['id'])).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conquistas',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allAchievements.isEmpty
              ? const Center(
                  child: Text('Nenhuma conquista disponível',
                      style: TextStyle(color: AppTheme.textSecondary)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.warningColor,
                              AppTheme.warningColor.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.emoji_events_rounded,
                                color: Colors.white, size: 36),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${unlocked.length} / ${_allAchievements.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text('Conquistas desbloqueadas',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Desbloqueadas
                      if (unlocked.isNotEmpty) ...[
                        const Text('Desbloqueadas',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        ...unlocked.map((a) => _AchievementTile(
                              achievement: a,
                              isUnlocked: true,
                              progress: 100,
                            )),
                        const SizedBox(height: 24),
                      ],

                      // Bloqueadas
                      if (locked.isNotEmpty) ...[
                        const Text('Em progresso',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        ...locked.map((a) => _AchievementTile(
                              achievement: a,
                              isUnlocked: false,
                              progress:
                                  _progressMap[a['id'] as String] ?? 0,
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
    final name = achievement['name'] as String? ?? 'Conquista';
    final description = achievement['description'] as String? ?? '';
    final iconName = achievement['icon'] as String? ?? 'emoji_events';
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
        rarityColor = AppTheme.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnlocked
            ? AppTheme.warningColor.withOpacity(0.06)
            : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: isUnlocked
            ? Border.all(color: AppTheme.warningColor.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          // Ícone
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? AppTheme.warningColor.withOpacity(0.15)
                  : AppTheme.dividerColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: isUnlocked ? AppTheme.warningColor : AppTheme.textHint,
              size: 24,
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
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isUnlocked
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: rarityColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rarity.toUpperCase(),
                        style: TextStyle(
                          color: rarityColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                      color: AppTheme.textHint, fontSize: 12),
                  maxLines: 2,
                ),
                if (!isUnlocked && progress > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            backgroundColor:
                                AppTheme.dividerColor.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation(
                                AppTheme.primaryColor),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$progress%',
                        style: const TextStyle(
                            color: AppTheme.textHint,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (reward > 0) ...[
            const SizedBox(width: 8),
            Column(
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: AppTheme.warningColor, size: 16),
                Text(
                  '+$reward',
                  style: const TextStyle(
                    color: AppTheme.warningColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
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
