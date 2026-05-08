import 'package:flutter/foundation.dart';

import '../../../core/services/remote_config_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/system_announcement.dart';

class AnnouncementService {
  AnnouncementService._();

  static const int supportedSchemaVersion = 1;
  static const String defaultPlacement = 'global_feed';

  static Future<List<SystemAnnouncement>> fetchActiveAnnouncements({
    required String locale,
    String placement = defaultPlacement,
  }) async {
    if (!RemoteConfigService.isRemoteAnnouncementsEnabled) {
      return fallbackAnnouncements();
    }

    try {
      final response = await SupabaseService.rpc(
        'get_active_announcements_v2',
        params: {
          'p_locale': locale,
          'p_schema_version': supportedSchemaVersion,
          'p_placement': placement,
        },
      );

      final rows = response is List ? response : const [];
      final announcements = rows
          .whereType<Map>()
          .map(
            (row) => SystemAnnouncement.fromMap(
              Map<String, dynamic>.from(row),
            ),
          )
          .where((announcement) =>
              announcement.schemaVersion <= supportedSchemaVersion &&
              announcement.title.trim().isNotEmpty &&
              announcement.body.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      return announcements;
    } catch (e) {
      debugPrint(
        '[AnnouncementService] Falha ao carregar system_announcements: $e',
      );
      return fallbackAnnouncements();
    }
  }

  static List<SystemAnnouncement> fallbackAnnouncements() => const [];
}
