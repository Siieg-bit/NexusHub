import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Widget que renderiza texto com URLs automaticamente clicáveis.
///
/// Suporta links externos (abre no navegador) e links internos do app
/// (navega via GoRouter com destaque visual de tipo).
/// Também suporta links no formato Markdown: `[título](url)`.
///
/// Implementado como [StatefulWidget] para gerenciar corretamente o ciclo
/// de vida dos [TapGestureRecognizer] e evitar memory leaks.
class LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.linkStyle,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  /// Regex que detecta:
  ///   1. Links Markdown: `[texto](https://...)`
  ///   2. URLs simples: `https://...`
  static final _urlRegex = RegExp(
    r'(?:\[([^\]]+)\]\((https?://[^\s\)]+)\))|(https?://[^\s]+)',
    caseSensitive: false,
  );

  /// Padrões de links internos do app com tipo, ícone e cor
  static const _internalPatterns = <String, _InternalLinkInfo>{
    '/community/': _InternalLinkInfo('Comunidade', Icons.groups_rounded, Color(0xFF6C5CE7)),
    '/post/': _InternalLinkInfo('Post', Icons.article_rounded, Color(0xFFE91E63)),
    '/user/': _InternalLinkInfo('Perfil', Icons.person_rounded, Color(0xFF00BCD4)),
    '/chat/': _InternalLinkInfo('Chat', Icons.chat_rounded, Color(0xFF4CAF50)),
    '/quiz/': _InternalLinkInfo('Quiz', Icons.quiz_rounded, Color(0xFFFF9800)),
    '/wiki/': _InternalLinkInfo('Wiki', Icons.menu_book_rounded, Color(0xFF9C27B0)),
    '/poll/': _InternalLinkInfo('Enquete', Icons.poll_rounded, Color(0xFF00BCD4)),
    '/question/': _InternalLinkInfo('Pergunta', Icons.help_rounded, Color(0xFFFF5722)),
  };

  /// Verifica se a URL é um link interno do app
  static _InternalLinkInfo? _getInternalInfo(String url) {
    final lower = url.toLowerCase();
    for (final entry in _internalPatterns.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Abre uma URL: tenta navegar internamente via GoRouter;
  /// se falhar, abre no navegador externo.
  static void openUrl(BuildContext context, String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path;
      if (path.isNotEmpty && path != '/') {
        try {
          GoRouter.of(context).push(path);
          return;
        } catch (_) {
          // GoRouter não encontrou a rota — abrir externamente
        }
      }
    }
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  /// Cria um [TapGestureRecognizer] gerenciado pelo estado,
  /// garantindo que será descartado no [dispose].
  TapGestureRecognizer _createRecognizer(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) {
    // Limpar recognizers anteriores a cada rebuild
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final defaultStyle = widget.style ??
        TextStyle(
          color: context.nexusTheme.textPrimary,
          fontSize: 14,
        );
    final defaultLinkStyle = widget.linkStyle ??
        defaultStyle.copyWith(
          color: context.nexusTheme.accentSecondary,
          decoration: TextDecoration.underline,
          decorationColor: context.nexusTheme.accentSecondary,
        );

    final matches = LinkifiedText._urlRegex.allMatches(widget.text).toList();
    if (matches.isEmpty) {
      return Text(
        widget.text,
        style: defaultStyle,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        textAlign: widget.textAlign,
      );
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Texto antes do link
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: widget.text.substring(lastEnd, match.start),
          style: defaultStyle,
        ));
      }

      final isMarkdownLink = match.group(1) != null;
      final displayText =
          isMarkdownLink ? match.group(1)! : match.group(3)!;
      final url = isMarkdownLink ? match.group(2)! : match.group(3)!;

      final internalInfo = LinkifiedText._getInternalInfo(url);

      if (internalInfo != null && !isMarkdownLink) {
        // Link interno: mostrar badge com tipo
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _InternalLinkChip(
            label: internalInfo.label,
            icon: internalInfo.icon,
            color: internalInfo.color,
            url: url,
          ),
        ));
      } else {
        // Link externo ou markdown link: texto clicável
        spans.add(TextSpan(
          text: displayText,
          style: defaultLinkStyle,
          recognizer: _createRecognizer(
            () => LinkifiedText.openUrl(context, url),
          ),
        ));
      }

      lastEnd = match.end;
    }

    // Texto restante
    if (lastEnd < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(lastEnd),
        style: defaultStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
  }
}

class _InternalLinkInfo {
  final String label;
  final IconData icon;
  final Color color;
  const _InternalLinkInfo(this.label, this.icon, this.color);
}

class _InternalLinkChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String url;

  const _InternalLinkChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => LinkifiedText.openUrl(context, url),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
