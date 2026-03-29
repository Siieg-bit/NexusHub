import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/amino_animations.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/cosmetic_avatar.dart';

// =============================================================================
// PROVIDER: Carrega todos os membros da comunidade
// =============================================================================
final allCommunityMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, communityId) async {
  final response = await SupabaseService.table('community_members')
      .select(
          '*, profiles!community_members_user_id_fkey(id, nickname, icon_url, level, online_status)')
      .eq('community_id', communityId)
      .order('joined_at', ascending: false);
  return List<Map<String, dynamic>>.from(response as List);
});

// =============================================================================
// TELA: Membros da Comunidade
// Líderes e Curadores no topo, membros do mais recente ao mais antigo
// =============================================================================
class CommunityMembersScreen extends ConsumerWidget {
  final String communityId;

  const CommunityMembersScreen({super.key, required this.communityId});

  String _roleLabel(String role) {
    switch (role) {
      case 'agent':
        return 'Agent';
      case 'leader':
        return 'Leader';
      case 'curator':
        return 'Curator';
      case 'moderator':
        return 'Moderator';
      default:
        return '';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'agent':
        return AppTheme.warningColor;
      case 'leader':
        return AppTheme.errorColor;
      case 'curator':
        return AppTheme.accentColor;
      case 'moderator':
        return AppTheme.primaryColor;
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
    final membersAsync = ref.watch(allCommunityMembersProvider(communityId));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Membros',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: membersAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
              color: AppTheme.primaryColor, strokeWidth: 2.5),
        ),
        error: (error, _) => Center(
            child: Text('Erro: $error',
                style: TextStyle(color: context.textSecondary))),
        data: (members) {
          if (members.isEmpty) {
            return const Center(
              child: Text('Nenhum membro',
                  style: TextStyle(color: context.textSecondary)),
            );
          }

          // Separar staff (leaders, curators, agents, moderators) dos membros comuns
          final leaders = members
              .where((m) => m['role'] == 'agent' || m['role'] == 'leader')
              .toList();
          leaders.sort((a, b) =>
              _rolePriority(a['role'] as String? ?? 'member')
                  .compareTo(_rolePriority(b['role'] as String? ?? 'member')));

          final curators = members
              .where((m) => m['role'] == 'curator')
              .toList();

          final moderators = members
              .where((m) => m['role'] == 'moderator')
              .toList();

          final regular = members
              .where((m) =>
                  m['role'] != 'agent' &&
                  m['role'] != 'leader' &&
                  m['role'] != 'curator' &&
                  m['role'] != 'moderator')
              .toList();
          // regular já vem ordenado por joined_at desc do provider

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Total de membros
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '${members.length} membro${members.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Líderes
              if (leaders.isNotEmpty) ...[
                _SectionHeader(
                  title: 'LÍDERES',
                  count: leaders.length,
                  color: AppTheme.errorColor,
                ),
                ...leaders.asMap().entries.map((entry) => _MemberTile(
                    index: entry.key,
                    member: entry.value,
                    roleLabel: _roleLabel,
                    roleColor: _roleColor,
                    communityId: communityId)),
                const SizedBox(height: 16),
              ],

              // Curadores
              if (curators.isNotEmpty) ...[
                _SectionHeader(
                  title: 'CURADORES',
                  count: curators.length,
                  color: AppTheme.accentColor,
                ),
                ...curators.asMap().entries.map((entry) => _MemberTile(
                    index: entry.key,
                    member: entry.value,
                    roleLabel: _roleLabel,
                    roleColor: _roleColor,
                    communityId: communityId)),
                const SizedBox(height: 16),
              ],

              // Moderadores
              if (moderators.isNotEmpty) ...[
                _SectionHeader(
                  title: 'MODERADORES',
                  count: moderators.length,
                  color: AppTheme.primaryColor,
                ),
                ...moderators.asMap().entries.map((entry) => _MemberTile(
                    index: entry.key,
                    member: entry.value,
                    roleLabel: _roleLabel,
                    roleColor: _roleColor,
                    communityId: communityId)),
                const SizedBox(height: 16),
              ],

              // Membros comuns (mais recente ao mais antigo)
              _SectionHeader(
                title: 'MEMBROS',
                count: regular.length,
                color: context.textSecondary,
              ),
              ...regular.asMap().entries.map((entry) => _MemberTile(
                  index: entry.key,
                  member: entry.value,
                  roleLabel: _roleLabel,
                  roleColor: _roleColor,
                  communityId: communityId)),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// SECTION HEADER
// =============================================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
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
class _MemberTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final profile = member['profiles'] as Map<String, dynamic>? ?? {};
    final userId = profile['id'] as String? ?? member['user_id'] as String?;
    final nickname = profile['nickname'] as String? ?? 'Usuário';
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
          padding: const EdgeInsets.symmetric(vertical: 8),
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
                size: 44,
                showOnline: isOnline,
              ),
              const SizedBox(width: 12),
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
                                  fontSize: 14,
                                  color: context.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (role != 'member') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor(role).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              roleLabel(role),
                              style: TextStyle(
                                color: roleColor(role),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Lv.$level ${levelTitle(level)}',
                        style: TextStyle(
                            color: AppTheme.getLevelColor(level), fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey[600], size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
