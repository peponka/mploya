/// Pantalla de Pitch Challenge semanal en mploya.
///
/// Muestra el reto semanal con información de participantes,
/// tiempo restante y estado de participación del usuario.
/// Incluye timer circular de 60 segundos, temas aleatorios,
/// y evaluación post-pitch con puntajes.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

// ─── Mock Topics ───────────────────────────────────────────────────

const _pitchTopics = [
  '¿Por qué deberían contratarte?',
  'Presenta tu idea de startup en 60 segundos',
  'Vende este producto: una app de productividad con IA',
  'Explica tu mayor logro profesional',
  'Convence al inversor de financiar tu proyecto',
  'Presenta una solución innovadora para el trabajo remoto',
  '¿Cómo transformarías la educación con tecnología?',
  'Pitch tu propuesta de valor como profesional',
  'Presenta un plan para aumentar ventas un 30%',
  'Explica por qué tu equipo es el mejor para este proyecto',
];

// ─── Evaluation Model ──────────────────────────────────────────────

class _EvalScore {
  const _EvalScore({
    required this.label,
    required this.score,
    required this.icon,
    required this.color,
  });

  final String label;
  final double score; // 0.0 to 1.0
  final IconData icon;
  final Color color;
}

// ─── Pitch State ───────────────────────────────────────────────────

enum PitchState { idle, running, finished, evaluated }

// ─── Screen ────────────────────────────────────────────────────────

class PitchChallengeScreen extends ConsumerStatefulWidget {
  const PitchChallengeScreen({super.key});

  @override
  ConsumerState<PitchChallengeScreen> createState() =>
      _PitchChallengeScreenState();
}

class _PitchChallengeScreenState extends ConsumerState<PitchChallengeScreen>
    with TickerProviderStateMixin {
  static const int _defaultSeconds = 60;
  final _random = Random();

  PitchState _pitchState = PitchState.idle;
  String _currentTopic = '';
  int _remainingSeconds = _defaultSeconds;
  List<_EvalScore> _evalScores = [];

  late AnimationController _timerController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _defaultSeconds),
    );
    _timerController.addListener(_onTimerTick);
    _timerController.addStatusListener(_onTimerStatus);

    _fadeController = AnimationController(
      vsync: this,
      duration: AnimDurations.normal,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _generateTopic();
  }

  @override
  void dispose() {
    _timerController.removeListener(_onTimerTick);
    _timerController.removeStatusListener(_onTimerStatus);
    _timerController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onTimerTick() {
    if (!mounted) return;
    final elapsed = (_timerController.value * _defaultSeconds).round();
    setState(() {
      _remainingSeconds = _defaultSeconds - elapsed;
    });
  }

  void _onTimerStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed) {
      setState(() {
        _pitchState = PitchState.finished;
        _remainingSeconds = 0;
      });
    }
  }

  void _generateTopic() {
    setState(() {
      _currentTopic = _pitchTopics[_random.nextInt(_pitchTopics.length)];
      _pitchState = PitchState.idle;
      _remainingSeconds = _defaultSeconds;
      _evalScores = [];
      _timerController.reset();
    });
  }

  void _startPitch() {
    setState(() {
      _pitchState = PitchState.running;
      _remainingSeconds = _defaultSeconds;
    });
    _timerController.forward(from: 0);
  }

  void _stopPitch() {
    _timerController.stop();
    setState(() {
      _pitchState = PitchState.finished;
    });
  }

  void _evaluatePitch() {
    // Demo: generate random evaluation scores
    setState(() {
      _evalScores = [
        _EvalScore(
          label: 'Claridad',
          score: 0.6 + _random.nextDouble() * 0.4,
          icon: Icons.visibility_rounded,
          color: MployaColors.blue,
        ),
        _EvalScore(
          label: 'Confianza',
          score: 0.5 + _random.nextDouble() * 0.5,
          icon: Icons.shield_rounded,
          color: MployaColors.teal,
        ),
        _EvalScore(
          label: 'Estructura',
          score: 0.5 + _random.nextDouble() * 0.5,
          icon: Icons.account_tree_rounded,
          color: MployaColors.orange,
        ),
      ];
      _pitchState = PitchState.evaluated;
    });
    _fadeController.forward(from: 0);
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.background,
      appBar: AppBar(
        backgroundColor: MployaColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Pitch Challenge',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MployaColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: MployaColors.orange,
              size: 22,
            ),
            onPressed: _generateTopic,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Column(
          children: [
            // ─── Topic Card ─────────────────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'TEMA DEL PITCH',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _currentTopic,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.timer_rounded,
                        text: '${_defaultSeconds}s',
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _InfoChip(
                        icon: Icons.people_rounded,
                        text: 'Individual',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ─── Timer Display ──────────────────────────────
            _buildTimerDisplay(),

            const SizedBox(height: AppSpacing.lg),

            // ─── Action Buttons ─────────────────────────────
            _buildActionButtons(),

            // ─── Evaluation Results ─────────────────────────
            if (_pitchState == PitchState.evaluated) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildEvaluationResults(),
            ],

            // ─── Tips ───────────────────────────────────────
            const SizedBox(height: AppSpacing.lg),
            _buildPitchTips(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerDisplay() {
    final progress = _pitchState == PitchState.running
        ? 1.0 - _timerController.value
        : (_pitchState == PitchState.finished ||
                _pitchState == PitchState.evaluated)
            ? 0.0
            : 1.0;

    final timerColor = _remainingSeconds <= 10 && _pitchState == PitchState.running
        ? MployaColors.red
        : _pitchState == PitchState.finished ||
                _pitchState == PitchState.evaluated
            ? MployaColors.teal
            : MployaColors.orange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: MployaColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: MployaColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: CustomPaint(
              painter: _CircularTimerPainter(
                progress: progress,
                color: timerColor,
                backgroundColor: MployaColors.borderLight,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(_remainingSeconds),
                      style: GoogleFonts.outfit(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: timerColor,
                      ),
                    ),
                    Text(
                      _pitchState == PitchState.running
                          ? 'En progreso...'
                          : _pitchState == PitchState.finished ||
                                  _pitchState == PitchState.evaluated
                              ? '¡Tiempo!'
                              : 'Listo',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: MployaColors.textSecondary,
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

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          if (_pitchState == PitchState.idle)
            _buildPrimaryButton(
              label: 'Empezar Pitch',
              icon: Icons.play_arrow_rounded,
              onTap: _startPitch,
              gradient: MployaColors.orangeGradient,
              shadowColor: MployaColors.orange,
            ),
          if (_pitchState == PitchState.running)
            _buildPrimaryButton(
              label: 'Detener',
              icon: Icons.stop_rounded,
              onTap: _stopPitch,
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              shadowColor: MployaColors.red,
            ),
          if (_pitchState == PitchState.finished)
            Row(
              children: [
                Expanded(
                  child: _buildSecondaryButton(
                    label: 'Reintentar',
                    icon: Icons.refresh_rounded,
                    onTap: () {
                      setState(() {
                        _pitchState = PitchState.idle;
                        _remainingSeconds = _defaultSeconds;
                        _timerController.reset();
                      });
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: _buildPrimaryButton(
                    label: 'Evaluar',
                    icon: Icons.star_rounded,
                    onTap: _evaluatePitch,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    shadowColor: MployaColors.teal,
                  ),
                ),
              ],
            ),
          if (_pitchState == PitchState.evaluated)
            _buildPrimaryButton(
              label: 'Nuevo Tema',
              icon: Icons.auto_awesome_rounded,
              onTap: _generateTopic,
              gradient: MployaColors.orangeGradient,
              shadowColor: MployaColors.orange,
            ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required LinearGradient gradient,
    required Color shadowColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: MployaColors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: MployaColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: MployaColors.textSecondary, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MployaColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluationResults() {
    final avgScore = _evalScores.isEmpty
        ? 0.0
        : _evalScores.map((e) => e.score).reduce((a, b) => a + b) /
            _evalScores.length;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: MployaColors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: MployaColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MployaColors.orangeSurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.assessment_rounded,
                      color: MployaColors.orange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evaluación del Pitch',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: MployaColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Puntaje general: ${(avgScore * 100).round()}/100',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: MployaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ..._evalScores.map(
                (score) => _ScoreBar(score: score),
              ),
              const SizedBox(height: AppSpacing.md),
              // Feedback message
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: avgScore >= 0.8
                      ? MployaColors.tealLight
                      : MployaColors.orangeSurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      avgScore >= 0.8
                          ? Icons.emoji_events_rounded
                          : Icons.trending_up_rounded,
                      color: avgScore >= 0.8
                          ? MployaColors.teal
                          : MployaColors.orange,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        avgScore >= 0.8
                            ? '¡Excelente pitch! Tienes muy buena presencia.'
                            : 'Buen intento. Practica la estructura y confianza.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: avgScore >= 0.8
                              ? MployaColors.teal
                              : MployaColors.orangeDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPitchTips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: MployaColors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: MployaColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tips para tu Pitch',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: MployaColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _TipRow(
              number: '1',
              text: 'Empieza con un gancho que capte la atención',
            ),
            const SizedBox(height: AppSpacing.sm),
            _TipRow(
              number: '2',
              text: 'Presenta el problema y tu solución clara',
            ),
            const SizedBox(height: AppSpacing.sm),
            _TipRow(
              number: '3',
              text: 'Usa datos concretos y ejemplos reales',
            ),
            const SizedBox(height: AppSpacing.sm),
            _TipRow(
              number: '4',
              text: 'Cierra con un call-to-action memorable',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Circular Timer Painter ────────────────────────────────────────

class _CircularTimerPainter extends CustomPainter {
  _CircularTimerPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 8.0;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    // Dot at the end of progress
    if (progress > 0 && progress < 1) {
      final dotAngle = -pi / 2 + sweepAngle;
      final dotCenter = Offset(
        center.dx + radius * cos(dotAngle),
        center.dy + radius * sin(dotAngle),
      );
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotCenter, strokeWidth / 2 + 2, dotPaint);

      // White inner dot
      final innerDotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotCenter, 3, innerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularTimerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// ─── Score Bar Widget ──────────────────────────────────────────────

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.score});

  final _EvalScore score;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: score.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(score.icon, color: score.color, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      score.label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MployaColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${(score.score * 100).round()}/100',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: score.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: score.score),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: score.color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          score.color,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Chip Widget ──────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tip Row Widget ────────────────────────────────────────────────

class _TipRow extends StatelessWidget {
  const _TipRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: MployaColors.orangeSurface,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MployaColors.orange,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MployaColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
