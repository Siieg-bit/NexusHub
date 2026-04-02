import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Diálogo de denúncia — permite reportar posts, comentários, mensagens ou usuários.
/// Categorias: Bullying, Art Theft, Conteúdo Impróprio, Spam, Off-Topic, Outro.
class ReportDialog extends StatefulWidget {
  final String communityId;
  final String? targetPostId;
  final String? targetCommentId;
  final String? targetMessageId;
  final String? targetUserId;

  const ReportDialog({
    super.key,
    required this.communityId,
    this.targetPostId,
    this.targetCommentId,
    this.targetMessageId,
    this.targetUserId,
  });

  /// Mostrar o diálogo de denúncia.
  static Future<void> show(
    BuildContext context, {
    required String communityId,
    String? targetPostId,
    String? targetCommentId,
    String? targetMessageId,
    String? targetUserId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ReportDialog(
        communityId: communityId,
        targetPostId: targetPostId,
        targetCommentId: targetCommentId,
        targetMessageId: targetMessageId,
        targetUserId: targetUserId,
      ),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _selectedType;
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  static const _flagTypes = [
    {
      'id': 'bullying',
      'label': 'Bullying / Assédio',
      'icon': Icons.person_off_rounded,
      'color': 0xFFF44336,
    },
    {
      'id': 'art_theft',
      'label': 'Art Theft / Plágio',
      'icon': Icons.palette_rounded,
      'color': 0xFFFF9800,
    },
    {
      'id': 'inappropriate_content',
      'label': 'Conteúdo Impróprio',
      'icon': Icons.no_adult_content_rounded,
      'color': 0xFF9C27B0,
    },
    {
      'id': 'spam',
      'label': 'Spam / Flood',
      'icon': Icons.report_rounded,
      'color': 0xFFFFC107,
    },
    {
      'id': 'off_topic',
      'label': 'Off-Topic',
      'icon': Icons.topic_rounded,
      'color': 0xFF2196F3,
    },
    {
      'id': 'impersonation',
      'label': 'Falsidade Ideológica',
      'icon': Icons.masks_rounded,
      'color': 0xFF607D8B,
    },
    {
      'id': 'self_harm',
      'label': 'Autolesão / Suicídio',
      'icon': Icons.health_and_safety_rounded,
      'color': 0xFFE91E63,
    },
    {
      'id': 'other',
      'label': 'Outro',
      'icon': Icons.more_horiz_rounded,
      'color': 0xFF9E9E9E,
    },
  ];

  Future<void> _submit() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o tipo de denúncia')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // RPC server-side: valida duplicatas e usa auth.uid()
      await SupabaseService.rpc('submit_flag', params: {
        'p_community_id': widget.communityId,
        'p_flag_type': _selectedType,
        'p_reason': _reasonController.text.trim().isNotEmpty
            ? _reasonController.text.trim()
            : null,
        'p_target_post_id': widget.targetPostId,
        'p_target_comment_id': widget.targetCommentId,
        'p_target_chat_message_id': widget.targetMessageId,
        'p_target_user_id': widget.targetUserId,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Denúncia enviada. Obrigado por reportar!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocorreu um erro. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: r.s(40),
              height: r.s(4),
              decoration: BoxDecoration(
                color: context.dividerClr,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: r.s(16)),
          Text(
            'Reportar Conteúdo',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: r.fs(18)),
          ),
          SizedBox(height: r.s(4)),
          Text(
            'Selecione o motivo da denúncia',
            style: TextStyle(color: context.textSecondary, fontSize: r.fs(13)),
          ),
          SizedBox(height: r.s(16)),

          // Tipos de flag
          ...(_flagTypes.map((type) {
            final id = type['id'] as String?;
            final isSelected = _selectedType == id;
            return GestureDetector(
              onTap: () => setState(() => _selectedType = id),
              child: Container(
                margin: EdgeInsets.only(bottom: r.s(6)),
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(12)),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Color(type['color'] as int? ?? 0).withValues(alpha: 0.1)
                      : context.cardBg,
                  borderRadius: BorderRadius.circular(r.s(12)),
                  border: isSelected
                      ? Border.all(
                          color: Color(type['color'] as int? ?? 0)
                              .withValues(alpha: 0.5))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(type['icon'] as IconData,
                        color: Color(type['color'] as int? ?? 0), size: r.s(20)),
                    SizedBox(width: r.s(12)),
                    Text(
                      type['label'] as String? ?? '',
                      style: TextStyle(fontSize: r.fs(14)),
                    ),
                    const Spacer(),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded,
                          color: Color(type['color'] as int? ?? 0), size: r.s(20)),
                  ],
                ),
              ),
            );
          })),

          SizedBox(height: r.s(12)),

          // Motivo adicional
          TextField(
            controller: _reasonController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Detalhes adicionais (opcional)...',
              filled: true,
              fillColor: context.cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(12)),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: r.s(16)),

          // Botão enviar
          SizedBox(
            width: double.infinity,
            height: r.s(48),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                ),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: r.s(20),
                      height: r.s(20),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Enviar Denúncia',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: r.fs(15))),
            ),
          ),
          SizedBox(height: r.s(16)),
        ],
      ),
    );
  }
}
