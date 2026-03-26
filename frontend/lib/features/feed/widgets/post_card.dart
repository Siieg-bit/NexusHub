import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../config/app_theme.dart';
import '../../../core/models/post_model.dart';

/// Card de post no feed, inspirado no design do Amino.
class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onLike;

  const PostCard({super.key, required this.post, this.onLike});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================================================================
            // HEADER: Avatar + Nome + Tempo
            // ================================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: () => context.push('/user/${post.authorId}'),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.3),
                      backgroundImage: post.author?.iconUrl != null
                          ? CachedNetworkImageProvider(post.author!.iconUrl!)
                          : null,
                      child: post.author?.iconUrl == null
                          ? Text(
                              (post.author?.nickname ?? '?')[0].toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Nome e nível
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post.author?.nickname ?? 'Usuário',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (post.author != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.getLevelColor(post.author!.level)
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Lv.${post.author!.level}',
                                  style: TextStyle(
                                    color: AppTheme.getLevelColor(post.author!.level),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          timeago.format(post.createdAt, locale: 'pt_BR'),
                          style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  // Feature badge
                  if (post.featureType != 'none')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 12, color: AppTheme.warningColor),
                          const SizedBox(width: 2),
                          Text(
                            post.featureType == 'featured' ? 'Destaque' : 'Fixado',
                            style: const TextStyle(
                              color: AppTheme.warningColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Menu
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded, size: 20),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // ================================================================
            // TÍTULO
            // ================================================================
            if (post.title != null && post.title!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  post.title!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // ================================================================
            // CONTEÚDO
            // ================================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Text(
                post.content,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ================================================================
            // MÍDIA (primeira imagem)
            // ================================================================
            if (post.mediaUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: post.mediaUrl.first,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 200,
                      color: AppTheme.cardColorLight,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 200,
                      color: AppTheme.cardColorLight,
                      child: const Icon(Icons.broken_image_rounded, color: AppTheme.textHint),
                    ),
                  ),
                ),
              ),

            // ================================================================
            // TAGS
            // ================================================================
            if (post.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Wrap(
                  spacing: 6,
                  children: post.tags.take(3).map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(
                        color: AppTheme.primaryLight,
                        fontSize: 11,
                      ),
                    ),
                  )).toList(),
                ),
              ),

            // ================================================================
            // AÇÕES: Like, Comentar, Compartilhar
            // ================================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
              child: Row(
                children: [
                  // Like
                  _ActionButton(
                    icon: post.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: post.likesCount > 0 ? '${post.likesCount}' : 'Curtir',
                    color: post.isLiked ? AppTheme.errorColor : null,
                    onTap: onLike ?? () {},
                  ),

                  // Comentar
                  _ActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: post.commentsCount > 0 ? '${post.commentsCount}' : 'Comentar',
                    onTap: () => context.push('/post/${post.id}'),
                  ),

                  // Compartilhar
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: 'Compartilhar',
                    onTap: () {},
                  ),

                  const Spacer(),

                  // Views
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 14, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Text(
                          '${post.viewsCount}',
                          style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color ?? AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
