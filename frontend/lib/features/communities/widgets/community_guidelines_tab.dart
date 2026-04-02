import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/utils/responsive.dart';
import '../providers/community_detail_providers.dart';

// =============================================================================
// TAB: Guidelines — Estilo Amino
// Bug #3 fix: Adicionado RefreshIndicator para pull-to-refresh.
// =============================================================================

class CommunityGuidelinesTab extends ConsumerWidget {
  final CommunityModel community;

  const CommunityGuidelinesTab({super.key, required this.community});

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(communityDetailProvider(community.id));
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return RefreshIndicator(
      onRefresh: () => _onRefresh(ref),
      color: AppTheme.primaryColor,
      backgroundColor: context.surfaceColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(r.s(12)),
        child: Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(r.s(12)),
          ),
          padding: EdgeInsets.all(r.s(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.public_rounded,
                      color: Color(0xFFFF9800), size: r.s(18)),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Text(
                      'Diretrizes da Comunidade',
                      style: TextStyle(
                        color: context.textPrimary,
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
              Text(
                community.description.isNotEmpty
                    ? community.description
                    : 'Nenhuma diretriz foi definida para esta comunidade ainda.',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: r.fs(13),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
