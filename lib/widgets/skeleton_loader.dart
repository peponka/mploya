import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
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
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final baseColor = isDark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFE8E8E8);
    final shimmerColor = isDark
        ? const Color(0xFF4A4A4A)
        : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, shimmerColor, baseColor],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MployaTheme.spaceLG),
      margin: const EdgeInsets.only(bottom: MployaTheme.spaceSM),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(MployaTheme.radiusMD),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonLoader(width: 48, height: 48, borderRadius: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(width: 140, height: 14),
                    SizedBox(height: 6),
                    SkeletonLoader(width: 100, height: 12),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          SkeletonLoader(height: 14),
          SizedBox(height: 8),
          SkeletonLoader(height: 14),
          SizedBox(height: 8),
          SkeletonLoader(width: 200, height: 14),
          SizedBox(height: 16),
          SkeletonLoader(height: 200, borderRadius: 12),
        ],
      ),
    );
  }
}

class ConnectionCardSkeleton extends StatelessWidget {
  const ConnectionCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(MployaTheme.radiusMD),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SkeletonLoader(width: 64, height: 64, borderRadius: 32),
          SizedBox(height: 12),
          SkeletonLoader(width: 100, height: 14),
          SizedBox(height: 6),
          SkeletonLoader(width: 80, height: 12),
          SizedBox(height: 12),
          SkeletonLoader(width: 120, height: 32, borderRadius: 16),
        ],
      ),
    );
  }
}

class NetworkListSkeleton extends StatelessWidget {
  const NetworkListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(MployaTheme.radiusMD),
            ),
            child: const Row(
              children: [
                SkeletonLoader(width: 52, height: 52, borderRadius: 26),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 140, height: 14),
                      SizedBox(height: 8),
                      SkeletonLoader(width: 200, height: 12),
                    ],
                  ),
                ),
                SkeletonLoader(width: 70, height: 28, borderRadius: 14),
              ],
            ),
          ),
        ),
        childCount: 5,
      ),
    );
  }
}
