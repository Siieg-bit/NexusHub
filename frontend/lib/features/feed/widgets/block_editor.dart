import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/app_theme.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

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
        // Move cursor para o final do texto
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
    final insertIndex = (afterIndex ?? (_blocks.length - 1)) + 1;
    final block = ContentBlock(type: type);
    setState(() {
      _blocks.insert(insertIndex, block);
      _focusedBlockIndex = insertIndex;
    });
    _notifyChanged();
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

  Future<void> _pickImageForBlock(int index) async {
    final s = ref.read(stringsProvider);
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted || image == null) return;

    setState(() {
      _isUploading = true;
      _focusedBlockIndex = index;
    });

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final bytes = await image.readAsBytes();
      final path =
          'posts/${widget.communityId}/$userId/${DateTime.now().millisecondsSinceEpoch}_${image.name}';

      await SupabaseService.client.storage
          .from('post_media')
          .uploadBinary(path, bytes);

      final publicUrl =
          SupabaseService.client.storage.from('post_media').getPublicUrl(path);

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
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _insertImageBlock({int? afterIndex}) async {
    final insertIndex = (afterIndex ?? (_blocks.length - 1)) + 1;
    final block = ContentBlock(type: BlockType.image);

    setState(() {
      _blocks.insert(insertIndex, block);
      _focusedBlockIndex = insertIndex;
    });

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
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
          'posts/${widget.communityId}/$userId/${DateTime.now().millisecondsSinceEpoch}_${image.name}';

      await SupabaseService.client.storage
          .from('post_media')
          .uploadBinary(path, bytes);

      final publicUrl =
          SupabaseService.client.storage.from('post_media').getPublicUrl(path);

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
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    // Renderiza como uma lista contínua sem separação visual entre blocos
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _blocks.length,
          onReorder: (from, to) {
            if (to > from) to--;
            _moveBlock(from, to);
          },
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) => Material(
                color: Colors.transparent,
                elevation: 2,
                child: child,
              ),
            );
          },
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
            );
          },
        ),
        if (widget.showAddBar) ...[
          SizedBox(height: r.s(10)),
          _AddBlockBar(
            onAddText: () => _addBlock(BlockType.text),
            onAddImage: () => _insertImageBlock(),
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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;

    return GestureDetector(
      onTap: onFocus,
      // Sem padding, sem margin, sem decoration — completamente transparente
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toolbar de formatação — aparece discretamente acima do bloco focado
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
            ),
          _buildContent(context, r),
          // Ações de imagem focada
          if (isFocused && block.type == BlockType.image && totalBlocks > 1)
            Padding(
              padding: EdgeInsets.only(top: r.s(2)),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onPickImage,
                    child: Text(
                      'Trocar',
                      style: TextStyle(
                        color: AppTheme.accentColor.withValues(alpha: 0.7),
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: r.s(12)),
                  GestureDetector(
                    onTap: onRemove,
                    child: Text(
                      'Remover',
                      style: TextStyle(
                        color: AppTheme.errorColor.withValues(alpha: 0.7),
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
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
          color: context.textPrimary,
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

        final field = TextField(
          controller: block.controller,
          focusNode: block.focusNode,
          textAlign: _parseTextAlign(block.align),
          style: baseStyle,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: context.textHint.withValues(alpha: 0.4),
              fontSize: baseStyle.fontSize,
              fontWeight: isHeading ? FontWeight.w700 : FontWeight.w400,
              fontStyle: isQuote ? FontStyle.italic : FontStyle.normal,
            ),
            // IMPORTANTE: sobrescrever o tema global que tem filled:true
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

        // Citação com borda lateral sutil
        return Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: AppTheme.accentColor.withValues(alpha: 0.4),
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
              color: context.scaffoldBg,
              borderRadius: BorderRadius.circular(r.s(6)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: r.s(18),
                    height: r.s(18),
                    child: const CircularProgressIndicator(
                      color: AppTheme.accentColor,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(height: r.s(4)),
                  Text(
                    s.sendingImage,
                    style: TextStyle(
                        color: context.textSecondary, fontSize: r.fs(10)),
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
                      color: context.textHint.withValues(alpha: 0.5),
                      size: r.s(20),
                    ),
                    SizedBox(width: r.s(6)),
                    Text(
                      s.tapToAddImage,
                      style: TextStyle(
                        color: context.textHint.withValues(alpha: 0.5),
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
                        color: context.textHint,
                        size: r.s(20),
                      ),
                    ),
                  ),
                ),
              ),
              // Legenda
              TextField(
                controller: block.captionController,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: r.fs(11),
                  fontStyle: FontStyle.italic,
                ),
                decoration: InputDecoration(
                  hintText: 'Legenda (opcional)',
                  hintStyle: TextStyle(
                    color: context.textHint.withValues(alpha: 0.3),
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
        return Padding(
          padding: EdgeInsets.symmetric(vertical: r.s(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (_) => Container(
                margin: EdgeInsets.symmetric(horizontal: r.s(3)),
                width: r.s(3),
                height: r.s(3),
                decoration: BoxDecoration(
                  color: context.textHint.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
    }
  }
}

// =============================================================================
// _InlineFormatBar — barra de formatação discreta
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

  const _InlineFormatBar({
    required this.block,
    required this.canRemove,
    required this.onToggleBold,
    required this.onToggleItalic,
    required this.onCycleAlignment,
    required this.onTypeChanged,
    required this.onHeadingLevelChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Padding(
      padding: EdgeInsets.only(bottom: r.s(2)),
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
            if (canRemove) ...[
              SizedBox(width: r.s(4)),
              _MiniIconBtn(
                icon: Icons.close_rounded,
                selected: false,
                onTap: onRemove,
                color: AppTheme.errorColor.withValues(alpha: 0.6),
              ),
            ],
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
        color: context.cardBg.withValues(alpha: 0.2),
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
              color: context.textSecondary,
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
// Widgets auxiliares mínimos
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
          color: context.textPrimary,
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
              (selected ? AppTheme.accentColor : context.textSecondary),
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
