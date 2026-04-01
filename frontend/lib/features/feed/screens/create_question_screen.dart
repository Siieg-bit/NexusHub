import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

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
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A pergunta é obrigatória'),
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
            content: Text('Pergunta publicada com sucesso!'),
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
                'Pergunte à comunidade',
                style: TextStyle(
                    color: context.textSecondary, fontSize: r.fs(13)),
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
                hintText: 'O que você quer saber?',
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
              style: TextStyle(
                  color: context.textPrimary, fontSize: r.fs(15)),
              decoration: InputDecoration(
                hintText:
                    'Adicione contexto ou detalhes (opcional)...',
                hintStyle: TextStyle(
                    color: context.textSecondary, fontSize: r.fs(15)),
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
                    color:
                        const Color(0xFFEA580C).withValues(alpha: 0.2)),
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
                          color: context.textPrimary
                              .withValues(alpha: 0.7),
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
