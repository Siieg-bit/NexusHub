import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/utils/amino_animations.dart';
import '../../../core/utils/responsive.dart';
import '../../feed/widgets/post_card.dart';
import '../../stories/widgets/story_carousel.dart';
import '../providers/community_detail_providers.dart';

// =============================================================================
// TAB: Feed (Featured / Latest)
//
// FIX: Changed from StatelessWidget receiving `ref` as constructor param
//      to ConsumerWidget — the idiomatic Riverpod approach.
// =============================================================================

class CommunityFeedTab extends ConsumerWidget {
  final String communityId;
  final bool isFeatured;

  const CommunityFeedTab({
    super.key,
    required this.communityId,
    this.isFeatured = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final feedAsync = ref.watch(communityFeedProvider(communityId));

    return feedAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
            color: AppTheme.primaryColor, strokeWidth: 2.5),
      ),
      error: (error, _) => Center(
          child: Text('Erro: $error',
              style: TextStyle(color: context.textSecondary))),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined,
                    size: r.s(48), color: context.textHint),
                SizedBox(height: r.s(12)),
                Text(
                  'Nenhum post ainda. Seja o primeiro a postar!',
                  style:
                      TextStyle(color: Colors.grey[600], fontSize: r.fs(13)),
                ),
              ],
            ),
          );
        }

        // Featured mode: compact list style (like Amino)
        if (isFeatured) {
          return ListView.builder(
            padding:
                EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return AminoAnimations.staggerItem(
                index: index,
                child: AminoAnimations.cardPress(
                  onTap: () => context.push('/post/${post.id}'),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        vertical: r.s(10), horizontal: r.s(4)),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color:
                              context.dividerClr.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: r.s(6),
                          height: r.s(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: r.s(10)),
                        Expanded(
                          child: Text(
                            post.title ?? '',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: r.fs(13),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (post.mediaUrls.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(left: r.s(8)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(r.s(6)),
                              child: CachedNetworkImage(
                                imageUrl: post.mediaUrls.first,
                                width: r.s(40),
                                height: r.s(40),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        // Latest mode: full post cards with Story Carousel on top
        return ListView.builder(
          padding:
              EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
          itemCount: posts.length + 1, // +1 para o carrossel de stories
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: EdgeInsets.only(bottom: r.s(8)),
                child: StoryCarousel(communityId: communityId),
              );
            }
            final postIndex = index - 1;
            return AminoAnimations.staggerItem(
              index: postIndex,
              child: PostCard(
                post: posts[postIndex],
                showCommunity: false,
              ),
            );
          },
        );
      },
    );
  }
}
