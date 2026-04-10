import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../feed/widgets/post_card.dart';
import '../providers/profile_providers.dart';

class ProfileBlogsTab extends ConsumerWidget {
  final String userId;
  final bool isOwnProfile;

  const ProfileBlogsTab({
    super.key,
    required this.userId,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final blogsAsync = ref.watch(userBlogsProvider(userId));
    final pinnedBlogAsync = ref.watch(pinnedProfileBlogProvider(userId));

    return blogsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
          strokeWidth: 2,
        ),
      ),
      error: (_, __) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(r.s(24)),
        children: [
          SizedBox(height: r.screenHeight * 0.08),
          Icon(Icons.article_outlined, color: Colors.grey[600], size: r.s(44)),
          SizedBox(height: r.s(12)),
          Text(
            'Não foi possível carregar os blogs deste perfil.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: r.fs(14)),
          ),
          SizedBox(height: r.s(14)),
          Align(
            child: TextButton.icon(
              onPressed: () {
                ref.invalidate(userBlogsProvider(userId));
                ref.invalidate(pinnedProfileBlogProvider(userId));
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(s.retry),
            ),
          ),
        ],
      ),
      data: (blogs) {
        return pinnedBlogAsync.when(
          loading: () => _buildBlogList(
            context,
            ref,
            blogs: blogs,
            pinnedBlog: null,
            loadingPinnedState: true,
          ),
          error: (_, __) => _buildBlogList(
            context,
            ref,
            blogs: blogs,
            pinnedBlog: null,
          ),
          data: (pinnedBlog) => _buildBlogList(
            context,
            ref,
            blogs: blogs,
            pinnedBlog: pinnedBlog,
          ),
        );
      },
    );
  }

  Widget _buildBlogList(
    BuildContext context,
    WidgetRef ref, {
    required List<PostModel> blogs,
    required PostModel? pinnedBlog,
    bool loadingPinnedState = false,
  }) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final visibleBlogs = blogs
        .where((blog) => pinnedBlog == null || blog.id != pinnedBlog.id)
        .toList();

    if (blogs.isEmpty && pinnedBlog == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(r.s(24)),
        children: [
          SizedBox(height: r.screenHeight * 0.08),
          Icon(Icons.menu_book_rounded,
              color: Colors.grey[600], size: r.s(48)),
          SizedBox(height: r.s(12)),
          Text(
            isOwnProfile
                ? 'Você ainda não publicou nenhum blog.'
                : 'Este usuário ainda não publicou nenhum blog.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: r.fs(14)),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        ref.invalidate(userBlogsProvider(userId));
        ref.invalidate(pinnedProfileBlogProvider(userId));
        await Future.delayed(const Duration(milliseconds: 250));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(r.s(12), r.s(12), r.s(12), r.s(24)),
        children: [
          if (pinnedBlog != null) ...[
            _SectionHeader(
              title: s.pinnedLabel,
              subtitle: 'Blog destacado no perfil',
              icon: Icons.push_pin_rounded,
            ),
            _ProfileBlogCard(
              post: pinnedBlog,
              isOwnProfile: isOwnProfile,
              busy: loadingPinnedState,
              actionLabel: s.unpinFromProfile,
              actionIcon: Icons.push_pin_outlined,
              onAction: () => _togglePinnedBlog(
                context,
                ref,
                post: pinnedBlog,
                shouldPin: false,
              ),
            ),
            SizedBox(height: r.s(16)),
          ],
          _SectionHeader(
            title: s.posts,
            subtitle: 'Blogs publicados',
            icon: Icons.article_outlined,
          ),
          if (visibleBlogs.isEmpty)
            Container(
              padding: EdgeInsets.all(r.s(18)),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(r.s(14)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Text(
                'Nenhum outro blog disponível para exibição.',
                style: TextStyle(color: Colors.grey[500], fontSize: r.fs(13)),
              ),
            )
          else
            ...visibleBlogs.map(
              (blog) => _ProfileBlogCard(
                post: blog,
                isOwnProfile: isOwnProfile,
                actionLabel:
                    blog.isPinnedProfile ? s.unpinFromProfile : s.pinToProfile,
                actionIcon: blog.isPinnedProfile
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                onAction: () => _togglePinnedBlog(
                  context,
                  ref,
                  post: blog,
                  shouldPin: !blog.isPinnedProfile,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _togglePinnedBlog(
    BuildContext context,
    WidgetRef ref, {
    required PostModel post,
    required bool shouldPin,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SupabaseService.rpc(
        'toggle_profile_blog_pin',
        params: {
          'p_post_id': post.id,
          'p_is_pinned': shouldPin,
        },
      );
      ref.invalidate(userBlogsProvider(userId));
      ref.invalidate(pinnedProfileBlogProvider(userId));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            shouldPin
                ? 'Blog fixado no perfil com sucesso.'
                : 'Blog removido do destaque do perfil.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.surfaceColor,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Não foi possível atualizar o blog fixado do perfil.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(4), 0, r.s(4), r.s(10)),
      child: Row(
        children: [
          Container(
            width: r.s(34),
            height: r.s(34),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(r.s(10)),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: r.s(18)),
          ),
          SizedBox(width: r.s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: r.fs(15),
                  ),
                ),
                SizedBox(height: r.s(2)),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: r.fs(12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBlogCard extends StatelessWidget {
  final PostModel post;
  final bool isOwnProfile;
  final bool busy;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _ProfileBlogCard({
    required this.post,
    required this.isOwnProfile,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Container(
      margin: EdgeInsets.only(bottom: r.s(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isOwnProfile)
            Padding(
              padding: EdgeInsets.fromLTRB(r.s(6), 0, r.s(6), r.s(8)),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onAction,
                  icon: Icon(actionIcon, size: r.s(16)),
                  label: Text(actionLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: r.s(12),
                      vertical: r.s(10),
                    ),
                  ),
                ),
              ),
            ),
          PostCard(post: post, showCommunity: false),
        ],
      ),
    );
  }
}
