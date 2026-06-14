import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DoubleTapHeart — TikTok/Instagram-style animated heart on double-tap
//
// Usage:
//   DoubleTapHeartOverlay(
//     onDoubleTap: () => _handleLike(),
//     child: VideoPlayer(),
//   )
// ─────────────────────────────────────────────────────────────────────────────

class DoubleTapHeartOverlay extends StatefulWidget {
  /// Called when the user double-taps.
  final VoidCallback? onDoubleTap;

  /// Single tap passthrough.
  final VoidCallback? onSingleTap;

  /// The content below the overlay.
  final Widget child;

  /// Set to false (web/desktop) to disable double-tap waiting so single-tap fires immediately.
  final bool enableDoubleTap;

  const DoubleTapHeartOverlay({
    super.key,
    this.onDoubleTap,
    this.onSingleTap,
    this.enableDoubleTap = true,
    required this.child,
  });

  @override
  State<DoubleTapHeartOverlay> createState() => _DoubleTapHeartOverlayState();
}

class _DoubleTapHeartOverlayState extends State<DoubleTapHeartOverlay>
    with TickerProviderStateMixin {
  final List<_HeartParticle> _particles = [];
  int _idCounter = 0;

  void _handleDoubleTap(TapDownDetails? details) {
    widget.onDoubleTap?.call();

    // Spawn heart at tap position
    final pos = details?.localPosition ?? const Offset(200, 400);
    final id = _idCounter++;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    final particle = _HeartParticle(
      id: id,
      position: pos,
      controller: controller,
    );

    setState(() => _particles.add(particle));

    controller.forward().then((_) {
      if (mounted) {
        setState(() => _particles.removeWhere((p) => p.id == id));
      }
      controller.dispose();
    });
  }

  @override
  void dispose() {
    for (final p in _particles) {
      p.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onSingleTap,
      onDoubleTapDown: widget.enableDoubleTap ? (details) => _handleDoubleTap(details) : null,
      onDoubleTap: widget.enableDoubleTap ? () {} : null, // Required for onDoubleTapDown to fire
      child: Stack(
        children: [
          widget.child,
          // Render all active particles
          ..._particles.map((p) => _AnimatedHeart(particle: p)),
        ],
      ),
    );
  }
}

class _HeartParticle {
  final int id;
  final Offset position;
  final AnimationController controller;

  _HeartParticle({
    required this.id,
    required this.position,
    required this.controller,
  });
}

class _AnimatedHeart extends StatelessWidget {
  final _HeartParticle particle;

  const _AnimatedHeart({required this.particle});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: particle.controller,
      builder: (context, child) {
        final t = particle.controller.value;

        // Scale: grow fast then shrink
        final scale = t < 0.3
            ? Curves.elasticOut.transform(t / 0.3) * 1.3
            : 1.3 - (t - 0.3) * 0.8;

        // Opacity: fully visible then fade
        final opacity = t < 0.6 ? 1.0 : (1.0 - (t - 0.6) / 0.4).clamp(0.0, 1.0);

        // Float upward
        final yOffset = -t * 60;

        return Positioned(
          left: particle.position.dx - 40,
          top: particle.position.dy - 40 + yOffset,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale.clamp(0.0, 2.0),
              child: const _HeartIcon(),
            ),
          ),
        );
      },
    );
  }
}

class _HeartIcon extends StatelessWidget {
  const _HeartIcon();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          MployaTheme.brandAccent,
          MployaTheme.brandAccent.withValues(alpha: 0.7),
          const Color(0xFFFFD60A),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: const Icon(
        CupertinoIcons.hand_thumbsup_fill,
        size: 80,
        color: Colors.white,
      ),
    );
  }
}
