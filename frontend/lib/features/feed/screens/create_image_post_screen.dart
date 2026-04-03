import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/utils/responsive.dart';
import 'package:nexus_hub/core/l10n/locale_provider.dart';
// TODO: Add 'final s = ref.watch(stringsProvider);' in build() methods

// =============================================================================
// CREATE IMAGE POST SCREEN — Post com galeria de imagens
// =============================================================================

class CreateImagePostScreen extends ConsumerStatefulWidget {
  final String communityId;
  const CreateImagePostScreen({super.key, required this.communityId});

  @override
  ConsumerState<CreateImagePostScreen> createState() =>
      _CreateImagePostScreenState();
}

class _CreateImagePostScreenState
    extends ConsumerState<CreateImagePostScreen> {
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final List<String> _mediaUrls = [];
  bool _isSubmitting = false;
  bool _isUploading = false;
  String _visibility = 'public';

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;
    if (!mounted) return;
    setState(() => _isUploading = true);
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      // Upload em paralelo para melhor performance
      final uploadFutures = images.asMap().entries.map((entry) async {
        final idx = entry.key;
        final image = entry.value;
        final rawBytes = await image.readAsBytes();
        final bytes = await MediaUtils.compressImage(rawBytes);
        final path =
            'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_${idx}_${image.name}';
        await SupabaseService.storage
            .from('post_media')
            .uploadBinary(path, bytes);
        return SupabaseService.storage
            .from('post_media')
            .getPublicUrl(path);
      });
      final urls = await Future.wait(uploadFutures);
      if (mounted) setState(() => _mediaUrls.addAll(urls));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(s.uploadError),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _submit() async {
    if (_mediaUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(s.addAtLeastOneImage),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception('Não autenticado');

      final result = await SupabaseService.table('posts')
          .insert({
            'community_id': widget.communityId,
            'author_id': userId,
            'type': 'image',
            'title': _titleController.text.trim().isNotEmpty
                ? _titleController.text.trim()
                : null,
            'content': _captionController.text.trim(),
            'media_list': _mediaUrls
                .map((url) => {'url': url, 'type': 'image'})
                .toList(),
            'cover_image_url': _mediaUrls.first,
            'visibility': _visibility,
            'comments_blocked': false,
          })
          .select()
          .single();

      try {
        await SupabaseService.rpc('add_reputation', params: {
          'p_user_id': userId,
          'p_community_id': widget.communityId,
          'p_action_type': 'post_create',
          'p_raw_amount': 15,
          'p_reference_id': result['id'],
        });
      } catch (e) { debugPrint('[create_image_post_screen.dart] $e'); }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post publicado com sucesso!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.publishError),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: Text(
          'Post de Imagem',
          style: TextStyle(
              color: context.textPrimary,
              fontSize: r.fs(17),
              fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: context.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            initialValue: _visibility,
            onSelected: (v) => setState(() => _visibility = v),
            color: context.surfaceColor,
            icon: Icon(
              _visibility == 'public'
                  ? Icons.public_rounded
                  : _visibility == 'followers'
                      ? Icons.people_rounded
                      : Icons.lock_rounded,
              color: AppTheme.accentColor,
              size: r.s(20),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'public',
                  child: Text(s.public,
                      style: TextStyle(color: context.textPrimary))),
              PopupMenuItem(
                  value: 'followers',
                  child: Text(s.followers,
                      style: TextStyle(color: context.textPrimary))),
              PopupMenuItem(
                  value: 'private',
                  child: Text(s.private,
                      style: TextStyle(color: context.textPrimary))),
            ],
          ),
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? SizedBox(
                    width: r.s(18),
                    height: r.s(18),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryColor),
                  )
                : Text(
                    'Publicar',
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w700),
                  ),
          ),
          SizedBox(width: r.s(4)),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Galeria de imagens
            _buildImageGrid(r),
            SizedBox(height: r.s(20)),
            // Título (opcional)
            TextField(
              controller: _titleController,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: r.fs(18),
                  fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Título (opcional)...',
                hintStyle: TextStyle(
                    color: context.textSecondary, fontSize: r.fs(18)),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
            Divider(color: context.dividerClr),
            SizedBox(height: r.s(8)),
            // Legenda
            TextField(
              controller: _captionController,
              maxLength: 500,
              maxLines: 5,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                  color: context.textPrimary, fontSize: r.fs(15)),
              decoration: InputDecoration(
                hintText: 'Escreva uma legenda...',
                hintStyle: TextStyle(
                    color: context.textSecondary, fontSize: r.fs(15)),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
            SizedBox(height: r.s(80)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_mediaUrls.isEmpty)
          GestureDetector(
            onTap: _isUploading ? null : _pickImages,
            child: Container(
              height: r.s(200),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(r.s(16)),
                border: Border.all(
                    color: context.dividerClr.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isUploading)
                      CircularProgressIndicator(
                          color: AppTheme.primaryColor)
                    else ...[
                      Icon(Icons.add_photo_alternate_rounded,
                          color: AppTheme.primaryColor, size: r.s(48)),
                      SizedBox(height: r.s(8)),
                      Text(
                        'Toque para adicionar imagens',
                        style: TextStyle(
                            color: context.textSecondary,
                            fontSize: r.fs(14)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: r.s(4),
              mainAxisSpacing: r.s(4),
            ),
            itemCount: _mediaUrls.length + 1,
            itemBuilder: (ctx, index) {
              if (index == _mediaUrls.length) {
                // Botão adicionar mais
                return GestureDetector(
                  onTap: _isUploading ? null : _pickImages,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(r.s(8)),
                      border: Border.all(
                          color:
                              context.dividerClr.withValues(alpha: 0.4)),
                    ),
                    child: _isUploading
                        ? Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                                strokeWidth: 2))
                        : Icon(Icons.add_rounded,
                            color: AppTheme.primaryColor, size: r.s(28)),
                  ),
                );
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(r.s(8)),
                    child: Image.network(_mediaUrls[index],
                        fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: r.s(4),
                    right: r.s(4),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _mediaUrls.removeAt(index)),
                      child: Container(
                        padding: EdgeInsets.all(r.s(2)),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded,
                            color: Colors.white, size: r.s(14)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
