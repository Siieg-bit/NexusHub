import 'package:flutter/foundation.dart';

@immutable
class LevelDefinition {
  final int level;
  final String locale;
  final String title;
  final int reputationRequired;
  final String colorHex;
  final List<String> gradientHex;
  final int sortOrder;
  final int schemaVersion;

  const LevelDefinition({
    required this.level,
    required this.locale,
    required this.title,
    required this.reputationRequired,
    required this.colorHex,
    required this.gradientHex,
    required this.sortOrder,
    required this.schemaVersion,
  });

  factory LevelDefinition.fromMap(Map<String, dynamic> map) {
    return LevelDefinition(
      level: _int(map['level'], fallback: 1),
      locale: _string(map['locale'], fallback: 'pt'),
      title: _string(map['title']),
      reputationRequired: _int(map['reputation_required'], fallback: 0),
      colorHex: _string(map['color_hex'], fallback: '#636E72'),
      gradientHex: _stringList(map['gradient_hex']),
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

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }
}
