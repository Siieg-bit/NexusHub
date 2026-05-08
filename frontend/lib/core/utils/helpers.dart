import 'package:flutter/material.dart';
import '../l10n/locale_provider.dart';
import '../l10n/app_strings.dart';
import '../services/level_definition_service.dart';

/// Utilitários e helpers do aplicativo.

// =============================================================================
// SISTEMA DE NÍVEIS / REPUTAÇÃO
// =============================================================================
// Nível 1 a 20. Baseado em reputação acumulada.
// Máximo 500 reputação por dia.
// Nível 20 requer 365.000 rep (~2 anos a 500/dia).
//
// Curva progressiva: primeiros níveis rápidos, últimos muito lentos.
// Fórmula: repForLevel(n) = floor(365000 * ((n-1)/19)^1.8)
// Arredondado para números bonitos.
// =============================================================================

/// Retorna a tabela de thresholds de nível da fonte central server-driven.
///
/// A fonte primária é `LevelDefinitionService`, inicializada no boot a partir da
/// RPC `get_level_definitions`. Se o serviço remoto estiver desabilitado, sem
/// rede ou ainda não inicializado, ele mantém fallback local equivalente ao APK.
List<int> get levelThresholds => LevelDefinitionService.thresholds;

/// Nível máximo do sistema.
const int maxLevel = 20;

/// Máximo de reputação que pode ser ganha por dia.
int get maxDailyReputation =>
    RemoteConfigService.getInt('gamification.max_daily_rep', fallback: 500);

/// Reputação ganha por cada tipo de ação.
/// Carregada do RemoteConfigService com fallbacks hardcoded.
class ReputationRewards {
  static int get checkIn        => RemoteConfigService.getInt('gamification.rep_per_checkin',  fallback: 10);
  static int get createPost     => RemoteConfigService.getInt('gamification.rep_per_post',      fallback: 15);
  static int get createPoll     => RemoteConfigService.getInt('gamification.rep_per_post',      fallback: 10);
  static int get commentOnPost  => RemoteConfigService.getInt('gamification.rep_per_comment',   fallback: 3);
  static int get receiveLikeOnPost    => RemoteConfigService.getInt('gamification.rep_per_like', fallback: 2);
  static int get receiveLikeOnComment => RemoteConfigService.getInt('gamification.rep_per_like', fallback: 1);
  static int get wallComment    => RemoteConfigService.getInt('gamification.rep_per_wall',       fallback: 2);
  static int get joinPublicChat => 2; // não tem config separada ainda
  static int get sendChatMessage => RemoteConfigService.getInt('gamification.rep_per_chat_msg', fallback: 1);
  static int get followUser     => RemoteConfigService.getInt('gamification.rep_per_follow',    fallback: 1);
  static int get completeQuiz   => RemoteConfigService.getInt('gamification.rep_per_quiz',      fallback: 5);
  static int get streakBonus7Days  => RemoteConfigService.getInt('gamification.rep_streak_7',   fallback: 50);
  static int get streakBonus30Days => RemoteConfigService.getInt('gamification.rep_streak_30',  fallback: 200);
}

/// Calcular nível baseado em reputação acumulada.
/// Retorna nível de 1 a 20.
int calculateLevel(int reputation) {
  if (reputation <= 0) return 1;
  for (int i = maxLevel - 1; i >= 0; i--) {
    if (reputation >= levelThresholds[i]) {
      return i + 1; // +1 porque index 0 = nível 1
    }
  }
  return 1;
}

/// Reputação necessária para alcançar um determinado nível.
int reputationForLevel(int level) {
  final clamped = level.clamp(1, maxLevel);
  return levelThresholds[clamped - 1];
}

/// Reputação necessária para o próximo nível.
/// Se já for nível 20, retorna o threshold do nível 20.
int reputationForNextLevel(int currentLevel) {
  if (currentLevel >= maxLevel) return levelThresholds[maxLevel - 1];
  return levelThresholds[currentLevel]; // index = currentLevel (próximo)
}

/// Calcular progresso percentual para o próximo nível (0.0 a 1.0).
double levelProgress(int reputation) {
  final currentLevel = calculateLevel(reputation);
  if (currentLevel >= maxLevel) return 1.0;

  final currentThreshold = levelThresholds[currentLevel - 1];
  final nextThreshold = levelThresholds[currentLevel];
  final range = nextThreshold - currentThreshold;
  if (range <= 0) return 1.0;

  final progress = (reputation - currentThreshold) / range;
  return progress.clamp(0.0, 1.0);
}

/// Reputação restante para o próximo nível.
int reputationToNextLevel(int reputation) {
  final currentLevel = calculateLevel(reputation);
  if (currentLevel >= maxLevel) return 0;
  return levelThresholds[currentLevel] - reputation;
}

/// Calcular quantos dias faltam para o próximo nível (assumindo 500/dia).
int daysToNextLevel(int reputation) {
  final remaining = reputationToNextLevel(reputation);
  if (remaining <= 0) return 0;
  return (remaining / maxDailyReputation).ceil();
}

/// Calcular reputação com limite diário aplicado.
/// [earnedToday] = reputação já ganha hoje.
/// [amount] = reputação a ser adicionada.
/// Retorna a quantidade efetiva que pode ser adicionada.
int clampDailyReputation(int earnedToday, int amount) {
  if (earnedToday >= maxDailyReputation) return 0;
  final remaining = maxDailyReputation - earnedToday;
  return amount.clamp(0, remaining);
}

/// Nome do nível para exibição (títulos temáticos).
/// Usa strings i18n para tradução automática.
String levelTitle(int level) {
  return LevelDefinitionService.titleForLevel(level, strings: getStrings());
}

/// Retorna o título do nível usando AppStrings diretamente (para widgets com ref).
String levelTitleFromStrings(AppStrings s, int level) {
  return LevelDefinitionService.titleForLevel(level, strings: s);
}

// =============================================================================
// HELPERS GERAIS
// =============================================================================

/// Formatar contagem para exibição compacta.
String formatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return count.toString();
}

/// Validar email.
bool isValidEmail(String email) {
  return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
}

/// Validar senha (mínimo 8 caracteres, 1 maiúscula, 1 número).
String? validatePassword(String password) {
  if (password.length < 8) return 'Mínimo 8 caracteres';
  if (!password.contains(RegExp(r'[A-Z]'))) return 'Inclua uma letra maiúscula';
  if (!password.contains(RegExp(r'[0-9]'))) return 'Inclua um número';
  return null;
}

/// Truncar texto com reticências.
String truncate(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...';
}

/// Gerar cor a partir de string (para avatares sem imagem).
Color colorFromString(String input) {
  final hash = input.hashCode;
  return Color.fromARGB(
    255,
    (hash & 0xFF0000) >> 16,
    (hash & 0x00FF00) >> 8,
    hash & 0x0000FF,
  );
}
