import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// In-app coach mark tooltips that appear once per feature.
/// Usage: Wrap any widget with CoachMark to show a contextual tip.
///
/// Example:
///   CoachMark(
///     id: 'jobs_bookmark',
///     message: 'Tocá para guardar esta vacante',
///     child: Icon(CupertinoIcons.bookmark),
///   )
class CoachMark extends StatefulWidget {
  final String id;
  final String message;
  final Widget child;
  final CoachMarkPosition position;

  const CoachMark({
    super.key,
    required this.id,
    required this.message,
    required this.child,
    this.position = CoachMarkPosition.bottom,
  });

  @override
  State<CoachMark> createState() => _CoachMarkState();
}

enum CoachMarkPosition { top, bottom }

class _CoachMarkState extends State<CoachMark> with SingleTickerProviderStateMixin {
  bool _visible = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: Offset(0, widget.position == CoachMarkPosition.bottom ? -0.3 : 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _checkVisibility();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'coach_mark_${widget.id}';
    if (prefs.getBool(key) == true) return;

    // Small delay so the widget tree is settled
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _visible = true);
      _animCtrl.forward();

      // Auto-dismiss after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _visible) _dismiss();
      });
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('coach_mark_${widget.id}', true);
    if (mounted) {
      await _animCtrl.reverse();
      setState(() => _visible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          left: -8,
          right: -8,
          top: widget.position == CoachMarkPosition.bottom ? null : -60,
          bottom: widget.position == CoachMarkPosition.bottom ? -60 : null,
          child: SlideTransition(
            position: _slideAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: GestureDetector(
                onTap: _dismiss,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.lightbulb_fill, size: 14, color: MployaTheme.brandAccent),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(CupertinoIcons.xmark, size: 12, color: Color(0xFFAEAEB2)),
                    ],
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

/// A simpler banner-style coach mark that appears at the top of a screen.
/// Shows once per [id], then auto-dismisses.
class CoachBanner extends StatefulWidget {
  final String id;
  final String title;
  final String message;
  final IconData icon;

  const CoachBanner({
    super.key,
    required this.id,
    required this.title,
    required this.message,
    this.icon = CupertinoIcons.lightbulb_fill,
  });

  @override
  State<CoachBanner> createState() => _CoachBannerState();
}

class _CoachBannerState extends State<CoachBanner>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _check();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'coach_banner_${widget.id}';
    if (prefs.getBool(key) == true) return;
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _visible = true);
      _ctrl.forward();
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('coach_banner_${widget.id}', true);
    if (mounted) {
      await _ctrl.reverse();
      setState(() => _visible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fade,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: MployaTheme.brandAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, size: 16, color: MployaTheme.brandAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E8E93),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _dismiss,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(CupertinoIcons.xmark_circle_fill, size: 18, color: Color(0xFFD1D1D6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
