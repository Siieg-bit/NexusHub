import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Tela de revisão de Wikis pendentes — estilo Amino Apps.
/// Apenas curadores e leaders podem acessar.
class WikiCuratorReviewScreen extends ConsumerStatefulWidget {
  final String communityId;
  const WikiCuratorReviewScreen({super.key, required this.communityId});

  @override
  ConsumerState<WikiCuratorReviewScreen> createState() =>
      _WikiCuratorReviewScreenState();
}

class _WikiCuratorReviewScreenState extends ConsumerState<WikiCuratorReviewScreen> {
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
      if (!mounted) return;
      _pendingEntries = List<Map<String, dynamic>>.from(res as List? ?? []);
      if (!mounted) return;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reviewEntry(String entryId, String action) async {
    final s = getStrings();
    final r = context.r;
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
      final entry = _pendingEntries.firstWhere((e) => e['id'] == entryId,
          orElse: () => {});
      if (entry.isNotEmpty) {
        try {
          final response = await SupabaseService.rpc(
            'send_system_notification',
            params: {
              'p_user_id': entry['author_id'],
              'p_type': action == 'approve' ? 'wiki_approved' : 'wiki_rejected',
              'p_title': action == 'approve'
                  ? s.wikiApproved
                  : s.wikiNeedsChanges,
              'p_body': action == 'approve'
                  ? s.entryApprovedMsg(entry['title'] as String? ?? '')
                  : s.entryNeedsChanges(entry['title'] as String? ?? '', rejectReason ?? ''),
              'p_community_id': widget.communityId,
              'p_wiki_id': entryId,
              'p_action_url': '/wiki/$entryId',
            },
          );

          final result = response is Map<String, dynamic>
              ? response
              : Map<String, dynamic>.from(response as Map);

          if (result['success'] != true) {
            throw Exception(result['error'] ?? 'unknown_error');
          }
        } catch (e) {
          debugPrint(
              '[wiki_curator_review_screen] Erro ao notificar autor: $e');
        }

        // Log de moderação via RPC server-side
        try {
          await SupabaseService.rpc('log_moderation_action', params: {
            'p_community_id': widget.communityId,
            'p_action': action == 'approve' ? 'wiki_approve' : 'wiki_reject',
            'p_target_wiki_id': entryId,
            'p_target_user_id': entry['author_id'],
            'p_reason': action == 'approve'
                ? s.wikiApprovedStatus
                : rejectReason ?? s.rejected2,
          });
        } catch (e) {
          debugPrint('[wiki_curator_review_screen] Erro: $e');
        }
      }

      setState(() {
        _pendingEntries.removeWhere((e) => e['id'] == entryId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'approve'
                ? s.wikiApprovalSuccess
                : s.wikiRejected),
            backgroundColor: action == 'approve'
                ? context.nexusTheme.success
                : context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(12))),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.anErrorOccurredTryAgain),
            backgroundColor: context.nexusTheme.error,
          ),
        );
      }
    }
  }

  Future<String?> _showRejectDialog() async {
    final s = getStrings();
    final r = context.r;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nexusTheme.surfacePrimary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(20))),
        title: Text(s.rejectionReason,
            style: TextStyle(
                color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: context.nexusTheme.textPrimary),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: s.describeCorrections,
            hintStyle: TextStyle(color: context.nexusTheme.textSecondary),
            filled: true,
            fillColor: context.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.s(12)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel,
                style: TextStyle(color: context.nexusTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(
                  ctx, text.isNotEmpty ? text : s.noReasonSpecified);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.nexusTheme.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(12))),
            ),
            child:
                Text(s.reject, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        elevation: 0,
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        title: Row(
          children: [
            Text(s.wikiReview,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(20))),
            SizedBox(width: r.s(8)),
            if (_pendingEntries.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: r.s(8), vertical: 2),
                decoration: BoxDecoration(
                  color: context.nexusTheme.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(r.s(12)),
                ),
                child: Text(
                  '${_pendingEntries.length}',
                  style: TextStyle(
                    color: context.nexusTheme.warning,
                    fontWeight: FontWeight.w800,
                    fontSize: r.fs(14),
                  ),
                ),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.nexusTheme.accentPrimary))
          : _pendingEntries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: r.s(64),
                          color: context.nexusTheme.success.withValues(alpha: 0.5)),
                      SizedBox(height: r.s(16)),
                      Text(s.noPendingWiki,
                          style: TextStyle(
                              color: context.nexusTheme.textSecondary,
                              fontSize: r.fs(16),
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: r.s(8)),
                      Text(s.allSubmissionsReviewed,
                          style: TextStyle(
                              color: context.nexusTheme.textHint, fontSize: r.fs(14))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPending,
                  color: context.nexusTheme.accentPrimary,
                  child: ListView.builder(
                    padding: EdgeInsets.all(r.s(16)),
                    itemCount: _pendingEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _pendingEntries[index];
                      return _PendingWikiCard(
                        entry: entry,
                        onApprove: () => _reviewEntry(entry['id'], 'approve'),
                        onReject: () => _reviewEntry(entry['id'], 'reject'),
                        onTap: () => context.push('/wiki/${entry["id"]}'),
                      );
                    },
                  ),
                ),
    );
  }
}

class _PendingWikiCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final title = entry['title'] as String? ?? s.noTitle;
    final content = entry['content'] as String? ?? '';
    final coverUrl = entry['cover_image_url'] as String?;
    final category = entry['category'] as String?;
    final author = entry['profiles'] as Map<String, dynamic>?;
    final createdAt = DateTime.tryParse(entry['created_at'] as String? ?? '') ??
        DateTime.now();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: r.s(16)),
        decoration: BoxDecoration(
          color: context.nexusTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(
            color: context.nexusTheme.warning.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: context.nexusTheme.warning.withValues(alpha: 0.08),
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
                  height: r.s(140),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

            // Pending badge
            Container(
              width: double.infinity,
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              decoration: BoxDecoration(
                color: context.nexusTheme.warning.withValues(alpha: 0.1),
                borderRadius: coverUrl == null
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : null,
              ),
              child: Row(
                children: [
                  Icon(Icons.pending_actions_rounded,
                      size: r.s(16), color: context.nexusTheme.warning),
                  SizedBox(width: r.s(6)),
                  Text(s.pendingReview2,
                      style: TextStyle(
                          color: context.nexusTheme.warning,
                          fontSize: r.fs(12),
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(timeago.format(createdAt, locale: 'pt_BR'),
                      style: TextStyle(
                          color: context.nexusTheme.textHint, fontSize: r.fs(11))),
                ],
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(r.s(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category
                  if (category != null && category.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(bottom: r.s(8)),
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(10), vertical: r.s(4)),
                      decoration: BoxDecoration(
                        color: context.nexusTheme.accentPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(r.s(8)),
                      ),
                      child: Text(category,
                          style: TextStyle(
                              color: context.nexusTheme.accentPrimary,
                              fontSize: r.fs(11),
                              fontWeight: FontWeight.w700)),
                    ),

                  // Title
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: r.fs(18),
                          color: context.nexusTheme.textPrimary)),
                  SizedBox(height: r.s(8)),

                  // Content preview
                  Text(content,
                      style: TextStyle(
                          color: context.nexusTheme.textSecondary,
                          fontSize: r.fs(14),
                          height: 1.5),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: r.s(12)),

                  // Author
                  if (author != null)
                    Row(
                      children: [
                        CosmeticAvatar(
                          userId: author['id'] as String?,
                          avatarUrl: author['icon_url'] as String?,
                          size: r.s(28),
                        ),
                        SizedBox(width: r.s(8)),
                        Text(
                          author['nickname'] as String? ?? s.anonymous2,
                          style: TextStyle(
                              color: context.nexusTheme.textSecondary,
                              fontSize: r.fs(13),
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  SizedBox(height: r.s(16)),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onReject,
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: r.s(12)),
                            decoration: BoxDecoration(
                              color:
                                  context.nexusTheme.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(r.s(12)),
                              border: Border.all(
                                  color: context.nexusTheme.error
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.close_rounded,
                                    size: r.s(18), color: context.nexusTheme.error),
                                SizedBox(width: r.s(6)),
                                Text(s.reject,
                                    style: TextStyle(
                                        color: context.nexusTheme.error,
                                        fontWeight: FontWeight.w700,
                                        fontSize: r.fs(14))),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: r.s(12)),
                      Expanded(
                        child: GestureDetector(
                          onTap: onApprove,
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: r.s(12)),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  context.nexusTheme.success,
                                  Color(0xFF00C853)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(r.s(12)),
                              boxShadow: [
                                BoxShadow(
                                  color: context.nexusTheme.success
                                      .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_rounded,
                                    size: r.s(18), color: Colors.white),
                                SizedBox(width: r.s(6)),
                                Text(s.approve,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: r.fs(14))),
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
