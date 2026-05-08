import 'package:flutter/foundation.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/onboarding_slide.dart';

class OnboardingSlideService {
  OnboardingSlideService._();

  static const int supportedSchemaVersion = 1;
  static const String defaultVariantKey = 'default';

  static Future<List<OnboardingSlide>> fetchSlides({
    required String locale,
    required AppStrings strings,
    String variantKey = defaultVariantKey,
  }) async {
    final fallback = fallbackSlides(locale: locale, strings: strings);

    if (!RemoteConfigService.isRemoteOnboardingSlidesEnabled) {
      return fallback;
    }

    try {
      final response = await SupabaseService.rpc(
        'get_onboarding_slides',
        params: {
          'p_locale': locale,
          'p_variant_key': variantKey,
          'p_schema_version': supportedSchemaVersion,
        },
      );

      final rows = response is List ? response : const [];
      final slides = rows
          .whereType<Map>()
          .map((row) => OnboardingSlide.fromMap(Map<String, dynamic>.from(row)))
          .where((slide) =>
              slide.schemaVersion <= supportedSchemaVersion &&
              slide.title.trim().isNotEmpty &&
              slide.body.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      if (_isValidSlideSet(slides)) return slides;
      return fallback;
    } catch (e) {
      debugPrint('[OnboardingSlideService] Falha ao carregar onboarding_slides: $e');
      return fallback;
    }
  }

  static bool _isValidSlideSet(List<OnboardingSlide> slides) {
    if (slides.length < 3) return false;
    final keys = <String>{};
    for (final slide in slides) {
      if (slide.slideKey.trim().isEmpty || slide.slideKey == 'unknown') return false;
      if (!keys.add(slide.slideKey)) return false;
    }
    return true;
  }

  static List<OnboardingSlide> fallbackSlides({
    required String locale,
    required AppStrings strings,
  }) {
    return [
      OnboardingSlide(
        slideKey: 'communities',
        locale: locale,
        title: strings.thousandsOfCommunities,
        body: 'Descubra espaços para cada fandom, jogo, história e interesse.',
        iconName: 'groups_rounded',
        iconColorHex: '#E8003A',
        gradientHex: const ['#E8003A', '#FF2D78'],
        imageAssetPath: '',
        variantKey: defaultVariantKey,
        sortOrder: 10,
        schemaVersion: supportedSchemaVersion,
      ),
      OnboardingSlide(
        slideKey: 'real_time_chat',
        locale: locale,
        title: strings.realTimeChat,
        body: 'Converse em tempo real com amigos, comunidades e salas públicas.',
        iconName: 'chat_bubble_rounded',
        iconColorHex: '#00E5FF',
        gradientHex: const ['#00E5FF', '#2979FF'],
        imageAssetPath: '',
        variantKey: defaultVariantKey,
        sortOrder: 20,
        schemaVersion: supportedSchemaVersion,
      ),
      OnboardingSlide(
        slideKey: 'customize_profile',
        locale: locale,
        title: strings.customizeProfile,
        body: 'Crie uma identidade única com níveis, conquistas, estética e RPG.',
        iconName: 'auto_awesome_rounded',
        iconColorHex: '#B84CFF',
        gradientHex: const ['#B84CFF', '#FF2D78'],
        imageAssetPath: '',
        variantKey: defaultVariantKey,
        sortOrder: 30,
        schemaVersion: supportedSchemaVersion,
      ),
    ];
  }
}
