import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/responsive.dart';

// ── Provider ──────────────────────────────────────────────────────────────────
final memberTitleProvider = FutureProvider.family<Map<String, dynamic>?, ({String userId, String communityId})>(
  (ref, args) async {
    final result = await SupabaseService.rpc('get_member_title', params: {
      'p_user_id': args.userId,
      'p_community_id': args.communityId,
    });
    if (result == null) return null;
    final list = result as List;
    if (list.isEmpty) return null;
    return list.first as Map<String, dynamic>;
  },
);

// ── Widget ────────────────────────────────────────────────────────────────────

/// Badge de título de membro exibido abaixo do nome em posts e mensagens.
/// Exibe o emoji + nome do título com a cor definida pelo admin.
class MemberTitleBadge extends ConsumerWidget {
  final String userId;
  final String communityId;
  final double? fontSize;

  const MemberTitleBadge({
    super.key,
    required this.userId,
    required this.communityId,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final titleAsync = ref.watch(
      memberTitleProvider((userId: userId, communityId: communityId)),
    );

    return titleAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (title) {
        if (title == null) return const SizedBox.shrink();
        final name = title['title_name'] as String? ?? '';
        final emoji = title['title_emoji'] as String?;
        final colorHex = title['title_color'] as String? ?? '#6366F1';
        final color = _hexToColor(colorHex);

        return Container(
          margin: EdgeInsets.only(top: r.s(2)),
          padding: EdgeInsets.symmetric(
              horizontal: r.s(6), vertical: r.s(2)),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(r.s(6)),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            emoji != null ? '$emoji $name' : name,
            style: TextStyle(
              color: color,
              fontSize: fontSize ?? r.fs(10),
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }

  static Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }
}
