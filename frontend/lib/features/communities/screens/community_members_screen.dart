import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/amino_animations.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../config/nexus_theme_extension.dart';

// =============================================================================
// PROVIDER: Carrega todos os membros da comunidade
// =============================================================================
final allCommunityMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, communityId) async {
  final response = await SupabaseService.table('community_members')
      .select(
          '*, profiles!community_members_user_id_fkey(id, nickname, icon_url, online_status)')
      .eq('community_id', communityId)
      .order('joined_at', ascending: false);
  return List<Map<String, dynamic>>.from(response as List? ?? []);
});

// =============================================================================
// TELA: Membros da Comunidade
// Líderes e Curadores no topo, membros do mais recente ao mais antigo
// =============================================================================
class CommunityMembersScreen extends ConsumerWidget {
  final String communityId;

  const CommunityMembersScreen({super.key, required this.communityId});

  String _roleLabel(String role) {
    final s = getStrings();
    switch (role) {
      case 'agent':
        return 'Agent';
      case 'leader':
        return s.leader2;
      case 'curator':
        return s.curator2;
      case 'moderator':
        return 'Moderator';
      default:
        return '';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'agent':
        return context.nexusTheme.warning;
      case 'leader':
        return context.nexusTheme.error;
      case 'curator':
        return context.nexusTheme.accentSecondary;
      case 'moderator':
        return context.nexusTheme.accentPrimary;
      default:
        return Colors.transparent;
    }
  }

  int _rolePriority(String role) {
    switch (role) {
      case 'agent':
        return 0;
      case 'leader':
        return 1;
      case 'curator':
        return 2;
      case 'moderator':
        return 3;
      default:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final membersAsync = ref.watch(allCommunityMembersProvider(communityId));

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.nexusTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          s.members,
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(18),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: membersAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
              color: context.nexusTheme.accentPrimary, strokeWidth: 2.5),
        ),
        error: (error, _) => Center(
            child: Text(s.errorGeneric(error.toString()),
                style: TextStyle(color: context.nexusTheme.textSecondary))),
        data: (members) {
          if (members.isEmpty) {
            return Center(
              child: Text(s.noMembers,
                  style: TextStyle(color: context.nexusTheme.textSecondary)),
            );
          }

          // Separar staff (leaders, curators, agents, moderators) dos membros comuns
          final leaders = members
              .where((m) => m['role'] == 'agent' || m['role'] == 'leader')
              .toList();
          leaders.sort((a, b) => _rolePriority(a['role'] as String? ?? 'member')
              .compareTo(_rolePriority(b['role'] as String? ?? 'member')));

          final curators =
              members.where((m) => m['role'] == 'curator').toList();

          final moderators =
              members.where((m) => m['role'] == 'moderator').toList();

          final regular = members
              .where((m) =>
                  m['role'] != 'agent' &&
                  m['role'] != 'leader' &&
                  m['role'] != 'curator' &&
                  m['role'] != 'moderator')
              .toList();
          // regular já vem ordenado por joined_at desc do provider

          return RefreshIndicator(
            color: context.nexusTheme.accentPrimary,
            onRefresh: () async {
              ref.invalidate(allCommunityMembersProvider(communityId));
              await Future.delayed(const Duration(milliseconds: 300));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(r.s(12)),
              children: [
                // Total de membros
                Padding(
                  padding: EdgeInsets.only(bottom: r.s(16)),
                  child: Text(
                    '${members.length} membro${members.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Líderes
                if (leaders.isNotEmpty) ...[
                  _SectionHeader(
                    title: s.leadersTitle,
                    count: leaders.length,
                    color: context.nexusTheme.error,
                  ),
                  ...leaders.asMap().entries.map((entry) => _MemberTile(
                      index: entry.key,
                      member: entry.value,
                      roleLabel: _roleLabel,
                      roleColor: _roleColor,
                      communityId: communityId)),
                  SizedBox(height: r.s(16)),
                ],

                // Curadores
                if (curators.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'CURADORES',
                    count: curators.length,
                    color: context.nexusTheme.accentSecondary,
                  ),
                  ...curators.asMap().entries.map((entry) => _MemberTile(
                      index: entry.key,
                      member: entry.value,
                      roleLabel: _roleLabel,
                      roleColor: _roleColor,
                      communityId: communityId)),
                  SizedBox(height: r.s(16)),
                ],

                // Moderadores
                if (moderators.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'MODERADORES',
                    count: moderators.length,
                    color: context.nexusTheme.accentPrimary,
                  ),
                  ...moderators.asMap().entries.map((entry) => _MemberTile(
                      index: entry.key,
                      member: entry.value,
                      roleLabel: _roleLabel,
                      roleColor: _roleColor,
                      communityId: communityId)),
                  SizedBox(height: r.s(16)),
                ],

                // Membros comuns (mais recente ao mais antigo)
                _SectionHeader(
                  title: 'MEMBROS',
                  count: regular.length,
                  color: context.nexusTheme.textSecondary,
                ),
                ...regular.asMap().entries.map((entry) => _MemberTile(
                    index: entry.key,
                    member: entry.value,
                    roleLabel: _roleLabel,
                    roleColor: _roleColor,
                    communityId: communityId)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// SECTION HEADER
// =============================================================================
class _SectionHeader extends ConsumerWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(left: r.s(4), bottom: r.s(8), top: r.s(4)),
      child: Row(
        children: [
          Container(
            width: r.s(3),
            height: r.s(14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: r.s(8)),
          Flexible(
            child: Text(
              '$title ($count)',
              style: TextStyle(
                color: color,
                fontSize: r.fs(11),
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MEMBER TILE — Estilo Amino
// =============================================================================
class _MemberTile extends ConsumerWidget {
  final int index;
  final Map<String, dynamic> member;
  final String Function(String) roleLabel;
  final Color Function(String) roleColor;
  final String communityId;

  const _MemberTile({
    required this.index,
    required this.member,
    required this.roleLabel,
    required this.roleColor,
    required this.communityId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final profile = member['profiles'] as Map<String, dynamic>? ?? {};
    final userId = profile['id'] as String? ?? member['user_id'] as String?;
    final nickname = profile['nickname'] as String? ?? s.user;
    final avatarUrl = profile['icon_url'] as String?;
    final reputation = member['local_reputation'] as int? ?? 0;
    final level = member['local_level'] as int? ?? calculateLevel(reputation);
    final isOnline = (profile['online_status'] as int? ?? 2) == 1;
    final role = member['role'] as String? ?? 'member';

    return AminoAnimations.staggerItem(
      index: index,
      child: AminoAnimations.cardPress(
        onTap: () {
          if (userId != null) {
            context.push('/community/$communityId/profile/$userId');
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: r.s(8)),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: context.dividerClr.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Avatar com frame e indicador online
              CosmeticAvatar(
                userId: userId,
                avatarUrl: avatarUrl,
                size: r.s(44),
                showOnline: isOnline,
              ),
              SizedBox(width: r.s(12)),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(nickname,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: r.fs(14),
                                  color: context.nexusTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (role != 'member') ...[
                          SizedBox(width: r.s(6)),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(6), vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor(role).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(r.s(6)),
                            ),
                            child: Text(
                              roleLabel(role),
                              style: TextStyle(
                                color: roleColor(role),
                                fontSize: r.fs(9),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(s.levelLabel,
                        style: TextStyle(
                            color: AppTheme.getLevelColor(level),
                            fontSize: r.fs(11))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey[600], size: r.s(18)),
            ],
          ),
        ),
      ),
    );
  }
}
