import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final featuredMembersProvider = FutureProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>((ref, communityId) async {
  final res = await SupabaseService.rpc(
    'get_featured_members',
    params: {'p_community_id': communityId},
  );
  return (res as List).cast<Map<String, dynamic>>();
});

// ─── Widget ───────────────────────────────────────────────────────────────────

class FeaturedMembersSection extends ConsumerWidget {
  final String communityId;
  final bool isStaff;

  const FeaturedMembersSection({
    super.key,
    required this.communityId,
    this.isStaff = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;
    final membersAsync = ref.watch(featuredMembersProvider(communityId));

    return membersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (members) {
        if (members.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), r.s(8)),
              child: Row(
                children: [
                  Icon(Icons.star_rounded,
                      color: theme.accentPrimary, size: r.s(18)),
                  SizedBox(width: r.s(6)),
                  Text(
                    'Membros em Destaque',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (isStaff)
                    GestureDetector(
                      onTap: () => _showManageDialog(context, ref),
                      child: Text(
                        'Gerenciar',
                        style: TextStyle(
                          color: theme.accentPrimary,
                          fontSize: r.fs(12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
                height: r.s(110),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: r.s(12)),
                  itemCount: members.length,
                  itemBuilder: (_, i) {
                    final m = members[i];
                    final name = m['display_name'] as String? ??
                        m['username'] as String? ??
                        'Usuário';
                    final avatar = m['avatar_url'] as String?;
                    final level = m['level'] as int? ?? 1;
                    final userId = m['user_id'] as String? ?? '';

                    return GestureDetector(
                      onTap: () =>
                          context.push('/community/$communityId/user/$userId'),
                      child: Container(
                        width: r.s(80),
                        margin: EdgeInsets.symmetric(horizontal: r.s(4)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: r.s(28),
                                  backgroundColor:
                                      theme.accentPrimary.withValues(alpha: 0.3),
                                  backgroundImage: avatar != null
                                      ? CachedNetworkImageProvider(avatar)
                                      : null,
                                  child: avatar == null
                                      ? Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                              color: theme.textPrimary,
                                              fontSize: r.fs(18),
                                              fontWeight: FontWeight.w700),
                                        )
                                      : null,
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(4), vertical: r.s(1)),
                                  decoration: BoxDecoration(
                                    color: theme.accentPrimary,
                                    borderRadius:
                                        BorderRadius.circular(r.s(8)),
                                  ),
                                  child: Text(
                                    'Lv.$level',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: r.fs(8),
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: r.s(6)),
                            Text(
                              name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: r.fs(11),
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            Divider(
              color: theme.divider,
              height: r.s(24),
              indent: r.s(16),
              endIndent: r.s(16),
            ),
          ],
        );
      },
    );
  }

  void _showManageDialog(BuildContext context, WidgetRef ref) async {
    final r = context.r;
    final theme = context.nexusTheme;

    // Carregar membros da comunidade
    List<Map<String, dynamic>> allMembers = [];
    Set<String> featuredIds = {};

    try {
      final res = await SupabaseService.table('community_members')
          .select(
              'user_id, role, profiles(id, nickname, icon_url)')
          .eq('community_id', communityId)
          .eq('status', 'active')
          .order('role');
      allMembers = (res as List).cast<Map<String, dynamic>>();

      final featured = await SupabaseService.rpc(
        'get_featured_members',
        params: {'p_community_id': communityId},
      );
      featuredIds = (featured as List)
          .map((m) => m['user_id'] as String)
          .toSet();
    } catch (_) {}

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              SizedBox(height: r.s(8)),
              Container(
                width: r.s(40),
                height: r.s(4),
                decoration: BoxDecoration(
                  color: theme.divider,
                  borderRadius: BorderRadius.circular(r.s(2)),
                ),
              ),
              SizedBox(height: r.s(12)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                child: Row(
                  children: [
                    Icon(Icons.star_rounded,
                        color: theme.accentPrimary, size: r.s(20)),
                    SizedBox(width: r.s(8)),
                    Text(
                      'Gerenciar Membros em Destaque',
                      style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: r.fs(15),
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(16), vertical: r.s(4)),
                child: Text(
                  '${featuredIds.length}/10 membros em destaque',
                  style: TextStyle(
                      color: theme.textSecondary, fontSize: r.fs(12)),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: EdgeInsets.symmetric(horizontal: r.s(8)),
                  itemCount: allMembers.length,
                  itemBuilder: (_, i) {
                    final profile = allMembers[i]['profiles']
                        as Map<String, dynamic>?;
                    final uid = profile?['id'] as String? ?? '';
                    final name =
                        profile?['nickname'] as String? ?? 'Usuário';
                    final avatar = profile?['icon_url'] as String?;
                    final role =
                        allMembers[i]['role'] as String? ?? 'member';
                    final isFeatured = featuredIds.contains(uid);

                    return ListTile(
                      leading: CircleAvatar(
                        radius: r.s(20),
                        backgroundImage: avatar != null
                            ? CachedNetworkImageProvider(avatar)
                            : null,
                        backgroundColor:
                            theme.accentPrimary.withValues(alpha: 0.3),
                        child: avatar == null
                            ? Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: r.fs(14)))
                            : null,
                      ),
                      title: Text(name,
                          style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: r.fs(13))),
                      subtitle: Text(role,
                          style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: r.fs(11))),
                      trailing: isFeatured
                          ? Icon(Icons.star_rounded,
                              color: theme.accentPrimary, size: r.s(22))
                          : Icon(Icons.star_border_rounded,
                              color: theme.textHint, size: r.s(22)),
                      onTap: () async {
                        try {
                          await SupabaseService.rpc(
                            'toggle_featured_member',
                            params: {
                              'p_community_id': communityId,
                              'p_target_user_id': uid,
                            },
                          );
                          setSheetState(() {
                            if (isFeatured) {
                              featuredIds.remove(uid);
                            } else {
                              featuredIds.add(uid);
                            }
                          });
                          ref.invalidate(featuredMembersProvider(communityId));
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Erro: ${e.toString()}'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: theme.error,
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
