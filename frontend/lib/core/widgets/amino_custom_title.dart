import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../models/user_model.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// =============================================================================
// AminoCustomTitle — Pílula de título customizado estilo Amino
//
// Design de badges da equipe NexusHub:
//   - Fundo sempre transparente
//   - Borda colorida conforme o cargo (TeamRole.borderColorHex)
//   - Founder: borda BRANCA exclusiva
//   - Co-Founder: borda dourada
//   - Team Admin: borda vermelha
//   - Trust & Safety: borda azul escuro
//   - Support: borda azul claro
//   - Bug Bounty: borda verde neon
//   - Community Manager: borda roxa
// =============================================================================
class AminoCustomTitle extends StatelessWidget {
  final String title;
  final Color color;
  final bool isRoleBadge;

  // Novo: cargo da equipe (null = não é team member)
  final TeamRole? teamRole;

  // Legado: mantido para retrocompatibilidade (usa borda branca genérica)
  final bool isTeamMember;

  const AminoCustomTitle({
    super.key,
    required this.title,
    required this.color,
    this.isRoleBadge = false,
    this.teamRole,
    this.isTeamMember = false,
  });

  /// Constrói uma badge de cargo da equipe com o design correto.
  factory AminoCustomTitle.teamBadge({
    Key? key,
    required TeamRole role,
  }) {
    return AminoCustomTitle(
      key: key,
      title: role.label,
      color: Colors.transparent,
      isRoleBadge: true,
      teamRole: role,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    // ── Badge de equipe com cargo específico ─────────────────────────────
    final effectiveTeamRole = teamRole;
    if (effectiveTeamRole != null && effectiveTeamRole != TeamRole.none) {
      return _TeamRoleBadge(role: effectiveTeamRole, r: r);
    }

    // ── Legado: badge genérico "Team Member" (borda branca) ──────────────
    if (isTeamMember) {
      return _TransparentBorderBadge(
        title: title,
        borderColor: Colors.white.withValues(alpha: 0.7),
        textColor: Colors.white,
        r: r,
      );
    }

    // ── Badge normal com cor de fundo ────────────────────────────────────
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

// =============================================================================
// _TeamRoleBadge — Badge de cargo da equipe com fundo transparente e borda
// colorida conforme o TeamRole.
// =============================================================================
class _TeamRoleBadge extends StatelessWidget {
  final TeamRole role;
  final Responsive r;

  const _TeamRoleBadge({required this.role, required this.r});

  @override
  Widget build(BuildContext context) {
    final borderHex = role.borderColorHex;
    final borderColor = _hexToColor(borderHex);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(5)),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(r.s(14)),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.85),
          width: 1.0,
        ),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontSize: r.fs(13),
          fontWeight: FontWeight.w700,
          color: borderColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }
}

// =============================================================================
// _TransparentBorderBadge — Badge genérico com fundo transparente e borda
// (usado para retrocompatibilidade com o badge "Team Member" legado).
// =============================================================================
class _TransparentBorderBadge extends StatelessWidget {
  final String title;
  final Color borderColor;
  final Color textColor;
  final Responsive r;

  const _TransparentBorderBadge({
    required this.title,
    required this.borderColor,
    required this.textColor,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(5)),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(r.s(14)),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: r.fs(13),
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// =============================================================================
// AminoCustomTitleList — Lista com overflow "..." e modal completo
// =============================================================================
class AminoCustomTitleList extends StatelessWidget {
  final List<dynamic> titles;
  final int maxVisible;

  // Cargo de equipe do dono dos títulos (exibe badge de cargo antes dos demais)
  final TeamRole? ownerTeamRole;

  const AminoCustomTitleList({
    super.key,
    required this.titles,
    this.maxVisible = 5,
    this.ownerTeamRole,
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

  /// Detecta se um título é o badge legado "Team Member".
  bool _isLegacyTeamBadge(dynamic t) {
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
                  children: [
                    // Badge de cargo da equipe (se houver)
                    if (ownerTeamRole != null && ownerTeamRole != TeamRole.none)
                      AminoCustomTitle.teamBadge(role: ownerTeamRole!),
                    // Demais títulos (excluindo o badge legado "Team Member")
                    ...allTitles
                        .where((t) => !_isLegacyTeamBadge(t))
                        .map((t) {
                      final titleText = t is Map ? (t['title'] ?? '') : t.toString();
                      final titleColor = _parseColor(context, t is Map ? t['color'] : null);
                      final isRole = t is Map && t['is_role_badge'] == true;
                      return AminoCustomTitle(
                        title: titleText,
                        color: titleColor,
                        isRoleBadge: isRole,
                      );
                    }),
                  ],
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

    // Filtrar o badge legado "Team Member" (será substituído pelo badge de cargo)
    final filteredTitles = titles.where((t) => !_isLegacyTeamBadge(t)).toList();

    // Calcular quantos títulos normais mostrar (reservar espaço para badge de cargo)
    final hasTeamBadge = ownerTeamRole != null && ownerTeamRole != TeamRole.none;
    final normalSlots = hasTeamBadge ? maxVisible - 1 : maxVisible;
    final visible = filteredTitles.take(normalSlots.clamp(0, filteredTitles.length)).toList();
    final hasMore = filteredTitles.length > normalSlots;

    if (!hasTeamBadge && filteredTitles.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: r.s(6),
      runSpacing: r.s(6),
      alignment: WrapAlignment.center,
      children: [
        // Badge de cargo da equipe sempre primeiro
        if (hasTeamBadge)
          AminoCustomTitle.teamBadge(role: ownerTeamRole!),

        // Títulos normais
        ...visible.map((t) {
          final titleText = t is Map ? (t['title'] ?? '') : t.toString();
          final titleColor = _parseColor(context, t is Map ? t['color'] : null);
          final isRole = t is Map && t['is_role_badge'] == true;
          return AminoCustomTitle(
            title: titleText,
            color: titleColor,
            isRoleBadge: isRole,
          );
        }),

        // Botão "..." para ver todos
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
