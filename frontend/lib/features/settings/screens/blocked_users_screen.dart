import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/providers/block_provider.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

/// Tela de Usuários Bloqueados — lista e gerencia bloqueios.
class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
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
      if (!mounted) return;

      _blockedUsers = List<Map<String, dynamic>>.from(res as List? ?? []);
    } catch (e) {
      debugPrint('[blocked_users_screen] Erro: $e');
    }
    if (!mounted) return;
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _unblockUser(String blockId, String nickname) async {
    final s = getStrings();
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
          s.unblockUser,
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          s.confirmUnblockUser,
          style: TextStyle(color: Colors.grey[500]),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx, false),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r.s(20)),
              ),
              child: Text(
                s.cancel,
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
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [context.nexusTheme.accentPrimary, context.nexusTheme.accentSecondary],
                ),
                borderRadius: BorderRadius.circular(r.s(20)),
                boxShadow: [
                  BoxShadow(
                    color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child:  Text(
                s.unblock,
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
      final blockedUserId = _blockedUsers
          .firstWhere((b) => b['id'] == blockId, orElse: () => {})['blocked']
          ?['id'] as String?;
      if (blockedUserId != null) {
        await ref.read(blockedIdsProvider.notifier).unblock(blockedUserId);
      } else {
        await SupabaseService.table('blocks').delete().eq('id', blockId);
      }
      if (!mounted) return;
      setState(() {
        _blockedUsers.removeWhere((b) => b['id'] == blockId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.nicknameUnblocked(nickname),
                style: TextStyle(color: context.nexusTheme.textPrimary)),
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
            content: Text(s.anErrorOccurredTryAgain,
                style: const TextStyle(color: Colors.white)),
            backgroundColor: context.nexusTheme.error,
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
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        title: Text(
          s.blockedUsers2,
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(context.nexusTheme.accentPrimary),
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
                        s.noBlockedUsers,
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontSize: r.fs(18),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: r.s(8)),
                      Text('${s.blockedUsersCannotSeeProfile}\n${s.orSendMessages}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: r.fs(14),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
                    padding: EdgeInsets.all(r.s(12)),
                    decoration: BoxDecoration(
                      color: context.nexusTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(r.s(12)),
                      border: Border.all(color: context.nexusTheme.error.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: context.nexusTheme.error, size: r.s(16)),
                        SizedBox(width: r.s(8)),
                        Expanded(
                          child: Text(
                            s.blockedUsersInfo,
                            style: TextStyle(
                              color: context.nexusTheme.error,
                              fontSize: r.fs(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                  padding: EdgeInsets.all(r.s(16)),
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final block = _blockedUsers[index];
                    final blocked =
                        block['blocked'] as Map<String, dynamic>? ?? {};
                    final nickname =
                        blocked['nickname'] as String? ?? s.user;
                    final iconUrl = blocked['icon_url'] as String?;
                    final blockedAt = block['created_at'] != null
                        ? DateTime.tryParse(
                            block['created_at'] as String? ?? '')
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
                                    color: context.nexusTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: r.fs(16),
                                  ),
                                ),
                                SizedBox(height: r.s(4)),
                                if (blockedAt != null)
                                  Text(
                                    s.blockedOnDate,
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: r.fs(12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _unblockUser(
                                block['id'] as String? ?? '', nickname),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: r.s(12),
                                vertical: r.s(8),
                              ),
                              decoration: BoxDecoration(
                                color:
                                    context.nexusTheme.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(r.s(20)),
                                border: Border.all(
                                  color: context.nexusTheme.error
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                s.unblock,
                                style: TextStyle(
                                  color: context.nexusTheme.error,
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
                  ),
                ],
              ),
    );
  }
}
