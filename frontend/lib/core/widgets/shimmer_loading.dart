import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
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
    final r = context.r;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? context.cardBg : const Color(0xFFE0E0E8);
    final highlightColor =
        isDark ? context.cardBgLight : const Color(0xFFF5F5F8);

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
    final r = context.r;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? context.cardBg : const Color(0xFFE0E0E8),
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
    final r = context.r;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? context.cardBg : const Color(0xFFE0E0E8),
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
          color: context.cardBg,
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
          color: context.cardBg,
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
