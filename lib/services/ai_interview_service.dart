import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'storage_service.dart';

class AIInterviewService {
  AIInterviewService._();
  static final instance = AIInterviewService._();

  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  // ── Fetch Interview by ID ──
  Future<Interview?> fetchInterview(String interviewId) async {
    if (interviewId.startsWith('demo-')) {
      return Interview(
        id: interviewId,
        jobId: 'demo-job',
        candidateId: 'demo-candidate',
        status: interviewId == 'demo-completed' ? 'completed' : 'pending',
        createdAt: DateTime.now(),
      );
    }

    try {
      final res = await _supabase
          .from('interviews')
          .select()
          .eq('id', interviewId)
          .maybeSingle();
      if (res == null) return null;
      return Interview.fromJson(res);
    } catch (e) {
      debugPrint('Error fetching interview: $e');
      return null;
    }
  }

  // ── Fetch Interviews (My role as Candidate or Company) ──
  Future<List<Interview>> fetchMyInterviews() async {
    if (_uid == null) return [];
    try {
      // Retorna entrevistas donde soy candidato o donde la vacante pertenece a mi empresa
      final res = await _supabase
          .from('interviews')
          .select('*, jobs!inner(company_id)')
          .or('candidate_id.eq.$_uid,jobs.company_id.eq.$_uid')
          .order('created_at', ascending: false);
      
      return (res as List).map((r) => Interview.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error fetching my interviews: $e');
      return [];
    }
  }

  // ── Fetch Questions for an Interview ──
  Future<List<InterviewQuestion>> fetchQuestions(String interviewId) async {
    if (interviewId.startsWith('demo-')) {
      return [
        InterviewQuestion(
          id: 'q1',
          interviewId: interviewId,
          ord: 0,
          text: '¿Cuáles han sido tus desafíos más grandes al desarrollar con Flutter y cómo los resolviste?',
          category: 'technical',
          generatedBy: 'ai',
          createdAt: DateTime.now(),
        ),
        InterviewQuestion(
          id: 'q2',
          interviewId: interviewId,
          ord: 1,
          text: 'Cuéntanos sobre alguna situación en la que tuviste un desacuerdo técnico con tu equipo y cómo llegaron a un consenso.',
          category: 'behavioral',
          generatedBy: 'ai',
          createdAt: DateTime.now(),
        ),
        InterviewQuestion(
          id: 'q3',
          interviewId: interviewId,
          ord: 2,
          text: '¿Qué tipo de proyectos o tecnologías te entusiasma aprender y aplicar en tu día a día?',
          category: 'motivation',
          generatedBy: 'ai',
          createdAt: DateTime.now(),
        ),
      ];
    }

    try {
      final res = await _supabase
          .from('interview_questions')
          .select()
          .eq('interview_id', interviewId)
          .order('ord');
      return (res as List).map((r) => InterviewQuestion.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error fetching interview questions: $e');
      return [];
    }
  }

  // ── Trigger Question Generation (Edge Function) ──
  Future<bool> triggerQuestionGeneration(String interviewId) async {
    if (interviewId.startsWith('demo-')) {
      return true;
    }

    try {
      debugPrint('🧠 Generando preguntas de entrevista...');
      final response = await _supabase.functions.invoke(
        'generate-interview-questions',
        body: {'interview_id': interviewId},
      );

      if (response.status == 200) {
        debugPrint('✅ Preguntas generadas correctamente');
        return true;
      }
      debugPrint('⚠️ Fallo en Edge Function al generar preguntas: ${response.status}');
      return false;
    } catch (e) {
      debugPrint('Error triggering question generation: $e');
      return false;
    }
  }

  // ── Submit Answer ──
  Future<bool> submitAnswer({
    required String interviewId,
    required String questionId,
    required XFile file,
    String? transcript,
  }) async {
    if (interviewId.startsWith('demo-')) {
      return true;
    }

    try {
      debugPrint('📤 Subiendo video de respuesta...');
      // 1. Subir a Storage
      final videoUrl = await StorageService.instance.uploadInterviewVideo(
        interviewId,
        questionId,
        file,
      );

      if (videoUrl == null) {
        debugPrint('🔴 Error al subir video de respuesta');
        return false;
      }

      // 2. Insertar respuesta en BD
      debugPrint('💾 Guardando registro de respuesta en BD...');
      await _supabase.from('interview_answers').insert({
        'interview_id': interviewId,
        'question_id': questionId,
        'video_url': videoUrl,
        'transcript': transcript ?? '',
      });

      return true;
    } catch (e) {
      debugPrint('Error submitting answer: $e');
      return false;
    }
  }

  // ── Trigger Report Generation (Edge Function) ──
  Future<bool> triggerReportGeneration(String interviewId) async {
    if (interviewId.startsWith('demo-')) {
      return true;
    }

    try {
      debugPrint('🧠 Generando reporte de entrevista con IA...');
      final response = await _supabase.functions.invoke(
        'generate-interview-report',
        body: {'interview_id': interviewId},
      );

      if (response.status == 200) {
        debugPrint('✅ Reporte generado correctamente');
        return true;
      }
      debugPrint('⚠️ Fallo al generar reporte: ${response.status}');
      return false;
    } catch (e) {
      debugPrint('Error triggering report generation: $e');
      return false;
    }
  }

  // ── Fetch Interview Report ──
  Future<InterviewReport?> fetchReport(String interviewId) async {
    if (interviewId.startsWith('demo-')) {
      return InterviewReport(
        id: 'r1',
        interviewId: interviewId,
        summary: 'Elena G. demuestra un alto nivel técnico en el ecosistema de Flutter. Responde de forma madura a situaciones de conflicto y muestra gran alineación de valores con el proyecto.',
        competencies: [
          {'name': 'Flutter & Dart', 'score': 95, 'note': 'Excelente conocimiento del ciclo de vida y optimización de renderizado.'},
          {'name': 'Resolución de Conflictos', 'score': 88, 'note': 'Afronta de manera madura las discrepancias en equipos multidisciplinares.'},
          {'name': 'Motivación & Fit Cultural', 'score': 92, 'note': 'Muestra un genuino interés en la visión a largo plazo.'},
        ],
        keywords: ['Flutter', 'Riverpod', 'Clean Architecture', 'Trabajo en Equipo', 'Liderazgo'],
        score: 92,
        rationale: 'El candidato posee un dominio excepcional de las herramientas principales de desarrollo. Su comunicación es fluida y estructura de manera lógica cada respuesta.',
        createdAt: DateTime.now(),
      );
    }

    try {
      final res = await _supabase
          .from('interview_reports')
          .select()
          .eq('interview_id', interviewId)
          .maybeSingle();
      if (res == null) return null;
      return InterviewReport.fromJson(res);
    } catch (e) {
      debugPrint('Error fetching report: $e');
      return null;
    }
  }

  // ── Fetch Answers for an Interview ──
  Future<List<Map<String, dynamic>>> fetchAnswers(String interviewId) async {
    if (interviewId.startsWith('demo-')) {
      return [
        {
          'id': 'a1',
          'question_id': 'q1',
          'video_url': 'https://assets.mixkit.co/videos/preview/mixkit-man-working-on-his-laptop-in-an-office-42352-large.mp4',
          'transcript': 'Para mí, el mayor desafío en Flutter ha sido la optimización del rendimiento en listas dinámicas de gran tamaño. Lo resolví utilizando constructores ListView.builder eficientes y delegando los cálculos pesados a isolates para mantener el hilo de UI liberado.',
        },
        {
          'id': 'a2',
          'question_id': 'q2',
          'video_url': 'https://assets.mixkit.co/videos/preview/mixkit-man-working-on-his-laptop-in-an-office-42352-large.mp4',
          'transcript': 'Tuvimos una discusión técnica sobre si usar Clean Architecture o una estructura más simple en un proyecto ágil. Creé un prototipo de ambas opciones en 1 día y mostré al equipo las ventajas a largo plazo de robustez de la arquitectura limpia, logrando convencerlos.',
        },
        {
          'id': 'a3',
          'question_id': 'q3',
          'video_url': 'https://assets.mixkit.co/videos/preview/mixkit-man-working-on-his-laptop-in-an-office-42352-large.mp4',
          'transcript': 'Me entusiasma mucho profundizar en las nuevas capacidades de compilación nativa en Flutter y la integración con modelos de lenguaje locales para automatizar procesos en tiempo real directamente en el cliente.',
        },
      ];
    }

    try {
      final res = await _supabase
          .from('interview_answers')
          .select()
          .eq('interview_id', interviewId);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('Error fetching answers: $e');
      return [];
    }
  }

  // ── Create New Interview (Company action) ──
  Future<Interview?> createInterview({
    required String jobId,
    required String candidateId,
  }) async {
    try {
      final row = await _supabase.from('interviews').insert({
        'job_id': jobId,
        'candidate_id': candidateId,
        'status': 'pending',
      }).select().single();
      
      final interview = Interview.fromJson(row);
      // Auto-disparar generación de preguntas iniciales
      await triggerQuestionGeneration(interview.id);
      return interview;
    } catch (e) {
      debugPrint('Error creating interview: $e');
      return null;
    }
  }
}
