import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
// Material: Colors, Icons — no Cupertino equivalent
import 'package:flutter/material.dart';
import '../services/video_personality_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PersonalityResultScreen — Pantalla radar de soft skills
//
// Muestra:
//   • Radar chart animado con 5 ejes (soft skills)
//   • Tipo de personalidad + rol ideal
//   • Fortalezas y áreas de desarrollo
//   • Botón compartir / re-analizar
// ─────────────────────────────────────────────────────────────────────────────

class PersonalityResultScreen extends StatefulWidget {
  final PersonalityAnalysis analysis;
  final VoidCallback? onReAnalyze;

  const PersonalityResultScreen({
    super.key,
    required this.analysis,
    this.onReAnalyze,
  });

  @override
  State<PersonalityResultScreen> createState() =>
      _PersonalityResultScreenState();
}

class _PersonalityResultScreenState extends State<PersonalityResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late Animation<double> _radarAnim;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _radarAnim = CurvedAnimation(
      parent: _radarController,
      curve: Curves.easeOutCubic,
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _radarController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.analysis;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      child: Stack(
        children: [
          // ── Animated gradient background ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.3,
                  colors: [
                    MployaTheme.brandAccent.withValues(alpha: 0.08),
                    const Color(0xFF0A0A0F),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Header ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Icon(CupertinoIcons.xmark,
                            color: Colors.white54, size: 22),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6C3FC8).withValues(alpha: 0.3),
                              const Color(0xFF9B6FE8).withValues(alpha: 0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                const Color(0xFF9B6FE8).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.sparkles,
                                size: 14, color: Color(0xFF9B6FE8)),
                            SizedBox(width: 6),
                            Text(
                              'IA Personality',
                              style: TextStyle(
                                color: Color(0xFF9B6FE8),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 44),
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
                        const SizedBox(height: 16),

                        // ── Personality Type Badge ──
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: Column(
                            children: [
                              Text(
                                a.personalityType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: MployaTheme.brandAccent
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Score global: ${a.overallScore}/100',
                                  style: const TextStyle(
                                    color: MployaTheme.brandAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Radar Chart ──
                        AnimatedBuilder(
                          animation: _radarAnim,
                          builder: (_, __) => SizedBox(
                            width: 280,
                            height: 280,
                            child: CustomPaint(
                              painter: _RadarChartPainter(
                                scores: a.allScores
                                    .map((s) => s.score / 100.0)
                                    .toList(),
                                labels: a.allScores
                                    .map((s) => '${s.emoji} ${s.name}')
                                    .toList(),
                                progress: _radarAnim.value,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Skill Score Bars ──
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: Column(
                            children: a.allScores.map((skill) {
                              return _SkillBar(
                                skill: skill,
                                animation: _radarAnim,
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Summary ──
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text('🧠',
                                        style: TextStyle(fontSize: 18)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Resumen de Personalidad',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  a.summary,
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.7),
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Ideal Role ──
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  MployaTheme.brandAccent
                                      .withValues(alpha: 0.1),
                                  const Color(0xFF6C3FC8)
                                      .withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: MployaTheme.brandAccent
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: MployaTheme.brandAccent
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.briefcase_fill,
                                    color: MployaTheme.brandAccent,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Rol Ideal Sugerido',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        a.idealRole,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Strengths & Dev Areas ──
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Strengths
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color:
                                        NexTheme.premiumEnd.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: NexTheme.premiumEnd
                                          .withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '💪 Fortalezas',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ...a.strengths.map((s) => Padding(
                                            padding:
                                                const EdgeInsets.only(bottom: 6),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  CupertinoIcons
                                                      .checkmark_circle_fill,
                                                  size: 14,
                                                  color: NexTheme.premiumEnd,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    s,
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.7),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Development areas
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5B300)
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFF5B300)
                                          .withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '🎯 Desarrollo',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ...a.developmentAreas.map((d) => Padding(
                                            padding:
                                                const EdgeInsets.only(bottom: 6),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  CupertinoIcons.lightbulb_fill,
                                                  size: 14,
                                                  color: Color(0xFFF5B300),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    d,
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.7),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom action ──
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
                      if (widget.onReAnalyze != null)
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onReAnalyze!();
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.arrow_counterclockwise,
                                    color: Colors.white70, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Re-analizar',
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
                      if (widget.onReAnalyze != null) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: MployaTheme.brandAccent,
                          borderRadius: BorderRadius.circular(14),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.checkmark_alt,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Entendido',
                                style: TextStyle(
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Radar Chart Painter
// ─────────────────────────────────────────────────────────────────────────────

class _RadarChartPainter extends CustomPainter {
  final List<double> scores; // 0.0 - 1.0
  final List<String> labels;
  final double progress;

  _RadarChartPainter({
    required this.scores,
    required this.labels,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 30;
    final sides = scores.length;
    final angleStep = 2 * pi / sides;

    // ── Grid lines ──
    for (int level = 1; level <= 4; level++) {
      final r = radius * (level / 4);
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;

      final path = Path();
      for (int i = 0; i <= sides; i++) {
        final angle = -pi / 2 + angleStep * (i % sides);
        final point = Offset(
          center.dx + r * cos(angle),
          center.dy + r * sin(angle),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // ── Axis lines ──
    for (int i = 0; i < sides; i++) {
      final angle = -pi / 2 + angleStep * i;
      final end = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(
        center,
        end,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..strokeWidth = 0.5,
      );
    }

    // ── Data polygon ──
    final dataPath = Path();
    final dataPoints = <Offset>[];
    for (int i = 0; i < sides; i++) {
      final angle = -pi / 2 + angleStep * i;
      final value = scores[i] * progress;
      final point = Offset(
        center.dx + radius * value * cos(angle),
        center.dy + radius * value * sin(angle),
      );
      dataPoints.add(point);
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();

    // Fill
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = MployaTheme.brandAccent.withValues(alpha: 0.15 * progress)
        ..style = PaintingStyle.fill,
    );

    // Stroke
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = MployaTheme.brandAccent.withValues(alpha: 0.8 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    // ── Data points ──
    for (final point in dataPoints) {
      canvas.drawCircle(
        point,
        4,
        Paint()
          ..color =
              MployaTheme.brandAccent.withValues(alpha: 0.6 * progress),
      );
      canvas.drawCircle(
        point,
        2.5,
        Paint()..color = Colors.white.withValues(alpha: progress),
      );
    }

    // ── Labels ──
    for (int i = 0; i < sides; i++) {
      final angle = -pi / 2 + angleStep * i;
      final labelRadius = radius + 22;
      final labelPos = Offset(
        center.dx + labelRadius * cos(angle),
        center.dy + labelRadius * sin(angle),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          labelPos.dx - textPainter.width / 2,
          labelPos.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter old) =>
      old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Skill Bar Widget
// ─────────────────────────────────────────────────────────────────────────────

class _SkillBar extends StatelessWidget {
  final SoftSkillScore skill;
  final Animation<double> animation;

  const _SkillBar({required this.skill, required this.animation});

  Color _barColor(int score) {
    if (score >= 80) return NexTheme.premiumEnd;
    if (score >= 65) return MployaTheme.brandAccent;
    if (score >= 50) return const Color(0xFFF5B300);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final color = _barColor(skill.score);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Text(skill.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                skill.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: animation,
                builder: (_, __) => Text(
                  '${(skill.score * animation.value).round()}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedBuilder(
              animation: animation,
              builder: (_, __) => LinearProgressIndicator(
                value: (skill.score / 100.0) * animation.value,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              skill.insight,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
