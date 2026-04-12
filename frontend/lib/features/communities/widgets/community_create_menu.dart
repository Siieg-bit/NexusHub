import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// =============================================================================
// COMMUNITY CREATE MENU — Bottom sheet grid estilo Amino Apps
//
// Exibido ao tocar no botão "+" (FAB rosa) da barra inferior da comunidade.
// Cada item abre sua própria tela dedicada de criação.
// Itens: Story, Pergunta, Chat Público, Imagem, Link, Quiz, Enquete,
//        Entrada Wiki, Blog, Rascunhos.
// =============================================================================

/// Abre o menu de criação da comunidade como um bottom sheet.
void showCommunityCreateMenu(
  BuildContext context, {
  required String communityId,
  required String communityName,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CommunityCreateMenuSheet(
      communityId: communityId,
      communityName: communityName,
    ),
  );
}

// ─── Modelo de item ───────────────────────────────────────────────────────────
class _CreateItem {
  final String label;
  final IconData icon;
  final Color color;
  final void Function(BuildContext ctx) onTap;

  const _CreateItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

// ─── Sheet principal ──────────────────────────────────────────────────────────
class _CommunityCreateMenuSheet extends ConsumerWidget {
  final String communityId;
  final String communityName;

  const _CommunityCreateMenuSheet({
    required this.communityId,
    required this.communityName,
  });

  List<_CreateItem> _buildItems(AppStrings s) {
    final s = getStrings();
    return [
      _CreateItem(
        label: s.storyLabel,
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF7C3AED),
        onTap: (ctx) {
          Navigator.pop(ctx);
          ctx.push('/community/$communityId/create-story');
        },
      ),
      _CreateItem(
        label: s.question,
        icon: Icons.help_rounded,
        color: const Color(0xFFEA580C),
        onTap: (ctx) {
          Navigator.pop(ctx);
          ctx.push('/community/$communityId/create-question');
        },
      ),
      _CreateItem(
        label: s.chatPublicNewline,
        icon: Icons.chat_bubble_rounded,
        color: const Color(0xFF16A34A),
        onTap: (ctx) {
          Navigator.pop(ctx);
          ctx.push('/create-public-chat', extra: {
            'communityId': communityId,
            'communityName': communityName,
          });
        },
      ),
      _CreateItem(
        label: s.image,
        icon: Icons.image_rounded,
        color: const Color(0xFFE11D48),
        onTap: (ctx) {
          Navigator.pop(ctx);
          ctx.push('/community/$communityId/create-image');
        },
      ),
      _CreateItem(
        label: s.link,
        icon: Icons.link_rounded,
        color: const Color(0xFF2563EB),
        onTap: (ctx) {
          Navigator.pop(ctx);
          ctx.push('/community/$communityId/create-link');
        },
      ),
      _CreateItem(
        label: s.quiz,
        icon: Icons.checklist_rounded,
        color: const Color(0xFFDB2777),
        onTap: (ctx) {
          Navigator.pop(ctx);
          ctx.push('/community/$communityId/create-quiz');
        },
      ),
      _CreateItem(
        label: s.poll,
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFF0891B2),
        onTap: (ctx) {
          Navigator.pop(ctx);
          ctx.push('/community/$communityId/create-poll');
        },
      ),
      _CreateItem(
        label: s.wikiEntryNewline,
        icon: Icons.menu_book_rounded,
        color: const Color(0xFFD97706),
        onTap: (ctx) {
          Navigator.pop(ctx);
          ctx.push('/community/$communityId/wiki/create');
        },
      ),
      _CreateItem(
        label: s.blog,
        icon: Icons.article_rounded,
        color: const Color(0xFF0D9488),
        onTap: (ctx) {
          Navigator.pop(ctx);
          ctx.push('/community/$communityId/create-blog');
        },
      ),
      _CreateItem(
        label: s.drafts,
        icon: Icons.inbox_rounded,
        color: const Color(0xFF4338CA),
        onTap: (ctx) {
          Navigator.pop(ctx);
          ctx.push('/drafts');
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final items = _buildItems(s);

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: r.s(12), bottom: r.s(8)),
            width: r.s(36),
            height: r.s(4),
            decoration: BoxDecoration(
              color: context.dividerClr.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(r.s(2)),
            ),
          ),
          // Título
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: r.s(20), vertical: r.s(8)),
            child: Row(
              children: [
                Text(
                  s.create,
                  style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(18),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded,
                      color: context.nexusTheme.textPrimary.withValues(alpha: 0.5),
                      size: r.s(22)),
                ),
              ],
            ),
          ),
          // Grid de itens
          Padding(
            padding: EdgeInsets.fromLTRB(r.s(16), r.s(4), r.s(16), r.s(24)),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: r.s(16),
                crossAxisSpacing: r.s(8),
                childAspectRatio: 0.85,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, index) {
                final item = items[index];
                return _CreateItemTile(item: item, sheetContext: context);
              },
            ),
          ),
          // Safe area bottom
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ─── Tile individual ─────────────────────────────────────────────────────────
class _CreateItemTile extends ConsumerWidget {
  final _CreateItem item;

  /// Contexto do sheet (necessário para Navigator.pop e context.push)
  final BuildContext sheetContext;

  const _CreateItemTile({required this.item, required this.sheetContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return GestureDetector(
      onTap: () => item.onTap(sheetContext),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: r.s(56),
            height: r.s(56),
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: item.color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(item.icon, color: Colors.white, size: r.s(26)),
          ),
          SizedBox(height: r.s(6)),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(11),
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
