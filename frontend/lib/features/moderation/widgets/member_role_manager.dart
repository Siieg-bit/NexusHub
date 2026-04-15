import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/rgb_color_picker.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// =============================================================================
// MemberRoleManager — Gerenciamento de Hierarquia e Títulos de Membros
//
// Funcionalidades:
//   - Promover/demitir (Líder, Curador, Moderador, Membro)
//   - Dar/editar/remover título customizado com color picker
//   - Banir membro (com duração: 1d, 7d, 30d, permanente)
//   - Aplicar strike/advertência
//   - Ocultar perfil na comunidade
//   - Transferência de título de Líder Fundador (agent → outro leader)
//   - Suporte a auto-gerenciamento (líder atribuindo título a si mesmo)
//
// Hierarquia de permissões:
//   agent  → pode gerenciar qualquer um, incluindo leaders
//   leader → pode gerenciar moderators/curators/members
//   curator/moderator → sem acesso a este widget
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
  /// Role do usuário que está abrindo o painel
  String callerRole = 'member',
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
      callerRole: callerRole,
    ),
  );
}

class _MemberRoleManagerSheet extends ConsumerStatefulWidget {
  final String communityId;
  final String targetUserId;
  final String targetUserName;
  final String currentRole;
  final String? currentTitle;
  final String callerRole;

  const _MemberRoleManagerSheet({
    required this.communityId,
    required this.targetUserId,
    required this.targetUserName,
    required this.currentRole,
    this.currentTitle,
    this.callerRole = 'member',
  });

  @override
  ConsumerState<_MemberRoleManagerSheet> createState() =>
      _MemberRoleManagerSheetState();
}

class _MemberRoleManagerSheetState
    extends ConsumerState<_MemberRoleManagerSheet> {
  bool _isLoading = false;
  final _titleController = TextEditingController();
  String _selectedTitleColor = '#FFFFFF';
  bool _showTitleEditor = false;

  // Ban
  String _banDuration = '7d';

  bool get _isSelf =>
      widget.targetUserId == SupabaseService.currentUserId;

  bool get _canManageRoles =>
      !_isSelf &&
      (widget.callerRole == 'agent' ||
          (widget.callerRole == 'leader' &&
              widget.currentRole != 'agent' &&
              widget.currentRole != 'leader'));

  bool get _canBanAndPunish =>
      !_isSelf &&
      (widget.callerRole == 'agent' ||
          (widget.callerRole == 'leader' &&
              widget.currentRole != 'agent' &&
              widget.currentRole != 'leader') ||
          (widget.callerRole == 'moderator' &&
              widget.currentRole == 'member'));

  bool get _canTransferFounder =>
      !_isSelf &&
      widget.callerRole == 'agent' &&
      widget.currentRole == 'leader';

  // Auto-título: líder pode atribuir título a si mesmo
  bool get _canSelfTitle =>
      _isSelf &&
      (widget.callerRole == 'agent' || widget.callerRole == 'leader');

  bool get _canManageTitle => _canManageRoles || _canSelfTitle;

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
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // AÇÕES
  // ──────────────────────────────────────────────────────────────────────────

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
          msg = 'O cargo de Agente (Fundador) não pode ser alterado aqui.';
        } else if (error == 'leaders_can_only_manage_curators') {
          msg = 'Líderes só podem gerenciar Curadores e Moderadores.';
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

  Future<void> _saveCustomTitle() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe um título.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await SupabaseService.rpc('manage_member_title', params: {
        'p_community_id': widget.communityId,
        'p_target_user_id': widget.targetUserId,
        'p_action': 'add',
        'p_title': title,
        'p_color': _selectedTitleColor,
      });

      if (!mounted) return;
      final error = result is Map ? result['error'] : null;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $error')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isSelf
              ? 'Seu título foi definido como "$title"!'
              : 'Título "$title" atribuído a ${widget.targetUserName}!'),
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

  Future<void> _removeCustomTitle() async {
    final titleToRemove = widget.currentTitle ?? _titleController.text.trim();
    if (titleToRemove.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final result = await SupabaseService.rpc('manage_member_title', params: {
        'p_community_id': widget.communityId,
        'p_target_user_id': widget.targetUserId,
        'p_action': 'remove',
        'p_title': titleToRemove,
      });

      if (!mounted) return;
      final error = result is Map ? result['error'] : null;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $error')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isSelf
              ? 'Seu título foi removido.'
              : 'Título removido de ${widget.targetUserName}.'),
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

  Future<void> _banMember() async {
    final r = context.r;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: ctx.surfaceColor,
          title: Text('Banir ${widget.targetUserName}?',
              style: TextStyle(color: ctx.nexusTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Duração do ban:',
                  style: TextStyle(
                      color: ctx.nexusTheme.textSecondary,
                      fontSize: r.fs(13))),
              SizedBox(height: r.s(8)),
              ...[
                ('1d', '1 dia'),
                ('7d', '7 dias'),
                ('30d', '30 dias'),
                ('permanent', 'Permanente'),
              ].map((e) => RadioListTile<String>(
                    value: e.$1,
                    groupValue: _banDuration,
                    onChanged: (v) => setS(() => _banDuration = v!),
                    title: Text(e.$2,
                        style: TextStyle(
                            color: ctx.nexusTheme.textPrimary,
                            fontSize: r.fs(13))),
                    activeColor: ctx.nexusTheme.error,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ctx.nexusTheme.error),
              child:
                  const Text('Banir', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await SupabaseService.rpc('ban_community_member', params: {
        'p_community_id': widget.communityId,
        'p_target_user_id': widget.targetUserId,
        'p_duration': _banDuration,
        'p_reason': 'Banido por ${_roleLabel(widget.callerRole)}',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.targetUserName} foi banido.'),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao banir: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _strikeWarning() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.rpc('apply_member_strike', params: {
        'p_community_id': widget.communityId,
        'p_target_user_id': widget.targetUserId,
        'p_reason': 'Strike aplicado por ${_roleLabel(widget.callerRole)}',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Strike aplicado a ${widget.targetUserName}.'),
          backgroundColor: context.nexusTheme.warning,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao aplicar strike: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _hideProfile() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.table('community_members').update({
        'is_hidden': true,
      })
          .eq('community_id', widget.communityId)
          .eq('user_id', widget.targetUserId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Perfil de ${widget.targetUserName} ocultado na comunidade.'),
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao ocultar perfil: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _transferFounderTitle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surfaceColor,
        title: Text('Transferir título de Fundador?',
            style: TextStyle(color: ctx.nexusTheme.textPrimary)),
        content: Text(
          'Você perderá o título de Líder Fundador. '
          '${widget.targetUserName} receberá o cargo de Agente (Fundador). '
          'Esta ação não pode ser desfeita.',
          style: TextStyle(color: ctx.nexusTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD600)),
            child: const Text('Transferir',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await SupabaseService.rpc('transfer_founder_title', params: {
        'p_community_id': widget.communityId,
        'p_new_founder_id': widget.targetUserId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${widget.targetUserName} é o novo Líder Fundador desta comunidade.'),
          backgroundColor: const Color(0xFFFFD600),
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao transferir: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  String _roleLabel(String role) {
    switch (role) {
      case 'agent':
        return 'Agente (Fundador)';
      case 'leader':
        return 'Líder';
      case 'curator':
        return 'Curador';
      case 'moderator':
        return 'Moderador';
      default:
        return 'Membro';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'agent':
        return const Color(0xFFFFD600);
      case 'leader':
        return const Color(0xFFFF6B35);
      case 'curator':
        return const Color(0xFF7C4DFF);
      case 'moderator':
        return const Color(0xFF00BCD4);
      default:
        return Colors.grey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'agent':
        return Icons.shield_rounded;
      case 'leader':
        return Icons.star_rounded;
      case 'curator':
        return Icons.auto_awesome_rounded;
      case 'moderator':
        return Icons.security_rounded;
      default:
        return Icons.person_rounded;
    }
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

  Widget _sectionHeader(String label, Responsive r) => Padding(
        padding: EdgeInsets.fromLTRB(r.s(20), r.s(16), r.s(20), r.s(8)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: r.fs(11),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final currentRoleColor = _roleColor(widget.currentRole);
    final currentRoleLabel = _roleLabel(widget.currentRole);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            Container(
              margin: EdgeInsets.only(top: r.s(12), bottom: r.s(4)),
              width: r.s(40),
              height: r.s(4),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(r.s(2)),
              ),
            ),

            // ── Cabeçalho ───────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                  vertical: r.s(16), horizontal: r.s(20)),
              child: Column(
                children: [
                  Text(
                    _isSelf ? 'Meu Cargo & Título' : 'Gerenciar Membro',
                    style: TextStyle(
                      color: context.nexusTheme.accentPrimary,
                      fontSize: r.fs(18),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: r.s(4)),
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
                child: CircularProgressIndicator(
                    color: context.nexusTheme.accentPrimary),
              )
            else ...[

              // ── SEÇÃO: PROMOÇÃO / DEMISSÃO ────────────────────────────────
              if (_canManageRoles) ...[
                _sectionHeader('CARGO', r),
                ...['leader', 'curator', 'moderator', 'member'].map((role) {
                  final isCurrentRole = widget.currentRole == role;
                  final roleColor = _roleColor(role);
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isDemote
                                          ? 'Demitir (Membro)'
                                          : 'Promover para ${_roleLabel(role)}',
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
                                    borderRadius:
                                        BorderRadius.circular(r.s(10)),
                                  ),
                                  child: Text(
                                    'Atual',
                                    style: TextStyle(
                                        color: roleColor,
                                        fontSize: r.fs(11),
                                        fontWeight: FontWeight.w700),
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
              ],

              // ── SEÇÃO: TÍTULO CUSTOMIZADO ─────────────────────────────────
              if (_canManageTitle) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      r.s(20), r.s(16), r.s(20), r.s(8)),
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
                          child: Text('Remover',
                              style: TextStyle(
                                  color: Colors.red[400],
                                  fontSize: r.fs(12))),
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
                              color: context.nexusTheme.accentPrimary
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.label_rounded,
                                color: context.nexusTheme.accentPrimary,
                                size: r.s(18)),
                          ),
                          SizedBox(width: r.s(14)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.currentTitle != null
                                      ? 'Editar: "${widget.currentTitle}"'
                                      : _isSelf
                                          ? 'Definir meu título'
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
                                      fontSize: r.fs(12)),
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
                    padding: EdgeInsets.fromLTRB(
                        r.s(20), 0, r.s(20), r.s(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _titleController,
                          maxLength: 30,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Título',
                            hintText: 'Ex: Fundador, Veterano, Artista...',
                            filled: true,
                            fillColor:
                                Theme.of(context).scaffoldBackgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(r.s(10)),
                              borderSide: BorderSide.none,
                            ),
                            counterText: '',
                          ),
                        ),
                        SizedBox(height: r.s(10)),

                        // Color picker integrado
                        Row(
                          children: [
                            Text('Cor do título',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: r.fs(12))),
                            const Spacer(),
                            GestureDetector(
                              onTap: () async {
                                Color initial;
                                try {
                                  initial = Color(int.parse(
                                      _selectedTitleColor
                                          .replaceFirst('#', '0xFF')));
                                } catch (_) {
                                  initial = Colors.white;
                                }
                                final picked = await showRGBColorPicker(
                                  context,
                                  initialColor: initial,
                                  title: 'Cor do Título',
                                );
                                if (picked != null && mounted) {
                                  final hex =
                                      '#${picked.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                                  setState(() => _selectedTitleColor = hex);
                                }
                              },
                              child: Container(
                                width: r.s(28),
                                height: r.s(28),
                                decoration: BoxDecoration(
                                  color: () {
                                    try {
                                      return Color(int.parse(
                                          _selectedTitleColor
                                              .replaceFirst('#', '0xFF')));
                                    } catch (_) {
                                      return Colors.white;
                                    }
                                  }(),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white38, width: 2),
                                ),
                              ),
                            ),
                            SizedBox(width: r.s(8)),
                            Text(
                              _selectedTitleColor,
                              style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: r.fs(12),
                                  fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                        SizedBox(height: r.s(10)),

                        // Paleta rápida
                        Wrap(
                          spacing: r.s(8),
                          runSpacing: r.s(8),
                          children: [
                            '#FFFFFF', '#FFD600', '#FF6B35', '#7C4DFF',
                            '#00BCD4', '#4CAF50', '#FF5722', '#E91E63',
                          ].map((hex) {
                            Color c;
                            try {
                              c = Color(int.parse(
                                  hex.replaceFirst('#', '0xFF')));
                            } catch (_) {
                              c = Colors.white;
                            }
                            final isSelected = _selectedTitleColor == hex;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedTitleColor = hex),
                              child: Container(
                                width: r.s(28),
                                height: r.s(28),
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
                                        size: r.s(14))
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),

                        SizedBox(height: r.s(12)),

                        // Preview
                        if (_titleController.text.isNotEmpty)
                          Center(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: r.s(12), vertical: r.s(6)),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius:
                                    BorderRadius.circular(r.s(20)),
                                border: Border.all(
                                  color: () {
                                    try {
                                      return Color(int.parse(
                                              _selectedTitleColor.replaceFirst(
                                                  '#', '0xFF')))
                                          .withValues(alpha: 0.5);
                                    } catch (_) {
                                      return Colors.white38;
                                    }
                                  }(),
                                ),
                              ),
                              child: Text(
                                _titleController.text,
                                style: TextStyle(
                                  color: () {
                                    try {
                                      return Color(int.parse(
                                          _selectedTitleColor
                                              .replaceFirst('#', '0xFF')));
                                    } catch (_) {
                                      return Colors.white;
                                    }
                                  }(),
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
                                onPressed: () => setState(
                                    () => _showTitleEditor = false),
                                style: OutlinedButton.styleFrom(
                                  side:
                                      BorderSide(color: Colors.grey[700]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(r.s(10)),
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
                                  backgroundColor:
                                      context.nexusTheme.accentPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(r.s(10)),
                                  ),
                                ),
                                child: const Text('Salvar Título',
                                    style:
                                        TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1, thickness: 0.5),
              ],

              // ── SEÇÃO: AÇÕES DISCIPLINARES ────────────────────────────────
              if (_canBanAndPunish) ...[
                _sectionHeader('AÇÕES DISCIPLINARES', r),

                // Strike / Advertência
                InkWell(
                  onTap: _strikeWarning,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(20), vertical: r.s(14)),
                    child: Row(
                      children: [
                        Container(
                          width: r.s(36),
                          height: r.s(36),
                          decoration: BoxDecoration(
                            color: context.nexusTheme.warning
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.warning_rounded,
                              color: context.nexusTheme.warning,
                              size: r.s(18)),
                        ),
                        SizedBox(width: r.s(14)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Aplicar Strike',
                                  style: TextStyle(
                                    color: context.nexusTheme.warning,
                                    fontWeight: FontWeight.w600,
                                    fontSize: r.fs(14),
                                  )),
                              Text('Advertência formal registrada no histórico',
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: r.fs(12))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 0.5),

                // Ocultar perfil
                InkWell(
                  onTap: _hideProfile,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(20), vertical: r.s(14)),
                    child: Row(
                      children: [
                        Container(
                          width: r.s(36),
                          height: r.s(36),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.visibility_off_rounded,
                              color: Colors.grey[400], size: r.s(18)),
                        ),
                        SizedBox(width: r.s(14)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ocultar Perfil na Comunidade',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontWeight: FontWeight.w600,
                                    fontSize: r.fs(14),
                                  )),
                              Text('O perfil fica invisível para outros membros',
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: r.fs(12))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 0.5),

                // Banir
                InkWell(
                  onTap: _banMember,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(20), vertical: r.s(14)),
                    child: Row(
                      children: [
                        Container(
                          width: r.s(36),
                          height: r.s(36),
                          decoration: BoxDecoration(
                            color: context.nexusTheme.error
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.block_rounded,
                              color: context.nexusTheme.error,
                              size: r.s(18)),
                        ),
                        SizedBox(width: r.s(14)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Banir da Comunidade',
                                  style: TextStyle(
                                    color: context.nexusTheme.error,
                                    fontWeight: FontWeight.w600,
                                    fontSize: r.fs(14),
                                  )),
                              Text('Remove e impede o acesso à comunidade',
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: r.fs(12))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 0.5),
              ],

              // ── SEÇÃO: FUNDADOR ───────────────────────────────────────────
              if (_canTransferFounder) ...[
                _sectionHeader('LÍDER FUNDADOR', r),
                InkWell(
                  onTap: _transferFounderTitle,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(20), vertical: r.s(14)),
                    child: Row(
                      children: [
                        Container(
                          width: r.s(36),
                          height: r.s(36),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFFD600).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_rounded,
                              color: Color(0xFFFFD600), size: 18),
                        ),
                        SizedBox(width: r.s(14)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Transferir título de Fundador',
                                  style: TextStyle(
                                    color: const Color(0xFFFFD600),
                                    fontWeight: FontWeight.w600,
                                    fontSize: r.fs(14),
                                  )),
                              Text(
                                  '${widget.targetUserName} assumirá como Agente',
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: r.fs(12))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 0.5),
              ],

            ],

            // ── Fechar ────────────────────────────────────────────────────
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
}
