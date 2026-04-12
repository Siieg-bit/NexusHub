// =============================================================================
// ChatModerationSheet
// Widget compartilhado de gerenciamento de membros com hierarquia de permissões.
//
// Hierarquia:
//   host     → controle total: promover/rebaixar co_host, banir/desbanir qualquer
//              membro, remover qualquer membro, bloquear envio de mensagens
//   co_host  → permissões intermediárias: remover membros comuns, banir membros
//              comuns, alterar nome e capa do chat
//   member   → sem permissões de moderação
//
// Usado tanto no chat global quanto no chat de comunidade.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import 'chat_cover_picker.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Abre o sheet de moderação do chat.
Future<void> showChatModerationSheet({
  required BuildContext context,
  required String threadId,
  required String? callerRole, // 'host', 'co_host', 'member' ou null
  required bool isAnnouncementOnly,
  required String? currentCover,
  required String? currentTitle,
  required VoidCallback onTitleChanged,
  required ValueChanged<String?> onCoverChanged,
  required ValueChanged<bool> onAnnouncementOnlyChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ChatModerationSheet(
      threadId: threadId,
      callerRole: callerRole,
      isAnnouncementOnly: isAnnouncementOnly,
      currentCover: currentCover,
      currentTitle: currentTitle,
      onTitleChanged: onTitleChanged,
      onCoverChanged: onCoverChanged,
      onAnnouncementOnlyChanged: onAnnouncementOnlyChanged,
    ),
  );
}

class _ChatModerationSheet extends StatefulWidget {
  final String threadId;
  final String? callerRole;
  final bool isAnnouncementOnly;
  final String? currentCover;
  final String? currentTitle;
  final VoidCallback onTitleChanged;
  final ValueChanged<String?> onCoverChanged;
  final ValueChanged<bool> onAnnouncementOnlyChanged;

  const _ChatModerationSheet({
    required this.threadId,
    required this.callerRole,
    required this.isAnnouncementOnly,
    required this.currentCover,
    required this.currentTitle,
    required this.onTitleChanged,
    required this.onCoverChanged,
    required this.onAnnouncementOnlyChanged,
  });

  @override
  State<_ChatModerationSheet> createState() => _ChatModerationSheetState();
}

class _ChatModerationSheetState extends State<_ChatModerationSheet> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isAnnouncementOnly = false;

  bool get _isHost => widget.callerRole == 'host';
  bool get _isCoHost => widget.callerRole == 'co_host';
  bool get _isModerator => _isHost || _isCoHost;

  @override
  void initState() {
    super.initState();
    _isAnnouncementOnly = widget.isAnnouncementOnly;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final response = await SupabaseService.table('chat_members')
          .select(
              '*, profiles!chat_members_user_id_fkey(id, nickname, icon_url)')
          .eq('thread_id', widget.threadId)
          .order('joined_at', ascending: true)
          .limit(200);
      if (mounted) {
        setState(() {
          _members =
              List<Map<String, dynamic>>.from(response as List? ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ChatModeration] Load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAnnouncementOnly(bool value) async {
    if (!_isHost) return;
    try {
      await SupabaseService.client.rpc('toggle_announcement_only', params: {
        'p_thread_id': widget.threadId,
        'p_enabled': value,
      });
      setState(() => _isAnnouncementOnly = value);
      widget.onAnnouncementOnlyChanged(value);
    } catch (e) {
      debugPrint('[ChatModeration] Toggle announcement error: $e');
    }
  }

  Future<void> _showMemberActions(
      BuildContext ctx, Map<String, dynamic> member) async {
    final profile =
        member['profiles'] as Map<String, dynamic>? ?? {};
    final targetId = member['user_id'] as String? ?? '';
    final targetRole = member['role'] as String? ?? 'member';
    final isBanned = member['is_banned'] as bool? ?? false;
    final nickname = profile['nickname'] as String? ?? 'Usuário';
    final r = ctx.r;

    final actions = <_MemberAction>[];

    // Navegar ao perfil (sempre disponível)
    actions.add(_MemberAction(
      icon: Icons.person_rounded,
      label: 'Ver perfil',
      color: Colors.blue,
      onTap: () {
        Navigator.pop(ctx);
        ctx.push('/user/$targetId');
      },
    ));

    if (_isModerator) {
      // Promover a co_host (apenas host, apenas membros)
      if (_isHost && targetRole == 'member' && !isBanned) {
        actions.add(_MemberAction(
          icon: Icons.shield_rounded,
          label: 'Promover a co-administrador',
          color: Colors.amber,
          onTap: () async {
            Navigator.pop(ctx);
            await _promoteCoHost(targetId);
          },
        ));
      }

      // Rebaixar co_host (apenas host)
      if (_isHost && targetRole == 'co_host') {
        actions.add(_MemberAction(
          icon: Icons.shield_outlined,
          label: 'Remover co-administrador',
          color: Colors.orange,
          onTap: () async {
            Navigator.pop(ctx);
            await _demoteCoHost(targetId);
          },
        ));
      }

      // Remover membro (host: todos; co_host: apenas membros)
      final canRemove = _isHost ||
          (_isCoHost && targetRole == 'member');
      if (canRemove && !isBanned) {
        actions.add(_MemberAction(
          icon: Icons.person_remove_rounded,
          label: 'Remover do chat',
          color: Colors.deepOrange,
          onTap: () async {
            Navigator.pop(ctx);
            await _removeMember(targetId);
          },
        ));
      }

      // Banir (host: todos; co_host: apenas membros)
      final canBan = _isHost ||
          (_isCoHost && targetRole == 'member');
      if (canBan && !isBanned) {
        actions.add(_MemberAction(
          icon: Icons.block_rounded,
          label: 'Banir do chat',
          color: context.nexusTheme.error,
          onTap: () async {
            Navigator.pop(ctx);
            await _showBanDialog(targetId, nickname);
          },
        ));
      }

      // Desbanir
      if (isBanned && _isModerator) {
        actions.add(_MemberAction(
          icon: Icons.lock_open_rounded,
          label: 'Desbanir',
          color: Colors.green,
          onTap: () async {
            Navigator.pop(ctx);
            await _unbanMember(targetId);
          },
        ));
      }
    }

    if (actions.isEmpty) return;

    await showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: ctx.surfaceColor,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(r.s(20))),
        ),
        padding: EdgeInsets.fromLTRB(
            r.s(16), r.s(12), r.s(16), r.s(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: r.s(36),
              height: r.s(4),
              margin: EdgeInsets.only(bottom: r.s(16)),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: r.s(20),
                  backgroundColor:
                      context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
                  backgroundImage: (profile['icon_url'] as String?) != null
                      ? CachedNetworkImageProvider(
                          profile['icon_url'] as String)
                      : null,
                  child: (profile['icon_url'] as String?) == null
                      ? Text(
                          nickname.isNotEmpty
                              ? nickname[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: context.nexusTheme.accentPrimary,
                              fontWeight: FontWeight.w700))
                      : null,
                ),
                SizedBox(width: r.s(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nickname,
                          style: TextStyle(
                              color: ctx.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: r.fs(15))),
                      if (targetRole != 'member')
                        Text(
                          targetRole == 'host'
                              ? 'Administrador'
                              : 'Co-administrador',
                          style: TextStyle(
                              color: context.nexusTheme.accentPrimary,
                              fontSize: r.fs(11),
                              fontWeight: FontWeight.w600),
                        ),
                      if (isBanned)
                        Text(
                          'Banido',
                          style: TextStyle(
                              color: context.nexusTheme.error,
                              fontSize: r.fs(11),
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: r.s(16)),
            ...actions.map((a) => _buildActionTile(ctx, r, a)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
      BuildContext ctx, Responsive r, _MemberAction action) {
    return GestureDetector(
      onTap: action.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
            vertical: r.s(13), horizontal: r.s(16)),
        margin: EdgeInsets.only(bottom: r.s(8)),
        decoration: BoxDecoration(
          color: action.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(r.s(12)),
          border:
              Border.all(color: action.color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(action.icon, color: action.color, size: r.s(20)),
            SizedBox(width: r.s(12)),
            Text(
              action.label,
              style: TextStyle(
                color: action.color,
                fontWeight: FontWeight.w600,
                fontSize: r.fs(14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promoteCoHost(String targetId) async {
    try {
      await SupabaseService.client.rpc('promote_chat_cohost', params: {
        'p_thread_id': widget.threadId,
        'p_target_user_id': targetId,
      });
      await _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Membro promovido a co-administrador'),
          backgroundColor: Colors.amber,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('[ChatModeration] Promote error: $e');
    }
  }

  Future<void> _demoteCoHost(String targetId) async {
    try {
      await SupabaseService.client.rpc('demote_chat_cohost', params: {
        'p_thread_id': widget.threadId,
        'p_target_user_id': targetId,
      });
      await _loadMembers();
    } catch (e) {
      debugPrint('[ChatModeration] Demote error: $e');
    }
  }

  Future<void> _removeMember(String targetId) async {
    try {
      await SupabaseService.client.rpc('remove_chat_member', params: {
        'p_thread_id': widget.threadId,
        'p_target_user_id': targetId,
      });
      await _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Membro removido do chat'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('[ChatModeration] Remove error: $e');
    }
  }

  Future<void> _showBanDialog(
      String targetId, String nickname) async {
    final r = context.r;
    final reasonCtrl = TextEditingController();
    int? durationHours; // null = permanente

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: ctx.surfaceColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.s(16))),
          title: Text(
            'Banir $nickname',
            style: TextStyle(
                color: ctx.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: r.fs(16)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: reasonCtrl,
                style: TextStyle(
                    color: ctx.textPrimary, fontSize: r.fs(14)),
                decoration: InputDecoration(
                  hintText: 'Motivo (opcional)',
                  hintStyle: TextStyle(
                      color: ctx.textHint, fontSize: r.fs(13)),
                  filled: true,
                  fillColor: ctx.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(10)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: r.s(12)),
              Text('Duração:',
                  style: TextStyle(
                      color: ctx.textSecondary,
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w600)),
              SizedBox(height: r.s(8)),
              Wrap(
                spacing: r.s(8),
                children: [
                  _DurationChip(
                      label: 'Permanente',
                      selected: durationHours == null,
                      onTap: () => setS(() => durationHours = null)),
                  _DurationChip(
                      label: '1h',
                      selected: durationHours == 1,
                      onTap: () => setS(() => durationHours = 1)),
                  _DurationChip(
                      label: '24h',
                      selected: durationHours == 24,
                      onTap: () => setS(() => durationHours = 24)),
                  _DurationChip(
                      label: '7d',
                      selected: durationHours == 168,
                      onTap: () => setS(() => durationHours = 168)),
                  _DurationChip(
                      label: '30d',
                      selected: durationHours == 720,
                      onTap: () => setS(() => durationHours = 720)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: TextStyle(
                      color: ctx.textHint, fontSize: r.fs(14))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.nexusTheme.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(10))),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _banMember(
                  targetId,
                  reason: reasonCtrl.text.trim().isEmpty
                      ? null
                      : reasonCtrl.text.trim(),
                  durationHours: durationHours,
                );
              },
              child: Text('Banir',
                  style: TextStyle(
                      color: Colors.white, fontSize: r.fs(14))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _banMember(
    String targetId, {
    String? reason,
    int? durationHours,
  }) async {
    try {
      await SupabaseService.client.rpc('ban_chat_member', params: {
        'p_thread_id': widget.threadId,
        'p_target_user_id': targetId,
        if (reason != null) 'p_reason': reason,
        if (durationHours != null) 'p_duration_hours': durationHours,
      });
      await _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(durationHours == null
              ? 'Membro banido permanentemente'
              : 'Membro banido por ${_formatDuration(durationHours)}'),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('[ChatModeration] Ban error: $e');
    }
  }

  Future<void> _unbanMember(String targetId) async {
    try {
      await SupabaseService.client.rpc('unban_chat_member', params: {
        'p_thread_id': widget.threadId,
        'p_target_user_id': targetId,
      });
      await _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Membro desbanido'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('[ChatModeration] Unban error: $e');
    }
  }

  String _formatDuration(int hours) {
    if (hours < 24) return '${hours}h';
    final days = hours ~/ 24;
    return '${days}d';
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(r.s(20))),
        ),
        child: Column(
          children: [
            // ── Handle + Header ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                  r.s(16), r.s(12), r.s(16), r.s(0)),
              child: Column(
                children: [
                  Container(
                    width: r.s(36),
                    height: r.s(4),
                    margin: EdgeInsets.only(bottom: r.s(16)),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Membros',
                        style: TextStyle(
                          fontSize: r.fs(18),
                          fontWeight: FontWeight.w800,
                          color: context.nexusTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_members.length}',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: r.fs(13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Controles de moderação (host/co_host) ──
            if (_isModerator) ...[
              SizedBox(height: r.s(12)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                child: Column(
                  children: [
                    // Bloquear mensagens (apenas host)
                    if (_isHost)
                      _ControlTile(
                        r: r,
                        icon: Icons.campaign_rounded,
                        label: 'Apenas anúncios',
                        subtitle:
                            'Bloqueia envio de mensagens para membros comuns',
                        value: _isAnnouncementOnly,
                        onChanged: _toggleAnnouncementOnly,
                      ),
                    SizedBox(height: r.s(8)),
                    // Capa do chat (host e co_host)
                    _ButtonTile(
                      r: r,
                      icon: Icons.image_rounded,
                      label: 'Alterar capa do chat',
                      onTap: () {
                        Navigator.pop(context);
                        showChatCoverPicker(
                          context: context,
                          threadId: widget.threadId,
                          currentCover: widget.currentCover,
                          canEdit: true,
                          onChanged: widget.onCoverChanged,
                        );
                      },
                    ),
                    SizedBox(height: r.s(8)),
                    // Renomear chat (host e co_host)
                    _ButtonTile(
                      r: r,
                      icon: Icons.edit_rounded,
                      label: 'Renomear chat',
                      onTap: () {
                        Navigator.pop(context);
                        _showRenameDialog();
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    r.s(16), r.s(12), r.s(16), r.s(4)),
                child: Row(
                  children: [
                    Text(
                      'Lista de membros',
                      style: TextStyle(
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w600,
                        color: context.nexusTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              SizedBox(height: r.s(12)),

            // ── Lista de membros ──
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: context.nexusTheme.accentPrimary, strokeWidth: 2))
                  : _members.isEmpty
                      ? Center(
                          child: Text('Nenhum membro',
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: r.fs(13))))
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(16)),
                          itemCount: _members.length,
                          itemBuilder: (ctx, i) {
                            final member = _members[i];
                            final profile = member['profiles']
                                    as Map<String, dynamic>? ??
                                {};
                            final nickname =
                                profile['nickname'] as String? ??
                                    'Usuário';
                            final iconUrl =
                                profile['icon_url'] as String?;
                            final role =
                                member['role'] as String? ?? 'member';
                            final isBanned =
                                member['is_banned'] as bool? ?? false;
                            final banReason =
                                member['ban_reason'] as String?;

                            return GestureDetector(
                              onTap: _isModerator
                                  ? () => _showMemberActions(ctx, member)
                                  : () {
                                      final uid = profile['id'] as String?;
                                      if (uid != null) {
                                        Navigator.pop(ctx);
                                        ctx.push('/user/$uid');
                                      }
                                    },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    vertical: r.s(10)),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.05)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: r.s(20),
                                          backgroundColor: context.nexusTheme.accentPrimary
                                              .withValues(alpha: 0.2),
                                          backgroundImage: iconUrl != null
                                              ? CachedNetworkImageProvider(
                                                  iconUrl)
                                              : null,
                                          child: iconUrl == null
                                              ? Text(
                                                  nickname.isNotEmpty
                                                      ? nickname[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: TextStyle(
                                                      color: context.nexusTheme.accentPrimary,
                                                      fontWeight:
                                                          FontWeight.w700))
                                              : null,
                                        ),
                                        if (isBanned)
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: r.s(14),
                                              height: r.s(14),
                                              decoration: BoxDecoration(
                                                color: context.nexusTheme.error,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                  Icons.block_rounded,
                                                  color: Colors.white,
                                                  size: r.s(9)),
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(width: r.s(12)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nickname,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isBanned
                                                  ? Colors.grey[600]
                                                  : context.nexusTheme.textPrimary,
                                              fontWeight: FontWeight.w500,
                                              fontSize: r.fs(14),
                                            ),
                                          ),
                                          if (isBanned && banReason != null)
                                            Text(
                                              'Banido: $banReason',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: context.nexusTheme.error,
                                                  fontSize: r.fs(10)),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Badge de role
                                    if (role != 'member')
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: r.s(8),
                                            vertical: r.s(3)),
                                        decoration: BoxDecoration(
                                          color: role == 'host'
                                              ? context.nexusTheme.accentPrimary
                                                  .withValues(alpha: 0.15)
                                              : Colors.amber
                                                  .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(r.s(8)),
                                        ),
                                        child: Text(
                                          role == 'host'
                                              ? 'ADMIN'
                                              : 'CO-ADMIN',
                                          style: TextStyle(
                                            color: role == 'host'
                                                ? context.nexusTheme.accentPrimary
                                                : Colors.amber,
                                            fontSize: r.fs(9),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    if (_isModerator)
                                      Icon(Icons.more_vert_rounded,
                                          color: Colors.grey[600],
                                          size: r.s(18)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog() {
    final r = context.r;
    final ctrl = TextEditingController(text: widget.currentTitle ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(16))),
        title: Text('Renomear chat',
            style: TextStyle(
                color: ctx.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: r.fs(16))),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: ctx.textPrimary, fontSize: r.fs(14)),
          decoration: InputDecoration(
            hintText: 'Nome do chat',
            hintStyle: TextStyle(color: ctx.textHint),
            filled: true,
            fillColor: ctx.cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.s(10)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: TextStyle(color: ctx.textHint, fontSize: r.fs(14))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.nexusTheme.accentPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(10))),
            ),
            onPressed: () async {
              final newTitle = ctrl.text.trim();
              if (newTitle.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await SupabaseService.client.rpc('update_chat_title', params: {
                  'p_thread_id': widget.threadId,
                  'p_title': newTitle,
                });
                widget.onTitleChanged();
              } catch (e) {
                debugPrint('[ChatModeration] Rename error: $e');
              }
            },
            child: Text('Salvar',
                style: TextStyle(
                    color: Colors.white, fontSize: r.fs(14))),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _MemberAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MemberAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _ControlTile extends StatelessWidget {
  final Responsive r;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ControlTile({
    required this.r,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.symmetric(vertical: r.s(10), horizontal: r.s(14)),
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.nexusTheme.accentPrimary, size: r.s(20)),
          SizedBox(width: r.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: r.fs(13))),
                Text(subtitle,
                    style: TextStyle(
                        color: context.nexusTheme.textHint, fontSize: r.fs(11))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: context.nexusTheme.accentPrimary,
          ),
        ],
      ),
    );
  }
}

class _ButtonTile extends StatelessWidget {
  final Responsive r;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ButtonTile({
    required this.r,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding:
            EdgeInsets.symmetric(vertical: r.s(12), horizontal: r.s(14)),
        decoration: BoxDecoration(
          color: context.nexusTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: context.nexusTheme.accentPrimary, size: r.s(20)),
            SizedBox(width: r.s(12)),
            Text(label,
                style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: r.fs(13))),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey[600], size: r.s(18)),
          ],
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? context.nexusTheme.error
              : context.nexusTheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? context.nexusTheme.error
                : context.nexusTheme.error.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : context.nexusTheme.error,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
