import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app_strings.dart';
import 'app_strings_ota.dart';
import 'app_strings_pt.dart';
import 'app_strings_en.dart';
import 'app_strings_ar.dart';
import 'app_strings_de.dart';
import 'app_strings_fr.dart';
import 'app_strings_it.dart';
import 'app_strings_ja.dart';
import 'app_strings_ko.dart';
import 'app_strings_ru.dart';
import 'app_strings_es.dart';
import 'package:flutter/foundation.dart';

/// Idiomas suportados pelo app.
enum AppLocale {
  pt('pt', 'Português (BR)', '🇧🇷'),
  en('en', 'English (US)', '🇺🇸'),
  ar('ar', 'العربية', '🇸🇦'),
  de('de', 'Deutsch', '🇩🇪'),
  es('es', 'Español', '🇪🇸'),
  fr('fr', 'Français', '🇫🇷'),
  it('it', 'Italiano', '🇮🇹'),
  ja('ja', '日本語', '🇯🇵'),
  ko('ko', '한국어', '🇰🇷'),
  ru('ru', 'Русский', '🇷🇺');

  final String code;
  final String label;
  final String flag;
  const AppLocale(this.code, this.label, this.flag);

  /// Retorna as strings do idioma com overlay OTA e fallback local.
  AppStrings get strings {
    final fallback = _fallbackStrings;
    return OtaAppStrings(locale: code, fallback: fallback);
  }

  /// Retorna as strings locais empacotadas no APK.
  ///
  /// Mantido separado para que a camada OTA seja reversível e nunca remova o
  /// fallback offline do aplicativo.
  AppStrings get _fallbackStrings {
    switch (this) {
      case AppLocale.pt:
        return const AppStringsPt();
      case AppLocale.en:
        return const AppStringsEn();
      case AppLocale.ar:
        return const AppStringsAr();
      case AppLocale.de:
        return const AppStringsDe();
      case AppLocale.fr:
        return const AppStringsFr();
      case AppLocale.it:
        return const AppStringsIt();
      case AppLocale.ja:
        return const AppStringsJa();
      case AppLocale.ko:
        return const AppStringsKo();
      case AppLocale.ru:
        return const AppStringsRu();
      case AppLocale.es:
        return const AppStringsEs();
    }
  }

  /// Converte código de idioma para enum.
  static AppLocale fromCode(String code) {
    return AppLocale.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLocale.pt,
    );
  }

  /// Detecta o idioma do sistema.
  static AppLocale fromSystem() {
    final systemLocale = PlatformDispatcher.instance.locale;
    final code = systemLocale.languageCode;
    return AppLocale.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLocale.pt,
    );
  }
}

/// Notifier que gerencia o idioma atual do app.
class LocaleNotifier extends StateNotifier<AppLocale> {
  static const _boxName = 'settings';
  static const _key = 'locale';

  LocaleNotifier() : super(AppLocale.pt) {
    _loadSavedLocale();
  }

  void _loadSavedLocale() {
    try {
      final box = Hive.box<String>(_boxName);
      final saved = box.get(_key);
      if (saved != null) {
        state = AppLocale.fromCode(saved);
      } else {
        // Primeira vez: usar idioma do sistema
        state = AppLocale.fromSystem();
      }
    } catch (_) {
      // Se o box não existir ainda, usar padrão
      state = AppLocale.fromSystem();
    }
  }

  /// Altera o idioma do app e persiste a escolha.
  Future<void> setLocale(AppLocale locale) async {
    state = locale;
    try {
      final box = await Hive.openBox<String>(_boxName);
      await box.put(_key, locale.code);
    } catch (e) {
      debugPrint('[locale_provider] Erro: $e');
    }
  }
}

/// Provider do idioma atual.
final localeProvider = StateNotifierProvider<LocaleNotifier, AppLocale>((ref) {
  return LocaleNotifier();
});

/// Provider das strings traduzidas — usar em qualquer widget.
/// Exemplo: final s = ref.watch(stringsProvider);
///          Text(s.login)
final stringsProvider = Provider<AppStrings>((ref) {
  final locale = ref.watch(localeProvider);
  return locale.strings;
});

/// Resolve o idioma inicial antes da criação da árvore Riverpod.
///
/// Usado no boot para carregar primeiro as traduções OTA do locale realmente
/// ativo, sem precisar instanciar providers nem bloquear a UI baixando todos os
/// idiomas suportados.
Future<AppLocale> resolveInitialAppLocale() async {
  try {
    final box = await Hive.openBox<String>(LocaleNotifier._boxName);
    final saved = box.get(LocaleNotifier._key);
    if (saved != null) return AppLocale.fromCode(saved);
  } catch (e) {
    debugPrint('[locale_provider] Erro ao resolver locale inicial: $e');
  }
  return AppLocale.fromSystem();
}

/// Cache global das strings do idioma atual.
/// Atualizado pelo [localeProvider] via [updateGlobalStrings] sempre que o
/// idioma muda — garante que [getStrings()] retorne o idioma correto em
/// services, models e widgets sem ref, sem precisar de pull-to-refresh.
AppStrings _currentStrings = AppLocale.fromSystem().strings;

/// Atualiza o cache global de strings. Deve ser chamado sempre que o
/// [localeProvider] mudar (ver main.dart / _AppState).
void updateGlobalStrings(AppLocale locale) {
  _currentStrings = locale.strings;
}

/// Helper estático para acessar strings em contextos sem ref (services, utils).
/// Retorna o cache reativo — atualizado automaticamente quando o idioma muda.
AppStrings getStrings() => _currentStrings;
