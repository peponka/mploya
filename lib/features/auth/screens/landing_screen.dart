/// Pantalla de bienvenida / landing de mploya.ai
///
/// Muestra el logo, tagline, selector de rol (Candidato / Confidencial / Empresa)
/// y opciones de login social. Al seleccionar un rol, abre el bottom sheet
/// de autenticación.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

/// Roles disponibles en la app.
enum UserRole { candidato, confidencial, empresa }

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _onRoleSelected(BuildContext context, UserRole role) {
    // ── MODO DEMO: Ir directo al formulario sin auth ──
    final path = switch (role) {
      UserRole.candidato => '/onboarding/candidato',
      UserRole.confidencial => '/onboarding/confidencial',
      UserRole.empresa => '/onboarding/empresa',
    };
    context.go(path);
  }

  void _onSocialLogin(BuildContext context, String provider) {
    if (provider == 'apple') {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Próximamente disponible'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF6366F1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    // ── MODO DEMO: Ir directo al home ──
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.xxl,
              bottom: bottomPadding + AppSpacing.md,
            ),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xxxl),

                // ── Logo ──
                const MployaLogo(size: 90)
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      duration: 600.ms,
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: AppSpacing.huge),

                // ── Pregunta ──
                Text(
                  '¿Cómo querés usar Mploya?',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: MployaColors.textPrimary,
                  ),
                ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: AppSpacing.lg),

                // ── Botón Soy Candidato (primario, naranja) ──
                _RoleButton(
                  label: 'Soy Candidato',
                  icon: Icons.person_rounded,
                  isPrimary: true,
                  onTap: () => _onRoleSelected(context, UserRole.candidato),
                ).animate(delay: 400.ms).fadeIn(duration: 400.ms).slideY(
                      begin: 0.2,
                      end: 0,
                      duration: 400.ms,
                      curve: Curves.easeOut,
                    ),

                const SizedBox(height: AppSpacing.sm),

                // ── Botón Candidato Confidencial ──
                _RoleButton(
                  label: 'Candidato Confidencial',
                  icon: Icons.visibility_off_rounded,
                  onTap: () =>
                      _onRoleSelected(context, UserRole.confidencial),
                ).animate(delay: 500.ms).fadeIn(duration: 400.ms).slideY(
                      begin: 0.2,
                      end: 0,
                      duration: 400.ms,
                      curve: Curves.easeOut,
                    ),

                const SizedBox(height: AppSpacing.sm),

                // ── Botón Soy Empresa ──
                _RoleButton(
                  label: 'Soy Empresa',
                  icon: Icons.business_rounded,
                  onTap: () => _onRoleSelected(context, UserRole.empresa),
                ).animate(delay: 600.ms).fadeIn(duration: 400.ms).slideY(
                      begin: 0.2,
                      end: 0,
                      duration: 400.ms,
                      curve: Curves.easeOut,
                    ),

                const SizedBox(height: AppSpacing.xl),

                // ── Divider "o entrá con" ──
                const OrDivider(text: 'o entrá con')
                    .animate(delay: 700.ms)
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: AppSpacing.md),

                // ── Botones sociales en fila ──
                Row(
                  children: [
                    Expanded(
                      child: _SocialMiniButton(
                        label: 'Email',
                        icon: Icons.email_outlined,
                        onTap: () => _onSocialLogin(context, 'email'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _SocialMiniButton(
                        label: 'Google',
                        icon: Icons.language_rounded,
                        onTap: () => _onSocialLogin(context, 'google'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _SocialMiniButton(
                        label: 'Apple',
                        icon: Icons.phone_iphone_rounded,
                        isDark: true,
                        onTap: () => _onSocialLogin(context, 'apple'),
                      ),
                    ),
                  ],
                ).animate(delay: 800.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: AppSpacing.lg),

                // ── Términos ──
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MployaColors.textTertiary,
                    ),
                    children: [
                      const TextSpan(text: 'Al continuar, aceptas los '),
                      TextSpan(
                        text: 'Términos de Uso',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MployaColors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const TextSpan(text: ' y\n'),
                      TextSpan(
                        text: 'Política de Privacidad',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MployaColors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 900.ms).fadeIn(duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Role Button ─────────────────────────────────────────────────────

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: Container(
          decoration: BoxDecoration(
            gradient: MployaColors.orangeGradient,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: MployaColors.textPrimary,
          side: const BorderSide(color: MployaColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        icon: Icon(icon, size: 20, color: MployaColors.textSecondary),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Social Mini Button (para la fila de 3) ──────────────────────────

class _SocialMiniButton extends StatelessWidget {
  const _SocialMiniButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDark = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? MployaColors.apple : Colors.transparent,
          foregroundColor: isDark ? Colors.white : MployaColors.textPrimary,
          side: BorderSide(
            color: isDark ? MployaColors.apple : MployaColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
