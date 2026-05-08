import 'package:flutter/foundation.dart';

@immutable
class OnboardingSlide {
  final String slideKey;
  final String locale;
  final String title;
  final String body;
  final String iconName;
  final String iconColorHex;
  final List<String> gradientHex;
  final String imageAssetPath;
  final String variantKey;
  final int sortOrder;
  final int schemaVersion;

  const OnboardingSlide({
    required this.slideKey,
    required this.locale,
    required this.title,
    required this.body,
    required this.iconName,
    required this.iconColorHex,
    required this.gradientHex,
    required this.imageAssetPath,
    required this.variantKey,
    required this.sortOrder,
    required this.schemaVersion,
  });

  factory OnboardingSlide.fromMap(Map<String, dynamic> map) {
    return OnboardingSlide(
      slideKey: _string(map['slide_key'], fallback: 'unknown'),
      locale: _string(map['locale'], fallback: 'pt'),
      title: _string(map['title']),
      body: _string(map['body']),
      iconName: _string(map['icon_name'], fallback: 'auto_awesome'),
      iconColorHex: _string(map['icon_color_hex'], fallback: '#00E5FF'),
      gradientHex: _stringList(map['gradient_hex']),
      imageAssetPath: _string(map['image_asset_path']),
      variantKey: _string(map['variant_key'], fallback: 'default'),
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
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    final single = value.toString().trim();
    return single.isEmpty ? const [] : [single];
  }
}
