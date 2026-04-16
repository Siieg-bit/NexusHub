import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Widget para renderizar formulários em mensagens de chat
/// Suporta diferentes tipos de campos: text, select, checkbox, radio, etc.

class FormMessageBubble extends ConsumerStatefulWidget {
  final String formId;
  final String formTitle;
  final String? formDescription;
  final List<dynamic> fields; // Array de campos do formulário
  final bool isMe;
  final bool allowMultipleResponses;

  const FormMessageBubble({
    super.key,
    required this.formId,
    required this.formTitle,
    this.formDescription,
    required this.fields,
    required this.isMe,
    this.allowMultipleResponses = false,
  });

  @override
  ConsumerState<FormMessageBubble> createState() => _FormMessageBubbleState();
}

class _FormMessageBubbleState extends ConsumerState<FormMessageBubble> {
  late Map<String, dynamic> _formValues;
  bool _isSubmitting = false;
  bool _hasResponded = false;

  @override
  void initState() {
    super.initState();
    _initializeFormValues();
    _checkIfUserResponded();
  }

  void _initializeFormValues() {
    _formValues = {};
    for (final field in widget.fields) {
      if (field is Map<String, dynamic>) {
        final fieldId = field['id'] as String?;
        if (fieldId != null) {
          final fieldType = field['type'] as String? ?? 'text';
          switch (fieldType) {
            case 'checkbox':
              _formValues[fieldId] = false;
              break;
            case 'select':
            case 'radio':
              _formValues[fieldId] = null;
              break;
            default:
              _formValues[fieldId] = '';
          }
        }
      }
    }
  }

  Future<void> _checkIfUserResponded() async {
    try {
      final result = await SupabaseService.rpc(
        'get_chat_form_responses',
        params: {'p_form_id': widget.formId},
      );

      if (result is Map<String, dynamic>) {
        final responses = result['responses'] as List?;
        if (responses != null && responses.isNotEmpty) {
          setState(() {
            _hasResponded = true;
          });
        }
      }
    } catch (e) {
      // Ignorar erro ao verificar resposta anterior
    }
  }

  Future<void> _submitForm() async {
    final s = ref.read(stringsProvider);

    // Validar campos obrigatórios
    for (final field in widget.fields) {
      if (field is Map<String, dynamic>) {
        final fieldId = field['id'] as String?;
        final isRequired = field['required'] as bool? ?? false;
        final value = _formValues[fieldId];

        if (isRequired && (value == null || value == '' || value == false)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${field['label'] ?? 'Campo'} é obrigatório'),
              backgroundColor: context.nexusTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await SupabaseService.rpc(
        'respond_to_chat_form',
        params: {
          'p_form_id': widget.formId,
          'p_responses': _formValues,
        },
      );

      if (result is Map<String, dynamic> && result['success'] == true) {
        if (mounted) {
          setState(() {
            _hasResponded = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Enviado com sucesso!'),
              backgroundColor: context.nexusTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception(result is Map ? result['error'] ?? 'Erro ao enviar' : 'Erro ao enviar');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.anErrorOccurredTryAgain),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildField(Map<String, dynamic> field) {
    final r = context.r;
    final fieldId = field['id'] as String?;
    final fieldType = field['type'] as String? ?? 'text';
    final label = field['label'] as String? ?? 'Campo';
    final isRequired = field['required'] as bool? ?? false;
    final options = field['options'] as List? ?? [];

    final textColor = widget.isMe ? Colors.white : context.nexusTheme.textPrimary;
    final borderColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.2)
        : context.nexusTheme.accentSecondary.withValues(alpha: 0.3);

    if (fieldId == null) return const SizedBox.shrink();

    switch (fieldType) {
      case 'text':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label + (isRequired ? ' *' : ''),
              style: TextStyle(
                color: textColor,
                fontSize: r.fs(12),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: r.s(6)),
            TextField(
              enabled: !_hasResponded,
              onChanged: (value) => _formValues[fieldId] = value,
              style: TextStyle(color: textColor, fontSize: r.fs(13)),
              decoration: InputDecoration(
                hintText: 'Digite aqui...',
                hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(8)),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(8)),
                  borderSide: BorderSide(color: borderColor),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(8)),
                  borderSide: BorderSide(color: borderColor.withValues(alpha: 0.3)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: r.s(12),
                  vertical: r.s(10),
                ),
              ),
            ),
          ],
        );

      case 'select':
      case 'radio':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label + (isRequired ? ' *' : ''),
              style: TextStyle(
                color: textColor,
                fontSize: r.fs(12),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: r.s(6)),
            ...options.map((option) {
              final optionText = option is String ? option : option['label'] ?? '';
              final optionValue = option is String ? option : option['value'] ?? option['label'];

              return GestureDetector(
                onTap: _hasResponded
                    ? null
                    : () {
                        setState(() {
                          _formValues[fieldId] = optionValue;
                        });
                      },
                child: Container(
                  margin: EdgeInsets.only(bottom: r.s(6)),
                  padding: EdgeInsets.symmetric(
                    horizontal: r.s(12),
                    vertical: r.s(10),
                  ),
                  decoration: BoxDecoration(
                    color: _formValues[fieldId] == optionValue
                        ? context.nexusTheme.accentPrimary.withValues(alpha: 0.2)
                        : textColor.withValues(alpha: 0.05),
                    border: Border.all(
                      color: _formValues[fieldId] == optionValue
                          ? context.nexusTheme.accentPrimary
                          : borderColor,
                    ),
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: r.s(20),
                        height: r.s(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _formValues[fieldId] == optionValue
                                ? context.nexusTheme.accentPrimary
                                : borderColor,
                          ),
                        ),
                        child: _formValues[fieldId] == optionValue
                            ? Center(
                                child: Container(
                                  width: r.s(10),
                                  height: r.s(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: context.nexusTheme.accentPrimary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      SizedBox(width: r.s(12)),
                      Expanded(
                        child: Text(
                          optionText,
                          style: TextStyle(
                            color: textColor,
                            fontSize: r.fs(13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        );

      case 'checkbox':
        return GestureDetector(
          onTap: _hasResponded
              ? null
              : () {
                  setState(() {
                    _formValues[fieldId] = !(_formValues[fieldId] as bool? ?? false);
                  });
                },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.s(12),
              vertical: r.s(10),
            ),
            decoration: BoxDecoration(
              color: (_formValues[fieldId] as bool? ?? false)
                  ? context.nexusTheme.accentPrimary.withValues(alpha: 0.2)
                  : textColor.withValues(alpha: 0.05),
              border: Border.all(
                color: (_formValues[fieldId] as bool? ?? false)
                    ? context.nexusTheme.accentPrimary
                    : borderColor,
              ),
              borderRadius: BorderRadius.circular(r.s(8)),
            ),
            child: Row(
              children: [
                Container(
                  width: r.s(20),
                  height: r.s(20),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: (_formValues[fieldId] as bool? ?? false)
                          ? context.nexusTheme.accentPrimary
                          : borderColor,
                    ),
                    borderRadius: BorderRadius.circular(r.s(4)),
                  ),
                  child: (_formValues[fieldId] as bool? ?? false)
                      ? Center(
                          child: Icon(
                            Icons.check_rounded,
                            size: r.s(14),
                            color: context.nexusTheme.accentPrimary,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: r.s(12)),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: r.fs(13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final s = ref.read(stringsProvider);
    final textColor = widget.isMe ? Colors.white : context.nexusTheme.textPrimary;

    return Container(
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: widget.isMe
            ? context.nexusTheme.accentPrimary.withValues(alpha: 0.15)
            : context.nexusTheme.surfacePrimary.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(
          color: context.nexusTheme.accentSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone e título
          Row(
            children: [
              Icon(
                Icons.assignment_rounded,
                size: r.s(18),
                color: context.nexusTheme.accentPrimary,
              ),
              SizedBox(width: r.s(8)),
              Expanded(
                child: Text(
                  widget.formTitle,
                  style: TextStyle(
                    color: textColor,
                    fontSize: r.fs(14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          // Descrição (se houver)
          if (widget.formDescription != null && widget.formDescription!.isNotEmpty) ...[
            SizedBox(height: r.s(8)),
            Text(
              widget.formDescription!,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: r.fs(12),
              ),
            ),
          ],

          // Status de resposta
          if (_hasResponded) ...[
            SizedBox(height: r.s(8)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.s(8),
                vertical: r.s(4),
              ),
              decoration: BoxDecoration(
                color: context.nexusTheme.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(r.s(6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: r.s(14),
                    color: context.nexusTheme.success,
                  ),
                  SizedBox(width: r.s(4)),
                  Text(
                    'Respondido',
                    style: TextStyle(
                      color: context.nexusTheme.success,
                      fontSize: r.fs(11),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Campos
          SizedBox(height: r.s(12)),
          ...widget.fields.map((field) {
            if (field is! Map<String, dynamic>) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.only(bottom: r.s(12)),
              child: _buildField(field),
            );
          }).toList(),

          // Botão de envio
          if (!_hasResponded)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.nexusTheme.accentPrimary,
                  disabledBackgroundColor: context.nexusTheme.accentPrimary.withValues(alpha: 0.5),
                  padding: EdgeInsets.symmetric(vertical: r.s(12)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: r.s(18),
                        width: r.s(18),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            widget.isMe ? Colors.white : context.nexusTheme.textPrimary,
                          ),
                        ),
                      )
                    : Text(
                        s.send,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.fs(14),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
