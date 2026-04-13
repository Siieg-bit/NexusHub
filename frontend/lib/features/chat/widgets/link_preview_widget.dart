import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Widget para renderizar preview de links com thumbnail, título e descrição
/// Suporta links externos e internos

class LinkPreviewWidget extends ConsumerStatefulWidget {
  final String linkId;
  final String url;
  final String? customTitle;
  final String? customDescription;
  final bool isClickable;
  final VoidCallback? onLinkTapped;

  const LinkPreviewWidget({
    super.key,
    required this.linkId,
    required this.url,
    this.customTitle,
    this.customDescription,
    this.isClickable = true,
    this.onLinkTapped,
  });

  @override
  ConsumerState<LinkPreviewWidget> createState() => _LinkPreviewWidgetState();
}

class _LinkPreviewWidgetState extends ConsumerState<LinkPreviewWidget> {
  late Future<Map<String, dynamic>?> _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = _loadPreview();
  }

  Future<Map<String, dynamic>?> _loadPreview() async {
    try {
      final result = await SupabaseService.rpc(
        'get_link_preview',
        params: {'p_link_id': widget.linkId},
      );

      if (result is Map<String, dynamic>) {
        return result;
      }
    } catch (e) {
      // Ignorar erro
    }
    return null;
  }

  Future<void> _openLink() async {
    if (!widget.isClickable) return;

    // Registrar clique
    try {
      await SupabaseService.rpc(
        'track_link_click',
        params: {'p_link_id': widget.linkId},
      );
    } catch (_) {}

    widget.onLinkTapped?.call();

    // Abrir link
    final url = Uri.parse(widget.url);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _previewFuture,
      builder: (context, snapshot) {
        final preview = snapshot.data;
        final hasImage = preview?['image_url'] != null;
        final title = widget.customTitle ?? preview?['title'] ?? 'Link';
        final description = widget.customDescription ?? preview?['description'];
        final domain = preview?['domain'] ?? 'Link';
        final imageUrl = preview?['image_url'] as String?;

        return GestureDetector(
          onTap: widget.isClickable ? _openLink : null,
          child: Container(
            decoration: BoxDecoration(
              color: context.nexusTheme.surfacePrimary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(
                color: context.nexusTheme.accentSecondary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagem
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(r.s(12)),
                      topRight: Radius.circular(r.s(12)),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl!,
                      width: double.infinity,
                      height: r.s(160),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey[800],
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.grey[600]),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[800],
                        child: Icon(
                          Icons.image_not_supported_rounded,
                          color: Colors.grey[600],
                          size: r.s(32),
                        ),
                      ),
                    ),
                  ),

                // Conteúdo
                Padding(
                  padding: EdgeInsets.all(r.s(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Domínio
                      Row(
                        children: [
                          if (preview?['favicon_url'] != null)
                            Padding(
                              padding: EdgeInsets.only(right: r.s(6)),
                              child: CachedNetworkImage(
                                imageUrl: preview!['favicon_url'] as String,
                                width: r.s(16),
                                height: r.s(16),
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.link_rounded,
                                  size: r.s(14),
                                  color: context.nexusTheme.accentPrimary,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              domain,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.nexusTheme.textPrimary.withValues(alpha: 0.6),
                                fontSize: r.fs(11),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: r.s(6)),

                      // Título
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      // Descrição
                      if (description != null && description.isNotEmpty) ...[
                        SizedBox(height: r.s(4)),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.nexusTheme.textPrimary.withValues(alpha: 0.7),
                            fontSize: r.fs(12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Widget para editar título e descrição customizados de um link
class LinkEditorDialog extends ConsumerStatefulWidget {
  final String linkId;
  final String? initialTitle;
  final String? initialDescription;
  final VoidCallback? onSaved;

  const LinkEditorDialog({
    super.key,
    required this.linkId,
    this.initialTitle,
    this.initialDescription,
    this.onSaved,
  });

  @override
  ConsumerState<LinkEditorDialog> createState() => _LinkEditorDialogState();
}

class _LinkEditorDialogState extends ConsumerState<LinkEditorDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _descriptionController = TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveLinkMetadata() async {
    setState(() => _isSaving = true);

    try {
      final result = await SupabaseService.rpc(
        'update_link_metadata',
        params: {
          'p_link_id': widget.linkId,
          'p_title': _titleController.text.isNotEmpty ? _titleController.text : null,
          'p_description': _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        },
      );

      if (result is Map<String, dynamic> && result['success'] == true) {
        if (mounted) {
          Navigator.of(context).pop();
          widget.onSaved?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: context.nexusTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return AlertDialog(
      backgroundColor: context.surfaceColor,
      title: Text(
        'Editar Link',
        style: TextStyle(
          color: context.nexusTheme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            style: TextStyle(color: context.nexusTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Título',
              labelStyle: TextStyle(color: context.nexusTheme.textPrimary.withValues(alpha: 0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(8)),
                borderSide: BorderSide(
                  color: context.nexusTheme.accentSecondary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          SizedBox(height: r.s(12)),
          TextField(
            controller: _descriptionController,
            style: TextStyle(color: context.nexusTheme.textPrimary),
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Descrição',
              labelStyle: TextStyle(color: context.nexusTheme.textPrimary.withValues(alpha: 0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(8)),
                borderSide: BorderSide(
                  color: context.nexusTheme.accentSecondary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: context.nexusTheme.textPrimary)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveLinkMetadata,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.nexusTheme.accentPrimary,
          ),
          child: _isSaving
              ? SizedBox(
                  width: r.s(18),
                  height: r.s(18),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text('Salvar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
