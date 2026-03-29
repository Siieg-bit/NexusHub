import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/cosmetic_avatar.dart';

/// Tela de Seguidores / Seguindo — Lista de conexões sociais.
class FollowersScreen extends StatefulWidget {
  final String userId;
  final bool showFollowers; // true = seguidores, false = seguindo

  const FollowersScreen({
    super.key,
    required this.userId,
    this.showFollowers = true,
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen>
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
      initialIndex: widget.showFollowers ? 0 : 1,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Seguidores
      final followersRes = await SupabaseService.table('follows')
          .select(
              '*, profiles!follows_follower_id_fkey(id, nickname, icon_url, level)')
          .eq('following_id', widget.userId)
          .order('created_at', ascending: false);
      _followers = List<Map<String, dynamic>>.from(followersRes as List);

      // Seguindo
      final followingRes = await SupabaseService.table('follows')
          .select(
              '*, profiles!follows_following_id_fkey(id, nickname, icon_url, level)')
          .eq('follower_id', widget.userId)
          .order('created_at', ascending: false);
      _following = List<Map<String, dynamic>>.from(followingRes as List);

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
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: const Text(
          'Conexões',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: AppTheme.primaryColor,
          dividerColor: Colors.white.withValues(alpha: 0.05),
          tabs: [
            Tab(text: 'Seguidores (${_followers.length})'),
            Tab(text: 'Seguindo (${_following.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_followers, 'follows_follower_id_fkey'),
                _buildList(_following, 'follows_following_id_fkey'),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list, String profileKey) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma conexão',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = list[index];
        final profile = item['profiles'] as Map<String, dynamic>? ?? item;
        final userId = profile['id'] as String?;
        final nickname = profile['nickname'] as String? ?? 'Usuário';
        final avatarUrl = profile['icon_url'] as String?;
        final level = profile['level'] as int? ?? 1;

        return Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () {
              if (userId != null) context.push('/user/$userId');
            },
            leading: CosmeticAvatar(
              userId: userId,
              avatarUrl: avatarUrl,
              size: 48,
            ),
            title: Text(
              nickname,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            subtitle: Text(
              'Nível $level',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
            trailing: _FollowButton(targetUserId: userId ?? ''),
          ),
        );
      },
    );
  }
}

class _FollowButton extends StatefulWidget {
  final String targetUserId;
  const _FollowButton({required this.targetUserId});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
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
          .eq('follower_id', currentUserId)
          .eq('following_id', widget.targetUserId)
          .maybeSingle();

      _isFollowing = res != null;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    try {
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId == null) return;

      if (_isFollowing) {
        await SupabaseService.table('follows')
            .delete()
            .eq('follower_id', currentUserId)
            .eq('following_id', widget.targetUserId);
      } else {
        await SupabaseService.table('follows').insert({
          'follower_id': currentUserId,
          'following_id': widget.targetUserId,
        });
        // Adicionar reputação por seguir alguém (best-effort)
        try {
          await SupabaseService.rpc('add_reputation', params: {
            'p_community_id': null,
            'p_user_id': currentUserId,
            'p_action': 'follow',
            'p_source_id': widget.targetUserId,
          });
        } catch (_) {}
      }

      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e', style: TextStyle(color: context.textPrimary)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || widget.targetUserId == SupabaseService.currentUserId) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _toggleFollow,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: _isFollowing
              ? null
              : const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
          color: _isFollowing ? Colors.transparent : null,
          border: _isFollowing
              ? Border.all(color: Colors.white.withValues(alpha: 0.08))
              : null,
          boxShadow: _isFollowing
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          _isFollowing ? 'Seguindo' : 'Seguir',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _isFollowing ? Colors.grey[500] : context.textPrimary,
          ),
        ),
      ),
    );
  }
}
