import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';

// =============================================================================
// CREATE POLL SCREEN — Enquete com múltiplas opções
// =============================================================================

class CreatePollScreen extends ConsumerStatefulWidget {
  final String communityId;
  const CreatePollScreen({super.key, required this.communityId});

  @override
  ConsumerState<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends ConsumerState<CreatePollScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _isSubmitting = false;
  String _visibility = 'public';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length >= 10) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    final c = _options.removeAt(index);
    c.dispose();
    setState(() {});
  }

  Future<void> _submit() async {
    final s = getStrings();
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(s.pollQuestionRequired),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    final validOptions =
        _options.where((c) => c.text.trim().isNotEmpty).toList();
    if (validOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(s.addAtLeast2Options),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception(s.notAuthenticated);

      // Montar opções da enquete como JSON
      final pollOpts =
          validOptions.map((c) => {'text': c.text.trim()}).toList();

      // RPC atômica: cria post + poll_options + reputação
      await SupabaseService.rpc('create_post_with_reputation', params: {
        'p_community_id': widget.communityId,
        'p_title': title,
        'p_content': _descriptionController.text.trim(),
        'p_type': 'poll',
        'p_visibility': _visibility,
        'p_poll_options': pollOpts,
      });

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(s.pollCreatedSuccess),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorCreatingPoll),
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
          s.newPoll,
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
                  color: const Color(0xFF0891B2).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bar_chart_rounded,
                    color: const Color(0xFF0891B2), size: r.s(32)),
              ),
            ),
            SizedBox(height: r.s(20)),
            // Pergunta
            Text(
              s.question,
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: r.s(8)),
            _buildField(
              controller: _titleController,
              hint: s.pollExampleHint,
              maxLength: 200,
              maxLines: 3,
              r: r,
            ),
            SizedBox(height: r.s(16)),
            // Descrição
            Text(
              s.descriptionOptional2,
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: r.s(8)),
            _buildField(
              controller: _descriptionController,
              hint: 'Contexto adicional...',
              maxLength: 500,
              maxLines: 3,
              r: r,
            ),
            SizedBox(height: r.s(24)),
            // Opções
            Row(
              children: [
                Text(
                  s.optionsLabel,
                  style: TextStyle(
                      color: context.textPrimary,
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${_options.length}/10',
                  style: TextStyle(
                      color: context.textSecondary, fontSize: r.fs(12)),
                ),
              ],
            ),
            SizedBox(height: r.s(8)),
            ...List.generate(_options.length, (i) {
              return Padding(
                padding: EdgeInsets.only(bottom: r.s(8)),
                child: Row(
                  children: [
                    Container(
                      width: r.s(28),
                      height: r.s(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0891B2).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                              color: const Color(0xFF0891B2),
                              fontSize: r.fs(12),
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    SizedBox(width: r.s(8)),
                    Expanded(
                      child: TextField(
                        controller: _options[i],
                        maxLength: 100,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                            color: context.textPrimary, fontSize: r.fs(14)),
                        decoration: InputDecoration(
                          hintText: s.optionNumber(i + 1),
                          hintStyle: TextStyle(
                              color: context.textSecondary, fontSize: r.fs(14)),
                          filled: true,
                          fillColor: context.cardBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(r.s(10)),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(r.s(10)),
                            borderSide: BorderSide(
                                color: const Color(0xFF0891B2), width: 1.5),
                          ),
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: r.s(12), vertical: r.s(10)),
                        ),
                      ),
                    ),
                    if (_options.length > 2) ...[
                      SizedBox(width: r.s(8)),
                      GestureDetector(
                        onTap: () => _removeOption(i),
                        child: Icon(Icons.remove_circle_outline_rounded,
                            color: AppTheme.errorColor, size: r.s(20)),
                      ),
                    ],
                  ],
                ),
              );
            }),
            if (_options.length < 10)
              TextButton.icon(
                onPressed: _addOption,
                icon: Icon(Icons.add_rounded,
                    color: AppTheme.primaryColor, size: r.s(18)),
                label: Text(
                  s.addOption,
                  style: TextStyle(
                      color: AppTheme.primaryColor, fontSize: r.fs(14)),
                ),
              ),
            SizedBox(height: r.s(80)),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    required int maxLines,
    required Responsive r,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.textSecondary, fontSize: r.fs(14)),
        filled: true,
        fillColor: context.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(12)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(12)),
          borderSide: BorderSide(color: const Color(0xFF0891B2), width: 1.5),
        ),
        counterText: '',
        contentPadding:
            EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(12)),
      ),
    );
  }
}
