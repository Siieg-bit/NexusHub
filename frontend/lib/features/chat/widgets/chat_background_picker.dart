// =============================================================================
// ChatBackgroundPickerSheet
// Widget compartilhado para seleção de fundo de chat.
// Usado tanto no chat global quanto no chat de comunidade (mesmo ChatRoomScreen).
//
// Funcionalidades:
//   - Opção "Sem fundo" (remover)
//   - Galeria de presets (URLs Unsplash)
//   - Botão "Da galeria" — abre o seletor de imagem do dispositivo,
//     faz upload para Supabase Storage e salva a URL
//   - Salva via tabela chat_backgrounds (por usuário + thread)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Abre o bottom sheet de seleção de fundo de chat.
/// [threadId] — ID do chat thread.
/// [currentBackground] — URL atual do fundo (pode ser null).
/// [onChanged] — callback chamado com a nova URL (null = sem fundo).
Future<void> showChatBackgroundPicker({
  required BuildContext context,
  required String threadId,
  required String? currentBackground,
  required ValueChanged<String?> onChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ChatBackgroundPickerSheet(
      threadId: threadId,
      currentBackground: currentBackground,
      onChanged: onChanged,
    ),
  );
}

class _ChatBackgroundPickerSheet extends StatefulWidget {
  final String threadId;
  final String? currentBackground;
  final ValueChanged<String?> onChanged;

  const _ChatBackgroundPickerSheet({
    required this.threadId,
    required this.currentBackground,
    required this.onChanged,
  });

  @override
  State<_ChatBackgroundPickerSheet> createState() =>
      _ChatBackgroundPickerSheetState();
}

class _ChatBackgroundPickerSheetState
    extends State<_ChatBackgroundPickerSheet> {
  bool _isUploading = false;
  String? _selected;

  static const List<String?> _presets = [
    null, // "Sem fundo"
    'https://images.unsplash.com/photo-1518655048521-f130df041f66?w=800',
    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
    'https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?w=800',
    'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800',
    'https://images.unsplash.com/photo-1477346611705-65d1883cee1e?w=800',
    'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800',
    'https://images.unsplash.com/photo-1534796636912-3b95b3ab5986?w=800',
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800',
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentBackground;
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path =
          'chat-backgrounds/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);

      await SupabaseService.storage.from('chat-media').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      final url =
          SupabaseService.storage.from('chat-media').getPublicUrl(path);

      if (mounted) {
        setState(() => _selected = url);
        await _save(url);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[ChatBgPicker] Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar imagem: $e'),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _save(String? url) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      await SupabaseService.table('chat_backgrounds').upsert({
        'thread_id': widget.threadId,
        'user_id': userId,
        'background_url': url,
      });
      widget.onChanged(url);
    } catch (e) {
      debugPrint('[ChatBgPicker] Save error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final s = getStrings();

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──
          Center(
            child: Container(
              width: r.s(36),
              height: r.s(4),
              margin: EdgeInsets.only(bottom: r.s(16)),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Título ──
          Text(
            s.chatBackground,
            style: TextStyle(
              fontSize: r.fs(18),
              fontWeight: FontWeight.w800,
              color: context.nexusTheme.textPrimary,
            ),
          ),
          SizedBox(height: r.s(4)),
          Text(
            'Escolha um fundo ou use uma imagem da sua galeria',
            style: TextStyle(
              fontSize: r.fs(12),
              color: context.nexusTheme.textHint,
            ),
          ),
          SizedBox(height: r.s(16)),

          // ── Botão "Da galeria" ──
          GestureDetector(
            onTap: _isUploading ? null : _pickFromGallery,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                  vertical: r.s(12), horizontal: r.s(16)),
              decoration: BoxDecoration(
                color: context.nexusTheme.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(r.s(12)),
                border: Border.all(
                    color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isUploading)
                    SizedBox(
                      width: r.s(18),
                      height: r.s(18),
                      child: CircularProgressIndicator(
                        color: context.nexusTheme.accentPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  else
                    Icon(Icons.photo_library_rounded,
                        color: context.nexusTheme.accentPrimary, size: r.s(20)),
                  SizedBox(width: r.s(8)),
                  Text(
                    _isUploading ? 'Enviando...' : 'Escolher da galeria',
                    style: TextStyle(
                      color: context.nexusTheme.accentPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: r.fs(14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: r.s(16)),

          // ── Presets ──
          Text(
            'Fundos prontos',
            style: TextStyle(
              fontSize: r.fs(13),
              fontWeight: FontWeight.w600,
              color: context.nexusTheme.textSecondary,
            ),
          ),
          SizedBox(height: r.s(10)),
          SizedBox(
            height: r.s(88),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _presets.length,
              itemBuilder: (_, i) {
                final url = _presets[i];
                final isSelected = _selected == url;
                return GestureDetector(
                  onTap: () async {
                    setState(() => _selected = url);
                    await _save(url);
                    if (mounted) Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: r.s(88),
                    height: r.s(88),
                    margin: EdgeInsets.only(right: r.s(8)),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(r.s(12)),
                      border: Border.all(
                        color: isSelected
                            ? context.nexusTheme.accentPrimary
                            : Colors.transparent,
                        width: 2.5,
                      ),
                      color: url == null ? context.nexusTheme.surfacePrimary : null,
                      image: url != null
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(url),
                              fit: BoxFit.cover,
                            )
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: context.nexusTheme.accentPrimary
                                    .withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: url == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.block_rounded,
                                  color: Colors.grey[500], size: r.s(26)),
                              SizedBox(height: r.s(4)),
                              Text(
                                'Sem fundo',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: r.fs(9),
                                ),
                              ),
                            ],
                          )
                        : isSelected
                            ? Center(
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: context.nexusTheme.accentPrimary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 16),
                                ),
                              )
                            : null,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: r.s(8)),
        ],
      ),
    );
  }
}
