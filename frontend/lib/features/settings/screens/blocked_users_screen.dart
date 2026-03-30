import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/utils/responsive.dart';

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

      final res = await SupabaseService.table('blocks')
          .select('*, blocked:profiles!blocked_id(*)')
          .eq('blocker_id', userId)
          .order('created_at', ascending: false);

      _blockedUsers = List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('[blocked_users_screen] Erro: $e');
    }
    if (!mounted) return;
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _unblockUser(String blockId, String nickname) async {

      final r = context.r;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.s(16)),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        title: Text(
          'Desbloquear Usuário',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Deseja desbloquear $nickname?',
          style: TextStyle(color: Colors.grey[500]),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx, false),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r.s(20)),
              ),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
                borderRadius: BorderRadius.circular(r.s(20)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Desbloquear',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.table('blocks').delete().eq('id', blockId);
      if (!mounted) return;
      setState(() {
        _blockedUsers.removeWhere((b) => b['id'] == blockId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$nickname desbloqueado', style: TextStyle(color: context.textPrimary)),
            backgroundColor: context.surfaceColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.s(12)),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ocorreu um erro. Tente novamente.', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          'Usuários Bloqueados',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            )
          : _blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.block_rounded,
                        size: r.s(64),
                        color: Colors.grey[600]?.withValues(alpha: 0.5),
                      ),
                      SizedBox(height: r.s(16)),
                      Text(
                        'Nenhum usuário bloqueado',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: r.fs(18),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: r.s(8)),
                      Text(
                        'Usuários bloqueados não podem ver seu perfil\n'
                        'nem enviar mensagens para você.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: r.fs(14),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(r.s(16)),
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
                      margin: EdgeInsets.only(bottom: r.s(12)),
                      padding: EdgeInsets.all(r.s(16)),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(r.s(16)),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          CosmeticAvatar(
                            userId: blocked['id'] as String?,
                            avatarUrl: iconUrl,
                            size: r.s(48),
                          ),
                          SizedBox(width: r.s(16)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nickname,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: r.fs(16),
                                  ),
                                ),
                                SizedBox(height: r.s(4)),
                                if (blockedAt != null)
                                  Text(
                                    'Bloqueado em ${blockedAt.day}/${blockedAt.month}/${blockedAt.year}',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: r.fs(12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                _unblockUser(block['id'] as String, nickname),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: r.s(12),
                                vertical: r.s(8),
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(r.s(20)),
                                border: Border.all(
                                  color: AppTheme.errorColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                'Desbloquear',
                                style: TextStyle(
                                  color: AppTheme.errorColor,
                                  fontSize: r.fs(12),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
