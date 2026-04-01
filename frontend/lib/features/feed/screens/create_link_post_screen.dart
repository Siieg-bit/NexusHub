import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

// =============================================================================
// CREATE LINK POST SCREEN — Post com URL externa
// =============================================================================

class CreateLinkPostScreen extends ConsumerStatefulWidget {
  final String communityId;
  const CreateLinkPostScreen({super.key, required this.communityId});

  @override
  ConsumerState<CreateLinkPostScreen> createState() =>
      _CreateLinkPostScreenState();
}

class _CreateLinkPostScreenState extends ConsumerState<CreateLinkPostScreen> {
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  String _visibility = 'public';

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool _isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final url = _urlController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O título é obrigatório'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    if (url.isEmpty || !_isValidUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insira um link válido (https://...)'),
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
            'type': 'link',
            'title': title,
            'content': _descriptionController.text.trim(),
            'external_url': url,
            'media_list': [],
            'visibility': _visibility,
            'comments_blocked': false,
          })
          .select()
          .single();

      try {
        await SupabaseService.rpc('add_reputation', params: {
          'p_community_id': widget.communityId,
          'p_user_id': userId,
          'p_action': 'post_create',
          'p_source_id': result['id'],
        });
      } catch (_) {}

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link compartilhado com sucesso!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao publicar. Tente novamente.'),
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
          'Compartilhar Link',
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
                  child: Text('Público',
                      style: TextStyle(color: context.textPrimary))),
              PopupMenuItem(
                  value: 'followers',
                  child: Text('Seguidores',
                      style: TextStyle(color: context.textPrimary))),
              PopupMenuItem(
                  value: 'private',
                  child: Text('Privado',
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
            // Card de URL
            Container(
              padding: EdgeInsets.all(r.s(16)),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(r.s(16)),
                border: Border.all(
                    color: context.dividerClr.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(r.s(8)),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(r.s(8)),
                        ),
                        child: Icon(Icons.link_rounded,
                            color: const Color(0xFF2563EB), size: r.s(20)),
                      ),
                      SizedBox(width: r.s(10)),
                      Text(
                        'URL do Link',
                        style: TextStyle(
                            color: context.textPrimary,
                            fontSize: r.fs(14),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  SizedBox(height: r.s(12)),
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    style: TextStyle(
                        color: context.textPrimary, fontSize: r.fs(14)),
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      hintStyle: TextStyle(
                          color: context.textSecondary, fontSize: r.fs(14)),
                      filled: true,
                      fillColor: context.scaffoldBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(r.s(10)),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(r.s(10)),
                        borderSide: BorderSide(
                            color: const Color(0xFF2563EB), width: 1.5),
                      ),
                      prefixIcon: Icon(Icons.language_rounded,
                          color: context.textSecondary, size: r.s(18)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(16)),
            // Título
            TextField(
              controller: _titleController,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: r.fs(20),
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Título do post...',
                hintStyle: TextStyle(
                    color: context.textSecondary,
                    fontSize: r.fs(20),
                    fontWeight: FontWeight.w700),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
            Divider(color: context.dividerClr),
            SizedBox(height: r.s(8)),
            // Descrição
            TextField(
              controller: _descriptionController,
              maxLength: 500,
              maxLines: 5,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                  color: context.textPrimary, fontSize: r.fs(15)),
              decoration: InputDecoration(
                hintText: 'Descreva o link (opcional)...',
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
}
