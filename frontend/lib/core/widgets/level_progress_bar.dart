import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../utils/responsive.dart';
import '../utils/helpers.dart';
import '../l10n/app_strings.dart';

/// Barra de progresso de nível estilo Amino.
///
/// Exibe:
///   - Ícone circular com "LV" + número do nível
///   - Nome do nível atual
///   - Barra de progresso com "X/Y REP"
///   - Texto motivacional
///   - Link "Ver Todos os Rankings"
///
/// Ao clicar no badge de nível, chama [onLevelTap].
class LevelProgressBar extends StatelessWidget {
  final int reputation;
  final int level;
  final AppStrings s;
  final VoidCallback? onLevelTap;
  final VoidCallback? onViewAllRankings;

  const LevelProgressBar({
    super.key,
    required this.reputation,
    required this.level,
    required this.s,
    this.onLevelTap,
    this.onViewAllRankings,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final levelColor = AppTheme.getLevelColor(level);
    final title = levelTitleFromStrings(s, level);
    final progress = levelProgress(reputation);
    final currentThreshold = reputationForLevel(level);
    final nextThreshold = level >= maxLevel
        ? reputationForLevel(maxLevel)
        : reputationForNextLevel(level);
    final isMaxLevel = level >= maxLevel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Ícone de nível (clicável) ──
        GestureDetector(
          onTap: onLevelTap,
          child: _buildLevelIcon(r, levelColor),
        ),
        SizedBox(height: r.s(8)),

        // ── Nome do nível ──
        Text(
          title,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: r.fs(15),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: r.s(12)),

        // ── Barra de progresso ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.s(24)),
          child: _buildProgressBar(r, context, progress, reputation,
              currentThreshold, nextThreshold, isMaxLevel, levelColor),
        ),
        SizedBox(height: r.s(12)),

        // ── Texto motivacional ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.s(32)),
          child: Text(
            isMaxLevel ? s.levelMaxReached : s.beActiveMemberMsg,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: r.fs(12),
            ),
          ),
        ),
        SizedBox(height: r.s(8)),

        // ── Link "Ver Todos os Rankings" ──
        GestureDetector(
          onTap: onViewAllRankings,
          child: Text(
            s.viewAllRankings,
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: r.fs(13),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelIcon(Responsive r, Color levelColor) {
    return Container(
      width: r.s(64),
      height: r.s(64),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            levelColor,
            levelColor.withValues(alpha: 0.7),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: levelColor.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LV',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: r.fs(10),
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
            Text(
              '$level',
              style: TextStyle(
                color: Colors.white,
                fontSize: r.fs(22),
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(
    Responsive r,
    BuildContext context,
    double progress,
    int currentRep,
    int currentThreshold,
    int nextThreshold,
    bool isMaxLevel,
    Color levelColor,
  ) {
    // Progresso relativo ao nível atual: quanto falta dentro do intervalo do nível
    final relativeRep = (currentRep - currentThreshold).clamp(0, nextThreshold - currentThreshold);
    final relativeNext = (nextThreshold - currentThreshold).clamp(1, nextThreshold);
    return Container(
      height: r.s(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r.s(14)),
        border: Border.all(
          color: levelColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
        color: Colors.black.withValues(alpha: 0.3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r.s(13)),
        child: Stack(
          children: [
            // Barra de preenchimento
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      levelColor,
                      levelColor.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
            // Texto centralizado
            Center(
              child: Text(
                isMaxLevel
                    ? s.levelMaxReached
                    : s.repProgressLabel(relativeRep, relativeNext),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
