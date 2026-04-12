import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Ações de Moderação — Tela para aplicar ações em um usuário/conteúdo.
/// Suporta: Ban, Mute, Warn, Hide Post, Delete Post, Strike, Transfer Leader.
class ModerationActionsScreen extends ConsumerStatefulWidget {
  final String communityId;
  final String? targetUserId;
  final String? targetPostId;

  const ModerationActionsScreen({
    super.key,
    required this.communityId,
    this.targetUserId,
    this.targetPostId,
  });

  @override
  ConsumerState<ModerationActionsScreen> createState() =>
      _ModerationActionsScreenState();
}

class _ModerationActionsScreenState extends ConsumerState<ModerationActionsScreen> {
  Map<String, dynamic>? _targetUser;
  bool _isLoading = true;
  final _reasonController = TextEditingController();
  String _selectedAction = 'warn';
  int _banDurationHours = 24;

  static List<Map<String, dynamic>> _getActions(AppStrings s) => [
    {
      'id': 'warn',
      'label': s.warn,
      'icon': Icons.warning_rounded,
      'color': 0xFFFFA726,
      'description': s.sendWarning,
    },
    {
      'id': 'mute',
      'label': s.mute,
      'icon': Icons.volume_off_rounded,
      'color': 0xFF42A5F5,
      'description': s.temporarilyPreventUser,
    },
    {
      'id': 'hide_post',
      'label': s.hidePost,
      'icon': Icons.visibility_off_rounded,
      'color': 0xFF78909C,
      'description': s.hidePostDesc,
    },
    {
      'id': 'delete_post',
      'label': s.deletePost2,
      'icon': Icons.delete_rounded,
      'color': 0xFFEF5350,
      'description': 'Remover permanentemente o post',
    },
    {
      'id': 'strike',
      'label': s.strike,
      'icon': Icons.gavel_rounded,
      'color': 0xFFFF7043,
      'description': s.applyStrikeDesc,
    },
    {
      'id': 'ban',
      'label': s.ban,
      'icon': Icons.block_rounded,
      'color': 0xFFF44336,
      'description': s.banUserFromCommunity,
    },
    {
      'id': 'unban',
      'label': s.unban,
      'icon': Icons.check_circle_rounded,
      'color': 0xFF66BB6A,
      'description': s.removeUserBan,
    },
    {
      'id': 'feature_post',
      'label': 'Adicionar aos Destaques',
      'icon': Icons.star_rounded,
      'color': 0xFFFFD600,
      'description': 'Adicionar o post à vitrine por ordem de entrada',
    },
    {
      'id': 'unfeature_post',
      'label': 'Remover dos Destaques',
      'icon': Icons.star_border_rounded,
      'color': 0xFF9E9E9E,
      'description': 'Remover o post da vitrine de destaques',
    },
    {
      'id': 'pin_post',
      'label': 'Fixar Post',
      'icon': Icons.push_pin_rounded,
      'color': 0xFF26A69A,
      'description': s.pinPostDesc,
    },
    {
      'id': 'unpin_post',
      'label': 'Desafixar Post',
      'icon': Icons.push_pin_outlined,
      'color': 0xFF78909C,
      'description': s.unpinPost,
    },
    {
      'id': 'kick',
      'label': s.kick,
      'icon': Icons.exit_to_app_rounded,
      'color': 0xFFFF5722,
      'description': s.removeUserDesc,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadTargetUser();
  }

  Future<void> _loadTargetUser() async {
    try {
      if (widget.targetUserId != null) {
        final user = await SupabaseService.table('profiles')
            .select()
            .eq('id', widget.targetUserId!)
            .single();
        if (!mounted) return;
        _targetUser = user;
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executeAction() async {
    final s = getStrings();
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.informActionReason)),
      );
      return;
    }

    try {
      // RPC server-side: log de moderação com auth.uid()
      await SupabaseService.rpc('log_moderation_action', params: {
        'p_community_id': widget.communityId,
        'p_action': _selectedAction,
        'p_target_user_id': widget.targetUserId,
        'p_target_post_id': widget.targetPostId,
        'p_reason': _reasonController.text.trim(),
        'p_duration_hours': _selectedAction == 'ban' ? _banDurationHours : null,
      });

      // Executar ação específica
      final targetUid = widget.targetUserId;
      switch (_selectedAction) {
        case 'ban':
          if (targetUid == null) break;
          await SupabaseService.table('community_members')
              .update({
                'is_banned': true,
                'ban_expires_at': DateTime.now()
                    .add(Duration(hours: _banDurationHours))
                    .toUtc()
                    .toIso8601String(),
              })
              .eq('community_id', widget.communityId)
              .eq('user_id', targetUid);
          break;

        case 'unban':
          if (targetUid == null) break;
          await SupabaseService.table('community_members')
              .update({
                'is_banned': false,
                'ban_expires_at': null,
              })
              .eq('community_id', widget.communityId)
              .eq('user_id', targetUid);
          break;

        case 'mute':
          if (targetUid == null) break;
          await SupabaseService.table('community_members')
              .update({
                'is_muted': true,
                'mute_expires_at': DateTime.now()
                    .add(Duration(hours: _banDurationHours))
                    .toUtc()
                    .toIso8601String(),
              })
              .eq('community_id', widget.communityId)
              .eq('user_id', targetUid);
          break;

        case 'hide_post':
          if (widget.targetPostId != null) {
            await SupabaseService.table('posts')
                .update({'status': 'disabled'}).eq('id', widget.targetPostId!);
          }
          break;

        case 'delete_post':
          if (widget.targetPostId != null) {
            await SupabaseService.table('posts')
                .delete()
                .eq('id', widget.targetPostId!);
          }
          break;

        case 'strike':
          // Usar RPC moderate_user para incrementar strikes
          await SupabaseService.rpc('moderate_user', params: {
            'p_community_id': widget.communityId,
            'p_target_user_id': widget.targetUserId,
            'p_action': 'strike',
            'p_reason': _reasonController.text.trim(),
          });
          break;

        case 'warn':
          // Enviar notificação de aviso
          await SupabaseService.table('notifications').insert({
            'user_id': widget.targetUserId,
            'actor_id': SupabaseService.currentUserId,
            'type': 'moderation',
            'title': s.moderationWarning,
            'body': s.receivedWarning(_reasonController.text.trim()),
            'community_id': widget.communityId,
          });
          break;

        case 'feature_post':
          if (widget.targetPostId != null) {
            final now = DateTime.now().toUtc();
            await SupabaseService.table('posts').update({
              'is_featured': true,
              'featured_at': now.toIso8601String(),
              'featured_by': SupabaseService.currentUserId,
              'featured_until': null,
            }).eq('id', widget.targetPostId!);
          }
          break;

        case 'unfeature_post':
          if (widget.targetPostId != null) {
            await SupabaseService.table('posts').update({
              'is_featured': false,
              'featured_at': null,
              'featured_until': null,
              'featured_by': null,
            }).eq('id', widget.targetPostId!);
          }
          break;

        case 'pin_post':
          if (widget.targetPostId != null) {
            await SupabaseService.table('posts').update({
              'is_pinned': true,
              'pinned_at': DateTime.now().toUtc().toIso8601String()
            }).eq('id', widget.targetPostId!);
          }
          break;

        case 'unpin_post':
          if (widget.targetPostId != null) {
            await SupabaseService.table('posts')
                .update({'is_pinned': false, 'pinned_at': null}).eq(
                    'id', widget.targetPostId!);
          }
          break;

        case 'kick':
          if (widget.targetUserId != null) {
            await SupabaseService.table('community_members')
                .delete()
                .eq('community_id', widget.communityId)
                .eq('user_id', targetUid!);
            // Notificar o usuário
            await SupabaseService.table('notifications').insert({
              'user_id': widget.targetUserId,
              'actor_id': SupabaseService.currentUserId,
              'type': 'moderation',
              'title': s.moderationActionLabel,
              'body':
                  s.removedFromCommunity(_reasonController.text.trim()),
              'community_id': widget.communityId,
            });
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.actionExecutedSuccess)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.anErrorOccurredTryAgain)),
        );
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
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
        title: Text(s.moderationActionTitle,
            style: TextStyle(
                fontWeight: FontWeight.w800, color: context.nexusTheme.textPrimary)),
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.nexusTheme.accentPrimary))
          : SingleChildScrollView(
              padding: EdgeInsets.all(r.s(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Target user info
                  if (_targetUser != null)
                    Container(
                      padding: EdgeInsets.all(r.s(16)),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(r.s(16)),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: context.nexusTheme.backgroundPrimary,
                            backgroundImage: _targetUser?['icon_url'] != null
                                ? CachedNetworkImageProvider(
                                    _targetUser?['icon_url'] as String? ?? '')
                                : null,
                            child: _targetUser?['icon_url'] == null
                                ? Icon(Icons.person_rounded,
                                    color: context.nexusTheme.textPrimary)
                                : null,
                          ),
                          SizedBox(width: r.s(12)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _targetUser?['nickname'] as String? ??
                                    s.user,
                                style: TextStyle(
                                    color: context.nexusTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: r.fs(16)),
                              ),
                              Text(
                                s.levelLabel,
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: r.fs(12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: r.s(20)),

                  // Seleção de ação
                  Text(s.actionType,
                      style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: r.fs(16))),
                  SizedBox(height: r.s(12)),
                  ..._getActions(s).map((action) {
                    final id = (action['id'] as String?) ?? '';
                    final isSelected = _selectedAction == id;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAction = id),
                      child: Container(
                        margin: EdgeInsets.only(bottom: r.s(8)),
                        padding: EdgeInsets.all(r.s(14)),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(action['color'] as int? ?? 0)
                                  .withValues(alpha: 0.1)
                              : context.surfaceColor,
                          borderRadius: BorderRadius.circular(r.s(16)),
                          border: Border.all(
                            color: isSelected
                                ? Color(action['color'] as int? ?? 0)
                                    .withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(action['icon'] as IconData,
                                color: Color(action['color'] as int? ?? 0),
                                size: r.s(22)),
                            SizedBox(width: r.s(12)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action['label'] as String? ?? '',
                                    style: TextStyle(
                                        color: isSelected
                                            ? Color(
                                                action['color'] as int? ?? 0)
                                            : context.nexusTheme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: r.fs(14)),
                                  ),
                                  Text(
                                    action['description'] as String? ?? '',
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: r.fs(11)),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded,
                                  color: Color(action['color'] as int? ?? 0)),
                          ],
                        ),
                      ),
                    );
                  }),


                  // Duração (para ban/mute)
                  if (_selectedAction == 'ban' ||
                      _selectedAction == 'mute') ...[
                    SizedBox(height: r.s(16)),
                    Text(s.duration,
                        style: TextStyle(
                            color: context.nexusTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: r.fs(16))),
                    SizedBox(height: r.s(8)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DurationChip(
                          label: s.oneHour,
                          hours: 1,
                          selected: _banDurationHours,
                          onTap: () => setState(() => _banDurationHours = 1),
                        ),
                        _DurationChip(
                          label: s.sixHours,
                          hours: 6,
                          selected: _banDurationHours,
                          onTap: () => setState(() => _banDurationHours = 6),
                        ),
                        _DurationChip(
                          label: s.twentyFourHours,
                          hours: 24,
                          selected: _banDurationHours,
                          onTap: () => setState(() => _banDurationHours = 24),
                        ),
                        _DurationChip(
                          label: s.sevenDays,
                          hours: 168,
                          selected: _banDurationHours,
                          onTap: () => setState(() => _banDurationHours = 168),
                        ),
                        _DurationChip(
                          label: s.thirtyDays,
                          hours: 720,
                          selected: _banDurationHours,
                          onTap: () => setState(() => _banDurationHours = 720),
                        ),
                        _DurationChip(
                          label: s.permanent,
                          hours: 87600,
                          selected: _banDurationHours,
                          onTap: () =>
                              setState(() => _banDurationHours = 87600),
                        ),
                      ],
                    ),
                  ],

                  // Motivo
                  SizedBox(height: r.s(16)),
                  Text(s.reason,
                      style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: r.fs(16))),
                  SizedBox(height: r.s(8)),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    style: TextStyle(color: context.nexusTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: s.describeActionReason,
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: context.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(r.s(16)),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(r.s(16)),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(r.s(16)),
                        borderSide:
                            BorderSide(color: context.nexusTheme.accentPrimary),
                      ),
                    ),
                  ),
                  SizedBox(height: r.s(24)),

                  // Botão executar
                  GestureDetector(
                    onTap: _executeAction,
                    child: Container(
                      width: double.infinity,
                      height: r.s(52),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [context.nexusTheme.error, Color(0xFFD32F2F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(r.s(16)),
                        boxShadow: [
                          BoxShadow(
                            color: context.nexusTheme.error.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        s.executeAction2,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.fs(16),
                          fontWeight: FontWeight.w800,
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

class _DurationChip extends ConsumerWidget {
  final String label;
  final int hours;
  final int selected;
  final VoidCallback onTap;

  const _DurationChip({
    required this.label,
    required this.hours,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final isSelected = selected == hours;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(10)),
        decoration: BoxDecoration(
          color: isSelected
              ? context.nexusTheme.error.withValues(alpha: 0.15)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(20)),
          border: Border.all(
            color: isSelected
                ? context.nexusTheme.error.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? context.nexusTheme.error : Colors.grey[500],
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            fontSize: r.fs(13),
          ),
        ),
      ),
    );
  }
}
