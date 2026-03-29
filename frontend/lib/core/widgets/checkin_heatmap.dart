import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Heatmap de Check-in estilo GitHub contributions / Amino Apps.
///
/// No Amino original, a tela de "Realizações" exibe um grid de quadrados
/// coloridos representando os dias em que o usuário fez check-in,
/// similar ao heatmap de contributions do GitHub.
///
/// Cores:
///   - Cinza escuro: dia sem check-in
///   - Verde claro → Verde escuro: intensidade baseada na streak
///   - Borda dourada: dia atual
///
/// O grid mostra os últimos 12 meses (52 semanas) com scroll horizontal.
class CheckinHeatmap extends StatelessWidget {
  /// Mapa de datas para intensidade (0 = sem check-in, 1-4 = níveis).
  /// Formato da chave: 'yyyy-MM-dd'
  final Map<String, int> checkinData;

  /// Número total de check-ins realizados.
  final int totalCheckins;

  /// Streak atual (dias consecutivos).
  final int currentStreak;

  /// Maior streak já alcançada.
  final int longestStreak;

  const CheckinHeatmap({
    super.key,
    required this.checkinData,
    this.totalCheckins = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
  });

  /// Cores do heatmap — estilo Amino (tons de verde/ciano sobre fundo escuro).
  static const _emptyColor = Color(0xFF1A2332);
  static const _level1 = Color(0xFF0E4429);
  static const _level2 = Color(0xFF006D32);
  static const _level3 = Color(0xFF26A641);
  static const _level4 = Color(0xFF39D353);

  Color _colorForLevel(int level) {
    switch (level) {
      case 1:
        return _level1;
      case 2:
        return _level2;
      case 3:
        return _level3;
      case 4:
        return _level4;
      default:
        return _emptyColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calcular 52 semanas para trás (364 dias)
    final startDate = today.subtract(const Duration(days: 363));
    // Ajustar para começar no domingo
    final adjustedStart =
        startDate.subtract(Duration(days: startDate.weekday % 7));

    // Gerar grid de semanas (colunas) x dias da semana (linhas)
    final weeks = <List<_DayData>>[];
    var currentDate = adjustedStart;

    while (currentDate.isBefore(today) ||
        currentDate.isAtSameMomentAs(today)) {
      final weekday = currentDate.weekday % 7; // 0=Dom, 6=Sáb
      if (weekday == 0) {
        weeks.add([]);
      }
      if (weeks.isEmpty) weeks.add([]);

      final key =
          '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
      final level = checkinData[key] ?? 0;
      final isToday = currentDate.isAtSameMomentAs(today);
      final isFuture = currentDate.isAfter(today);

      weeks.last.add(_DayData(
        date: currentDate,
        level: level,
        isToday: isToday,
        isFuture: isFuture,
      ));

      currentDate = currentDate.add(const Duration(days: 1));
    }

    // Preencher última semana se incompleta
    while (weeks.isNotEmpty && weeks.last.length < 7) {
      weeks.last.add(_DayData(
        date: currentDate,
        level: 0,
        isToday: false,
        isFuture: true,
      ));
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Histórico de Check-in',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '$totalCheckins dias',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Heatmap Grid ──
          SizedBox(
            height: 7 * 14.0 + 6 * 2.0, // 7 rows * (12+2 gap)
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true, // Scroll começa no final (semana atual)
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Labels dos dias da semana
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S']
                        .map((d) => SizedBox(
                              height: 14,
                              child: Text(d,
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(width: 4),
                  // Grid de quadrados
                  ...weeks.map((week) => Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: week
                              .map((day) => _HeatmapCell(
                                    color: day.isFuture
                                        ? Colors.transparent
                                        : _colorForLevel(day.level),
                                    isToday: day.isToday,
                                  ))
                              .toList(),
                        ),
                      )),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Legenda ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Menos',
                  style: TextStyle(color: Colors.grey[600], fontSize: 10)),
              const SizedBox(width: 4),
              _HeatmapCell(color: _emptyColor, isToday: false),
              const SizedBox(width: 2),
              _HeatmapCell(color: _level1, isToday: false),
              const SizedBox(width: 2),
              _HeatmapCell(color: _level2, isToday: false),
              const SizedBox(width: 2),
              _HeatmapCell(color: _level3, isToday: false),
              const SizedBox(width: 2),
              _HeatmapCell(color: _level4, isToday: false),
              const SizedBox(width: 4),
              Text('Mais',
                  style: TextStyle(color: Colors.grey[600], fontSize: 10)),
            ],
          ),

          const SizedBox(height: 16),

          // ── Stats Row ──
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Streak Atual',
                  value: '$currentStreak dias',
                  color: AppTheme.warningColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.emoji_events_rounded,
                  label: 'Maior Streak',
                  value: '$longestStreak dias',
                  color: const Color(0xFFFFD700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_today_rounded,
                  label: 'Total',
                  value: '$totalCheckins dias',
                  color: AppTheme.accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dados de um dia no heatmap.
class _DayData {
  final DateTime date;
  final int level;
  final bool isToday;
  final bool isFuture;

  _DayData({
    required this.date,
    required this.level,
    required this.isToday,
    required this.isFuture,
  });
}

/// Célula individual do heatmap (quadrado colorido).
class _HeatmapCell extends StatelessWidget {
  final Color color;
  final bool isToday;

  const _HeatmapCell({required this.color, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: isToday
            ? Border.all(color: AppTheme.warningColor, width: 1.5)
            : null,
      ),
    );
  }
}

/// Card de estatística compacto.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
