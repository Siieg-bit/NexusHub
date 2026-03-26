import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

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
      switch (_selectedAction) {
        case 'ban':
          await SupabaseService.table('community_members')
              .update({
                'is_banned': true,
                'banned_until': DateTime.now()
                    .add(Duration(hours: _banDurationHours))
                    .toUtc()
                    .toIso8601String(),
              })
              .eq('community_id', widget.communityId)
              .eq('user_id', widget.targetUserId!);
          break;

        case 'unban':
          await SupabaseService.table('community_members')
              .update({
                'is_banned': false,
                'banned_until': null,
              })
              .eq('community_id', widget.communityId)
              .eq('user_id', widget.targetUserId!);
          break;

        case 'mute':
          await SupabaseService.table('community_members')
              .update({
                'is_muted': true,
                'muted_until': DateTime.now()
                    .add(Duration(hours: _banDurationHours))
                    .toUtc()
                    .toIso8601String(),
              })
              .eq('community_id', widget.communityId)
              .eq('user_id', widget.targetUserId!);
          break;

        case 'hide_post':
          if (widget.targetPostId != null) {
            await SupabaseService.table('posts')
                .update({'is_hidden': true}).eq('id', widget.targetPostId!);
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
          // Incrementar strikes
          await SupabaseService.table('community_members')
              .update({
                'strikes': SupabaseService.client.rpc('increment_strikes',
                    params: {
                      'p_community_id': widget.communityId,
                      'p_user_id': widget.targetUserId,
                    }),
              })
              .eq('community_id', widget.communityId)
              .eq('user_id', widget.targetUserId!);
          break;

        case 'warn':
          // Enviar notificação de aviso
          await SupabaseService.table('notifications').insert({
            'user_id': widget.targetUserId,
            'type': 'moderation',
            'message':
                'Você recebeu um aviso: ${_reasonController.text.trim()}',
            'target_type': 'community',
            'target_id': widget.communityId,
          });
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
          SnackBar(content: Text('Erro: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ação de Moderação',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Target user info
                  if (_targetUser != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage:
                                _targetUser!['icon_url'] != null
                                    ? CachedNetworkImageProvider(
                                        _targetUser!['icon_url']
                                            as String)
                                    : null,
                            child: _targetUser!['icon_url'] == null
                                ? const Icon(Icons.person_rounded)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _targetUser!['nickname'] as String? ??
                                    'Usuário',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16),
                              ),
                              Text(
                                'Nível ${_targetUser!['level'] ?? 1}',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Seleção de ação
                  const Text('Tipo de Ação',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  ..._actions.map((action) {
                    final id = action['id'] as String;
                    final isSelected = _selectedAction == id;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedAction = id),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(action['color'] as int)
                                  .withOpacity(0.1)
                              : AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: Color(action['color'] as int)
                                      .withOpacity(0.5))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(action['icon'] as IconData,
                                color:
                                    Color(action['color'] as int),
                                size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action['label'] as String,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                  ),
                                  Text(
                                    action['description'] as String,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded,
                                  color:
                                      Color(action['color'] as int)),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Duração (para ban/mute)
                  if (_selectedAction == 'ban' ||
                      _selectedAction == 'mute') ...[
                    const SizedBox(height: 16),
                    const Text('Duração',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _DurationChip(
                          label: '1h',
                          hours: 1,
                          selected: _banDurationHours,
                          onTap: () =>
                              setState(() => _banDurationHours = 1),
                        ),
                        _DurationChip(
                          label: '6h',
                          hours: 6,
                          selected: _banDurationHours,
                          onTap: () =>
                              setState(() => _banDurationHours = 6),
                        ),
                        _DurationChip(
                          label: '24h',
                          hours: 24,
                          selected: _banDurationHours,
                          onTap: () =>
                              setState(() => _banDurationHours = 24),
                        ),
                        _DurationChip(
                          label: '7 dias',
                          hours: 168,
                          selected: _banDurationHours,
                          onTap: () =>
                              setState(() => _banDurationHours = 168),
                        ),
                        _DurationChip(
                          label: '30 dias',
                          hours: 720,
                          selected: _banDurationHours,
                          onTap: () =>
                              setState(() => _banDurationHours = 720),
                        ),
                        _DurationChip(
                          label: 'Permanente',
                          hours: 87600,
                          selected: _banDurationHours,
                          onTap: () => setState(
                              () => _banDurationHours = 87600),
                        ),
                      ],
                    ),
                  ],

                  // Motivo
                  const SizedBox(height: 16),
                  const Text('Motivo',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Descreva o motivo da ação...',
                      filled: true,
                      fillColor: AppTheme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botão executar
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _executeAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Executar Ação',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
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
    final isSelected = selected == hours;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.errorColor.withOpacity(0.15)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: AppTheme.errorColor.withOpacity(0.5))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.errorColor : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
