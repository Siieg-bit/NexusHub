import 'package:flutter/foundation.dart';

@immutable
class RewardTask {
  final String taskKey;
  final String sectionKey;
  final String sectionTitle;
  final String title;
  final String subtitle;
  final String rewardLabel;
  final String iconName;
  final String iconColorHex;
  final String actionType;
  final int sortOrder;
  final int schemaVersion;

  const RewardTask({
    required this.taskKey,
    required this.sectionKey,
    required this.sectionTitle,
    required this.title,
    required this.subtitle,
    required this.rewardLabel,
    required this.iconName,
    required this.iconColorHex,
    required this.actionType,
    required this.sortOrder,
    required this.schemaVersion,
  });

  bool get isRewardedAd => actionType == 'rewarded_ad';

  factory RewardTask.fromMap(Map<String, dynamic> map) {
    return RewardTask(
      taskKey: _string(map['task_key'], fallback: 'unknown'),
      sectionKey: _string(map['section_key'], fallback: 'general'),
      sectionTitle: _string(map['section_title']),
      title: _string(map['title']),
      subtitle: _string(map['subtitle']),
      rewardLabel: _string(map['reward_label']),
      iconName: _string(map['icon_name'], fallback: 'monetization_on'),
      iconColorHex: _string(map['icon_color_hex'], fallback: '#FF9800'),
      actionType: _string(map['action_type'], fallback: 'informational'),
      sortOrder: _int(map['sort_order'], fallback: 0),
      schemaVersion: _int(map['schema_version'], fallback: 1),
    );
  }

  static String _string(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static int _int(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
