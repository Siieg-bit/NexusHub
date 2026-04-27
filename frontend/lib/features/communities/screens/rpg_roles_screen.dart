import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/nexus_empty_state.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final communityRolesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, communityId) async {
  final result = await SupabaseService.client
      .from('community_roles')
      .select('*')
      .eq('community_id', communityId)
      .eq('is_active', true)
      .order('sort_order');
  return (result as List).map((e) => e as Map<String, dynamic>).toList();
});

final myRoleInCommunityProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, communityId) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return null;
  final result = await SupabaseService.client
      .from('community_members')
      .select('role_id, community_roles(id, name, color, icon_url)')
      .eq('community_id', communityId)
      .eq('user_id', userId)
      .maybeSingle();
  if (result == null) return null;
  return result['community_roles'] as Map<String, dynamic>?;
});

// ── Screen ────────────────────────────────────────────────────────────────────
class RpgRolesScreen extends ConsumerStatefulWidget {
  final String communityId;
  final bool isHost;

  const RpgRolesScreen({
    super.key,
    required this.communityId,
    this.isHost = false,
  });

  @override
  ConsumerState<RpgRolesScreen> createState() => _RpgRolesScreenState();
}

class _RpgRolesScreenState extends ConsumerState<RpgRolesScreen> {
  bool _isSelectingRole = false;
  String? _selectedRoleId;

  Future<void> _selectRole(String roleId) async {
    setState(() => _isSelectingRole = true);
    try {
      final result =
          await SupabaseService.rpc('select_community_role', params: {
        'p_community_id': widget.communityId,
        'p_role_id': roleId,
      });
      if (!mounted) return;
      final success = result?['success'] as bool? ?? false;
      if (success) {
        ref.invalidate(myRoleInCommunityProvider(widget.communityId));
        ref.invalidate(communityRolesProvider(widget.communityId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role "${result?['role_name']}" selecionado!'),
            backgroundColor: context.nexusTheme.accentPrimary,
          ),
        );
      } else {
        final error = result?['error'] as String? ?? 'desconhecido';
        final msg = switch (error) {
          'role_full' => 'Este role está cheio. Escolha outro.',
          'not_a_member' => 'Você não é membro desta comunidade.',
          _ => 'Erro: $error',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSelectingRole = false);
    }
  }

  Future<void> _createRole() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final colorCtrl = TextEditingController(text: '#6C63FF');
    final maxCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nexusTheme.backgroundSecondary,
        title: Text('Criar Role',
            style: TextStyle(color: context.nexusTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome do Role *',
                  hintText: 'Ex: Guerreiro, Mago, Curandeiro...',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Descreva o papel deste role...',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: colorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cor (hex)',
                  hintText: '#6C63FF',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: maxCtrl,
                decoration: const InputDecoration(
                  labelText: 'Máximo de membros (opcional)',
                  hintText: 'Deixe vazio para ilimitado',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Criar'),
          ),
        ],
      ),
    );

    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;

    await SupabaseService.client.from('community_roles').insert({
      'community_id': widget.communityId,
      'name': nameCtrl.text.trim(),
      'description':
          descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      'color': colorCtrl.text.trim().isEmpty ? null : colorCtrl.text.trim(),
      'max_members': maxCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(maxCtrl.text.trim()),
    });

    if (mounted) ref.invalidate(communityRolesProvider(widget.communityId));
  }

  Future<void> _deleteRole(String roleId, String roleName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nexusTheme.backgroundSecondary,
        title: Text('Remover Role',
            style: TextStyle(color: context.nexusTheme.textPrimary)),
        content: Text(
          'Remover o role "$roleName"? Os membros com este role perderão a atribuição.',
          style: TextStyle(color: context.nexusTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: context.nexusTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await SupabaseService.client
        .from('community_roles')
        .update({'is_active': false}).eq('id', roleId);

    if (mounted) ref.invalidate(communityRolesProvider(widget.communityId));
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final rolesAsync = ref.watch(communityRolesProvider(widget.communityId));
    final myRoleAsync =
        ref.watch(myRoleInCommunityProvider(widget.communityId));

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Roles RPG',
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(17),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (widget.isHost)
            IconButton(
              tooltip: 'Criar Role',
              icon: Icon(Icons.add_rounded,
                  color: context.nexusTheme.accentPrimary),
              onPressed: _createRole,
            ),
        ],
      ),
      body: rolesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erro: $e',
              style: TextStyle(color: context.nexusTheme.textSecondary)),
        ),
        data: (roles) {
          if (roles.isEmpty) {
            return NexusEmptyState(
              icon: Icons.shield_rounded,
              title: 'Nenhum role criado',
              subtitle: widget.isHost
                  ? 'Crie roles para os membros da sua comunidade RPG.'
                  : 'O host ainda não criou roles para esta comunidade.',
              actionLabel: widget.isHost ? 'Criar Role' : null,
              onAction: widget.isHost ? _createRole : null,
            );
          }

          final myRole = myRoleAsync.valueOrNull;
          final myRoleId = myRole?['id'] as String?;

          return ListView(
            padding: EdgeInsets.all(r.s(16)),
            children: [
              // ── Meu role atual ──────────────────────────────────────────
              if (myRole != null) ...[
                Container(
                  padding: EdgeInsets.all(r.s(14)),
                  margin: EdgeInsets.only(bottom: r.s(16)),
                  decoration: BoxDecoration(
                    color: context.nexusTheme.accentPrimary
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(r.s(12)),
                    border: Border.all(
                        color: context.nexusTheme.accentPrimary
                            .withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_rounded,
                          color: context.nexusTheme.accentPrimary,
                          size: r.s(20)),
                      SizedBox(width: r.s(10)),
                      Text(
                        'Seu role: ${myRole['name']}',
                        style: TextStyle(
                          color: context.nexusTheme.accentPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Lista de roles ──────────────────────────────────────────
              ...roles.map((role) {
                final roleId = role['id'] as String;
                final name = role['name'] as String? ?? 'Role';
                final description = role['description'] as String?;
                final colorHex = role['color'] as String?;
                final maxMembers = role['max_members'] as int?;
                final isSelected = roleId == myRoleId;

                Color roleColor = context.nexusTheme.accentPrimary;
                if (colorHex != null) {
                  try {
                    roleColor = Color(
                        int.parse(colorHex.replaceFirst('#', '0xFF')));
                  } catch (_) {}
                }

                return GestureDetector(
                  onTap: !widget.isHost && !_isSelectingRole
                      ? () => _selectRole(roleId)
                      : null,
                  child: Container(
                    margin: EdgeInsets.only(bottom: r.s(10)),
                    padding: EdgeInsets.all(r.s(14)),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? roleColor.withValues(alpha: 0.15)
                          : context.nexusTheme.backgroundSecondary,
                      borderRadius: BorderRadius.circular(r.s(14)),
                      border: Border.all(
                        color: isSelected
                            ? roleColor.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.05),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // ── Ícone de cor ──────────────────────────────────
                        Container(
                          width: r.s(44),
                          height: r.s(44),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(r.s(12)),
                          ),
                          child: Icon(
                            Icons.shield_rounded,
                            color: roleColor,
                            size: r.s(22),
                          ),
                        ),
                        SizedBox(width: r.s(12)),

                        // ── Info ──────────────────────────────────────────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: context.nexusTheme.textPrimary,
                                      fontSize: r.fs(15),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    SizedBox(width: r.s(6)),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: r.s(6),
                                          vertical: r.s(2)),
                                      decoration: BoxDecoration(
                                        color: roleColor
                                            .withValues(alpha: 0.2),
                                        borderRadius:
                                            BorderRadius.circular(r.s(6)),
                                      ),
                                      child: Text(
                                        'Seu role',
                                        style: TextStyle(
                                          color: roleColor,
                                          fontSize: r.fs(10),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (description != null &&
                                  description.isNotEmpty) ...[
                                SizedBox(height: r.s(2)),
                                Text(
                                  description,
                                  style: TextStyle(
                                    color: context.nexusTheme.textSecondary,
                                    fontSize: r.fs(12),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (maxMembers != null) ...[
                                SizedBox(height: r.s(4)),
                                Text(
                                  'Máx. $maxMembers membros',
                                  style: TextStyle(
                                    color: context.nexusTheme.textHint,
                                    fontSize: r.fs(11),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // ── Ações do host ─────────────────────────────────
                        if (widget.isHost)
                          IconButton(
                            tooltip: 'Remover role',
                            icon: Icon(Icons.delete_outline_rounded,
                                color: context.nexusTheme.error,
                                size: r.s(20)),
                            onPressed: () => _deleteRole(roleId, name),
                          )
                        else if (!isSelected)
                          Icon(
                            Icons.chevron_right_rounded,
                            color: context.nexusTheme.textHint,
                            size: r.s(20),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
