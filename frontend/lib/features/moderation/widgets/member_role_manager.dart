import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/rgb_color_picker.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import 'manage_member_titles_sheet.dart';

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
// Hierarquia de permissões (rank numérico):
//   founder    (7) → Fundador: modera TODOS, único com borda branca
//   co_founder (6) → Co-Fundador: modera team_admin e abaixo
//   team_admin (5) → Administrador: modera team_mod e abaixo
//   team_mod   (4) → Moderador Global: modera todos os cargos de comunidade
//   agent      (3) → Líder Fundador: modera leader e abaixo
//   leader     (2) → Líder normal: modera curator e abaixo
//   curator    (1) → modera apenas member
//   member     (0) → sem poder de moderação
//
// Regra universal: ninguém pode moderar alguém de rank igual ou superior.
// =============================================================================

/// Retorna o rank numérico de um role string para comparações hierárquicas.
int _rankOf(String role) {
  switch (role) {
    case 'founder':    return 7;
    case 'co_founder': return 6;
    case 'team_admin': return 5;
    case 'team_mod':   return 4;
    case 'agent':      return 3;
    case 'leader':     return 2;
    case 'curator':    return 1;
    case 'moderator':  return 1; // legado, equivale a curator
    default:           return 0;
  }
}

/// Exibe o gerenciador de cargo/título de um membro como bottom sheet.
Future<bool?> showMemberRoleManager({
  required BuildContext context,
  required WidgetRef ref,
  required String communityId,
  required String targetUserId,
  required String targetUserName,
  required String currentRole,
  String? currentTitle,
  Map<String, dynamic> membershipData = const <String, dynamic>{},
  /// Role do usuário que está abrindo o painel
  String callerRole = 'member',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MemberRoleManagerSheet(
      communityId: communityId,
      targetUserId: targetUserId,
      targetUserName: targetUserName,
      currentRole: currentRole,
      currentTitle: currentTitle,
      membershipData: membershipData,
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
  final Map<String, dynamic> membershipData;
  final String callerRole;

  const _MemberRoleManagerSheet({
    required this.communityId,
    required this.targetUserId,
    required this.targetUserName,
    required this.currentRole,
    this.currentTitle,
    this.membershipData = const <String, dynamic>{},
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

  // Histórico de advertências
  List<Map<String, dynamic>> _moderationHistory = [];
  bool _historyLoaded = false;

  bool get _isSelf =>
      widget.targetUserId == SupabaseService.currentUserId;

  // ── Ranks numéricos ────────────────────────────────────────────────────────
  int get _callerRank => _rankOf(widget.callerRole);
  int get _targetRank => _rankOf(widget.currentRole);

  // O caller pode gerenciar cargos se seu rank for superior ao do alvo
  // e tiver pelo menos rank de leader (2) para alterar cargos.
  bool get _canManageRoles =>
      !_isSelf &&
      _callerRank >= 2 &&
      _callerRank > _targetRank;

  // Pode advertir/dar strike se tiver rank >= 1 (curator) e rank > alvo.
  // curator (rank 1) só pode advertir member (rank 0).
  bool get _canIssueWarnings =>
      !_isSelf &&
      _callerRank >= 1 &&
      _callerRank > _targetRank &&
      (_callerRank > 1 || _targetRank == 0);

  bool get _canHideProfile => _canIssueWarnings;

  // Pode banir se tiver rank >= 2 (leader) e rank > alvo.
  bool get _canBanMember =>
      !_isSelf &&
      _callerRank >= 2 &&
      _callerRank > _targetRank;

  bool get _canBanAndPunish =>
      _canIssueWarnings || _canHideProfile || _canBanMember;

  // Pode transferir o título de fundador se for agent (rank 3) ou team member (rank 4+)
  // e o alvo for leader (rank 2).
  bool get _canTransferFounder =>
      !_isSelf &&
      _callerRank >= 3 &&
      widget.currentRole == 'leader';

  // Auto-título: leader ou superior pode atribuir título a si mesmo
  bool get _canSelfTitle =>
      _isSelf && _callerRank >= 2;

  bool get _canManageTitle => _canManageRoles || _canSelfTitle;

  @override
  void initState() {
    super.initState();
    _loadModerationHistory();
    if (widget.currentTitle != null) {
      _titleController.text = widget.currentTitle!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadModerationHistory() async {
    try {
      final response = await SupabaseService.table('moderation_logs')
          .select('id, action, reason, created_at, moderator:profiles!moderation_logs_moderator_id_fkey(nickname)')
          .eq('community_id', widget.communityId)
          .eq('target_user_id', widget.targetUserId)
          .inFilter('action', ['warn', 'mute', 'ban', 'kick'])
          .order('created_at', ascending: false)
          .limit(20);
      if (mounted) {
        setState(() {
          _moderationHistory = List<Map<String, dynamic>>.from(response as List? ?? []);
          _historyLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _historyLoaded = true);
    }
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
          msg = 'Líderes só podem gerenciar Curadores e Membros.';
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
        // Enviar notificação ao membro que recebeu o título (apenas quando não é o próprio moderador)
        if (!_isSelf) {
          try {
            final roleLabel = _roleLabel(widget.callerRole);
            await SupabaseService.rpc('send_moderation_notification', params: {
              'p_community_id': widget.communityId,
              'p_user_id':      widget.targetUserId,
              'p_type':         'moderation',
              'p_title':        'Novo título recebido',
              'p_body':         '$roleLabel te deu o título "$title" nesta comunidade.',
            });
          } catch (_) {
            // Notificação não é crítica — ignorar falha silenciosamente
          }
        }
        if (!mounted) return;
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
    bool sendVerbalWarning = true;
    String silenceOption = 'none';
    final warningMessageController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: ctx.surfaceColor,
          title: Text(
            'Advertir ${widget.targetUserName}',
            style: TextStyle(color: ctx.nexusTheme.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                value: sendVerbalWarning,
                onChanged: (value) => setModalState(
                  () => sendVerbalWarning = value ?? false,
                ),
                contentPadding: EdgeInsets.zero,
                activeColor: ctx.nexusTheme.warning,
                title: Text(
                  'Enviar advertência verbal',
                  style: TextStyle(color: ctx.nexusTheme.textPrimary),
                ),
                subtitle: Text(
                  'Gera um aviso urgente nas notificações do membro.',
                  style: TextStyle(color: ctx.nexusTheme.textSecondary),
                ),
              ),
              if (sendVerbalWarning) ...[  
                SizedBox(height: context.r.s(8)),
                Text(
                  'Mensagem para o membro',
                  style: TextStyle(
                    color: ctx.nexusTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: context.r.s(6)),
                TextField(
                  controller: warningMessageController,
                  style: TextStyle(color: ctx.nexusTheme.textPrimary),
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: 'Ex: Para aí mano, isso não é permitido aqui.',
                    hintStyle: TextStyle(color: ctx.nexusTheme.textHint),
                    filled: true,
                    fillColor: ctx.nexusTheme.surfaceSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    counterStyle: TextStyle(color: ctx.nexusTheme.textHint, fontSize: 11),
                  ),
                ),
              ],
              SizedBox(height: context.r.s(8)),
              Text(
                'Silenciamento',
                style: TextStyle(
                  color: ctx.nexusTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              RadioListTile<String>(
                value: 'none',
                groupValue: silenceOption,
                onChanged: (value) => setModalState(() => silenceOption = value ?? 'none'),
                contentPadding: EdgeInsets.zero,
                activeColor: ctx.nexusTheme.warning,
                title: Text('Sem silenciamento',
                    style: TextStyle(color: ctx.nexusTheme.textPrimary)),
              ),
              RadioListTile<String>(
                value: '24h',
                groupValue: silenceOption,
                onChanged: (value) => setModalState(() => silenceOption = value ?? 'none'),
                contentPadding: EdgeInsets.zero,
                activeColor: ctx.nexusTheme.warning,
                title: Text('Silenciar por 24 horas',
                    style: TextStyle(color: ctx.nexusTheme.textPrimary)),
              ),
              RadioListTile<String>(
                value: '7d',
                groupValue: silenceOption,
                onChanged: (value) => setModalState(() => silenceOption = value ?? 'none'),
                contentPadding: EdgeInsets.zero,
                activeColor: ctx.nexusTheme.warning,
                title: Text('Silenciar por 7 dias',
                    style: TextStyle(color: ctx.nexusTheme.textPrimary)),
              ),
              RadioListTile<String>(
                value: '30d',
                groupValue: silenceOption,
                onChanged: (value) => setModalState(() => silenceOption = value ?? 'none'),
                contentPadding: EdgeInsets.zero,
                activeColor: ctx.nexusTheme.warning,
                title: Text('Silenciar por 1 mês',
                    style: TextStyle(color: ctx.nexusTheme.textPrimary)),
              ),
            ],
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: ctx.nexusTheme.warning,
              ),
              child: const Text(
                'Aplicar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || (!sendVerbalWarning && silenceOption == 'none')) {
      warningMessageController.dispose();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final roleLabel = _roleLabel(widget.callerRole);
      final customMsg = warningMessageController.text.trim();
      warningMessageController.dispose();
      final notificationRows = <Map<String, dynamic>>[];

      // ── Strike real via RPC issue_strike ──────────────────────────────────
      // Sempre registra o strike na tabela `strikes` + incrementa strike_count.
      // Se atingir 3 strikes, a RPC aplica ban automático de 30 dias.
      final strikeReason = customMsg.isNotEmpty
          ? 'Strike por $roleLabel: $customMsg'
          : 'Strike aplicado por $roleLabel';

      final strikeResult = await SupabaseService.rpc('issue_strike', params: {
        'p_community_id': widget.communityId,
        'p_target_id':    widget.targetUserId,
        'p_reason':       strikeReason,
      });

      final strikeMap = strikeResult as Map<String, dynamic>? ?? {};
      final strikeCount = strikeMap['strike_count'] as int? ?? 0;
      final autoBanned  = strikeMap['auto_banned']  as bool? ?? false;

      // ── Advertência verbal (notificação urgente) ──────────────────────────
      if (sendVerbalWarning) {
        final notifBody = customMsg.isNotEmpty
            ? customMsg
            : 'Você recebeu um strike da moderação.';
        notificationRows.add({
          'community_id': widget.communityId,
          'user_id':      widget.targetUserId,
          'type':         'moderation',
          'title':        autoBanned
              ? '🚫 Banido automaticamente (3 strikes)'
              : '⚠️ Strike $strikeCount/3 — ${widget.communityId}',
          'body': autoBanned
              ? 'Você acumulou 3 strikes e foi banido por 30 dias.'
              : notifBody,
        });
      }

      // ── Silenciamento opcional ────────────────────────────────────────────
      if (silenceOption != 'none' && !autoBanned) {
        final durationHours = switch (silenceOption) {
          '24h' => 24,
          '7d'  => 24 * 7,
          '30d' => 24 * 30,
          _     => 0,
        };
        await SupabaseService.rpc('silence_community_member', params: {
          'p_community_id':   widget.communityId,
          'p_target_id':      widget.targetUserId,
          'p_duration_hours': durationHours,
          'p_reason':         'Silenciamento aplicado por $roleLabel ($silenceOption)',
        });
        notificationRows.add({
          'community_id': widget.communityId,
          'user_id':      widget.targetUserId,
          'type':         'moderation',
          'title':        'Silenciamento aplicado',
          'body':         'Você foi silenciado por $silenceOption nesta comunidade.',
        });
      }

      // ── Enviar notificações ───────────────────────────────────────────────
      for (final row in notificationRows) {
        try {
          await SupabaseService.rpc('send_moderation_notification', params: {
            'p_community_id': row['community_id'],
            'p_user_id':      row['user_id'],
            'p_type':         row['type'],
            'p_title':        row['title'],
            'p_body':         row['body'],
          });
        } catch (_) {}
      }

      if (mounted) {
        final msg = autoBanned
            ? '🚫 ${widget.targetUserName} acumulou 3 strikes e foi banido por 30 dias.'
            : '⚠️ Strike $strikeCount/3 aplicado a ${widget.targetUserName}.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: autoBanned
              ? context.nexusTheme.error
              : context.nexusTheme.warning,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aplicar strike: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleHiddenProfile() async {
    final isCurrentlyHidden = widget.membershipData['is_hidden'] == true;
    final nextHiddenState = !isCurrentlyHidden;

    setState(() => _isLoading = true);
    try {
      // RPC toggle_member_visibility: update + log atomicamente
      await SupabaseService.rpc('toggle_member_visibility', params: {
        'p_community_id': widget.communityId,
        'p_target_id':    widget.targetUserId,
        'p_hide':         nextHiddenState,
      });

      if (mounted) {
        final message = nextHiddenState
            ? 'Perfil de ${widget.targetUserName} ocultado na comunidade.'
            : 'Perfil de ${widget.targetUserName} reativado na comunidade.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final actionLabel = nextHiddenState ? 'ocultar' : 'reativar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao $actionLabel perfil: $e')),
        );
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
        return 'Curador';
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
        return const Color(0xFF7C4DFF);
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
        return Icons.auto_awesome_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _roleDescription(String role) {
    switch (role) {
      case 'leader':
        return 'Pode gerenciar curadores e membros, além de banir, ocultar e reverter moderações';
      case 'curator':
        return 'Pode advertir, ocultar ou reativar perfis e ocultar posts';
      case 'moderator':
        return 'Compatibilidade legada tratada visualmente como curadoria';
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
                    _isSelf ? 'Meu Cargo & Título' : 'Opções de moderação',
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
                ...['leader', 'curator', 'member'].map((role) {
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

              // ── SEÇÃO: GERENCIAR TÍTULOS ──────────────────────────────
              if (_canManageTitle) ...[
                _sectionHeader('TÍTULOS CUSTOMIZADOS', r),
                InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    final changed = await showManageMemberTitlesSheet(
                      context: context,
                      ref: ref,
                      communityId: widget.communityId,
                      targetUserId: widget.targetUserId,
                      targetUserName: widget.targetUserName,
                      callerRole: widget.callerRole,
                    );
                    if (changed == true) {
                      // Sinaliza que algo mudou ao fechar o bottom sheet pai
                    }
                  },
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
                                _isSelf
                                    ? 'Gerenciar meus títulos'
                                    : 'Gerenciar títulos',
                                style: TextStyle(
                                  color: context.nexusTheme.accentPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: r.fs(14),
                                ),
                              ),
                              Text(
                                'Adicionar, editar ou remover títulos customizados',
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
                ),
                const Divider(height: 1, thickness: 0.5),
              ],

              // ── SEÇÃO: AÇÕES DISCIPLINARES ────────────────────────────────
              if (_canBanAndPunish) ...[
                _sectionHeader('OPÇÕES DE MODERAÇÃO', r),

                // Advertências e silenciamentos
                if (_canIssueWarnings)
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
                              Text('Aplicar Advertência',
                                  style: TextStyle(
                                    color: context.nexusTheme.warning,
                                    fontWeight: FontWeight.w600,
                                    fontSize: r.fs(14),
                                  )),
                              Text('Aviso verbal e silenciamento de 24h, 7 dias ou 1 mês',
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

                // Ocultar/Reativar perfil
                if (_canHideProfile)
                  InkWell(
                    onTap: _toggleHiddenProfile,
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
                              Text(
                                  widget.membershipData['is_hidden'] == true
                                      ? 'Reativar Perfil na Comunidade'
                                      : 'Ocultar Perfil na Comunidade',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontWeight: FontWeight.w600,
                                    fontSize: r.fs(14),
                                  )),
                              Text(
                                  widget.membershipData['is_hidden'] == true
                                      ? 'Restaura conteúdo, foto, capa e bio para membros comuns.'
                                      : 'Oculta conteúdo, foto, capa e bio para membros comuns até reativação',
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
                if (_canBanMember)
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

            // ── Histórico de advertências ───────────────────────────────────
            if (!_isSelf && _historyLoaded && _moderationHistory.isNotEmpty) ...[  
              _sectionHeader('HISTÓRICO DE MODERAÇÃO', r),
              ..._moderationHistory.asMap().entries.map((entry) {
                final i = entry.key;
                final log = entry.value;
                final action = log['action'] as String? ?? 'warn';
                final reason = log['reason'] as String? ?? '';
                final createdAt = log['created_at'] as String? ?? '';
                final moderatorMap = log['moderator'];
                final moderatorNick = moderatorMap is Map
                    ? (moderatorMap['nickname'] as String? ?? 'Moderador')
                    : 'Moderador';
                final warnIndex = _moderationHistory
                    .where((l) => l['action'] == 'warn')
                    .toList()
                    .indexOf(log);
                final label = action == 'warn'
                    ? 'ADV ${warnIndex + 1}'
                    : action == 'mute'
                        ? 'MUTE'
                        : action == 'ban'
                            ? 'BAN'
                            : 'KICK';
                final labelColor = action == 'warn'
                    ? context.nexusTheme.warning
                    : action == 'ban'
                        ? context.nexusTheme.error
                        : Colors.grey[500]!;
                final dateStr = createdAt.isNotEmpty
                    ? createdAt.substring(0, 10)
                    : '';
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(20), vertical: r.s(10)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: labelColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: labelColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: labelColor,
                                fontSize: r.fs(11),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: r.s(10)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (reason.isNotEmpty)
                                  Text(
                                    reason,
                                    style: TextStyle(
                                      color: context.nexusTheme.textPrimary,
                                      fontSize: r.fs(12),
                                    ),
                                  ),
                                SizedBox(height: r.s(2)),
                                Text(
                                  'por $moderatorNick · $dateStr',
                                  style: TextStyle(
                                    color: context.nexusTheme.textHint,
                                    fontSize: r.fs(11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < _moderationHistory.length - 1)
                      Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: r.s(20),
                          endIndent: r.s(20)),
                  ],
                );
              }),
              const Divider(height: 1, thickness: 0.5),
            ],
            // ── Limpar ADVs (apenas agentes/líderes) ──────────────────────────────────────────────────────
            if (!_isSelf &&
                _canIssueWarnings &&
                _historyLoaded &&
                _moderationHistory.any((l) => l['action'] == 'warn'))
              Padding(
                padding: EdgeInsets.fromLTRB(r.s(16), r.s(4), r.s(16), r.s(4)),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: ctx.surfaceColor,
                          title: Text(
                            'Limpar ADVs da conta?',
                            style: TextStyle(
                                color: ctx.textPrimary,
                                fontWeight: FontWeight.w700),
                          ),
                          content: Text(
                            'Todos os registros de advertência deste usuário nesta comunidade serão removidos. Esta ação não pode ser desfeita.',
                            style: TextStyle(
                                color: ctx.textSecondary,
                                fontSize: r.fs(13)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('Cancelar',
                                  style: TextStyle(color: Colors.grey[500])),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.nexusTheme.warning,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(r.s(10))),
                              ),
                              child: Text('Limpar',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: r.fs(14))),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && mounted) {
                        try {
                          await SupabaseService.table('moderation_logs')
                              .delete()
                              .eq('community_id', widget.communityId)
                              .eq('target_user_id', widget.targetUserId)
                              .eq('action', 'warn');
                          setState(() {
                            _moderationHistory.removeWhere(
                                (l) => l['action'] == 'warn');
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    const Text('ADVs removidos com sucesso'),
                                backgroundColor: Colors.green[700],
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint(
                              '[MemberRoleManager] Clear warns error: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Erro ao limpar ADVs. Tente novamente.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: Icon(Icons.cleaning_services_rounded,
                        color: context.nexusTheme.warning, size: r.s(18)),
                    label: Text(
                      'Limpar ADVs da conta',
                      style: TextStyle(
                        color: context.nexusTheme.warning,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: r.s(12)),
                      side: BorderSide(
                          color: context.nexusTheme.warning
                              .withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.s(10)),
                      ),
                    ),
                  ),
                ),
              ),
            // ── Fechar ──────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16),
                  r.s(16) + MediaQuery.of(context).padding.bottom),      child: SizedBox(
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
