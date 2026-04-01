import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/block_editor.dart';

// =============================================================================
// CREATE BLOG SCREEN — Editor de post tipo "Blog" (texto rico com blocos)
// =============================================================================

class CreateBlogScreen extends ConsumerStatefulWidget {
  final String communityId;
  const CreateBlogScreen({super.key, required this.communityId});

  @override
  ConsumerState<CreateBlogScreen> createState() => _CreateBlogScreenState();
}

class _CreateBlogScreenState extends ConsumerState<CreateBlogScreen> {
  final _titleController = TextEditingController();
  List<ContentBlock> _blocks = [];
  bool _isSubmitting = false;
  String _visibility = 'public';

  @override
  void dispose() {
    _titleController.dispose();
    for (final b in _blocks) {
      b.controller?.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O título é obrigatório'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception('Não autenticado');

      final content = _blocks
          .where((b) =>
              b.type == BlockType.text || b.type == BlockType.heading)
          .map((b) => b.controller?.text ?? b.text)
          .where((t) => t.isNotEmpty)
          .join('\n\n');

      final result = await SupabaseService.table('posts')
          .insert({
            'community_id': widget.communityId,
            'author_id': userId,
            'type': 'normal',
            'title': title,
            'content': content,
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
            content: Text('Blog publicado com sucesso!'),
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
          'Novo Blog',
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
          // Visibilidade
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
                        strokeWidth: 2,
                        color: AppTheme.primaryColor),
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
            // Título
            TextField(
              controller: _titleController,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: r.fs(22),
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Título do blog...',
                hintStyle: TextStyle(
                    color: context.textSecondary,
                    fontSize: r.fs(22),
                    fontWeight: FontWeight.w700),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
            Divider(color: context.dividerClr, height: r.s(24)),
            // Editor de blocos
            BlockEditor(
              initialBlocks: _blocks,
              communityId: widget.communityId,
              onChanged: (blocks) => setState(() => _blocks = blocks),
            ),
            SizedBox(height: r.s(80)),
          ],
        ),
      ),
    );
  }
}
