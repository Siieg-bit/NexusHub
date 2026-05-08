import 'package:flutter/foundation.dart';

import '../l10n/app_strings.dart';
import '../models/level_definition.dart';
import 'remote_config_service.dart';
import 'supabase_service.dart';

class LevelDefinitionService {
  LevelDefinitionService._();

  static const int supportedSchemaVersion = 1;
  static const int fallbackMaxLevel = 20;

  static List<LevelDefinition> _cache = const [];
  static String? _cacheLocale;

  static Future<void> initialize({
    required String locale,
    required AppStrings strings,
  }) async {
    final fallback = fallbackLevelDefinitions(locale: locale, strings: strings);
    _cache = fallback;
    _cacheLocale = locale;

    if (!RemoteConfigService.isRemoteLevelDefinitionsEnabled) {
      return;
    }

    try {
      final response = await SupabaseService.rpc(
        'get_level_definitions',
        params: {
          'p_locale': locale,
          'p_schema_version': supportedSchemaVersion,
        },
      );

      final rows = response is List ? response : const [];
      final definitions = rows
          .whereType<Map>()
          .map((row) => LevelDefinition.fromMap(Map<String, dynamic>.from(row)))
          .where((definition) =>
              definition.schemaVersion <= supportedSchemaVersion &&
              definition.level >= 1)
          .toList()
        ..sort((a, b) => a.level.compareTo(b.level));

      if (_isValidDefinitionSet(definitions)) {
        _cache = definitions;
        _cacheLocale = locale;
      }
    } catch (e) {
      debugPrint('[LevelDefinitionService] Falha ao carregar level_definitions: $e');
      _cache = fallback;
      _cacheLocale = locale;
    }
  }

  static Future<void> refresh({
    required String locale,
    required AppStrings strings,
  }) async {
    _cache = const [];
    _cacheLocale = null;
    await initialize(locale: locale, strings: strings);
  }

  static List<LevelDefinition> get definitions => _cache.isNotEmpty
      ? List.unmodifiable(_cache)
      : fallbackLevelDefinitions(locale: 'pt', strings: null);

  static List<int> get thresholds {
    final source = definitions;
    return source.map((definition) => definition.reputationRequired).toList(growable: false);
  }

  static int get maxLevel => definitions.length;

  static String titleForLevel(int level, {AppStrings? strings}) {
    final definition = _definitionForLevel(level);
    if (definition != null && definition.title.trim().isNotEmpty) {
      return definition.title;
    }
    final fallbackIndex = (level - 1).clamp(0, fallbackMaxLevel - 1).toInt();
    return fallbackLevelDefinitions(locale: _cacheLocale ?? 'pt', strings: strings)
        .elementAt(fallbackIndex)
        .title;
  }

  static String colorHexForLevel(int level) {
    final definition = _definitionForLevel(level);
    return definition?.colorHex ?? _fallbackColorHexForLevel(level);
  }

  static LevelDefinition? _definitionForLevel(int level) {
    final clampedLevel = level.clamp(1, maxLevel).toInt();
    for (final definition in definitions) {
      if (definition.level == clampedLevel) return definition;
    }
    return null;
  }

  static bool _isValidDefinitionSet(List<LevelDefinition> definitions) {
    if (definitions.length < fallbackMaxLevel) return false;
    for (var i = 0; i < fallbackMaxLevel; i++) {
      if (definitions[i].level != i + 1) return false;
      if (definitions[i].reputationRequired < 0) return false;
      if (i > 0 &&
          definitions[i].reputationRequired < definitions[i - 1].reputationRequired) {
        return false;
      }
    }
    return true;
  }

  static List<LevelDefinition> fallbackLevelDefinitions({
    required String locale,
    AppStrings? strings,
  }) {
    final s = strings;
    final titles = [
      s?.levelTitleNovice ?? 'Novato',
      s?.levelTitleBeginner ?? 'Iniciante',
      s?.levelTitleApprentice ?? 'Aprendiz',
      s?.levelTitleExplorer ?? 'Explorador',
      s?.levelTitleWarrior ?? 'Guerreiro',
      s?.levelTitleVeteran ?? 'Veterano',
      s?.levelTitleSpecialist ?? 'Especialista',
      s?.levelTitleMaster ?? 'Mestre',
      s?.levelTitleGrandMaster ?? 'Grão-Mestre',
      s?.levelTitleChampion ?? 'Campeão',
      s?.levelTitleHero ?? 'Herói',
      s?.levelTitleGuardian ?? 'Guardião',
      s?.levelTitleSentinel ?? 'Sentinela',
      s?.levelTitleLegendary ?? 'Lendário',
      s?.levelTitleMythical ?? 'Mítico',
      s?.levelTitleDivine ?? 'Divino',
      s?.levelTitleCelestial ?? 'Celestial',
      s?.levelTitleTranscendent ?? 'Transcendente',
      s?.levelTitleSupreme ?? 'Supremo',
      s?.levelTitleUltimate ?? 'Supremo Final',
    ];

    const thresholds = [
      0,
      1800,
      6300,
      13000,
      22000,
      33000,
      46000,
      60500,
      77000,
      95000,
      115000,
      136500,
      159500,
      184500,
      210500,
      238500,
      268000,
      299000,
      331000,
      365000,
    ];

    return List<LevelDefinition>.generate(fallbackMaxLevel, (index) {
      final level = index + 1;
      return LevelDefinition(
        level: level,
        locale: locale,
        title: titles[index],
        reputationRequired: thresholds[index],
        colorHex: _fallbackColorHexForLevel(level),
        gradientHex: const [],
        sortOrder: level * 10,
        schemaVersion: supportedSchemaVersion,
      );
    }, growable: false);
  }

  static String _fallbackColorHexForLevel(int level) {
    if (level <= 2) return '#636E72';
    if (level <= 4) return '#2DBE60';
    if (level <= 6) return '#2979FF';
    if (level <= 8) return '#7C3AED';
    if (level <= 10) return '#E53935';
    if (level <= 14) return '#FF9800';
    if (level <= 17) return '#FF6B6B';
    if (level <= 19) return '#E040FB';
    return '#FFD700';
  }
}
