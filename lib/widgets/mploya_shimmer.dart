import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MployaShimmer — Skeleton loading placeholder with shimmer animation
//
// Usage:
//   MployaShimmer.feedCard()        — Full-screen feed placeholder
//   MployaShimmer.profileHeader()   — Profile top section
//   MployaShimmer.listTile()        — Single list row
//   MployaShimmer.card()            — Generic card placeholder
//   MployaShimmer.inbox()           — Messaging inbox placeholder
//
// Or build custom:
//   ShimmerBox(width: 120, height: 16)
// ─────────────────────────────────────────────────────────────────────────────

/// A single shimmer-animated rectangle placeholder.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final baseColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8E8ED);
    final shimmerColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF5F5F7);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(1.0 + 2.0 * _controller.value, 0),
              colors: [baseColor, shimmerColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// A circular shimmer placeholder (for avatars).
class ShimmerCircle extends StatefulWidget {
  final double size;

  const ShimmerCircle({super.key, this.size = 48});

  @override
  State<ShimmerCircle> createState() => _ShimmerCircleState();
}

class _ShimmerCircleState extends State<ShimmerCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final baseColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8E8ED);
    final shimmerColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF5F5F7);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(1.0 + 2.0 * _controller.value, 0),
              colors: [baseColor, shimmerColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Pre-built shimmer layouts for common Mploya screens.
class MployaShimmer {
  MployaShimmer._();

  /// Full-screen feed card skeleton (mimics a TikTok reel loading).
  static Widget feedCard() {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Spacer(),
          Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Row(
              children: [
                ShimmerCircle(size: 44),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 140, height: 14),
                    SizedBox(height: 6),
                    ShimmerBox(width: 90, height: 11),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 16, bottom: 6),
            child: ShimmerBox(width: 220, height: 12),
          ),
          Padding(
            padding: EdgeInsets.only(left: 16, bottom: 6),
            child: ShimmerBox(width: 160, height: 12),
          ),
          Padding(
            padding: EdgeInsets.only(left: 16, bottom: 16),
            child: Row(
              children: [
                ShimmerBox(width: 60, height: 24, borderRadius: 12),
                SizedBox(width: 8),
                ShimmerBox(width: 70, height: 24, borderRadius: 12),
                SizedBox(width: 8),
                ShimmerBox(width: 50, height: 24, borderRadius: 12),
              ],
            ),
          ),
          SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Profile header skeleton.
  static Widget profileHeader() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          ShimmerCircle(size: 80),
          SizedBox(height: 16),
          ShimmerBox(width: 160, height: 18),
          SizedBox(height: 8),
          ShimmerBox(width: 200, height: 13),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatShimmer(),
              _StatShimmer(),
              _StatShimmer(),
            ],
          ),
        ],
      ),
    );
  }

  /// Single list tile skeleton (for inbox, saved jobs, etc).
  static Widget listTile({int count = 1}) {
    return Column(
      children: List.generate(count, (_) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ShimmerCircle(size: 48),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 140, height: 14),
                  SizedBox(height: 6),
                  ShimmerBox(height: 11),
                ],
              ),
            ),
            SizedBox(width: 12),
            ShimmerBox(width: 50, height: 11),
          ],
        ),
      )),
    );
  }

  /// Generic card skeleton.
  static Widget card() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 180, height: 16),
          SizedBox(height: 10),
          ShimmerBox(height: 12),
          SizedBox(height: 6),
          ShimmerBox(width: 250, height: 12),
          SizedBox(height: 14),
          Row(
            children: [
              ShimmerBox(width: 70, height: 26, borderRadius: 13),
              SizedBox(width: 8),
              ShimmerBox(width: 80, height: 26, borderRadius: 13),
            ],
          ),
        ],
      ),
    );
  }

  /// Inbox/messaging skeleton.
  static Widget inbox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Story row shimmer
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => const Column(
              children: [
                ShimmerCircle(size: 56),
                SizedBox(height: 6),
                ShimmerBox(width: 40, height: 10),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Message list shimmer
        listTile(count: 8),
      ],
    );
  }
}

class _StatShimmer extends StatelessWidget {
  const _StatShimmer();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ShimmerBox(width: 36, height: 20),
        SizedBox(height: 4),
        ShimmerBox(width: 50, height: 11),
      ],
    );
  }
}
