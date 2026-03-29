import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';

/// BlockContentRenderer — Renderizador de blocos de conteúdo rico.
///
/// No Amino original, os blogs são compostos por blocos intercalados:
/// - Parágrafos de texto (com formatação básica)
/// - Imagens inline (entre parágrafos)
/// - Separadores visuais
/// - Links embutidos com preview
///
/// Este widget recebe uma lista de blocos (content_blocks JSONB) e
/// renderiza cada um como um widget independente em uma Column.
///
/// Formato dos blocos:
/// ```json
/// [
///   {"type": "text", "content": "Parágrafo de texto..."},
///   {"type": "image", "url": "https://...", "caption": "Legenda"},
///   {"type": "heading", "content": "Título da seção", "level": 2},
///   {"type": "divider"},
///   {"type": "quote", "content": "Citação importante"},
///   {"type": "link", "url": "https://...", "title": "Título", "preview": "..."}
/// ]
/// ```
class BlockContentRenderer extends StatelessWidget {
  final List<Map<String, dynamic>> blocks;
  final String? backgroundUrl;
  final double horizontalPadding;

  const BlockContentRenderer({
    super.key,
    required this.blocks,
    this.backgroundUrl,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < blocks.length; i++) ...[
          _buildBlock(blocks[i], context),
          if (i < blocks.length - 1) SizedBox(height: r.s(12)),
        ],
      ],
    );
  }

  Widget _buildBlock(Map<String, dynamic> block, BuildContext context) {
    final type = block['type'] as String? ?? 'text';

    switch (type) {
      case 'text':
        return _buildTextBlock(block, context);
      case 'heading':
        return _buildHeadingBlock(block, context);
      case 'image':
        return _buildImageBlock(block, context);
      case 'divider':
        return _buildDividerBlock(context);
      case 'quote':
        return _buildQuoteBlock(block, context);
      case 'link':
        return _buildLinkBlock(block, context);
      default:
        return _buildTextBlock(block, context);
    }
  }

  /// Bloco de texto — parágrafo com formatação básica
  Widget _buildTextBlock(Map<String, dynamic> block, BuildContext context) {
      final r = context.r;
    final content = block['content'] as String? ?? '';
    final isBold = block['bold'] == true;
    final isItalic = block['italic'] == true;
    final alignment = _parseAlignment(block['align'] as String?);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Text(
        content,
        textAlign: alignment,
        style: TextStyle(
          color: context.textPrimary,
          fontSize: r.fs(15),
          height: 1.65,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }

  /// Bloco de heading — título de seção
  Widget _buildHeadingBlock(Map<String, dynamic> block, BuildContext context) {
    final content = block['content'] as String? ?? '';
    final level = block['level'] as int? ?? 2;

    final fontSize = level == 1 ? 22.0 : level == 2 ? 18.0 : 16.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Text(
        content,
        style: TextStyle(
          color: context.textPrimary,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      ),
    );
  }

  /// Bloco de imagem — imagem inline com legenda opcional
  Widget _buildImageBlock(Map<String, dynamic> block, BuildContext context) {
      final r = context.r;
    final url = block['url'] as String? ?? '';
    final caption = block['caption'] as String?;

    if (url.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Imagem com cantos arredondados
        ClipRRect(
          borderRadius: BorderRadius.circular(r.s(12)),
          child: CachedNetworkImage(
            imageUrl: url,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: r.s(200),
              color: context.cardBg,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.accentColor,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              height: r.s(120),
              color: context.cardBg,
              child: Center(
                child: Icon(Icons.broken_image_rounded,
                    color: context.textHint, size: r.s(32)),
              ),
            ),
          ),
        ),
        // Legenda
        if (caption != null && caption.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              top: r.s(6),
            ),
            child: Text(
              caption,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: r.fs(12),
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }

  /// Bloco de divisor — separador visual
  Widget _buildDividerBlock(BuildContext context) {
      final r = context.r;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding * 2,
        vertical: r.s(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: r.s(4),
            height: r.s(4),
            decoration: BoxDecoration(
              color: context.textHint.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: r.s(8)),
          Container(
            width: r.s(4),
            height: r.s(4),
            decoration: BoxDecoration(
              color: context.textHint.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: r.s(8)),
          Container(
            width: r.s(4),
            height: r.s(4),
            decoration: BoxDecoration(
              color: context.textHint.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  /// Bloco de citação — quote com barra lateral
  Widget _buildQuoteBlock(Map<String, dynamic> block, BuildContext context) {
      final r = context.r;
    final content = block['content'] as String? ?? '';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
        padding: EdgeInsets.only(left: r.s(14), top: r.s(10), bottom: r.s(10), right: r.s(10)),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppTheme.accentColor.withValues(alpha: 0.6),
              width: r.s(3),
            ),
          ),
          color: AppTheme.accentColor.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
        ),
        child: Text(
          content,
          style: TextStyle(
            color: context.textPrimary.withValues(alpha: 0.85),
            fontSize: r.fs(14),
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  /// Bloco de link — preview de link embutido
  Widget _buildLinkBlock(Map<String, dynamic> block, BuildContext context) {
      final r = context.r;
    final url = block['url'] as String? ?? '';
    final title = block['title'] as String? ?? url;
    final preview = block['preview'] as String?;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(r.s(10)),
          border: Border.all(
            color: context.dividerClr.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: r.s(36),
              height: r.s(36),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(r.s(8)),
              ),
              child: Icon(Icons.link_rounded,
                  color: AppTheme.accentColor, size: r.s(18)),
            ),
            SizedBox(width: r.s(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.accentColor,
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: r.fs(11),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextAlign _parseAlignment(String? align) {
    switch (align) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }
}

/// Versão compacta do BlockContentRenderer para uso no PostCard (preview).
/// Mostra apenas o primeiro bloco de texto e a primeira imagem.
class BlockContentPreview extends StatelessWidget {
  final List<Map<String, dynamic>> blocks;
  final int maxLines;

  const BlockContentPreview({
    super.key,
    required this.blocks,
    this.maxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    if (blocks.isEmpty) return const SizedBox.shrink();

    // Encontrar o primeiro bloco de texto
    final firstText = blocks.firstWhere(
      (b) => b['type'] == 'text' || b['type'] == 'heading',
      orElse: () => {},
    );
    final textContent = firstText['content'] as String? ?? '';

    // Encontrar a primeira imagem
    final firstImage = blocks.firstWhere(
      (b) => b['type'] == 'image',
      orElse: () => {},
    );
    final imageUrl = firstImage['url'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (textContent.isNotEmpty)
          Text(
            textContent,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: r.fs(13),
              height: 1.4,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        if (imageUrl != null && imageUrl.isNotEmpty) ...[
          SizedBox(height: r.s(8)),
          ClipRRect(
            borderRadius: BorderRadius.circular(r.s(8)),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              height: r.s(120),
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: r.s(120),
                color: context.cardBg,
              ),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    );
  }
}
