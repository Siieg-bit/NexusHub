import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/amino_animations.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';

// =============================================================================
// LIVE CHATROOMS SECTION — Estilo Amino (horizontal scroll cards)
// Exibe apenas chats do tipo 'public' da comunidade.
// Long press abre menu contextual: Fixar / Apagar.
// =============================================================================

class CommunityLiveChats extends ConsumerStatefulWidget {
  final String communityId;
  final CommunityModel community;

  const CommunityLiveChats({
    super.key,
    required this.communityId,
    required this.community,
  });

  @override
  State<CommunityLiveChats> createState() => _CommunityLiveChatsState();
}

class _CommunityLiveChatsState extends ConsumerState<CommunityLiveChats> {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final response = await SupabaseService.table('chat_threads')
          .select()
          .eq('community_id', widget.communityId)
          .eq('type', 'public')
          .order('is_pinned', ascending: false)
          .order('last_message_at', ascending: false)
          .limit(20);
      if (mounted) {
        setState(() {
          _chats = List<Map<String, dynamic>>.from(response as List? ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[community_live_chats] Erro: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // Verifica se o usuário atual é o host do chat
  bool _isHost(Map<String, dynamic> chat) {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;
    return userId == (chat['host_id'] as String?);
  }

  Future<void> _togglePin(Map<String, dynamic> chat) async {
    final isPinned = chat['is_pinned'] as bool? ?? false;
    try {
      // Usa RPC com validação de permissão (host/admin)
      final result = await SupabaseService.rpc('toggle_chat_pin', params: {
        'p_thread_id': chat['id'] as String,
      });
      final res = result as Map<String, dynamic>? ?? {};
      if (res['success'] != true) {
        throw Exception(res['error'] ?? 'not_authorized');
      }
      await _loadChats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPinned ? 'Chat desafixado.' : 'Chat fixado.'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[community_live_chats] Erro ao fixar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao alterar fixação. Tente novamente.'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _leaveOrDeleteChat(Map<String, dynamic> chat) async {
    try {
      // RPC usa auth.uid() internamente — não precisa passar p_user_id
      final result = await SupabaseService.rpc('leave_public_chat', params: {
        'p_thread_id': chat['id'] as String,
      });
      final wasDeleted = (result as Map<String, dynamic>?)?['deleted'] == true;
      if (mounted) {
        setState(() => _chats.removeWhere((c) => c['id'] == chat['id']));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasDeleted ? s.chatDeletedMsg : s.leftChat),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[community_live_chats] Erro ao apagar/sair: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(s.errorExecutingActionRetry),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showContextMenu(BuildContext context, Map<String, dynamic> chat) {
    final r = context.r;
    final isPinned = chat['is_pinned'] as bool? ?? false;
    final isHost = _isHost(chat);

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: r.s(36),
                height: r.s(4),
                margin: EdgeInsets.only(bottom: r.s(16)),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Título do chat
              Text(
                chat['title'] as String? ?? s.chat,
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: r.fs(15),
                ),
              ),
              SizedBox(height: r.s(16)),
              // Fixar / Desafixar (apenas para host)
              if (isHost)
                _menuTile(
                  r,
                  isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  isPinned ? 'Desafixar Chat' : 'Fixar Chat',
                  () {
                    Navigator.pop(ctx);
                    _togglePin(chat);
                  },
                ),
              // Apagar (host) ou Sair (membro comum)
              _menuTile(
                r,
                isHost ? Icons.delete_rounded : Icons.exit_to_app_rounded,
                isHost ? 'Apagar Chat' : s.leaveChatTitle,
                () {
                  Navigator.pop(ctx);
                  _confirmAction(context, chat, isHost);
                },
                isDestructive: true,
              ),
              SizedBox(height: r.s(8)),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAction(
      BuildContext context, Map<String, dynamic> chat, bool isDelete) {
    final r = context.r;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(16))),
        title: Text(
          isDelete ? 'Apagar Chat' : s.leaveChatTitle,
          style: TextStyle(
              color: context.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          isDelete
              ? s.confirmDeleteChat
              : s.confirmLeaveChat,
          style: TextStyle(color: Colors.grey[400], fontSize: r.fs(14)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _leaveOrDeleteChat(chat);
            },
            child: Text(
              isDelete ? s.deleteAction : s.logout,
              style: TextStyle(
                  color: AppTheme.errorColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile(
      Responsive r, IconData icon, String label, VoidCallback onTap,
      {bool isDestructive = false}) {
    final color = isDestructive ? AppTheme.errorColor : Colors.grey[400]!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: r.s(12)),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: r.s(20)),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    color: isDestructive
                        ? AppTheme.errorColor
                        : context.textPrimary,
                    fontSize: r.fs(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;

    if (_loading || _chats.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(
          left: r.s(12), right: r.s(12), top: r.s(4), bottom: r.s(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho ──────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(bottom: r.s(8)),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_rounded,
                    color: AppTheme.primaryColor, size: r.s(16)),
                SizedBox(width: r.s(6)),
                Text(
                  s.publicChatsLabel,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // ── Lista horizontal de cards ───────────────────────────────────
          SizedBox(
            height: r.s(130),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                final membersCount = chat['members_count'] as int? ?? 0;
                final isPinned = chat['is_pinned'] as bool? ?? false;

                return GestureDetector(
                  onLongPress: () => _showContextMenu(context, chat),
                  child: AminoAnimations.cardPress(
                    onTap: () => context.push('/chat/${chat["id"]}'),
                    child: Container(
                      width: r.s(150),
                      margin: EdgeInsets.only(right: r.s(8)),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(r.s(12)),
                        border: isPinned
                            ? Border.all(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.6),
                                width: 1.5)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cover
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(r.s(12))),
                                  child: chat['icon_url'] != null
                                      ? CachedNetworkImage(
                                          imageUrl: chat['icon_url'] as String,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.2),
                                          child: Icon(Icons.chat_bubble_rounded,
                                              color: AppTheme.primaryColor
                                                  .withValues(alpha: 0.5),
                                              size: r.s(28)),
                                        ),
                                ),
                                // Badge de membros
                                Positioned(
                                  top: r.s(6),
                                  right: r.s(6),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: r.s(6), vertical: r.s(2)),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.6),
                                      borderRadius:
                                          BorderRadius.circular(r.s(10)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.people_rounded,
                                            color: Colors.white, size: r.s(10)),
                                        SizedBox(width: r.s(3)),
                                        Text(
                                          '$membersCount',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: r.fs(9),
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Ícone de fixado
                                if (isPinned)
                                  Positioned(
                                    top: r.s(6),
                                    left: r.s(6),
                                    child: Container(
                                      padding: EdgeInsets.all(r.s(3)),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.85),
                                        borderRadius:
                                            BorderRadius.circular(r.s(6)),
                                      ),
                                      child: Icon(Icons.push_pin_rounded,
                                          color: Colors.white, size: r.s(10)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Título
                          Padding(
                            padding: EdgeInsets.all(r.s(8)),
                            child: Text(
                              chat['title'] as String? ?? s.chat,
                              style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: r.fs(11),
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
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
