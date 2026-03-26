import 'package:flutter/material.dart';

/// Utilitários e helpers do aplicativo.

/// Formatar contagem para exibição compacta.
String formatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return count.toString();
}

/// Calcular nível baseado em XP.
int calculateLevel(int xp) {
  // Fórmula: nível = floor(sqrt(xp / 100)) + 1
  if (xp <= 0) return 1;
  final level = (xp / 100).sqrt().floor() + 1;
  return level.clamp(1, 99);
}

/// Calcular XP necessário para o próximo nível.
int xpForNextLevel(int currentLevel) {
  return (currentLevel * currentLevel) * 100;
}

/// Calcular progresso percentual para o próximo nível.
double levelProgress(int xp) {
  final currentLevel = calculateLevel(xp);
  final currentLevelXp = ((currentLevel - 1) * (currentLevel - 1)) * 100;
  final nextLevelXp = xpForNextLevel(currentLevel);
  final progress = (xp - currentLevelXp) / (nextLevelXp - currentLevelXp);
  return progress.clamp(0.0, 1.0);
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

/// Extensão para sqrt em int.
extension IntSqrt on double {
  int sqrt() {
    double x = this;
    double y = 1;
    while (x - y > 0.001) {
      x = (x + y) / 2;
      y = this / x;
    }
    return x.floor();
  }
}
