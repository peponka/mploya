import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/nex_avatar.dart';
import '../screens/messaging_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NexusMatchOverlay — Celebración visual cuando dos usuarios hacen match
//
// Muestra:
//  • Fondo blur oscuro
//  • Avatares de ambos usuarios con ⚡ en el centro
//  • Texto "¡ES UN NEXUS!" con glow
//  • Confetti animado
//  • Botones: "Enviar Mensaje" y "Seguir explorando"
// ─────────────────────────────────────────────────────────────────────────────

class NexusMatchOverlay extends StatefulWidget {
  final NexUser currentUser;
  final NexUser matchedUser;
  final int matchScore;

  const NexusMatchOverlay({
    super.key,
    required this.currentUser,
    required this.matchedUser,
    this.matchScore = 0,
  });

  /// Muestra el overlay como una pantalla modal
  static Future<void> show(BuildContext context, {
    required NexUser currentUser,
    required NexUser matchedUser,
    int matchScore = 0,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) {
        return NexusMatchOverlay(
          currentUser: currentUser,
          matchedUser: matchedUser,
          matchScore: matchScore,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.elasticOut,
            ).drive(Tween(begin: 0.5, end: 1.0)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<NexusMatchOverlay> createState() => _NexusMatchOverlayState();
}

class _NexusMatchOverlayState extends State<NexusMatchOverlay>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<_ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();

    // Confetti
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    final random = Random();
    for (int i = 0; i < 50; i++) {
      _particles.add(_ConfettiParticle(
        x: random.nextDouble(),
        y: random.nextDouble() * -1,
        speed: 0.3 + random.nextDouble() * 0.7,
        size: 4 + random.nextDouble() * 8,
        color: [
          MployaTheme.brandAccent,
          const Color(0xFFD4AF37),
          const Color(0xFF5F3DC4),
          const Color(0xFFFF6B6B),
          const Color(0xFF00C9A7),
          Colors.white,
        ][random.nextInt(6)],
        rotation: random.nextDouble() * 2 * pi,
      ));
    }

    // Pulse glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Confetti Layer ──
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, _) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _confettiController.value,
                ),
              );
            },
          ),

          // ── Content ──
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── "¡ES UN NEXUS!" ──
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Text(
                          '✨ ¡ES UN NEXUS! ✨',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                            shadows: [
                              Shadow(
                                color: MployaTheme.brandAccent.withValues(alpha: _pulseAnimation.value),
                                blurRadius: 30,
                              ),
                              Shadow(
                                color: const Color(0xFFD4AF37).withValues(alpha: _pulseAnimation.value * 0.5),
                                blurRadius: 60,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // ── Avatares con ⚡ ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mi avatar
                        _GlowAvatar(user: widget.currentUser),
                        
                        // ⚡ central
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, _) {
                              return Transform.scale(
                                scale: 0.8 + _pulseAnimation.value * 0.4,
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        MployaTheme.brandAccent,
                                        Color(0xFFD4AF37),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: MployaTheme.brandAccent.withValues(alpha: 0.6),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text('⚡', style: TextStyle(fontSize: 24)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Su avatar
                        _GlowAvatar(user: widget.matchedUser),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Nombres ──
                    Text(
                      '${widget.currentUser.name.split(' ').first} × ${widget.matchedUser.name.split(' ').first}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),

                    if (widget.matchScore > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: MployaTheme.brandAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Afinidad IA: ${widget.matchScore}%',
                          style: const TextStyle(
                            color: MployaTheme.brandAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 48),

                    // ── CTA: Enviar Mensaje ──
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => ChatDetailScreen(otherUser: widget.matchedUser),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [MployaTheme.brandAccent, Color(0xFF00C65E)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: MployaTheme.brandAccent.withValues(alpha: 0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '💬 Enviar Mensaje',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Seguir explorando ──
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Seguir explorando',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glow Avatar ──

class _GlowAvatar extends StatelessWidget {
  final NexUser user;
  const _GlowAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF004E99), Color(0xFFD4AF37)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF004E99).withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF1A1A2E),
        ),
        child: NexAvatar(user: user, size: 72, onTap: () {}),
      ),
    );
  }
}

// ── Confetti System ──

class _ConfettiParticle {
  double x;
  double y;
  final double speed;
  final double size;
  final Color color;
  final double rotation;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotation,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final yPos = (p.y + progress * p.speed * 2) % 1.3 - 0.15;
      final xPos = p.x + sin(progress * pi * 4 + p.rotation) * 0.05;

      final paint = Paint()
        ..color = p.color.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(xPos * size.width, yPos * size.height);
      canvas.rotate(progress * pi * 2 * p.speed);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
