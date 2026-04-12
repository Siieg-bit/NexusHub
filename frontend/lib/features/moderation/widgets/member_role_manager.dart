import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

// =============================================================================
// MemberRoleManager — Gerenciamento de Hierarquia e Títulos de Membros
//
// Exibido como bottom sheet ao tocar em "Gerenciar Cargo" no perfil de um
// membro dentro da comunidade.
//
// Funcionalidades:
//   - Promover para Curador / Moderador
//   - Demitir de cargo atual
//   - Dar título customizado (tag personalizada)
//   - Remover título customizado
// =============================================================================

/// Exibe o gerenciador de cargo/título de um membro como bottom sheet.
Future<bool?> showMemberRoleManager({
  required BuildContext context,
  required WidgetRef ref,
  required String communityId,
  required String targetUserId,
  required String targetUserName,
  required String currentRole,
  String? currentTitle,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _MemberRoleManagerSheet(
      communityId: communityId,
      targetUserId: targetUserId,
      targetUserName: targetUserName,
      currentRole: currentRole,
      currentTitle: currentTitle,
    ),
  );
}

class _MemberRoleManagerSheet extends ConsumerStatefulWidget {
  final String communityId;
  final String targetUserId;
  final String targetUserName;
  final String currentRole;
  final String? currentTitle;

  const _MemberRoleManagerSheet({
    required this.communityId,
    required this.targetUserId,
    required this.targetUserName,
    required this.currentRole,
    this.currentTitle,
  });

  @override
  ConsumerState<_MemberRoleManagerSheet> createState() =>
      _MemberRoleManagerSheetState();
}

class _MemberRoleManagerSheetState
    extends ConsumerState<_MemberRoleManagerSheet> {
  bool _isLoading = false;
  final _titleController = TextEditingController();
  final _titleColorController = TextEditingController(text: '#FFFFFF');
  String _selectedTitleColor = '#FFFFFF';
  bool _showTitleEditor = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentTitle != null) {
      _titleController.text = widget.currentTitle!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleColorController.dispose();
    super.dispose();
  }

  /// Promove ou demite o membro via RPC
  Future<void> _changeRole(String newRole) async {
    setState(() => _isLoading = true);
    try {
      final result = await SupabaseService.rpc('change_member_role', params: {
        'p_community_id': widget.communityId,
        'p_target_user_id': widget.targetUserId,
        'p_new_role': newRole,
        'p_reason': newRole == 'member'
            ? 'Demitido do cargo ${widget.currentRole}'
            : 'Promovido para $newRole',
      });

      if (!mounted) return;
      final error = result is Map ? result['error'] : null;
      if (error != null) {
        String msg = 'Erro ao alterar cargo.';
        if (error == 'insufficient_permissions') {
          msg = 'Você não tem permissão para alterar este cargo.';
        } else if (error == 'cannot_change_agent_role') {
          msg = 'O cargo de Agente não pode ser alterado aqui.';
        } else if (error == 'leaders_can_only_manage_curators') {
          msg = 'Líderes só podem gerenciar Curadores.';
        } else if (error == 'not_authenticated') {
          msg = 'Você precisa estar autenticado.';
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      } else {
        final label = _roleLabel(newRole);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newRole == 'member'
              ? '${widget.targetUserName} foi demitido do cargo.'
              : '${widget.targetUserName} foi promovido para $label!'),
          backgroundColor: context.nexusTheme.accentPrimary,
          behavior: SnackBarBehavior.floating,
        ));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Dá ou remove título customizado via RPC
  Future<void> _saveCustomTitle() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe um título.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final titleResult = await SupabaseService.rpc('manage_member_title', params: {
        'p_community_id': widget.communityId,
        'p_target_user_id': widget.targetUserId,
        'p_action': 'add',
        'p_title': title,
        'p_color': _selectedTitleColor,
      });

      if (!mounted) return;
      final titleError = titleResult is Map ? titleResult['error'] : null;
      if (titleError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $titleError')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Título "$title" atribuído a ${widget.targetUserName}!'),
          backgroundColor: context.nexusTheme.accentPrimary,
          behavior: SnackBarBehavior.floating,
        ));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Remove o título customizado do membro via RPC manage_member_title
  Future<void> _removeCustomTitle() async {
    final titleToRemove = widget.currentTitle ?? _titleController.text.trim();
    if (titleToRemove.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum título para remover.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final removeResult = await SupabaseService.rpc('manage_member_title', params: {
        'p_community_id': widget.communityId,
        'p_target_user_id': widget.targetUserId,
        'p_action': 'remove',
        'p_title': titleToRemove,
      });

      if (!mounted) return;
      final removeError = removeResult is Map ? removeResult['error'] : null;
      if (removeError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $removeError')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Título removido de ${widget.targetUserName}.'),
          behavior: SnackBarBehavior.floating,
        ));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'agent': return 'Agente (Líder)';
      case 'leader': return 'Líder';
      case 'curator': return 'Curador';
      case 'moderator': return 'Moderador';
      default: return 'Membro';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'agent': return const Color(0xFFFFD600);
      case 'leader': return const Color(0xFFFF6B35);
      case 'curator': return const Color(0xFF7C4DFF);
      case 'moderator': return const Color(0xFF00BCD4);
      default: return Colors.grey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'agent': return Icons.shield_rounded;
      case 'leader': return Icons.star_rounded;
      case 'curator': return Icons.auto_awesome_rounded;
      case 'moderator': return Icons.security_rounded;
      default: return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final currentRoleColor = _roleColor(widget.currentRole);
    final currentRoleLabel = _roleLabel(widget.currentRole);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
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
            // Título
            Padding(
              padding: EdgeInsets.symmetric(
                  vertical: r.s(16), horizontal: r.s(20)),
              child: Column(
                children: [
                  Text(
                    'Gerenciar Cargo',
                    style: TextStyle(
                      color: context.nexusTheme.accentPrimary,
                      fontSize: r.fs(18),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: r.s(4)),
                  // Cargo atual
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(12), vertical: r.s(6)),
                    decoration: BoxDecoration(
                      color: currentRoleColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(r.s(20)),
                      border: Border.all(
                          color: currentRoleColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_roleIcon(widget.currentRole),
                            color: currentRoleColor, size: r.s(14)),
                        SizedBox(width: r.s(6)),
                        Text(
                          '${widget.targetUserName} — $currentRoleLabel',
                          style: TextStyle(
                            color: currentRoleColor,
                            fontSize: r.fs(13),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.5),

            if (_isLoading)
              Padding(
                padding: EdgeInsets.all(r.s(24)),
                child: const CircularProgressIndicator(
                    color: context.nexusTheme.accentPrimary),
              )
            else ...[
              // ── SEÇÃO: PROMOÇÃO / DEMISSÃO ──────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(r.s(20), r.s(16), r.s(20), r.s(8)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'CARGO',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: r.fs(11),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              // Opções de cargo (exceto agent — não pode ser transferido aqui)
              ...['leader', 'curator', 'moderator', 'member'].map((role) {
                final isCurrentRole = widget.currentRole == role;
                final roleColor = _roleColor(role);
                final roleLabel = _roleLabel(role);
                final isDemote = role == 'member';

                return Column(
                  children: [
                    InkWell(
                      onTap: isCurrentRole ? null : () => _changeRole(role),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(20), vertical: r.s(14)),
                        child: Row(
                          children: [
                            Container(
                              width: r.s(36),
                              height: r.s(36),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_roleIcon(role),
                                  color: roleColor, size: r.s(18)),
                            ),
                            SizedBox(width: r.s(14)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isDemote ? 'Demitir (Membro)' : 'Promover para $roleLabel',
                                    style: TextStyle(
                                      color: isDemote
                                          ? Colors.red[400]
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                      fontWeight: FontWeight.w600,
                                      fontSize: r.fs(14),
                                    ),
                                  ),
                                  Text(
                                    _roleDescription(role),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: r.fs(12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrentRole)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.s(8), vertical: r.s(4)),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(r.s(10)),
                                ),
                                child: Text(
                                  'Atual',
                                  style: TextStyle(
                                    color: roleColor,
                                    fontSize: r.fs(11),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, thickness: 0.5),
                  ],
                );
              }),

              // ── SEÇÃO: TÍTULO CUSTOMIZADO ────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(r.s(20), r.s(16), r.s(20), r.s(8)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'TÍTULO CUSTOMIZADO',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: r.fs(11),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    if (widget.currentTitle != null)
                      TextButton(
                        onPressed: _removeCustomTitle,
                        child: Text(
                          'Remover',
                          style: TextStyle(
                              color: Colors.red[400], fontSize: r.fs(12)),
                        ),
                      ),
                  ],
                ),
              ),

              if (!_showTitleEditor)
                InkWell(
                  onTap: () => setState(() => _showTitleEditor = true),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(20), vertical: r.s(14)),
                    child: Row(
                      children: [
                        Container(
                          width: r.s(36),
                          height: r.s(36),
                          decoration: BoxDecoration(
                            color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.label_rounded,
                              color: context.nexusTheme.accentPrimary, size: r.s(18)),
                        ),
                        SizedBox(width: r.s(14)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.currentTitle != null
                                    ? 'Editar Título: "${widget.currentTitle}"'
                                    : 'Dar Título Customizado',
                                style: TextStyle(
                                  color: context.nexusTheme.accentPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: r.fs(14),
                                ),
                              ),
                              Text(
                                'Exibido no perfil do membro na comunidade',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: r.fs(12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.grey[600]),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.fromLTRB(r.s(20), 0, r.s(20), r.s(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _titleController,
                        maxLength: 30,
                        decoration: InputDecoration(
                          labelText: 'Título',
                          hintText: 'Ex: Fundador, Veterano, Artista...',
                          filled: true,
                          fillColor: Theme.of(context).scaffoldBackgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(r.s(10)),
                            borderSide: BorderSide.none,
                          ),
                          counterText: '',
                        ),
                      ),
                      SizedBox(height: r.s(10)),
                      // Seletor de cor do título
                      Text(
                        'Cor do título',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: r.fs(12)),
                      ),
                      SizedBox(height: r.s(8)),
                      Wrap(
                        spacing: r.s(8),
                        runSpacing: r.s(8),
                        children: [
                          '#FFFFFF', '#FFD600', '#FF6B35', '#7C4DFF',
                          '#00BCD4', '#4CAF50', '#FF5722', '#E91E63',
                        ].map((hex) {
                          Color c;
                          try {
                            c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                          } catch (_) {
                            c = Colors.white;
                          }
                          final isSelected = _selectedTitleColor == hex;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedTitleColor = hex;
                              _titleColorController.text = hex;
                            }),
                            child: Container(
                              width: r.s(32),
                              height: r.s(32),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: r.s(2.5),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                            color: c.withValues(alpha: 0.5),
                                            blurRadius: 6)
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? Icon(Icons.check_rounded,
                                      color: c.computeLuminance() > 0.5
                                          ? Colors.black
                                          : Colors.white,
                                      size: r.s(16))
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: r.s(16)),
                      // Preview do título
                      if (_titleController.text.isNotEmpty)
                        Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(12), vertical: r.s(6)),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(r.s(20)),
                              border: Border.all(
                                color: Color(int.tryParse(
                                        _selectedTitleColor.replaceFirst(
                                            '#', '0xFF')) ??
                                    0xFFFFFFFF)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              _titleController.text,
                              style: TextStyle(
                                color: Color(int.tryParse(
                                        _selectedTitleColor.replaceFirst(
                                            '#', '0xFF')) ??
                                    0xFFFFFFFF),
                                fontWeight: FontWeight.w700,
                                fontSize: r.fs(13),
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: r.s(16)),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setState(() => _showTitleEditor = false),
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
                              onPressed: _saveCustomTitle,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.nexusTheme.accentPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(r.s(10)),
                                ),
                              ),
                              child: const Text('Salvar Título',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const Divider(height: 1, thickness: 0.5),
            ],

            // Botão Fechar
            Padding(
              padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16),
                  r.s(16) + MediaQuery.of(context).padding.bottom),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: r.s(14)),
                    side: BorderSide(color: Colors.grey[700]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(10)),
                    ),
                  ),
                  child: Text(
                    'Fechar',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: r.fs(15),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleDescription(String role) {
    switch (role) {
      case 'leader':
        return 'Pode gerenciar moderadores e curadores';
      case 'curator':
        return 'Pode destacar e fixar conteúdo';
      case 'moderator':
        return 'Pode banir e moderar membros';
      case 'member':
        return 'Remove todos os cargos de staff';
      default:
        return '';
    }
  }
}
