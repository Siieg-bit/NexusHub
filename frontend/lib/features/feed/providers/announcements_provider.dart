import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_provider.dart';
import '../models/system_announcement.dart';
import '../services/announcement_service.dart';

final activeAnnouncementsProvider =
    FutureProvider<List<SystemAnnouncement>>((ref) async {
  final locale = ref.watch(localeProvider);

  return AnnouncementService.fetchActiveAnnouncements(
    locale: locale.code,
  );
});
