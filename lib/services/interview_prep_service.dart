import 'package:flutter/foundation.dart';
import 'claude_ai_service.dart';

/// Genera preguntas de entrevista personalizadas usando IA
/// basado en el match candidato ↔ oferta.
class InterviewPrepService {
  InterviewPrepService._();
  static final instance = InterviewPrepService._();

  /// Genera preguntas de entrevista personalizadas.
  /// [candidateSkills] - skills del candidato
  /// [jobTitle] - título del puesto
  /// [jobRequirements] - requisitos del puesto
  Future<InterviewPrepResult> generateQuestions({
    required List<String> candidateSkills,
    required String jobTitle,
    String? companyName,
    List<String>? jobRequirements,
  }) async {
    try {
      return await _callAI(candidateSkills, jobTitle, companyName, jobRequirements);
    } catch (e) {
      debugPrint('InterviewPrep: AI error, using fallback: $e');
      return _fallback(jobTitle, candidateSkills);
    }
  }

  Future<InterviewPrepResult> _callAI(
    List<String> skills, String title, String? company, List<String>? reqs,
  ) async {
    // Si el backend no está configurado, usar fallback local
    try {
      final aiService = ClaudeAIService.instance;
      final result = await aiService.generateSkillQuiz(
        skillName: 'Interview: $title',
        difficulty: 'advanced',
      );
      // Adapt quiz to interview format
      return InterviewPrepResult(
        jobTitle: title,
        questions: result.questions.map((q) => InterviewQuestion(
          question: q.question,
          category: 'technical',
          tip: 'Relacioná tu respuesta con tu experiencia concreta.',
          sampleAnswer: q.options[q.correctIndex],
        )).toList(),
        generalTips: [
          'Investigá la empresa antes de la entrevista',
          'Prepará ejemplos concretos de tu experiencia con ${skills.take(3).join(", ")}',
          'Practicá el método STAR para respuestas estructuradas',
          'Prepará preguntas para hacer al entrevistador',
        ],
      );
    } catch (_) {
      rethrow;
    }
  }

  InterviewPrepResult _fallback(String title, List<String> skills) {
    final skillStr = skills.take(3).join(', ');
    return InterviewPrepResult(
      jobTitle: title,
      questions: [
        InterviewQuestion(
          question: 'Contame sobre tu experiencia con $skillStr.',
          category: 'technical',
          tip: 'Usá el método STAR: Situación, Tarea, Acción, Resultado.',
          sampleAnswer: 'En mi último proyecto, implementé...',
        ),
        InterviewQuestion(
          question: '¿Cuál fue el mayor desafío técnico que enfrentaste y cómo lo resolviste?',
          category: 'behavioral',
          tip: 'Mostrá tu capacidad de resolución de problemas.',
        ),
        InterviewQuestion(
          question: '¿Por qué te interesa este puesto de $title?',
          category: 'motivation',
          tip: 'Conectá tus goals con la misión de la empresa.',
        ),
        InterviewQuestion(
          question: '¿Cómo manejás el trabajo bajo presión y deadlines ajustados?',
          category: 'behavioral',
          tip: 'Dá un ejemplo concreto con métricas.',
        ),
        InterviewQuestion(
          question: '¿Dónde te ves profesionalmente en 3 años?',
          category: 'motivation',
          tip: 'Mostrá ambición pero alineada al crecimiento en la empresa.',
        ),
        InterviewQuestion(
          question: '¿Cómo te mantenés actualizado en $skillStr?',
          category: 'technical',
          tip: 'Mencioná cursos, blogs, proyectos personales.',
        ),
      ],
      generalTips: [
        'Investigá la empresa a fondo antes de la entrevista',
        'Prepará 3 ejemplos concretos de logros medibles',
        'Practicá respuestas en voz alta (grabate con Video-Pitch)',
        'Vestite profesional incluso para entrevistas remotas',
        'Llegá 5 min antes y tené tu CV a mano',
      ],
    );
  }
}

class InterviewPrepResult {
  final String jobTitle;
  final List<InterviewQuestion> questions;
  final List<String> generalTips;
  const InterviewPrepResult({required this.jobTitle, required this.questions, required this.generalTips});
}

class InterviewQuestion {
  final String question;
  final String category; // technical, behavioral, motivation
  final String? tip;
  final String? sampleAnswer;
  const InterviewQuestion({required this.question, required this.category, this.tip, this.sampleAnswer});
}
