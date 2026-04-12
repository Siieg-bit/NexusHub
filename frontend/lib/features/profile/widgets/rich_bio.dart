import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:markdown/markdown.dart' as md;
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
  static RichBioContent decode(String? raw, {int depth = 0}) {
    final source = raw?.trim() ?? '';
    if (source.isEmpty) {
      return const RichBioContent(markdown: '', isLegacy: true);
    }
    if (depth > 2) {
      return RichBioContent(markdown: source, isLegacy: true);
    }

    try {
      final parsed = jsonDecode(source);

      if (parsed is String) {
        final nested = parsed.trim();
        if (nested.isNotEmpty && nested != source) {
          return decode(nested, depth: depth + 1);
        }
      }

      if (parsed is Map) {
        final map = Map<String, dynamic>.from(parsed);
        final media = _extractMedia(map['media']);

        if (map['kind'] == 'rich_bio_v1') {
          return RichBioContent(
            markdown: (map['markdown'] as String?)?.trim() ?? '',
            textColorHex: _normalizeHex(map['textColorHex'] as String?),
            media: media,
            isLegacy: false,
          );
        }

        final fallbackMarkdown = _firstMeaningfulString([
          map['markdown'],
          map['text'],
          map['content'],
          map['bio'],
          map['value'],
          _extractReadableText(map),
        ]);

        if ((fallbackMarkdown?.isNotEmpty ?? false) || media.isNotEmpty) {
          return RichBioContent(
            markdown: fallbackMarkdown ?? '',
            textColorHex: _normalizeHex(
              (map['textColorHex'] ?? map['text_color_hex']) as String?,
            ),
            media: media,
            isLegacy: true,
          );
        }
      }
    } catch (_) {}

    return RichBioContent(markdown: source, isLegacy: true);
  }

  static List<RichBioMediaItem> _extractMedia(dynamic rawMedia) {
    if (rawMedia is! List) return const [];
    return rawMedia
        .whereType<Map>()
        .map((item) => RichBioMediaItem.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.url.trim().isNotEmpty)
        .toList(growable: false);
  }

  static String? _firstMeaningfulString(List<dynamic> values) {
    for (final value in values) {
      final text = value is String ? value.trim() : null;
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  static String? _extractReadableText(dynamic value, {int depth = 0}) {
    if (depth > 3 || value == null) return null;
    if (value is String) {
      final text = value.trim();
      return text.isEmpty ? null : text;
    }
    if (value is List) {
      for (final item in value) {
        final nested = _extractReadableText(item, depth: depth + 1);
        if (nested != null && nested.isNotEmpty) {
          return nested;
        }
      }
      return null;
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return _firstMeaningfulString([
        map['markdown'],
        map['text'],
        map['content'],
        map['bio'],
        map['value'],
      ]);
    }
    return null;
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

const _richBioColorTag = 'rich-bio-color';

class _RichBioColorSyntax extends md.InlineSyntax {
  _RichBioColorSyntax()
      : super(r'\[color=(#[0-9A-Fa-f]{6})\]([\s\S]+?)\[/color\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text(_richBioColorTag, match.group(2) ?? '');
    element.attributes['hex'] = (match.group(1) ?? '').toUpperCase();
    parser.addNode(element);
    return true;
  }
}

class _RichBioColorBuilder extends MarkdownElementBuilder {
  _RichBioColorBuilder();

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final baseStyle =
        parentStyle ?? preferredStyle ?? DefaultTextStyle.of(context).style;
    final resolvedColor = RichBioCodec.parseColor(element.attributes['hex']);
    return Text.rich(
      TextSpan(
        text: element.textContent,
        style: baseStyle.copyWith(color: resolvedColor ?? baseStyle.color),
      ),
    );
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
    useSafeArea: true,
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

  String _toPreviewText(String markdown) {
    return markdown
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^\)]*\)'), '')
        .replaceAllMapped(
          RegExp(r'\[color=(#[0-9A-Fa-f]{6})\]([\s\S]+?)\[/color\]'),
          (match) => match.group(2) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^\)]+\)'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'(^|\n)\s{0,3}#{1,6}\s*', multiLine: true),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'(^|\n)\s*>\s*', multiLine: true),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'(^|\n)\s*[-*+]\s+', multiLine: true),
          (match) => '${match.group(1) ?? ''}• ',
        )
        .replaceAll(RegExp(r'[*_`~]'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
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

    if (maxPreviewLines != null) {
      final previewText = _toPreviewText(text);
      final summary = previewText.isNotEmpty
          ? previewText
          : (parsed.media.isNotEmpty ? '${parsed.media.length} mídia(s) adicionada(s)' : emptyPlaceholder);
      final preview = Text(
        summary,
        maxLines: maxPreviewLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize ?? r.fs(14),
          height: 1.45,
        ),
      );
      if (padding == null) return preview;
      return Padding(padding: padding!, child: preview);
    }

    final children = <Widget>[];

    if (text.isNotEmpty) {
      children.add(
        MarkdownBody(
          data: text,
          selectable: selectable,
          onTapLink: (_, href, __) => _openLink(href),
          inlineSyntaxes: [_RichBioColorSyntax()],
          builders: {_richBioColorTag: _RichBioColorBuilder()},
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

    if (parsed.media.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(SizedBox(height: r.s(14)));
      }
      children.addAll(
        parsed.media.map(
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
  Color? _legacyTextColor;
  String _activeToolSection = 'text';

  static final RegExp _inlineTextColorPattern = RegExp(
    r'\[color=(#[0-9A-Fa-f]{6})\]([\s\S]+?)\[/color\]',
  );

  @override
  void initState() {
    super.initState();
    final content = RichBioCodec.decode(widget.initialValue);
    _controller = TextEditingController(text: content.markdown);
    _focusNode = FocusNode();
    _media = List<RichBioMediaItem>.from(content.media);
    _legacyTextColor = RichBioCodec.parseColor(content.textColorHex);
    _textColor = _legacyTextColor;
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

  bool get _hasInlineTextColors =>
      _inlineTextColorPattern.hasMatch(_controller.text);

  String? get _effectiveGlobalTextColorHex => _hasInlineTextColors
      ? null
      : RichBioCodec.colorToHex(_legacyTextColor);

  void _applyTextColorToSelection(Color color) {
    final hex = RichBioCodec.colorToHex(color);
    if (hex == null) return;

    final value = _controller.value;
    final selection = value.selection;
    final text = value.text;
    final prefix = '[color=$hex]';
    const suffix = '[/color]';

    if (!selection.isValid ||
        selection.start < 0 ||
        selection.end < 0 ||
        selection.isCollapsed) {
      const placeholder = 'texto';
      final insertion = '$prefix$placeholder$suffix';
      final cursor = selection.isValid && selection.start >= 0
          ? selection.start
          : text.length;
      final updated = text.replaceRange(cursor, cursor, insertion);
      _replaceValue(
        updated,
        selection: TextSelection(
          baseOffset: cursor + prefix.length,
          extentOffset: cursor + prefix.length + placeholder.length,
        ),
      );
      setState(() {
        _textColor = color;
        _legacyTextColor = null;
      });
      return;
    }

    final selectedText = text.substring(selection.start, selection.end);
    final updated = text.replaceRange(
      selection.start,
      selection.end,
      '$prefix$selectedText$suffix',
    );
    _replaceValue(
      updated,
      selection: TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.start + prefix.length + selectedText.length,
      ),
    );
    setState(() {
      _textColor = color;
      _legacyTextColor = null;
    });
  }

  Future<void> _pickTextColor() async {
    final selected = await showRGBColorPicker(
      context,
      initialColor: _textColor ?? AppTheme.primaryColor,
      title: 'Cor do texto selecionado',
    );
    if (selected == null || !mounted) return;
    _applyTextColorToSelection(selected);
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
      textColorHex: _effectiveGlobalTextColorHex,
      media: _media,
    );
    return RichBioCodec.encode(content);
  }

  void _insertTemplate(String template) {
    final value = _controller.value;
    final selection = value.selection;
    final text = value.text;
    final insertion = text.trim().isEmpty ? template : '\n\n$template';

    if (!selection.isValid || selection.start < 0 || selection.end < 0) {
      final updated = '$text$insertion';
      _replaceValue(
        updated,
        selection: TextSelection.collapsed(offset: updated.length),
      );
      return;
    }

    final updated = text.replaceRange(selection.start, selection.end, insertion);
    _replaceValue(
      updated,
      selection: TextSelection.collapsed(
        offset: selection.start + insertion.length,
      ),
    );
  }

  void _insertLinkTemplate() {
    final value = _controller.value;
    final selection = value.selection;
    final text = value.text;

    if (!selection.isValid || selection.start < 0 || selection.end < 0) {
      const insertion = '[texto](https://)';
      final updated = '$text${text.isEmpty ? '' : '\n\n'}$insertion';
      _replaceValue(
        updated,
        selection: TextSelection(baseOffset: updated.length - 9, extentOffset: updated.length - 1),
      );
      return;
    }

    final selected = text.substring(selection.start, selection.end);
    final label = selected.isEmpty ? 'texto' : selected;
    final replacement = '[$label](https://)';
    final updated = text.replaceRange(selection.start, selection.end, replacement);
    final urlStart = selection.start + replacement.length - 9;
    _replaceValue(
      updated,
      selection: TextSelection(baseOffset: urlStart, extentOffset: urlStart + 8),
    );
  }

  void _changeMode(bool showPreview) {
    setState(() => _showPreview = showPreview);
    if (showPreview) {
      _focusNode.unfocus();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Widget _buildHeader(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.fromLTRB(r.s(12), r.s(10), r.s(12), r.s(12)),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(20)),
        border: Border.all(color: context.dividerClr),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (_, value, __) {
          final mediaLabel = _media.isEmpty ? 'Sem mídia' : '${_media.length} mídia(s)';

          final chips = <Widget>[
            _StatusPill(
              icon: Icons.auto_awesome_rounded,
              label: 'Markdown',
            ),
            if (_media.isNotEmpty)
              _StatusPill(
                icon: Icons.collections_outlined,
                label: '${_media.length} mídia(s)',
              ),
            if (_textColor != null)
              _StatusPill(
                icon: Icons.palette_outlined,
                label: 'Seleção ${RichBioCodec.colorToHex(_textColor) ?? 'Cor'}',
              ),
            if (_isUploading)
              _StatusPill(
                icon: Icons.cloud_upload_outlined,
                label: 'Enviando...',
              ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: r.fs(17),
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                  SizedBox(width: r.s(8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.s(10),
                      vertical: r.s(6),
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(r.s(999)),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Text(
                      '${value.text.length}/${widget.maxLength}',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.s(8)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(widget.cancelLabel),
                    ),
                  ),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isUploading
                          ? null
                          : () => Navigator.of(context).pop(_buildResult()),
                      child: Text(widget.saveLabel),
                    ),
                  ),
                ],
              ),
              if (chips.isNotEmpty) ...[
                SizedBox(height: r.s(8)),
                SizedBox(
                  height: r.s(32),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: chips.length,
                    separatorBuilder: (_, __) => SizedBox(width: r.s(8)),
                    itemBuilder: (_, index) => chips[index],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildModeSwitch(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.all(r.s(4)),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(18)),
        border: Border.all(color: context.dividerClr),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              icon: Icons.edit_note_rounded,
              label: widget.editorLabel,
              selected: !_showPreview,
              onTap: () => _changeMode(false),
            ),
          ),
          SizedBox(width: r.s(8)),
          Expanded(
            child: _ModeButton(
              icon: Icons.visibility_rounded,
              label: widget.previewLabel,
              selected: _showPreview,
              onTap: () => _changeMode(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorCanvas(BuildContext context) {
    final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(22)),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(r.s(14), r.s(12), r.s(14), r.s(8)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Editor livre',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_textColor != null)
                  Container(
                    width: r.s(12),
                    height: r.s(12),
                    decoration: BoxDecoration(
                      color: _textColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              expands: true,
              maxLength: widget.maxLength,
              textAlignVertical: TextAlignVertical.top,
              scrollPadding: EdgeInsets.fromLTRB(r.s(20), r.s(20), r.s(20), r.s(140)),
              style: TextStyle(
                color: context.textPrimary,
                fontSize: r.fs(15),
                height: 1.55,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: context.textHint,
                  fontSize: r.fs(14),
                  height: 1.45,
                ),
                contentPadding: EdgeInsets.fromLTRB(
                  r.s(16),
                  r.s(14),
                  r.s(16),
                  r.s(18),
                ),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCanvas(BuildContext context) {
    final r = context.r;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (_, value, __) {
          final preview = RichBioContent(
            markdown: value.text,
            textColorHex: _effectiveGlobalTextColorHex,
            media: _media,
          );


        return Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(r.s(22)),
            border: Border.all(color: context.dividerClr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(r.s(14), r.s(12), r.s(14), r.s(8)),
                child: Text(
                  'Prévia',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: r.fs(14),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(r.s(16)),
                  child: RichBioRenderer(
                    rawContent: RichBioCodec.encode(preview),
                    emptyPlaceholder: widget.hintText,
                    fontSize: r.fs(14),
                    fallbackTextColor: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolDock(BuildContext context, {bool compact = false}) {
    final r = context.r;
    final actions = <Widget>[];

    if (_activeToolSection == 'text') {
      actions.addAll([
        _StudioActionTile(
          icon: Icons.format_bold_rounded,
          label: 'Negrito',
          caption: 'Destacar trecho',
          onTap: () => _wrapSelection('**', '**'),
        ),
        _StudioActionTile(
          icon: Icons.format_italic_rounded,
          label: 'Itálico',
          caption: 'Dar tom ao texto',
          onTap: () => _wrapSelection('*', '*'),
        ),
        _StudioActionTile(
          icon: Icons.link_rounded,
          label: 'Link',
          caption: 'Inserir link editável',
          onTap: _insertLinkTemplate,
        ),
        _StudioActionTile(
          icon: Icons.format_strikethrough_rounded,
          label: 'Tachado',
          caption: 'Marcar contraste',
          onTap: () => _wrapSelection('~~', '~~'),
        ),
      ]);
    } else if (_activeToolSection == 'structure') {
      actions.addAll([
        _StudioActionTile(
          icon: Icons.title_rounded,
          label: 'Título',
          caption: 'Criar chamada',
          onTap: () => _toggleLinePrefix('## '),
        ),
        _StudioActionTile(
          icon: Icons.format_quote_rounded,
          label: 'Citação',
          caption: 'Bloco de destaque',
          onTap: () => _toggleLinePrefix('> '),
        ),
        _StudioActionTile(
          icon: Icons.format_list_bulleted_rounded,
          label: 'Lista',
          caption: 'Organizar ideias',
          onTap: () => _toggleLinePrefix('- '),
        ),
        _StudioActionTile(
          icon: Icons.horizontal_rule_rounded,
          label: 'Divisor',
          caption: 'Separar blocos',
          onTap: _insertDivider,
        ),
      ]);
    } else {
      actions.addAll([
        _StudioActionTile(
          icon: Icons.format_color_text_rounded,
          label: 'Cor',
          caption: 'Escolher identidade',
          onTap: _pickTextColor,
        ),
        _StudioActionTile(
          icon: Icons.image_outlined,
          label: 'Imagem',
          caption: 'Adicionar da galeria',
          onTap: _pickAndUploadImage,
        ),
        _StudioActionTile(
          icon: Icons.gif_box_outlined,
          label: 'GIF',
          caption: 'Upload ou busca',
          onTap: _openGifOptions,
        ),
        _StudioActionTile(
          icon: Icons.smart_display_outlined,
          label: 'Vídeo',
          caption: 'Trazer movimento',
          onTap: _pickAndUploadVideo,
        ),
      ]);
    }

    final paletteSelector = compact
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PaletteChip(
                  icon: Icons.text_fields_rounded,
                  label: 'Texto',
                  selected: _activeToolSection == 'text',
                  onTap: () => setState(() => _activeToolSection = 'text'),
                ),
                SizedBox(width: r.s(8)),
                _PaletteChip(
                  icon: Icons.view_agenda_outlined,
                  label: 'Estrutura',
                  selected: _activeToolSection == 'structure',
                  onTap: () => setState(() => _activeToolSection = 'structure'),
                ),
                SizedBox(width: r.s(8)),
                _PaletteChip(
                  icon: Icons.perm_media_outlined,
                  label: 'Mídia',
                  selected: _activeToolSection == 'media',
                  onTap: () => setState(() => _activeToolSection = 'media'),
                ),
              ],
            ),
          )
        : Row(
            children: [
              Expanded(
                child: _PaletteChip(
                  icon: Icons.text_fields_rounded,
                  label: 'Texto',
                  selected: _activeToolSection == 'text',
                  onTap: () => setState(() => _activeToolSection = 'text'),
                ),
              ),
              SizedBox(width: r.s(8)),
              Expanded(
                child: _PaletteChip(
                  icon: Icons.view_agenda_outlined,
                  label: 'Estrutura',
                  selected: _activeToolSection == 'structure',
                  onTap: () => setState(() => _activeToolSection = 'structure'),
                ),
              ),
              SizedBox(width: r.s(8)),
              Expanded(
                child: _PaletteChip(
                  icon: Icons.perm_media_outlined,
                  label: 'Mídia',
                  selected: _activeToolSection == 'media',
                  onTap: () => setState(() => _activeToolSection = 'media'),
                ),
              ),
            ],
          );

    final actionStrip = compact
        ? SizedBox(
            height: r.s(48),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: actions.length,
              separatorBuilder: (_, __) => SizedBox(width: r.s(8)),
              itemBuilder: (_, index) {
                final action = actions[index] as _StudioActionTile;
                return _CompactStudioActionChip(
                  icon: action.icon,
                  label: action.label,
                  onTap: action.onTap,
                );
              },
            ),
          )
        : Wrap(
            spacing: r.s(10),
            runSpacing: r.s(10),
            children: actions,
          );

    final compactTemplates = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _TemplateChip(
            label: 'Sobre mim',
            onTap: () => _insertTemplate('## Sobre mim\nEscreva aqui quem você é.'),
          ),
          SizedBox(width: r.s(8)),
          _TemplateChip(
            label: 'Destaques',
            onTap: () => _insertTemplate('## Destaques\n- Item 1\n- Item 2\n- Item 3'),
          ),
          SizedBox(width: r.s(8)),
          _TemplateChip(
            label: 'Mood',
            onTap: () => _insertTemplate('> Uma frase que define sua vibe.'),
          ),
          SizedBox(width: r.s(8)),
          _TemplateChip(
            label: 'Links',
            onTap: () => _insertTemplate('## Links\n- [Meu link](https://)'),
          ),
        ],
      ),
    );
    final compactMeta = <Widget>[
      if (_textColor != null)
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(6)),
          decoration: BoxDecoration(
            color: (_textColor ?? AppTheme.primaryColor).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(r.s(999)),
            border: Border.all(
              color: (_textColor ?? AppTheme.primaryColor).withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: r.s(10),
                height: r.s(10),
                decoration: BoxDecoration(
                  color: _textColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: r.s(6)),
              Text(
                'Seleção ${RichBioCodec.colorToHex(_textColor) ?? ''}',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: r.fs(11),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      if (_media.isNotEmpty)
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(6)),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(r.s(999)),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.16),
            ),
          ),
          child: Text(
            '${_media.length} mídia(s)',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: r.fs(11),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(22)),
        border: Border.all(color: context.dividerClr),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? r.s(10) : r.s(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (compact)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ferramentas',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (compactMeta.isNotEmpty)
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < compactMeta.length; i++) ...[
                              if (i > 0) SizedBox(width: r.s(6)),
                              compactMeta[i],
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dock criativo',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_textColor != null)
                    compactMeta.first,
                ],
              ),
              SizedBox(height: r.s(4)),
              Text(
                'Ferramentas agrupadas para você focar no que está criando, sem tudo jogado na tela ao mesmo tempo.',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: r.fs(11),
                  height: 1.4,
                ),
              ),
            ],
            SizedBox(height: compact ? r.s(8) : r.s(12)),
            paletteSelector,
            SizedBox(height: compact ? r.s(8) : r.s(12)),
            actionStrip,
            SizedBox(height: compact ? r.s(8) : r.s(12)),
            if (!compact) ...[
              Text(
                'Blocos rápidos',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: r.s(8)),
            ],
            compactTemplates,
            if (!compact && _media.isNotEmpty) ...[
              SizedBox(height: r.s(12)),
              Text(
                'Mídia anexada',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: r.s(8)),
              SizedBox(
                height: r.s(112),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _media.length,
                  separatorBuilder: (_, __) => SizedBox(width: r.s(10)),
                  itemBuilder: (_, index) {
                    final item = _media[index];
                    return Container(
                      width: r.s(132),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(r.s(16)),
                        border: Border.all(color: context.dividerClr),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(r.s(16)),
                            ),
                            child: TappableImage(
                              url: item.url,
                              width: double.infinity,
                              height: r.s(70),
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              r.s(10),
                              r.s(8),
                              r.s(8),
                              r.s(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.type.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: r.fs(11),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(r.s(999)),
                                  onTap: () => setState(() {
                                    _media = _media.where((m) => m.id != item.id).toList();
                                  }),
                                  child: Padding(
                                    padding: EdgeInsets.all(r.s(2)),
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppTheme.errorColor,
                                      size: r.s(18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboardQuickBar(BuildContext context) {
    final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(18)),
        border: Border.all(color: context.dividerClr),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(8)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _MiniStudioButton(
                icon: Icons.format_bold_rounded,
                onTap: () => _wrapSelection('**', '**'),
              ),
              _MiniStudioButton(
                icon: Icons.format_italic_rounded,
                onTap: () => _wrapSelection('*', '*'),
              ),
              _MiniStudioButton(
                icon: Icons.title_rounded,
                onTap: () => _toggleLinePrefix('## '),
              ),
              _MiniStudioButton(
                icon: Icons.format_list_bulleted_rounded,
                onTap: () => _toggleLinePrefix('- '),
              ),
              _MiniStudioButton(
                icon: Icons.link_rounded,
                onTap: _insertLinkTemplate,
              ),
              _MiniStudioButton(
                icon: Icons.format_color_text_rounded,
                onTap: _pickTextColor,
              ),
              _MiniStudioButton(
                icon: Icons.image_outlined,
                onTap: _pickAndUploadImage,
              ),
              _MiniStudioButton(
                icon: Icons.gif_box_outlined,
                onTap: _openGifOptions,
              ),
              _MiniStudioButton(
                icon: Icons.smart_display_outlined,
                onTap: _pickAndUploadVideo,
              ),
              _MiniStudioButton(
                icon: Icons.visibility_rounded,
                onTap: () => _changeMode(true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileStudio(BuildContext context, {required bool keyboardVisible}) {
    final r = context.r;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final compactViewport = availableHeight < r.s(430);
        final spacing = compactViewport ? r.s(6) : r.s(8);
        double dockHeight = compactViewport ? availableHeight * 0.20 : availableHeight * 0.24;
        final minDockHeight = compactViewport ? r.s(108) : r.s(124);
        final maxDockHeight = compactViewport ? r.s(136) : r.s(164);

        if (dockHeight < minDockHeight) dockHeight = minDockHeight;
        if (dockHeight > maxDockHeight) dockHeight = maxDockHeight;

        return Column(
          children: [
            _buildModeSwitch(context),
            SizedBox(height: spacing),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _showPreview
                    ? _buildPreviewCanvas(context)
                    : Column(
                        key: const ValueKey('editor_mode'),
                        children: [
                          Expanded(child: _buildEditorCanvas(context)),
                          SizedBox(height: spacing),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: keyboardVisible
                                ? _buildKeyboardQuickBar(context)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(r.s(20)),
                                    child: SizedBox(
                                      height: dockHeight,
                                      child: _buildToolDock(context, compact: true),
                                    ),
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWideStudio(BuildContext context) {
    final r = context.r;
    return Column(
      children: [
        _buildModeSwitch(context),
        SizedBox(height: r.s(12)),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _buildEditorCanvas(context)),
                    SizedBox(height: r.s(12)),
                    _buildToolDock(context),
                  ],
                ),
              ),
              SizedBox(width: r.s(12)),
              Expanded(child: _buildPreviewCanvas(context)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final maxSheetHeight =
        (mediaQuery.size.height - mediaQuery.padding.top - r.s(8)).clamp(
      mediaQuery.size.height * 0.72,
      mediaQuery.size.height,
    ).toDouble();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 0),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              clipBehavior: Clip.antiAlias,
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(28))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 28,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(r.s(12), r.s(10), r.s(12), r.s(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    SizedBox(height: r.s(10)),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 920;
                          return isWide
                              ? _buildWideStudio(context)
                              : _buildMobileStudio(
                                  context,
                                  keyboardVisible: bottomInset > 0,
                                );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStudioButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniStudioButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(right: r.s(8)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(r.s(12)),
          onTap: onTap,
          child: Ink(
            padding: EdgeInsets.all(r.s(10)),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(color: context.dividerClr),
            ),
            child: Icon(
              icon,
              size: r.s(18),
              color: context.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return InkWell(
      borderRadius: BorderRadius.circular(r.s(14)),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: r.s(14),
          vertical: r.s(12),
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(r.s(14)),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: r.s(18),
              color: selected ? AppTheme.primaryColor : context.textSecondary,
            ),
            SizedBox(width: r.s(8)),
            Text(
              label,
              style: TextStyle(
                color: selected ? context.textPrimary : context.textSecondary,
                fontSize: r.fs(12),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return InkWell(
      borderRadius: BorderRadius.circular(r.s(14)),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: r.s(12),
          vertical: r.s(11),
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentColor.withValues(alpha: 0.14)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(14)),
          border: Border.all(
            color: selected
                ? AppTheme.accentColor.withValues(alpha: 0.35)
                : context.dividerClr,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: r.s(16),
              color: selected ? AppTheme.accentColor : context.textSecondary,
            ),
            SizedBox(width: r.s(7)),
            Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: r.fs(11),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;

  const _StudioActionTile({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return InkWell(
      borderRadius: BorderRadius.circular(r.s(16)),
      onTap: onTap,
      child: Container(
        width: r.s(150),
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(color: context.dividerClr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(r.s(8)),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(r.s(12)),
              ),
              child: Icon(icon, size: r.s(18), color: AppTheme.primaryColor),
            ),
            SizedBox(height: r.s(10)),
            Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: r.fs(12),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: r.s(4)),
            Text(
              caption,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: r.fs(10),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactStudioActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CompactStudioActionChip({
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
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(999)),
          border: Border.all(color: context.dividerClr),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: r.s(16), color: AppTheme.primaryColor),
            SizedBox(width: r.s(8)),
            Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: r.fs(11),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TemplateChip({
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
          vertical: r.s(9),
        ),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(999)),
          border: Border.all(color: context.dividerClr),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: r.fs(11),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.s(10),
        vertical: r.s(8),
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(999)),
        border: Border.all(color: context.dividerClr),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: r.s(14), color: context.textSecondary),
          SizedBox(width: r.s(6)),
          Text(
            label,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: r.fs(11),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
