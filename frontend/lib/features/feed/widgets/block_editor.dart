import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/app_theme.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Rich Text Block Editor — Editor de blocos estilo Amino.
///
/// Serializa os blocos em um formato compatível com o renderer atual,
/// mantendo chaves legadas e novas ao mesmo tempo:
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
      type == BlockType.text || type == BlockType.heading || type == BlockType.quote;

  void _ensureControllers() {
    if (isTextBased) {
      controller ??= TextEditingController(text: text);
    } else {
      controller?.dispose();
      controller = null;
    }

    if (type == BlockType.image) {
      captionController ??= TextEditingController(text: caption ?? '');
    } else {
      captionController?.dispose();
      captionController = null;
    }
  }

  void syncFromControllers() {
    if (controller != null) {
      text = controller!.text;
    }
    if (captionController != null) {
      caption = captionController!.text.trim();
    }
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

    final block = ContentBlock(
      type: type,
      text: (json['content'] ?? json['text'] ?? '') as String,
      imageUrl: (json['url'] ?? json['image_url']) as String?,
      caption: json['caption'] as String?,
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      align: (json['align'] as String?) ?? 'left',
      level: (json['level'] as num?)?.toInt() ?? 2,
    );

    return block;
  }

  ContentBlock clone() => ContentBlock.fromJson(toJson());

  void dispose() {
    controller?.dispose();
    captionController?.dispose();
  }
}

class BlockEditor extends ConsumerStatefulWidget {
  final List<ContentBlock> initialBlocks;
  final ValueChanged<List<ContentBlock>> onChanged;
  final String communityId;

  /// Placeholder para o primeiro bloco de texto quando vazio.
  final String? placeholder;

  /// Se false, esconde a barra de adicionar blocos no final.
  /// Útil quando a tela pai controla a inserção de blocos (estilo Amino).
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
  ConsumerState<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends ConsumerState<BlockEditor> {
  late List<ContentBlock> _blocks;
  int? _focusedBlockIndex;
  bool _isUploading = false;

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
      if (_focusedBlockIndex == index) {
        _focusedBlockIndex = null;
      }
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
    final next = alignments[(alignments.indexOf(current) + 1) % alignments.length];
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
                elevation: 4,
                child: child,
              ),
            );
          },
          itemBuilder: (context, index) {
            final block = _blocks[index];
            // Determinar placeholder: só o primeiro bloco de texto usa o placeholder custom
            String? blockPlaceholder;
            if (index == 0 && block.isTextBased && widget.placeholder != null) {
              blockPlaceholder = widget.placeholder;
            }
            return _BlockWidget(
              key: ValueKey(block.id),
              block: block,
              index: index,
              isFocused: _focusedBlockIndex == index,
              isUploading: _isUploading && _focusedBlockIndex == index,
              placeholder: blockPlaceholder,
              onFocus: () => setState(() => _focusedBlockIndex = index),
              onRemove: () => _removeBlock(index),
              onPickImage: () => _pickImageForBlock(index),
              onTextChanged: (_) => _notifyChanged(),
              onCaptionChanged: (_) => _notifyChanged(),
              onToggleBold: () => _toggleBold(index),
              onToggleItalic: () => _toggleItalic(index),
              onCycleAlignment: () => _cycleAlignment(index),
              onTypeChanged: (nextType) => _changeTextBlockType(index, nextType),
              onHeadingLevelChanged: (level) => _changeHeadingLevel(index, level),
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
// _BlockWidget — renderiza cada bloco individual
// =============================================================================

class _BlockWidget extends ConsumerWidget {
  final ContentBlock block;
  final int index;
  final bool isFocused;
  final bool isUploading;
  final String? placeholder;
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

  const _BlockWidget({
    super.key,
    required this.block,
    required this.index,
    required this.isFocused,
    required this.isUploading,
    this.placeholder,
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
      child: Container(
        // Sem margin extra, sem background — estilo Amino limpo
        padding: EdgeInsets.symmetric(vertical: r.s(2)),
        decoration: BoxDecoration(
          // Borda lateral sutil apenas quando focado (não card inteiro)
          border: isFocused
              ? Border(
                  left: BorderSide(
                    color: AppTheme.accentColor.withValues(alpha: 0.4),
                    width: r.s(2),
                  ),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toolbar de formatação compacta — só quando focado
                  if (isFocused && block.isTextBased)
                    _FormatToolbar(
                      block: block,
                      onToggleBold: onToggleBold,
                      onToggleItalic: onToggleItalic,
                      onCycleAlignment: onCycleAlignment,
                      onTypeChanged: onTypeChanged,
                      onHeadingLevelChanged: onHeadingLevelChanged,
                    ),
                  _buildContent(context),
                ],
              ),
            ),
            // Ações mínimas apenas quando focado
            if (isFocused)
              Padding(
                padding: EdgeInsets.only(top: r.s(2), right: r.s(2)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: _MiniAction(
                        icon: Icons.drag_indicator_rounded,
                        color: context.textSecondary.withValues(alpha: 0.5),
                        onTap: () {},
                      ),
                    ),
                    _MiniAction(
                      icon: Icons.close_rounded,
                      color: AppTheme.errorColor.withValues(alpha: 0.7),
                      onTap: onRemove,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final s = getStrings();
    final r = context.r;

    switch (block.type) {
      case BlockType.text:
      case BlockType.quote:
      case BlockType.heading:
        final isHeading = block.type == BlockType.heading;
        final isQuote = block.type == BlockType.quote;
        final baseStyle = TextStyle(
          fontSize: isHeading
              ? (block.level == 1 ? r.fs(20) : block.level == 2 ? r.fs(17) : r.fs(15))
              : r.fs(14),
          height: isQuote ? 1.6 : 1.7,
          color: context.textPrimary,
          fontWeight: isHeading || block.bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: block.italic || isQuote ? FontStyle.italic : FontStyle.normal,
        );

        // Determinar hint text
        final hintText = placeholder ??
            (isHeading
                ? 'Subtítulo'
                : isQuote
                    ? 'Citação...'
                    : s.writeHereHint);

        final field = TextField(
          controller: block.controller,
          textAlign: _parseTextAlign(block.align),
          style: baseStyle,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: context.textHint.withValues(alpha: 0.5),
              fontSize: baseStyle.fontSize,
              fontWeight: isHeading ? FontWeight.w700 : FontWeight.w400,
              fontStyle: isQuote ? FontStyle.italic : FontStyle.normal,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: r.s(4),
              vertical: r.s(4),
            ),
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
                color: AppTheme.accentColor.withValues(alpha: 0.5),
                width: r.s(2.5),
              ),
            ),
          ),
          child: field,
        );

      case BlockType.image:
        if (isUploading) {
          return Container(
            height: r.s(120),
            decoration: BoxDecoration(
              color: context.cardBg.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(r.s(8)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: r.s(20),
                    height: r.s(20),
                    child: const CircularProgressIndicator(
                      color: AppTheme.accentColor,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(height: r.s(6)),
                  Text(
                    s.sendingImage,
                    style: TextStyle(color: context.textSecondary, fontSize: r.fs(11)),
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
              height: r.s(100),
              decoration: BoxDecoration(
                color: context.cardBg.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(r.s(8)),
                border: Border.all(
                  color: context.dividerClr.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: context.textHint,
                      size: r.s(24),
                    ),
                    SizedBox(height: r.s(4)),
                    Text(
                      s.tapToAddImage,
                      style: TextStyle(
                        color: context.textHint,
                        fontSize: r.fs(11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(r.s(8)),
              child: Image.network(
                block.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: r.s(100),
                  color: context.cardBg,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: context.textHint,
                      size: r.s(24),
                    ),
                  ),
                ),
              ),
            ),
            if (isFocused) ...[
              SizedBox(height: r.s(4)),
              GestureDetector(
                onTap: onPickImage,
                child: Text(
                  'Trocar imagem',
                  style: TextStyle(
                    color: AppTheme.accentColor.withValues(alpha: 0.7),
                    fontSize: r.fs(11),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            SizedBox(height: r.s(2)),
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
                  color: context.textHint.withValues(alpha: 0.4),
                  fontSize: r.fs(11),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: r.s(2)),
                isDense: true,
              ),
              onTap: onFocus,
              onChanged: onCaptionChanged,
            ),
          ],
        );

      case BlockType.divider:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: r.s(12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (_) => Container(
                margin: EdgeInsets.symmetric(horizontal: r.s(3)),
                width: r.s(3),
                height: r.s(3),
                decoration: BoxDecoration(
                  color: context.textHint.withValues(alpha: 0.4),
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
// _FormatToolbar — barra de formatação compacta inline
// =============================================================================

class _FormatToolbar extends StatelessWidget {
  final ContentBlock block;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleItalic;
  final VoidCallback onCycleAlignment;
  final ValueChanged<BlockType> onTypeChanged;
  final ValueChanged<int> onHeadingLevelChanged;

  const _FormatToolbar({
    required this.block,
    required this.onToggleBold,
    required this.onToggleItalic,
    required this.onCycleAlignment,
    required this.onTypeChanged,
    required this.onHeadingLevelChanged,
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
            PopupMenuButton<BlockType>(
              tooltip: 'Estilo',
              color: context.surfaceColor,
              onSelected: onTypeChanged,
              itemBuilder: (_) => const [
                PopupMenuItem(value: BlockType.text, child: Text('Texto')),
                PopupMenuItem(value: BlockType.heading, child: Text('Subtítulo')),
                PopupMenuItem(value: BlockType.quote, child: Text('Citação')),
              ],
              child: _ToolbarChip(
                label: switch (block.type) {
                  BlockType.heading => 'H',
                  BlockType.quote => 'Q',
                  _ => 'T',
                },
              ),
            ),
            SizedBox(width: r.s(4)),
            _ToolbarIconBtn(
              icon: Icons.format_bold_rounded,
              selected: block.bold,
              onTap: onToggleBold,
            ),
            SizedBox(width: r.s(4)),
            _ToolbarIconBtn(
              icon: Icons.format_italic_rounded,
              selected: block.italic,
              onTap: onToggleItalic,
            ),
            SizedBox(width: r.s(4)),
            _ToolbarIconBtn(
              icon: _alignmentIcon(block.align),
              selected: false,
              onTap: onCycleAlignment,
            ),
            if (block.type == BlockType.heading) ...[
              SizedBox(width: r.s(4)),
              PopupMenuButton<int>(
                tooltip: 'Nível',
                color: context.surfaceColor,
                onSelected: onHeadingLevelChanged,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 1, child: Text('H1')),
                  PopupMenuItem(value: 2, child: Text('H2')),
                  PopupMenuItem(value: 3, child: Text('H3')),
                ],
                child: _ToolbarChip(label: 'H${block.level}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _AddBlockBar — barra de adicionar blocos (visível quando showAddBar = true)
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
      padding: EdgeInsets.symmetric(vertical: r.s(8), horizontal: r.s(6)),
      decoration: BoxDecoration(
        color: context.cardBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(r.s(10)),
        border: Border.all(color: context.dividerClr.withValues(alpha: 0.15)),
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
            width: r.s(36),
            height: r.s(36),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(r.s(8)),
            ),
            child: Icon(icon, color: color, size: r.s(18)),
          ),
          SizedBox(height: r.s(3)),
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
// Widgets auxiliares compactos
// =============================================================================

class _ToolbarChip extends StatelessWidget {
  final String label;

  const _ToolbarChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(8), vertical: r.s(4)),
      decoration: BoxDecoration(
        color: context.cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(color: context.dividerClr.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.textPrimary,
          fontSize: r.fs(10),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ToolbarIconBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToolbarIconBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r.s(12)),
      child: Container(
        padding: EdgeInsets.all(r.s(5)),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Icon(
          icon,
          size: r.s(15),
          color: selected ? AppTheme.accentColor : context.textSecondary,
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(r.s(3)),
        child: Icon(icon, color: color, size: r.s(14)),
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
