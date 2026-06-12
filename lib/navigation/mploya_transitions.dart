import 'package:flutter/cupertino.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MployaPageTransitions — Custom page route with fade+slide transitions
//
// Usage:
//   Navigator.push(context, MployaPageRoute(
//     builder: (_) => ProfileScreen(userId: id),
//   ));
// ─────────────────────────────────────────────────────────────────────────────

/// A page route with a smoother fade+slide animation (vs. Cupertino's default).
class MployaPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  MployaPageRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0)
                  .animate(curvedAnimation),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.04),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}

/// A bottom-to-top modal-style route.
class MployaModalRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  MployaModalRoute({
    required this.builder,
    super.settings,
  }) : super(
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          opaque: true,
          barrierColor: const Color(0x80000000),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            );

            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );
          },
        );
}
