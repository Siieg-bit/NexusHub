import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/l10n/locale_provider.dart';

/// Tela "Todos os Rankings" — lista dos 20 níveis com banner da comunidade
/// ao fundo com opacidade, destaque do nível atual do usuário.
///
/// Baseado no design do Amino Apps (prints de referência).
class AllRankingsScreen extends ConsumerWidget {
  final int currentLevel;
  final int currentReputation;
  final String? communityBannerUrl;

  const AllRankingsScreen({
    super.key,
    required this.currentLevel,
    required this.currentReputation,
    this.communityBannerUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final s = ref.watch(stringsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Fundo: banner da comunidade com opacidade ──
          if (communityBannerUrl != null && communityBannerUrl!.isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: communityBannerUrl!,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.65),
                colorBlendMode: BlendMode.darken,
                errorWidget: (_, __, ___) => Container(
                  color: context.scaffoldBg,
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: context.scaffoldBg,
              ),
            ),

          // ── Conteúdo principal ──
          SafeArea(
            child: Column(
              children: [
                // ── AppBar customizada ──
                _buildAppBar(context, r, s),

                // ── Info do nível atual ──
                _buildCurrentLevelInfo(context, r, s),

                SizedBox(height: r.s(8)),

                // ── Lista de todos os 20 níveis ──
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.s(0),
                      vertical: r.s(4),
                    ),
                    itemCount: maxLevel,
                    itemBuilder: (context, index) {
                      final lvl = index + 1;
                      return _buildLevelTile(context, r, s, lvl);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAppBar(BuildContext context, Responsive r, dynamic s) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: r.s(4),
        vertical: r.s(8),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white, size: r.s(24)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              s.allRankings,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: r.fs(18),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          // Placeholder para manter centralizado
          SizedBox(width: r.s(48)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INFO DO NÍVEL ATUAL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCurrentLevelInfo(
      BuildContext context, Responsive r, dynamic s) {
    final levelColor = AppTheme.getLevelColor(currentLevel);
    final title = levelTitleFromStrings(s, currentLevel);
    final progress = levelProgress(currentReputation);
    final nextThreshold = currentLevel >= maxLevel
        ? reputationForLevel(maxLevel)
        : reputationForNextLevel(currentLevel);
    final isMaxLevel = currentLevel >= maxLevel;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(16)),
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(
          color: levelColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Ícone de nível
              _buildLevelBadge(r, currentLevel, levelColor, r.s(48)),
              SizedBox(width: r.s(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.currentLevel}: $currentLevel',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: r.s(2)),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.fs(18),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: r.s(4)),
                    Text(
                      '${formatCount(currentReputation)} REP',
                      style: TextStyle(
                        color: levelColor,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r.s(12)),

          // Barra de progresso
          Container(
            height: r.s(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(
                color: levelColor.withValues(alpha: 0.4),
                width: 1,
              ),
              color: Colors.black.withValues(alpha: 0.3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(r.s(11)),
              child: Stack(
                children: [
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
                  Center(
                    child: Text(
                      isMaxLevel
                          ? s.levelMaxReached
                          : s.repProgressLabel(
                              currentReputation, nextThreshold),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!isMaxLevel) ...[
            SizedBox(height: r.s(6)),
            Text(
              s.daysToLevelUp(daysToNextLevel(currentReputation)),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: r.fs(10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TILE DE CADA NÍVEL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLevelTile(
      BuildContext context, Responsive r, dynamic s, int lvl) {
    final levelColor = AppTheme.getLevelColor(lvl);
    final title = levelTitleFromStrings(s, lvl);
    final threshold = reputationForLevel(lvl);
    final isCurrent = lvl == currentLevel;
    final isUnlocked = lvl <= currentLevel;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: r.s(8),
        vertical: r.s(2),
      ),
      decoration: BoxDecoration(
        color: isCurrent
            ? levelColor.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(r.s(12)),
        border: isCurrent
            ? Border.all(color: levelColor.withValues(alpha: 0.5), width: 1.5)
            : null,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: r.s(12),
          vertical: r.s(4),
        ),
        leading: _buildLevelBadge(r, lvl, levelColor, r.s(44)),
        title: Text(
          title,
          style: TextStyle(
            color: isUnlocked
                ? Colors.white
                : Colors.white.withValues(alpha: 0.5),
            fontSize: r.fs(15),
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          lvl == 1
              ? '< ${formatCount(levelThresholds[1])} ${s.reputation}'
              : s.reputationPointsLabel(threshold),
          style: TextStyle(
            color: isUnlocked
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.35),
            fontSize: r.fs(12),
          ),
        ),
        trailing: isCurrent
            ? Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.s(8),
                  vertical: r.s(4),
                ),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(r.s(8)),
                  border: Border.all(
                    color: levelColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  s.currentLevel,
                  style: TextStyle(
                    color: levelColor,
                    fontSize: r.fs(10),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : isUnlocked
                ? Icon(
                    Icons.check_circle_rounded,
                    color: levelColor.withValues(alpha: 0.6),
                    size: r.s(20),
                  )
                : Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.2),
                    size: r.s(20),
                  ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BADGE DE NÍVEL (ícone circular)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLevelBadge(
      Responsive r, int lvl, Color levelColor, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            levelColor,
            levelColor.withValues(alpha: 0.65),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: levelColor.withValues(alpha: 0.3),
            blurRadius: 6,
            spreadRadius: 1,
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
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: size * 0.17,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
            Text(
              '$lvl',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.38,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
