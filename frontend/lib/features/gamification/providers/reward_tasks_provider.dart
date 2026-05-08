import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_provider.dart';
import '../models/reward_task.dart';
import '../services/reward_task_service.dart';

final rewardTasksProvider = FutureProvider<List<RewardTask>>((ref) async {
  final locale = ref.watch(localeProvider);
  final strings = ref.watch(stringsProvider);

  return RewardTaskService.fetchRewardTasks(
    locale: locale.code,
    strings: strings,
  );
});
