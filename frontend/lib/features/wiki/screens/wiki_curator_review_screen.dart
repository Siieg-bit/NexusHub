import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/cosmetic_avatar.dart';

/// Tela de revisão de Wikis pendentes — estilo Amino Apps.
/// Apenas curadores e leaders podem acessar.
class WikiCuratorReviewScreen extends StatefulWidget {
  final String communityId;
  const WikiCuratorReviewScreen({super.key, required this.communityId});

  @override
  State<WikiCuratorReviewScreen> createState() =>
      _WikiCuratorReviewScreenState();
}

class _WikiCuratorReviewScreenState extends State<WikiCuratorReviewScreen> {
  List<Map<String, dynamic>> _pendingEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    try {
      final res = await SupabaseService.table('wiki_entries')
          .select('*, profiles(*)')
          .eq('community_id', widget.communityId)
          .eq('status', 'pending')
          .order('created_at', ascending: true);
      _pendingEntries = List<Map<String, dynamic>>.from(res as List);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reviewEntry(String entryId, String action) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final newStatus = action == 'approve' ? 'approved' : 'rejected';
    String? rejectReason;

    if (action == 'reject') {
      rejectReason = await _showRejectDialog();
      if (rejectReason == null) return; // Cancelou
    }

    try {
      await SupabaseService.table('wiki_entries').update({
        'status': newStatus,
        'reviewed_by': userId,
        'reviewed_at': DateTime.now().toIso8601String(),
        if (rejectReason != null) 'submission_note': rejectReason,
      }).eq('id', entryId);

      // Enviar notificação ao autor
      final entry =
          _pendingEntries.firstWhere((e) => e['id'] == entryId, orElse: () => {});
      if (entry.isNotEmpty) {
        try {
          await SupabaseService.table('notifications').insert({
            'user_id': entry['author_id'],
            'type': action == 'approve' ? 'wiki_approved' : 'wiki_rejected',
            'title': action == 'approve'
                ? 'Wiki aprovada!'
                : 'Wiki precisa de alterações',
            'body': action == 'approve'
                ? 'Sua entrada "${entry['title']}" foi aprovada e está visível no catálogo.'
                : 'Sua entrada "${entry['title']}" precisa de alterações: ${rejectReason ?? ""}',
            'community_id': widget.communityId,
            'wiki_id': entryId,
            'action_url': '/wiki/$entryId',
          });
        } catch (_) {}

        // Log de moderação
        try {
          await SupabaseService.table('moderation_logs').insert({
            'community_id': widget.communityId,
            'moderator_id': userId,
            'action': action == 'approve' ? 'wiki_approve' : 'wiki_reject',
            'target_wiki_id': entryId,
            'target_user_id': entry['author_id'],
            'reason': action == 'approve'
                ? 'Wiki aprovada'
                : rejectReason ?? 'Rejeitada',
          });
        } catch (_) {}
      }

      setState(() {
        _pendingEntries.removeWhere((e) => e['id'] == entryId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'approve'
                ? 'Wiki aprovada com sucesso!'
                : 'Wiki rejeitada'),
            backgroundColor:
                action == 'approve' ? AppTheme.successColor : AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Motivo da rejeição',
            style: TextStyle(
                color: context.textPrimary, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: context.textPrimary),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Descreva o que precisa ser corrigido...',
            hintStyle: TextStyle(color: context.textSecondary),
            filled: true,
            fillColor: context.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: TextStyle(color: context.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(ctx, text.isNotEmpty ? text : 'Sem motivo especificado');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child:
                const Text('Rejeitar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Row(
          children: [
            const Text('Revisão de Wiki',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                    fontSize: 20)),
            const SizedBox(width: 8),
            if (_pendingEntries.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_pendingEntries.length}',
                  style: const TextStyle(
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppTheme.primaryColor))
          : _pendingEntries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 64,
                          color: AppTheme.successColor.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text('Nenhuma wiki pendente',
                          style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Todas as submissões foram revisadas.',
                          style: TextStyle(
                              color: context.textHint, fontSize: 14)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPending,
                  color: AppTheme.primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _pendingEntries[index];
                      return _PendingWikiCard(
                        entry: entry,
                        onApprove: () => _reviewEntry(entry['id'], 'approve'),
                        onReject: () => _reviewEntry(entry['id'], 'reject'),
                        onTap: () => context.push('/wiki/${entry['id']}'),
                      );
                    },
                  ),
                ),
    );
  }
}

class _PendingWikiCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onTap;

  const _PendingWikiCard({
    required this.entry,
    required this.onApprove,
    required this.onReject,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = entry['title'] as String? ?? 'Sem titulo';
    final content = entry['content'] as String? ?? '';
    final coverUrl = entry['cover_image_url'] as String?;
    final category = entry['category'] as String?;
    final author = entry['profiles'] as Map<String, dynamic>?;
    final createdAt =
        DateTime.tryParse(entry['created_at'] as String? ?? '') ?? DateTime.now();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.warningColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.warningColor.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            if (coverUrl != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

            // Pending badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: coverUrl == null
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : null,
              ),
              child: Row(
                children: [
                  Icon(Icons.pending_actions_rounded,
                      size: 16, color: AppTheme.warningColor),
                  const SizedBox(width: 6),
                  Text('Pendente de revisao',
                      style: TextStyle(
                          color: AppTheme.warningColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(timeago.format(createdAt, locale: 'pt_BR'),
                      style:
                          TextStyle(color: context.textHint, fontSize: 11)),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category
                  if (category != null && category.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(category,
                          style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),

                  // Title
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: context.textPrimary)),
                  const SizedBox(height: 8),

                  // Content preview
                  Text(content,
                      style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 14,
                          height: 1.5),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),

                  // Author
                  if (author != null)
                    Row(
                      children: [
                        CosmeticAvatar(
                          userId: author['id'] as String?,
                          avatarUrl: author['icon_url'] as String?,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          author['nickname'] as String? ?? 'Anonimo',
                          style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onReject,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      AppTheme.errorColor.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.close_rounded,
                                    size: 18, color: AppTheme.errorColor),
                                SizedBox(width: 6),
                                Text('Rejeitar',
                                    style: TextStyle(
                                        color: AppTheme.errorColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: onApprove,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.successColor,
                                  Color(0xFF00C853)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.successColor
                                      .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_rounded,
                                    size: 18, color: Colors.white),
                                SizedBox(width: 6),
                                Text('Aprovar',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
