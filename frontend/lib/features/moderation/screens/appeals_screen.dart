import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final myAppealsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async {
    final result = await SupabaseService.rpc('get_my_appeals');
    return List<Map<String, dynamic>>.from(
      (result as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Tela principal
// ─────────────────────────────────────────────────────────────────────────────

/// Tela de Apelações — permite ao usuário apelar contra banimentos de comunidades.
class AppealsScreen extends ConsumerWidget {
  const AppealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final theme = context.nexusTheme;
    final appealsAsync = ref.watch(myAppealsProvider);

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: theme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          s.appealsTitle,
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: r.fs(18),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.textSecondary),
            onPressed: () => ref.invalidate(myAppealsProvider),
          ),
        ],
      ),
      body: appealsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(context, r, theme, s, ref, e),
        data: (appeals) => appeals.isEmpty
            ? _buildEmpty(context, r, theme, s)
            : _buildList(context, r, theme, s, appeals, ref),
      ),
    );
  }

  Widget _buildError(BuildContext context, Responsive r, NexusThemeData theme,
      dynamic s, WidgetRef ref, Object e) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: theme.error, size: r.s(48)),
          SizedBox(height: r.s(12)),
          Text(s.anErrorOccurredTryAgain,
              style: TextStyle(color: theme.textSecondary, fontSize: r.fs(14))),
          SizedBox(height: r.s(16)),
          ElevatedButton(
            onPressed: () => ref.invalidate(myAppealsProvider),
            child: Text(s.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, Responsive r, NexusThemeData theme, dynamic s) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.s(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: r.s(80),
              height: r.s(80),
              decoration: BoxDecoration(
                color: theme.accentPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.gavel_rounded,
                  color: theme.accentPrimary, size: r.s(40)),
            ),
            SizedBox(height: r.s(20)),
            Text(
              s.appealsEmptyTitle,
              style: TextStyle(
                fontSize: r.fs(18),
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.s(8)),
            Text(
              s.appealsEmptySubtitle,
              style: TextStyle(
                  fontSize: r.fs(14), color: theme.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, Responsive r, NexusThemeData theme,
      dynamic s, List<Map<String, dynamic>> appeals, WidgetRef ref) {
    return ListView(
      padding: EdgeInsets.all(r.s(16)),
      children: [
        // Banner informativo
        Container(
          padding: EdgeInsets.all(r.s(14)),
          decoration: BoxDecoration(
            color: theme.accentPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(r.s(12)),
            border: Border.all(color: theme.accentPrimary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: theme.accentPrimary, size: r.s(18)),
              SizedBox(width: r.s(10)),
              Expanded(
                child: Text(
                  s.appealsInfoBanner,
                  style: TextStyle(
                      fontSize: r.fs(12), color: theme.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: r.s(16)),
        ...appeals.map((appeal) => _AppealCard(appeal: appeal, ref: ref)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de apelação
// ─────────────────────────────────────────────────────────────────────────────

class _AppealCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> appeal;
  final WidgetRef ref;

  const _AppealCard({required this.appeal, required this.ref});

  @override
  ConsumerState<_AppealCard> createState() => _AppealCardState();
}

class _AppealCardState extends ConsumerState<_AppealCard> {
  bool _expanded = false;
  bool _isCancelling = false;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    final s = ref.watch(stringsProvider);
    final appeal = widget.appeal;

    final status = appeal['status'] as String? ?? 'pending';
    final communityName = appeal['community_name'] as String? ?? '';
    final communityIcon = appeal['community_icon'] as String?;
    final reason = appeal['reason'] as String? ?? '';
    final reviewerNote = appeal['reviewer_note'] as String?;
    final banReason = appeal['ban_reason'] as String?;
    final createdAt = appeal['created_at'] != null
        ? DateTime.tryParse(appeal['created_at'] as String)
        : null;
    final reviewedAt = appeal['reviewed_at'] != null
        ? DateTime.tryParse(appeal['reviewed_at'] as String)
        : null;

    final (statusColor, statusIcon, statusLabel) = switch (status) {
      'accepted' => (theme.success, Icons.check_circle_rounded, s.appealStatusAccepted),
      'rejected' => (theme.error, Icons.cancel_rounded, s.appealStatusRejected),
      'cancelled' => (theme.textSecondary, Icons.remove_circle_rounded, s.appealStatusCancelled),
      _ => (const Color(0xFFFF9800), Icons.hourglass_top_rounded, s.appealStatusPending),
    };

    return Container(
      margin: EdgeInsets.only(bottom: r.s(12)),
      decoration: BoxDecoration(
        color: theme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Cabeçalho
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(r.s(16)),
            child: Padding(
              padding: EdgeInsets.all(r.s(14)),
              child: Row(
                children: [
                  // Ícone da comunidade
                  ClipRRect(
                    borderRadius: BorderRadius.circular(r.s(8)),
                    child: communityIcon != null
                        ? CachedNetworkImage(
                            imageUrl: communityIcon,
                            width: r.s(44),
                            height: r.s(44),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _communityPlaceholder(r, theme),
                          )
                        : _communityPlaceholder(r, theme),
                  ),
                  SizedBox(width: r.s(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          communityName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: r.fs(15),
                            color: theme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: r.s(2)),
                        if (createdAt != null)
                          Text(
                            timeago.format(createdAt, locale: 'pt_BR'),
                            style: TextStyle(
                                fontSize: r.fs(12), color: theme.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: r.s(8)),
                  // Badge de status
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(10), vertical: r.s(4)),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(r.s(20)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: r.s(13)),
                        SizedBox(width: r.s(4)),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: r.fs(11),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: r.s(4)),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: theme.textSecondary,
                    size: r.s(20),
                  ),
                ],
              ),
            ),
          ),

          // Conteúdo expandido
          if (_expanded) ...[
            Divider(height: 1, color: theme.divider),
            Padding(
              padding: EdgeInsets.all(r.s(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Motivo do banimento
                  if (banReason != null) ...[
                    _InfoRow(
                      icon: Icons.block_rounded,
                      label: s.appealBanReason,
                      value: banReason,
                      theme: theme,
                      r: r,
                      valueColor: theme.error,
                    ),
                    SizedBox(height: r.s(10)),
                  ],

                  // Motivo da apelação
                  _InfoRow(
                    icon: Icons.edit_note_rounded,
                    label: s.appealYourReason,
                    value: reason,
                    theme: theme,
                    r: r,
                  ),

                  // Nota do revisor
                  if (reviewerNote != null) ...[
                    SizedBox(height: r.s(10)),
                    _InfoRow(
                      icon: Icons.rate_review_rounded,
                      label: s.appealReviewerNote,
                      value: reviewerNote,
                      theme: theme,
                      r: r,
                      valueColor: status == 'accepted'
                          ? theme.success
                          : theme.error,
                    ),
                  ],

                  // Data de revisão
                  if (reviewedAt != null) ...[
                    SizedBox(height: r.s(10)),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: r.s(14), color: theme.textSecondary),
                        SizedBox(width: r.s(6)),
                        Text(
                          '${s.appealReviewedAt}: ${timeago.format(reviewedAt, locale: 'pt_BR')}',
                          style: TextStyle(
                              fontSize: r.fs(12), color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ],

                  // Botão cancelar (só para pendentes)
                  if (status == 'pending') ...[
                    SizedBox(height: r.s(14)),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isCancelling
                            ? null
                            : () => _cancelAppeal(context, appeal['id'] as String),
                        icon: _isCancelling
                            ? SizedBox(
                                width: r.s(14),
                                height: r.s(14),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: theme.error),
                              )
                            : Icon(Icons.cancel_outlined,
                                size: r.s(16), color: theme.error),
                        label: Text(
                          s.appealCancel,
                          style: TextStyle(color: theme.error, fontSize: r.fs(13)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: theme.error.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r.s(10)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _communityPlaceholder(Responsive r, NexusThemeData theme) {
    return Container(
      width: r.s(44),
      height: r.s(44),
      color: theme.surfaceSecondary,
      child: Icon(Icons.group_rounded, color: theme.textSecondary, size: r.s(22)),
    );
  }

  Future<void> _cancelAppeal(BuildContext context, String appealId) async {
    final s = ref.read(stringsProvider);
    setState(() => _isCancelling = true);
    try {
      await SupabaseService.rpc('review_ban_appeal', params: {
        'p_appeal_id': appealId,
        'p_action': 'cancel',
        'p_note': null,
      });
      if (mounted) {
        ref.invalidate(myAppealsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.appealCancelledSuccess),
            backgroundColor: context.nexusTheme.success,
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
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tela de envio de nova apelação
// ─────────────────────────────────────────────────────────────────────────────

class SubmitAppealScreen extends ConsumerStatefulWidget {
  final String communityId;
  final String communityName;

  const SubmitAppealScreen({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  ConsumerState<SubmitAppealScreen> createState() => _SubmitAppealScreenState();
}

class _SubmitAppealScreenState extends ConsumerState<SubmitAppealScreen> {
  final _reasonController = TextEditingController();
  final _additionalController = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _additionalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = ref.read(stringsProvider);
    final reason = _reasonController.text.trim();
    if (reason.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.appealReasonTooShort),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.rpc('submit_ban_appeal', params: {
        'p_community_id': widget.communityId,
        'p_reason': reason,
        'p_additional': _additionalController.text.trim().isNotEmpty
            ? _additionalController.text.trim()
            : null,
      });
      if (mounted) {
        setState(() { _submitted = true; _isSubmitting = false; });
        ref.invalidate(myAppealsProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final msg = e.toString().contains('already_pending')
            ? s.appealAlreadyPending
            : e.toString().contains('not_banned')
            ? s.appealNotBanned
            : s.anErrorOccurredTryAgain;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: context.nexusTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final theme = context.nexusTheme;

    if (_submitted) {
      return Scaffold(
        backgroundColor: theme.backgroundPrimary,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(r.s(32)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: r.s(80),
                  height: r.s(80),
                  decoration: BoxDecoration(
                    color: theme.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_rounded,
                      color: theme.success, size: r.s(44)),
                ),
                SizedBox(height: r.s(20)),
                Text(
                  s.appealSubmittedTitle,
                  style: TextStyle(
                    fontSize: r.fs(20),
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: r.s(8)),
                Text(
                  s.appealSubmittedSubtitle,
                  style: TextStyle(
                      fontSize: r.fs(14), color: theme.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: r.s(24)),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(12)),
                    ),
                  ),
                  child: Text(s.backToAppeals,
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: theme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          s.appealSubmitTitle,
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: r.fs(18),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Comunidade alvo
            Container(
              padding: EdgeInsets.all(r.s(14)),
              decoration: BoxDecoration(
                color: theme.surfacePrimary,
                borderRadius: BorderRadius.circular(r.s(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.group_rounded,
                      color: theme.accentPrimary, size: r.s(20)),
                  SizedBox(width: r.s(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.appealTargetCommunity,
                          style: TextStyle(
                              fontSize: r.fs(11), color: theme.textSecondary),
                        ),
                        Text(
                          widget.communityName,
                          style: TextStyle(
                            fontSize: r.fs(15),
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(20)),

            // Aviso
            Container(
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(r.s(10)),
                border: Border.all(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFFF9800), size: 18),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Text(
                      s.appealWarning,
                      style: TextStyle(
                          fontSize: r.fs(12),
                          color: theme.textSecondary,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(20)),

            // Campo de motivo
            Text(
              s.appealReasonLabel,
              style: TextStyle(
                fontSize: r.fs(14),
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            ),
            SizedBox(height: r.s(8)),
            TextField(
              controller: _reasonController,
              maxLines: 5,
              maxLength: 1000,
              style: TextStyle(fontSize: r.fs(14), color: theme.textPrimary),
              decoration: InputDecoration(
                hintText: s.appealReasonHint,
                hintStyle: TextStyle(
                    fontSize: r.fs(13), color: theme.textSecondary),
                filled: true,
                fillColor: theme.surfacePrimary,
                counterStyle: TextStyle(
                    fontSize: r.fs(11), color: theme.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide(
                      color: theme.accentPrimary.withValues(alpha: 0.5)),
                ),
              ),
            ),
            SizedBox(height: r.s(16)),

            // Campo adicional
            Text(
              s.appealAdditionalLabel,
              style: TextStyle(
                fontSize: r.fs(14),
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            ),
            SizedBox(height: r.s(4)),
            Text(
              s.appealAdditionalHint2,
              style: TextStyle(fontSize: r.fs(12), color: theme.textSecondary),
            ),
            SizedBox(height: r.s(8)),
            TextField(
              controller: _additionalController,
              maxLines: 3,
              maxLength: 500,
              style: TextStyle(fontSize: r.fs(14), color: theme.textPrimary),
              decoration: InputDecoration(
                hintText: s.appealAdditionalHint,
                hintStyle: TextStyle(
                    fontSize: r.fs(13), color: theme.textSecondary),
                filled: true,
                fillColor: theme.surfacePrimary,
                counterStyle: TextStyle(
                    fontSize: r.fs(11), color: theme.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide(
                      color: theme.accentPrimary.withValues(alpha: 0.5)),
                ),
              ),
            ),
            SizedBox(height: r.s(24)),

            SizedBox(
              width: double.infinity,
              height: r.s(52),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(14)),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: r.s(22),
                        height: r.s(22),
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded,
                              size: r.s(18), color: Colors.white),
                          SizedBox(width: r.s(8)),
                          Text(
                            s.appealSubmitButton,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: r.fs(16),
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget auxiliar
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final NexusThemeData theme;
  final Responsive r;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
    required this.r,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: r.s(14), color: theme.textSecondary),
            SizedBox(width: r.s(6)),
            Text(
              label,
              style: TextStyle(
                fontSize: r.fs(11),
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        SizedBox(height: r.s(4)),
        Text(
          value,
          style: TextStyle(
            fontSize: r.fs(13),
            color: valueColor ?? theme.textPrimary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
