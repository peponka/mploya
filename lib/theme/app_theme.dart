import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MPLOYA — Design System
// ─────────────────────────────────────────────────────────────────────────────

class NexTheme {
  // ──── Brand Colors (Warm Orange — refined #F97316) ────
  static const Color brandAccent = Color(0xFFF97316); // Warm Orange (Tailwind 500)
  static const Color brandAccentDark = Color(0xFFFB923C); // Lighter for dark mode
  static const Color accentLight = Color(0xFFFFF7ED); // Orange-50 tint
  static const Color accentDark = Color(0xFF9A3412); // Orange-800 deep

  // Premium gradient endpoints
  static const Color premiumStart = Color(0xFFF97316);
  static const Color premiumEnd = Color(0xFFFB923C);
  static const Color premiumGold = Color(0xFFF59E0B);
  static const Color premiumGoldSoft = Color(0xFFFEF3C7);
  static const Color premiumGoldBright = Color(0xFFEA580C);

  // Semantic
  static const Color openToWork = Color(0xFFF97316);
  static const Color hiring = Color(0xFF3B82F6);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF3B82F6);

  // ──── Light Mode (Ultra-clean iOS Style) ────
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF000000);
  static const Color lightSecondary = Color(0xFF6C6C70);
  static const Color lightTertiary = Color(0xFFAEAEB2);
  static const Color lightDivider = Color(0xFFE5E5EA);
  static const Color lightNavBar = Color(0xF8FFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);

  // ──── Dark Mode (Deeper blacks — primary mode per prompt) ────
  static const Color darkBg = Color(0xFF000000);
  static const Color darkCard = Color(0xFF1C1E26);
  static const Color darkText = Color(0xFFE7E9EA);
  static const Color darkSecondary = Color(0xFF71767B);
  static const Color darkTertiary = Color(0xFF536471);
  static const Color darkDivider = Color(0xFF2F3336);
  static const Color darkNavBar = Color(0xF5000000);
  static const Color darkSurface = Color(0xFF1E2030);

  // ──── Spacing (8pt grid) ────
  static const double spaceXXS = 2;
  static const double spaceXS = 4;
  static const double spaceSM = 8;
  static const double spaceMD = 12;
  static const double spaceLG = 16;
  static const double spaceXL = 24;
  static const double spaceXXL = 32;
  static const double spaceHuge = 48;

  // ──── Radii ────
  static const double radiusSM = 10;
  static const double radiusMD = 14;
  static const double radiusLG = 18;
  static const double radiusXL = 24;
  static const double radiusXXL = 32;
  static const double radiusPill = 999;

  // ──── Shadows (tinted, not pure black) ────
  static List<BoxShadow> get cardShadowLight => [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.03),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get cardShadowDark => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.30),
      blurRadius: 20,
      offset: const Offset(0, 6),
      spreadRadius: 0,
    ),
  ];

  // ──── Premium Glow Shadows ────
  static List<BoxShadow> get accentGlow => [
    BoxShadow(
      color: brandAccent.withValues(alpha: 0.25),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  // ──── Brand Gradient ────
  static LinearGradient get brandGradient => const LinearGradient(
    colors: [Color(0xFFF97316), Color(0xFFFBBF24)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static BoxDecoration gradientButtonDecoration({
    double borderRadius = radiusPill,
    List<BoxShadow>? shadows,
  }) =>
      BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: brandAccent.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
      );

  // ──── Glassmorphism Helpers ────
  static BoxDecoration glassDecoration({
    Color? color,
    double opacity = 0.7,
    double borderRadius = radiusLG,
    double borderOpacity = 0.05,
  }) {
    return BoxDecoration(
      color: (color ?? Colors.white).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: borderOpacity),
        width: 0.5,
      ),
    );
  }

  static Widget glassContainer({
    required Widget child,
    double sigmaX = 20,
    double sigmaY = 20,
    Color? color,
    double opacity = 0.7,
    double borderRadius = radiusLG,
    EdgeInsetsGeometry? padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: Container(
          padding: padding,
          decoration: glassDecoration(
            color: color,
            opacity: opacity,
            borderRadius: borderRadius,
          ),
          child: child,
        ),
      ),
    );
  }

  // ──── Gold Glow Shadows ────
  static List<BoxShadow> get goldGlow => [
    BoxShadow(
      color: premiumGold.withValues(alpha: 0.30),
      blurRadius: 24,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: premiumGold.withValues(alpha: 0.10),
      blurRadius: 60,
      spreadRadius: 5,
    ),
  ];

  // ──── Dark Glass Decoration (for dark mode overlays) ────
  static BoxDecoration darkGlassDecoration({
    double borderRadius = radiusLG,
    double opacity = 0.12,
  }) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.08),
        width: 0.5,
      ),
    );
  }

  // ──── CupertinoThemeData ────
  static CupertinoThemeData get lightTheme => const CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: brandAccent,
    primaryContrastingColor: Colors.white,
    scaffoldBackgroundColor: lightBg,
    barBackgroundColor: lightNavBar,
    textTheme: CupertinoTextThemeData(
      primaryColor: brandAccent,
      textStyle: TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 16,
        color: lightText,
        letterSpacing: -0.2,
      ),
      navTitleTextStyle: TextStyle(
        fontFamily: '.SF Pro Display',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: lightText,
        letterSpacing: -0.3,
      ),
      navLargeTitleTextStyle: TextStyle(
        fontFamily: '.SF Pro Display',
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: lightText,
        letterSpacing: -0.8,
      ),
    ),
  );

  static CupertinoThemeData get darkTheme => const CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: brandAccentDark,
    primaryContrastingColor: Colors.black,
    scaffoldBackgroundColor: darkBg,
    barBackgroundColor: darkNavBar,
    textTheme: CupertinoTextThemeData(
      primaryColor: brandAccentDark,
      textStyle: TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 16,
        color: darkText,
        letterSpacing: -0.2,
      ),
      navTitleTextStyle: TextStyle(
        fontFamily: '.SF Pro Display',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: darkText,
        letterSpacing: -0.3,
      ),
      navLargeTitleTextStyle: TextStyle(
        fontFamily: '.SF Pro Display',
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: darkText,
        letterSpacing: -0.8,
      ),
    ),
  );
}

// ──── Backward-compatibility typedef ────
// Allows existing code referencing MployaTheme to keep working.
typedef MployaTheme = NexTheme;

// ──── Extension for easy theme access ────
extension NexContext on BuildContext {
  bool get isDark =>
      CupertinoTheme.brightnessOf(this) == Brightness.dark;

  Color get cardColor =>
      isDark ? NexTheme.darkCard : NexTheme.lightCard;

  Color get bgColor =>
      isDark ? NexTheme.darkBg : NexTheme.lightBg;

  Color get surfaceColor =>
      isDark ? NexTheme.darkSurface : NexTheme.lightSurface;

  Color get textPrimary =>
      isDark ? NexTheme.darkText : NexTheme.lightText;

  Color get textSecondary =>
      isDark ? NexTheme.darkSecondary : NexTheme.lightSecondary;

  Color get textTertiary =>
      isDark ? NexTheme.darkTertiary : NexTheme.lightTertiary;

  Color get dividerColor =>
      isDark ? NexTheme.darkDivider : NexTheme.lightDivider;

  Color get brandAccent =>
      isDark ? NexTheme.brandAccentDark : NexTheme.brandAccent;

  List<BoxShadow> get cardShadow =>
      isDark ? NexTheme.cardShadowDark : NexTheme.cardShadowLight;
}

// Backward-compatibility — existing code uses `MployaContext`
// The new canonical name is `NexContext`. Since Dart doesn't allow
// duplicate extension methods, we use a simple typedef-like alias
// via re-export. All call sites using `context.isDark`, `context.cardColor`,
// etc. resolve to NexContext automatically.
