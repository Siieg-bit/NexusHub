import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/community_model.dart';
import '../../../core/models/post_draft_model.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/providers/draft_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../communities/widgets/community_create_menu.dart';

class DraftsScreen extends ConsumerWidget {
  /// Quando fornecido, o FAB e os rascunhos sem comunidade usam este ID
  /// automaticamente, sem exibir o seletor de comunidade.
  final String? communityId;

  const DraftsScreen({super.key, this.communityId});

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
        actions: [
          draftsAsync.maybeWhen(
            data: (drafts) => drafts.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.delete_sweep_rounded,
                        color: context.nexusTheme.error, size: r.s(24)),
                    tooltip: 'Apagar todos os rascunhos',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: context.surfaceColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(r.s(16))),
                          title: Text(
                            'Apagar todos os rascunhos?',
                            style: TextStyle(
                                color: context.nexusTheme.textPrimary,
                                fontWeight: FontWeight.w700),
                          ),
                          content: Text(
                            'Todos os ${drafts.length} rascunhos serão apagados permanentemente. Esta ação não pode ser desfeita.',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: r.fs(14)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(s.cancel,
                                  style: TextStyle(color: Colors.grey[500])),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.nexusTheme.error,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(r.s(10))),
                              ),
                              child: const Text('Apagar todos',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        final ok = await ref
                            .read(postDraftsProvider.notifier)
                            .deleteAllDrafts();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Todos os rascunhos foram apagados.'
                                  : 'Erro ao apagar rascunhos.'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: ok
                                  ? context.nexusTheme.success
                                  : context.nexusTheme.error,
                            ),
                          );
                        }
                      }
                    },
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
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
            itemBuilder: (context, index) => _DraftCard(
                draft: drafts[index], defaultCommunityId: communityId),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (communityId != null) {
            // Já temos a comunidade — abre o menu de criação igual ao FAB principal
            final community = await ref
                .read(communityDetailProvider(communityId!).future)
                .catchError((_) => null);
            if (!context.mounted) return;
            showCommunityCreateMenu(
              context,
              communityId: communityId!,
              communityName: community?.name ?? '',
            );
          } else {
            // Sem comunidade — pede ao usuário para selecionar
            final cid = await _pickCommunity(context, ref);
            if (cid == null || !context.mounted) return;
            final community = await ref
                .read(communityDetailProvider(cid).future)
                .catchError((_) => null);
            if (!context.mounted) return;
            showCommunityCreateMenu(
              context,
              communityId: cid,
              communityName: community?.name ?? '',
            );
          }
        },
        backgroundColor: context.nexusTheme.accentPrimary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

/// Exibe um bottom sheet para o usuário selecionar a comunidade onde quer criar o post.
/// Retorna o id da comunidade selecionada ou null se cancelado.
Future<String?> _pickCommunity(BuildContext context, WidgetRef ref) async {
  final r = context.r;
  final communities = await ref.read(myCommunitiesProvider.future).catchError((_) => <CommunityModel>[]);

  if (!context.mounted) return null;

  if (communities.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Você precisa participar de uma comunidade para criar um post.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.nexusTheme.error,
      ),
    );
    return null;
  }

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: context.surfaceColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: r.s(12)),
          Container(
            width: r.s(40),
            height: r.s(4),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(r.s(2)),
            ),
          ),
          SizedBox(height: r.s(16)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(20)),
            child: Text(
              'Selecionar comunidade',
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: r.s(12)),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: r.s(320)),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(4)),
              itemCount: communities.length,
              itemBuilder: (_, i) {
                final c = communities[i];
                return ListTile(
                  leading: CircleAvatar(
                    radius: r.s(18),
                    backgroundImage: c.iconUrl != null ? NetworkImage(c.iconUrl!) : null,
                    backgroundColor: context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
                    child: c.iconUrl == null
                        ? Text(c.name[0].toUpperCase(),
                            style: TextStyle(
                              color: context.nexusTheme.accentPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: r.fs(14),
                            ))
                        : null,
                  ),
                  title: Text(
                    c.name,
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: r.fs(14),
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(12)),
                  ),
                  onTap: () => Navigator.pop(ctx, c.id),
                );
              },
            ),
          ),
          SizedBox(height: r.s(8)),
        ],
      ),
    ),
  );
}

String _draftRouteFor(String communityId, PostDraftModel draft) {
  final type = draft.effectiveEditorType;
  switch (type) {
    case 'blog':
      return '/community/$communityId/create-blog';
    case 'image':
      return '/community/$communityId/create-image';
    case 'link':
      return '/community/$communityId/create-link';
    case 'poll':
      return '/community/$communityId/create-poll';
    case 'quiz':
      return '/community/$communityId/create-quiz';
    case 'question':
    case 'qa':
      return '/community/$communityId/create-question';
    default:
      return '/community/$communityId/create-post';
  }
}

class _DraftCard extends ConsumerWidget {
  final PostDraftModel draft;
  /// communityId da tela atual — usado como fallback quando o rascunho não tem comunidade
  final String? defaultCommunityId;

  const _DraftCard({required this.draft, this.defaultCommunityId});

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
        onTap: () async {
          if (!context.mounted) return;
          // Prioridade: comunidade do rascunho > comunidade atual > seletor
          final cid = (draft.communityId?.isNotEmpty == true)
              ? draft.communityId!
              : (defaultCommunityId ?? await _pickCommunity(context, ref));
          if (cid == null || !context.mounted) return;
          context.push(
            _draftRouteFor(cid, draft),
            extra: {'draftId': draft.id, 'initialType': draft.effectiveEditorType},
          );
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
