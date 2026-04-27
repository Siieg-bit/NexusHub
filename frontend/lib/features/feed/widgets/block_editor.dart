import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import 'package:amino_clone/core/widgets/nexus_media_picker.dart';

/// Rich Text Block Editor — Editor de blocos estilo Amino.
///
/// Renderiza como uma área de texto contínua com imagens inline.
/// Sem containers visíveis, sem cards, sem bordas nos blocos.
///
/// Serializa os blocos em formato compatível com o renderer:
/// - texto: `content` e `text`
/// - imagem: `url` e `image_url`
/// - heading: `level`
/// - texto/citação: `bold`, `italic` e `align`
enum BlockType { text, image, divider, heading, quote }

class ContentBlock {
  final String id;
  BlockType type;
  String text;
  String? imageUrl;
  String? caption;
  bool bold;
  bool italic;
  String align;
  int level;
  /// Estilo do divisor: 'dots', 'line', 'dashed', 'stars'
  String dividerStyle;
  TextEditingController? controller;
  TextEditingController? captionController;
  FocusNode? focusNode;

  ContentBlock({
    String? id,
    required this.type,
    this.text = '',
    this.imageUrl,
    this.caption,
    this.bold = false,
    this.italic = false,
    this.align = 'left',
    this.level = 2,
    this.dividerStyle = 'dots',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString() {
    _ensureControllers();
  }

  bool get isTextBased =>
      type == BlockType.text ||
      type == BlockType.heading ||
      type == BlockType.quote;

  void _ensureControllers() {
    if (isTextBased) {
      controller ??= TextEditingController(text: text);
      focusNode ??= FocusNode();
    } else {
      controller?.dispose();
      controller = null;
      focusNode?.dispose();
      focusNode = null;
    }

    if (type == BlockType.image) {
      captionController ??= TextEditingController(text: caption ?? '');
    } else {
      captionController?.dispose();
      captionController = null;
    }
  }

  void syncFromControllers() {
    if (controller != null) text = controller!.text;
    if (captionController != null) caption = captionController!.text.trim();
  }

  void setType(BlockType newType) {
    syncFromControllers();
    type = newType;
    if (type != BlockType.heading) level = 2;
    _ensureControllers();
  }

  Map<String, dynamic> toJson() {
    syncFromControllers();
    final serializedText = text.trim();
    final serializedCaption = caption?.trim();

    return {
      'type': type.name,
      if (isTextBased) 'content': serializedText,
      if (isTextBased) 'text': serializedText,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'url': imageUrl,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
      if (serializedCaption != null && serializedCaption.isNotEmpty)
        'caption': serializedCaption,
      if (type == BlockType.text || type == BlockType.quote) 'bold': bold,
      if (type == BlockType.text || type == BlockType.quote) 'italic': italic,
      if (type == BlockType.text || type == BlockType.quote) 'align': align,
      if (type == BlockType.heading) 'level': level,
      if (type == BlockType.divider) 'divider_style': dividerStyle,
    };
  }

  static ContentBlock fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] as String? ?? 'text').toLowerCase();
    final type = BlockType.values.firstWhere(
      (value) => value.name == rawType,
      orElse: () => BlockType.text,
    );

    return ContentBlock(
      type: type,
      text: (json['content'] ?? json['text'] ?? '') as String,
      imageUrl: (json['url'] ?? json['image_url']) as String?,
      caption: json['caption'] as String?,
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      align: (json['align'] as String?) ?? 'left',
      level: (json['level'] as num?)?.toInt() ?? 2,
      dividerStyle: (json['divider_style'] as String?) ?? 'dots',
    );
  }

  ContentBlock clone() => ContentBlock.fromJson(toJson());

  void dispose() {
    controller?.dispose();
    captionController?.dispose();
    focusNode?.dispose();
  }
}

// =============================================================================
// BlockEditor Widget
// =============================================================================

class BlockEditor extends ConsumerStatefulWidget {
  final List<ContentBlock> initialBlocks;
  final ValueChanged<List<ContentBlock>> onChanged;
  final String communityId;

  /// Placeholder para o primeiro bloco de texto quando vazio.
  final String? placeholder;

  /// Se false, esconde a barra de adicionar blocos no final.
  final bool showAddBar;

  const BlockEditor({
    super.key,
    this.initialBlocks = const [],
    required this.onChanged,
    required this.communityId,
    this.placeholder,
    this.showAddBar = true,
  });

  @override
  ConsumerState<BlockEditor> createState() => BlockEditorState();
}

class BlockEditorState extends ConsumerState<BlockEditor> {
  late List<ContentBlock> _blocks;
  int? _focusedBlockIndex;
  bool _isUploading = false;

  /// Foca no último bloco de texto (chamado externamente via GlobalKey)
  void focusLastTextBlock() {
    for (int i = _blocks.length - 1; i >= 0; i--) {
      if (_blocks[i].isTextBased && _blocks[i].focusNode != null) {
        setState(() => _focusedBlockIndex = i);
        _blocks[i].focusNode!.requestFocus();
        final controller = _blocks[i].controller;
        if (controller != null) {
          controller.selection = TextSelection.collapsed(
            offset: controller.text.length,
          );
        }
        return;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _blocks = widget.initialBlocks.isNotEmpty
        ? widget.initialBlocks.map((block) => block.clone()).toList()
        : [ContentBlock(type: BlockType.text)];
  }

  @override
  void dispose() {
    for (final block in _blocks) {
      block.dispose();
    }
    super.dispose();
  }

  void _notifyChanged() {
    for (final block in _blocks) {
      block.syncFromControllers();
    }
    widget.onChanged(_blocks.map((block) => block.clone()).toList());
  }

  void _addBlock(BlockType type, {int? afterIndex}) {
    addBlock(type, afterIndex: afterIndex);
  }

  /// Adiciona um bloco (acessível externamente via GlobalKey)
  void addBlock(BlockType type, {int? afterIndex}) {
    final insertIndex = (afterIndex ?? (_blocks.length - 1)) + 1;
    final block = ContentBlock(type: type);
    setState(() {
      _blocks.insert(insertIndex, block);
      _focusedBlockIndex = insertIndex;
    });
    _notifyChanged();
    if (block.isTextBased && block.focusNode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) block.focusNode!.requestFocus();
      });
    }
  }

  void _removeBlock(int index) {
    if (_blocks.length <= 1) return;
    setState(() {
      _blocks[index].dispose();
      _blocks.removeAt(index);
      if (_focusedBlockIndex == index) _focusedBlockIndex = null;
    });
    _notifyChanged();
  }

  void _moveBlock(int from, int to) {
    if (to < 0 || to >= _blocks.length) return;
    setState(() {
      final block = _blocks.removeAt(from);
      _blocks.insert(to, block);
      _focusedBlockIndex = to;
    });
    _notifyChanged();
  }

  void _changeTextBlockType(int index, BlockType nextType) {
    if (!(nextType == BlockType.text ||
        nextType == BlockType.heading ||
        nextType == BlockType.quote)) {
      return;
    }
    setState(() {
      _blocks[index].setType(nextType);
      _focusedBlockIndex = index;
    });
    // Foca após o rebuild para evitar crash de TextPainter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _blocks.length > index) {
        _blocks[index].focusNode?.requestFocus();
      }
    });
    _notifyChanged();
  }

  void _toggleBold(int index) {
    setState(() => _blocks[index].bold = !_blocks[index].bold);
    _notifyChanged();
  }

  void _toggleItalic(int index) {
    setState(() => _blocks[index].italic = !_blocks[index].italic);
    _notifyChanged();
  }

  /// Insere um link no formato Markdown [texto](url) no cursor do bloco.
  Future<void> _insertLink(int index, BuildContext context) async {
    final block = _blocks[index];
    if (!block.isTextBased || block.controller == null) return;
    final ctrl = block.controller!;
    final selection = ctrl.selection;
    final selectedText = selection.isValid && !selection.isCollapsed
        ? ctrl.text.substring(selection.start, selection.end)
        : '';
    // Mostrar dialog para inserir URL e texto do link
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _LinkInsertDialog(initialText: selectedText),
    );
    if (result == null) return;
    final linkText = result['text'] ?? '';
    final linkUrl = result['url'] ?? '';
    if (linkUrl.isEmpty) return;
    final markdownLink = '[${linkText.isEmpty ? linkUrl : linkText}]($linkUrl)';
    final newText = selection.isValid && !selection.isCollapsed
        ? ctrl.text.replaceRange(selection.start, selection.end, markdownLink)
        : ctrl.text + markdownLink;
    ctrl.text = newText;
    ctrl.selection = TextSelection.collapsed(
      offset: selection.isValid && !selection.isCollapsed
          ? selection.start + markdownLink.length
          : newText.length,
    );
    block.text = ctrl.text;
    _notifyChanged();
  }

  void _cycleAlignment(int index) {
    const alignments = ['left', 'center', 'right'];
    final current = _blocks[index].align;
    final next =
        alignments[(alignments.indexOf(current) + 1) % alignments.length];
    setState(() => _blocks[index].align = next);
    _notifyChanged();
  }

  void _changeHeadingLevel(int index, int level) {
    setState(() => _blocks[index].level = level);
    _notifyChanged();
  }

  void _changeDividerStyle(int index, String style) {
    setState(() => _blocks[index].dividerStyle = style);
    _notifyChanged();
  }

  Future<void> _pickImageForBlock(int index) async {
    final s = ref.read(stringsProvider);
    final _pickedFiles_image = await showNexusMediaPicker(
  context,
  maxSelect: 1,
  mode: NexusPickerMode.imageOnly,
);
if (_pickedFiles_image.isEmpty) return;
final image = _pickedFiles_image.first.file;
    if (!mounted || image == null) return;

    setState(() {
      _isUploading = true;
      _focusedBlockIndex = index;
    });

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final bytes = await image.readAsBytes();
      final path =
          'posts/${widget.communityId}/$userId/${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';

      await SupabaseService.client.storage
          .from('post-media')
          .uploadBinary(path, bytes);

      final publicUrl =
          SupabaseService.client.storage.from('post-media').getPublicUrl(path);

      if (!mounted) return;
      setState(() {
        _blocks[index].imageUrl = publicUrl;
        _isUploading = false;
      });
      _notifyChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.errorUploadTryAgain),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Insere bloco de imagem com picker (acessível externamente via GlobalKey)
  Future<void> insertImageBlock({int? afterIndex}) async {
    final insertIndex = (afterIndex ?? (_blocks.length - 1)) + 1;
    final block = ContentBlock(type: BlockType.image);

    setState(() {
      _blocks.insert(insertIndex, block);
      _focusedBlockIndex = insertIndex;
    });
    final _pickedFiles_image = await showNexusMediaPicker(
  context,
  maxSelect: 1,
  mode: NexusPickerMode.imageOnly,
);
if (_pickedFiles_image.isEmpty) return;
final image = _pickedFiles_image.first.file;
    if (!mounted) return;

    if (image == null) {
      setState(() {
        _blocks[insertIndex].dispose();
        _blocks.removeAt(insertIndex);
        _focusedBlockIndex = null;
      });
      _notifyChanged();
      return;
    }

    setState(() => _isUploading = true);

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final bytes = await image.readAsBytes();
      final path =
          'posts/${widget.communityId}/$userId/${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';

      await SupabaseService.client.storage
          .from('post-media')
          .uploadBinary(path, bytes);

      final publicUrl =
          SupabaseService.client.storage.from('post-media').getPublicUrl(path);

      if (!mounted) return;
      setState(() {
        _blocks[insertIndex].imageUrl = publicUrl;
        _isUploading = false;
      });

      _notifyChanged();
      _addBlock(BlockType.text, afterIndex: insertIndex);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(stringsProvider).errorUploadTryAgain),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Usar ListView.builder normal em vez de ReorderableListView
        // para evitar conflitos de gestos com TextField.
        // Reordenação é feita via botões de mover no toolbar.
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _blocks.length,
          itemBuilder: (context, index) {
            final block = _blocks[index];
            String? blockPlaceholder;
            if (index == 0 && block.isTextBased && widget.placeholder != null) {
              blockPlaceholder = widget.placeholder;
            }
            return _SeamlessBlock(
              key: ValueKey(block.id),
              block: block,
              index: index,
              isFocused: _focusedBlockIndex == index,
              isUploading: _isUploading && _focusedBlockIndex == index,
              placeholder: blockPlaceholder,
              totalBlocks: _blocks.length,
              onFocus: () => setState(() => _focusedBlockIndex = index),
              onRemove: () => _removeBlock(index),
              onPickImage: () => _pickImageForBlock(index),
              onTextChanged: (_) => _notifyChanged(),
              onCaptionChanged: (_) => _notifyChanged(),
              onToggleBold: () => _toggleBold(index),
              onToggleItalic: () => _toggleItalic(index),
              onCycleAlignment: () => _cycleAlignment(index),
              onTypeChanged: (t) => _changeTextBlockType(index, t),
              onHeadingLevelChanged: (l) => _changeHeadingLevel(index, l),
              onMoveUp: index > 0 ? () => _moveBlock(index, index - 1) : null,
              onMoveDown: index < _blocks.length - 1
                  ? () => _moveBlock(index, index + 1)
                  : null,
              onDividerStyleChanged: block.type == BlockType.divider
                  ? (style) => _changeDividerStyle(index, style)
                  : null,
              onInsertLink: block.isTextBased
                  ? () => _insertLink(index, context)
                  : null,
            );
          },
        ),
        if (widget.showAddBar) ...[
          SizedBox(height: r.s(10)),
          _AddBlockBar(
            onAddText: () => _addBlock(BlockType.text),
            onAddImage: () => insertImageBlock(),
            onAddDivider: () => _addBlock(BlockType.divider),
            onAddHeading: () => _addBlock(BlockType.heading),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// _SeamlessBlock — bloco individual sem container visível
// =============================================================================

class _SeamlessBlock extends ConsumerWidget {
  final ContentBlock block;
  final int index;
  final bool isFocused;
  final bool isUploading;
  final String? placeholder;
  final int totalBlocks;
  final VoidCallback onFocus;
  final VoidCallback onRemove;
  final VoidCallback onPickImage;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<String> onCaptionChanged;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleItalic;
  final VoidCallback onCycleAlignment;
  final ValueChanged<BlockType> onTypeChanged;
  final ValueChanged<int> onHeadingLevelChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final ValueChanged<String>? onDividerStyleChanged;
  final VoidCallback? onInsertLink;

  const _SeamlessBlock({
    super.key,
    required this.block,
    required this.index,
    required this.isFocused,
    required this.isUploading,
    this.placeholder,
    required this.totalBlocks,
    required this.onFocus,
    required this.onRemove,
    required this.onPickImage,
    required this.onTextChanged,
    required this.onCaptionChanged,
    required this.onToggleBold,
    required this.onToggleItalic,
    required this.onCycleAlignment,
    required this.onTypeChanged,
    required this.onHeadingLevelChanged,
    this.onMoveUp,
    this.onMoveDown,
    this.onDividerStyleChanged,
    this.onInsertLink,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;

    return GestureDetector(
      onTap: onFocus,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toolbar de formatação para blocos de texto focados
          if (isFocused && block.isTextBased)
            _InlineFormatBar(
              block: block,
              canRemove: totalBlocks > 1,
              onToggleBold: onToggleBold,
              onToggleItalic: onToggleItalic,
              onCycleAlignment: onCycleAlignment,
              onTypeChanged: onTypeChanged,
              onHeadingLevelChanged: onHeadingLevelChanged,
              onRemove: onRemove,
              onMoveUp: onMoveUp,
              onMoveDown: onMoveDown,
              onInsertLink: onInsertLink,
            ),
          // Toolbar para divisor focado
          if (isFocused && block.type == BlockType.divider)
            _DividerToolbar(
              currentStyle: block.dividerStyle,
              canRemove: totalBlocks > 1,
              onStyleChanged: onDividerStyleChanged ?? (_) {},
              onRemove: onRemove,
              onMoveUp: onMoveUp,
              onMoveDown: onMoveDown,
            ),
          _buildContent(context, r),
          // Ações de imagem focada
          if (isFocused && block.type == BlockType.image)
            _ImageToolbar(
              totalBlocks: totalBlocks,
              onPickImage: onPickImage,
              onRemove: onRemove,
              onMoveUp: onMoveUp,
              onMoveDown: onMoveDown,
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, Responsive r) {
    final s = getStrings();

    switch (block.type) {
      case BlockType.text:
      case BlockType.quote:
      case BlockType.heading:
        final isHeading = block.type == BlockType.heading;
        final isQuote = block.type == BlockType.quote;
        final baseStyle = TextStyle(
          fontSize: isHeading
              ? (block.level == 1
                  ? r.fs(18)
                  : block.level == 2
                      ? r.fs(16)
                      : r.fs(14))
              : r.fs(14),
          height: 1.6,
          color: context.nexusTheme.textPrimary,
          fontWeight:
              isHeading || block.bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle:
              block.italic || isQuote ? FontStyle.italic : FontStyle.normal,
        );

        final hintText = placeholder ??
            (isHeading
                ? 'Subtítulo'
                : isQuote
                    ? 'Citação...'
                    : s.writeHereHint);

        // Usar textAlign fixo baseado no valor atual do bloco
        final textAlign = _parseTextAlign(block.align);

        final field = TextField(
          controller: block.controller,
          focusNode: block.focusNode,
          textAlign: textAlign,
          style: baseStyle,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: context.nexusTheme.textHint.withValues(alpha: 0.4),
              fontSize: baseStyle.fontSize,
              fontWeight: isHeading ? FontWeight.w700 : FontWeight.w400,
              fontStyle: isQuote ? FontStyle.italic : FontStyle.normal,
            ),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          maxLines: null,
          onTap: onFocus,
          onChanged: onTextChanged,
        );

        if (!isQuote) return field;

        return Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: context.nexusTheme.accentSecondary.withValues(alpha: 0.4),
                width: r.s(2),
              ),
            ),
          ),
          padding: EdgeInsets.only(left: r.s(8)),
          child: field,
        );

      case BlockType.image:
        if (isUploading) {
          return Container(
            height: r.s(100),
            margin: EdgeInsets.symmetric(vertical: r.s(4)),
            decoration: BoxDecoration(
              color: context.nexusTheme.backgroundPrimary,
              borderRadius: BorderRadius.circular(r.s(6)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: r.s(18),
                    height: r.s(18),
                    child: CircularProgressIndicator(
                      color: context.nexusTheme.accentSecondary,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(height: r.s(4)),
                  Text(
                    s.sendingImage,
                    style: TextStyle(
                        color: context.nexusTheme.textSecondary, fontSize: r.fs(10)),
                  ),
                ],
              ),
            ),
          );
        }

        if (block.imageUrl == null || block.imageUrl!.isEmpty) {
          return GestureDetector(
            onTap: onPickImage,
            child: Container(
              height: r.s(80),
              margin: EdgeInsets.symmetric(vertical: r.s(4)),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: context.nexusTheme.textHint.withValues(alpha: 0.5),
                      size: r.s(20),
                    ),
                    SizedBox(width: r.s(6)),
                    Text(
                      s.tapToAddImage,
                      style: TextStyle(
                        color: context.nexusTheme.textHint.withValues(alpha: 0.5),
                        fontSize: r.fs(12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(vertical: r.s(6)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(r.s(6)),
                child: Image.network(
                  block.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: r.s(80),
                    color: context.surfaceColor,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: context.nexusTheme.textHint,
                        size: r.s(20),
                      ),
                    ),
                  ),
                ),
              ),
              TextField(
                controller: block.captionController,
                style: TextStyle(
                  color: context.nexusTheme.textSecondary,
                  fontSize: r.fs(11),
                  fontStyle: FontStyle.italic,
                ),
                decoration: InputDecoration(
                  hintText: 'Legenda (opcional)',
                  hintStyle: TextStyle(
                    color: context.nexusTheme.textHint.withValues(alpha: 0.3),
                    fontSize: r.fs(11),
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onTap: onFocus,
                onChanged: onCaptionChanged,
              ),
            ],
          ),
        );

      case BlockType.divider:
        return GestureDetector(
          onTap: onFocus,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: r.s(10)),
            child: _buildDividerContent(context, r, block.dividerStyle),
          ),
        );
    }
  }

  Widget _buildDividerContent(
      BuildContext context, Responsive r, String style) {
    final color = context.nexusTheme.textHint.withValues(alpha: 0.3);
    final softPink = const Color(0xFFE8A0BF).withValues(alpha: 0.6);
    final softPurple = const Color(0xFFB983FF).withValues(alpha: 0.6);
    final softBlue = const Color(0xFF94B3FD).withValues(alpha: 0.5);

    switch (style) {
      // --- Estilos clássicos ---
      case 'line':
        return Container(
          height: 1,
          margin: EdgeInsets.symmetric(horizontal: r.s(20)),
          color: color,
        );
      case 'dashed':
        return Padding(
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
      case 'dots':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (_) => Container(
              margin: EdgeInsets.symmetric(horizontal: r.s(3)),
              width: r.s(3),
              height: r.s(3),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );

      // --- Estilos fofinhos / estéticos ---
      case 'hearts':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '♡ ♥ ♡ ♥ ♡',
              style: TextStyle(color: softPink, fontSize: r.fs(14), letterSpacing: 4),
            ),
          ],
        );
      case 'sparkles':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '✩ · ✩ · ✩ · ✩',
              style: TextStyle(color: softPurple, fontSize: r.fs(14), letterSpacing: 3),
            ),
          ],
        );
      case 'flowers':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '❀ • ✿ • ❀ • ✿ • ❀',
              style: TextStyle(color: softPink, fontSize: r.fs(13), letterSpacing: 2),
            ),
          ],
        );
      case 'stars':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '☆ ★ ☆ ★ ☆',
              style: TextStyle(color: softPurple, fontSize: r.fs(13), letterSpacing: 4),
            ),
          ],
        );
      case 'moon':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '✩ ☽ ✩',
              style: TextStyle(color: softBlue, fontSize: r.fs(15), letterSpacing: 6),
            ),
          ],
        );
      case 'ribbon':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '── ♡ ─── ♡ ──',
              style: TextStyle(color: softPink, fontSize: r.fs(12), letterSpacing: 1),
            ),
          ],
        );
      case 'wave':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '∼∼∼∼∼∼∼∼∼∼',
              style: TextStyle(color: softBlue, fontSize: r.fs(14), letterSpacing: 2),
            ),
          ],
        );
      case 'butterfly':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '•·•·• ๑ •·•·•',
              style: TextStyle(color: softPurple, fontSize: r.fs(13), letterSpacing: 1),
            ),
          ],
        );
      default:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (_) => Container(
              margin: EdgeInsets.symmetric(horizontal: r.s(3)),
              width: r.s(3),
              height: r.s(3),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
    }
  }
}

// =============================================================================
// _InlineFormatBar — barra de formatação para blocos de texto
// =============================================================================

class _InlineFormatBar extends StatelessWidget {
  final ContentBlock block;
  final bool canRemove;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleItalic;
  final VoidCallback onCycleAlignment;
  final ValueChanged<BlockType> onTypeChanged;
  final ValueChanged<int> onHeadingLevelChanged;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onInsertLink;

  const _InlineFormatBar({
    required this.block,
    required this.canRemove,
    required this.onToggleBold,
    required this.onToggleItalic,
    required this.onCycleAlignment,
    required this.onTypeChanged,
    required this.onHeadingLevelChanged,
    required this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
    this.onInsertLink,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Padding(
      padding: EdgeInsets.only(bottom: r.s(4)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Tipo de bloco
            PopupMenuButton<BlockType>(
              tooltip: 'Estilo',
              color: context.surfaceColor,
              onSelected: onTypeChanged,
              itemBuilder: (_) => const [
                PopupMenuItem(value: BlockType.text, child: Text('Texto')),
                PopupMenuItem(
                    value: BlockType.heading, child: Text('Subtítulo')),
                PopupMenuItem(value: BlockType.quote, child: Text('Citação')),
              ],
              child: _MiniChip(
                label: switch (block.type) {
                  BlockType.heading => 'H',
                  BlockType.quote => 'Q',
                  _ => 'T',
                },
              ),
            ),
            SizedBox(width: r.s(4)),
            _MiniIconBtn(
              icon: Icons.format_bold_rounded,
              selected: block.bold,
              onTap: onToggleBold,
            ),
            SizedBox(width: r.s(2)),
            _MiniIconBtn(
              icon: Icons.format_italic_rounded,
              selected: block.italic,
              onTap: onToggleItalic,
            ),
            SizedBox(width: r.s(2)),
            _MiniIconBtn(
              icon: _alignmentIcon(block.align),
              selected: false,
              onTap: onCycleAlignment,
            ),
            if (onInsertLink != null) ...[  
              SizedBox(width: r.s(2)),
              _MiniIconBtn(
                icon: Icons.link_rounded,
                selected: false,
                onTap: onInsertLink!,
              ),
            ],
            if (block.type == BlockType.heading) ...[
              SizedBox(width: r.s(2)),
              PopupMenuButton<int>(
                tooltip: 'Nível',
                color: context.surfaceColor,
                onSelected: onHeadingLevelChanged,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 1, child: Text('H1')),
                  PopupMenuItem(value: 2, child: Text('H2')),
                  PopupMenuItem(value: 3, child: Text('H3')),
                ],
                child: _MiniChip(label: 'H${block.level}'),
              ),
            ],
            // Separador visual
            SizedBox(width: r.s(6)),
            Container(
              width: 1,
              height: r.s(16),
              color: context.dividerClr.withValues(alpha: 0.3),
            ),
            SizedBox(width: r.s(4)),
            // Mover para cima
            if (onMoveUp != null)
              _MiniIconBtn(
                icon: Icons.arrow_upward_rounded,
                selected: false,
                onTap: onMoveUp!,
              ),
            // Mover para baixo
            if (onMoveDown != null)
              _MiniIconBtn(
                icon: Icons.arrow_downward_rounded,
                selected: false,
                onTap: onMoveDown!,
              ),
            if (canRemove) ...[
              SizedBox(width: r.s(4)),
              _MiniIconBtn(
                icon: Icons.close_rounded,
                selected: false,
                onTap: onRemove,
                color: context.nexusTheme.error.withValues(alpha: 0.6),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _DividerToolbar — toolbar para blocos de divisor
// =============================================================================

class _DividerToolbar extends StatelessWidget {
  final String currentStyle;
  final bool canRemove;
  final ValueChanged<String> onStyleChanged;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _DividerToolbar({
    required this.currentStyle,
    required this.canRemove,
    required this.onStyleChanged,
    required this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Padding(
      padding: EdgeInsets.only(bottom: r.s(4)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Estilos clássicos
            _DividerStyleChip(
              label: '•••',
              isSelected: currentStyle == 'dots',
              onTap: () => onStyleChanged('dots'),
            ),
            SizedBox(width: r.s(4)),
            _DividerStyleChip(
              label: '───',
              isSelected: currentStyle == 'line',
              onTap: () => onStyleChanged('line'),
            ),
            SizedBox(width: r.s(4)),
            _DividerStyleChip(
              label: '- - -',
              isSelected: currentStyle == 'dashed',
              onTap: () => onStyleChanged('dashed'),
            ),
            SizedBox(width: r.s(4)),
            // Estilos fofinhos
            _DividerStyleChip(
              label: '♡♥♡',
              isSelected: currentStyle == 'hearts',
              onTap: () => onStyleChanged('hearts'),
            ),
            SizedBox(width: r.s(4)),
            _DividerStyleChip(
              label: '✩·✩',
              isSelected: currentStyle == 'sparkles',
              onTap: () => onStyleChanged('sparkles'),
            ),
            SizedBox(width: r.s(4)),
            _DividerStyleChip(
              label: '✿❀✿',
              isSelected: currentStyle == 'flowers',
              onTap: () => onStyleChanged('flowers'),
            ),
            SizedBox(width: r.s(4)),
            _DividerStyleChip(
              label: '☆★☆',
              isSelected: currentStyle == 'stars',
              onTap: () => onStyleChanged('stars'),
            ),
            SizedBox(width: r.s(4)),
            _DividerStyleChip(
              label: '☽✩',
              isSelected: currentStyle == 'moon',
              onTap: () => onStyleChanged('moon'),
            ),
            SizedBox(width: r.s(4)),
            _DividerStyleChip(
              label: '─♡─',
              isSelected: currentStyle == 'ribbon',
              onTap: () => onStyleChanged('ribbon'),
            ),
            SizedBox(width: r.s(4)),
            _DividerStyleChip(
              label: '∼∼∼',
              isSelected: currentStyle == 'wave',
              onTap: () => onStyleChanged('wave'),
            ),
            SizedBox(width: r.s(4)),
            _DividerStyleChip(
              label: '๑',
              isSelected: currentStyle == 'butterfly',
              onTap: () => onStyleChanged('butterfly'),
            ),
            // Separador visual
            SizedBox(width: r.s(6)),
            Container(
              width: 1,
              height: r.s(16),
              color: context.dividerClr.withValues(alpha: 0.3),
            ),
            SizedBox(width: r.s(4)),
            // Mover para cima
            if (onMoveUp != null)
              _MiniIconBtn(
                icon: Icons.arrow_upward_rounded,
                selected: false,
                onTap: onMoveUp!,
              ),
            // Mover para baixo
            if (onMoveDown != null)
              _MiniIconBtn(
                icon: Icons.arrow_downward_rounded,
                selected: false,
                onTap: onMoveDown!,
              ),
            if (canRemove) ...[
              SizedBox(width: r.s(4)),
              _MiniIconBtn(
                icon: Icons.close_rounded,
                selected: false,
                onTap: onRemove,
                color: context.nexusTheme.error.withValues(alpha: 0.6),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _ImageToolbar — toolbar para blocos de imagem
// =============================================================================

class _ImageToolbar extends StatelessWidget {
  final int totalBlocks;
  final VoidCallback onPickImage;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _ImageToolbar({
    required this.totalBlocks,
    required this.onPickImage,
    required this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Padding(
      padding: EdgeInsets.only(top: r.s(2)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            GestureDetector(
              onTap: onPickImage,
              child: Text(
                'Trocar',
                style: TextStyle(
                  color: context.nexusTheme.accentSecondary.withValues(alpha: 0.7),
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: r.s(12)),
            if (totalBlocks > 1)
              GestureDetector(
                onTap: onRemove,
                child: Text(
                  'Remover',
                  style: TextStyle(
                    color: context.nexusTheme.error.withValues(alpha: 0.7),
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            // Separador visual
            SizedBox(width: r.s(8)),
            Container(
              width: 1,
              height: r.s(16),
              color: context.dividerClr.withValues(alpha: 0.3),
            ),
            SizedBox(width: r.s(6)),
            // Mover para cima
            if (onMoveUp != null)
              _MiniIconBtn(
                icon: Icons.arrow_upward_rounded,
                selected: false,
                onTap: onMoveUp!,
              ),
            // Mover para baixo
            if (onMoveDown != null)
              _MiniIconBtn(
                icon: Icons.arrow_downward_rounded,
                selected: false,
                onTap: onMoveDown!,
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _AddBlockBar
// =============================================================================

class _AddBlockBar extends ConsumerWidget {
  final VoidCallback onAddText;
  final VoidCallback onAddImage;
  final VoidCallback onAddDivider;
  final VoidCallback onAddHeading;

  const _AddBlockBar({
    required this.onAddText,
    required this.onAddImage,
    required this.onAddDivider,
    required this.onAddHeading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;

    return Container(
      padding: EdgeInsets.symmetric(vertical: r.s(6), horizontal: r.s(6)),
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(r.s(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _AddBlockButton(
            icon: Icons.text_fields_rounded,
            label: s.text,
            color: const Color(0xFF4CAF50),
            onTap: onAddText,
          ),
          _AddBlockButton(
            icon: Icons.image_rounded,
            label: s.image,
            color: const Color(0xFF2196F3),
            onTap: onAddImage,
          ),
          _AddBlockButton(
            icon: Icons.title_rounded,
            label: 'Subtítulo',
            color: const Color(0xFFFF9800),
            onTap: onAddHeading,
          ),
          _AddBlockButton(
            icon: Icons.horizontal_rule_rounded,
            label: s.divider,
            color: const Color(0xFF9C27B0),
            onTap: onAddDivider,
          ),
        ],
      ),
    );
  }
}

class _AddBlockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AddBlockButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: r.s(32),
            height: r.s(32),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.s(8)),
            ),
            child: Icon(icon, color: color, size: r.s(16)),
          ),
          SizedBox(height: r.s(2)),
          Text(
            label,
            style: TextStyle(
              color: context.nexusTheme.textSecondary,
              fontSize: r.fs(9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Widgets auxiliares
// =============================================================================

class _MiniChip extends StatelessWidget {
  final String label;

  const _MiniChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(5)),
      decoration: BoxDecoration(
        color: context.surfaceColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(r.s(12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.nexusTheme.textPrimary,
          fontSize: r.fs(14),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniIconBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _MiniIconBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r.s(12)),
      child: Padding(
        padding: EdgeInsets.all(r.s(6)),
        child: Icon(
          icon,
          size: r.s(20),
          color: color ??
              (selected ? context.nexusTheme.accentSecondary : context.nexusTheme.textSecondary),
        ),
      ),
    );
  }
}

class _DividerStyleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DividerStyleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(5)),
        decoration: BoxDecoration(
          color: isSelected
              ? context.nexusTheme.accentSecondary.withValues(alpha: 0.15)
              : context.surfaceColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(r.s(12)),
          border: isSelected
              ? Border.all(
                  color: context.nexusTheme.accentSecondary.withValues(alpha: 0.4),
                  width: 1,
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? context.nexusTheme.accentSecondary : context.nexusTheme.textPrimary,
            fontSize: r.fs(12),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

TextAlign _parseTextAlign(String align) {
  switch (align) {
    case 'center':
      return TextAlign.center;
    case 'right':
      return TextAlign.right;
    default:
      return TextAlign.left;
  }
}

IconData _alignmentIcon(String align) {
  switch (align) {
    case 'center':
      return Icons.format_align_center_rounded;
    case 'right':
      return Icons.format_align_right_rounded;
    default:
      return Icons.format_align_left_rounded;
  }
}

// =============================================================================
// _LinkInsertDialog — Dialog para inserir link no formato Markdown
// =============================================================================
class _LinkInsertDialog extends StatefulWidget {
  final String initialText;
  const _LinkInsertDialog({this.initialText = ''});

  @override
  State<_LinkInsertDialog> createState() => _LinkInsertDialogState();
}

class _LinkInsertDialogState extends State<_LinkInsertDialog> {
  late final TextEditingController _textCtrl;
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.initialText);
    _urlCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return AlertDialog(
      backgroundColor: context.surfaceColor,
      title: Text(
        'Inserir link',
        style: TextStyle(
          color: context.nexusTheme.textPrimary,
          fontSize: r.fs(16),
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textCtrl,
            style: TextStyle(color: context.nexusTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Texto do link',
              labelStyle: TextStyle(color: context.nexusTheme.textSecondary),
              hintText: 'Ex: Clique aqui',
              hintStyle: TextStyle(color: context.nexusTheme.textSecondary.withValues(alpha: 0.5)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.nexusTheme.textSecondary.withValues(alpha: 0.3)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.nexusTheme.accentPrimary),
              ),
            ),
          ),
          SizedBox(height: r.s(12)),
          TextField(
            controller: _urlCtrl,
            style: TextStyle(color: context.nexusTheme.textPrimary),
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'URL',
              labelStyle: TextStyle(color: context.nexusTheme.textSecondary),
              hintText: 'https://...',
              hintStyle: TextStyle(color: context.nexusTheme.textSecondary.withValues(alpha: 0.5)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.nexusTheme.textSecondary.withValues(alpha: 0.3)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.nexusTheme.accentPrimary),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: TextStyle(color: context.nexusTheme.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            final url = _urlCtrl.text.trim();
            if (url.isEmpty) return;
            Navigator.of(context).pop({
              'text': _textCtrl.text.trim(),
              'url': url,
            });
          },
          child: Text(
            'Inserir',
            style: TextStyle(
              color: context.nexusTheme.accentPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
