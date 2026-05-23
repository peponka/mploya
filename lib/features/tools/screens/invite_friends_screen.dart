/// Pantalla de Invitar Amigos en mploya.
///
/// Muestra un código de invitación que el usuario puede copiar
/// o compartir, con un contador de invitaciones exitosas.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

// ─── Screen ────────────────────────────────────────────────────────

class InviteFriendsScreen extends StatefulWidget {
  const InviteFriendsScreen({super.key});

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  late final String _referralCode;

  @override
  void initState() {
    super.initState();
    _referralCode = _generateCode();
  }

  /// Generates a random referral code: MPL- + 5 uppercase alphanumeric chars.
  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    final suffix = List.generate(5, (_) => chars[rng.nextInt(chars.length)]);
    return 'MPL-${suffix.join()}';
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _referralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado'),
        backgroundColor: MployaColors.teal,
      ),
    );
  }

  void _shareInvite() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Próximamente'),
        backgroundColor: MployaColors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.background,
      appBar: AppBar(
        backgroundColor: MployaColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.chevron_left,
                  color: MployaColors.orange,
                  size: 24,
                ),
                Text(
                  'Atrás',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
        leadingWidth: 100,
        title: Text(
          'Invitar Amigos',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MployaColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // ─── Hero gradient card ─────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              decoration: BoxDecoration(
                gradient: MployaColors.orangeGradient,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: MployaColors.orange.withValues(alpha: 0.30),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Gift emoji
                  const Text(
                    '🎁',
                    style: TextStyle(fontSize: 44),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Invitá y ganá',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Cada amigo que se registre te da un boost de visibilidad',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Pill badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '0 invitaciones exitosas',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MployaColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(
                  begin: 0.1,
                  end: 0,
                  duration: 500.ms,
                  curve: Curves.easeOut,
                ),

            const SizedBox(height: AppSpacing.lg),

            // ─── Referral code card ─────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: MployaColors.white,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: MployaColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Tu código de invitación',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MployaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Code display with copy button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _referralCode,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: MployaColors.textPrimary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        onPressed: _copyCode,
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 20,
                          color: MployaColors.orange,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              MployaColors.orange.withValues(alpha: 0.10),
                          shape: const CircleBorder(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Share button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _shareInvite,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MployaColors.orange,
                        side: const BorderSide(color: MployaColors.orange),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 20),
                      label: Text(
                        'Compartir invitación',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms)
                .slideY(
                  begin: 0.1,
                  end: 0,
                  delay: 200.ms,
                  duration: 400.ms,
                  curve: Curves.easeOut,
                ),

            const SizedBox(height: AppSpacing.lg),

            // ─── Reward info row ────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: MployaColors.orangeSurface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Por cada 5 invitaciones exitosas, recibís '
                      '1 semana de Mploya Pro gratis.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: MployaColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 400.ms, duration: 400.ms),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
