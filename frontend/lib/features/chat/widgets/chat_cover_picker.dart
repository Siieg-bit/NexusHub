// =============================================================================
// ChatCoverPickerSheet
// Widget compartilhado para definir a imagem de capa do chat (cover_image_url).
// Usado tanto no chat global quanto no chat de comunidade.
//
// A capa aparece:
//   - No item da lista de chats (my_community_chats_screen / chat_list_screen)
//   - No header do chat (AppBar background)
//
// Permissões: apenas host e co_host podem alterar a capa.
// Salva via RPC update_chat_cover.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/media_utils.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Abre o bottom sheet de seleção de capa do chat.
/// [threadId] — ID do chat thread.
/// [currentCover] — URL atual da capa (pode ser null).
/// [canEdit] — se o usuário tem permissão (host ou co_host).
/// [onChanged] — callback chamado com a nova URL (null = sem capa).
Future<void> showChatCoverPicker({
  required BuildContext context,
  required String threadId,
  required String? currentCover,
  required bool canEdit,
  required ValueChanged<String?> onChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ChatCoverPickerSheet(
      threadId: threadId,
      currentCover: currentCover,
      canEdit: canEdit,
      onChanged: onChanged,
    ),
  );
}

class _ChatCoverPickerSheet extends StatefulWidget {
  final String threadId;
  final String? currentCover;
  final bool canEdit;
  final ValueChanged<String?> onChanged;

  const _ChatCoverPickerSheet({
    required this.threadId,
    required this.currentCover,
    required this.canEdit,
    required this.onChanged,
  });

  @override
  State<_ChatCoverPickerSheet> createState() => _ChatCoverPickerSheetState();
}

class _ChatCoverPickerSheetState extends State<_ChatCoverPickerSheet> {
  bool _isUploading = false;

  Future<void> _pickFromGallery() async {
    if (!widget.canEdit) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path =
          'chat-covers/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);

      await SupabaseService.storage.from('chat-media').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      final url =
          SupabaseService.storage.from('chat-media').getPublicUrl(path);

      // Salvar via RPC
      await SupabaseService.client.rpc('update_chat_cover', params: {
        'p_thread_id': widget.threadId,
        'p_cover_url': url,
      });

      widget.onChanged(url);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('[ChatCoverPicker] Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar capa: $e'),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _removeCover() async {
    if (!widget.canEdit) return;
    try {
      await SupabaseService.client.rpc('update_chat_cover', params: {
        'p_thread_id': widget.threadId,
        'p_cover_url': null,
      });
      widget.onChanged(null);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('[ChatCoverPicker] Remove error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(32)),
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
            'Capa do Chat',
            style: TextStyle(
              fontSize: r.fs(18),
              fontWeight: FontWeight.w800,
              color: context.nexusTheme.textPrimary,
            ),
          ),
          SizedBox(height: r.s(4)),
          Text(
            widget.canEdit
                ? 'A capa aparece na lista de chats e no topo da conversa'
                : 'Apenas o host e co-administradores podem alterar a capa',
            style: TextStyle(
              fontSize: r.fs(12),
              color: context.nexusTheme.textHint,
            ),
          ),
          SizedBox(height: r.s(20)),

          // ── Preview atual ──
          if (widget.currentCover != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(r.s(12)),
              child: CachedNetworkImage(
                imageUrl: widget.currentCover!,
                width: double.infinity,
                height: r.s(140),
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: r.s(140),
                  color: context.nexusTheme.surfacePrimary,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: context.nexusTheme.accentPrimary, strokeWidth: 2),
                  ),
                ),
              ),
            ),
            SizedBox(height: r.s(16)),
          ],

          // ── Ações ──
          if (widget.canEdit) ...[
            _ActionTile(
              r: r,
              icon: Icons.photo_library_rounded,
              label: widget.currentCover != null
                  ? 'Alterar capa da galeria'
                  : 'Escolher capa da galeria',
              color: context.nexusTheme.accentPrimary,
              isLoading: _isUploading,
              onTap: _pickFromGallery,
            ),
            if (widget.currentCover != null) ...[
              SizedBox(height: r.s(8)),
              _ActionTile(
                r: r,
                icon: Icons.delete_outline_rounded,
                label: 'Remover capa',
                color: context.nexusTheme.error,
                onTap: _removeCover,
              ),
            ],
          ] else ...[
            // Visualização apenas
            if (widget.currentCover == null)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: r.s(16)),
                  child: Text(
                    'Nenhuma capa definida',
                    style: TextStyle(
                        color: context.nexusTheme.textHint, fontSize: r.fs(13)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final Responsive r;
  final IconData icon;
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionTile({
    required this.r,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding:
            EdgeInsets.symmetric(vertical: r.s(14), horizontal: r.s(16)),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            if (isLoading)
              SizedBox(
                width: r.s(20),
                height: r.s(20),
                child: CircularProgressIndicator(
                    color: color, strokeWidth: 2),
              )
            else
              Icon(icon, color: color, size: r.s(20)),
            SizedBox(width: r.s(12)),
            Text(
              isLoading ? 'Enviando...' : label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: r.fs(14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
