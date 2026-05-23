/// Pantalla de Interview Prep en mploya.
///
/// Muestra preguntas de entrevista personalizadas por categoría
/// (Técnica, Conductual, Motivación) con tips expandibles.
/// Incluye selector de dificultad, generador de preguntas aleatorias,
/// botón de grabación y seguimiento de progreso.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

// ─── Enums & Models ────────────────────────────────────────────────

enum QuestionCategory {
  tecnica,
  conductual,
  motivacion;

  String get displayName {
    switch (this) {
      case QuestionCategory.tecnica:
        return 'Técnica';
      case QuestionCategory.conductual:
        return 'Conductual';
      case QuestionCategory.motivacion:
        return 'Motivación';
    }
  }

  IconData get icon {
    switch (this) {
      case QuestionCategory.tecnica:
        return Icons.code_rounded;
      case QuestionCategory.conductual:
        return Icons.people_rounded;
      case QuestionCategory.motivacion:
        return Icons.rocket_launch_rounded;
    }
  }

  Color get color {
    switch (this) {
      case QuestionCategory.tecnica:
        return const Color(0xFF3B82F6); // blue
      case QuestionCategory.conductual:
        return const Color(0xFFF97316); // orange
      case QuestionCategory.motivacion:
        return const Color(0xFF10B981); // green
    }
  }

  Color get bgColor {
    switch (this) {
      case QuestionCategory.tecnica:
        return const Color(0xFFEFF6FF);
      case QuestionCategory.conductual:
        return const Color(0xFFFFF7ED);
      case QuestionCategory.motivacion:
        return const Color(0xFFECFDF5);
    }
  }
}

enum Difficulty {
  facil,
  media,
  dificil;

  String get displayName {
    switch (this) {
      case Difficulty.facil:
        return 'Fácil';
      case Difficulty.media:
        return 'Media';
      case Difficulty.dificil:
        return 'Difícil';
    }
  }

  Color get color {
    switch (this) {
      case Difficulty.facil:
        return const Color(0xFF10B981);
      case Difficulty.media:
        return const Color(0xFFF97316);
      case Difficulty.dificil:
        return const Color(0xFFEF4444);
    }
  }

  Color get bgColor {
    switch (this) {
      case Difficulty.facil:
        return const Color(0xFFECFDF5);
      case Difficulty.media:
        return const Color(0xFFFFF7ED);
      case Difficulty.dificil:
        return const Color(0xFFFEE2E2);
    }
  }
}

class _InterviewQuestion {
  const _InterviewQuestion({
    required this.category,
    required this.question,
    required this.tip,
    required this.difficulty,
  });

  final QuestionCategory category;
  final String question;
  final String tip;
  final Difficulty difficulty;
}

// ─── Mock Data ─────────────────────────────────────────────────────

const _allQuestions = [
  // Fácil
  _InterviewQuestion(
    category: QuestionCategory.motivacion,
    question: '¿Por qué quieres trabajar en esta empresa?',
    tip:
        'Investiga la misión y valores de la empresa. Conecta tus metas personales con su visión.',
    difficulty: Difficulty.facil,
  ),
  _InterviewQuestion(
    category: QuestionCategory.conductual,
    question: '¿Cuáles son tus principales fortalezas?',
    tip:
        'Elige 2-3 fortalezas relevantes al puesto y respalda cada una con un ejemplo concreto.',
    difficulty: Difficulty.facil,
  ),
  _InterviewQuestion(
    category: QuestionCategory.motivacion,
    question: '¿Qué te motivó a elegir tu carrera profesional?',
    tip:
        'Sé auténtico. Comparte un momento o experiencia que definió tu camino profesional.',
    difficulty: Difficulty.facil,
  ),
  _InterviewQuestion(
    category: QuestionCategory.conductual,
    question: 'Háblame de ti y tu trayectoria profesional.',
    tip:
        'Prepara un "elevator pitch" de 2 minutos. Conecta tu historia con el puesto al que aplicas.',
    difficulty: Difficulty.facil,
  ),

  // Media
  _InterviewQuestion(
    category: QuestionCategory.tecnica,
    question:
        '¿Cómo construirías un modelo DCF para una empresa de SaaS con ingresos recurrentes?',
    tip:
        'Enfócate en las métricas clave de SaaS (MRR, churn, LTV/CAC). Muestra que entiendes la diferencia entre valorar un modelo de suscripción vs. ingresos tradicionales.',
    difficulty: Difficulty.media,
  ),
  _InterviewQuestion(
    category: QuestionCategory.conductual,
    question:
        'Cuéntame sobre una vez que tuviste un desacuerdo con tu jefe. ¿Cómo lo manejaste?',
    tip:
        'Usa el método STAR (Situación, Tarea, Acción, Resultado). Muestra madurez profesional y capacidad de resolver conflictos de manera constructiva.',
    difficulty: Difficulty.media,
  ),
  _InterviewQuestion(
    category: QuestionCategory.tecnica,
    question:
        '¿Qué herramientas de análisis de datos manejas y cómo las aplicas en tu trabajo diario?',
    tip:
        'Sé específico con ejemplos. Menciona Excel avanzado, SQL, Power BI o Tableau con casos de uso concretos.',
    difficulty: Difficulty.media,
  ),
  _InterviewQuestion(
    category: QuestionCategory.conductual,
    question:
        'Describe un proyecto donde tuviste que trabajar bajo presión con plazos ajustados.',
    tip:
        'Destaca tu capacidad de priorización y gestión del tiempo. Incluye el impacto cuantificable de tu trabajo.',
    difficulty: Difficulty.media,
  ),

  // Difícil
  _InterviewQuestion(
    category: QuestionCategory.tecnica,
    question:
        'Diseña la arquitectura de un sistema de pagos en tiempo real que maneje 10,000 TPS.',
    tip:
        'Menciona patrones como event sourcing, CQRS, message queues. Habla de trade-offs entre consistencia y disponibilidad.',
    difficulty: Difficulty.dificil,
  ),
  _InterviewQuestion(
    category: QuestionCategory.motivacion,
    question:
        '¿Cómo manejarías una situación donde la estrategia de la empresa va en contra de tus valores personales?',
    tip:
        'Muestra inteligencia emocional. Habla de cómo buscarías entender la perspectiva de la empresa antes de tomar decisiones.',
    difficulty: Difficulty.dificil,
  ),
  _InterviewQuestion(
    category: QuestionCategory.tecnica,
    question:
        'Explica cómo optimizarías una consulta SQL que tarda 30 segundos en una tabla con 100M de registros.',
    tip:
        'Menciona indexación, particionamiento, query plan analysis, materialización de vistas y caching strategies.',
    difficulty: Difficulty.dificil,
  ),
  _InterviewQuestion(
    category: QuestionCategory.conductual,
    question:
        'Cuéntame de una vez que fracasaste significativamente. ¿Qué aprendiste?',
    tip:
        'La clave es mostrar vulnerabilidad genuina + aprendizaje concreto. Evita "fracasos" que en realidad son logros disfrazados.',
    difficulty: Difficulty.dificil,
  ),
];

// ─── Screen ────────────────────────────────────────────────────────

class InterviewPrepScreen extends ConsumerStatefulWidget {
  const InterviewPrepScreen({super.key});

  @override
  ConsumerState<InterviewPrepScreen> createState() =>
      _InterviewPrepScreenState();
}

class _InterviewPrepScreenState extends ConsumerState<InterviewPrepScreen>
    with SingleTickerProviderStateMixin {
  static const int _totalQuestions = 10;
  final _random = Random();

  Difficulty _selectedDifficulty = Difficulty.media;
  _InterviewQuestion? _currentQuestion;
  bool _showTip = false;
  bool _isRecording = false;
  int _answeredCount = 0;
  final Set<int> _answeredIndices = {};

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  List<_InterviewQuestion> get _filteredQuestions =>
      _allQuestions.where((q) => q.difficulty == _selectedDifficulty).toList();

  void _generateQuestion() {
    final questions = _filteredQuestions;
    if (questions.isEmpty) return;
    setState(() {
      _currentQuestion = questions[_random.nextInt(questions.length)];
      _showTip = false;
      _isRecording = false;
    });
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
        // Mark question as answered
        if (_currentQuestion != null &&
            _answeredCount < _totalQuestions) {
          final idx = _allQuestions.indexOf(_currentQuestion!);
          if (!_answeredIndices.contains(idx)) {
            _answeredIndices.add(idx);
            _answeredCount++;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _answeredCount / _totalQuestions;

    return Scaffold(
      backgroundColor: MployaColors.background,
      appBar: AppBar(
        backgroundColor: MployaColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Interview Prep',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MployaColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Column(
          children: [
            // ─── Header Card ────────────────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
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
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.psychology_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Interview Prep',
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Practica para tu próxima entrevista',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Progress
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$_answeredCount de $_totalQuestions preguntas',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${(progress * 100).round()}%',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.2),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Difficulty Selector ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: MployaColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: MployaColors.borderLight),
                ),
                child: Row(
                  children: Difficulty.values.map((d) {
                    final isSelected = d == _selectedDifficulty;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDifficulty = d;
                            _currentQuestion = null;
                            _showTip = false;
                            _isRecording = false;
                          });
                        },
                        child: AnimatedContainer(
                          duration: AnimDurations.fast,
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? d.bgColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              AppRadius.md,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              d.displayName,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? d.color
                                    : MployaColors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ─── Generate Question Button ───────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: GestureDetector(
                onTap: _generateQuestion,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: MployaColors.orangeGradient,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: MployaColors.orange.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Generar Pregunta',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ─── Question Card ──────────────────────────────
            if (_currentQuestion != null)
              _buildQuestionCard()
            else
              _buildEmptyState(),

            // ─── Recording Section ──────────────────────────
            if (_currentQuestion != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildRecordingSection(),
            ],

            // ─── Tips Section ───────────────────────────────
            if (_currentQuestion != null) ...[
              const SizedBox(height: AppSpacing.md),
              _buildTipSection(),
            ],

            // ─── General Guidance ───────────────────────────
            const SizedBox(height: AppSpacing.lg),
            _buildGuidanceCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard() {
    final q = _currentQuestion!;
    return Padding(
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
            // Category + Difficulty
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: q.category.bgColor,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(q.category.icon, size: 14, color: q.category.color),
                      const SizedBox(width: 4),
                      Text(
                        q.category.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: q.category.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: q.difficulty.bgColor,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    q.difficulty.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: q.difficulty.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Question text
            Text(
              q.question,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: MployaColors.textPrimary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xl,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: MployaColors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: MployaColors.borderLight,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: MployaColors.orangeSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.question_answer_rounded,
                size: 40,
                color: MployaColors.orange,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Presiona "Generar Pregunta"',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: MployaColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Selecciona la dificultad y genera una pregunta aleatoria para practicar.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MployaColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: GestureDetector(
        onTap: _toggleRecording,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: _isRecording
                ? MployaColors.red
                : MployaColors.textPrimary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: [
              if (_isRecording)
                BoxShadow(
                  color: MployaColors.red.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: _isRecording ? 12 + (_pulseController.value * 4) : 22,
                    height: _isRecording ? 12 + (_pulseController.value * 4) : 22,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        _isRecording ? 3 : 11,
                      ),
                    ),
                    child: _isRecording
                        ? null
                        : const Icon(
                            Icons.videocam_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  );
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _isRecording ? 'Detener Grabación' : 'Grabar Respuesta',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipSection() {
    final q = _currentQuestion!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: MployaColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: MployaColors.borderLight),
        ),
        child: Column(
          children: [
            // Toggle tip
            InkWell(
              onTap: () => setState(() => _showTip = !_showTip),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MployaColors.orangeSurface,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.lightbulb_rounded,
                        color: MployaColors.orange,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Ver tip para responder',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: MployaColors.orange,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _showTip ? 0.5 : 0,
                      duration: AnimDurations.fast,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: MployaColors.orange,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tip content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: MployaColors.orangeSurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  q.tip,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MployaColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
              crossFadeState: _showTip
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: AnimDurations.fast,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guía rápida',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: MployaColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _GuidanceCard(
            icon: Icons.timer_rounded,
            title: 'Método STAR',
            description:
                'Estructura tu respuesta: Situación, Tarea, Acción, Resultado.',
            color: MployaColors.blue,
          ),
          const SizedBox(height: AppSpacing.sm),
          _GuidanceCard(
            icon: Icons.record_voice_over_rounded,
            title: 'Sé conciso',
            description:
                'Respuestas de 1-2 minutos. Ve directo al punto con ejemplos claros.',
            color: MployaColors.teal,
          ),
          const SizedBox(height: AppSpacing.sm),
          _GuidanceCard(
            icon: Icons.emoji_objects_rounded,
            title: 'Datos concretos',
            description:
                'Incluye métricas y resultados cuantificables siempre que sea posible.',
            color: MployaColors.orange,
          ),
        ],
      ),
    );
  }
}

// ─── Guidance Card Widget ──────────────────────────────────────────

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MployaColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: MployaColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MployaColors.textSecondary,
                    height: 1.4,
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
