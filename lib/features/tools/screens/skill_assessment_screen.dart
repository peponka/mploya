/// Pantalla de Skill Assessment en mploya.
///
/// Muestra badges obtenidos, explicación del proceso y lista de skills
/// disponibles para evaluación.
/// Incluye 4 categorías con 5 preguntas cada una, múltiple opción,
/// progreso por categoría, y resultados con radar chart y barras.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

// ─── Models ────────────────────────────────────────────────────────

class _SkillCategory {
  const _SkillCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.questions,
  });

  final String name;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final List<_QuizQuestion> questions;
}

class _QuizQuestion {
  const _QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  final String question;
  final List<String> options; // A, B, C, D
  final int correctIndex;
}

// ─── Mock Data ─────────────────────────────────────────────────────

final _categories = [
  _SkillCategory(
    name: 'Comunicación',
    icon: Icons.chat_bubble_rounded,
    color: MployaColors.blue,
    bgColor: const Color(0xFFEFF6FF),
    questions: const [
      _QuizQuestion(
        question: '¿Cuál es la clave de la escucha activa?',
        options: [
          'Interrumpir para mostrar interés',
          'Parafrasear y confirmar entendimiento',
          'Dar consejos inmediatos',
          'Cambiar de tema frecuentemente',
        ],
        correctIndex: 1,
      ),
      _QuizQuestion(
        question: '¿Qué técnica mejora la comunicación no verbal?',
        options: [
          'Evitar el contacto visual',
          'Cruzar los brazos siempre',
          'Mantener postura abierta y contacto visual',
          'Hablar lo más rápido posible',
        ],
        correctIndex: 2,
      ),
      _QuizQuestion(
        question: '¿Cómo dar feedback constructivo?',
        options: [
          'Centrarse solo en errores',
          'Ser vago para no ofender',
          'Usar el modelo SBI (Situación, Comportamiento, Impacto)',
          'Darlo siempre en público',
        ],
        correctIndex: 2,
      ),
      _QuizQuestion(
        question: '¿Qué elemento es esencial en una presentación efectiva?',
        options: [
          'Leer todo el texto de las diapositivas',
          'Contar una historia que conecte con la audiencia',
          'Usar la mayor cantidad de datos posible',
          'Hablar sin pausas',
        ],
        correctIndex: 1,
      ),
      _QuizQuestion(
        question: '¿Cuál es el principio de la comunicación asertiva?',
        options: [
          'Evitar conflictos a toda costa',
          'Imponer tu punto de vista',
          'Expresar ideas con respeto y claridad',
          'Estar de acuerdo con todos',
        ],
        correctIndex: 2,
      ),
    ],
  ),
  _SkillCategory(
    name: 'Liderazgo',
    icon: Icons.groups_rounded,
    color: MployaColors.orange,
    bgColor: const Color(0xFFFFF7ED),
    questions: const [
      _QuizQuestion(
        question: '¿Qué define a un líder transformacional?',
        options: [
          'Dicta todas las decisiones',
          'Inspira y motiva al equipo hacia una visión',
          'Evita el riesgo a toda costa',
          'Se enfoca solo en resultados financieros',
        ],
        correctIndex: 1,
      ),
      _QuizQuestion(
        question: '¿Cómo se delega efectivamente?',
        options: [
          'Asignar tareas sin contexto',
          'Hacer todo uno mismo para asegurar calidad',
          'Dar autonomía con expectativas claras y seguimiento',
          'Delegar solo tareas fáciles',
        ],
        correctIndex: 2,
      ),
      _QuizQuestion(
        question: '¿Cuál es la mejor forma de manejar un conflicto en el equipo?',
        options: [
          'Ignorarlo hasta que se resuelva solo',
          'Tomar partido por un lado',
          'Facilitar el diálogo y buscar soluciones win-win',
          'Escalar inmediatamente a RRHH',
        ],
        correctIndex: 2,
      ),
      _QuizQuestion(
        question: '¿Qué caracteriza a un equipo de alto rendimiento?',
        options: [
          'Competencia interna agresiva',
          'Confianza, objetivos claros y comunicación abierta',
          'Jerarquía rígida',
          'Horarios extensos',
        ],
        correctIndex: 1,
      ),
      _QuizQuestion(
        question: '¿Cuál es el rol del líder en el desarrollo del equipo?',
        options: [
          'Controlar cada detalle del trabajo',
          'Crear oportunidades de crecimiento y mentoring',
          'Mantener la información centralizada',
          'Evitar dar feedback negativo',
        ],
        correctIndex: 1,
      ),
    ],
  ),
  _SkillCategory(
    name: 'Técnicas',
    icon: Icons.code_rounded,
    color: MployaColors.teal,
    bgColor: const Color(0xFFECFDF5),
    questions: const [
      _QuizQuestion(
        question: '¿Qué metodología ágil se basa en sprints de 2-4 semanas?',
        options: [
          'Waterfall',
          'Kanban',
          'Scrum',
          'Lean',
        ],
        correctIndex: 2,
      ),
      _QuizQuestion(
        question: '¿Cuál es el propósito principal del análisis FODA?',
        options: [
          'Evaluar fortalezas, oportunidades, debilidades y amenazas',
          'Calcular el ROI de un proyecto',
          'Diseñar la estructura organizacional',
          'Medir la satisfacción del cliente',
        ],
        correctIndex: 0,
      ),
      _QuizQuestion(
        question: '¿Qué herramienta se usa para mapear procesos?',
        options: [
          'Excel pivot tables',
          'Diagramas de flujo',
          'Análisis de regresión',
          'Canvas de modelo de negocio',
        ],
        correctIndex: 1,
      ),
      _QuizQuestion(
        question: '¿Qué es un KPI?',
        options: [
          'Un tipo de base de datos',
          'Un lenguaje de programación',
          'Un indicador clave de rendimiento',
          'Un método de gestión de proyectos',
        ],
        correctIndex: 2,
      ),
      _QuizQuestion(
        question: '¿Cuál es la diferencia entre eficiencia y eficacia?',
        options: [
          'Son sinónimos',
          'Eficiencia es hacer las cosas correctas, eficacia es hacerlas bien',
          'Eficiencia es usar recursos óptimamente, eficacia es lograr objetivos',
          'No tienen relación entre sí',
        ],
        correctIndex: 2,
      ),
    ],
  ),
  _SkillCategory(
    name: 'Creatividad',
    icon: Icons.palette_rounded,
    color: const Color(0xFF8B5CF6),
    bgColor: const Color(0xFFF5F3FF),
    questions: const [
      _QuizQuestion(
        question: '¿Qué técnica creativa genera ideas sin juzgar?',
        options: [
          'Análisis PEST',
          'Brainstorming',
          'Análisis de regresión',
          'Benchmarking',
        ],
        correctIndex: 1,
      ),
      _QuizQuestion(
        question: '¿Qué es el pensamiento lateral?',
        options: [
          'Seguir la lógica tradicional paso a paso',
          'Buscar soluciones desde ángulos no convencionales',
          'Copiar lo que hace la competencia',
          'Evitar el riesgo en la toma de decisiones',
        ],
        correctIndex: 1,
      ),
      _QuizQuestion(
        question: '¿Cuál es el principio del Design Thinking?',
        options: [
          'Tecnología primero, usuario después',
          'Empatizar con el usuario y prototipar rápido',
          'Seguir un proceso lineal sin cambios',
          'Minimizar la participación del equipo',
        ],
        correctIndex: 1,
      ),
      _QuizQuestion(
        question: '¿Qué fomenta la innovación en una organización?',
        options: [
          'Penalizar los errores duramente',
          'Crear un ambiente seguro para experimentar',
          'Mantener procesos rígidos',
          'Reducir la diversidad del equipo',
        ],
        correctIndex: 1,
      ),
      _QuizQuestion(
        question: '¿Qué es un "moonshot" en innovación?',
        options: [
          'Una mejora incremental',
          'Una idea radical con potencial transformador',
          'Un proyecto con bajo presupuesto',
          'Una réplica de algo existente',
        ],
        correctIndex: 1,
      ),
    ],
  ),
];

// ─── Screen ────────────────────────────────────────────────────────

class SkillAssessmentScreen extends ConsumerStatefulWidget {
  const SkillAssessmentScreen({super.key});

  @override
  ConsumerState<SkillAssessmentScreen> createState() =>
      _SkillAssessmentScreenState();
}

class _SkillAssessmentScreenState
    extends ConsumerState<SkillAssessmentScreen> {
  // Assessment state
  bool _isAssessing = false;
  bool _showResults = false;
  int _currentCategoryIndex = 0;
  int _currentQuestionIndex = 0;
  int? _selectedOption;
  bool _answered = false;

  // Scores per category (0.0 to 1.0)
  final Map<int, int> _correctCounts = {};
  final Map<int, int> _totalAnswered = {};

  _SkillCategory get _currentCategory => _categories[_currentCategoryIndex];

  _QuizQuestion get _currentQuestion =>
      _currentCategory.questions[_currentQuestionIndex];

  int get _totalQuestions =>
      _categories.fold(0, (sum, c) => sum + c.questions.length);

  int get _totalAnsweredAll =>
      _totalAnswered.values.fold(0, (sum, v) => sum + v);

  void _startAssessment() {
    setState(() {
      _isAssessing = true;
      _showResults = false;
      _currentCategoryIndex = 0;
      _currentQuestionIndex = 0;
      _selectedOption = null;
      _answered = false;
      _correctCounts.clear();
      _totalAnswered.clear();
    });
  }

  void _selectOption(int index) {
    if (_answered) return;
    setState(() {
      _selectedOption = index;
      _answered = true;
      _totalAnswered[_currentCategoryIndex] =
          (_totalAnswered[_currentCategoryIndex] ?? 0) + 1;
      if (index == _currentQuestion.correctIndex) {
        _correctCounts[_currentCategoryIndex] =
            (_correctCounts[_currentCategoryIndex] ?? 0) + 1;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _currentCategory.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedOption = null;
        _answered = false;
      });
    } else if (_currentCategoryIndex < _categories.length - 1) {
      setState(() {
        _currentCategoryIndex++;
        _currentQuestionIndex = 0;
        _selectedOption = null;
        _answered = false;
      });
    } else {
      // All done
      setState(() {
        _showResults = true;
        _isAssessing = false;
      });
    }
  }

  double _categoryScore(int catIndex) {
    final total = _categories[catIndex].questions.length;
    final correct = _correctCounts[catIndex] ?? 0;
    return total > 0 ? correct / total : 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_showResults) return _buildResultsScreen();
    if (_isAssessing) return _buildQuizScreen();
    return _buildCategorySelectionScreen();
  }

  // ─── Category Selection Screen ──────────────────────────────────

  Widget _buildCategorySelectionScreen() {
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
          'Skill Assessment',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header Card ───────────────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A1A2E).withValues(alpha: 0.3),
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
                          color: MployaColors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: MployaColors.orange,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Skill Assessment',
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Evalúa tus habilidades profesionales',
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
                  Row(
                    children: [
                      _HeaderPill(
                        label: '${_categories.length} Categorías',
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _HeaderPill(
                        label: '$_totalQuestions Preguntas',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── How it works ──────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
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
                    '¿Cómo funciona?',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: MployaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _HowItWorksStep(
                    number: '1',
                    text: 'Responde 5 preguntas por cada categoría',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _HowItWorksStep(
                    number: '2',
                    text: 'Elige la mejor respuesta (A/B/C/D)',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _HowItWorksStep(
                    number: '3',
                    text:
                        'Obtén tu perfil con radar chart y puntajes detallados',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ─── Categories ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: Text(
                'Categorías',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: MployaColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            ...List.generate(_categories.length, (i) {
              final cat = _categories[i];
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Container(
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
                          color: cat.bgColor,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          cat.icon,
                          color: cat.color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.name,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: MployaColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${cat.questions.length} preguntas',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: MployaColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: cat.bgColor,
                          borderRadius: BorderRadius.circular(
                            AppRadius.pill,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.quiz_rounded,
                              size: 14,
                              color: cat.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Quiz',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cat.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: AppSpacing.lg),

            // ─── Start Button ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: MployaButton(
                label: 'Comenzar Evaluación',
                icon: Icons.play_arrow_rounded,
                onPressed: _startAssessment,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Quiz Screen ────────────────────────────────────────────────

  Widget _buildQuizScreen() {
    final cat = _currentCategory;
    final q = _currentQuestion;
    final categoryProgress =
        (_currentQuestionIndex + 1) / cat.questions.length;
    final globalProgress = (_totalAnsweredAll) / _totalQuestions;

    return Scaffold(
      backgroundColor: MployaColors.background,
      appBar: AppBar(
        backgroundColor: MployaColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 24),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                title: Text(
                  '¿Salir del assessment?',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                content: Text(
                  'Perderás tu progreso actual.',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Continuar',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: MployaColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _isAssessing = false;
                        _correctCounts.clear();
                        _totalAnswered.clear();
                      });
                    },
                    child: Text(
                      'Salir',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: MployaColors.red,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        title: Text(
          cat.name,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MployaColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Global progress bar
          Container(
            color: MployaColors.white,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progreso general',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MployaColors.textTertiary,
                      ),
                    ),
                    Text(
                      '$_totalAnsweredAll/$_totalQuestions',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MployaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: globalProgress,
                    minHeight: 4,
                    backgroundColor: MployaColors.borderLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      MployaColors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category + question counter
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: cat.bgColor,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cat.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                              child: Icon(
                                cat.icon,
                                color: cat.color,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              cat.name,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cat.color,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_currentQuestionIndex + 1}/${cat.questions.length}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cat.color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // Category progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppRadius.pill,
                          ),
                          child: LinearProgressIndicator(
                            value: categoryProgress,
                            minHeight: 5,
                            backgroundColor:
                                cat.color.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              cat.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Question
                  Text(
                    q.question,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: MployaColors.textPrimary,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Options A/B/C/D
                  ...List.generate(q.options.length, (i) {
                    final letter = String.fromCharCode(65 + i); // A, B, C, D
                    final isSelected = _selectedOption == i;
                    final isCorrect = i == q.correctIndex;

                    Color optionColor = MployaColors.white;
                    Color borderColor = MployaColors.border;
                    Color letterBg = MployaColors.surfaceVariant;
                    Color letterColor = MployaColors.textSecondary;

                    if (_answered) {
                      if (isCorrect) {
                        optionColor = MployaColors.tealLight;
                        borderColor = MployaColors.teal;
                        letterBg = MployaColors.teal;
                        letterColor = Colors.white;
                      } else if (isSelected && !isCorrect) {
                        optionColor = MployaColors.redLight;
                        borderColor = MployaColors.red;
                        letterBg = MployaColors.red;
                        letterColor = Colors.white;
                      }
                    } else if (isSelected) {
                      borderColor = cat.color;
                      letterBg = cat.color;
                      letterColor = Colors.white;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: GestureDetector(
                        onTap: () => _selectOption(i),
                        child: AnimatedContainer(
                          duration: AnimDurations.fast,
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: optionColor,
                            borderRadius: BorderRadius.circular(
                              AppRadius.lg,
                            ),
                            border: Border.all(
                              color: borderColor,
                              width: isSelected || (_answered && isCorrect)
                                  ? 1.5
                                  : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: AnimDurations.fast,
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: letterBg,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                                child: Center(
                                  child: _answered && isCorrect
                                      ? Icon(
                                          Icons.check_rounded,
                                          color: letterColor,
                                          size: 18,
                                        )
                                      : _answered &&
                                              isSelected &&
                                              !isCorrect
                                          ? Icon(
                                              Icons.close_rounded,
                                              color: letterColor,
                                              size: 18,
                                            )
                                          : Text(
                                              letter,
                                              style: GoogleFonts.outfit(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: letterColor,
                                              ),
                                            ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  q.options[i],
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: MployaColors.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  // Next button
                  if (_answered) ...[
                    const SizedBox(height: AppSpacing.md),
                    GestureDetector(
                      onTap: _nextQuestion,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: MployaColors.orangeGradient,
                          borderRadius: BorderRadius.circular(
                            AppRadius.pill,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: MployaColors.orange.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentQuestionIndex <
                                          _currentCategory
                                                  .questions.length -
                                              1 ||
                                      _currentCategoryIndex <
                                          _categories.length - 1
                                  ? 'Siguiente'
                                  : 'Ver Resultados',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Results Screen ─────────────────────────────────────────────

  Widget _buildResultsScreen() {
    final scores =
        List.generate(_categories.length, (i) => _categoryScore(i));
    final avgScore = scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;
    final totalCorrect =
        _correctCounts.values.fold(0, (sum, v) => sum + v);

    return Scaffold(
      backgroundColor: MployaColors.background,
      appBar: AppBar(
        backgroundColor: MployaColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () {
            setState(() {
              _showResults = false;
              _correctCounts.clear();
              _totalAnswered.clear();
            });
          },
        ),
        title: Text(
          'Resultados',
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
            // ─── Score Header ──────────────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: avgScore >= 0.8
                      ? [const Color(0xFF10B981), const Color(0xFF059669)]
                      : avgScore >= 0.6
                          ? [const Color(0xFFF97316), const Color(0xFFEA580C)]
                          : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: (avgScore >= 0.8
                            ? MployaColors.teal
                            : avgScore >= 0.6
                                ? MployaColors.orange
                                : MployaColors.red)
                        .withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    avgScore >= 0.8
                        ? Icons.emoji_events_rounded
                        : avgScore >= 0.6
                            ? Icons.thumb_up_rounded
                            : Icons.trending_up_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${(avgScore * 100).round()}%',
                    style: GoogleFonts.outfit(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    avgScore >= 0.8
                        ? '¡Excelente!'
                        : avgScore >= 0.6
                            ? '¡Buen trabajo!'
                            : 'Sigue practicando',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$totalCorrect de $_totalQuestions respuestas correctas',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // ─── Radar Chart ──────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perfil de Habilidades',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: MployaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 250,
                    child: CustomPaint(
                      size: const Size(double.infinity, 250),
                      painter: _RadarChartPainter(
                        labels: _categories.map((c) => c.name).toList(),
                        values: scores,
                        color: MployaColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ─── Category Scores ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
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
                      'Detalle por Categoría',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: MployaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ...List.generate(_categories.length, (i) {
                      final cat = _categories[i];
                      final score = _categoryScore(i);
                      final correct = _correctCounts[i] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cat.bgColor,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                              child: Icon(
                                cat.icon,
                                color: cat.color,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        cat.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: MployaColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '$correct/${cat.questions.length}',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: cat.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: score),
                                      duration: const Duration(
                                        milliseconds: 800,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, value, _) {
                                        return LinearProgressIndicator(
                                          value: value,
                                          minHeight: 8,
                                          backgroundColor: cat.color
                                              .withValues(alpha: 0.1),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            cat.color,
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
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ─── Retry Button ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: MployaButton(
                label: 'Repetir Evaluación',
                icon: Icons.refresh_rounded,
                onPressed: _startAssessment,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Radar Chart Painter ───────────────────────────────────────────

class _RadarChartPainter extends CustomPainter {
  _RadarChartPainter({
    required this.labels,
    required this.values,
    required this.color,
  });

  final List<String> labels;
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 30;
    final n = labels.length;
    if (n < 3) return;

    final angleStep = 2 * pi / n;

    // Draw grid rings
    for (int ring = 1; ring <= 4; ring++) {
      final r = radius * ring / 4;
      final gridPaint = Paint()
        ..color = MployaColors.border.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      final path = Path();
      for (int i = 0; i <= n; i++) {
        final angle = -pi / 2 + angleStep * (i % n);
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw axis lines
    for (int i = 0; i < n; i++) {
      final angle = -pi / 2 + angleStep * i;
      final endX = center.dx + radius * cos(angle);
      final endY = center.dy + radius * sin(angle);
      final axisPaint = Paint()
        ..color = MployaColors.border.withValues(alpha: 0.3)
        ..strokeWidth = 1;
      canvas.drawLine(center, Offset(endX, endY), axisPaint);
    }

    // Draw data polygon (filled)
    final fillPath = Path();
    final strokePath = Path();
    for (int i = 0; i <= n; i++) {
      final idx = i % n;
      final angle = -pi / 2 + angleStep * idx;
      final v = values[idx].clamp(0.0, 1.0);
      final r = radius * v;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        fillPath.moveTo(x, y);
        strokePath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
        strokePath.lineTo(x, y);
      }
    }
    fillPath.close();
    strokePath.close();

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(strokePath, strokePaint);

    // Draw data points
    for (int i = 0; i < n; i++) {
      final angle = -pi / 2 + angleStep * i;
      final v = values[i].clamp(0.0, 1.0);
      final r = radius * v;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);

      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()..color = color,
      );
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()..color = Colors.white,
      );
    }

    // Draw labels
    for (int i = 0; i < n; i++) {
      final angle = -pi / 2 + angleStep * i;
      final labelRadius = radius + 22;
      final x = center.dx + labelRadius * cos(angle);
      final y = center.dy + labelRadius * sin(angle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MployaColors.textSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

// ─── Header Pill Widget ────────────────────────────────────────────

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─── How It Works Step Widget ──────────────────────────────────────

class _HowItWorksStep extends StatelessWidget {
  const _HowItWorksStep({
    required this.number,
    required this.text,
  });

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: MployaColors.orangeSurface,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MployaColors.orange,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MployaColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
