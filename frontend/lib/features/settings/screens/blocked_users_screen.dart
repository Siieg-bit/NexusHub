import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Tela de Usuários Bloqueados — lista e gerencia bloqueios.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final res = await SupabaseService.table('user_blocks')
          .select('*, blocked:profiles!blocked_user_id(*)')
          .eq('blocker_id', userId)
          .order('created_at', ascending: false);

      _blockedUsers = List<Map<String, dynamic>>.from(res as List);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _unblockUser(String blockId, String nickname) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desbloquear Usuário'),
        content: Text('Deseja desbloquear $nickname?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.table('user_blocks').delete().eq('id', blockId);
      setState(() {
        _blockedUsers.removeWhere((b) => b['id'] == blockId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$nickname desbloqueado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuários Bloqueados',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block_rounded,
                          size: 64,
                          color: AppTheme.textHint.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text('Nenhum usuário bloqueado',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text(
                          'Usuários bloqueados não podem ver seu perfil\n'
                          'nem enviar mensagens para você.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.textHint, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final block = _blockedUsers[index];
                    final blocked =
                        block['blocked'] as Map<String, dynamic>? ?? {};
                    final nickname =
                        blocked['nickname'] as String? ?? 'Usuário';
                    final iconUrl = blocked['icon_url'] as String?;
                    final blockedAt = block['created_at'] != null
                        ? DateTime.tryParse(block['created_at'] as String)
                        : null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundImage: iconUrl != null
                                ? CachedNetworkImageProvider(iconUrl)
                                : null,
                            child: iconUrl == null
                                ? const Icon(Icons.person_rounded)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nickname,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                if (blockedAt != null)
                                  Text(
                                    'Bloqueado em ${blockedAt.day}/${blockedAt.month}/${blockedAt.year}',
                                    style: const TextStyle(
                                        color: AppTheme.textHint, fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _unblockUser(block['id'] as String, nickname),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.errorColor,
                            ),
                            child: const Text('Desbloquear',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
