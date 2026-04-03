import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Rich Text Block Editor — Editor de Blocos estilo Amino.
///
/// No Amino original, blogs são compostos por blocos intercalados:
///   [Texto] → [Imagem] → [Texto] → [Imagem] → [Texto]
///
/// Cada bloco pode ser:
///   - text: parágrafo com formatação (negrito, itálico, etc.)
///   - image: imagem inline com legenda opcional
///   - divider: separador visual
///   - heading: título/subtítulo dentro do blog
///
/// O editor permite:
///   - Adicionar/remover/reordenar blocos
///   - Upload de imagens inline entre parágrafos
///   - Toolbar flutuante por bloco
///   - Preview em tempo real
///   - Serialização para JSON (content_blocks)

// ═══════════════════════════════════════════════════════════════
// MODELO DE BLOCO
// ═══════════════════════════════════════════════════════════════

enum BlockType { text, image, divider, heading }

class ContentBlock {
  final String id;
  BlockType type;
  String text;
  String? imageUrl;
  String? caption;
  TextEditingController? controller;

  ContentBlock({
    String? id,
    required this.type,
    this.text = '',
    this.imageUrl,
    this.caption,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString() {
    if (type == BlockType.text || type == BlockType.heading) {
      controller = TextEditingController(text: text);
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'text': type == BlockType.text || type == BlockType.heading
            ? (controller?.text ?? text)
            : text,
        if (imageUrl != null) 'image_url': imageUrl,
        if (caption != null && caption!.isNotEmpty) 'caption': caption,
      };

  static ContentBlock fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      type: BlockType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BlockType.text,
      ),
      text: json['text'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      caption: json['caption'] as String?,
    );
  }

  void dispose() {
    controller?.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// BLOCK EDITOR WIDGET
// ═══════════════════════════════════════════════════════════════

class BlockEditor extends StatefulWidget {
  final List<ContentBlock> initialBlocks;
  final ValueChanged<List<ContentBlock>> onChanged;
  final String communityId;

  const BlockEditor({
    super.key,
    this.initialBlocks = const [],
    required this.onChanged,
    required this.communityId,
  });

  @override
  State<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<BlockEditor> {
  late List<ContentBlock> _blocks;
  int? _focusedBlockIndex;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _blocks = widget.initialBlocks.isNotEmpty
        ? List.from(widget.initialBlocks)
        : [ContentBlock(type: BlockType.text)];
  }

  @override
  void dispose() {
    for (final b in _blocks) {
      b.dispose();
    }
    super.dispose();
  }

  void _notifyChanged() {
    widget.onChanged(List.from(_blocks));
  }

  void _addBlock(BlockType type, {int? afterIndex}) {
    final index = (afterIndex ?? _blocks.length - 1) + 1;
    final block = ContentBlock(type: type);
    setState(() {
      _blocks.insert(index, block);
      _focusedBlockIndex = index;
    });
    _notifyChanged();
  }

  void _removeBlock(int index) {
    if (_blocks.length <= 1) return; // Mínimo 1 bloco
    setState(() {
      _blocks[index].dispose();
      _blocks.removeAt(index);
      _focusedBlockIndex = null;
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

  Future<void> _pickImageForBlock(int index) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted) return;
    if (image == null) return;

    if (!mounted) return;
    setState(() => _isUploading = true);

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final bytes = await image.readAsBytes();
      final path =
          'posts/${widget.communityId}/$userId/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      await SupabaseService.client.storage
          .from('media')
          .uploadBinary(path, bytes);
      if (!mounted) return;
      final url =
          SupabaseService.client.storage.from('media').getPublicUrl(path);

      if (!mounted) return;
      setState(() {
        _blocks[index].imageUrl = url;
        _isUploading = false;
      });
      _notifyChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no upload. Tente novamente.'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _insertImageBlock({int? afterIndex}) async {
    final index = (afterIndex ?? _blocks.length - 1) + 1;
    final block = ContentBlock(type: BlockType.image);
    setState(() {
      _blocks.insert(index, block);
      _focusedBlockIndex = index;
    });

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted) return;
    if (image == null) {
      // Remover bloco se cancelou
      if (!mounted) return;
      setState(() {
        _blocks.removeAt(index);
        _focusedBlockIndex = null;
      });
      return;
    }

    setState(() => _isUploading = true);

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final bytes = await image.readAsBytes();
      final path =
          'posts/${widget.communityId}/$userId/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      await SupabaseService.client.storage
          .from('media')
          .uploadBinary(path, bytes);
      if (!mounted) return;
      final url =
          SupabaseService.client.storage.from('media').getPublicUrl(path);

      setState(() {
        _blocks[index].imageUrl = url;
        _isUploading = false;
      });

      // Adicionar bloco de texto após a imagem automaticamente
      _addBlock(BlockType.text, afterIndex: index);
      _notifyChanged();
    } catch (e) {
      setState(() => _isUploading = false);
    }
  }

  /// Serializa todos os blocos para JSON (para salvar no banco)
  List<Map<String, dynamic>> toJson() {
    return _blocks.map((b) => b.toJson()).toList();
  }

  /// Converte blocos para texto plano (fallback para content)
  String toPlainText() {
    return _blocks
        .where((b) => b.type == BlockType.text || b.type == BlockType.heading)
        .map((b) => b.controller?.text ?? b.text)
        .where((t) => t.isNotEmpty)
        .join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Blocos ──
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
              builder: (ctx, child) => Material(
                color: Colors.transparent,
                elevation: 4,
                child: child,
              ),
              child: child,
            );
          },
          itemBuilder: (ctx, i) {
            final block = _blocks[i];
            return _BlockWidget(
              key: ValueKey(block.id),
              block: block,
              index: i,
              isFocused: _focusedBlockIndex == i,
              isUploading: _isUploading && _focusedBlockIndex == i,
              onFocus: () => setState(() => _focusedBlockIndex = i),
              onRemove: () => _removeBlock(i),
              onPickImage: () => _pickImageForBlock(i),
              onTextChanged: (_) => _notifyChanged(),
            );
          },
        ),

        // ── Barra de adicionar bloco ──
        SizedBox(height: r.s(8)),
        _AddBlockBar(
          onAddText: () => _addBlock(BlockType.text),
          onAddImage: () => _insertImageBlock(),
          onAddDivider: () => _addBlock(BlockType.divider),
          onAddHeading: () => _addBlock(BlockType.heading),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BLOCO INDIVIDUAL
// ═══════════════════════════════════════════════════════════════

class _BlockWidget extends StatelessWidget {
  final ContentBlock block;
  final int index;
  final bool isFocused;
  final bool isUploading;
  final VoidCallback onFocus;
  final VoidCallback onRemove;
  final VoidCallback onPickImage;
  final ValueChanged<String> onTextChanged;

  const _BlockWidget({
    super.key,
    required this.block,
    required this.index,
    required this.isFocused,
    required this.isUploading,
    required this.onFocus,
    required this.onRemove,
    required this.onPickImage,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onFocus,
      child: Container(
        margin: EdgeInsets.only(bottom: r.s(4)),
        decoration: BoxDecoration(
          border: isFocused
              ? Border(
                  left: BorderSide(
                    color: AppTheme.accentColor.withValues(alpha: 0.5),
                    width: r.s(3),
                  ),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Conteúdo do bloco
            Expanded(child: _buildContent(context)),

            // Ações do bloco (visíveis quando focado)
            if (isFocused)
              Padding(
                padding: EdgeInsets.only(top: r.s(4)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniAction(
                      icon: Icons.drag_indicator_rounded,
                      color: (Colors.grey[600] ?? Colors.grey),
                      onTap: () {},
                    ),
                    _MiniAction(
                      icon: Icons.delete_outline_rounded,
                      color: AppTheme.errorColor,
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
    final r = context.r;
    switch (block.type) {
      case BlockType.text:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: r.s(4)),
          child: TextField(
            controller: block.controller,
            style: TextStyle(
              fontSize: r.fs(15),
              height: 1.7,
              color: Colors.grey[300],
            ),
            decoration: InputDecoration(
              hintText: 'Escreva aqui...',
              hintStyle: TextStyle(color: Colors.grey[700]),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: r.s(8)),
            ),
            maxLines: null,
            onChanged: onTextChanged,
          ),
        );

      case BlockType.heading:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: r.s(4)),
          child: TextField(
            controller: block.controller,
            style: TextStyle(
              fontSize: r.fs(20),
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'Subtítulo...',
              hintStyle: TextStyle(
                  color: Colors.grey[700], fontWeight: FontWeight.w700),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: r.s(8)),
            ),
            maxLines: null,
            onChanged: onTextChanged,
          ),
        );

      case BlockType.image:
        if (isUploading) {
          return Container(
            height: r.s(180),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                      color: AppTheme.accentColor, strokeWidth: 2),
                  SizedBox(height: r.s(8)),
                  Text('Enviando imagem...',
                      style: TextStyle(color: Colors.grey, fontSize: r.fs(12))),
                ],
              ),
            ),
          );
        }

        if (block.imageUrl == null || block.imageUrl!.isEmpty) {
          return GestureDetector(
            onTap: onPickImage,
            child: Container(
              height: r.s(120),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(r.s(12)),
                border: Border.all(
                  color: AppTheme.accentColor.withValues(alpha: 0.2),
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded,
                        color: AppTheme.accentColor.withValues(alpha: 0.6),
                        size: r.s(32)),
                    SizedBox(height: r.s(4)),
                    Text('Toque para adicionar imagem',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: r.fs(12))),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(r.s(12)),
              child: Image.network(
                block.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: r.s(120),
                  color: context.cardBg,
                  child: Center(
                    child: Icon(Icons.broken_image_rounded,
                        color: Colors.grey, size: r.s(32)),
                  ),
                ),
              ),
            ),
            if (block.caption != null && block.caption!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: r.s(4)),
                child: Text(
                  block.caption!,
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: r.fs(11),
                      fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );

      case BlockType.divider:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: r.s(12)),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.accentColor.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// BARRA DE ADICIONAR BLOCO
// ═══════════════════════════════════════════════════════════════

class _AddBlockBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(vertical: r.s(8), horizontal: r.s(4)),
      decoration: BoxDecoration(
        color: context.cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _AddBlockButton(
            icon: Icons.text_fields_rounded,
            label: 'Texto',
            color: const Color(0xFF4CAF50),
            onTap: onAddText,
          ),
          _AddBlockButton(
            icon: Icons.image_rounded,
            label: 'Imagem',
            color: const Color(0xFF2196F3),
            onTap: onAddImage,
          ),
          _AddBlockButton(
            icon: Icons.title_rounded,
            label: 'Título',
            color: const Color(0xFFFF9800),
            onTap: onAddHeading,
          ),
          _AddBlockButton(
            icon: Icons.horizontal_rule_rounded,
            label: 'Divisor',
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
            width: r.s(40),
            height: r.s(40),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(r.s(10)),
            ),
            child: Icon(icon, color: color, size: r.s(20)),
          ),
          SizedBox(height: r.s(4)),
          Text(
            label,
            style: TextStyle(
                color: Colors.grey[500],
                fontSize: r.fs(10),
                fontWeight: FontWeight.w600),
          ),
        ],
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
        padding: EdgeInsets.all(r.s(4)),
        child: Icon(icon, color: color, size: r.s(16)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BLOCK CONTENT RENDERER — Para renderizar blocos na visualização
// ═══════════════════════════════════════════════════════════════

class BlockContentRenderer extends StatelessWidget {
  final List<dynamic> blocks;

  const BlockContentRenderer({super.key, required this.blocks});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((blockData) {
        final data = blockData as Map<String, dynamic>;
        final type = data['type'] as String? ?? 'text';
        final text = data['text'] as String? ?? '';
        final imageUrl = data['image_url'] as String?;
        final caption = data['caption'] as String?;

        switch (type) {
          case 'heading':
            return Padding(
              padding: EdgeInsets.only(bottom: r.s(8), top: r.s(12)),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: r.fs(20),
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                  height: 1.4,
                ),
              ),
            );

          case 'image':
            return Padding(
              padding: EdgeInsets.symmetric(vertical: r.s(8)),
              child: Column(
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(r.s(12)),
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: r.s(120),
                          color: context.cardBg,
                          child: Center(
                            child: Icon(Icons.broken_image_rounded,
                                color: Colors.grey, size: r.s(32)),
                          ),
                        ),
                      ),
                    ),
                  if (caption != null && caption.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: r.s(4)),
                      child: Text(
                        caption,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: r.fs(11),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            );

          case 'divider':
            return Padding(
              padding: EdgeInsets.symmetric(vertical: r.s(12)),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.accentColor.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );

          default: // text
            return Padding(
              padding: EdgeInsets.only(bottom: r.s(8)),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: r.fs(15),
                  height: 1.7,
                  color: Colors.grey[300],
                ),
              ),
            );
        }
      }).toList(),
    );
  }
}
