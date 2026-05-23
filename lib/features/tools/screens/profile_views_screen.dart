/// Pantalla de "Quién vio tu perfil" en mploya.
///
/// Muestra un estado vacío cuando no hay vistas,
/// con un CTA para grabar un Video-Pitch.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

// ─── Screen ────────────────────────────────────────────────────────

class ProfileViewsScreen extends StatelessWidget {
  const ProfileViewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.white,
      appBar: AppBar(
        backgroundColor: MployaColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 20,
            color: MployaColors.orange,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Quién vio tu perfil',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MployaColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Eye-off Icon ─────────────────────────────
              Icon(
                Icons.visibility_off_outlined,
                size: 64,
                color: MployaColors.textTertiary.withValues(alpha: 0.3),
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    duration: 600.ms,
                    curve: Curves.easeOutBack,
                  ),

              const SizedBox(height: AppSpacing.lg),

              // ─── Title ────────────────────────────────────
              Text(
                'Aún nadie vio tu perfil',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MployaColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 200.ms),

              const SizedBox(height: AppSpacing.sm),

              // ─── Description ──────────────────────────────
              Text(
                'Graba un Video-Pitch increíble para atraer más vistas 🎬',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: MployaColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 350.ms),

              const SizedBox(height: AppSpacing.xl),

              // ─── CTA Button ───────────────────────────────
              MployaButton(
                label: 'Grabar Video-Pitch',
                onPressed: () => context.push('/onboarding/video'),
                expanded: false,
                icon: Icons.videocam_rounded,
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 500.ms)
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    duration: 500.ms,
                    delay: 500.ms,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
