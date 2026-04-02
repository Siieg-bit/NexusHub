import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/models/post_model.dart';
import '../../../core/utils/amino_animations.dart';
import '../../../core/utils/responsive.dart';
import '../../feed/widgets/post_card.dart';
import '../../stories/widgets/story_carousel.dart';
import '../providers/community_detail_providers.dart';

// =============================================================================
// TAB: Feed (Destaque / Recentes)
//
// Aba "Destaque" (isFeatured: true) — estrutura Amino:
//   1. Seção "Fixados"  — lista compacta de posts com is_pinned = true
//   2. Seção "Destaques" — grid 2 colunas de posts ativos (featured_until > now)
//   3. Seção "Recentes" — feed padrão de posts recentes (excluindo fixados)
//
// Aba "Recentes" (isFeatured: false) — feed padrão com StoryCarousel no topo.
// =============================================================================

class CommunityFeedTab extends ConsumerWidget {
  final String communityId;
  final bool isFeatured;

  const CommunityFeedTab({
    super.key,
    required this.communityId,
    this.isFeatured = false,
  });

  Future<void> _onRefresh(WidgetRef ref) async {
    if (isFeatured) {
      ref.invalidate(pinnedFeedProvider(communityId));
      ref.invalidate(activeFeaturedFeedProvider(communityId));
      ref.invalidate(latestFeedProvider(communityId));
    } else {
      ref.invalidate(communityFeedProvider(communityId));
    }
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isFeatured) {
      return _FeaturedTab(communityId: communityId, onRefresh: _onRefresh);
    }
    return _LatestTab(communityId: communityId, onRefresh: _onRefresh);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Aba DESTAQUE — três seções em um único CustomScrollView
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturedTab extends ConsumerWidget {
  final String communityId;
  final Future<void> Function(WidgetRef ref) onRefresh;

  const _FeaturedTab({required this.communityId, required this.onRefresh});

  Color _accentColor(WidgetRef ref) {
    final community = ref.watch(communityDetailProvider(communityId)).valueOrNull;
    if (community == null) return AppTheme.primaryColor;
    try {
      return Color(int.parse(community.themeColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final pinnedAsync = ref.watch(pinnedFeedProvider(communityId));
    final featuredAsync = ref.watch(activeFeaturedFeedProvider(communityId));
    final latestAsync = ref.watch(latestFeedProvider(communityId));
    final accent = _accentColor(ref);

    final pinnedPosts = pinnedAsync.valueOrNull ?? [];
    final featuredPosts = featuredAsync.valueOrNull ?? [];
    final latestPosts = latestAsync.valueOrNull ?? [];

    final isLoading = pinnedAsync.isLoading &&
        featuredAsync.isLoading &&
        latestAsync.isLoading;

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: accent, strokeWidth: 2.5),
      );
    }

    return RefreshIndicator(
      onRefresh: () => onRefresh(ref),
      color: accent,
      backgroundColor: context.surfaceColor,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Seção 1: Posts Fixados ──────────────────────────────────────
          if (pinnedPosts.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                icon: Icons.push_pin_rounded,
                label: 'Fixados',
                accent: accent,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _PinnedPostRow(
                  post: pinnedPosts[i],
                  accent: accent,
                  index: i,
                ),
                childCount: pinnedPosts.length,
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: r.s(8))),
          ],

          // ── Seção 2: Destaques Ativos ───────────────────────────────────
          if (featuredPosts.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                icon: Icons.star_rounded,
                label: 'Destaques',
                accent: accent,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: r.s(12)),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: r.s(8),
                  mainAxisSpacing: r.s(8),
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _FeaturedPostCard(
                    post: featuredPosts[i],
                    accent: accent,
                    index: i,
                  ),
                  childCount: featuredPosts.length,
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: r.s(8))),
          ],

          // ── Seção 3: Posts Recentes ─────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              icon: Icons.access_time_rounded,
              label: 'Recentes',
              accent: accent,
            ),
          ),

          if (latestPosts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: r.s(32)),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.article_outlined,
                          size: r.s(40), color: context.textHint),
                      SizedBox(height: r.s(8)),
                      Text(
                        'Nenhum post ainda. Seja o primeiro a postar!',
                        style: TextStyle(
                            color: context.textHint, fontSize: r.fs(13)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => RepaintBoundary(
                  child: AminoAnimations.staggerItem(
                    index: i,
                    child: PostCard(
                      post: latestPosts[i],
                      showCommunity: false,
                    ),
                  ),
                ),
                childCount: latestPosts.length,
              ),
            ),

          SliverToBoxAdapter(child: SizedBox(height: r.s(80))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Aba RECENTES — feed padrão com StoryCarousel no topo
// ─────────────────────────────────────────────────────────────────────────────

class _LatestTab extends ConsumerWidget {
  final String communityId;
  final Future<void> Function(WidgetRef ref) onRefresh;

  const _LatestTab({required this.communityId, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final feedAsync = ref.watch(communityFeedProvider(communityId));

    return feedAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
            color: AppTheme.primaryColor, strokeWidth: 2.5),
      ),
      error: (error, _) => RefreshIndicator(
        onRefresh: () => onRefresh(ref),
        color: AppTheme.primaryColor,
        backgroundColor: context.surfaceColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Text('Erro ao carregar posts',
                  style: TextStyle(color: context.textSecondary)),
            ),
          ),
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => onRefresh(ref),
            color: AppTheme.primaryColor,
            backgroundColor: context.surfaceColor,
            child: LayoutBuilder(
              builder: (ctx, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.article_outlined,
                            size: r.s(48), color: context.textHint),
                        SizedBox(height: r.s(12)),
                        Text(
                          'Nenhum post ainda. Seja o primeiro a postar!',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: r.fs(13)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => onRefresh(ref),
          color: AppTheme.primaryColor,
          backgroundColor: context.surfaceColor,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
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
              return RepaintBoundary(
                child: AminoAnimations.staggerItem(
                  index: postIndex,
                  child: PostCard(
                    post: posts[postIndex],
                    showCommunity: false,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

/// Cabeçalho de seção estilo Amino: ícone colorido + label bold
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), r.s(8)),
      child: Row(
        children: [
          Icon(icon, size: r.s(16), color: accent),
          SizedBox(width: r.s(6)),
          Text(
            label,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: r.fs(14),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha compacta para posts fixados (estilo lista Amino)
class _PinnedPostRow extends StatelessWidget {
  final PostModel post;
  final Color accent;
  final int index;

  const _PinnedPostRow({
    required this.post,
    required this.accent,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final thumb = post.coverImageUrl ?? post.mediaUrl;

    return AminoAnimations.staggerItem(
      index: index,
      child: AminoAnimations.cardPress(
        onTap: () => context.push('/post/${post.id}'),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: r.s(16), vertical: r.s(10)),
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
              // Ícone de fixado
              Icon(Icons.push_pin_rounded,
                  size: r.s(14), color: accent.withValues(alpha: 0.8)),
              SizedBox(width: r.s(8)),
              // Título
              Expanded(
                child: Text(
                  post.title ?? post.content,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Thumbnail opcional
              if (thumb != null) ...[
                SizedBox(width: r.s(8)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(r.s(6)),
                  child: CachedNetworkImage(
                    imageUrl: thumb,
                    width: r.s(44),
                    height: r.s(44),
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Card grande para posts em destaque (grid 2 colunas, estilo Amino)
class _FeaturedPostCard extends StatelessWidget {
  final PostModel post;
  final Color accent;
  final int index;

  const _FeaturedPostCard({
    required this.post,
    required this.accent,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final thumb = post.coverImageUrl ?? post.mediaUrl;
    final hasImage = thumb != null && thumb.isNotEmpty;

    return AminoAnimations.staggerItem(
      index: index,
      child: AminoAnimations.cardPress(
        onTap: () => context.push('/post/${post.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(r.s(12))),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: thumb,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _PlaceholderCover(
                              accent: accent),
                        )
                      : _PlaceholderCover(accent: accent),
                ),
              ),

              // Conteúdo
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(r.s(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título
                      Expanded(
                        child: Text(
                          post.title ?? post.content,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: r.fs(12),
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      SizedBox(height: r.s(6)),

                      // Autor + stats
                      Row(
                        children: [
                          // Avatar do autor
                          if (post.author?.iconUrl != null)
                            ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: post.author!.iconUrl!,
                                width: r.s(16),
                                height: r.s(16),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    _DefaultAvatar(size: r.s(16)),
                              ),
                            )
                          else
                            _DefaultAvatar(size: r.s(16)),
                          SizedBox(width: r.s(4)),
                          Expanded(
                            child: Text(
                              post.author?.nickname ?? 'Usuário',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: r.fs(10),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: r.s(4)),

                      // Likes + Comentários
                      Row(
                        children: [
                          Icon(Icons.favorite_rounded,
                              size: r.s(11),
                              color: context.textHint),
                          SizedBox(width: r.s(2)),
                          Text(
                            '${post.likesCount}',
                            style: TextStyle(
                                color: context.textHint,
                                fontSize: r.fs(10)),
                          ),
                          SizedBox(width: r.s(8)),
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: r.s(11),
                              color: context.textHint),
                          SizedBox(width: r.s(2)),
                          Text(
                            '${post.commentsCount}',
                            style: TextStyle(
                                color: context.textHint,
                                fontSize: r.fs(10)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder colorido quando não há imagem de capa
class _PlaceholderCover extends StatelessWidget {
  final Color accent;
  const _PlaceholderCover({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: accent.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          Icons.article_rounded,
          color: accent.withValues(alpha: 0.5),
          size: 32,
        ),
      ),
    );
  }
}

/// Avatar padrão quando não há foto de perfil
class _DefaultAvatar extends StatelessWidget {
  final double size;
  const _DefaultAvatar({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: size * 0.65, color: Colors.white54),
    );
  }
}
