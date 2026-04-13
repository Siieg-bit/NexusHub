import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

/// Widget que renderiza texto com URLs automaticamente clicáveis.
/// Suporta links externos (abre no navegador) e links internos do app
/// (navega via GoRouter com destaque visual de tipo).
///
/// Também suporta links no formato Markdown: [título](url)
class LinkifiedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.linkStyle,
    this.maxLines,
    this.overflow,
  });

  static final _urlRegex = RegExp(
    r'(?:\[([^\]]+)\]\((https?://[^\s\)]+)\))|(https?://[^\s]+)',
    caseSensitive: false,
  );

  /// Padrões de links internos do app
  static final _internalPatterns = <String, _InternalLinkInfo>{
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

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ?? TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 14,
    );
    final defaultLinkStyle = linkStyle ?? defaultStyle.copyWith(
      color: const Color(0xFF64B5F6),
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFF64B5F6),
    );

    final matches = _urlRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: defaultStyle, maxLines: maxLines, overflow: overflow);
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Texto antes do link
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: defaultStyle));
      }

      final isMarkdownLink = match.group(1) != null;
      final displayText = isMarkdownLink ? match.group(1)! : match.group(3)!;
      final url = isMarkdownLink ? match.group(2)! : match.group(3)!;

      final internalInfo = _getInternalInfo(url);

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
          recognizer: TapGestureRecognizer()
            ..onTap = () => _openUrl(context, url),
        ));
      }

      lastEnd = match.end;
    }

    // Texto restante
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: defaultStyle));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  static void _openUrl(BuildContext context, String url) {
    // Tentar navegar internamente se for link do app
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path;
      if (path.isNotEmpty && path != '/') {
        try {
          context.push(path);
          return;
        } catch (_) {}
      }
    }
    // Fallback: abrir externamente
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
      onTap: () => LinkifiedText._openUrl(context, url),
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
