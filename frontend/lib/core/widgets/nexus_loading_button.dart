import 'package:flutter/material.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../utils/responsive.dart';

/// Botão de ação padronizado com estado de loading inline.
///
/// Substitui o texto pelo spinner sem alterar o tamanho do botão,
/// evitando "layout shift" e dando feedback imediato ao usuário.
///
/// Uso:
/// ```dart
/// NexusLoadingButton(
///   label: 'Publicar',
///   isLoading: _isSubmitting,
///   onPressed: _handleSubmit,
/// )
/// ```
class NexusLoadingButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double borderRadius;

  const NexusLoadingButton({
    super.key,
    required this.label,
    required this.isLoading,
    this.onPressed,
    this.width,
    this.height,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    final bgColor = backgroundColor ?? theme.accentPrimary;
    final fgColor = foregroundColor ?? Colors.white;

    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? r.s(52),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          disabledBackgroundColor: bgColor.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(borderRadius)),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? SizedBox(
                  key: const ValueKey('loading'),
                  width: r.s(20),
                  height: r.s(20),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fgColor,
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: r.s(18), color: fgColor),
                      SizedBox(width: r.s(8)),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: r.fs(16),
                        fontWeight: FontWeight.w700,
                        color: fgColor,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Versão outline do NexusLoadingButton.
class NexusLoadingButtonOutline extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final IconData? icon;
  final double borderRadius;

  const NexusLoadingButtonOutline({
    super.key,
    required this.label,
    required this.isLoading,
    this.onPressed,
    this.width,
    this.height,
    this.icon,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;

    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? r.s(52),
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.accentPrimary,
          side: BorderSide(color: theme.accentPrimary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(borderRadius)),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? SizedBox(
                  key: const ValueKey('loading'),
                  width: r.s(20),
                  height: r.s(20),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.accentPrimary,
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: r.s(18)),
                      SizedBox(width: r.s(8)),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: r.fs(16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
