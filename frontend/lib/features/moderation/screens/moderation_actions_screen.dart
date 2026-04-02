import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Ações de Moderação — Tela para aplicar ações em um usuário/conteúdo.
/// Suporta: Ban, Mute, Warn, Hide Post, Delete Post, Strike, Transfer Leader.
class ModerationActionsScreen extends StatefulWidget {
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
  State<ModerationActionsScreen> createState() =>
      _ModerationActionsScreenState();
}

class _ModerationActionsScreenState extends State<ModerationActionsScreen> {
  Map<String, dynamic>? _targetUser;
  bool _isLoading = true;
  final _reasonController = TextEditingController();
  String _selectedAction = 'warn';
  int _banDurationHours = 24;
  int _featuredDurationDays = 1; // 1, 3, 7 ou 0 (permanente)

  static const _actions = [
    {
      'id': 'warn',
      'label': 'Avisar',
      'icon': Icons.warning_rounded,
      'color': 0xFFFFA726,
      'description': 'Enviar um aviso ao usuário',
    },
    {
      'id': 'mute',
      'label': 'Silenciar',
      'icon': Icons.volume_off_rounded,
      'color': 0xFF42A5F5,
      'description': 'Impedir o usuário de postar/comentar temporariamente',
    },
    {
      'id': 'hide_post',
      'label': 'Ocultar Post',
      'icon': Icons.visibility_off_rounded,
      'color': 0xFF78909C,
      'description': 'Ocultar o post sem deletá-lo',
    },
    {
      'id': 'delete_post',
      'label': 'Deletar Post',
      'icon': Icons.delete_rounded,
      'color': 0xFFEF5350,
      'description': 'Remover permanentemente o post',
    },
    {
      'id': 'strike',
      'label': 'Strike',
      'icon': Icons.gavel_rounded,
      'color': 0xFFFF7043,
      'description': 'Aplicar um strike (3 strikes = ban automático)',
    },
    {
      'id': 'ban',
      'label': 'Banir',
      'icon': Icons.block_rounded,
      'color': 0xFFF44336,
      'description': 'Banir o usuário da comunidade',
    },
    {
      'id': 'unban',
      'label': 'Desbanir',
      'icon': Icons.check_circle_rounded,
      'color': 0xFF66BB6A,
      'description': 'Remover o ban do usuário',
    },
    {
      'id': 'feature_post',
      'label': 'Destacar Post',
      'icon': Icons.star_rounded,
      'color': 0xFFFFD600,
      'description': 'Destacar o post no topo do feed da comunidade',
    },
    {
      'id': 'unfeature_post',
      'label': 'Remover Destaque',
      'icon': Icons.star_border_rounded,
      'color': 0xFF9E9E9E,
      'description': 'Remover o destaque do post',
    },
    {
      'id': 'pin_post',
      'label': 'Fixar Post',
      'icon': Icons.push_pin_rounded,
      'color': 0xFF26A69A,
      'description': 'Fixar o post no topo do feed (máx 3 fixados)',
    },
    {
      'id': 'unpin_post',
      'label': 'Desafixar Post',
      'icon': Icons.push_pin_outlined,
      'color': 0xFF78909C,
      'description': 'Remover a fixação do post',
    },
    {
      'id': 'kick',
      'label': 'Expulsar',
      'icon': Icons.exit_to_app_rounded,
      'color': 0xFFFF5722,
      'description': 'Remover o usuário da comunidade (pode voltar a entrar)',
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
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o motivo da ação')),
      );
      return;
    }

    try {
      // Registrar ação no log de moderação
      await SupabaseService.table('moderation_logs').insert({
        'community_id': widget.communityId,
        'moderator_id': SupabaseService.currentUserId,
        'target_user_id': widget.targetUserId,
        'target_post_id': widget.targetPostId,
        'action': _selectedAction,
        'reason': _reasonController.text.trim(),
        'metadata': {
          if (_selectedAction == 'ban') 'duration_hours': _banDurationHours,
        },
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
            'title': 'Aviso da moderação',
            'body':
                'Você recebeu um aviso: ${_reasonController.text.trim()}',
            'community_id': widget.communityId,
          });
          break;

        case 'feature_post':
          if (widget.targetPostId != null) {
            final now = DateTime.now().toUtc();
            final featuredUntil = _featuredDurationDays > 0
                ? now.add(Duration(days: _featuredDurationDays)).toIso8601String()
                : null; // null = permanente
            await SupabaseService.table('posts')
                .update({
                  'is_featured': true,
                  'featured_at': now.toIso8601String(),
                  'featured_by': SupabaseService.currentUserId,
                  'featured_until': featuredUntil,
                })
                .eq('id', widget.targetPostId!);
          }
          break;

        case 'unfeature_post':
          if (widget.targetPostId != null) {
            await SupabaseService.table('posts')
                .update({'is_featured': false, 'featured_at': null})
                .eq('id', widget.targetPostId!);
          }
          break;

        case 'pin_post':
          if (widget.targetPostId != null) {
            await SupabaseService.table('posts')
                .update({'is_pinned': true, 'pinned_at': DateTime.now().toUtc().toIso8601String()})
                .eq('id', widget.targetPostId!);
          }
          break;

        case 'unpin_post':
          if (widget.targetPostId != null) {
            await SupabaseService.table('posts')
                .update({'is_pinned': false, 'pinned_at': null})
                .eq('id', widget.targetPostId!);
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
              'title': 'Ação da moderação',
              'body': 'Você foi removido da comunidade: ${_reasonController.text.trim()}',
              'community_id': widget.communityId,
            });
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ação executada com sucesso')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocorreu um erro. Tente novamente.')),
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
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Ação de Moderação',
            style: TextStyle(fontWeight: FontWeight.w800, color: context.textPrimary)),
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
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
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: context.scaffoldBg,
                            backgroundImage: _targetUser!['icon_url'] != null
                                ? CachedNetworkImageProvider(
                                    _targetUser!['icon_url'] as String? ?? '')
                                : null,
                            child: _targetUser!['icon_url'] == null
                                ? Icon(Icons.person_rounded, color: context.textPrimary)
                                : null,
                          ),
                          SizedBox(width: r.s(12)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _targetUser!['nickname'] as String? ??
                                    'Usuário',
                                style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w700, fontSize: r.fs(16)),
                              ),
                              Text(
                                'Nível ${_targetUser!['level'] ?? 1}',
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
                  Text('Tipo de Ação',
                      style:
                          TextStyle(color: context.textPrimary, fontWeight: FontWeight.w800, fontSize: r.fs(16))),
                  SizedBox(height: r.s(12)),
                  ..._actions.map((action) {
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
                                color: Color(action['color'] as int? ?? 0), size: r.s(22)),
                            SizedBox(width: r.s(12)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action['label'] as String? ?? '',
                                    style: TextStyle(
                                        color: isSelected ? Color(action['color'] as int? ?? 0) : context.textPrimary,
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

                  // Duração do destaque (para feature_post)
                  if (_selectedAction == 'feature_post') ...[  
                    SizedBox(height: r.s(16)),
                    Text('Duração do Destaque',
                        style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w800, fontSize: r.fs(16))),
                    SizedBox(height: r.s(8)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DurationChip(
                          label: '1 dia',
                          hours: 24,
                          selected: _featuredDurationDays * 24,
                          onTap: () => setState(() => _featuredDurationDays = 1),
                        ),
                        _DurationChip(
                          label: '3 dias',
                          hours: 72,
                          selected: _featuredDurationDays * 24,
                          onTap: () => setState(() => _featuredDurationDays = 3),
                        ),
                        _DurationChip(
                          label: '7 dias',
                          hours: 168,
                          selected: _featuredDurationDays * 24,
                          onTap: () => setState(() => _featuredDurationDays = 7),
                        ),
                        _DurationChip(
                          label: 'Permanente',
                          hours: 0,
                          selected: _featuredDurationDays * 24,
                          onTap: () => setState(() => _featuredDurationDays = 0),
                        ),
                      ],
                    ),
                  ],

                  // Duração (para ban/mute)
                  if (_selectedAction == 'ban' ||
                      _selectedAction == 'mute') ...[
                    SizedBox(height: r.s(16)),
                    Text('Duração',
                        style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w800, fontSize: r.fs(16))),
                    SizedBox(height: r.s(8)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DurationChip(
                          label: '1h',
                          hours: 1,
                          selected: _banDurationHours,
                          onTap: () => setState(() => _banDurationHours = 1),
                        ),
                        _DurationChip(
                          label: '6h',
                          hours: 6,
                          selected: _banDurationHours,
                          onTap: () => setState(() => _banDurationHours = 6),
                        ),
                        _DurationChip(
                          label: '24h',
                          hours: 24,
                          selected: _banDurationHours,
                          onTap: () => setState(() => _banDurationHours = 24),
                        ),
                        _DurationChip(
                          label: '7 dias',
                          hours: 168,
                          selected: _banDurationHours,
                          onTap: () => setState(() => _banDurationHours = 168),
                        ),
                        _DurationChip(
                          label: '30 dias',
                          hours: 720,
                          selected: _banDurationHours,
                          onTap: () => setState(() => _banDurationHours = 720),
                        ),
                        _DurationChip(
                          label: 'Permanente',
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
                  Text('Motivo',
                      style:
                          TextStyle(color: context.textPrimary, fontWeight: FontWeight.w800, fontSize: r.fs(16))),
                  SizedBox(height: r.s(8)),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    style: TextStyle(color: context.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Descreva o motivo da ação...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: context.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(r.s(16)),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(r.s(16)),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(r.s(16)),
                        borderSide: const BorderSide(color: AppTheme.primaryColor),
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
                        gradient: const LinearGradient(
                          colors: [AppTheme.errorColor, Color(0xFFD32F2F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(r.s(16)),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.errorColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Executar Ação',
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

class _DurationChip extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final r = context.r;
    final isSelected = selected == hours;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(10)),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.errorColor.withValues(alpha: 0.15)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(20)),
          border: Border.all(
            color: isSelected 
                ? AppTheme.errorColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.errorColor : Colors.grey[500],
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            fontSize: r.fs(13),
          ),
        ),
      ),
    );
  }
}
