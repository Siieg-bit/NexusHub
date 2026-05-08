import 'package:flutter/foundation.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/reward_task.dart';

class RewardTaskService {
  RewardTaskService._();

  static const int supportedSchemaVersion = 1;

  static Future<List<RewardTask>> fetchRewardTasks({
    required String locale,
    required AppStrings strings,
  }) async {
    final fallback = fallbackRewardTasks(strings);

    if (!RemoteConfigService.isRemoteRewardTasksEnabled) {
      return fallback;
    }

    try {
      final response = await SupabaseService.rpc(
        'get_reward_tasks',
        params: {
          'p_locale': locale,
          'p_schema_version': supportedSchemaVersion,
        },
      );

      final rows = response is List ? response : const [];
      final tasks = rows
          .whereType<Map>()
          .map((row) => RewardTask.fromMap(Map<String, dynamic>.from(row)))
          .where((task) => task.schemaVersion <= supportedSchemaVersion)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      if (tasks.isEmpty) return fallback;
      return tasks;
    } catch (e) {
      debugPrint('[RewardTaskService] Falha ao carregar reward_tasks: $e');
      return fallback;
    }
  }

  static List<RewardTask> fallbackRewardTasks(AppStrings s) {
    return [
      RewardTask(
        taskKey: 'watch_rewarded_ad',
        sectionKey: 'watch_ads',
        sectionTitle: s.watchAdsAction,
        title: s.watchVideoAction,
        subtitle: '{watched}/{max} assistidos hoje',
        rewardLabel: '+{rewarded_coins_per_ad}',
        iconName: 'play_circle_filled',
        iconColorHex: '#E53935',
        actionType: 'rewarded_ad',
        sortOrder: 10,
        schemaVersion: supportedSchemaVersion,
      ),
      RewardTask(
        taskKey: 'daily_check_in',
        sectionKey: 'daily_activities',
        sectionTitle: s.dailyActivities,
        title: s.dailyCheckIn2,
        subtitle: s.checkInEveryDay,
        rewardLabel: '+5-25',
        iconName: 'calendar_today',
        iconColorHex: '#2196F3',
        actionType: 'informational',
        sortOrder: 20,
        schemaVersion: supportedSchemaVersion,
      ),
      RewardTask(
        taskKey: 'create_post',
        sectionKey: 'daily_activities',
        sectionTitle: s.dailyActivities,
        title: 'Criar um Post',
        subtitle: s.publishContentCommunity,
        rewardLabel: '+3',
        iconName: 'edit',
        iconColorHex: '#4CAF50',
        actionType: 'informational',
        sortOrder: 30,
        schemaVersion: supportedSchemaVersion,
      ),
      RewardTask(
        taskKey: 'comment_posts',
        sectionKey: 'daily_activities',
        sectionTitle: s.dailyActivities,
        title: 'Comentar em Posts',
        subtitle: s.joinDiscussions,
        rewardLabel: '+1',
        iconName: 'comment',
        iconColorHex: '#00BCD4',
        actionType: 'informational',
        sortOrder: 40,
        schemaVersion: supportedSchemaVersion,
      ),
      RewardTask(
        taskKey: 'answer_quiz',
        sectionKey: 'daily_activities',
        sectionTitle: s.dailyActivities,
        title: 'Responder Quiz',
        subtitle: s.getCommunityQuizzes,
        rewardLabel: '+2',
        iconName: 'quiz',
        iconColorHex: '#FF9800',
        actionType: 'informational',
        sortOrder: 50,
        schemaVersion: supportedSchemaVersion,
      ),
      RewardTask(
        taskKey: 'complete_achievements',
        sectionKey: 'achievements',
        sectionTitle: s.achievements,
        title: 'Completar Conquistas',
        subtitle: 'Desbloqueie badges e ganhe moedas',
        rewardLabel: '+10-100',
        iconName: 'emoji_events',
        iconColorHex: '#FF9800',
        actionType: 'informational',
        sortOrder: 60,
        schemaVersion: supportedSchemaVersion,
      ),
      RewardTask(
        taskKey: 'invite_friends',
        sectionKey: 'achievements',
        sectionTitle: s.achievements,
        title: 'Convidar Amigos',
        subtitle: 'Ganhe moedas quando amigos se cadastram',
        rewardLabel: '+50',
        iconName: 'person_add',
        iconColorHex: '#9C27B0',
        actionType: 'informational',
        sortOrder: 70,
        schemaVersion: supportedSchemaVersion,
      ),
      RewardTask(
        taskKey: 'level_up',
        sectionKey: 'achievements',
        sectionTitle: s.achievements,
        title: s.levelUpAction,
        subtitle: s.earnCoinsLevelUp,
        rewardLabel: '+20',
        iconName: 'trending_up',
        iconColorHex: '#2196F3',
        actionType: 'informational',
        sortOrder: 80,
        schemaVersion: supportedSchemaVersion,
      ),
    ];
  }
}
