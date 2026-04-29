import 'package:flutter/material.dart';
import 'package:amino_clone/config/app_theme.dart';
import 'package:amino_clone/core/utils/helpers.dart';
import 'package:amino_clone/core/utils/responsive.dart';

// =============================================================================
// LevelBadge — Badge de nível estilo "alça + label"
//
// Design: círculo colorido com "Lv" + número projeta levemente para a esquerda
// de uma pill cinza escura que exibe o título do nível (ex: "Mítico").
//
// Uso:
//   LevelBadge(level: 12)
//   LevelBadge(level: 8, size: LevelBadgeSize.small)
//   LevelBadge(level: 15, showTitle: false)  // só o círculo
// =============================================================================

enum LevelBadgeSize { small, medium, large }

class LevelBadge extends StatelessWidget {
  final int level;
  final LevelBadgeSize size;

  /// Se true, exibe a pill com o título do nível ao lado do círculo.
  /// Se false, exibe apenas o círculo colorido (útil em listas densas).
  final bool showTitle;

  const LevelBadge({
    super.key,
    required this.level,
    this.size = LevelBadgeSize.medium,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final levelColor = AppTheme.getLevelColor(level);
    final title = levelTitle(level);

    // Dimensões escaláveis por tamanho
    final double circleSize = switch (size) {
      LevelBadgeSize.small  => r.s(28),
      LevelBadgeSize.medium => r.s(34),
      LevelBadgeSize.large  => r.s(42),
    };
    final double pillHeight = switch (size) {
      LevelBadgeSize.small  => r.s(22),
      LevelBadgeSize.medium => r.s(26),
      LevelBadgeSize.large  => r.s(32),
    };
    final double lvFontSize = switch (size) {
      LevelBadgeSize.small  => r.fs(7),
      LevelBadgeSize.medium => r.fs(8),
      LevelBadgeSize.large  => r.fs(10),
    };
    final double numFontSize = switch (size) {
      LevelBadgeSize.small  => r.fs(11),
      LevelBadgeSize.medium => r.fs(13),
      LevelBadgeSize.large  => r.fs(16),
    };
    final double titleFontSize = switch (size) {
      LevelBadgeSize.small  => r.fs(10),
      LevelBadgeSize.medium => r.fs(12),
      LevelBadgeSize.large  => r.fs(14),
    };

    // Quanto o círculo projeta para fora da pill à esquerda
    final double overlap = circleSize * 0.35;
    // Padding direito da pill (para o texto ficar centrado visualmente)
    final double pillPaddingRight = r.s(10);
    // Padding esquerdo da pill (espaço após o círculo encaixado)
    final double pillPaddingLeft = circleSize - overlap + r.s(4);

    if (!showTitle) {
      return _buildCircle(
        levelColor: levelColor,
        circleSize: circleSize,
        lvFontSize: lvFontSize,
        numFontSize: numFontSize,
      );
    }

    return SizedBox(
      height: circleSize,
      child: Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: [
          // ── Pill cinza escura (fundo) ──────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(left: overlap),
            child: Container(
              height: pillHeight,
              padding: EdgeInsets.only(
                left: pillPaddingLeft,
                right: pillPaddingRight,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(pillHeight / 2),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.90),
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  height: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // ── Círculo colorido (projeta à esquerda) ─────────────────────────
          _buildCircle(
            levelColor: levelColor,
            circleSize: circleSize,
            lvFontSize: lvFontSize,
            numFontSize: numFontSize,
          ),
        ],
      ),
    );
  }

  Widget _buildCircle({
    required Color levelColor,
    required double circleSize,
    required double lvFontSize,
    required double numFontSize,
  }) {
    return Container(
      width: circleSize,
      height: circleSize,
      decoration: BoxDecoration(
        color: levelColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: levelColor.withValues(alpha: 0.55),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Lv',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: lvFontSize,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          Text(
            '$level',
            style: TextStyle(
              color: Colors.white,
              fontSize: numFontSize,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
