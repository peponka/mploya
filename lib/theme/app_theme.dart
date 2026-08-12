import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NexTheme {
  // FINAL_SCREENS palette
  static const Color brandAccent = Color(0xFF5B3DF5);
  static const Color brandAccentDark = Color(0xFF7C68FF);
  static const Color accentLight = Color(0xFFF1EEFF);
  static const Color accentDark = Color(0xFF3620B8);
  static const Color brandAccentSoft = Color(0xFFE9E4FF);
  static const Color brandOrange = Color(0xFFFF6B2C);
  static const Color brandOrangeSoft = Color(0xFFFFEEE5);
  static const Color brandMint = Color(0xFF18C58F);
  static const Color brandSky = Color(0xFF22A8F2);
  static const Color shellDark = Color(0xFF0D1120);
  static const Color shellDarkSoft = Color(0xFF151B2E);
  static const Color shellStrokeDark = Color(0xFF262E4A);
  static const Color shellBg = Color(0xFFF4F6FB);
  static const Color shellBgSoft = Color(0xFFEEF2F9);
  static const Color shellCard = Color(0xFFFFFFFF);
  static const Color shellStroke = Color(0xFFE7EBF4);

  static const Color premiumStart = Color(0xFF5B3DF5);
  static const Color premiumEnd = Color(0xFF8B6BFF);
  static const Color premiumGold = Color(0xFFF59E0B);
  static const Color premiumGoldSoft = Color(0xFFFEF3C7);
  static const Color premiumGoldBright = Color(0xFF5B3DF5);

  static const Color openToWork = Color(0xFF5B3DF5);
  static const Color hiring = Color(0xFF22A8F2);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF18C58F);
  static const Color info = Color(0xFF22A8F2);

  static const Color aiAccent = Color(0xFF6C3FC8);
  static const Color aiAccentLight = Color(0xFF9B6FE8);

  static const Color lightBg = shellBg;
  static const Color lightCard = shellCard;
  static const Color lightText = Color(0xFF10162A);
  static const Color lightSecondary = Color(0xFF64708B);
  static const Color lightTertiary = Color(0xFF98A2B3);
  static const Color lightDivider = shellStroke;
  static const Color lightNavBar = Color(0xF7FFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);

  static const Color darkBg = Color(0xFF090C17);
  static const Color darkCard = Color(0xFF141A2C);
  static const Color darkText = Color(0xFFF5F7FF);
  static const Color darkSecondary = Color(0xFFA6AEC8);
  static const Color darkTertiary = Color(0xFF75809D);
  static const Color darkDivider = Color(0xFF27304A);
  static const Color darkNavBar = Color(0xF50C1020);
  static const Color darkSurface = Color(0xFF0F1425);

  static const double spaceXXS = 2;
  static const double spaceXS = 4;
  static const double spaceSM = 8;
  static const double spaceMD = 12;
  static const double spaceLG = 16;
  static const double spaceXL = 24;
  static const double spaceXXL = 32;
  static const double spaceHuge = 48;

  static const double radiusSM = 10;
  static const double radiusMD = 14;
  static const double radiusLG = 18;
  static const double radiusXL = 24;
  static const double radiusXXL = 32;
  static const double radiusPill = 999;

  static List<BoxShadow> get cardShadowLight => [
        BoxShadow(
          color: const Color(0xFF131A2B).withValues(alpha: 0.05),
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
      ];

  static List<BoxShadow> get cardShadowDark => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.34),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ];

  static List<BoxShadow> get accentGlow => [
        BoxShadow(
          color: brandAccent.withValues(alpha: 0.25),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

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

  static LinearGradient get brandGradient => const LinearGradient(
        colors: [Color(0xFF5B3DF5), Color(0xFF7C68FF)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  static LinearGradient get accentGradient => const LinearGradient(
        colors: [Color(0xFFFF7C45), Color(0xFFFF5E2B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get shellGradient => const LinearGradient(
        colors: [Color(0xFFF8FAFF), Color(0xFFF1F4FB)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  static BoxDecoration gradientButtonDecoration({
    double borderRadius = radiusPill,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
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
  }

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
            fontWeight: FontWeight.w700,
            color: lightText,
            letterSpacing: -0.3,
          ),
          navLargeTitleTextStyle: TextStyle(
            fontFamily: '.SF Pro Display',
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: lightText,
            letterSpacing: -1.0,
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
            fontWeight: FontWeight.w700,
            color: darkText,
            letterSpacing: -0.3,
          ),
          navLargeTitleTextStyle: TextStyle(
            fontFamily: '.SF Pro Display',
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: darkText,
            letterSpacing: -1.0,
          ),
        ),
      );
}

typedef MployaTheme = NexTheme;

extension NexContext on BuildContext {
  bool get isDark => CupertinoTheme.brightnessOf(this) == Brightness.dark;

  Color get cardColor => isDark ? NexTheme.darkCard : NexTheme.lightCard;

  Color get bgColor => isDark ? NexTheme.darkBg : NexTheme.lightBg;

  Color get surfaceColor =>
      isDark ? NexTheme.darkSurface : NexTheme.lightSurface;

  Color get textPrimary => isDark ? NexTheme.darkText : NexTheme.lightText;

  Color get textSecondary =>
      isDark ? NexTheme.darkSecondary : NexTheme.lightSecondary;

  Color get textTertiary =>
      isDark ? NexTheme.darkTertiary : NexTheme.lightTertiary;

  Color get dividerColor =>
      isDark ? NexTheme.darkDivider : NexTheme.lightDivider;

  Color get brandAccent =>
      isDark ? NexTheme.brandAccentDark : NexTheme.brandAccent;

  Color get primaryAccent => brandAccent;

  Color get shellBorder =>
      isDark ? NexTheme.shellStrokeDark : NexTheme.shellStroke;

  Color get shellSidebar =>
      isDark ? NexTheme.shellDark : const Color(0xFFFFFFFF);

  Color get shellSidebarSecondary =>
      isDark ? NexTheme.shellDarkSoft : const Color(0xFFF9FAFD);

  Color get glassColor => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.white.withValues(alpha: 0.78);

  Color get glassBorder => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFFFFFFF).withValues(alpha: 0.75);

  LinearGradient get primaryGradient => NexTheme.brandGradient;

  LinearGradient get shellGradient => isDark
      ? const LinearGradient(
          colors: [Color(0xFF090C17), Color(0xFF0F1425)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )
      : NexTheme.shellGradient;

  List<BoxShadow> get cardShadow =>
      isDark ? NexTheme.cardShadowDark : NexTheme.cardShadowLight;
}
