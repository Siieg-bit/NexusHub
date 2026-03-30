import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../feed/widgets/post_card.dart';
import '../providers/profile_providers.dart';

// =============================================================================
// STORIES TAB — Posts do usuário
// =============================================================================

class ProfileStoriesTab extends ConsumerWidget {
  final String userId;
  const ProfileStoriesTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final postsAsync = ref.watch(userPostsProvider(userId));

    return postsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
            color: AppTheme.accentColor, strokeWidth: 2),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to load data.',
                style: TextStyle(color: Colors.grey[500])),
            SizedBox(height: r.s(12)),
            GestureDetector(
              onTap: () => ref.invalidate(userPostsProvider(userId)),
              child: Icon(Icons.refresh_rounded,
                  color: Colors.grey[500], size: r.s(32)),
            ),
          ],
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined,
                    size: r.s(48), color: Colors.grey[700]),
                SizedBox(height: r.s(12)),
                Text('Nenhum post ainda',
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: posts.length,
          itemBuilder: (context, index) => PostCard(post: posts[index]),
        );
      },
    );
  }
}
