import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/amino_custom_title.dart';
import '../../../core/widgets/rgb_color_picker.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// =============================================================================
// ManageMemberTitlesSheet — Gerenciamento de títulos customizados de um membro
//
// Acessível via: Opções de moderação > Gerenciar Títulos
//
// Funcionalidades:
//   - Listar todos os títulos customizados do membro (excluindo role badges)
//   - Adicionar novo título (texto + cor customizável)
//   - Editar título existente
//   - Remover título
//   - Limite de 20 títulos por membro
//   - Preview em tempo real com AminoCustomTitle
//
// Regras:
//   - Apenas líderes (leader/agent) podem gerenciar títulos de outros membros
//   - Usa RPC manage_member_title e get_member_titles_full
// =============================================================================

/// Exibe o gerenciador de títulos customizados como bottom sheet.
Future<bool?> showManageMemberTitlesSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String communityId,
  required String targetUserId,
  required String targetUserName,
  required String callerRole,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ManageMemberTitlesSheet(
      communityId: communityId,
      targetUserId: targetUserId,
      targetUserName: targetUserName,
      callerRole: callerRole,
    ),
  );
}

class _ManageMemberTitlesSheet extends ConsumerStatefulWidget {
  final String communityId;
  final String targetUserId;
  final String targetUserName;
  final String callerRole;

  const _ManageMemberTitlesSheet({
    required this.communityId,
    required this.targetUserId,
    required this.targetUserName,
    required this.callerRole,
  });

  @override
  ConsumerState<_ManageMemberTitlesSheet> createState() =>
      _ManageMemberTitlesSheetState();
}

class _ManageMemberTitlesSheetState
    extends ConsumerState<_ManageMemberTitlesSheet> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _titles = [];
  bool _showAddForm = false;
  Map<String, dynamic>? _editingTitle; // título sendo editado

  final _titleController = TextEditingController();
  String _selectedColor = '#7C4DFF';

  static const int _maxTitles = 20;
  static const List<String> _quickColors = [
    '#7C4DFF', '#2DBE60', '#2196F3', '#FF6B35',
    '#FFD600', '#E91E63', '#00BCD4', '#FF5722',
    '#FFFFFF', '#9E9E9E', '#FF1744', '#00E676',
  ];

  @override
  void initState() {
    super.initState();
    _loadTitles();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadTitles() async {
    setState(() => _isLoading = true);
    try {
      final result = await SupabaseService.rpc('get_member_titles_full', params: {
        'p_community_id': widget.communityId,
        'p_user_id': widget.targetUserId,
      });
      if (!mounted) return;
      final List<Map<String, dynamic>> allTitles = [];
      if (result is List) {
        for (final item in result) {
          if (item is Map) {
            // Excluir role badges — líderes não gerenciam esses
            if (item['is_role_badge'] != true) {
              allTitles.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }
      setState(() {
        _titles = allTitles;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[ManageMemberTitlesSheet] _loadTitles error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar títulos: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _startAdd() {
    setState(() {
      _editingTitle = null;
      _titleController.clear();
      _selectedColor = '#7C4DFF';
      _showAddForm = true;
    });
  }

  void _startEdit(Map<String, dynamic> title) {
    setState(() {
      _editingTitle = title;
      _titleController.text = title['title'] as String? ?? '';
      _selectedColor = title['color'] as String? ?? '#7C4DFF';
      _showAddForm = true;
    });
  }

  void _cancelForm() {
    setState(() {
      _showAddForm = false;
      _editingTitle = null;
      _titleController.clear();
    });
  }

  Future<void> _saveTitle() async {
    final titleText = _titleController.text.trim();
    if (titleText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um título.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final result = await SupabaseService.rpc('manage_member_title', params: {
        'p_community_id': widget.communityId,
        'p_target_user_id': widget.targetUserId,
        'p_action': 'add',
        'p_title': titleText,
        'p_color': _selectedColor,
      });

      if (!mounted) return;
      final error = result is Map ? result['error'] : null;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $error'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Notificação ao membro (não crítica)
        try {
          await SupabaseService.rpc('send_moderation_notification', params: {
            'p_community_id': widget.communityId,
            'p_user_id': widget.targetUserId,
            'p_type': 'moderation',
            'p_title': 'Novo título recebido',
            'p_body': 'Você recebeu o título "$titleText" nesta comunidade.',
          });
        } catch (_) {}

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Título "$titleText" adicionado!'),
            backgroundColor: context.nexusTheme.accentPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _cancelForm();
        await _loadTitles();
      }
    } catch (e) {
      debugPrint('[ManageMemberTitlesSheet] _saveTitle error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeTitle(Map<String, dynamic> title) async {
    final titleText = title['title'] as String? ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surfaceColor,
        title: Text(
          'Remover título?',
          style: TextStyle(color: ctx.nexusTheme.textPrimary),
        ),
        content: Text(
          'Deseja remover o título "$titleText" de ${widget.targetUserName}?',
          style: TextStyle(color: ctx.nexusTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final result = await SupabaseService.rpc('manage_member_title', params: {
        'p_community_id': widget.communityId,
        'p_target_user_id': widget.targetUserId,
        'p_action': 'remove',
        'p_title': titleText,
      });

      if (!mounted) return;
      final error = result is Map ? result['error'] : null;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $error'), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Título "$titleText" removido.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadTitles();
      }
    } catch (e) {
      debugPrint('[ManageMemberTitlesSheet] _removeTitle error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF7C4DFF);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: r.s(12), bottom: r.s(4)),
            width: r.s(40),
            height: r.s(4),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(r.s(2)),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(20), vertical: r.s(12)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gerenciar Títulos',
                        style: TextStyle(
                          color: context.nexusTheme.accentPrimary,
                          fontSize: r.fs(18),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        widget.targetUserName,
                        style: TextStyle(
                          color: context.nexusTheme.textSecondary,
                          fontSize: r.fs(13),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_showAddForm && _titles.length < _maxTitles)
                  TextButton.icon(
                    onPressed: _startAdd,
                    icon: Icon(Icons.add_rounded, size: r.s(16)),
                    label: const Text('Adicionar'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.nexusTheme.accentPrimary,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),

          // Conteúdo
          Flexible(
            child: _isLoading
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(r.s(32)),
                      child: CircularProgressIndicator(
                        color: context.nexusTheme.accentPrimary,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(r.s(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Formulário de adição/edição
                        if (_showAddForm) ...[
                          _buildAddForm(r),
                          SizedBox(height: r.s(16)),
                          const Divider(height: 1, thickness: 0.5),
                          SizedBox(height: r.s(8)),
                        ],

                        // Lista de títulos
                        if (_titles.isEmpty && !_showAddForm)
                          _buildEmptyState(r)
                        else if (_titles.isNotEmpty) ...[
                          Padding(
                            padding: EdgeInsets.only(bottom: r.s(8)),
                            child: Text(
                              'TÍTULOS ATUAIS (${_titles.length}/$_maxTitles)',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: r.fs(11),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          ..._titles.map((t) => _buildTitleRow(t, r)),
                        ],

                        // Aviso de limite
                        if (_titles.length >= _maxTitles)
                          Padding(
                            padding: EdgeInsets.only(top: r.s(12)),
                            child: Container(
                              padding: EdgeInsets.all(r.s(12)),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(r.s(10)),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Colors.orange, size: r.s(16)),
                                  SizedBox(width: r.s(8)),
                                  Expanded(
                                    child: Text(
                                      'Limite de $_maxTitles títulos atingido.',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: r.fs(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        SizedBox(height: r.s(8)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.s(32)),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.label_off_rounded, color: Colors.grey[600], size: r.s(40)),
            SizedBox(height: r.s(12)),
            Text(
              'Nenhum título customizado',
              style: TextStyle(
                color: context.nexusTheme.textSecondary,
                fontSize: r.fs(14),
              ),
            ),
            SizedBox(height: r.s(6)),
            Text(
              'Toque em "Adicionar" para criar o primeiro título.',
              style: TextStyle(color: Colors.grey[600], fontSize: r.fs(12)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow(Map<String, dynamic> title, Responsive r) {
    final titleText = title['title'] as String? ?? '';
    final colorHex = title['color'] as String? ?? '#7C4DFF';
    final titleColor = _parseColor(colorHex);

    return Padding(
      padding: EdgeInsets.only(bottom: r.s(8)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: r.s(14),
            vertical: r.s(4),
          ),
          leading: Container(
            width: r.s(32),
            height: r.s(32),
            decoration: BoxDecoration(
              color: titleColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: titleColor.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Container(
                width: r.s(12),
                height: r.s(12),
                decoration: BoxDecoration(
                  color: titleColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          title: AminoCustomTitle(
            title: titleText,
            color: titleColor,
          ),
          subtitle: Text(
            colorHex.toUpperCase(),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: r.fs(11),
              fontFamily: 'monospace',
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit_rounded,
                    color: context.nexusTheme.accentPrimary, size: r.s(18)),
                onPressed: _isSaving ? null : () => _startEdit(title),
                tooltip: 'Editar',
              ),
              IconButton(
                icon: Icon(Icons.delete_rounded,
                    color: Colors.red[400], size: r.s(18)),
                onPressed: _isSaving ? null : () => _removeTitle(title),
                tooltip: 'Remover',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddForm(Responsive r) {
    final isEditing = _editingTitle != null;
    final previewColor = _parseColor(_selectedColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título do formulário
        Padding(
          padding: EdgeInsets.only(bottom: r.s(12)),
          child: Text(
            isEditing ? 'EDITAR TÍTULO' : 'NOVO TÍTULO',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: r.fs(11),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),

        // Campo de texto
        TextField(
          controller: _titleController,
          maxLength: 30,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Texto do título',
            hintText: 'Ex: Fundador, Veterano, Artista...',
            filled: true,
            fillColor: Theme.of(context).scaffoldBackgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.s(10)),
              borderSide: BorderSide.none,
            ),
            counterText: '${_titleController.text.length}/30',
            counterStyle: TextStyle(color: Colors.grey[600], fontSize: r.fs(11)),
          ),
        ),
        SizedBox(height: r.s(12)),

        // Seletor de cor
        Row(
          children: [
            Text(
              'Cor do título',
              style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                final picked = await showRGBColorPicker(
                  context,
                  initialColor: previewColor,
                  title: 'Cor do Título',
                );
                if (picked != null && mounted) {
                  final hex =
                      '#${picked.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                  setState(() => _selectedColor = hex);
                }
              },
              child: Container(
                width: r.s(28),
                height: r.s(28),
                decoration: BoxDecoration(
                  color: previewColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 2),
                ),
              ),
            ),
            SizedBox(width: r.s(8)),
            Text(
              _selectedColor,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: r.fs(12),
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        SizedBox(height: r.s(10)),

        // Paleta rápida
        Wrap(
          spacing: r.s(8),
          runSpacing: r.s(8),
          children: _quickColors.map((hex) {
            final c = _parseColor(hex);
            final isSelected = _selectedColor.toUpperCase() == hex.toUpperCase();
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = hex),
              child: Container(
                width: r.s(28),
                height: r.s(28),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: r.s(2.5),
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)]
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        size: r.s(14),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
        SizedBox(height: r.s(14)),

        // Preview
        if (_titleController.text.isNotEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: r.s(12)),
              child: AminoCustomTitle(
                title: _titleController.text,
                color: previewColor,
              ),
            ),
          ),

        // Botões
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : _cancelForm,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[700]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(10)),
                  ),
                ),
                child: const Text('Cancelar'),
              ),
            ),
            SizedBox(width: r.s(12)),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveTitle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.nexusTheme.accentPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(10)),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        width: r.s(18),
                        height: r.s(18),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isEditing ? 'Atualizar' : 'Adicionar',
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
