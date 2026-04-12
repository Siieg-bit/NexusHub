import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../providers/community_detail_providers.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';
// =============================================================================
// TAB: Guidelines — Estilo Amino
// Busca as regras da tabela guidelines no banco de dados.
// =============================================================================
class CommunityGuidelinesTab extends ConsumerWidget {
  final String communityId;
  const CommunityGuidelinesTab({super.key, required this.communityId});
  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(guidelinesProvider(communityId));
    await Future.delayed(const Duration(milliseconds: 500));
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final guidelinesAsync = ref.watch(guidelinesProvider(communityId));
    return RefreshIndicator(
      onRefresh: () => _onRefresh(ref),
      color: context.nexusTheme.accentPrimary,
      backgroundColor: context.surfaceColor,
      child: guidelinesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
              color: context.nexusTheme.accentPrimary, strokeWidth: 2.5),
        ),
        error: (e, _) => Center(
          child: Text(s.errorGeneric(e.toString()),
              style: TextStyle(color: context.nexusTheme.textSecondary)),
        ),
        data: (guidelines) {
          final title = guidelines?['title'] as String? ?? s.guidelines;
          final content = guidelines?['content'] as String? ?? '';
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(r.s(12)),
            child: Container(
              decoration: BoxDecoration(
                color: context.nexusTheme.surfacePrimary,
                borderRadius: BorderRadius.circular(r.s(12)),
              ),
              padding: EdgeInsets.all(r.s(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.public_rounded,
                          color: const Color(0xFFFF9800), size: r.s(18)),
                      SizedBox(width: r.s(8)),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: context.nexusTheme.textPrimary,
                            fontSize: r.fs(16),
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.s(16)),
                  if (content.isEmpty)
                    Text(
                      s.noGuidelinesYet,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: r.fs(13),
                        height: 1.6,
                      ),
                    )
                  else
                    Text(
                      content,
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: r.fs(13),
                        height: 1.6,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
