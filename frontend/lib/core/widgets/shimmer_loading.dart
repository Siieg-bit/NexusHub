import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppTheme.cardColor : const Color(0xFFE0E0E8);
    final highlightColor =
        isDark ? AppTheme.cardColorLight : const Color(0xFFF5F5F8);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardColor : const Color(0xFFE0E0E8),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardColor : const Color(0xFFE0E0E8),
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
    return ShimmerLoading(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const ShimmerCircle(size: 40),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(width: 120, height: 14),
                    SizedBox(height: 6),
                    ShimmerBox(width: 80, height: 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Title
            const ShimmerBox(width: double.infinity, height: 18),
            const SizedBox(height: 8),
            // Body
            const ShimmerBox(width: double.infinity, height: 12),
            const SizedBox(height: 4),
            const ShimmerBox(width: 200, height: 12),
            const SizedBox(height: 16),
            // Image placeholder
            const ShimmerBox(
                width: double.infinity, height: 180, borderRadius: 12),
            const SizedBox(height: 16),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBox(width: 60, height: 24),
                ShimmerBox(width: 60, height: 24),
                ShimmerBox(width: 60, height: 24),
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
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const ShimmerCircle(size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(width: 160, height: 14),
                  SizedBox(height: 6),
                  ShimmerBox(width: 220, height: 10),
                ],
              ),
            ),
            const ShimmerBox(width: 40, height: 10),
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
    return ShimmerLoading(
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: const [
            ShimmerBox(width: 140, height: 80, borderRadius: 16),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: ShimmerBox(width: 100, height: 12),
            ),
            SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: ShimmerBox(width: 60, height: 10),
            ),
          ],
        ),
      ),
    );
  }
}
