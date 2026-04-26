import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ── Provider ──────────────────────────────────────────────────────────────────
final recentProfileVisitorsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final result = await SupabaseService.rpc(
    'get_recent_profile_visitors',
    params: {'p_limit': 20},
  );
  if (result == null) return [];
  return (result as List).map((e) => e as Map<String, dynamic>).toList();
});

// ── Widget ────────────────────────────────────────────────────────────────────

/// Seção "Visitantes Recentes" exibida no ProfileScreen apenas para o próprio perfil.
/// Mostra até 20 visitantes dos últimos 7 dias em um scroll horizontal.
class ProfileVisitorsSection extends ConsumerWidget {
  const ProfileVisitorsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final visitorsAsync = ref.watch(recentProfileVisitorsProvider);

    return visitorsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (visitors) {
        if (visitors.isEmpty) return const SizedBox.shrink();
        return _buildSection(context, r, visitors);
      },
    );
  }

  Widget _buildSection(
    BuildContext context,
    dynamic r,
    List<Map<String, dynamic>> visitors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), r.s(8)),
          child: Row(
            children: [
              Icon(Icons.visibility_rounded,
                  color: context.nexusTheme.accentPrimary, size: r.s(18)),
              SizedBox(width: r.s(6)),
              Text(
                'Visitantes Recentes',
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: r.s(6)),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(6), vertical: r.s(2)),
                decoration: BoxDecoration(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.s(8)),
                ),
                child: Text(
                  '${visitors.length}',
                  style: TextStyle(
                    color: context.nexusTheme.accentPrimary,
                    fontSize: r.fs(11),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: r.s(88),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: r.s(12)),
            itemCount: visitors.length,
            itemBuilder: (context, index) {
              final v = visitors[index];
              final userId = v['visitor_id'] as String?;
              final nickname = v['nickname'] as String? ?? 'Usuário';
              final iconUrl = v['icon_url'] as String?;
              final isVerified = v['is_verified'] as bool? ?? false;
              final visitedAt =
                  DateTime.tryParse(v['visited_at'] as String? ?? '');

              return GestureDetector(
                onTap: userId != null
                    ? () => context.push('/user/$userId')
                    : null,
                child: Container(
                  width: r.s(68),
                  margin: EdgeInsets.symmetric(horizontal: r.s(4)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          CosmeticAvatar(
                            userId: userId,
                            avatarUrl: iconUrl,
                            size: r.s(48),
                          ),
                          if (isVerified)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.all(r.s(1)),
                                decoration: BoxDecoration(
                                  color: context.nexusTheme.backgroundPrimary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.verified_rounded,
                                  color: context.nexusTheme.accentSecondary,
                                  size: r.s(12),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: r.s(4)),
                      Text(
                        nickname,
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontSize: r.fs(10),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      if (visitedAt != null)
                        Text(
                          timeago.format(visitedAt, locale: 'pt_BR'),
                          style: TextStyle(
                            color: context.nexusTheme.textSecondary,
                            fontSize: r.fs(9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Divider(
          color: Colors.white.withValues(alpha: 0.06),
          height: r.s(24),
          indent: r.s(16),
          endIndent: r.s(16),
        ),
      ],
    );
  }
}
