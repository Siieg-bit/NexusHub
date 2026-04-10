import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';

// =============================================================================
// CREATE QUESTION SCREEN — Post tipo Q&A (pergunta aberta para a comunidade)
// =============================================================================

class CreateQuestionScreen extends ConsumerStatefulWidget {
  final String communityId;
  const CreateQuestionScreen({super.key, required this.communityId});

  @override
  ConsumerState<CreateQuestionScreen> createState() =>
      _CreateQuestionScreenState();
}

class _CreateQuestionScreenState extends ConsumerState<CreateQuestionScreen> {
  final _questionController = TextEditingController();
  final _contextController = TextEditingController();
  bool _isSubmitting = false;
  String _visibility = 'public';

  @override
  void dispose() {
    _questionController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = getStrings();
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text(s.questionRequired),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception(s.notAuthenticated);

      final result = await SupabaseService.table('posts')
          .insert({
            'community_id': widget.communityId,
            'author_id': userId,
            'type': 'qa',
            'title': question,
            'content': _contextController.text.trim(),
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
        debugPrint('[create_question_screen.dart] $e');
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(s.questionPublishedSuccess),
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
          'Fazer Pergunta',
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
            // Ícone decorativo
            Center(
              child: Container(
                width: r.s(64),
                height: r.s(64),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.help_rounded,
                    color: const Color(0xFFEA580C), size: r.s(32)),
              ),
            ),
            SizedBox(height: r.s(8)),
            Center(
              child: Text(
                s.askCommunity,
                style:
                    TextStyle(color: context.textSecondary, fontSize: r.fs(13)),
              ),
            ),
            SizedBox(height: r.s(24)),
            // Pergunta
            TextField(
              controller: _questionController,
              maxLength: 300,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: r.fs(20),
                  fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: s.whatDoYouWantToKnow,
                hintStyle: TextStyle(
                    color: context.textSecondary,
                    fontSize: r.fs(20),
                    fontWeight: FontWeight.w600),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
            Divider(color: context.dividerClr, height: r.s(24)),
            // Contexto adicional
            TextField(
              controller: _contextController,
              maxLength: 1000,
              maxLines: 8,
              minLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: context.textPrimary, fontSize: r.fs(15)),
              decoration: InputDecoration(
                hintText: s.addContextHint,
                hintStyle:
                    TextStyle(color: context.textSecondary, fontSize: r.fs(15)),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
            SizedBox(height: r.s(16)),
            // Dica
            Container(
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: const Color(0xFFEA580C).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.s(12)),
                border: Border.all(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      color: const Color(0xFFEA580C), size: r.s(16)),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Text(
                      'Perguntas claras e específicas recebem mais respostas. '
                      'Inclua detalhes relevantes no contexto.',
                      style: TextStyle(
                          color: context.textPrimary.withValues(alpha: 0.7),
                          fontSize: r.fs(12),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(80)),
          ],
        ),
      ),
    );
  }
}
