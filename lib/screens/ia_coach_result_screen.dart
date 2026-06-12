import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import '../services/ia_coach_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IACoachResultScreen — Pantalla de resultados del IA Coach
//
// Muestra el análisis completo del video-pitch con:
//   • Score radial animado (0-100)
//   • 4 categorías expandibles con tips
//   • Resumen general
//   • Botones: Re-grabar / Publicar así
//
// Diseño: Glassmorphism, dark theme, animaciones premium.
// ─────────────────────────────────────────────────────────────────────────────

class IACoachResultScreen extends StatefulWidget {
  final PitchAnalysis analysis;
  final VoidCallback onReRecord;
  final VoidCallback onPublish;

  const IACoachResultScreen({
    super.key,
    required this.analysis,
    required this.onReRecord,
    required this.onPublish,
  });

  @override
  State<IACoachResultScreen> createState() => _IACoachResultScreenState();
}

class _IACoachResultScreenState extends State<IACoachResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _scoreAnimController;
  late Animation<double> _scoreAnim;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  int? _expandedCategory;

  @override
  void initState() {
    super.initState();

    // Score ring animation
    _scoreAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scoreAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scoreAnimController, curve: Curves.easeOutCubic),
    );

    // Fade in animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    // Start animations
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _scoreAnimController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _scoreAnimController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Color _scoreColor(int score) {
    if (score >= 85) return NexTheme.premiumEnd;
    if (score >= 70) return MployaTheme.brandAccent;
    if (score >= 50) return const Color(0xFFF5B300);
    return const Color(0xFFEF4444);
  }

  String _scoreEmoji(int score) {
    if (score >= 85) return '🔥';
    if (score >= 70) return '👏';
    if (score >= 50) return '💡';
    return '🎯';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.analysis;
    final color = _scoreColor(a.overallScore);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      child: Stack(
        children: [
          // ── Animated gradient background ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _scoreAnimController,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 1.2,
                    colors: [
                      color.withValues(alpha: 0.12 * _scoreAnim.value),
                      const Color(0xFF0A0A0F),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Icon(CupertinoIcons.xmark, color: Colors.white54, size: 22),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: MployaTheme.brandAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.wand_stars, size: 14, color: MployaTheme.brandAccent),
                            SizedBox(width: 6),
                            Text(
                              'IA Coach',
                              style: TextStyle(
                                color: MployaTheme.brandAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 44), // balance for X button
                    ],
                  ),
                ),

                // ── Scrollable content ──
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // ── Score Ring ──
                        AnimatedBuilder(
                          animation: _scoreAnim,
                          builder: (_, __) {
                            final animatedScore = (a.overallScore * _scoreAnim.value).round();
                            return SizedBox(
                              width: 180,
                              height: 180,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Ring background
                                  CustomPaint(
                                    size: const Size(180, 180),
                                    painter: _ScoreRingPainter(
                                      progress: _scoreAnim.value * (a.overallScore / 100),
                                      color: color,
                                      bgColor: Colors.white.withValues(alpha: 0.06),
                                    ),
                                  ),
                                  // Score text
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _scoreEmoji(a.overallScore),
                                        style: const TextStyle(fontSize: 28),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$animatedScore',
                                        style: TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w900,
                                          color: color,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                          height: 1.0,
                                        ),
                                      ),
                                      Text(
                                        'de 100',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.4),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // ── Label + Summary ──
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _scoreLabelFull(a.overallScore),
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                a.summary,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 15,
                                  height: 1.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ── Stats row ──
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _StatPill(
                                  icon: CupertinoIcons.clock,
                                  label: '${a.durationSeconds}s',
                                  subtitle: 'Duración',
                                ),
                                _StatPill(
                                  icon: CupertinoIcons.textformat_size,
                                  label: '${a.wordCount}',
                                  subtitle: 'Palabras',
                                ),
                                _StatPill(
                                  icon: CupertinoIcons.speedometer,
                                  label: '${a.estimatedWPM}',
                                  subtitle: 'Pal/min',
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ── Category cards ──
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: Column(
                            children: [
                              _CategoryCard(
                                category: a.communication,
                                color: _scoreColor(a.communication.score),
                                isExpanded: _expandedCategory == 0,
                                onTap: () => setState(() => _expandedCategory = _expandedCategory == 0 ? null : 0),
                              ),
                              const SizedBox(height: 10),
                              _CategoryCard(
                                category: a.content,
                                color: _scoreColor(a.content.score),
                                isExpanded: _expandedCategory == 1,
                                onTap: () => setState(() => _expandedCategory = _expandedCategory == 1 ? null : 1),
                              ),
                              const SizedBox(height: 10),
                              _CategoryCard(
                                category: a.technical,
                                color: _scoreColor(a.technical.score),
                                isExpanded: _expandedCategory == 2,
                                onTap: () => setState(() => _expandedCategory = _expandedCategory == 2 ? null : 2),
                              ),
                              const SizedBox(height: 10),
                              _CategoryCard(
                                category: a.impact,
                                color: _scoreColor(a.impact.score),
                                isExpanded: _expandedCategory == 3,
                                onTap: () => setState(() => _expandedCategory = _expandedCategory == 3 ? null : 3),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Top tips section ──
                        if (a.topTips.isNotEmpty)
                          FadeTransition(
                            opacity: _fadeAnim,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    MployaTheme.brandAccent.withValues(alpha: 0.08),
                                    NexTheme.premiumEnd.withValues(alpha: 0.04),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: MployaTheme.brandAccent.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Text('💡', style: TextStyle(fontSize: 18)),
                                      SizedBox(width: 8),
                                      Text(
                                        'Top Tips para Mejorar',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ...a.topTips.asMap().entries.map((entry) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: MployaTheme.brandAccent.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(7),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${entry.key + 1}',
                                                style: const TextStyle(
                                                  color: MployaTheme.brandAccent,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              entry.value,
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.75),
                                                fontSize: 14,
                                                height: 1.45,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 100), // bottom padding for buttons
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom action buttons ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF0A0A0F).withValues(alpha: 0.8),
                        const Color(0xFF0A0A0F),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Re-grabar
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onReRecord();
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.arrow_counterclockwise, color: Colors.white70, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Re-grabar',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Publicar
                      Expanded(
                        flex: 2,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: MployaTheme.brandAccent,
                          borderRadius: BorderRadius.circular(14),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onPublish();
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(CupertinoIcons.arrow_up_circle_fill, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                a.overallScore >= 70 ? 'Publicar Pitch 🚀' : 'Publicar Así',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _scoreLabelFull(int score) {
    if (score >= 85) return '¡Pitch Excelente!';
    if (score >= 70) return 'Buen Pitch';
    if (score >= 50) return 'Pitch Mejorable';
    return 'Necesita Más Trabajo';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Animated ring painter for the score
class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _ScoreRingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 10.0;

    // Background ring
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [color.withValues(alpha: 0.3), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );

    // Glow dot at the end of the arc
    if (progress > 0.01) {
      final endAngle = -pi / 2 + 2 * pi * progress;
      final dotCenter = Offset(
        center.dx + radius * cos(endAngle),
        center.dy + radius * sin(endAngle),
      );
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(dotCenter, 6, glowPaint);
      canvas.drawCircle(dotCenter, 4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) =>
      old.progress != progress;
}

/// Category expandable card
class _CategoryCard extends StatelessWidget {
  final CategoryScore category;
  final Color color;
  final bool isExpanded;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.color,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isExpanded
              ? color.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded
                ? color.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          children: [
            // Header row
            Row(
              children: [
                Text(category.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Score badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${category.score}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    CupertinoIcons.chevron_forward,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),

            // Expanded tips
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  children: category.tips.map((tip) {
                    final isPositive = tip.startsWith('✓');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isPositive
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.lightbulb_fill,
                            size: 16,
                            color: isPositive
                                ? NexTheme.premiumEnd
                                : const Color(0xFFF5B300),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isPositive ? tip.substring(2) : tip,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              crossFadeState:
                  isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small stat pill
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: MployaTheme.brandAccent),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}