import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/amino_animations.dart';
import '../../../core/utils/responsive.dart';

// =============================================================================
// TAB: Chats Públicos — Grid 2 colunas estilo Amino
// Cada card exibe: cover, avatar do host, tag/descrição, título, membros, tempo.
// Long press → menu contextual: Fixar / Apagar.
// =============================================================================

class CommunityChatTab extends StatefulWidget {
  final String communityId;

  const CommunityChatTab({super.key, required this.communityId});

  @override
  State<CommunityChatTab> createState() => _CommunityChatTabState();
}

class _CommunityChatTabState extends State<CommunityChatTab> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      // Buscar chats públicos com join no perfil do host
      final response = await SupabaseService.table('chat_threads')
          .select(
              '*, host:profiles!chat_threads_host_id_fkey(id, nickname, icon_url)')
          .eq('community_id', widget.communityId)
          .eq('type', 'public')
          .order('is_pinned', ascending: false)
          .order('members_count', ascending: false)
          .order('last_message_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _chats = List<Map<String, dynamic>>.from(response as List? ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await _loadChats();
  }

  bool _isHost(Map<String, dynamic> chat) {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;
    return userId == (chat['host_id'] as String?);
  }

  Future<void> _togglePin(Map<String, dynamic> chat) async {
    final isPinned = chat['is_pinned'] as bool? ?? false;
    try {
      await SupabaseService.table('chat_threads')
          .update({'is_pinned': !isPinned}).eq('id', chat['id'] as String);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(isPinned ? 'Chat desafixado.' : 'Chat fixado no topo.'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao alterar fixação.'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _leaveOrDeleteChat(Map<String, dynamic> chat) async {
    try {
      final result = await SupabaseService.rpc('leave_public_chat', params: {
        'p_thread_id': chat['id'] as String,
      });
      final wasDeleted = (result as Map<String, dynamic>?)?['deleted'] == true;
      if (mounted) {
        setState(() => _chats.removeWhere((c) => c['id'] == chat['id']));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasDeleted ? 'Chat excluído.' : 'Você saiu do chat.'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao executar ação. Tente novamente.'),
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
              Text(
                chat['title'] as String? ?? 'Chat',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: r.fs(15),
                ),
              ),
              SizedBox(height: r.s(16)),
              // Fixar/Desafixar (apenas para host)
              if (isHost)
                _menuTile(
                  context,
                  r,
                  isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  isPinned ? 'Desafixar Chat' : 'Fixar Chat no Topo',
                  () {
                    Navigator.pop(ctx);
                    _togglePin(chat);
                  },
                ),
              // Apagar / Sair
              _menuTile(
                context,
                r,
                isHost ? Icons.delete_rounded : Icons.exit_to_app_rounded,
                isHost ? 'Apagar Chat' : 'Sair do Chat',
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
          isDelete ? 'Apagar Chat' : 'Sair do Chat',
          style: TextStyle(
              color: context.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          isDelete
              ? 'Tem certeza que deseja apagar este chat? Esta ação não pode ser desfeita.'
              : 'Tem certeza que deseja sair deste chat?',
          style: TextStyle(color: Colors.grey[400], fontSize: r.fs(14)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _leaveOrDeleteChat(chat);
            },
            child: Text(
              isDelete ? 'Apagar' : 'Sair',
              style: TextStyle(
                  color: AppTheme.errorColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile(
    BuildContext context,
    Responsive r,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppTheme.errorColor : Colors.grey[400]!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: r.s(12)),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: r.s(20)),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color:
                      isDestructive ? AppTheme.errorColor : context.textPrimary,
                  fontSize: r.fs(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return timeago.format(dt, locale: 'pt_BR');
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
            color: AppTheme.primaryColor, strokeWidth: 2.5),
      );
    }

    if (_chats.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: AppTheme.primaryColor,
        backgroundColor: context.surfaceColor,
        child: LayoutBuilder(
          builder: (ctx, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        size: r.s(52), color: context.textHint),
                    SizedBox(height: r.s(14)),
                    Text(
                      'Nenhum chat público ainda.',
                      style: TextStyle(
                          color: context.textPrimary,
                          fontSize: r.fs(15),
                          fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: r.s(6)),
                    Text(
                      'Use o botão + para criar um!',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: r.fs(13)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primaryColor,
      backgroundColor: context.surfaceColor,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(r.s(8)),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: r.s(8),
          mainAxisSpacing: r.s(8),
          // Proporção similar ao print: cover grande + info embaixo
          childAspectRatio: 0.72,
        ),
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return _ChatCard(
            chat: chat,
            onTap: () => context.push('/chat/${chat['id']}'),
            onLongPress: () => _showContextMenu(context, chat),
            formatTime: _formatTime,
          );
        },
      ),
    );
  }
}

// =============================================================================
// CARD INDIVIDUAL — estilo Amino
// =============================================================================
class _ChatCard extends StatelessWidget {
  final Map<String, dynamic> chat;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String Function(String?) formatTime;

  const _ChatCard({
    required this.chat,
    required this.onTap,
    required this.onLongPress,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final isPinned = chat['is_pinned'] as bool? ?? false;
    final membersCount = chat['members_count'] as int? ?? 0;
    final lastMsgAt = chat['last_message_at'] as String?;
    final timeStr = formatTime(lastMsgAt);
    final host = chat['host'] as Map<String, dynamic>?;
    final hostAvatar = host?['icon_url'] as String?;
    final description = chat['description'] as String?;
    final coverUrl =
        chat['background_url'] as String? ?? chat['icon_url'] as String?;

    return AminoAnimations.staggerItem(
      index: 0,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: AminoAnimations.cardPress(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(r.s(12)),
              border: isPinned
                  ? Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.7),
                      width: 1.5)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cover (imagem grande ~62%) ──────────────────────────
                Expanded(
                  flex: 62,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Imagem de fundo
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(r.s(12))),
                        child: coverUrl != null
                            ? CachedNetworkImage(
                                imageUrl: coverUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    _defaultCover(context, r),
                              )
                            : _defaultCover(context, r),
                      ),
                      // Gradient escuro no bottom para legibilidade
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: r.s(50),
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(r.s(12))),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Avatar do host (canto superior esquerdo)
                      Positioned(
                        top: r.s(6),
                        left: r.s(6),
                        child: Container(
                          width: r.s(32),
                          height: r.s(32),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: ClipOval(
                            child: hostAvatar != null
                                ? CachedNetworkImage(
                                    imageUrl: hostAvatar,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _avatarFallback(r),
                                  )
                                : _avatarFallback(r),
                          ),
                        ),
                      ),
                      // Badge de fixado (canto superior direito)
                      if (isPinned)
                        Positioned(
                          top: r.s(6),
                          right: r.s(6),
                          child: Container(
                            padding: EdgeInsets.all(r.s(3)),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(r.s(6)),
                            ),
                            child: Icon(Icons.push_pin_rounded,
                                color: Colors.white, size: r.s(10)),
                          ),
                        ),
                      // Tag de categoria (description) — canto inferior esquerdo
                      if (description != null && description.isNotEmpty)
                        Positioned(
                          bottom: r.s(6),
                          left: r.s(6),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(7), vertical: r.s(3)),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(r.s(20)),
                            ),
                            child: Text(
                              description,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: r.fs(9),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // ── Info embaixo (~38%) ─────────────────────────────────
                Expanded(
                  flex: 38,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(8), vertical: r.s(6)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Título
                        Text(
                          chat['title'] as String? ?? 'Chat',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: r.fs(12),
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: r.s(4)),
                        // Membros + timestamp
                        Row(
                          children: [
                            Icon(Icons.people_rounded,
                                color: Colors.grey[500], size: r.s(12)),
                            SizedBox(width: r.s(3)),
                            Text(
                              '$membersCount',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: r.fs(10)),
                            ),
                            if (timeStr.isNotEmpty) ...[
                              const Spacer(),
                              Text(
                                timeStr,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: r.fs(9)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _defaultCover(BuildContext context, Responsive r) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.35),
            AppTheme.primaryColor.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Icon(
        Icons.chat_bubble_rounded,
        color: AppTheme.primaryColor.withValues(alpha: 0.4),
        size: r.s(40),
      ),
    );
  }

  Widget _avatarFallback(Responsive r) {
    return Container(
      color: Colors.grey[800],
      child: Icon(Icons.person_rounded, color: Colors.grey[500], size: r.s(18)),
    );
  }
}
