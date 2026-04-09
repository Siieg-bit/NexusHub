import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/block_editor.dart';
import '../../../core/l10n/locale_provider.dart';

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
    // Não chamar b.controller?.dispose() aqui — o BlockEditor já gerencia
    // o ciclo de vida dos seus próprios ContentBlocks. Chamar dispose() duas
    // vezes causa o erro "TextEditingController used after being disposed".
    super.dispose();
  }

  Future<void> _submit() async {
    final s = getStrings();
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(s.titleRequired),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception(s.notAuthenticated);

      // Ler o texto dos blocos ANTES de qualquer await para evitar
      // acesso a controllers já disposed após context.pop().
      final content = _blocks
          .where((b) => b.type == BlockType.text || b.type == BlockType.heading)
          .map((b) => b.controller?.text ?? b.text)
          .where((t) => t.isNotEmpty)
          .join('\n\n');

      final result = await SupabaseService.table('posts')
          .insert({
            'community_id': widget.communityId,
            'author_id': userId,
            'type': 'blog',
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
          'p_user_id': userId,
          'p_community_id': widget.communityId,
          'p_action_type': 'post_create',
          'p_raw_amount': 15,
          'p_reference_id': result['id'],
        });
      } catch (e) {
        debugPrint('[create_blog_screen.dart] $e');
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(s.blogPublishedSuccess),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorPublishing2),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: Text(
          s.newBlog,
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
                  child: Text(s.publicLabel,
                      style: TextStyle(color: context.textPrimary))),
              PopupMenuItem(
                  value: 'followers',
                  child: Text(s.followers,
                      style: TextStyle(color: context.textPrimary))),
              PopupMenuItem(
                  value: 'private',
                  child: Text(s.privateLabel,
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
                    s.publish,
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
                hintText: s.blogTitleHint,
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
