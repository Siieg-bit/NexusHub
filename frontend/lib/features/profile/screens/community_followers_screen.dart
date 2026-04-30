// =============================================================================
// CommunityFollowersScreen
// Tela de Conexões contextual para comunidades.
// Exibe local_nickname e local_icon_url de cada conexão dentro da comunidade,
// e navega para o perfil de comunidade (/community/:communityId/profile/:userId)
// em vez do perfil global.
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/call_service.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../providers/profile_providers.dart';

/// Tela de Conexões dentro do contexto de uma comunidade.
/// Usa local_nickname e local_icon_url dos membros da comunidade.
class CommunityFollowersScreen extends ConsumerStatefulWidget {
  final String userId;
  final String communityId;
  final bool showFollowers; // true = seguidores, false = seguindo

  const CommunityFollowersScreen({
    super.key,
    required this.userId,
    required this.communityId,
    this.showFollowers = true,
  });

  @override
  ConsumerState<CommunityFollowersScreen> createState() =>
      _CommunityFollowersScreenState();
}

class _CommunityFollowersScreenState
    extends ConsumerState<CommunityFollowersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.showFollowers ? 1 : 0,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Seguidores — busca perfil global + perfil de comunidade
      final followersRes = await SupabaseService.table('follows')
          .select('*, profiles!follows_follower_id_fkey(id, nickname, icon_url, level)')
          .eq('community_id', widget.communityId)
          .eq('following_id', widget.userId)
          .order('created_at', ascending: false);
      final followersList =
          List<Map<String, dynamic>>.from(followersRes as List? ?? []);

      // Seguindo — busca perfil global + perfil de comunidade
      final followingRes = await SupabaseService.table('follows')
          .select('*, profiles!follows_following_id_fkey(id, nickname, icon_url, level)')
          .eq('community_id', widget.communityId)
          .eq('follower_id', widget.userId)
          .order('created_at', ascending: false);
      final followingList =
          List<Map<String, dynamic>>.from(followingRes as List? ?? []);

      // Enriquecer com perfis de comunidade
      final allUserIds = <String>{};
      for (final f in followersList) {
        final p = f['profiles'] as Map<String, dynamic>?;
        if (p?['id'] != null) allUserIds.add(p!['id'] as String);
      }
      for (final f in followingList) {
        final p = f['profiles'] as Map<String, dynamic>?;
        if (p?['id'] != null) allUserIds.add(p!['id'] as String);
      }

      Map<String, Map<String, dynamic>> communityProfiles = {};
      if (allUserIds.isNotEmpty) {
        try {
          final cmRes = await SupabaseService.table('community_members')
              .select('user_id, local_nickname, local_icon_url')
              .eq('community_id', widget.communityId)
              .inFilter('user_id', allUserIds.toList());
          for (final cm in (cmRes as List? ?? [])) {
            final uid = cm['user_id'] as String?;
            if (uid != null) {
              communityProfiles[uid] = Map<String, dynamic>.from(cm);
            }
          }
        } catch (_) {}
      }

      // Mesclar perfil de comunidade nos resultados
      void mergeProfile(Map<String, dynamic> item, String profileKey) {
        final profile = item[profileKey] as Map<String, dynamic>?;
        if (profile == null) return;
        final uid = profile['id'] as String?;
        if (uid == null) return;
        final cm = communityProfiles[uid];
        if (cm != null) {
          if (cm['local_nickname'] != null) {
            profile['nickname'] = cm['local_nickname'];
          }
          if (cm['local_icon_url'] != null) {
            profile['icon_url'] = cm['local_icon_url'];
          }
        }
      }

      for (final f in followersList) {
        mergeProfile(f, 'profiles');
      }
      for (final f in followingList) {
        mergeProfile(f, 'profiles');
      }

      if (!mounted) return;
      setState(() {
        _followers = followersList;
        _following = followingList;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        title: Text(
          s.connections,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.nexusTheme.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.nexusTheme.accentPrimary,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: context.nexusTheme.accentPrimary,
          dividerColor: Colors.white.withValues(alpha: 0.05),
          tabs: [
            Tab(text: 'Seguindo (${_following.length})'),
            Tab(text: 'Seguidores (${_followers.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: context.nexusTheme.accentPrimary,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_following),
                _buildList(_followers),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list) {
    final s = getStrings();
    final r = context.r;
    if (list.isEmpty) {
      return Center(
        child: Text(
          s.noConnections,
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return RefreshIndicator(
      color: context.nexusTheme.accentPrimary,
      onRefresh: () async {
        await _loadData();
        if (!mounted) return;
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(r.s(16)),
        itemCount: list.length,
        separatorBuilder: (context, index) => SizedBox(height: r.s(12)),
        itemBuilder: (context, index) {
          final item = list[index];
          final profile = item['profiles'] as Map<String, dynamic>? ?? item;
          final userId = profile['id'] as String?;
          final nickname = profile['nickname'] as String? ?? s.user;
          final avatarUrl = profile['icon_url'] as String?;

          return Container(
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(r.s(16)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: ListTile(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              onTap: () {
                if (!mounted || userId == null) return;
                // Navega para o perfil DENTRO da comunidade
                context.push(
                    '/community/${widget.communityId}/profile/$userId');
              },
              leading: userId != null
                  ? _CommunityAvatarWithIndicators(
                      userId: userId,
                      avatarUrl: avatarUrl,
                      size: r.s(48),
                      communityId: widget.communityId,
                    )
                  : CosmeticAvatar(
                      userId: userId,
                      avatarUrl: avatarUrl,
                      size: r.s(48),
                    ),
              title: Text(
                nickname,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.nexusTheme.textPrimary,
                ),
              ),
              subtitle: Text(
                s.levelLabel,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Widget auxiliar que combina CosmeticAvatar com indicadores de story e call
/// para a lista de seguidores/seguindo dentro de uma comunidade.
class _CommunityAvatarWithIndicators extends ConsumerWidget {
  final String userId;
  final String? avatarUrl;
  final double size;
  final String communityId;

  const _CommunityAvatarWithIndicators({
    required this.userId,
    required this.avatarUrl,
    required this.size,
    required this.communityId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasActiveStory =
        ref.watch(userHasActiveStoryProvider(userId)).valueOrNull == true;
    final activeCallData =
        ref.watch(userActiveCallProvider(userId)).valueOrNull;
    final hasActiveCall = activeCallData != null;
    final isScreeningRoom = hasActiveCall &&
        (activeCallData?['type'] as String? ?? '') == 'screening_room';
    final hasCanonicalWiki =
        ref.watch(userHasCanonicalWikiProvider(userId)).valueOrNull == true;

    return CosmeticAvatar(
      userId: userId,
      avatarUrl: avatarUrl,
      size: size,
      hasActiveStory: hasActiveStory,
      hasActiveCall: hasActiveCall,
      isScreeningRoom: isScreeningRoom,
      hasCanonicalWiki: hasCanonicalWiki,
      onTap: hasActiveCall && activeCallData != null
          ? () {
              final threadId = activeCallData['thread_id'] as String? ?? '';
              final sessionId = activeCallData['id'] as String? ?? '';
              if (threadId.isNotEmpty) {
                if (isScreeningRoom) {
                  context.push('/screening-room/$threadId?sessionId=$sessionId');
                } else {
                  CallService.joinCallSession(sessionId).then((session) {
                    if (session != null && context.mounted) {
                      context.push('/call/${session.id}', extra: session);
                    }
                  });
                }
              }
            }
          : null,
    );
  }
}
