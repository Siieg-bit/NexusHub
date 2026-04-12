import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

// =============================================================================
// Menu de Moderação de Post — Estilo Amino
//
// Exibido como bottom sheet ao selecionar "Menu de Moderação" no menu de
// opções de um post. Disponível para staff da comunidade (agent, leader,
// curator, moderator).
//
// Opções:
//   1. Fixar no Feed de Destaques
//   2. Adicionar/Remover dos Destaques por ordem de entrada
//   3. Gerenciar Categorias
//   4. Enviar Esta Página (broadcast para membros)
//   5. Desabilitar Este Post
//   6. Histórico da Moderação
// =============================================================================

/// Exibe o Menu de Moderação de Post como bottom sheet.
/// Retorna true se alguma ação foi executada.
Future<bool?> showPostModerationMenu({
  required BuildContext context,
  required WidgetRef ref,
  required String communityId,
  required String postId,
  required bool isPinned,
  required bool isFeatured,
  required String postTitle,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _PostModerationMenuSheet(
      communityId: communityId,
      postId: postId,
      isPinned: isPinned,
      isFeatured: isFeatured,
      postTitle: postTitle,
    ),
  );
}

class _PostModerationMenuSheet extends ConsumerStatefulWidget {
  final String communityId;
  final String postId;
  final bool isPinned;
  final bool isFeatured;
  final String postTitle;

  const _PostModerationMenuSheet({
    required this.communityId,
    required this.postId,
    required this.isPinned,
    required this.isFeatured,
    required this.postTitle,
  });

  @override
  ConsumerState<_PostModerationMenuSheet> createState() =>
      _PostModerationMenuSheetState();
}

class _PostModerationMenuSheetState
    extends ConsumerState<_PostModerationMenuSheet> {
  bool _isLoading = false;

  Future<void> _pinPost() async {
    setState(() => _isLoading = true);
    try {
      final newPinned = !widget.isPinned;
      final result = await SupabaseService.rpc('pin_community_post', params: {
        'p_community_id': widget.communityId,
        'p_post_id': widget.postId,
        'p_pin': newPinned,
      });
      if (!mounted) return;
      final error = result is Map ? result['error'] : null;
      if (error != null) {
        String msg = 'Erro ao fixar post.';
        if (error == 'max_pinned_reached') {
          final max = result['max'] ?? 5;
          msg = 'Limite de $max posts fixados atingido.';
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newPinned
              ? 'Post fixado no Feed de Destaques!'
              : 'Post desafixado.'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _featurePost() async {
    setState(() => _isLoading = true);
    try {
      final featuredAt = DateTime.now().toUtc().toIso8601String();
      await SupabaseService.table('posts').update({
        'is_featured': true,
        'featured_at': featuredAt,
        'featured_until': null,
        'featured_by': SupabaseService.currentUserId,
      }).eq('id', widget.postId);

      // Registrar no log de moderação
      await SupabaseService.rpc('log_moderation_action', params: {
        'p_community_id': widget.communityId,
        'p_action': 'feature_post',
        'p_target_post_id': widget.postId,
        'p_reason': 'Adicionado à vitrine de destaques por ordem de entrada',
        'p_duration_hours': null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Post adicionado aos destaques!'),
        backgroundColor: AppTheme.warningColor,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unfeaturePost() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.table('posts').update({
        'is_featured': false,
        'featured_at': null,
        'featured_until': null,
        'featured_by': null,
      }).eq('id', widget.postId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Destaque removido.'),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _disablePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Desabilitar Post'),
        content: const Text(
            'Tem certeza que deseja desabilitar este post? Ele ficará oculto para os membros.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Desabilitar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await SupabaseService.table('posts')
          .update({'status': 'disabled'}).eq('id', widget.postId);

      await SupabaseService.rpc('log_moderation_action', params: {
        'p_community_id': widget.communityId,
        'p_action': 'hide_post',
        'p_target_post_id': widget.postId,
        'p_reason': 'Post desabilitado pela moderação',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Post desabilitado.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendBroadcast() async {
    setState(() => _isLoading = true);
    try {
      // Buscar todos os membros da comunidade
      final members = await SupabaseService.table('community_members')
          .select('user_id')
          .eq('community_id', widget.communityId)
          .eq('is_banned', false);

      final memberIds = (members as List)
          .map((m) => m['user_id'] as String)
          .where((id) => id != SupabaseService.currentUserId)
          .toList();

      if (memberIds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Nenhum membro para notificar.'),
          ));
        }
        return;
      }

      // Criar notificações em lote
      final notifications = memberIds
          .map((userId) => {
                'user_id': userId,
                'actor_id': SupabaseService.currentUserId,
                'type': 'broadcast',
                'title': 'Nova publicação em destaque',
                'body': widget.postTitle.isNotEmpty
                    ? widget.postTitle
                    : 'Confira esta publicação da comunidade!',
                'community_id': widget.communityId,
                'post_id': widget.postId,
              })
          .toList();

      // Inserir em lotes de 100
      for (var i = 0; i < notifications.length; i += 100) {
        final batch = notifications.sublist(
          i,
          i + 100 > notifications.length ? notifications.length : i + 100,
        );
        await SupabaseService.table('notifications').insert(batch);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Notificação enviada para ${memberIds.length} membro(s)!'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showModerationHistory() async {
    Navigator.of(context).pop();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ModerationHistorySheet(
        communityId: widget.communityId,
        postId: widget.postId,
      ),
    );
  }

  /// Alterna a presença do post na vitrine de destaques.
  Future<void> _toggleFeaturedPost() async {
    if (widget.isFeatured) {
      await _unfeaturePost();
      return;
    }
    await _featurePost();
  }

  /// Exibe diálogo para gerenciar categorias do post
  Future<void> _manageCategories() async {
    Navigator.of(context).pop();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ManageCategoriesSheet(
        communityId: widget.communityId,
        postId: widget.postId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: r.s(12), bottom: r.s(4)),
            width: r.s(40),
            height: r.s(4),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(r.s(2)),
            ),
          ),
          // Título
          Padding(
            padding: EdgeInsets.symmetric(
                vertical: r.s(16), horizontal: r.s(20)),
            child: Text(
              'Menu de Moderação',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: r.fs(18),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(r.s(24)),
              child: const CircularProgressIndicator(
                  color: AppTheme.primaryColor),
            )
          else ...[
            // 1. Fixar no Feed de Destaques
            _MenuItem(
              label: widget.isPinned
                  ? 'Desafixar do Feed de Destaques'
                  : 'Fixar no Feed de Destaques',
              icon: widget.isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              onTap: _pinPost,
            ),
            const Divider(height: 1, thickness: 0.5),
            // 2. Destacar Essa Publicação
            _MenuItem(
              label: widget.isFeatured
                  ? 'Remover Destaque'
                  : 'Adicionar aos Destaques',
              subtitle: widget.isFeatured
                  ? 'Remove o post da vitrine atual'
                  : 'Envia o post para a vitrine por ordem de entrada',
              icon: widget.isFeatured
                  ? Icons.star_border_rounded
                  : Icons.star_rounded,
              onTap: _toggleFeaturedPost,
            ),
            const Divider(height: 1, thickness: 0.5),
            // 3. Gerenciar Categorias
            _MenuItem(
              label: 'Gerenciar Categorias',
              icon: Icons.label_rounded,
              onTap: _manageCategories,
            ),
            const Divider(height: 1, thickness: 0.5),
            // 4. Enviar Esta Página
            _MenuItem(
              label: 'Enviar Esta Página',
              subtitle: 'Enviar uma notificação para todos os membros',
              icon: Icons.send_rounded,
              onTap: _sendBroadcast,
            ),
            const Divider(height: 1, thickness: 0.5),
            // 5. Desabilitar Este Post
            _MenuItem(
              label: 'Desabilitar Este Post',
              icon: Icons.block_rounded,
              isDestructive: true,
              onTap: _disablePost,
            ),
            const Divider(height: 1, thickness: 0.5),
            // 6. Histórico da Moderação
            _MenuItem(
              label: 'Histórico da Moderação',
              icon: Icons.history_rounded,
              onTap: _showModerationHistory,
            ),
            const Divider(height: 1, thickness: 0.5),
          ],
          // Botão Fechar
          Padding(
            padding: EdgeInsets.fromLTRB(
                r.s(16), r.s(8), r.s(16), r.s(16) + MediaQuery.of(context).padding.bottom),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: r.s(14)),
                  side: BorderSide(color: Colors.grey[700]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(10)),
                  ),
                ),
                child: Text(
                  'Fechar',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: r.fs(15),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item do menu
// ─────────────────────────────────────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final color = isDestructive ? Colors.red : Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(20), vertical: subtitle != null ? r.s(14) : r.s(18)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: r.fs(15),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: r.s(2)),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: r.fs(12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Histórico de Moderação do Post
// ─────────────────────────────────────────────────────────────────────────────
class _ModerationHistorySheet extends ConsumerStatefulWidget {
  final String communityId;
  final String postId;

  const _ModerationHistorySheet({
    required this.communityId,
    required this.postId,
  });

  @override
  ConsumerState<_ModerationHistorySheet> createState() =>
      _ModerationHistorySheetState();
}

class _ModerationHistorySheetState
    extends ConsumerState<_ModerationHistorySheet> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final logs = await SupabaseService.table('moderation_logs')
          .select('*, moderator:profiles!moderation_logs_moderator_id_fkey(nickname, icon_url)')
          .eq('community_id', widget.communityId)
          .eq('target_post_id', widget.postId)
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted) {
        setState(() {
          _logs = (logs as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'feature_post':
        return 'Destacado';
      case 'unfeature_post':
        return 'Destaque removido';
      case 'pin_post':
        return 'Fixado';
      case 'unpin_post':
        return 'Desafixado';
      case 'hide_post':
        return 'Desabilitado';
      case 'unhide_post':
        return 'Reabilitado';
      case 'delete_post':
        return 'Excluído';
      case 'broadcast':
        return 'Notificação enviada';
      case 'assign_category':
        return 'Categoria atribuída';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: r.s(12), bottom: r.s(4)),
            width: r.s(40),
            height: r.s(4),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(r.s(2)),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                vertical: r.s(16), horizontal: r.s(20)),
            child: Text(
              'Histórico da Moderação',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: r.fs(18),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryColor))
                : _logs.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma ação de moderação registrada.',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(r.s(16)),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final log = _logs[i];
                          final moderator = log['moderator'] as Map?;
                          final action = log['action'] as String? ?? '';
                          final reason = log['reason'] as String? ?? '';
                          final createdAt = log['created_at'] as String?;
                          final dt = createdAt != null
                              ? DateTime.tryParse(createdAt)
                              : null;
                          return Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: r.s(10)),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: r.s(18),
                                  backgroundColor:
                                      AppTheme.primaryColor.withValues(alpha: 0.2),
                                  backgroundImage: moderator?['icon_url'] !=
                                          null
                                      ? NetworkImage(
                                          moderator!['icon_url'] as String)
                                      : null,
                                  child: moderator?['icon_url'] == null
                                      ? Icon(Icons.person_rounded,
                                          size: r.s(18),
                                          color: AppTheme.primaryColor)
                                      : null,
                                ),
                                SizedBox(width: r.s(10)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        moderator?['nickname'] as String? ??
                                            'Moderador',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          fontWeight: FontWeight.w600,
                                          fontSize: r.fs(13),
                                        ),
                                      ),
                                      Text(
                                        _actionLabel(action),
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontSize: r.fs(12),
                                        ),
                                      ),
                                      if (reason.isNotEmpty)
                                        Text(
                                          reason,
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: r.fs(11),
                                          ),
                                        ),
                                      if (dt != null)
                                        Text(
                                          '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: r.fs(10),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                r.s(16), r.s(8), r.s(16), r.s(16) + MediaQuery.of(context).padding.bottom),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: r.s(14)),
                  side: BorderSide(color: Colors.grey[700]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(10)),
                  ),
                ),
                child: Text(
                  'Fechar',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: r.fs(15),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gerenciar Categorias do Post
// ─────────────────────────────────────────────────────────────────────────────
class _ManageCategoriesSheet extends ConsumerStatefulWidget {
  final String communityId;
  final String postId;

  const _ManageCategoriesSheet({
    required this.communityId,
    required this.postId,
  });

  @override
  ConsumerState<_ManageCategoriesSheet> createState() =>
      _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState
    extends ConsumerState<_ManageCategoriesSheet> {
  List<Map<String, dynamic>> _categories = [];
  String? _currentCategoryId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        SupabaseService.table('community_categories')
            .select()
            .eq('community_id', widget.communityId)
            .order('name'),
        SupabaseService.table('posts')
            .select('category_id')
            .eq('id', widget.postId)
            .maybeSingle(),
      ]);
      if (mounted) {
        setState(() {
          _categories =
              (results[0] as List).cast<Map<String, dynamic>>();
          _currentCategoryId =
              (results[1] as Map?)?['category_id'] as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCategory(String? categoryId) async {
    setState(() => _isSaving = true);
    try {
      final result = await SupabaseService.rpc('assign_post_category', params: {
        'p_community_id': widget.communityId,
        'p_post_id': widget.postId,
        'p_category_id': categoryId,
      });
      if (!mounted) return;
      final error = result is Map ? result['error'] : null;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $error')));
      } else {
        setState(() => _currentCategoryId = categoryId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Categoria atualizada!'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: r.s(12), bottom: r.s(4)),
            width: r.s(40),
            height: r.s(4),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(r.s(2)),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                vertical: r.s(16), horizontal: r.s(20)),
            child: Text(
              'Gerenciar Categorias',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: r.fs(18),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryColor))
                : _categories.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(r.s(20)),
                          child: Text(
                            'Nenhuma categoria criada.\nCrie categorias no ACM da comunidade.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.all(r.s(8)),
                        children: [
                          // Opção "Sem categoria"
                          RadioListTile<String?>(
                            title: const Text('Sem categoria'),
                            value: null,
                            groupValue: _currentCategoryId,
                            onChanged: _isSaving
                                ? null
                                : (v) => _saveCategory(v),
                            activeColor: AppTheme.primaryColor,
                          ),
                          ..._categories.map((cat) => RadioListTile<String?>(
                                title: Text(cat['name'] as String? ?? ''),
                                value: cat['id'] as String?,
                                groupValue: _currentCategoryId,
                                onChanged: _isSaving
                                    ? null
                                    : (v) => _saveCategory(v),
                                activeColor: AppTheme.primaryColor,
                              )),
                        ],
                      ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                r.s(16), r.s(8), r.s(16), r.s(16) + MediaQuery.of(context).padding.bottom),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: r.s(14)),
                  side: BorderSide(color: Colors.grey[700]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(10)),
                  ),
                ),
                child: Text(
                  'Fechar',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: r.fs(15),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
