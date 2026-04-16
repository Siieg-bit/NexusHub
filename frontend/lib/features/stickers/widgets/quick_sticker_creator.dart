import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/utils/media_utils.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Widget para criação rápida de figurinhas (stickers)
/// Dois modos de operação:
///   1. Com threadId: envia a figurinha diretamente no chat
///   2. Sem threadId: salva a figurinha no pack pessoal do usuário

class QuickStickerCreator extends ConsumerStatefulWidget {
  final String? threadId; // Opcional: se fornecido, envia direto no chat
  final VoidCallback? onStickerCreated;

  const QuickStickerCreator({
    super.key,
    this.threadId,
    this.onStickerCreated,
  });

  @override
  ConsumerState<QuickStickerCreator> createState() =>
      _QuickStickerCreatorState();
}

class _QuickStickerCreatorState extends ConsumerState<QuickStickerCreator> {
  String? _stickerUrl;
  String _stickerName = '';
  bool _isUploading = false;
  bool _isSending = false;
  final _nameController = TextEditingController();

  bool get _isChatMode => widget.threadId != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickStickerImage() async {
    final s = ref.read(stringsProvider);
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() => _isUploading = true);

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(
        rawBytes,
        minWidth: 512,
        minHeight: 512,
      );
      final path =
          'stickers/$userId/${DateTime.now().millisecondsSinceEpoch}_${image.name}';

      await SupabaseService.storage
          .from('post-media')
          .uploadBinary(path, bytes);

      final url = SupabaseService.storage.from('post-media').getPublicUrl(path);

      if (mounted) {
        final name = image.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        setState(() {
          _stickerUrl = url;
          _stickerName = name;
          _nameController.text = name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorUploadTryAgain),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _sendOrSaveSticker() async {
    final s = ref.read(stringsProvider);

    if (_stickerUrl == null || _stickerUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecione uma figurinha'),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      if (_isChatMode) {
        // Modo chat: enviar como mensagem de sticker
        await SupabaseService.table('chat_messages').insert({
          'thread_id': widget.threadId,
          'sender_id': SupabaseService.currentUserId,
          'type': 'sticker',
          'sticker_url': _stickerUrl,
          'content': _stickerName.isNotEmpty ? _stickerName : 'Figurinha',
        });
      } else {
        // Modo pack pessoal: salvar no pack pessoal do usuário
        final userId = SupabaseService.currentUserId;
        if (userId == null) throw Exception('Usuário não autenticado');

        // Buscar ou criar pack pessoal
        final existingPacks = await SupabaseService.table('sticker_packs')
            .select('id')
            .eq('creator_id', userId)
            .eq('name', 'Minhas Figurinhas')
            .limit(1);

        String packId;
        if (existingPacks.isNotEmpty) {
          packId = existingPacks[0]['id'] as String;
        } else {
          // Criar pack pessoal
          final newPack =
              await SupabaseService.table('sticker_packs').insert({
            'name': 'Minhas Figurinhas',
            'creator_id': userId,
            'is_public': false,
          }).select('id').single();
          packId = newPack['id'] as String;
        }

        // Adicionar sticker ao pack
        await SupabaseService.table('stickers').insert({
          'pack_id': packId,
          'name': _stickerName.isNotEmpty ? _stickerName : 'Figurinha',
          'image_url': _stickerUrl,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isChatMode ? 'Enviado com sucesso!' : 'Figurinha salva!'),
            backgroundColor: context.nexusTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        setState(() {
          _stickerUrl = null;
          _stickerName = '';
          _nameController.clear();
        });

        widget.onStickerCreated?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.anErrorOccurredTryAgain),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Dialog(
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r.s(16)),
      ),
      child: Padding(
        padding: EdgeInsets.all(r.s(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título
            Text(
              'Criar Figurinha',
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(18),
                fontWeight: FontWeight.w700,
              ),
            ),

            // Subtítulo com modo
            SizedBox(height: r.s(4)),
            Text(
              _isChatMode
                  ? 'Enviar direto no chat'
                  : 'Salvar no seu pack pessoal',
              style: TextStyle(
                color: context.nexusTheme.textSecondary,
                fontSize: r.fs(12),
              ),
            ),

            SizedBox(height: r.s(20)),

            // Preview da figurinha
            if (_stickerUrl != null)
              Container(
                width: r.s(200),
                height: r.s(200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  image: DecorationImage(
                    image: NetworkImage(_stickerUrl!),
                    fit: BoxFit.contain,
                  ),
                  color: context.nexusTheme.backgroundPrimary,
                ),
              )
            else
              Container(
                width: r.s(200),
                height: r.s(200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  color: context.nexusTheme.backgroundPrimary,
                  border: Border.all(
                    color: context.nexusTheme.accentSecondary
                        .withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.image_rounded,
                    size: r.s(48),
                    color: context.nexusTheme.textPrimary
                        .withValues(alpha: 0.3),
                  ),
                ),
              ),

            SizedBox(height: r.s(20)),

            // Botão para escolher imagem
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickStickerImage,
                icon: _isUploading
                    ? SizedBox(
                        width: r.s(18),
                        height: r.s(18),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.image_rounded),
                label: Text(_stickerUrl == null
                    ? 'Escolher Imagem'
                    : 'Mudar Imagem'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.nexusTheme.accentPrimary,
                  padding: EdgeInsets.symmetric(vertical: r.s(12)),
                ),
              ),
            ),

            SizedBox(height: r.s(16)),

            // Campo de nome
            if (_stickerUrl != null)
              TextField(
                controller: _nameController,
                onChanged: (val) => _stickerName = val,
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(13),
                ),
                decoration: InputDecoration(
                  labelText: 'Nome da Figurinha',
                  labelStyle: TextStyle(
                    color: context.nexusTheme.textPrimary
                        .withValues(alpha: 0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(8)),
                    borderSide: BorderSide(
                      color: context.nexusTheme.accentSecondary
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: r.s(12),
                    vertical: r.s(10),
                  ),
                ),
              ),

            SizedBox(height: r.s(20)),

            // Botões de ação
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: r.s(12)),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_stickerUrl == null || _isSending)
                        ? null
                        : _sendOrSaveSticker,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.nexusTheme.accentPrimary,
                      disabledBackgroundColor: context.nexusTheme
                          .accentPrimary
                          .withValues(alpha: 0.5),
                    ),
                    child: _isSending
                        ? SizedBox(
                            height: r.s(18),
                            width: r.s(18),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation(
                                  Colors.white),
                            ),
                          )
                        : Text(
                            _isChatMode ? 'Enviar' : 'Salvar',
                            style: const TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
