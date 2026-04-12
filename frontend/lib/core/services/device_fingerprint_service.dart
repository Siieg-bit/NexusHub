import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Serviço de Device Fingerprinting — registra e atualiza dispositivos.
/// Tabela: device_fingerprints (id, user_id, device_id, device_model, os_version, app_version,
///         ip_address, is_banned, banned_reason, first_seen_at, last_seen_at)
class DeviceFingerprintService {
  DeviceFingerprintService._();

  /// Registra ou atualiza o dispositivo atual no banco.
  /// Deve ser chamado após login bem-sucedido.
  static Future<void> registerDevice() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final info = _collectDeviceInfo();
      final deviceId = _generateDeviceId(info);
      final now = DateTime.now().toUtc().toIso8601String();

      await SupabaseService.table('device_fingerprints').upsert(
        {
          'user_id': userId,
          'device_id': deviceId,
          'device_model': info['device_model'],
          'os_version': info['os_version'],
          'app_version': info['app_version'],
          'last_seen_at': now,
        },
        onConflict: 'user_id,device_id',
      );
    } catch (e) {
      debugPrint('DeviceFingerprint: Erro ao registrar: $e');
    }
  }

  /// Atualiza o last_seen_at do dispositivo atual.
  static Future<void> updateLastSeen() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final deviceId = _generateDeviceId(_collectDeviceInfo());

      await SupabaseService.table('device_fingerprints')
          .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', userId)
          .eq('device_id', deviceId);
    } catch (e) {
      debugPrint('DeviceFingerprint: Erro ao atualizar: $e');
    }
  }

  static Map<String, String> _collectDeviceInfo() {
    String deviceModel;
    String osVersion;
    const String appVersion = '1.0.0';

    if (kIsWeb) {
      deviceModel = 'Web Browser';
      osVersion = 'web';
    } else {
      try {
        if (Platform.isAndroid) {
          deviceModel = 'Android Device';
          osVersion = 'Android ${Platform.operatingSystemVersion}';
        } else if (Platform.isIOS) {
          deviceModel = 'iPhone/iPad';
          osVersion = 'iOS ${Platform.operatingSystemVersion}';
        } else if (Platform.isMacOS) {
          deviceModel = 'macOS';
          osVersion = 'macOS ${Platform.operatingSystemVersion}';
        } else if (Platform.isWindows) {
          deviceModel = 'Windows PC';
          osVersion = 'Windows ${Platform.operatingSystemVersion}';
        } else if (Platform.isLinux) {
          deviceModel = 'Linux PC';
          osVersion = 'Linux ${Platform.operatingSystemVersion}';
        } else {
          deviceModel = 'Unknown Device';
          osVersion = Platform.operatingSystem;
        }
      } catch (_) {
        deviceModel = 'Unknown Device';
        osVersion = 'unknown';
      }
    }

    return {
      'device_model': deviceModel,
      'os_version': osVersion,
      'app_version': appVersion,
    };
  }

  static String _generateDeviceId(Map<String, String> info) {
    final raw = '${info['device_model']}_${info['os_version']}';
    var hash = 0;
    for (var i = 0; i < raw.length; i++) {
      hash = ((hash << 5) - hash) + raw.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    return 'dev_${hash.toRadixString(16)}';
  }
}
