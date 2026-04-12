import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/media_upload_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/image_viewer.dart';
import '../../../core/widgets/rgb_color_picker.dart';
import '../../chat/widgets/giphy_picker.dart';

class RichBioMediaItem {
  final String id;
  final String type;
  final String url;

  const RichBioMediaItem({
    required this.id,
    required this.type,
    required this.url,
  });

  factory RichBioMediaItem.fromJson(Map<String, dynamic> json) {
    return RichBioMediaItem(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? (json['id'] as String).trim()
          : DateTime.now().microsecondsSinceEpoch.toString(),
      type: (json['type'] as String?)?.trim().toLowerCase() ?? 'image',
      url: (json['url'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'url': url,
      };

  RichBioMediaItem copyWith({String? id, String? type, String? url}) {
    return RichBioMediaItem(
      id: id ?? this.id,
      type: type ?? this.type,
      url: url ?? this.url,
    );
  }
}

class RichBioContent {
  final String markdown;
  final String? textColorHex;
  final List<RichBioMediaItem> media;
  final bool isLegacy;

  const RichBioContent({
    required this.markdown,
    this.textColorHex,
    this.media = const [],
    this.isLegacy = false,
  });

  bool get hasRichData =>
      (textColorHex?.trim().isNotEmpty ?? false) || media.isNotEmpty;

  RichBioContent copyWith({
    String? markdown,
    String? textColorHex,
    List<RichBioMediaItem>? media,
    bool? isLegacy,
  }) {
    return RichBioContent(
      markdown: markdown ?? this.markdown,
      textColorHex: textColorHex ?? this.textColorHex,
      media: media ?? this.media,
      isLegacy: isLegacy ?? this.isLegacy,
    );
  }
}

class RichBioCodec {
  static RichBioContent decode(String? raw) {
    final source = raw?.trim() ?? '';
    if (source.isEmpty) {
      return const RichBioContent(markdown: '', isLegacy: true);
    }

    try {
      final parsed = jsonDecode(source);
      if (parsed is Map<String, dynamic> && parsed['kind'] == 'rich_bio_v1') {
        final mediaJson = parsed['media'];
        return RichBioContent(
          markdown: (parsed['markdown'] as String?) ?? '',
          textColorHex: _normalizeHex(parsed['textColorHex'] as String?),
          media: mediaJson is List
              ? mediaJson
                  .whereType<Map>()
                  .map((item) => RichBioMediaItem.fromJson(
                      Map<String, dynamic>.from(item)))
                  .where((item) => item.url.trim().isNotEmpty)
                  .toList()
              : const [],
          isLegacy: false,
        );
      }
    } catch (_) {}

    return RichBioContent(markdown: source, isLegacy: true);
  }

  static String encode(RichBioContent content) {
    final normalized = content.markdown.trim();
    final normalizedHex = _normalizeHex(content.textColorHex);
    final validMedia = content.media
        .where((item) => item.url.trim().isNotEmpty)
        .toList(growable: false);

    if (normalizedHex == null && validMedia.isEmpty) {
      return normalized;
    }

    return jsonEncode({
      'kind': 'rich_bio_v1',
      'markdown': normalized,
      'textColorHex': normalizedHex,
      'media': validMedia.map((item) => item.toJson()).toList(),
    });
  }

  static Color? parseColor(String? hex) {
    final normalized = _normalizeHex(hex);
    if (normalized == null) return null;
    try {
      return Color(int.parse('FF${normalized.substring(1)}', radix: 16));
    } catch (_) {
      return null;
    }
  }

  static String? colorToHex(Color? color) {
    if (color == null) return null;
    final argb = color.toARGB32();
    final red = (argb >> 16) & 0xFF;
    final green = (argb >> 8) & 0xFF;
    final blue = argb & 0xFF;
    return '#${red.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${green.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${blue.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  static String? _normalizeHex(String? hex) {
    final cleaned = hex?.trim().replaceAll('#', '');
    if (cleaned == null || cleaned.isEmpty) return null;
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) return null;
    return '#${cleaned.toUpperCase()}';
  }
}

Future<String?> showRichBioEditorSheet(
  BuildContext context, {
  required String initialValue,
  required String title,
  required String hintText,
  String saveLabel = 'Salvar',
  String cancelLabel = 'Cancelar',
  String editorLabel = 'Editor',
  String previewLabel = 'Prévia',
  String markdownLabel = 'Use Markdown para formatar',
  int maxLength = 500,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RichBioEditorSheet(
      initialValue: initialValue,
      title: title,
      hintText: hintText,
      saveLabel: saveLabel,
      cancelLabel: cancelLabel,
      editorLabel: editorLabel,
      previewLabel: previewLabel,
      markdownLabel: markdownLabel,
      maxLength: maxLength,
    ),
  );
}

class RichBioRenderer extends StatelessWidget {
  final String rawContent;
  final String emptyPlaceholder;
  final EdgeInsetsGeometry? padding;
  final double? fontSize;
  final Color? fallbackTextColor;
  final bool selectable;
  final int? maxPreviewLines;

  const RichBioRenderer({
    super.key,
    required this.rawContent,
    this.emptyPlaceholder = 'Sem conteúdo ainda.',
    this.padding,
    this.fontSize,
    this.fallbackTextColor,
    this.selectable = false,
    this.maxPreviewLines,
  });

  Future<void> _openLink(String? href) async {
    final value = href?.trim();
    if (value == null || value.isEmpty) return;
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final parsed = RichBioCodec.decode(rawContent);
    final text = parsed.markdown.trim();
    final textColor = RichBioCodec.parseColor(parsed.textColorHex) ??
        fallbackTextColor ??
        context.textPrimary;

    if (text.isEmpty && parsed.media.isEmpty) {
      return Padding(
        padding: padding ?? EdgeInsets.zero,
        child: Text(
          emptyPlaceholder,
          style: TextStyle(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
            fontSize: fontSize ?? r.fs(13),
          ),
        ),
      );
    }

    final effectiveMedia = maxPreviewLines == null ? parsed.media : const <RichBioMediaItem>[];
    final children = <Widget>[];

    if (text.isNotEmpty) {
      children.add(
        MarkdownBody(
          data: text,
          selectable: selectable,
          onTapLink: (_, href, __) => _openLink(href),
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: TextStyle(
              color: textColor,
              fontSize: fontSize ?? r.fs(14),
              height: 1.55,
            ),
            strong: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: fontSize ?? r.fs(14),
            ),
            em: TextStyle(
              color: textColor,
              fontStyle: FontStyle.italic,
              fontSize: fontSize ?? r.fs(14),
            ),
            del: TextStyle(
              color: textColor.withValues(alpha: 0.72),
              decoration: TextDecoration.lineThrough,
              fontSize: fontSize ?? r.fs(14),
            ),
            h1: TextStyle(
              color: textColor,
              fontSize: (fontSize ?? r.fs(14)) + 6,
              fontWeight: FontWeight.w800,
            ),
            h2: TextStyle(
              color: textColor,
              fontSize: (fontSize ?? r.fs(14)) + 4,
              fontWeight: FontWeight.w700,
            ),
            h3: TextStyle(
              color: textColor,
              fontSize: (fontSize ?? r.fs(14)) + 2,
              fontWeight: FontWeight.w700,
            ),
            a: const TextStyle(
              color: AppTheme.primaryColor,
              decoration: TextDecoration.underline,
            ),
            blockquote: TextStyle(
              color: textColor.withValues(alpha: 0.86),
              fontStyle: FontStyle.italic,
              fontSize: fontSize ?? r.fs(14),
            ),
            blockquoteDecoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.14),
              ),
            ),
            listBullet: TextStyle(
              color: textColor,
              fontSize: fontSize ?? r.fs(14),
            ),
            horizontalRuleDecoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.dividerClr),
              ),
            ),
          ),
        ),
      );
    }

    if (effectiveMedia.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(SizedBox(height: r.s(14)));
      }
      children.addAll(
        effectiveMedia.map(
          (item) => Padding(
            padding: EdgeInsets.only(bottom: r.s(12)),
            child: TappableImage(
              url: item.url,
              width: double.infinity,
              height: item.type == 'video' ? r.s(190) : r.s(220),
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(r.s(16)),
            ),
          ),
        ),
      );
    }

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );

    if (maxPreviewLines != null && text.isNotEmpty) {
      final resolvedFontSize = fontSize ?? r.fs(14);
      final maxHeight = resolvedFontSize * 1.55 * maxPreviewLines!;
      content = ClipRect(
        child: SizedBox(
          height: maxHeight,
          child: content,
        ),
      );
    }

    if (padding == null) return content;
    return Padding(padding: padding!, child: content);
  }
}

class RichBioEditorSheet extends StatefulWidget {
  final String initialValue;
  final String title;
  final String hintText;
  final String saveLabel;
  final String cancelLabel;
  final String editorLabel;
  final String previewLabel;
  final String markdownLabel;
  final int maxLength;

  const RichBioEditorSheet({
    super.key,
    required this.initialValue,
    required this.title,
    required this.hintText,
    required this.saveLabel,
    required this.cancelLabel,
    required this.editorLabel,
    required this.previewLabel,
    required this.markdownLabel,
    this.maxLength = 500,
  });

  @override
  State<RichBioEditorSheet> createState() => _RichBioEditorSheetState();
}

class _RichBioEditorSheetState extends State<RichBioEditorSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late List<RichBioMediaItem> _media;
  bool _showPreview = false;
  bool _isUploading = false;
  Color? _textColor;

  @override
  void initState() {
    super.initState();
    final content = RichBioCodec.decode(widget.initialValue);
    _controller = TextEditingController(text: content.markdown);
    _focusNode = FocusNode();
    _media = List<RichBioMediaItem>.from(content.media);
    _textColor = RichBioCodec.parseColor(content.textColorHex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _replaceValue(String value, {TextSelection? selection}) {
    final safeOffset = selection?.extentOffset ?? value.length;
    final clampedOffset = safeOffset.clamp(0, value.length) as int;
    _controller.value = TextEditingValue(
      text: value,
      selection: selection != null
          ? TextSelection(
              baseOffset: selection.baseOffset.clamp(0, value.length) as int,
              extentOffset:
                  selection.extentOffset.clamp(0, value.length) as int,
            )
          : TextSelection.collapsed(offset: clampedOffset),
    );
    setState(() {});
  }

  void _wrapSelection(String prefix, String suffix) {
    final value = _controller.value;
    final selection = value.selection;
    final text = value.text;

    if (!selection.isValid || selection.start < 0 || selection.end < 0) {
      final inserted = '$prefix$suffix';
      _replaceValue(
        '$text$inserted',
        selection: TextSelection.collapsed(offset: text.length + prefix.length),
      );
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final selected = text.substring(start, end);
    final updated = text.replaceRange(start, end, '$prefix$selected$suffix');

    _replaceValue(
      updated,
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: start + prefix.length)
          : TextSelection(
              baseOffset: start + prefix.length,
              extentOffset: start + prefix.length + selected.length,
            ),
    );
  }

  void _toggleLinePrefix(String prefix) {
    final value = _controller.value;
    final selection = value.selection;
    final text = value.text;

    if (!selection.isValid || selection.start < 0 || selection.end < 0) {
      final updated = '$text${text.isNotEmpty ? '\n' : ''}$prefix';
      _replaceValue(
        updated,
        selection: TextSelection.collapsed(offset: updated.length),
      );
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final blockStart = text.lastIndexOf('\n', start == 0 ? 0 : start - 1) + 1;
    final nextBreak = text.indexOf('\n', end);
    final blockEnd = nextBreak == -1 ? text.length : nextBreak;
    final block = text.substring(blockStart, blockEnd);
    final lines = block.split('\n');
    final allPrefixed = lines
        .where((line) => line.trim().isNotEmpty)
        .every((line) => line.startsWith(prefix));

    final updatedBlock = lines
        .map((line) {
          if (line.trim().isEmpty) return line;
          if (allPrefixed) {
            return line.startsWith(prefix) ? line.substring(prefix.length) : line;
          }
          return line.startsWith(prefix) ? line : '$prefix$line';
        })
        .join('\n');

    final updated = text.replaceRange(blockStart, blockEnd, updatedBlock);
    _replaceValue(
      updated,
      selection: TextSelection(
        baseOffset: blockStart,
        extentOffset: blockStart + updatedBlock.length,
      ),
    );
  }

  void _insertDivider() {
    final text = _controller.text;
    final selection = _controller.selection;
    final insertText = '${text.isNotEmpty ? '\n\n' : ''}---\n';

    if (!selection.isValid || selection.start < 0) {
      final updated = '$text$insertText';
      _replaceValue(
        updated,
        selection: TextSelection.collapsed(offset: updated.length),
      );
      return;
    }

    final updated = text.replaceRange(selection.start, selection.end, insertText);
    _replaceValue(
      updated,
      selection: TextSelection.collapsed(
        offset: selection.start + insertText.length,
      ),
    );
  }

  Future<void> _pickTextColor() async {
    final selected = await showRGBColorPicker(
      context,
      initialColor: _textColor ?? AppTheme.primaryColor,
      title: 'Cor do texto da bio',
    );
    if (selected == null || !mounted) return;
    setState(() => _textColor = selected);
  }

  Future<void> _pickAndUploadImage() async {
    final file = await MediaUploadService.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    await _uploadMediaFile(file, type: 'image');
  }

  Future<void> _pickAndUploadVideo() async {
    final file = await MediaUploadService.pickVideo(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    await _uploadMediaFile(file, type: 'video');
  }

  Future<void> _pickAndUploadGif() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gif'],
      allowMultiple: false,
    );
    final path = picked?.files.single.path;
    if (path == null || path.isEmpty || !mounted) return;
    await _uploadMediaFile(File(path), type: 'gif');
  }

  Future<void> _pickGifFromGiphy() async {
    final url = await GiphyPicker.show(context);
    if (url == null || url.trim().isEmpty || !mounted) return;
    setState(() {
      _media = [
        ..._media,
        RichBioMediaItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          type: 'gif',
          url: url.trim(),
        ),
      ];
    });
  }

  Future<void> _uploadMediaFile(File file, {required String type}) async {
    setState(() => _isUploading = true);
    final result = await MediaUploadService.uploadFile(
      file: file,
      bucket: MediaBucket.postMedia,
    );
    if (!mounted) return;
    setState(() {
      _isUploading = false;
      if (result != null) {
        _media = [
          ..._media,
          RichBioMediaItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: type,
            url: result.url,
          ),
        ];
      }
    });
  }

  Future<void> _openGifOptions() async {
    final r = context.r;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.surfaceColor,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(r.s(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adicionar GIF',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: r.fs(18),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: r.s(14)),
                ListTile(
                  leading: const Icon(Icons.search_rounded),
                  title: const Text('Buscar no Giphy'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pickGifFromGiphy();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file_rounded),
                  title: const Text('Enviar arquivo GIF'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pickAndUploadGif();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildResult() {
    final content = RichBioContent(
      markdown: _controller.text,
      textColorHex: RichBioCodec.colorToHex(_textColor),
      media: _media,
    );
    return RichBioCodec.encode(content);
  }

  Widget _buildToolbarSection(
    BuildContext context, {
    required String title,
    required List<Widget> actions,
  }) {
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: r.fs(12),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: r.s(8)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: actions),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final maxSheetHeight = mediaQuery.size.height * 0.92;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(24))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: r.s(44),
                    height: r.s(4),
                    decoration: BoxDecoration(
                      color: context.dividerClr,
                      borderRadius: BorderRadius.circular(r.s(999)),
                    ),
                  ),
                ),
                SizedBox(height: r.s(16)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: r.fs(18),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: r.s(6)),
                          Text(
                            '${widget.markdownLabel}. Você também pode definir a cor do texto e anexar imagem, GIF ou vídeo.',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: r.fs(12),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: r.s(12)),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(widget.cancelLabel),
                    ),
                    SizedBox(width: r.s(6)),
                    FilledButton(
                      onPressed: _isUploading
                          ? null
                          : () => Navigator.of(context).pop(_buildResult()),
                      child: Text(widget.saveLabel),
                    ),
                  ],
                ),
                SizedBox(height: r.s(16)),
                _buildToolbarSection(
                  context,
                  title: 'Formatação',
                  actions: [
                    _FormatActionChip(
                      icon: Icons.format_bold_rounded,
                      label: 'Negrito',
                      onTap: () => _wrapSelection('**', '**'),
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.format_italic_rounded,
                      label: 'Itálico',
                      onTap: () => _wrapSelection('*', '*'),
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.format_strikethrough_rounded,
                      label: 'Tachado',
                      onTap: () => _wrapSelection('~~', '~~'),
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.title_rounded,
                      label: 'Título',
                      onTap: () => _toggleLinePrefix('## '),
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.format_quote_rounded,
                      label: 'Citação',
                      onTap: () => _toggleLinePrefix('> '),
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.format_list_bulleted_rounded,
                      label: 'Lista',
                      onTap: () => _toggleLinePrefix('- '),
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.horizontal_rule_rounded,
                      label: 'Divisor',
                      onTap: _insertDivider,
                    ),
                  ],
                ),
                SizedBox(height: r.s(12)),
                _buildToolbarSection(
                  context,
                  title: 'Estilo e mídia',
                  actions: [
                    _FormatActionChip(
                      icon: Icons.format_color_text_rounded,
                      label: 'Cor do texto',
                      onTap: _pickTextColor,
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.image_outlined,
                      label: 'Imagem',
                      onTap: _pickAndUploadImage,
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.gif_box_outlined,
                      label: 'GIF',
                      onTap: _openGifOptions,
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.smart_display_outlined,
                      label: 'Vídeo',
                      onTap: _pickAndUploadVideo,
                    ),
                    SizedBox(width: r.s(8)),
                    if (_textColor != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: r.s(12),
                          vertical: r.s(10),
                        ),
                        decoration: BoxDecoration(
                          color: (_textColor ?? AppTheme.primaryColor)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(r.s(999)),
                          border: Border.all(
                            color: (_textColor ?? AppTheme.primaryColor)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: r.s(12),
                              height: r.s(12),
                              decoration: BoxDecoration(
                                color: _textColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: r.s(8)),
                            Text(
                              RichBioCodec.colorToHex(_textColor) ?? '',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: r.fs(12),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: r.s(8)),
                            GestureDetector(
                              onTap: () => setState(() => _textColor = null),
                              child: Icon(
                                Icons.close_rounded,
                                color: context.textSecondary,
                                size: r.s(16),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (_media.isNotEmpty) ...[
                  SizedBox(height: r.s(12)),
                  Wrap(
                    spacing: r.s(10),
                    runSpacing: r.s(10),
                    children: _media
                        .map(
                          (item) => Container(
                            width: r.s(118),
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(r.s(14)),
                              border: Border.all(color: context.dividerClr),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(r.s(14)),
                                  ),
                                  child: TappableImage(
                                    url: item.url,
                                    width: double.infinity,
                                    height: r.s(84),
                                    fit: BoxFit.cover,
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    r.s(10),
                                    r.s(8),
                                    r.s(10),
                                    r.s(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.type.toUpperCase(),
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: r.fs(11),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(() {
                                          _media = _media
                                              .where((m) => m.id != item.id)
                                              .toList();
                                        }),
                                        child: Icon(
                                          Icons.delete_outline_rounded,
                                          color: AppTheme.errorColor,
                                          size: r.s(18),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                SizedBox(height: r.s(14)),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(r.s(18)),
                      border: Border.all(
                        color: _showPreview
                            ? context.dividerClr
                            : AppTheme.accentColor.withValues(alpha: 0.55),
                        width: 1.4,
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            r.s(10),
                            r.s(10),
                            r.s(10),
                            r.s(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SegmentedButton<bool>(
                                  showSelectedIcon: true,
                                  segments: [
                                    ButtonSegment<bool>(
                                      value: false,
                                      icon: const Icon(Icons.edit_rounded),
                                      label: Text(widget.editorLabel),
                                    ),
                                    ButtonSegment<bool>(
                                      value: true,
                                      icon: const Icon(Icons.visibility_rounded),
                                      label: Text(widget.previewLabel),
                                    ),
                                  ],
                                  selected: {_showPreview},
                                  onSelectionChanged: (selection) {
                                    setState(() => _showPreview = selection.first);
                                    if (!_showPreview) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (mounted) _focusNode.requestFocus();
                                      });
                                    } else {
                                      _focusNode.unfocus();
                                    }
                                  },
                                ),
                              ),
                              SizedBox(width: r.s(10)),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _controller,
                                builder: (_, value, __) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${value.text.length}/${widget.maxLength}',
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: r.fs(12),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: r.s(2)),
                                    Text(
                                      _isUploading
                                          ? 'Enviando mídia...'
                                          : (_showPreview
                                              ? 'Prévia rica ativa'
                                              : 'Editor ativo'),
                                      style: TextStyle(
                                        color: context.textHint,
                                        fontSize: r.fs(10),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            r.s(12),
                            0,
                            r.s(12),
                            r.s(10),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _showPreview
                                  ? 'Veja abaixo como a bio vai aparecer com texto e mídia.'
                                  : 'O texto continua em Markdown e a prévia rica mostra cor e mídias anexadas.',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: r.fs(11),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(r.s(18)),
                            ),
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _controller,
                              builder: (_, value, __) {
                                if (_showPreview) {
                                  final preview = RichBioContent(
                                    markdown: value.text,
                                    textColorHex:
                                        RichBioCodec.colorToHex(_textColor),
                                    media: _media,
                                  );
                                  return SingleChildScrollView(
                                    padding: EdgeInsets.all(r.s(16)),
                                    child: RichBioRenderer(
                                      rawContent: RichBioCodec.encode(preview),
                                      emptyPlaceholder: widget.hintText,
                                      fontSize: r.fs(14),
                                      fallbackTextColor: context.textPrimary,
                                    ),
                                  );
                                }

                                return TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  autofocus: true,
                                  maxLines: null,
                                  expands: true,
                                  maxLength: widget.maxLength,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: r.fs(14),
                                    height: 1.45,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: widget.hintText,
                                    hintStyle: TextStyle(
                                      color: context.textHint,
                                      fontSize: r.fs(14),
                                    ),
                                    contentPadding: EdgeInsets.all(r.s(16)),
                                    border: InputBorder.none,
                                    counterText: '',
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FormatActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return InkWell(
      borderRadius: BorderRadius.circular(r.s(999)),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.s(12),
          vertical: r.s(10),
        ),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(r.s(999)),
          border: Border.all(color: context.dividerClr),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: context.textPrimary, size: r.s(16)),
            SizedBox(width: r.s(8)),
            Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: r.fs(12),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
