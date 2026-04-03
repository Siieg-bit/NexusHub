import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

// =============================================================================
// CREATE PUBLIC CHAT SCREEN
// Cria um chat público em uma comunidade via RPC create_public_chat.
// Recebe communityId e communityName via GoRouter extra.
// =============================================================================

class CreatePublicChatScreen extends ConsumerStatefulWidget {
  final String communityId;
  final String communityName;

  const CreatePublicChatScreen({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  ConsumerState<CreatePublicChatScreen> createState() =>
      _CreatePublicChatScreenState();
}

class _CreatePublicChatScreenState
    extends ConsumerState<CreatePublicChatScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createChat() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);
    try {
      final result = await SupabaseService.rpc(
        'create_public_chat',
        params: {
          'p_community_id': widget.communityId,
          'p_title': _titleController.text.trim(),
          'p_description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
        },
      );

      final map = Map<String, dynamic>.from(result as Map);
      if (map['success'] == true) {
        final threadId = map['thread_id'] as String;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Chat público criado!'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Navega para o chat criado
          context.go('/chat/$threadId');
        }
      } else {
        final error = map['error'] as String? ?? 'unknown';
        final message = switch (error) {
          'unauthenticated' => 'Você precisa estar logado.',
          'title_required' => 'O nome do chat é obrigatório.',
          'not_a_member' => 'Você precisa ser membro da comunidade.',
          _ => 'Erro ao criar chat. Tente novamente.',
        };
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[create_public_chat] Erro: $e');
      if (mounted) {
        // Extrair mensagem legível do erro Supabase/PostgreSQL
        final errStr = e.toString();
        String userMsg = 'Erro ao criar chat. Tente novamente.';
        if (errStr.contains('not_a_member')) {
          userMsg = 'Você precisa ser membro da comunidade.';
        } else if (errStr.contains('unauthenticated')) {
          userMsg = 'Você precisa estar logado.';
        } else if (errStr.contains('title_required')) {
          userMsg = 'O nome do chat é obrigatório.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Novo Chat Público',
          style: TextStyle(
            fontSize: r.fs(17),
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: r.s(12)),
            child: TextButton(
              onPressed: _isCreating ? null : _createChat,
              child: _isCreating
                  ? SizedBox(
                      width: r.s(16),
                      height: r.s(16),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : Text(
                      'Criar',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: r.fs(15),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(r.s(16)),
          children: [
            // Comunidade destino
            Container(
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(r.s(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.group_rounded,
                      color: AppTheme.primaryColor, size: r.s(20)),
                  SizedBox(width: r.s(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comunidade',
                          style: TextStyle(
                            color: context.textPrimary.withValues(alpha: 0.6),
                            fontSize: r.fs(11),
                          ),
                        ),
                        Text(
                          widget.communityName,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: r.fs(14),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(16)),

            // Nome do chat
            Text(
              'Nome do Chat',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: r.s(8)),
            TextFormField(
              controller: _titleController,
              maxLength: 50,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ex: Discussão de Episódios',
                counterText: '',
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide:
                      BorderSide(color: AppTheme.primaryColor, width: 1.5),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'O nome do chat é obrigatório';
                }
                if (value.trim().length < 3) {
                  return 'O nome deve ter pelo menos 3 caracteres';
                }
                return null;
              },
            ),
            SizedBox(height: r.s(16)),

            // Descrição (opcional)
            Text(
              'Descrição (opcional)',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: r.s(8)),
            TextFormField(
              controller: _descriptionController,
              maxLength: 200,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Descreva o propósito deste chat...',
                counterText: '',
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide:
                      BorderSide(color: AppTheme.primaryColor, width: 1.5),
                ),
              ),
            ),
            SizedBox(height: r.s(24)),

            // Info sobre chat público
            Container(
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.s(12)),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppTheme.primaryColor, size: r.s(16)),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Text(
                      'Chats públicos são visíveis para todos os membros da comunidade. '
                      'Qualquer membro pode entrar e participar.',
                      style: TextStyle(
                        color: context.textPrimary.withValues(alpha: 0.7),
                        fontSize: r.fs(12),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(32)),

            // Botão criar (alternativo ao do AppBar)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: r.s(14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(12)),
                  ),
                ),
                child: _isCreating
                    ? SizedBox(
                        width: r.s(20),
                        height: r.s(20),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Criar Chat Público',
                        style: TextStyle(
                          fontSize: r.fs(15),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
