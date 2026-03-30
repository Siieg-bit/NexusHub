import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../utils/responsive.dart';

/// AminoCustomTitle — Pílula de título customizado estilo Amino.
///
/// No Amino original, os Custom Titles são pílulas com:
/// - Cor de fundo sólida (definida pelo líder)
/// - Borda fina de 1px em tom mais claro
/// - Texto branco com sombra sutil
/// - Cantos arredondados (borderRadius: 12)
/// - Padding horizontal: 10, vertical: 3
/// - FontSize: 10, FontWeight: w700
///
/// Diferente do Material Chip, não tem ícone de delete, não tem avatar,
/// e a borda é mais fina e sutil.
class AminoCustomTitle extends StatelessWidget {
  final String title;
  final Color color;

  const AminoCustomTitle({
    super.key,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    // Calcular cor da borda (mais clara que o fundo)
    final borderColor = Color.lerp(color, Colors.white, 0.3)!;
    // Calcular se o texto deve ser branco ou preto
    final textColor = color.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(3)),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.4),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: r.fs(10),
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.3,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 1,
              offset: const Offset(0, 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renderiza uma lista de Custom Titles em um Wrap
class AminoCustomTitleList extends StatelessWidget {
  final List<dynamic> titles;
  final int maxVisible;

  const AminoCustomTitleList({
    super.key,
    required this.titles,
    this.maxVisible = 6,
  });

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor.withValues(alpha: 0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    if (titles.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      alignment: WrapAlignment.center,
      children: [
        ...titles.take(maxVisible).map((t) {
          final titleText =
              t is Map ? (t['title'] ?? '') : t.toString();
          final titleColor = t is Map && t['color'] != null
              ? _parseColor(t['color'] as String? ?? '')
              : AppTheme.primaryColor.withValues(alpha: 0.3);
          return AminoCustomTitle(
            title: titleText,
            color: titleColor,
          );
        }),
        if (titles.length > maxVisible)
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.s(8), vertical: r.s(3)),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.8,
              ),
            ),
            child: Text(
              '+${titles.length - maxVisible}',
              style: TextStyle(
                fontSize: r.fs(10),
                fontWeight: FontWeight.w700,
                color: context.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
