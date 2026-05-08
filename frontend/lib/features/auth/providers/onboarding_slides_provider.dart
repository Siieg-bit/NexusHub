import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_provider.dart';
import '../models/onboarding_slide.dart';
import '../services/onboarding_slide_service.dart';

final onboardingSlidesProvider = FutureProvider<List<OnboardingSlide>>((ref) async {
  final locale = ref.watch(localeProvider);
  final strings = ref.watch(stringsProvider);

  return OnboardingSlideService.fetchSlides(
    locale: locale.code,
    strings: strings,
  );
});
