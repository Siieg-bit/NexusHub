import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ============================================================
// AminoCustomTitle — Pílula de título customizado estilo Amino
// ============================================================
class AminoCustomTitle extends StatelessWidget {
  final String title;
  final Color color;
  final bool isRoleBadge;
  final bool isTeamMember;

  const AminoCustomTitle({
    super.key,
    required this.title,
    required this.color,
    this.isRoleBadge = false,
    this.isTeamMember = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    // Team Member: fundo transparente, borda branca
    if (isTeamMember) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(5)),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(r.s(14)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.0),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: r.fs(13),
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    final borderColor = Color.lerp(color, Colors.white, 0.35)!;
    final textColor = color.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(5)),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r.s(14)),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.45),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: r.fs(13),
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.3,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 1,
              offset: const Offset(0, 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AminoCustomTitleList — Lista com overflow "..." e modal completo
// ============================================================
class AminoCustomTitleList extends StatelessWidget {
  final List<dynamic> titles;
  final int maxVisible;

  const AminoCustomTitleList({
    super.key,
    required this.titles,
    this.maxVisible = 5,
  });

  Color _parseColor(BuildContext context, dynamic hex) {
    if (hex == null || hex.toString().isEmpty) {
      return context.nexusTheme.accentPrimary.withValues(alpha: 0.5);
    }
    try {
      return Color(int.parse(hex.toString().replaceFirst('#', '0xFF')));
    } catch (_) {
      return context.nexusTheme.accentPrimary.withValues(alpha: 0.5);
    }
  }

  bool _isTeamMember(dynamic t) {
    if (t is! Map) return false;
    return (t['title'] ?? '').toString() == 'Team Member' &&
        (t['is_role_badge'] == true);
  }

  void _showAllTitles(BuildContext context, List<dynamic> allTitles) {
    final r = context.r;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(top: r.s(12), bottom: r.s(8)),
              child: Container(
                width: r.s(36),
                height: r.s(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.s(20), vertical: r.s(4)),
              child: Text(
                'Títulos',
                style: TextStyle(
                  fontSize: r.fs(15),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(r.s(20)),
                child: Wrap(
                  spacing: r.s(6),
                  runSpacing: r.s(8),
                  alignment: WrapAlignment.center,
                  children: allTitles.map((t) {
                    final titleText = t is Map ? (t['title'] ?? '') : t.toString();
                    final titleColor = _parseColor(context, t is Map ? t['color'] : null);
                    final isTeam = _isTeamMember(t);
                    final isRole = t is Map && t['is_role_badge'] == true;
                    return AminoCustomTitle(
                      title: titleText,
                      color: titleColor,
                      isRoleBadge: isRole,
                      isTeamMember: isTeam,
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + r.s(8)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    if (titles.isEmpty) return const SizedBox.shrink();

    final visible = titles.take(maxVisible).toList();
    final hasMore = titles.length > maxVisible;

    return Wrap(
      spacing: r.s(6),
      runSpacing: r.s(6),
      alignment: WrapAlignment.center,
      children: [
        ...visible.map((t) {
          final titleText = t is Map ? (t['title'] ?? '') : t.toString();
          final titleColor = _parseColor(context, t is Map ? t['color'] : null);
          final isTeam = _isTeamMember(t);
          final isRole = t is Map && t['is_role_badge'] == true;
          return AminoCustomTitle(
            title: titleText,
            color: titleColor,
            isRoleBadge: isRole,
            isTeamMember: isTeam,
          );
        }),
        if (hasMore)
          GestureDetector(
            onTap: () => _showAllTitles(context, titles),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(5)),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(r.s(14)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.20),
                  width: 0.8,
                ),
              ),
              child: Text(
                '•••',
                style: TextStyle(
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.75),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
