import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

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
      appBar: AppBar(
        title: const Text('Conexões',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: [
            Tab(text: 'Seguidores (${_followers.length})'),
            Tab(text: 'Seguindo (${_following.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
      return const Center(
        child: Text('Nenhuma conexão',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final profile = item['profiles'] as Map<String, dynamic>? ?? item;
        final userId = profile['id'] as String?;
        final nickname = profile['nickname'] as String? ?? 'Usuário';
        final avatarUrl = profile['icon_url'] as String?;
        final level = profile['level'] as int? ?? 1;

        return ListTile(
          onTap: () {
            if (userId != null) context.push('/user/$userId');
          },
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
            backgroundImage: avatarUrl != null
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: avatarUrl == null
                ? Text(nickname[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold))
                : null,
          ),
          title: Text(nickname,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('Nível $level',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          trailing: _FollowButton(targetUserId: userId ?? ''),
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
      }

      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || widget.targetUserId == SupabaseService.currentUserId) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: _toggleFollow,
        style: OutlinedButton.styleFrom(
          backgroundColor:
              _isFollowing ? Colors.transparent : AppTheme.primaryColor,
          foregroundColor: _isFollowing ? AppTheme.textSecondary : Colors.white,
          side: BorderSide(
            color: _isFollowing ? AppTheme.dividerColor : AppTheme.primaryColor,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          _isFollowing ? 'Seguindo' : 'Seguir',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
