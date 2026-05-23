/// Sistema de diseño de mploya.ai
///
/// Paleta naranja + blanco, estilo moderno/clean, mobile-first.
/// Basado en el diseño original de la app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Colores de la marca ─────────────────────────────────────────────

/// Colores principales de mploya.ai
abstract final class MployaColors {
  // Primario - Naranja
  static const orange = Color(0xFFF97316);
  static const orangeDark = Color(0xFFEA580C);
  static const orangeLight = Color(0xFFFB923C);
  static const orangeSurface = Color(0xFFFFF7ED);

  // Fondo
  static const white = Color(0xFFFFFFFF);
  static const background = Color(0xFFFAFAFA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF5F5F5);

  // Texto
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
  static const textOnOrange = Color(0xFFFFFFFF);

  // Bordes
  static const border = Color(0xFFE5E7EB);
  static const borderLight = Color(0xFFF3F4F6);
  static const borderFocus = Color(0xFFF97316);

  // Acentos
  static const teal = Color(0xFF10B981);
  static const tealLight = Color(0xFFD1FAE5);
  static const red = Color(0xFFEF4444);
  static const redLight = Color(0xFFFEE2E2);
  static const blue = Color(0xFF3B82F6);

  // Social
  static const google = Color(0xFF4285F4);
  static const apple = Color(0xFF000000);

  // Gradientes
  static const orangeGradient = LinearGradient(
    colors: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const orangeGradientVertical = LinearGradient(
    colors: [Color(0xFFFB923C), Color(0xFFF97316)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const subtleGradient = LinearGradient(
    colors: [Color(0xFFF9FAFB), Color(0xFFFFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// ─── Espaciado ───────────────────────────────────────────────────────

abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 56;
  static const double huge = 72;
}

// ─── Radios ──────────────────────────────────────────────────────────

abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 100;
  static const double full = 999;
}

// ─── Elevación ───────────────────────────────────────────────────────

abstract final class AppElevation {
  static const double none = 0;
  static const double sm = 1;
  static const double md = 4;
  static const double lg = 8;
  static const double xl = 16;
}

// ─── Tamaños de íconos ──────────────────────────────────────────────

abstract final class AppIconSize {
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;
  static const double xxl = 64;
  static const double logo = 80;
}

// ─── Duraciones de animación ─────────────────────────────────────────

abstract final class AnimDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
  static const splash = Duration(milliseconds: 2000);
}

// ─── Tema principal ──────────────────────────────────────────────────

ThemeData buildMployaTheme() {
  final textTheme = GoogleFonts.interTextTheme();

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Colores
    colorScheme: const ColorScheme.light(
      primary: MployaColors.orange,
      onPrimary: MployaColors.textOnOrange,
      primaryContainer: MployaColors.orangeSurface,
      onPrimaryContainer: MployaColors.orangeDark,
      secondary: MployaColors.teal,
      onSecondary: Colors.white,
      surface: MployaColors.surface,
      onSurface: MployaColors.textPrimary,
      onSurfaceVariant: MployaColors.textSecondary,
      outline: MployaColors.border,
      outlineVariant: MployaColors.borderLight,
      error: MployaColors.red,
      onError: Colors.white,
    ),

    scaffoldBackgroundColor: MployaColors.white,

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: MployaColors.white,
      foregroundColor: MployaColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: MployaColors.textPrimary,
      ),
    ),

    // Texto
    textTheme: textTheme.copyWith(
      displayLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: MployaColors.textPrimary,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: MployaColors.textPrimary,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: MployaColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: MployaColors.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: MployaColors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: MployaColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: MployaColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: MployaColors.textSecondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: MployaColors.textTertiary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: MployaColors.textOnOrange,
      ),
    ),

    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: const BorderSide(color: MployaColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: const BorderSide(color: MployaColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: const BorderSide(color: MployaColors.orange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: const BorderSide(color: MployaColors.red),
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 15,
        color: MployaColors.textTertiary,
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 15,
        color: MployaColors.textSecondary,
      ),
    ),

    // Botones
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MployaColors.orange,
        foregroundColor: MployaColors.textOnOrange,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MployaColors.textPrimary,
        side: const BorderSide(color: MployaColors.border),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: MployaColors.orange,
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MployaColors.orange,
        foregroundColor: MployaColors.textOnOrange,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Bottom Sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: MployaColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      showDragHandle: true,
      dragHandleColor: MployaColors.border,
    ),

    // Card
    cardTheme: CardThemeData(
      color: MployaColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: MployaColors.borderLight),
      ),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: MployaColors.borderLight,
      thickness: 1,
      space: 0,
    ),

    // BottomNavigationBar
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: MployaColors.white,
      selectedItemColor: MployaColors.orange,
      unselectedItemColor: MployaColors.textTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: MployaColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
    ),
  );
}

// ─── Widget helpers ──────────────────────────────────────────────────

/// Botón primario con gradiente naranja (estilo mploya)
class MployaButton extends StatelessWidget {
  const MployaButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: expanded ? double.infinity : null,
      height: 52,
      decoration: BoxDecoration(
        gradient: onPressed != null ? MployaColors.orangeGradient : null,
        color: onPressed == null ? MployaColors.border : null,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const Text(
                        '→',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    return child;
  }
}

/// Botón social (Google, Apple, Email)
class SocialButton extends StatelessWidget {
  const SocialButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isDark = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? MployaColors.apple : MployaColors.white,
          foregroundColor:
              isDark ? Colors.white : MployaColors.textPrimary,
          side: BorderSide(
            color: isDark ? MployaColors.apple : MployaColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Divider con texto centrado ("o entrá con", "o continúa con")
class OrDivider extends StatelessWidget {
  const OrDivider({this.text = 'o continúa con', super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: MployaColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MployaColors.textTertiary,
            ),
          ),
        ),
        const Expanded(child: Divider(color: MployaColors.border)),
      ],
    );
  }
}

/// Logo de mploya.ai
class MployaLogo extends StatelessWidget {
  const MployaLogo({this.size = AppIconSize.logo, super.key});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ícono del logo
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: MployaColors.orangeGradientVertical,
            borderRadius: BorderRadius.circular(size * 0.25),
          ),
          child: Center(
            child: Text(
              'm',
              style: GoogleFonts.outfit(
                fontSize: size * 0.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Nombre
        Text(
          'mploya.ai',
          style: GoogleFonts.outfit(
            fontSize: size * 0.3,
            fontWeight: FontWeight.w700,
            color: MployaColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Tagline
        Text(
          'Mutea el papel. Dale Play a tu carrera.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: MployaColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// Widget de estado vacío reutilizable
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppIconSize.xxl,
              color: MployaColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: MployaColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                description!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MployaColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              MployaButton(
                label: actionLabel!,
                onPressed: onAction,
                expanded: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
