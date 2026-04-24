import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
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
      // RPC review_wiki_entry: atualiza status, notifica autor e loga moderação atomicamente
      await SupabaseService.rpc('review_wiki_entry', params: {
        'p_wiki_id':       entryId,
        'p_action':        action,
        'p_reject_reason': rejectReason,
      });

      
