import 'package:flutter/material.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../utils/responsive.dart';

/// Widget de shimmer/skeleton loading para exibir enquanto dados carregam.
///
/// Uso:
/// ```dart
/// ShimmerLoading(child: _PostSkeleton())
/// ```
class ShimmerLoading extends StatefulWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nexusTheme = context.nexusTheme;
    final baseColor = nexusTheme.shimmerBase;
    final highlightColor = nexusTheme.shimmerHighlight;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

/// Placeholder retangular para shimmer.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.nexusTheme.shimmerBase,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Placeholder circular para shimmer (avatares).
class ShimmerCircle extends StatelessWidget {
  final double size;

  const ShimmerCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.nexusTheme.shimmerBase,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton de um Post Card para exibir durante carregamento.
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return ShimmerLoading(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(6)),
        padding: EdgeInsets.all(r.s(16)),
        decoration: BoxDecoration(
          color: context.nexusTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                ShimmerCircle(size: r.s(40)),
                SizedBox(width: r.s(12)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: r.s(120), height: r.s(14)),
                    SizedBox(height: r.s(6)),
                    ShimmerBox(width: r.s(80), height: r.s(10)),
                  ],
                ),
              ],
            ),
            SizedBox(height: r.s(16)),
            // Title
            ShimmerBox(width: double.infinity, height: r.s(18)),
            SizedBox(height: r.s(8)),
            // Body
            ShimmerBox(width: double.infinity, height: r.s(12)),
            SizedBox(height: r.s(4)),
            ShimmerBox(width: r.s(200), height: r.s(12)),
            SizedBox(height: r.s(16)),
            // Image placeholder
            ShimmerBox(
                width: double.infinity, height: r.s(180), borderRadius: 12),
            SizedBox(height: r.s(16)),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: r.s(60), height: r.s(24)),
                ShimmerBox(width: r.s(60), height: r.s(24)),
                ShimmerBox(width: r.s(60), height: r.s(24)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton de um Chat Item para exibir durante carregamento.
class ChatItemSkeleton extends StatelessWidget {
  const ChatItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return ShimmerLoading(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
        child: Row(
          children: [
            ShimmerCircle(size: r.s(48)),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: r.s(160), height: r.s(14)),
                  SizedBox(height: r.s(6)),
                  ShimmerBox(width: r.s(220), height: r.s(10)),
                ],
              ),
            ),
            ShimmerBox(width: r.s(40), height: r.s(10)),
          ],
        ),
      ),
    );
  }
}

/// Skeleton de uma Community Card para exibir durante carregamento.
class CommunityCardSkeleton extends StatelessWidget {
  const CommunityCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return ShimmerLoading(
      child: Container(
        width: r.s(140),
        margin: EdgeInsets.only(right: r.s(12)),
        decoration: BoxDecoration(
          color: context.nexusTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(16)),
        ),
        child: Column(
          children: [
            ShimmerBox(width: r.s(140), height: r.s(80), borderRadius: 16),
            SizedBox(height: r.s(8)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.s(8)),
              child: ShimmerBox(width: r.s(100), height: r.s(12)),
            ),
            SizedBox(height: r.s(4)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.s(8)),
              child: ShimmerBox(width: r.s(60), height: r.s(10)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOVOS SKELETONS — Polimento UX v1
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton do cabeçalho do perfil (avatar grande + nome + bio).
class ProfileHeaderSkeleton extends StatelessWidget {
  const ProfileHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return ShimmerLoading(
      child: Column(
        children: [
          // Banner
          ShimmerBox(
            width: double.infinity,
            height: r.s(140),
            borderRadius: 0,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(16)),
            child: Column(
              children: [
                // Avatar sobreposto ao banner
                Transform.translate(
                  offset: Offset(0, -r.s(40)),
                  child: ShimmerCircle(size: r.s(80)),
                ),
                SizedBox(height: r.s(4)),
                // Nome
                ShimmerBox(width: r.s(140), height: r.s(18)),
                SizedBox(height: r.s(8)),
                // Bio
                ShimmerBox(width: r.s(220), height: r.s(12)),
                SizedBox(height: r.s(4)),
                ShimmerBox(width: r.s(180), height: r.s(12)),
                SizedBox(height: r.s(16)),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShimmerBox(width: r.s(60), height: r.s(36)),
                    SizedBox(width: r.s(24)),
                    ShimmerBox(width: r.s(60), height: r.s(36)),
                    SizedBox(width: r.s(24)),
                    ShimmerBox(width: r.s(60), height: r.s(36)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton completo da tela de perfil (header + posts).
class ProfileScreenSkeleton extends StatelessWidget {
  const ProfileScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ProfileHeaderSkeleton(),
        const PostCardSkeleton(),
        const PostCardSkeleton(),
      ],
    );
  }
}

/// Skeleton do cabeçalho da comunidade (banner + ícone + nome + tabs).
class CommunityHeaderSkeleton extends StatelessWidget {
  const CommunityHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return ShimmerLoading(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          ShimmerBox(
            width: double.infinity,
            height: r.s(160),
            borderRadius: 0,
          ),
          Padding(
            padding: EdgeInsets.all(r.s(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone + nome
                Row(
                  children: [
                    ShimmerCircle(size: r.s(56)),
                    SizedBox(width: r.s(12)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: r.s(160), height: r.s(18)),
                        SizedBox(height: r.s(6)),
                        ShimmerBox(width: r.s(100), height: r.s(12)),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: r.s(12)),
                // Descrição
                ShimmerBox(width: double.infinity, height: r.s(12)),
                SizedBox(height: r.s(4)),
                ShimmerBox(width: r.s(240), height: r.s(12)),
                SizedBox(height: r.s(16)),
                // Botão de ação
                ShimmerBox(
                  width: r.s(120),
                  height: r.s(36),
                  borderRadius: 20,
                ),
              ],
            ),
          ),
          // Tabs
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(16)),
            child: Row(
              children: [
                ShimmerBox(width: r.s(60), height: r.s(32), borderRadius: 16),
                SizedBox(width: r.s(8)),
                ShimmerBox(width: r.s(60), height: r.s(32), borderRadius: 16),
                SizedBox(width: r.s(8)),
                ShimmerBox(width: r.s(60), height: r.s(32), borderRadius: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton de um card de usuário para a grade do Explore.
class UserCardSkeleton extends StatelessWidget {
  const UserCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return ShimmerLoading(
      child: Container(
        decoration: BoxDecoration(
          color: context.nexusTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(16)),
        ),
        padding: EdgeInsets.all(r.s(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShimmerCircle(size: r.s(56)),
            SizedBox(height: r.s(8)),
            ShimmerBox(width: r.s(80), height: r.s(12)),
            SizedBox(height: r.s(4)),
            ShimmerBox(width: r.s(60), height: r.s(10)),
          ],
        ),
      ),
    );
  }
}

/// Skeleton de um item de notificação.
class NotificationItemSkeleton extends StatelessWidget {
  const NotificationItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return ShimmerLoading(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(10)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerCircle(size: r.s(44)),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: double.infinity, height: r.s(13)),
                  SizedBox(height: r.s(5)),
                  ShimmerBox(width: r.s(180), height: r.s(11)),
                  SizedBox(height: r.s(5)),
                  ShimmerBox(width: r.s(80), height: r.s(10)),
                ],
              ),
            ),
            SizedBox(width: r.s(8)),
            ShimmerBox(width: r.s(40), height: r.s(40), borderRadius: 8),
          ],
        ),
      ),
    );
  }
}

/// Lista de skeletons de feed (3-4 cards) para a tela global.
class GlobalFeedSkeleton extends StatelessWidget {
  final int count;
  const GlobalFeedSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, __) => const PostCardSkeleton(),
        childCount: count,
      ),
    );
  }
}

/// Lista de skeletons de notificações (5 itens).
class NotificationsListSkeleton extends StatelessWidget {
  final int count;
  const NotificationsListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, __) => const NotificationItemSkeleton(),
        childCount: count,
      ),
    );
  }
}

/// Lista de skeletons de chat (5 itens).
class ChatListSkeleton extends StatelessWidget {
  final int count;
  const ChatListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, __) => const ChatItemSkeleton(),
        childCount: count,
      ),
    );
  }
}

/// Grade de skeletons de usuário para o Explore (6 cards).
class ExploreUserGridSkeleton extends StatelessWidget {
  final int count;
  const ExploreUserGridSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return SliverPadding(
      padding: EdgeInsets.all(r.s(16)),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: r.s(10),
          mainAxisSpacing: r.s(10),
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, __) => const UserCardSkeleton(),
          childCount: count,
        ),
      ),
    );
  }
}
