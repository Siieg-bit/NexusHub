import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_config_service.dart';
import 'supabase_service.dart';

// =============================================================================
// OtaTranslationService — Traduções dinâmicas com fallback local
//
// Busca traduções da tabela `app_translations` via RPC `get_app_translations`
// e mantém cache local em SharedPreferences. As classes AppStrings* continuam
// sendo a fonte de fallback: se o banco/cache não tiver uma chave, o texto
// hardcoded atual é usado normalmente.
// =============================================================================

const _kTranslationsCacheKey = 'nexushub_ota_translations_v1';
const _kTranslationFetchTimeout = Duration(seconds: 6);
const _kSupportedTranslationLocales = <String>[
  'pt',
  'en',
  'ar',
  'de',
  'es',
  'fr',
  'it',
  'ja',
  'ko',
  'ru',
];

class OtaTranslationService {
  OtaTranslationService._();

  static final Map<String, Map<String, String>> _cache = {};
  static bool _initialized = false;

  /// Inicializa o serviço carregando traduções remotas e salvando cache local.
  ///
  /// Nunca lança exceção. Se a rede ou Supabase falharem, usa o último cache
  /// local conhecido; se não houver cache, todos os getters continuam retornando
  /// seus fallbacks locais.
  static Future<void> initialize({
    String? initialLocale,
    List<String>? locales,
    bool preloadRemainingLocales = true,
  }) async {
    if (_initialized) return;

    if (!RemoteConfigService.isOtaTranslationsEnabled) {
      _cache.clear();
      _initialized = true;
      debugPrint('[OtaTranslations] ⏸️ Desabilitado por Remote Config');
      return;
    }

    final targetLocales =
        _normalizeLocaleList(locales ?? _kSupportedTranslationLocales);
    if (targetLocales.isEmpty) {
      _initialized = true;
      return;
    }

    final preferredLocale = _resolvePreferredLocale(initialLocale, targetLocales);

    try {
      // Carrega primeiro o último cache local conhecido. Isso mantém fallback
      // offline imediato sem aguardar todos os idiomas remotos no boot.
      await _loadLocalFallback();

      // Busca síncrona apenas do idioma ativo. O boot não fica preso ao download
      // paralelo dos demais locales, reduzindo latência de inicialização.
      final primaryEntry = await _fetchLocaleTranslations(preferredLocale);
      if (primaryEntry != null && primaryEntry.value.isNotEmpty) {
        _cache[primaryEntry.key] = primaryEntry.value;
        await _saveToLocalCache(_cache);
        debugPrint(
          '[OtaTranslations] ✅ ${primaryEntry.value.length} traduções carregadas para ${primaryEntry.key}',
        );
      }

      _initialized = true;

      if (preloadRemainingLocales) {
        final remainingLocales = targetLocales
            .where((locale) => locale != preferredLocale)
            .toList(growable: false);
        if (remainingLocales.isNotEmpty) {
          unawaited(_preloadLocalesInBackground(remainingLocales));
        }
      }
    } catch (e) {
      debugPrint('[OtaTranslations] ⚠️ Falha ao inicializar traduções OTA: $e');
      await _loadLocalFallback();
      _initialized = true;
    }
  }

  /// Recarrega traduções remotas. Útil após atualizações via painel admin.
  static Future<void> refresh({
    String? initialLocale,
    List<String>? locales,
    bool preloadRemainingLocales = true,
  }) async {
    _initialized = false;
    await initialize(
      initialLocale: initialLocale,
      locales: locales,
      preloadRemainingLocales: preloadRemainingLocales,
    );
  }

  /// Retorna a tradução remota para [locale]/[key] quando houver valor ativo.
  /// Caso contrário, retorna [fallback] sem alterar o comportamento atual.
  static String translate(String locale, String key, String fallback) {
    final value = _cache[locale]?[key];
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  static List<String> _normalizeLocaleList(Iterable<String> locales) {
    final normalized = <String>[];
    for (final locale in locales) {
      final code = locale.trim().toLowerCase();
      if (code.isEmpty || normalized.contains(code)) continue;
      if (_kSupportedTranslationLocales.contains(code)) {
        normalized.add(code);
      }
    }
    return normalized;
  }

  static String _resolvePreferredLocale(
    String? initialLocale,
    List<String> targetLocales,
  ) {
    final normalized = initialLocale?.trim().toLowerCase();
    if (normalized != null && targetLocales.contains(normalized)) {
      return normalized;
    }
    return targetLocales.first;
  }

  static Future<void> _preloadLocalesInBackground(List<String> locales) async {
    try {
      final entries = await Future.wait(
        locales.map(_fetchLocaleTranslations),
        eagerError: false,
      );
      var changed = false;
      for (final entry in entries) {
        if (entry != null && entry.value.isNotEmpty) {
          _cache[entry.key] = entry.value;
          changed = true;
        }
      }
      if (changed) {
        await _saveToLocalCache(_cache);
        debugPrint(
          '[OtaTranslations] ✅ ${_totalKeys(_cache)} traduções disponíveis após prefetch',
        );
      }
    } catch (e) {
      debugPrint('[OtaTranslations] ⚠️ Prefetch em background falhou: $e');
    }
  }

  static Future<MapEntry<String, Map<String, String>>?> _fetchLocaleTranslations(
    String locale,
  ) async {
    try {
      final result = await SupabaseService.client
          .rpc(
            'get_app_translations',
            params: {'p_locale': locale},
          )
          .timeout(_kTranslationFetchTimeout);
      return MapEntry(locale, _normalizeTranslationMap(result));
    } catch (e) {
      debugPrint('[OtaTranslations] ⚠️ Falha ao buscar locale $locale: $e');
      return null;
    }
  }

  static Map<String, String> _normalizeTranslationMap(dynamic raw) {
    if (raw == null) return {};
    try {
      final map = raw is Map ? raw : jsonDecode(raw.toString()) as Map;
      return map.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      )..removeWhere((_, value) => value.isEmpty);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _loadLocalFallback() async {
    final local = await _loadFromLocalCache();
    if (local.isNotEmpty) {
      _cache
        ..clear()
        ..addAll(local);
      debugPrint('[OtaTranslations] ✅ ${_totalKeys(_cache)} traduções carregadas do cache local');
    } else {
      debugPrint('[OtaTranslations] ⚠️ Sem cache local; usando fallbacks do APK');
    }
  }

  static Future<void> _saveToLocalCache(
    Map<String, Map<String, String>> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTranslationsCacheKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[OtaTranslations] Erro ao salvar cache local: $e');
    }
  }

  static Future<Map<String, Map<String, String>>> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTranslationsCacheKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw) as Map;
      return decoded.map(
        (locale, values) => MapEntry(
          locale.toString(),
          Map<String, String>.from((values as Map).map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )),
        ),
      );
    } catch (e) {
      debugPrint('[OtaTranslations] Erro ao carregar cache local: $e');
      return {};
    }
  }

  static int _totalKeys(Map<String, Map<String, String>> data) =>
      data.values.fold<int>(0, (total, localeMap) => total + localeMap.length);
}
