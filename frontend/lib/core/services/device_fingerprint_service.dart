import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import '../../core/l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Serviço de Device Fingerprinting — registra e atualiza dispositivos.
/// Baseado na tabela device_fingerprints do schema v5.
class DeviceFingerprintService {
  DeviceFingerprintService._();

  /// Registra ou atualiza o dispositivo atual no banco.
  /// Deve ser chamado após login bem-sucedido.
  static Future<void> registerDevice() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final deviceInfo = _collectDeviceInfo();
      final fingerprint = _generateFingerprint(deviceInfo);

      // Upsert: atualiza se já existe, cria se não
      await SupabaseService.table('device_fingerprints').upsert(
        {
          'user_id': userId,
          'fingerprint': fingerprint,
          'device_type': deviceInfo['device_type'],
          'device_name': deviceInfo['device_name'],
          'os': deviceInfo['os'],
          'browser': deviceInfo['browser'],
          'is_current': true,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,fingerprint',
      );
    } catch (e) {
      debugPrint('DeviceFingerprint: Erro ao registrar: $e');
    }
  }

  /// Atualiza o last_seen_at do dispositivo atual.
  /// Pode ser chamado periodicamente (ex: a cada abertura do app).
  static Future<void> updateLastSeen() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final fingerprint = _generateFingerprint(_collectDeviceInfo());

      await SupabaseService.table('device_fingerprints')
          .update({
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
            'is_current': true,
          })
          .eq('user_id', userId)
          .eq('fingerprint', fingerprint);
    } catch (e) {
      debugPrint('DeviceFingerprint: Erro ao atualizar: $e');
    }
  }

  /// Coleta informações do dispositivo atual.
  static Map<String, String> _collectDeviceInfo() {
    final s = getStrings();
    String deviceType;
    String deviceName;
    String os;
    String browser = '';

    if (kIsWeb) {
      final s = getStrings();
      deviceType = 'web';
      deviceName = s.webBrowser;
      os = s.web;
      browser = s.browser; // Em produção, usar package:web para detectar
    } else {
      try {
      final s = getStrings();
        if (Platform.isAndroid) {
      final s = getStrings();
          deviceType = 'android';
          deviceName = s.android;
          os = s.androidVersion;
        } else if (Platform.isIOS) {
          deviceType = 'ios';
          deviceName = 'iPhone/iPad';
          os = 'iOS ${Platform.operatingSystemVersion}';
        } else if (Platform.isMacOS) {
          deviceType = 'desktop';
          deviceName = 'macOS';
          os = 'macOS ${Platform.operatingSystemVersion}';
        } else if (Platform.isWindows) {
          deviceType = 'desktop';
          deviceName = s.windows;
          os = s.windowsVersion;
        } else if (Platform.isLinux) {
          deviceType = 'desktop';
          deviceName = s.linux;
          os = s.linuxVersion;
        } else {
          deviceType = 'unknown';
          deviceName = s.device;
          os = Platform.operatingSystem;
        }
      } catch (_) {
        deviceType = 'unknown';
        deviceName = s.device;
        os = s.unknown;
      }
    }

    return {
      'device_type': deviceType,
      'device_name': deviceName,
      'os': os,
      'browser': browser,
    };
  }

  /// Gera um fingerprint simples baseado nas informações do dispositivo.
  /// Em produção, usar package:device_info_plus para dados mais precisos.
  static String _generateFingerprint(Map<String, String> info) {
    final raw =
        '${info['device_type']}_${info['os']}_${info['browser']}_${info['device_name']}';
    // Simple hash
    var hash = 0;
    for (var i = 0; i < raw.length; i++) {
      hash = ((hash << 5) - hash) + raw.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    return 'fp_${hash.toRadixString(16)}';
  }
}
