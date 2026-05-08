import 'package:flutter/foundation.dart';

@immutable
class SystemAnnouncement {
  const SystemAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.severity,
    required this.placement,
    required this.dismissible,
    required this.sortOrder,
    required this.schemaVersion,
    this.imageUrl,
    this.ctaText,
    this.ctaUrl,
    this.publishAt,
    this.expireAt,
    this.metadata = const {},
  });

  final String id;
  final String title;
  final String body;
  final String severity;
  final String placement;
  final String? imageUrl;
  final String? ctaText;
  final String? ctaUrl;
  final bool dismissible;
  final int sortOrder;
  final int schemaVersion;
  final DateTime? publishAt;
  final DateTime? expireAt;
  final Map<String, dynamic> metadata;

  bool get hasCta => ctaText != null && ctaText!.trim().isNotEmpty;

  static SystemAnnouncement fromMap(Map<String, dynamic> map) {
    return SystemAnnouncement(
      id: _readString(map, 'id', fallback: 'system-announcement'),
      title: _readString(map, 'title'),
      body: _readString(map, 'body'),
      severity: _readString(map, 'severity', fallback: 'info'),
      placement: _readString(map, 'placement', fallback: 'global_feed'),
      imageUrl: _readNullableString(map, 'image_url'),
      ctaText: _readNullableString(map, 'cta_text'),
      ctaUrl: _readNullableString(map, 'cta_url'),
      dismissible: _readBool(map, 'dismissible', fallback: true),
      sortOrder: _readInt(map, 'sort_order', fallback: 100),
      schemaVersion: _readInt(map, 'schema_version', fallback: 1),
      publishAt: _readDateTime(map, 'publish_at'),
      expireAt: _readDateTime(map, 'expire_at'),
      metadata: _readMap(map, 'metadata'),
    );
  }

  static String _readString(
    Map<String, dynamic> map,
    String key, {
    String fallback = '',
  }) {
    final value = map[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String? _readNullableString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool _readBool(
    Map<String, dynamic> map,
    String key, {
    required bool fallback,
  }) {
    final value = map[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return fallback;
  }

  static int _readInt(
    Map<String, dynamic> map,
    String key, {
    required int fallback,
  }) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime? _readDateTime(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static Map<String, dynamic> _readMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
}
