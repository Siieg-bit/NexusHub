import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../repositories/sticker_repository.dart';
import '../../../core/widgets/rgb_color_picker.dart';

/// Tela de criação de stickers personalizados.
/// Permite: escolher imagem, adicionar texto, emojis, molduras e bordas.
class StickerCreatorScreen extends ConsumerStatefulWidget {
  final String packId;
  final String packName;

  const StickerCreatorScreen({
    super.key,
    required this.packId,
    required this.packName,
  });

  @override
  ConsumerState<StickerCreatorScreen> createState() => _StickerCreatorScreenState();
}

class _StickerCreatorScreenState extends ConsumerState<StickerCreatorScreen> {
  final _repaintKey = GlobalKey();
  final _nameCtrl = TextEditingController();
  final _textCtrl = TextEditingController();

  Uint8List? _imageBytes;
  String? _uploadedUrl;
  bool _isUploading = false;
  bool _isSaving = false;

  // Texto overlay
  String _overlayText = '';
  Color _textColor = Colors.white;
  double _textSize = 24;
  bool _textBold = false;
  // Emoji overlay
  String _overlayEmoji = '';

  // Borda/moldura
  Color _borderColor = Colors.transparent;
  double _borderWidth = 0;

  // Background color (quando não há imagem)
  Color _bgColor = const Color(0xFF1B2838);

  // Ferramentas disponíveis
  _Tool _activeTool = _Tool.none;

  static const _emojis = [
    '😀','😂','😍','🤔','😎','😢','😡','🥺','🤩','🥰',
    '😴','🤗','👋','👍','❤️','🔥','⭐','🎉','💀','🙏',
    '💪','🎮','🎵','🌈','🦋','🐱','🐶','🍕','🎂','🏆',
    '✨','💫','🌟','💎','🎯','🚀','🌙','☀️','🌊','🍀',
  ];

  static const _borderColors = [
    Colors.transparent,
    Colors.white,
    Color(0xFF2DBE60),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
    Color(0xFFFFD54F),
    Colors.black,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 90,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _uploadedUrl = null;
    });
  }

  Future<void> _captureAndSave() async {
    if (_isSaving) return;

    // Validar nome
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um nome para a figurinha')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? finalUrl = _uploadedUrl;

      // Se há imagem local, fazer upload
      if (_imageBytes != null && finalUrl == null) {
        setState(() => _isUploading = true);
        final fileName = '${const Uuid().v4()}.png';
        finalUrl = await StickerRepository.instance.uploadStickerImage(
          packId: widget.packId,
          imageBytes: _imageBytes!,
          fileName: fileName,
        );
        setState(() => _isUploading = false);
      }

      // Se não há imagem, capturar o canvas como PNG
      if (finalUrl == null) {
        final boundary = _repaintKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final pngBytes = byteData.buffer.asUint8List();
            final fileName = '${const Uuid().v4()}.png';
            finalUrl = await StickerRepository.instance.uploadStickerImage(
              packId: widget.packId,
              imageBytes: pngBytes,
              fileName: fileName,
            );
          }
        }
      }

      if (finalUrl == null) {
        throw Exception('Não foi possível processar a imagem');
      }

      // Adicionar sticker ao pack
      await StickerRepository.instance.addStickerToPack(
        packId: widget.packId,
        imageUrl: finalUrl,
        name: name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Figurinha adicionada ao pack!'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        title: Text(
          'Criar Figurinha',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: r.fs(17),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _captureAndSave,
            child: _isSaving
                ? SizedBox(
                    width: r.s(16),
                    height: r.s(16),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : Text(
                    'Salvar',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: r.fs(15),
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Canvas de preview
          Expanded(
            flex: 5,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(r.s(16)),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: _buildCanvas(r),
                  ),
                ),
              ),
            ),
          ),

          // Nome da figurinha
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(16)),
            child: TextField(
              controller: _nameCtrl,
              style: TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
              decoration: InputDecoration(
                hintText: 'Nome da figurinha...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: r.s(16),
                  vertical: r.s(10),
                ),
                prefixIcon: Icon(Icons.label_rounded, color: Colors.grey[600], size: r.s(18)),
              ),
            ),
          ),

          SizedBox(height: r.s(12)),

          // Barra de ferramentas
          _buildToolbar(r),

          // Painel de opções da ferramenta ativa
          _buildToolPanel(r),

          SizedBox(height: r.s(8)),
        ],
      ),
    );
  }

  Widget _buildCanvas(Responsive r) {
    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: _borderWidth > 0
            ? Border.all(color: _borderColor, width: _borderWidth)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r.s(16)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Imagem de fundo
            if (_imageBytes != null)
              Image.memory(_imageBytes!, fit: BoxFit.cover)
            else
              Container(color: _bgColor),

            // Emoji overlay (arrastável)
            if (_overlayEmoji.isNotEmpty)
              Positioned(
                left: null,
                top: null,
                child: Center(
                  child: Draggable(
                    feedback: Text(_overlayEmoji, style: TextStyle(fontSize: r.fs(48))),
                    childWhenDragging: const SizedBox.shrink(),
                    child: Text(_overlayEmoji, style: TextStyle(fontSize: r.fs(48))),
                  ),
                ),
              ),

            // Texto overlay
            if (_overlayText.isNotEmpty)
              Positioned(
                bottom: r.s(16),
                left: r.s(8),
                right: r.s(8),
                child: Text(
                  _overlayText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: _textSize,
                    fontWeight: _textBold ? FontWeight.w900 : FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),

            // Overlay de upload
            if (_isUploading)
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(Responsive r) {
    return Container(
      height: r.s(56),
      margin: EdgeInsets.symmetric(horizontal: r.s(16)),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolButton(
            icon: Icons.image_rounded,
            label: 'Imagem',
            isActive: false,
            onTap: _pickImage,
          ),
          _ToolButton(
            icon: Icons.text_fields_rounded,
            label: 'Texto',
            isActive: _activeTool == _Tool.text,
            onTap: () => setState(() {
              _activeTool = _activeTool == _Tool.text ? _Tool.none : _Tool.text;
            }),
          ),
          _ToolButton(
            icon: Icons.emoji_emotions_rounded,
            label: 'Emoji',
            isActive: _activeTool == _Tool.emoji,
            onTap: () => setState(() {
              _activeTool = _activeTool == _Tool.emoji ? _Tool.none : _Tool.emoji;
            }),
          ),
          _ToolButton(
            icon: Icons.palette_rounded,
            label: 'Fundo',
            isActive: _activeTool == _Tool.background,
            onTap: () => setState(() {
              _activeTool = _activeTool == _Tool.background ? _Tool.none : _Tool.background;
            }),
          ),
          _ToolButton(
            icon: Icons.border_style_rounded,
            label: 'Borda',
            isActive: _activeTool == _Tool.border,
            onTap: () => setState(() {
              _activeTool = _activeTool == _Tool.border ? _Tool.none : _Tool.border;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildToolPanel(Responsive r) {
    if (_activeTool == _Tool.none) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), 0),
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(14)),
      ),
      child: switch (_activeTool) {
        _Tool.text => _buildTextPanel(r),
        _Tool.emoji => _buildEmojiPanel(r),
        _Tool.background => _buildBgPanel(r),
        _Tool.border => _buildBorderPanel(r),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildTextPanel(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                style: TextStyle(color: context.textPrimary, fontSize: r.fs(13)),
                decoration: InputDecoration(
                  hintText: 'Digite o texto...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: context.surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(8)),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: r.s(12),
                    vertical: r.s(8),
                  ),
                ),
                onChanged: (v) => setState(() => _overlayText = v),
              ),
            ),
            SizedBox(width: r.s(8)),
            GestureDetector(
              onTap: () => setState(() => _textBold = !_textBold),
              child: Container(
                padding: EdgeInsets.all(r.s(8)),
                decoration: BoxDecoration(
                  color: _textBold
                      ? AppTheme.primaryColor.withValues(alpha: 0.2)
                      : context.surfaceColor,
                  borderRadius: BorderRadius.circular(r.s(8)),
                ),
                child: Text(
                  'B',
                  style: TextStyle(
                    color: _textBold ? AppTheme.primaryColor : Colors.grey[500],
                    fontWeight: FontWeight.w900,
                    fontSize: r.fs(16),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r.s(8)),
        // Tamanho do texto
        Row(
          children: [
            Text('Tamanho:', style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
            Expanded(
              child: Slider(
                value: _textSize,
                min: 12,
                max: 48,
                activeColor: AppTheme.primaryColor,
                inactiveColor: Colors.grey[700],
                onChanged: (v) => setState(() => _textSize = v),
              ),
            ),
            Text(
              _textSize.round().toString(),
              style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
            ),
          ],
        ),
        // Cores do texto
        SizedBox(height: r.s(4)),
        Row(
          children: [
            Text('Cor do texto:', style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
            const Spacer(),
            ColorPickerButton(
              color: _textColor,
              title: 'Cor do texto',
              size: 28,
              onColorChanged: (c) => setState(() => _textColor = c),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmojiPanel(Responsive r) {
    return SizedBox(
      height: r.s(120),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          crossAxisSpacing: r.s(4),
          mainAxisSpacing: r.s(4),
        ),
        itemCount: _emojis.length,
        itemBuilder: (_, i) {
          final emoji = _emojis[i];
          final isSelected = _overlayEmoji == emoji;
          return GestureDetector(
            onTap: () => setState(() {
              _overlayEmoji = isSelected ? '' : emoji;
            }),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(r.s(6)),
              ),
              child: Center(
                child: Text(emoji, style: TextStyle(fontSize: r.fs(20))),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBgPanel(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Cor de fundo:', style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
            const Spacer(),
            ColorPickerButton(
              color: _bgColor,
              title: 'Cor de fundo',
              size: 36,
              onColorChanged: (c) => setState(() {
                _bgColor = c;
                if (_imageBytes != null) _imageBytes = null;
              }),
            ),
          ],
        ),
        SizedBox(height: r.s(8)),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.s(8)),
              border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_rounded, color: AppTheme.accentColor, size: r.s(16)),
                SizedBox(width: r.s(6)),
                Text(
                  _imageBytes != null ? 'Trocar imagem' : 'Usar imagem da galeria',
                  style: TextStyle(color: AppTheme.accentColor, fontSize: r.fs(12)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBorderPanel(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Espessura:', style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
            Expanded(
              child: Slider(
                value: _borderWidth,
                min: 0,
                max: 12,
                divisions: 12,
                activeColor: AppTheme.primaryColor,
                inactiveColor: Colors.grey[700],
                onChanged: (v) => setState(() {
                  _borderWidth = v;
                  if (v > 0 && _borderColor == Colors.transparent) {
                    _borderColor = Colors.white;
                  }
                }),
              ),
            ),
            Text(
              _borderWidth.round().toString(),
              style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
            ),
          ],
        ),
        Text('Cor da borda:', style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
        SizedBox(height: r.s(8)),
        SizedBox(
          height: r.s(28),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _borderColors.length,
            separatorBuilder: (_, __) => SizedBox(width: r.s(6)),
            itemBuilder: (_, i) {
              final c = _borderColors[i];
              final isSelected = _borderColor == c;
              return GestureDetector(
                onTap: () => setState(() {
                  _borderColor = c;
                  if (c == Colors.transparent) _borderWidth = 0;
                  else if (_borderWidth == 0) _borderWidth = 3;
                }),
                child: Container(
                  width: r.s(28),
                  height: r.s(28),
                  decoration: BoxDecoration(
                    color: c == Colors.transparent ? null : c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.white.withValues(alpha: 0.2),
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: c == Colors.transparent
                      ? Icon(Icons.block_rounded, color: Colors.grey[500], size: r.s(16))
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _Tool { none, text, emoji, background, border }

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: r.s(20),
            color: isActive ? AppTheme.primaryColor : Colors.grey[500],
          ),
          SizedBox(height: r.s(2)),
          Text(
            label,
            style: TextStyle(
              fontSize: r.fs(9),
              color: isActive ? AppTheme.primaryColor : Colors.grey[600],
              fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
