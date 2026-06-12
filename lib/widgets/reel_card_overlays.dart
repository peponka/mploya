import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../screens/role_selection_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reel Card Overlays — Visual overlays del TikTokReelCard
//
// Incluye: Stealth frosted glass, gradiente oscuro, play/pause icon,
// y la animación de doble-tap (bolt).
// Extraído de tiktok_reel_card.dart para reducir el tamaño del god file.
// ─────────────────────────────────────────────────────────────────────────────

/// Stealth Mode Frosted Glass Overlay — blurs and locks confidential profiles.
class ReelStealthOverlay extends StatelessWidget {
  final NexUser author;
  final NexUser? currentUser;
  final VoidCallback onUnlockTap;

  const ReelStealthOverlay({
    super.key,
    required this.author,
    required this.currentUser,
    required this.onUnlockTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Layer 1: Heavy blur — hides video content
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 44.0, sigmaY: 44.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.70),
                      Colors.black.withValues(alpha: 0.80),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Layer 2: Minimalist Centered Stealth Info
        Positioned.fill(
          child: Center(
            child: GestureDetector(
              onTap: () {
                if (currentUser?.accountType != 'empresa') {
                  Navigator.of(context).pushReplacement(
                    CupertinoPageRoute(builder: (_) => const RoleSelectionScreen()),
                  );
                  return;
                }
                onUnlockTap();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4), width: 0.5),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.1), blurRadius: 40, spreadRadius: 10),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.lock_fill, size: 40, color: Color(0xFFD4AF37)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Candidato Confidencial',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      decoration: TextDecoration.none,
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    author.headline.isNotEmpty ? author.headline : 'Experiencia Verificada',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.eye_solid, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              currentUser?.accountType == 'empresa' ? 'Desbloquear Perfil' : 'Solo Empresas',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                decoration: TextDecoration.none,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dark gradient at the base for text legibility.
class ReelBottomGradient extends StatelessWidget {
  const ReelBottomGradient({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 160,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.03),
                Colors.black.withValues(alpha: 0.20),
                Colors.black.withValues(alpha: 0.40),
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
    );
  }
}

/// Play/Pause icon overlay shown when video is paused.
class ReelPlayPauseOverlay extends StatelessWidget {
  const ReelPlayPauseOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IgnorePointer(
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.play_arrow_solid,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }
}

/// Double-tap bolt animation.
class ReelBoltAnimation extends StatelessWidget {
  const ReelBoltAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.5, end: 1.2),
        duration: const Duration(milliseconds: 400),
        curve: Curves.elasticOut,
        builder: (_, scale, child) => Transform.scale(
          scale: scale,
          child: child,
        ),
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.bolt_fill,
            color: Color(0xFFFFD60A),
            size: 56,
            shadows: [
              Shadow(color: Colors.black54, blurRadius: 12),
              Shadow(color: Color(0xFFFFD60A), blurRadius: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Analytics badges (Match %, Insight) — top right.
class ReelAnalyticsBadges extends StatelessWidget {
  final NexUser author;
  final int matchScore;
  final String insightText;
  final IconData insightIcon;
  final VoidCallback onMatchTap;

  const ReelAnalyticsBadges({
    super.key,
    required this.author,
    required this.matchScore,
    required this.insightText,
    required this.insightIcon,
    required this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Match — minimal glass pill
        GestureDetector(
          onTap: onMatchTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.5),
            ),
            child: Text(
              '$matchScore% Match',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: -0.2),
            ),
          ),
        ),
      ],
    );
  }
}
