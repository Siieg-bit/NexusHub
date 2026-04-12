import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/post_draft_model.dart';
import '../../../core/providers/draft_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../config/nexus_theme_extension.dart';

class DraftsScreen extends ConsumerWidget {
  const DraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final draftsAsync = ref.watch(postDraftsProvider);

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back, color: context.nexusTheme.textPrimary, size: r.s(22)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          s.drafts,
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: r.fs(18),
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: draftsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.grey[600], size: r.s(48)),
              SizedBox(height: r.s(12)),
              Text(
                'Erro ao carregar rascunhos',
                style: TextStyle(color: Colors.grey[500], fontSize: r.fs(14)),
              ),
              SizedBox(height: r.s(16)),
              ElevatedButton(
                onPressed: () =>
                    ref.read(postDraftsProvider.notifier).refresh(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.nexusTheme.accentPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(10))),
                ),
                child: Text(s.retry,
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        data: (drafts) {
          if (drafts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.drafts_outlined,
                      color: Colors.grey[700], size: r.s(64)),
                  SizedBox(height: r.s(16)),
                  Text(
                    'Nenhum rascunho',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: r.fs(16),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: r.s(8)),
                  Text(
                    s.postDraftsAppearHere,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: r.fs(13),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(r.s(16)),
            itemCount: drafts.length,
            itemBuilder: (context, index) => _DraftCard(draft: drafts[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final draft = await ref
              .read(postDraftsProvider.notifier)
              .createDraft(title: '', content: '');
          if (draft != null && context.mounted) {
            final cid = draft.communityId ?? 'global';
            context.push('/community/$cid/create-post', extra: {'draftId': draft.id});
          }
        },
        backgroundColor: context.nexusTheme.accentPrimary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _DraftCard extends ConsumerWidget {
  final PostDraftModel draft;

  const _DraftCard({required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(draft.updatedAt);

    return Dismissible(
      key: Key(draft.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: r.s(20)),
        margin: EdgeInsets.only(bottom: r.s(12)),
        decoration: BoxDecoration(
          color: context.nexusTheme.error,
          borderRadius: BorderRadius.circular(r.s(14)),
        ),
        child: Icon(Icons.delete_rounded, color: Colors.white, size: r.s(24)),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.surfaceColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(16))),
            title: Text(s.deleteDraftQuestion,
                style: TextStyle(
                    color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w700)),
            content: Text(s.actionCannotBeUndone,
                style: TextStyle(color: Colors.grey[400], fontSize: r.fs(14))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child:
                    Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.nexusTheme.error,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(10))),
                ),
                child: Text(s.delete,
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(postDraftsProvider.notifier).deleteDraft(draft.id);
      },
      child: GestureDetector(
        onTap: () {
          if (!context.mounted) return;
          final cid = draft.communityId ?? 'global';
          context.push('/community/$cid/create-post', extra: {'draftId': draft.id});
        },
        child: Container(
          margin: EdgeInsets.only(bottom: r.s(12)),
          padding: EdgeInsets.all(r.s(16)),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(14)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _typeIcon(draft.postType, r),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Text(
                      draft.preview,
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(15),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.grey[600], size: r.s(20)),
                ],
              ),
              SizedBox(height: r.s(8)),
              Row(
                children: [
                  Icon(Icons.access_time_rounded,
                      color: Colors.grey[600], size: r.s(14)),
                  SizedBox(width: r.s(4)),
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: r.fs(12),
                    ),
                  ),
                  if (draft.communityId != null) ...[
                    SizedBox(width: r.s(12)),
                    Icon(Icons.group_rounded,
                        color: Colors.grey[600], size: r.s(14)),
                    SizedBox(width: r.s(4)),
                    Text(
                      s.community,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: r.fs(12),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeIcon(String postType, Responsive r) {
    IconData icon;
    Color color;
    switch (postType) {
      case 'image':
        icon = Icons.image_rounded;
        color = Colors.blue;
        break;
      case 'blog':
        icon = Icons.article_rounded;
        color = Colors.purple;
        break;
      case 'poll':
        icon = Icons.poll_rounded;
        color = Colors.orange;
        break;
      case 'quiz':
        icon = Icons.quiz_rounded;
        color = Colors.teal;
        break;
      case 'link':
        icon = Icons.link_rounded;
        color = Colors.cyan;
        break;
      default:
        icon = Icons.text_fields_rounded;
        color = Colors.grey;
    }
    return Container(
      padding: EdgeInsets.all(r.s(6)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(r.s(8)),
      ),
      child: Icon(icon, color: color, size: r.s(16)),
    );
  }
}
