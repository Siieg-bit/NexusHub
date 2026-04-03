import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chave para persistir o tema no SharedPreferences.
const _kThemeKey = 'nexushub_theme_mode';

/// Provider global de tema (Dark / Light / System).
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

/// Notifier que gerencia o tema do app com persistência local.
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark) {
    _loadFromPrefs();
  }

  /// Carrega o tema salvo do SharedPreferences.
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_kThemeKey);
      if (themeIndex != null &&
          themeIndex < ThemeMode.values.length &&
          mounted) {
        state = ThemeMode.values[themeIndex];
      }
    } catch (_) {
      // Manter dark como fallback
    }
  }

  /// Salva o tema no SharedPreferences.
  Future<void> _saveToPrefs(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kThemeKey, mode.index);
    } catch (_) {
      // Silenciar
    }
  }

  /// Alterna entre dark e light.
  void toggle() {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = newMode;
    _saveToPrefs(newMode);
  }

  /// Define um tema específico.
  void setTheme(ThemeMode mode) {
    state = mode;
    _saveToPrefs(mode);
  }

  /// Verifica se está em dark mode.
  bool get isDark => state == ThemeMode.dark;
}
