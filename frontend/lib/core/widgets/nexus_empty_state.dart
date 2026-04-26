import 'package:flutter/material.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../utils/responsive.dart';

/// Widget de estado vazio padronizado para o NexusHub.
///
/// Substitui os empty states ad-hoc espalhados pelo app por um componente
/// consistente com ícone, título, subtítulo e CTA opcional.
///
/// Uso:
/// ```dart
/// NexusEmptyState(
///   icon: Icons.explore_rounded,
///   title: 'Nenhum post ainda',
///   subtitle: 'Entre em comunidades para ver posts aqui.',
///   actionLabel: 'Explorar comunidades',
///   onAction: () => context.push('/explore'),
/// )
/// ```
class NexusEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const NexusEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.s(32)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone em container com gradiente suave
            Container(
              width: r.s(80),
              height: r.s(80),
              decoration: BoxDecoration(
                color: theme.accentPrimary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.accentPrimary.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                size: r.s(36),
                color: theme.accentPrimary.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: r.s(20)),

            // Título
            Text(
              title,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),

            // Subtítulo (opcional)
            if (subtitle != null) ...[
              SizedBox(height: r.s(8)),
              Text(
                subtitle!,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: r.fs(13),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Botão de ação (opcional)
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: r.s(24)),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.s(24),
                    vertical: r.s(12),
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.accentPrimary,
                        theme.accentSecondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(r.s(24)),
                    boxShadow: [
                      BoxShadow(
                        color: theme.accentPrimary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
