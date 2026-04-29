import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/post_model.dart';
import '../../../core/utils/amino_animations.dart';
import '../../../core/utils/responsive.dart';
import '../../feed/widgets/post_card.dart';
import '../../stories/widgets/story_carousel.dart';
import '../providers/community_detail_providers.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/haptic_service.dart';
import 'featured_members_section.dart';
import '../../../core/widgets/reaction_picker.dart';

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
      ref.invalidate(archivedFeaturedFeedProvider(communityId));
      ref.invalidate(latestFeedProvider(communityId));
    } else {
      ref.invalidate(latestFeedProvider(communityId));
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

  Color _accentColor(BuildContext context, WidgetRef ref) {
    final community =
        ref.watch(communityDetailProvider(communityId)).valueOrNull;
    if (community == null) return context.nexusTheme.accentPrimary;
    try {
      return Color(int.parse(community.themeColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return context.nexusTheme.accentPrimary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final pinnedAsync = ref.watch(pinnedFeedProvider(communityId));
    final featuredAsync = ref.watch(activeFeaturedFeedProvider(communityId));
    final archivedFeaturedAsync =
        ref.watch(archivedFeaturedFeedProvider(communityId));
    final latestAsync = ref.watch(latestFeedProvider(communityId));
    final accent = _accentColor(context, ref);

    final pinnedPosts = pinnedAsync.valueOrNull ?? [];
    final featuredPosts = featuredAsync.valueOrNull ?? [];
    final archivedFeaturedPosts = archivedFeaturedAsync.valueOrNull ?? [];
    final latestPosts = latestAsync.valueOrNull ?? [];
    final membershipAsync = ref.watch(communityMembershipProvider(communityId));
    final userRole = membershipAsync.valueOrNull?['role'] as String?;
    final isStaff = ['leader', 'co_leader', 'moderator', 'agent'].contains(userRole);
    final primaryFeatured =
        featuredPosts.isNotEmpty ? featuredPosts.first : null;
    final secondaryFeatured = featuredPosts.length > 1
        ? featuredPosts.skip(1).take(4).toList()
        : <PostModel>[];
    final rotatedFeaturedPosts = <PostModel>[
      ...featuredPosts.skip(5),
      ...archivedFeaturedPosts,
    ];
    final dedupedRotatedFeaturedPosts = <PostModel>[];
    final seenRotatedPostIds = <String>{};
    for (final post in rotatedFeaturedPosts) {
      if (seenRotatedPostIds.add(post.id)) {
        dedupedRotatedFeaturedPosts.add(post);
      }
    }

    final isLoading = pinnedAsync.isLoading &&
        featuredAsync.isLoading &&
        archivedFeaturedAsync.isLoading &&
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
        // Pré-renderiza 500px além da área visível para scroll mais suave
        cacheExtent: 500,
        slivers: [
          // ── Seção 0: Membros em Destaque ────────────────────────────────
          SliverToBoxAdapter(
            child: FeaturedMembersSection(
              communityId: communityId,
              isStaff: isStaff,
            ),
          ),
          // ── Seção 1: Posts Fixados ──────────────────────────────────────
          if (pinnedPosts.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: 4)),
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

          // ── Seção 2: Destaques e histórico de rotação ───────────────────
          if (primaryFeatured != null ||
              dedupedRotatedFeaturedPosts.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                icon: Icons.star_rounded,
                label: s.highlights,
                accent: accent,
              ),
            ),
            if (primaryFeatured != null)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: r.s(12)),
                sliver: SliverToBoxAdapter(
                  child: _FeaturedHeroCard(
                    post: primaryFeatured,
                    accent: accent,
                  ),
                ),
              ),
            if (secondaryFeatured.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(r.s(12), r.s(8), r.s(12), 0),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: r.s(8),
                    mainAxisSpacing: r.s(8),
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _FeaturedPostCard(
                      post: secondaryFeatured[i],
                      accent: accent,
                      index: i + 1,
                    ),
                    childCount: secondaryFeatured.length,
                  ),
                ),
              ),
            if (dedupedRotatedFeaturedPosts.isNotEmpty)
              SliverToBoxAdapter(
                child: _RotatedFeaturedCarousel(
                  posts: dedupedRotatedFeaturedPosts,
                  accent: accent,
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: r.s(8))),
          ],

          // ── Seção 3: Posts Recentes ─────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              icon: Icons.access_time_rounded,
              label: s.latest,
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
                          size: r.s(40), color: context.nexusTheme.textHint),
                      SizedBox(height: r.s(8)),
                      Text(
                        'Nenhum post ainda. Seja o primeiro a postar!',
                        style: TextStyle(
                            color: context.nexusTheme.textHint, fontSize: r.fs(13)),
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

class _RotatedFeaturedCarousel extends ConsumerWidget {
  final List<PostModel> posts;
  final Color accent;

  const _RotatedFeaturedCarousel({
    required this.posts,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;

    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(16), r.s(16), 0, r.s(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_toggle_off_rounded,
                size: r.s(16),
                color: accent,
              ),
              SizedBox(width: r.s(6)),
              Text(
                'Saíram de rotação',
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(14),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          SizedBox(height: r.s(6)),
          Text(
            'Os destaques mais antigos continuam acessíveis aqui sem ocupar uma aba separada.',
            style: TextStyle(
              color: context.nexusTheme.textHint,
              fontSize: r.fs(11),
              height: 1.35,
            ),
          ),
          SizedBox(height: r.s(10)),
          SizedBox(
            height: r.s(226),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(right: r.s(16)),
              itemCount: posts.length,
              separatorBuilder: (_, __) => SizedBox(width: r.s(10)),
              itemBuilder: (context, index) => SizedBox(
                width: r.s(190),
                child: _FeaturedPostCard(
                  post: posts[index],
                  accent: accent,
                  index: index + 5,
                ),
              ),
            ),
          ),
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
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final feedAsync = ref.watch(latestFeedProvider(communityId));

    return feedAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
            color: context.nexusTheme.accentPrimary, strokeWidth: 2.5),
      ),
      error: (error, stackTrace) {
        debugPrint('[CommunityFeedTab][latestFeed] ERROR: $error');
        debugPrint('[CommunityFeedTab][latestFeed] STACK: $stackTrace');
        return RefreshIndicator(
          onRefresh: () => onRefresh(ref),
          color: context.nexusTheme.accentPrimary,
          backgroundColor: context.surfaceColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s.errorLoadingPosts,
                        style: TextStyle(color: context.nexusTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: const TextStyle(color: Colors.red, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      data: (posts) {
        if (posts.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => onRefresh(ref),
            color: context.nexusTheme.accentPrimary,
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
                            size: r.s(48), color: context.nexusTheme.textHint),
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
          color: context.nexusTheme.accentPrimary,
          backgroundColor: context.surfaceColor,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            // Pré-renderiza 500px além da área visível para scroll mais suave
            cacheExtent: 500,
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
class _SectionHeader extends ConsumerWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              color: context.nexusTheme.textPrimary,
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
class _PinnedPostRow extends ConsumerWidget {
  final PostModel post;
  final Color accent;
  final int index;

  const _PinnedPostRow({
    required this.post,
    required this.accent,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return AminoAnimations.staggerItem(
      index: index,
      child: AminoAnimations.cardPress(
        onTap: () => context.push('/post/${post.id}'),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(10)),
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
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedHeroCard extends ConsumerStatefulWidget {
  final PostModel post;
  final Color accent;

  const _FeaturedHeroCard({required this.post, required this.accent});

  @override
  ConsumerState<_FeaturedHeroCard> createState() => _FeaturedHeroCardState();
}

class _FeaturedHeroCardState extends ConsumerState<_FeaturedHeroCard> {
  late PostModel _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void didUpdateWidget(_FeaturedHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.isLiked != widget.post.isLiked ||
        oldWidget.post.likesCount != widget.post.likesCount) {
      _post = widget.post;
    }
  }

  Future<void> _toggleReaction(String? reactionType) async {
    final prevReaction = _post.myReactionType;
    final prevLikes = _post.likesCount;
    final isAdding = reactionType != null;
    final isRemoving = reactionType == null && prevReaction != null;
    final isChanging = reactionType != null && prevReaction != null && reactionType != prevReaction;
    // Atualização otimista
    setState(() {
      _post = _post.copyWith(
        isLiked: isAdding,
        myReactionType: reactionType,
        clearReaction: reactionType == null,
        likesCount: isAdding && !isChanging
            ? prevLikes + 1
            : isRemoving
                ? prevLikes - 1
                : prevLikes,
      );
    });
    try {
      await SupabaseService.client.rpc('toggle_reaction_with_reputation', params: {
        'p_community_id': _post.communityId,
        'p_user_id': SupabaseService.currentUserId,
        'p_post_id': _post.id,
        'p_type': reactionType ?? prevReaction ?? 'like',
      });
    } catch (_) {
      // Reverte em caso de erro
      if (mounted) {
        setState(() {
          _post = _post.copyWith(
            isLiked: prevReaction != null,
            myReactionType: prevReaction,
            clearReaction: prevReaction == null,
            likesCount: prevLikes,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final accent = widget.accent;
    final imageUrl = _post.coverImageUrl ?? _post.mediaUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth;
        return AminoAnimations.cardPress(
      onTap: () => context.push('/post/${_post.id}'),
      child: Container(
        height: side,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r.s(20)),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
          image: hasImage
              ? DecorationImage(
                  image: CachedNetworkImageProvider(imageUrl),
                  fit: BoxFit.cover,
                )
              : null,
          color: context.surfaceColor,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.s(20)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: hasImage ? 0.08 : 0.02),
                Colors.black.withValues(alpha: 0.88),
              ],
            ),
          ),
          padding: EdgeInsets.all(r.s(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // ── Barra de ações ──
              Row(
                children: [
                  // Botão de reaction com picker
                  ReactionButton(
                    currentReaction: _post.myReactionType,
                    totalCount: _post.likesCount,
                    onReaction: _toggleReaction,
                  ),
                  SizedBox(width: r.s(18)),
                  // Botão de comentários — abre o post diretamente na seção de comentários
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context
                        .push('/post/${_post.id}?scrollToComments=true'),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: r.s(6), horizontal: r.s(2)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: r.s(20),
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          SizedBox(width: r.s(5)),
                          Text(
                            '${_post.commentsCount}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: r.fs(14),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
         ),
      ),
    );
      },
    );
  }
}
/// Card grande para posts em destaque (grid 2 colunas, estilo Amino)
class _FeaturedPostCard extends ConsumerStatefulWidget {
  final PostModel post;
  final Color accent;
  final int index;

  const _FeaturedPostCard({
    required this.post,
    required this.accent,
    required this.index,
  });

  @override
  ConsumerState<_FeaturedPostCard> createState() => _FeaturedPostCardState();
}

class _FeaturedPostCardState extends ConsumerState<_FeaturedPostCard> {
  late PostModel _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  Future<void> _toggleLike() async {
    final wasLiked = _post.isLiked;
    if (!wasLiked) {
      HapticService.success();
    } else {
      HapticService.buttonPress();
    }
    setState(() {
      _post = _post.copyWith(
        isLiked: !wasLiked,
        likesCount: _post.likesCount + (wasLiked ? -1 : 1),
      );
    });
    try {
      await SupabaseService.client.rpc('toggle_reaction_with_reputation', params: {
        'p_community_id': _post.communityId,
        'p_user_id': SupabaseService.currentUserId,
        'p_post_id': _post.id,
        'p_type': 'like',
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _post = _post.copyWith(
            isLiked: wasLiked,
            likesCount: _post.likesCount + (wasLiked ? 1 : -1),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final thumb = _post.coverImageUrl ?? _post.mediaUrl;
    final hasImage = thumb != null && thumb.isNotEmpty;

    return AminoAnimations.staggerItem(
      index: widget.index,
      child: AminoAnimations.cardPress(
        onTap: () => context.push('/post/${_post.id}'),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cover image
              ClipRRect(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(r.s(12))),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: thumb,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _PlaceholderCover(accent: widget.accent),
                        )
                      : _PlaceholderCover(accent: widget.accent),
                ),
              ),

              // Conteúdo
              Padding(
                padding: EdgeInsets.all(r.s(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      // Título — 1 linha com ellipsis
                      Text(
                        _post.title ?? _post.content,
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontSize: r.fs(12),
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: r.s(6)),

                      // Autor
                      Builder(builder: (context) {
                        final featuredAvatarUrl =
                            _post.authorLocalIconUrl?.trim().isNotEmpty == true
                                ? _post.authorLocalIconUrl!.trim()
                                : null;
                        final featuredNickname =
                            _post.authorLocalNickname?.trim().isNotEmpty == true
                                ? _post.authorLocalNickname!.trim()
                                : s.user;
                        return Row(
                          children: [
                            if (featuredAvatarUrl != null)
                              ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: featuredAvatarUrl,
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
                                featuredNickname,
                                style: TextStyle(
                                  color: context.nexusTheme.textSecondary,
                                  fontSize: r.fs(10),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      }),

                      SizedBox(height: r.s(4)),

                      // Likes + Comentários — ações inline
                      Row(
                        children: [
                          // Botão de curtir
                          GestureDetector(
                            onTap: _toggleLike,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: r.s(4), horizontal: r.s(2)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _post.isLiked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: r.s(14),
                                    color: _post.isLiked
                                        ? Colors.redAccent
                                        : context.nexusTheme.textHint,
                                  ),
                                  SizedBox(width: r.s(3)),
                                  Text(
                                    '${_post.likesCount}',
                                    style: TextStyle(
                                        color: _post.isLiked
                                            ? Colors.redAccent
                                            : context.nexusTheme.textHint,
                                        fontSize: r.fs(11),
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: r.s(10)),
                          // Botão de comentar — abre post com foco no campo
                          GestureDetector(
                            onTap: () => context.push(
                                '/post/${_post.id}?scrollToComments=true'),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: r.s(4), horizontal: r.s(2)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded,
                                      size: r.s(14),
                                      color: context.nexusTheme.textHint),
                                  SizedBox(width: r.s(3)),
                                  Text(
                                    '${_post.commentsCount}',
                                    style: TextStyle(
                                        color: context.nexusTheme.textHint,
                                        fontSize: r.fs(11),
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                   ],
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
class _PlaceholderCover extends ConsumerWidget {
  final Color accent;
  const _PlaceholderCover({required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
class _DefaultAvatar extends ConsumerWidget {
  final double size;
  const _DefaultAvatar({required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: size * 0.65, color: Colors.white54),
    );
  }
}
