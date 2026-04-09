import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app_strings.dart';
import 'app_strings_pt.dart';
import 'app_strings_en.dart';
import 'package:flutter/foundation.dart';

/// Idiomas suportados pelo app.
enum AppLocale {
  pt('pt', 'Português (BR)', '🇧🇷'),
  en('en', 'English (US)', '🇺🇸');

  final String code;
  final String label;
  final String flag;
  const AppLocale(this.code, this.label, this.flag);

  /// Retorna as strings do idioma.
  AppStrings get strings {
    switch (this) {
      case AppLocale.pt:
        return const AppStringsPt();
      case AppLocale.en:
        return const AppStringsEn();
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

/// Helper estático para acessar strings em contextos sem ref (services, utils).
/// Lê o idioma salvo no Hive e retorna as strings correspondentes.
AppStrings getStrings() {
  try {
    final box = Hive.box<String>('settings');
    final code = box.get('locale');
    if (code != null) return AppLocale.fromCode(code).strings;
  } catch (_) {}
  return AppLocale.fromSystem().strings;
}
