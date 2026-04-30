import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../../core/widgets/amino_custom_title.dart';
import '../../auth/providers/auth_provider.dart';

// =============================================================================
// StaffManagementScreen — Gerenciamento de cargos da equipe NexusHub
// Acessível apenas para usuários com team_rank >= 80 (Team Admin ou superior).
// =============================================================================

// ── Provider ─────────────────────────────────────────────────────────────────
final teamMembersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final result = await SupabaseService.rpc('get_team_members');
  if (result == null) return [];
  return (result as List).cast<Map<String, dynamic>>();
});

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  Map<String, dynamic>? _searchResult;
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Buscar usuário por amino_id ───────────────────────────────────────────
  Future<void> _searchUser() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResult = null;
      _searchError = null;
    });

    try {
      final result = await SupabaseService.rpc('search_users_by_amino_id', params: {
        'p_amino_id': query,
        'p_limit': 1,
      });
      if (result == null || (result as List).isEmpty) {
        setState(() => _searchError = 'Usuário "@$query" não encontrado.');
      } else {
        setState(() => _searchResult = (result as List).first as Map<String, dynamic>);
      }
    } catch (e) {
      setState(() => _searchError = 'Erro ao buscar: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // ── Atribuir cargo ────────────────────────────────────────────────────────
  Future<void> _setRole(String targetUserId, TeamRole newRole) async {
    final confirmed = await _showConfirmDialog(newRole);
    if (!confirmed) return;

    try {
      final result = await SupabaseService.rpc('set_team_role', params: {
        'p_target_user_id': targetUserId,
        'p_new_role': newRole.dbValue,
      });

      if (result is Map && result['error'] != null) {
        if (!mounted) return;
        _showSnack(result['message'] as String? ?? result['error'] as String, isError: true);
        return;
      }

      if (!mounted) return;
      _showSnack(
        newRole == TeamRole.none
            ? 'Cargo removido com sucesso.'
            : 'Cargo "${newRole.label}" atribuído com sucesso!',
      );
      // Atualizar lista e resultado da busca
      ref.invalidate(teamMembersProvider);
      setState(() {
        if (_searchResult != null) {
          _searchResult = {
            ..._searchResult!,
            'team_role': newRole.dbValue,
            'team_rank': newRole.rank,
          };
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Erro: $e', isError: true);
    }
  }

  Future<bool> _showConfirmDialog(TeamRole role) async {
    final r = context.r;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(16))),
        title: Text(
          role == TeamRole.none ? 'Remover cargo' : 'Atribuir cargo',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          role == TeamRole.none
              ? 'Tem certeza que deseja remover o cargo desta pessoa da equipe?'
              : 'Atribuir o cargo "${role.label}" a este usuário?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              role == TeamRole.none ? 'Remover' : 'Confirmar',
              style: TextStyle(
                color: role == TeamRole.none ? Colors.redAccent : Colors.greenAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
    ));
  }

  // ── Mostrar sheet de seleção de cargo ─────────────────────────────────────
  void _showRoleSelector(String targetUserId, TeamRole currentRole, int callerRank) {
    final r = context.r;
    final assignableRoles = TeamRole.values
        .where((role) => role != TeamRole.none && role.rank < callerRank)
        .toList()
      ..sort((a, b) => b.rank.compareTo(a.rank));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        padding: EdgeInsets.all(r.s(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: r.s(36), height: r.s(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: r.s(16)),
            Text(
              'Selecionar cargo',
              style: TextStyle(
                color: Colors.white,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: r.s(12)),
            ...assignableRoles.map((role) {
              final isSelected = role == currentRole;
              final borderColor = _hexToColor(role.borderColorHex);
              return ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: r.s(4), vertical: r.s(2)),
                leading: Container(
                  width: r.s(12), height: r.s(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: borderColor,
                  ),
                ),
                title: Text(
                  role.label,
                  style: TextStyle(
                    color: isSelected ? borderColor : Colors.white,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Rank ${role.rank}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: r.fs(11),
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: borderColor, size: r.s(20))
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _setRole(targetUserId, role);
                },
              );
            }),
            // Opção de remover cargo (se tiver cargo)
            if (currentRole != TeamRole.none) ...[
              Divider(color: Colors.white.withValues(alpha: 0.08)),
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: r.s(4)),
                leading: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                title: const Text(
                  'Remover da equipe',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _setRole(targetUserId, TeamRole.none);
                },
              ),
            ],
            SizedBox(height: MediaQuery.of(context).padding.bottom + r.s(8)),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    final teamAsync = ref.watch(teamMembersProvider);

    // Rank do caller (usuário logado)
    final currentUser = ref.watch(currentUserProvider);
    final callerRank = currentUser?.teamRank ?? 0;

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: theme.backgroundPrimary,
        elevation: 0,
        title: Text(
          'Gerenciar Equipe',
          style: TextStyle(
            color: Colors.white,
            fontSize: r.fs(18),
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Barra de busca ───────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(r.s(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adicionar membro à equipe',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: r.s(8)),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Buscar por @amino_id...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                          prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.07),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(r.s(12)),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: r.s(12)),
                        ),
                        onSubmitted: (_) => _searchUser(),
                      ),
                    ),
                    SizedBox(width: r.s(8)),
                    GestureDetector(
                      onTap: _isSearching ? null : _searchUser,
                      child: Container(
                        padding: EdgeInsets.all(r.s(12)),
                        decoration: BoxDecoration(
                          color: theme.accentPrimary,
                          borderRadius: BorderRadius.circular(r.s(12)),
                        ),
                        child: _isSearching
                            ? SizedBox(
                                width: r.s(20), height: r.s(20),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white,
                                ),
                              )
                            : Icon(Icons.arrow_forward_rounded, color: Colors.white, size: r.s(20)),
                      ),
                    ),
                  ],
                ),
                // Resultado da busca
                if (_searchError != null) ...[
                  SizedBox(height: r.s(8)),
                  Text(_searchError!, style: const TextStyle(color: Colors.redAccent)),
                ],
                if (_searchResult != null) ...[
                  SizedBox(height: r.s(12)),
                  _SearchResultCard(
                    user: _searchResult!,
                    callerRank: callerRank,
                    onSetRole: (role) => _setRole(
                      _searchResult!['id'] as String,
                      role,
                    ),
                    onShowSelector: () => _showRoleSelector(
                      _searchResult!['id'] as String,
                      TeamRole.fromString(_searchResult!['team_role'] as String?),
                      callerRank,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

          // ── Lista da equipe atual ────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
            child: Row(
              children: [
                Text(
                  'Equipe atual',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.fs(15),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                teamAsync.when(
                  data: (members) => Text(
                    '${members.length} membros',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: r.fs(12),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          Expanded(
            child: teamAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Erro ao carregar equipe: $e',
                    style: const TextStyle(color: Colors.redAccent)),
              ),
              data: (members) {
                if (members.isEmpty) {
                  return Center(
                    child: Text(
                      'Nenhum membro na equipe ainda.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => Divider(
                    color: Colors.white.withValues(alpha: 0.06),
                    height: 1,
                  ),
                  itemBuilder: (_, i) {
                    final m = members[i];
                    final memberRole = TeamRole.fromString(m['team_role'] as String?);
                    final memberRank = (m['team_rank'] as num?)?.toInt() ?? 0;
                    final canEdit = callerRank > memberRank;
                    final borderColor = _hexToColor(memberRole.borderColorHex);

                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(vertical: r.s(4)),
                      leading: CircleAvatar(
                        radius: r.s(22),
                        backgroundImage: m['icon_url'] != null
                            ? NetworkImage(m['icon_url'] as String)
                            : null,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        child: m['icon_url'] == null
                            ? Icon(Icons.person, color: Colors.white.withValues(alpha: 0.5))
                            : null,
                      ),
                      title: Text(
                        m['nickname'] as String? ?? '—',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Container(
                            margin: EdgeInsets.only(top: r.s(4)),
                            padding: EdgeInsets.symmetric(
                              horizontal: r.s(8), vertical: r.s(2),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(r.s(8)),
                              border: Border.all(
                                color: borderColor.withValues(alpha: 0.7),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              memberRole.label,
                              style: TextStyle(
                                color: borderColor,
                                fontSize: r.fs(11),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: r.s(6)),
                          Text(
                            'Rank $memberRank',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: r.fs(11),
                            ),
                          ),
                        ],
                      ),
                      trailing: canEdit
                          ? IconButton(
                              icon: Icon(
                                Icons.edit_rounded,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: r.s(20),
                              ),
                              onPressed: () => _showRoleSelector(
                                m['user_id'] as String,
                                memberRole,
                                callerRank,
                              ),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }
}

// =============================================================================
// _SearchResultCard — Card exibido após busca de usuário
// =============================================================================
class _SearchResultCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final int callerRank;
  final void Function(TeamRole) onSetRole;
  final VoidCallback onShowSelector;

  const _SearchResultCard({
    required this.user,
    required this.callerRank,
    required this.onSetRole,
    required this.onShowSelector,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final currentRole = TeamRole.fromString(user['team_role'] as String?);
    final currentRank = (user['team_rank'] as num?)?.toInt() ?? 0;
    final canEdit = callerRank > currentRank;

    return Container(
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: r.s(24),
            backgroundImage: user['icon_url'] != null
                ? NetworkImage(user['icon_url'] as String)
                : null,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
          ),
          SizedBox(width: r.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['nickname'] as String? ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '@${user['amino_id'] ?? ''}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: r.fs(12),
                  ),
                ),
                if (currentRole != TeamRole.none)
                  AminoCustomTitle.teamBadge(role: currentRole),
              ],
            ),
          ),
          if (canEdit)
            TextButton(
              onPressed: onShowSelector,
              child: Text(
                currentRole == TeamRole.none ? 'Adicionar' : 'Alterar',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (currentRank >= callerRank)
            Text(
              'Rank superior',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: r.fs(12),
              ),
            ),
        ],
      ),
    );
  }
}

// currentUserProvider é importado de auth_provider.dart
