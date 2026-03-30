import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/utils/responsive.dart';

// =============================================================================
// TAB: Guidelines — Estilo Amino
// =============================================================================

class CommunityGuidelinesTab extends StatelessWidget {
  final CommunityModel community;

  const CommunityGuidelinesTab({super.key, required this.community});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return SingleChildScrollView(
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
                Text(
                  'Community Guidelines',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: r.fs(16),
                    fontWeight: FontWeight.w700,
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
    );
  }
}
