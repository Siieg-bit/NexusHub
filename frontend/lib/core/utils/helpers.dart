import 'package:flutter/material.dart';
import '../l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Tabela fixa de reputação necessária para cada nível.
/// Index 0 = Nível 1, Index 19 = Nível 20.
const List<int> levelThresholds = [
  0, // Nível  1  —  0 rep (início)
  1800, // Nível  2  —  ~4 dias
  6300, // Nível  3  —  ~13 dias
  13000, // Nível  4  —  ~26 dias
  22000, // Nível  5  —  ~44 dias
  33000, // Nível  6  —  ~66 dias (2 meses)
  46000, // Nível  7  —  ~92 dias (3 meses)
  60500, // Nível  8  —  ~121 dias (4 meses)
  77000, // Nível  9  —  ~154 dias (5 meses)
  95000, // Nível 10  —  ~190 dias (6 meses)
  115000, // Nível 11  —  ~230 dias (8 meses)
  136500, // Nível 12  —  ~273 dias (9 meses)
  159500, // Nível 13  —  ~319 dias (11 meses)
  184500, // Nível 14  —  ~369 dias (1 ano)
  210500, // Nível 15  —  ~421 dias (1 ano 2 meses)
  238500, // Nível 16  —  ~477 dias (1 ano 4 meses)
  268000, // Nível 17  —  ~536 dias (1 ano 6 meses)
  299000, // Nível 18  —  ~598 dias (1 ano 8 meses)
  331000, // Nível 19  —  ~662 dias (1 ano 10 meses)
  365000, // Nível 20  —  ~730 dias (2 anos)
];

/// Nível máximo do sistema.
const int maxLevel = 20;

/// Máximo de reputação que pode ser ganha por dia.
const int maxDailyReputation = 500;

/// Reputação ganha por cada tipo de ação.
class ReputationRewards {
  /// Check-in diário.
  static const int checkIn = 10;

  /// Criar um post (blog, wiki, etc).
  static const int createPost = 15;

  /// Criar enquete ou quiz.
  static const int createPoll = 10;

  /// Comentar em um post.
  static const int commentOnPost = 3;

  /// Receber like em post.
  static const int receiveLikeOnPost = 2;

  /// Receber like em comentário.
  static const int receiveLikeOnComment = 1;

  /// Escrever no mural de alguém.
  static const int wallComment = 2;

  /// Entrar em um chat público.
  static const int joinPublicChat = 2;

  /// Enviar mensagem em chat.
  static const int sendChatMessage = 1;

  /// Seguir alguém.
  static const int followUser = 1;

  /// Completar um quiz.
  static const int completeQuiz = 5;

  /// Bonus de streak de 7 dias consecutivos.
  static const int streakBonus7Days = 50;

  /// Bonus de streak de 30 dias consecutivos.
  static const int streakBonus30Days = 200;
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
String levelTitle(int level) {
    final s = getStrings();
  const titles = [
    'Novato', // 1
    'Iniciante', // 2
    s.apprentice, // 3
    'Explorador', // 4
    s.adventurer, // 5
    'Guerreiro', // 6
    'Veterano', // 7
    'Especialista', // 8
    'Mestre', // 9
    'Grão-Mestre', // 10
    'Campeão', // 11
    'Herói', // 12
    'Guardião', // 13
    'Sentinela', // 14
    s.legendary, // 15
    s.mythical, // 16
    'Divino', // 17
    'Celestial', // 18
    'Transcendente', // 19
    'Supremo', // 20
  ];
  final idx = (level - 1).clamp(0, titles.length - 1);
  return titles[idx];
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
