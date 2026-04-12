import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/image_viewer.dart';
import '../../../config/nexus_theme_extension.dart';

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
        return _buildDividerBlock(block, context);
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
    final content = (block['content'] ?? block['text']) as String? ?? '';
    final isBold = block['bold'] == true;
    final isItalic = block['italic'] == true;
    final alignment = _parseAlignment(block['align'] as String?);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Text(
        content,
        textAlign: alignment,
        style: TextStyle(
          color: context.nexusTheme.textPrimary,
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
    final content = (block['content'] ?? block['text']) as String? ?? '';
    final level = block['level'] as int? ?? 2;

    final fontSize = level == 1
        ? 22.0
        : level == 2
            ? 18.0
            : 16.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Text(
        content,
        style: TextStyle(
          color: context.nexusTheme.textPrimary,
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
    final url = (block['url'] ?? block['image_url']) as String? ?? '';
    final caption = block['caption'] as String?;
    if (url.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Imagem com cantos arredondados — clicável para abrir em tela cheia
        GestureDetector(
          onTap: () => showSingleImageViewer(
            context,
            imageUrl: url,
            heroTag: 'blog_img_$url',
          ),
          onLongPress: () => showSingleImageViewer(
            context,
            imageUrl: url,
            heroTag: 'blog_img_$url',
          ),
          child: Hero(
            tag: 'blog_img_$url',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(r.s(12)),
              child: CachedNetworkImage(
                imageUrl: url,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: r.s(200),
                  color: context.nexusTheme.surfacePrimary,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: context.nexusTheme.accentSecondary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: r.s(120),
                  color: context.nexusTheme.surfacePrimary,
                  child: Center(
                    child: Icon(Icons.broken_image_rounded,
                        color: context.nexusTheme.textHint, size: r.s(32)),
                  ),
                ),
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
                color: context.nexusTheme.textSecondary,
                fontSize: r.fs(12),
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }

  /// Bloco de divisor — separador visual com estilos variados
  Widget _buildDividerBlock(
      Map<String, dynamic> block, BuildContext context) {
    final r = context.r;
    final style = block['divider_style'] as String? ?? 'dots';
    final color = context.nexusTheme.textHint.withValues(alpha: 0.3);
    final softPink = const Color(0xFFE8A0BF).withValues(alpha: 0.6);
    final softPurple = const Color(0xFFB983FF).withValues(alpha: 0.6);
    final softBlue = const Color(0xFF94B3FD).withValues(alpha: 0.5);

    Widget dividerContent;

    switch (style) {
      case 'line':
        dividerContent = Container(
          height: 1,
          margin: EdgeInsets.symmetric(horizontal: r.s(20)),
          color: color,
        );
        break;
      case 'dashed':
        dividerContent = Padding(
          padding: EdgeInsets.symmetric(horizontal: r.s(20)),
          child: Row(
            children: List.generate(
              20,
              (_) => Expanded(
                child: Container(
                  height: 1,
                  margin: EdgeInsets.symmetric(horizontal: r.s(2)),
                  color: color,
                ),
              ),
            ),
          ),
        );
        break;
      case 'hearts':
        dividerContent = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\u2661 \u2665 \u2661 \u2665 \u2661',
              style: TextStyle(
                  color: softPink,
                  fontSize: r.fs(14),
                  letterSpacing: 4),
            ),
          ],
        );
        break;
      case 'sparkles':
        dividerContent = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\u2729 \u00b7 \u2729 \u00b7 \u2729 \u00b7 \u2729',
              style: TextStyle(
                  color: softPurple,
                  fontSize: r.fs(14),
                  letterSpacing: 3),
            ),
          ],
        );
        break;
      case 'flowers':
        dividerContent = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\u2740 \u2022 \u273f \u2022 \u2740 \u2022 \u273f \u2022 \u2740',
              style: TextStyle(
                  color: softPink,
                  fontSize: r.fs(13),
                  letterSpacing: 2),
            ),
          ],
        );
        break;
      case 'stars':
        dividerContent = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\u2606 \u2605 \u2606 \u2605 \u2606',
              style: TextStyle(
                  color: softPurple,
                  fontSize: r.fs(13),
                  letterSpacing: 4),
            ),
          ],
        );
        break;
      case 'moon':
        dividerContent = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\u2729 \u263d \u2729',
              style: TextStyle(
                  color: softBlue,
                  fontSize: r.fs(15),
                  letterSpacing: 6),
            ),
          ],
        );
        break;
      case 'ribbon':
        dividerContent = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\u2500\u2500 \u2661 \u2500\u2500\u2500 \u2661 \u2500\u2500',
              style: TextStyle(
                  color: softPink,
                  fontSize: r.fs(12),
                  letterSpacing: 1),
            ),
          ],
        );
        break;
      case 'wave':
        dividerContent = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\u223c\u223c\u223c\u223c\u223c\u223c\u223c\u223c\u223c\u223c',
              style: TextStyle(
                  color: softBlue,
                  fontSize: r.fs(14),
                  letterSpacing: 2),
            ),
          ],
        );
        break;
      case 'butterfly':
        dividerContent = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\u2022\u00b7\u2022\u00b7\u2022 \u0e51 \u2022\u00b7\u2022\u00b7\u2022',
              style: TextStyle(
                  color: softPurple,
                  fontSize: r.fs(13),
                  letterSpacing: 1),
            ),
          ],
        );
        break;
      case 'dots':
      default:
        dividerContent = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (_) => Container(
              margin: EdgeInsets.symmetric(horizontal: r.s(3)),
              width: r.s(4),
              height: r.s(4),
              decoration: BoxDecoration(
                color: context.nexusTheme.textHint.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: r.s(8),
      ),
      child: dividerContent,
    );
  }

  /// Bloco de citação — quote com barra lateral
  Widget _buildQuoteBlock(Map<String, dynamic> block, BuildContext context) {
    final r = context.r;
    final content = (block['content'] ?? block['text']) as String? ?? '';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
        padding: EdgeInsets.only(
            left: r.s(14), top: r.s(10), bottom: r.s(10), right: r.s(10)),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: context.nexusTheme.accentSecondary.withValues(alpha: 0.6),
              width: r.s(3),
            ),
          ),
          color: context.nexusTheme.accentSecondary.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
        ),
        child: Text(
          content,
          style: TextStyle(
            color: context.nexusTheme.textPrimary.withValues(alpha: 0.85),
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
    final url = (block['url'] ?? block['image_url']) as String? ?? '';
    final title = block['title'] as String? ?? url;
    final preview = block['preview'] as String?;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: context.nexusTheme.surfacePrimary,
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
                color: context.nexusTheme.accentSecondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(r.s(8)),
              ),
              child: Icon(Icons.link_rounded,
                  color: context.nexusTheme.accentSecondary, size: r.s(18)),
            ),
            SizedBox(width: r.s(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.nexusTheme.accentSecondary,
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
                        color: context.nexusTheme.textSecondary,
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
              color: context.nexusTheme.textSecondary,
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
                color: context.nexusTheme.surfacePrimary,
              ),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    );
  }
}
