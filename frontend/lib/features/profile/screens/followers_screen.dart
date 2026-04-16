import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Tela de Seguidores / Seguindo — Lista de conexões sociais.
class FollowersScreen extends ConsumerStatefulWidget {
  final String userId;
  final bool showFollowers; // true = seguidores, false = seguindo

  const FollowersScreen({
    super.key,
    required this.userId,
    this.showFollowers = true,
  });

  @override
  ConsumerState<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends ConsumerState<FollowersScreen>
    with SingleTickerProviderStateMixin {
  static const String _globalCommunityId =
      '00000000-0000-0000-0000-000000000000';
  late TabController _tabController;
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Bug #9 fix: A ordem anterior era [Seguidores(0), Seguindo(1)] mas o
    // profile_screen exibe os cards na ordem [Following | Followers]. Ao clicar
    // em 'Following' (esquerda), a tela abria na tab direita (index=1), criando
    // inconsistência visual. A correção inverte as tabs para [Seguindo(0), Seguidores(1)]
    // e ajusta o initialIndex: showFollowers=true → index=1, false → index=0.
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.showFollowers ? 1 : 0,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Seguidores
      final followersRes = await SupabaseService.table('follows')
          .select(
              '*, profiles!follows_follower_id_fkey(id, nickname, icon_url, level)')
          .eq('community_id', _globalCommunityId)
          .eq('following_id', widget.userId)
          .order('created_at', ascending: false);
      _followers = List<Map<String, dynamic>>.from(followersRes as List? ?? []);

      // Seguindo
      final followingRes = await SupabaseService.table('follows')
          .select(
              '*, profiles!follows_following_id_fkey(id, nickname, icon_url, level)')
          .eq('community_id', _globalCommunityId)
          .eq('follower_id', widget.userId)
          .order('created_at', ascending: false);
      _following = List<Map<String, dynamic>>.from(followingRes as List? ?? []);

      if (!mounted) return;
      if (mounted) setState(() => _isLoading = false);
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
                _buildList(_following, 'follows_following_id_fkey'),
                _buildList(_followers, 'follows_follower_id_fkey'),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list, String profileKey) {
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
                if (!mounted) return;
                if (userId != null) context.push('/user/$userId');
              },
              leading: CosmeticAvatar(
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
                ),
              ),
              trailing: _FollowButton(targetUserId: userId ?? ''),
            ),
          );
        },
      ),
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  final String targetUserId;
  const _FollowButton({required this.targetUserId});

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  static const String _globalCommunityId =
      '00000000-0000-0000-0000-000000000000';
  bool _isFollowing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFollowing();
  }

  Future<void> _checkFollowing() async {
    try {
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId == null || currentUserId == widget.targetUserId) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final res = await SupabaseService.table('follows')
          .select('id')
          .eq('community_id', _globalCommunityId)
          .eq('follower_id', currentUserId)
          .eq('following_id', widget.targetUserId)
          .maybeSingle();
      if (!mounted) return;

      _isFollowing = res != null;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final s = getStrings();
    try {
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId == null) return;

      // RPC atômica: toggle follow + reputação + contadores
      // Nota: followers_screen não tem communityId, usamos UUID nulo
      // A RPC toggle_follow_with_reputation aceita p_community_id
      final result = await SupabaseService.rpc(
        'toggle_follow_with_reputation',
        params: {
          'p_community_id': _globalCommunityId,
          'p_follower_id': currentUserId,
          'p_following_id': widget.targetUserId,
        },
      );
      if (mounted) {
        final isNowFollowing =
            result is Map ? (result['following'] == true) : !_isFollowing;
        setState(() => _isFollowing = isNowFollowing);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.anErrorOccurredTryAgain,
                style: TextStyle(color: context.nexusTheme.textPrimary)),
            backgroundColor: context.nexusTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    if (_isLoading || widget.targetUserId == SupabaseService.currentUserId) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _toggleFollow,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r.s(20)),
          gradient: _isFollowing
              ? null
              : LinearGradient(
                  colors: [context.nexusTheme.accentPrimary, context.nexusTheme.accentSecondary],
                ),
          color: _isFollowing ? Colors.transparent : null,
          border: _isFollowing
              ? Border.all(color: Colors.white.withValues(alpha: 0.08))
              : null,
          boxShadow: _isFollowing
              ? null
              : [
                  BoxShadow(
                    color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          _isFollowing ? s.following : s.follow,
          style: TextStyle(
            fontSize: r.fs(12),
            fontWeight: FontWeight.w700,
            color: _isFollowing ? Colors.grey[500] : context.nexusTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
