import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FeatureHint — One-time tooltip overlays that teach hidden gestures
//
// Shows a pill badge with a gesture hint on the first time a user sees it.
// Usage:
//   FeatureHint(
//     hintKey: 'double_tap_interest',
//     icon: CupertinoIcons.hand_point_right_fill,
//     text: 'Tocá dos veces para mostrar interés',
//     child: myWidget,
//   )
// ─────────────────────────────────────────────────────────────────────────────

class FeatureHint extends StatefulWidget {
  /// Unique key to track if the hint has been shown before.
  final String hintKey;

  /// Icon to display in the hint badge.
  final IconData icon;

  /// Short instructional text.
  final String text;

  /// Optional: position the hint relative to the child.
  /// Defaults to [Alignment.topCenter].
  final Alignment alignment;

  /// The child widget to show the hint on top of.
  final Widget child;

  /// Delay before showing the hint (allows the screen to settle).
  final Duration delay;

  const FeatureHint({
    super.key,
    required this.hintKey,
    required this.icon,
    required this.text,
    required this.child,
    this.alignment = Alignment.topCenter,
    this.delay = const Duration(seconds: 2),
  });

  @override
  State<FeatureHint> createState() => _FeatureHintState();
}

class _FeatureHintState extends State<FeatureHint>
    with SingleTickerProviderStateMixin {
  bool _show = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _checkAndShow();
  }

  Future<void> _checkAndShow() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'feature_hint_${widget.hintKey}';
    if (prefs.getBool(key) == true) return; // Already shown

    // Wait for delay
    await Future.delayed(widget.delay);
    if (!mounted) return;

    setState(() => _show = true);
    _controller.forward();

    // Auto-dismiss after 5 seconds
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    _dismiss();
  }

  void _dismiss() async {
    if (!_show) return;
    await _controller.reverse();
    if (!mounted) return;
    setState(() => _show = false);

    // Mark as shown
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('feature_hint_${widget.hintKey}', true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_show)
          Positioned.fill(
            child: Align(
              alignment: widget.alignment,
              child: GestureDetector(
                onTap: _dismiss,
                child: SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Semantics(
                      liveRegion: true,
                      label: widget.text,
                      child: _HintBadge(
                        icon: widget.icon,
                        text: widget.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HintBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HintBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xE01C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MployaTheme.brandAccent.withValues(alpha: 0.3),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: MployaTheme.brandAccent.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: MployaTheme.brandAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: MployaTheme.brandAccent),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            CupertinoIcons.xmark_circle_fill,
            size: 16,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

/// Pre-defined feature discovery hints for Mploya.
/// Usage: FeatureHints.doubleTapInterest(child: myWidget)
class FeatureHints {
  FeatureHints._();

  /// Hint for double-tap to show interest on the feed
  static Widget doubleTapInterest({required Widget child}) {
    return FeatureHint(
      hintKey: 'double_tap_interest',
      icon: CupertinoIcons.hand_draw_fill,
      text: AppStrings.hintDoubleTap,
      alignment: Alignment.center,
      child: child,
    );
  }

  /// Hint for long-press on reactions
  static Widget longPressReactions({required Widget child}) {
    return FeatureHint(
      hintKey: 'long_press_reactions',
      icon: CupertinoIcons.smiley_fill,
      text: AppStrings.hintLongPressReactions,
      alignment: Alignment.bottomCenter,
      delay: const Duration(seconds: 4),
      child: child,
    );
  }

  /// Hint for swipe down to refresh
  static Widget swipeDownRefresh({required Widget child}) {
    return FeatureHint(
      hintKey: 'swipe_down_refresh',
      icon: CupertinoIcons.arrow_2_circlepath,
      text: AppStrings.hintSwipeRefresh,
      alignment: Alignment.topCenter,
      delay: const Duration(seconds: 6),
      child: child,
    );
  }

  /// Hint for share long-press → Nexus
  static Widget longPressShare({required Widget child}) {
    return FeatureHint(
      hintKey: 'long_press_share_nexus',
      icon: CupertinoIcons.bolt_fill,
      text: AppStrings.hintLongPressNexus,
      alignment: Alignment.bottomCenter,
      delay: const Duration(seconds: 5),
      child: child,
    );
  }

  /// Hint for swipe left on saved jobs to delete
  static Widget swipeToDelete({required Widget child}) {
    return FeatureHint(
      hintKey: 'swipe_to_delete',
      icon: CupertinoIcons.trash,
      text: AppStrings.hintSwipeDelete,
      alignment: Alignment.topCenter,
      delay: const Duration(seconds: 3),
      child: child,
    );
  }
}
