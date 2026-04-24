import 'package:flutter/material.dart';
import '../../config/nexus_theme_extension.dart';

/// Badge de notificação reutilizável — design limpo e moderno.
///
/// Comportamento:
///   count == 0  → invisível
///   count 1–9   → número no badge
///   count >= 10 → "9+"
///
/// Uso:
///   NexusBadge(count: 3, child: Icon(Icons.notifications))
///   NexusBadge.dot(child: Icon(Icons.notifications))  // apenas ponto
class NexusBadge extends StatelessWidget {
  final Widget child;
  final int count;
  final bool forceDot;
  final Color? color;
  final Alignment alignment;
  final Offset offset;

  const NexusBadge({
    super.key,
    required this.child,
    required this.count,
    this.forceDot = false,
    this.color,
    this.alignment = Alignment.topRight,
    this.offset = Offset.zero,
  });

  /// Apenas ponto vermelho, sem número.
  const NexusBadge.dot({
    super.key,
    required this.child,
    this.color,
    this.alignment = Alignment.topRight,
    this.offset = Offset.zero,
  })  : count = 1,
        forceDot = true;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;

    final badgeColor = color ?? context.nexusTheme.error;
    final label = forceDot ? null : (count > 9 ? '9+' : '$count');
    final isDot = forceDot || label == null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -5 + offset.dy,
          right: -5 + offset.dx,
          child: _BadgeChip(
            label: label,
            isDot: isDot,
            color: badgeColor,
          ),
        ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String? label;
  final bool isDot;
  final Color color;

  const _BadgeChip({
    required this.label,
    required this.isDot,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isDot) {
      return Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: context.nexusTheme.backgroundPrimary,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: context.nexusTheme.backgroundPrimary,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.40),
            blurRadius: 5,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label!,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1.2,
          letterSpacing: -0.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
