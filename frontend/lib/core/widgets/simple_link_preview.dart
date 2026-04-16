import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../utils/responsive.dart';

/// Widget simplificado de preview de link que funciona apenas com URL.
/// Para links internos do app, exibe um card estilizado com ícone e tipo.
/// Para links externos, exibe domínio e URL formatada.
/// Não depende de banco de dados ou RPCs.
class SimpleLinkPreview extends StatelessWidget {
  final String url;
  final String? customTitle;

  const SimpleLinkPreview({
    super.key,
    required this.url,
    this.customTitle,
  });

  /// Detecta se é um link interno do app e retorna info de tipo
  static _InternalLinkInfo? _detectInternalLink(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    // Links internos (sem host ou com host do app)
    final isInternal = host.isEmpty ||
        host.contains('aminexus') ||
        host.contains('nexushub') ||
        host.contains('localhost');

    if (!isInternal) return null;

    if (path.contains('/blog/') || path.contains('/post/')) {
      return _InternalLinkInfo('Blog', Icons.article_rounded, Colors.blue);
    }
    if (path.contains('/chat/') || path.contains('/thread/')) {
      return _InternalLinkInfo('Chat', Icons.chat_bubble_rounded, Colors.green);
    }
    if (path.contains('/quiz')) {
      return _InternalLinkInfo('Quiz', Icons.quiz_rounded, Colors.orange);
    }
    if (path.contains('/question')) {
      return _InternalLinkInfo('Pergunta', Icons.help_rounded, Colors.purple);
    }
    if (path.contains('/wiki')) {
      return _InternalLinkInfo('Wiki', Icons.menu_book_rounded, Colors.teal);
    }
    if (path.contains('/profile/') || path.contains('/user/')) {
      return _InternalLinkInfo(
          'Perfil', Icons.person_rounded, Colors.pinkAccent);
    }
    if (path.contains('/community/')) {
      return _InternalLinkInfo(
          'Comunidade', Icons.groups_rounded, Colors.indigo);
    }
    if (path.contains('/poll')) {
      return _InternalLinkInfo(
          'Enquete', Icons.poll_rounded, Colors.amber);
    }

    return _InternalLinkInfo('Link interno', Icons.link_rounded, Colors.cyan);
  }

  static String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (_) {
      return url;
    }
  }

  void _handleTap(BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final internalInfo = _detectInternalLink(url);
    if (internalInfo != null) {
      final path = uri.path;
      if (path.isNotEmpty && context.mounted) {
        // Preserva query string e fragment para que rotas que dependem de
        // estado por query (ex: ?tab=following) funcionem corretamente.
        final internalLocation = uri.replace(scheme: '', host: '').toString();
        GoRouter.of(context).push(internalLocation);
        return;
      }
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final internalInfo = _detectInternalLink(url);

    if (internalInfo != null) {
      return _buildInternalLinkCard(context, r, internalInfo);
    }
    return _buildExternalLinkCard(context, r);
  }

  Widget _buildInternalLinkCard(
      BuildContext context, Responsive r, _InternalLinkInfo info) {
    final displayTitle = customTitle ?? info.label;

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              info.color.withValues(alpha: 0.15),
              info.color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(
            color: info.color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: r.s(36),
              height: r.s(36),
              decoration: BoxDecoration(
                color: info.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(r.s(8)),
              ),
              child: Icon(info.icon, color: info.color, size: r.s(18)),
            ),
            SizedBox(width: r.s(10)),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayTitle,
                    style: TextStyle(
                      color: info.color,
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: r.s(2)),
                  Text(
                    'Ver ${info.label.toLowerCase()}',
                    style: TextStyle(
                      color: info.color.withValues(alpha: 0.7),
                      fontSize: r.fs(11),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: r.s(8)),
            Icon(Icons.arrow_forward_ios_rounded,
                color: info.color.withValues(alpha: 0.5), size: r.s(14)),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalLinkCard(BuildContext context, Responsive r) {
    final domain = _extractDomain(url);
    final displayTitle = customTitle ?? domain;

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: context.nexusTheme.surfacePrimary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(
            color: context.nexusTheme.accentSecondary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: r.s(36),
              height: r.s(36),
              decoration: BoxDecoration(
                color: context.nexusTheme.accentSecondary
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(r.s(8)),
              ),
              child: Icon(Icons.link_rounded,
                  color: context.nexusTheme.accentSecondary, size: r.s(18)),
            ),
            SizedBox(width: r.s(10)),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayTitle,
                    style: TextStyle(
                      color: context.nexusTheme.accentSecondary,
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (customTitle != null) ...[
                    SizedBox(height: r.s(2)),
                    Text(
                      domain,
                      style: TextStyle(
                        color: context.nexusTheme.textSecondary,
                        fontSize: r.fs(11),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: r.s(8)),
            Icon(Icons.open_in_new_rounded,
                color: context.nexusTheme.textSecondary, size: r.s(14)),
          ],
        ),
      ),
    );
  }
}

class _InternalLinkInfo {
  final String label;
  final IconData icon;
  final Color color;

  _InternalLinkInfo(this.label, this.icon, this.color);
}
