import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de categoria de denúncia
// ─────────────────────────────────────────────────────────────────────────────
class _ReportCategory {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final bool requiresDetails;

  const _ReportCategory({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    this.requiresDetails = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal
// ─────────────────────────────────────────────────────────────────────────────

/// Diálogo de denúncia universal — suporta posts, comentários, mensagens,
/// wikis, stories e perfis de usuário.
class ReportDialog extends ConsumerStatefulWidget {
  final String communityId;
  final String? targetPostId;
  final String? targetCommentId;
  final String? targetMessageId;
  final String? targetUserId;
  final String? targetWikiId;
  final String? targetStoryId;

  const ReportDialog({
    super.key,
    required this.communityId,
    this.targetPostId,
    this.targetCommentId,
    this.targetMessageId,
    this.targetUserId,
    this.targetWikiId,
    this.targetStoryId,
  });

  /// Abre o bottom sheet de denúncia.
  static Future<void> show(
    BuildContext context, {
    required String communityId,
    String? targetPostId,
    String? targetCommentId,
    String? targetMessageId,
    String? targetUserId,
    String? targetWikiId,
    String? targetStoryId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReportDialog(
        communityId: communityId,
        targetPostId: targetPostId,
        targetCommentId: targetCommentId,
        targetMessageId: targetMessageId,
        targetUserId: targetUserId,
        targetWikiId: targetWikiId,
        targetStoryId: targetStoryId,
      ),
    );
  }

  @override
  ConsumerState<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<ReportDialog>
    with SingleTickerProviderStateMixin {
  String? _selectedId;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;
  late AnimationController _checkAnim;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkScale = CurvedAnimation(parent: _checkAnim, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _checkAnim.dispose();
    super.dispose();
  }

  List<_ReportCategory> _getCategories() {
    final s = getStrings();
    return [
      _ReportCategory(
        id: 'sexual_content',
        label: s.reportCategorySexual,
        description: s.reportCategorySexualDesc,
        icon: Icons.no_adult_content_rounded,
        color: const Color(0xFFE91E63),
      ),
      _ReportCategory(
        id: 'bullying',
        label: s.reportCategoryBullying,
        description: s.reportCategoryBullyingDesc,
        icon: Icons.person_off_rounded,
        color: const Color(0xFFF44336),
      ),
      _ReportCategory(
        id: 'hate_speech',
        label: s.reportCategoryHate,
        description: s.reportCategoryHateDesc,
        icon: Icons.record_voice_over_rounded,
        color: const Color(0xFFFF5722),
      ),
      _ReportCategory(
        id: 'violence',
        label: s.reportCategoryViolence,
        description: s.reportCategoryViolenceDesc,
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFFF9800),
      ),
      _ReportCategory(
        id: 'spam',
        label: s.reportCategorySpam,
        description: s.reportCategorySpamDesc,
        icon: Icons.mark_email_unread_rounded,
        color: const Color(0xFFFFC107),
      ),
      _ReportCategory(
        id: 'misinformation',
        label: s.reportCategoryMisinfo,
        description: s.reportCategoryMisinfoDesc,
        icon: Icons.fact_check_rounded,
        color: const Color(0xFF2196F3),
      ),
      _ReportCategory(
        id: 'art_theft',
        label: s.reportCategoryArtTheft,
        description: s.reportCategoryArtTheftDesc,
        icon: Icons.palette_rounded,
        color: const Color(0xFF9C27B0),
      ),
      _ReportCategory(
        id: 'impersonation',
        label: s.reportCategoryImpersonation,
        description: s.reportCategoryImpersonationDesc,
        icon: Icons.masks_rounded,
        color: const Color(0xFF607D8B),
      ),
      _ReportCategory(
        id: 'self_harm',
        label: s.reportCategorySelfHarm,
        description: s.reportCategorySelfHarmDesc,
        icon: Icons.health_and_safety_rounded,
        color: const Color(0xFF00BCD4),
      ),
      _ReportCategory(
        id: 'other',
        label: s.reportCategoryOther,
        description: s.reportCategoryOtherDesc,
        icon: Icons.more_horiz_rounded,
        color: const Color(0xFF9E9E9E),
        requiresDetails: true,
      ),
    ];
  }

  _ReportCategory? get _selected => _selectedId == null
      ? null
      : _getCategories().firstWhere((c) => c.id == _selectedId);

  Future<void> _submit() async {
    final s = ref.read(stringsProvider);
    if (_selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.selectReportType), backgroundColor: Colors.orange),
      );
      return;
    }
    final cat = _selected!;
    if (cat.requiresDetails && _detailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.reportDetailsRequired), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.rpc('submit_flag', params: {
        'p_community_id': widget.communityId,
        'p_flag_type': _selectedId,
        'p_reason': _detailsController.text.trim().isNotEmpty
            ? _detailsController.text.trim()
            : null,
        'p_target_post_id': widget.targetPostId,
        'p_target_comment_id': widget.targetCommentId,
        'p_target_chat_message_id': widget.targetMessageId,
        'p_target_user_id': widget.targetUserId,
        'p_target_wiki_id': widget.targetWikiId,
        'p_target_story_id': widget.targetStoryId,
      });

      if (mounted) {
        setState(() { _submitted = true; _isSubmitting = false; });
        _checkAnim.forward();
        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.anErrorOccurredTryAgain),
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

    return Container(
      decoration: BoxDecoration(
        color: theme.backgroundSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _submitted ? _buildSuccess(r, theme) : _buildForm(r, theme, s),
      ),
    );
  }

  Widget _buildSuccess(Responsive r, NexusThemeExtension theme) {
    final s = getStrings();
    return SizedBox(
      key: const ValueKey('success'),
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: r.s(48), horizontal: r.s(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _checkScale,
              child: Container(
                width: r.s(72),
                height: r.s(72),
                decoration: BoxDecoration(
                  color: theme.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: theme.success, size: r.s(40)),
              ),
            ),
            SizedBox(height: r.s(20)),
            Text(
              s.reportSubmittedThankYou,
              style: TextStyle(
                fontSize: r.fs(18),
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.s(8)),
            Text(
              s.reportSubmittedThanks,
              style: TextStyle(fontSize: r.fs(14), color: theme.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(Responsive r, NexusThemeExtension theme, dynamic s) {
    final categories = _getCategories();
    final cat = _selected;

    return Padding(
      key: const ValueKey('form'),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + r.s(16),
        left: r.s(20),
        right: r.s(20),
        top: r.s(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: r.s(40),
              height: r.s(4),
              decoration: BoxDecoration(
                color: theme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: r.s(20)),
          Row(
            children: [
              Container(
                width: r.s(40),
                height: r.s(40),
                decoration: BoxDecoration(
                  color: theme.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.flag_rounded, color: theme.error, size: r.s(20)),
              ),
              SizedBox(width: r.s(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.reportContentTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(17),
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      s.selectReportReason,
                      style: TextStyle(fontSize: r.fs(12), color: theme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r.s(20)),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: r.s(10),
              mainAxisSpacing: r.s(10),
              childAspectRatio: 2.6,
            ),
            itemCount: categories.length,
            itemBuilder: (ctx, i) {
              final c = categories[i];
              final isSelected = _selectedId == c.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedId = c.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(10), vertical: r.s(8)),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? c.color.withValues(alpha: 0.15)
                        : theme.surfacePrimary,
                    borderRadius: BorderRadius.circular(r.s(12)),
                    border: Border.all(
                      color: isSelected
                          ? c.color.withValues(alpha: 0.6)
                          : theme.divider.withValues(alpha: 0.3),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(c.icon,
                          color: isSelected ? c.color : theme.textSecondary,
                          size: r.s(18)),
                      SizedBox(width: r.s(8)),
                      Expanded(
                        child: Text(
                          c.label,
                          style: TextStyle(
                            fontSize: r.fs(12),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? c.color : theme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (cat != null) ...[
            SizedBox(height: r.s(12)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.s(10)),
                border: Border.all(color: cat.color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: cat.color, size: r.s(16)),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Text(
                      cat.description,
                      style: TextStyle(
                          fontSize: r.fs(12), color: theme.textSecondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: r.s(14)),
          TextField(
            controller: _detailsController,
            maxLines: 3,
            maxLength: 500,
            style: TextStyle(fontSize: r.fs(13), color: theme.textPrimary),
            decoration: InputDecoration(
              hintText: cat?.requiresDetails == true
                  ? s.reportDetailsRequiredHint
                  : s.additionalDetailsHint,
              hintStyle: TextStyle(fontSize: r.fs(13), color: theme.textSecondary),
              filled: true,
              fillColor: theme.surfacePrimary,
              counterStyle: TextStyle(fontSize: r.fs(11), color: theme.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(12)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(12)),
                borderSide: BorderSide(color: theme.accentPrimary.withValues(alpha: 0.5)),
              ),
            ),
          ),
          SizedBox(height: r.s(14)),
          SizedBox(
            width: double.infinity,
            height: r.s(50),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedId != null
                    ? (_selected?.color ?? theme.error)
                    : theme.surfacePrimary,
                disabledBackgroundColor: theme.surfacePrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(14)),
                ),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: r.s(20),
                      height: r.s(20),
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flag_rounded, size: r.s(18), color: Colors.white),
                        SizedBox(width: r.s(8)),
                        Text(
                          s.submitReport,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: r.fs(15),
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          SizedBox(height: r.s(8)),
          Center(
            child: Text(
              s.reportResponsibleUse,
              style: TextStyle(fontSize: r.fs(11), color: theme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: r.s(8)),
        ],
      ),
    );
  }
}
