import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// ClaudeAIService — Conexión con el backend Mploya AI (FastAPI + Claude)
//
// Provee 4 features de IA para Mploya:
//   1. matchScore      — Análisis profundo candidato ↔ oferta (0-100)
//   2. videoCoach      — Feedback del Video-CV por transcripción
//   3. generarBio      — Bio profesional generada desde el perfil
//   4. recomendaciones — Top ofertas recomendadas para un candidato
//
// Complementa ai_match_service.dart (embeddings) e ia_coach_service.dart
// (análisis local), añadiendo análisis semántico vía Claude.
// ─────────────────────────────────────────────────────────────────────────────

// ── Modelos de respuesta ──────────────────────────────────────────────────────

class ClaudeMatchResult {
  final int score;
  final String nivel;
  final List<String> fortalezas;
  final List<String> debilidades;
  final String recomendacion;
  final List<String> habilidadesFaltantes;
  final bool matchUbicacion;

  const ClaudeMatchResult({
    required this.score,
    required this.nivel,
    required this.fortalezas,
    required this.debilidades,
    required this.recomendacion,
    required this.habilidadesFaltantes,
    required this.matchUbicacion,
  });

  factory ClaudeMatchResult.fromJson(Map<String, dynamic> j) =>
      ClaudeMatchResult(
        score: (j['score'] as num).toInt(),
        nivel: j['nivel'] as String,
        fortalezas: List<String>.from(j['fortalezas'] ?? []),
        debilidades: List<String>.from(j['debilidades'] ?? []),
        recomendacion: j['recomendacion'] as String,
        habilidadesFaltantes:
            List<String>.from(j['habilidades_faltantes'] ?? []),
        matchUbicacion: j['match_ubicacion'] as bool? ?? false,
      );
}

class ClaudeVideoCoachResult {
  final int puntuacionGeneral;
  final String duracionEstimada;
  final List<String> puntosFuertes;
  final List<AreaMejora> areasMejora;
  final String? fraseDestacada;
  final String resumen;
  final Map<String, int> puntuaciones;
  final bool listoParaPublicar;

  const ClaudeVideoCoachResult({
    required this.puntuacionGeneral,
    required this.duracionEstimada,
    required this.puntosFuertes,
    required this.areasMejora,
    this.fraseDestacada,
    required this.resumen,
    required this.puntuaciones,
    required this.listoParaPublicar,
  });

  factory ClaudeVideoCoachResult.fromJson(Map<String, dynamic> j) =>
      ClaudeVideoCoachResult(
        puntuacionGeneral: (j['puntuacion_general'] as num).toInt(),
        duracionEstimada: j['duracion_estimada'] as String,
        puntosFuertes: List<String>.from(j['puntos_fuertes'] ?? []),
        areasMejora: (j['areas_mejora'] as List<dynamic>? ?? [])
            .map((e) => AreaMejora.fromJson(e as Map<String, dynamic>))
            .toList(),
        fraseDestacada: j['frase_destacada'] as String?,
        resumen: j['resumen'] as String,
        puntuaciones: Map<String, int>.from(
          (j['puntuaciones'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ),
        ),
        listoParaPublicar: j['listo_para_publicar'] as bool? ?? false,
      );
}

class AreaMejora {
  final String area;
  final String problema;
  final String sugerencia;

  const AreaMejora({
    required this.area,
    required this.problema,
    required this.sugerencia,
  });

  factory AreaMejora.fromJson(Map<String, dynamic> j) => AreaMejora(
        area: j['area'] as String,
        problema: j['problema'] as String,
        sugerencia: j['sugerencia'] as String,
      );
}

class ClaudeBioResult {
  final String bioCorta;
  final String bioCompleta;
  final String titularProfesional;
  final List<String> palabrasClave;

  const ClaudeBioResult({
    required this.bioCorta,
    required this.bioCompleta,
    required this.titularProfesional,
    required this.palabrasClave,
  });

  factory ClaudeBioResult.fromJson(Map<String, dynamic> j) => ClaudeBioResult(
        bioCorta: j['bio_corta'] as String,
        bioCompleta: j['bio_completa'] as String,
        titularProfesional: j['titular_profesional'] as String,
        palabrasClave: List<String>.from(j['palabras_clave'] ?? []),
      );
}

class ClaudeRecomendacion {
  final int numeroOferta;
  final int scoreMatch;
  final String razonPrincipal;
  final String accionSugerida;

  const ClaudeRecomendacion({
    required this.numeroOferta,
    required this.scoreMatch,
    required this.razonPrincipal,
    required this.accionSugerida,
  });

  factory ClaudeRecomendacion.fromJson(Map<String, dynamic> j) =>
      ClaudeRecomendacion(
        numeroOferta: (j['numero_oferta'] as num).toInt(),
        scoreMatch: (j['score_match'] as num).toInt(),
        razonPrincipal: j['razon_principal'] as String,
        accionSugerida: j['accion_sugerida'] as String,
      );
}

class ClaudeRecomendacionesResult {
  final List<ClaudeRecomendacion> recomendaciones;
  final String consejoGeneral;
  final String habilidadMasDemandada;

  const ClaudeRecomendacionesResult({
    required this.recomendaciones,
    required this.consejoGeneral,
    required this.habilidadMasDemandada,
  });

  factory ClaudeRecomendacionesResult.fromJson(Map<String, dynamic> j) =>
      ClaudeRecomendacionesResult(
        recomendaciones: (j['recomendaciones'] as List<dynamic>? ?? [])
            .map(
              (e) =>
                  ClaudeRecomendacion.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        consejoGeneral: j['consejo_general'] as String,
        habilidadMasDemandada: j['habilidad_mas_demandada'] as String,
      );
}

// ── Servicio ──────────────────────────────────────────────────────────────────

class ClaudeAIService {
  ClaudeAIService._();
  static final ClaudeAIService instance = ClaudeAIService._();

  // URL del backend IA — configurable vía --dart-define=MPLOYA_AI_URL=https://...
  // En producción: flutter build apk --dart-define=MPLOYA_AI_URL=https://mploya-ai.fly.dev
  // En desarrollo: usa localhost:8000 (o Edge Function si no está configurada)
  static const String _baseUrl = String.fromEnvironment(
    'MPLOYA_AI_URL',
    defaultValue: '', // Vacío = deshabilitado (usa Edge Function fallback)
  );

  static const String _apiKey = String.fromEnvironment(
    'MPLOYA_API_KEY',
    defaultValue: '',
  );

  static const Duration _timeout = Duration(seconds: 30);

  // ── Helper interno ─────────────────────────────────────────────────────────

  Future<T> _post<T>(
    String endpoint,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    if (_baseUrl.isEmpty) {
      throw Exception(
        'AI backend no configurado. Usa --dart-define=MPLOYA_AI_URL=https://...',
      );
    }
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              if (_apiKey.isNotEmpty) 'X-API-Key': _apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Error AI [$endpoint]: ${response.statusCode} — ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ ClaudeAIService.$endpoint: $e');
      rethrow;
    }
  }

  // ── 1. Match Score ─────────────────────────────────────────────────────────

  /// Analiza la compatibilidad profunda entre un candidato y una oferta.
  /// Complementa el score por embeddings con análisis semántico de Claude.
  Future<ClaudeMatchResult> matchScore({
    required Map<String, dynamic> candidato,
    required Map<String, dynamic> oferta,
  }) =>
      _post(
        '/ai/match-score',
        {'candidato': candidato, 'oferta': oferta},
        ClaudeMatchResult.fromJson,
      );

  // ── 2. Video-CV Coach ──────────────────────────────────────────────────────

  /// Analiza la transcripción de un Video-CV con Claude.
  /// Complementa el análisis local de IACoachService con feedback más rico.
  Future<ClaudeVideoCoachResult> videoCoach({
    required String transcripcion,
    required String nombreCandidato,
    String? puestoObjetivo,
  }) =>
      _post(
        '/ai/video-coach',
        {
          'transcripcion': transcripcion,
          'nombre_candidato': nombreCandidato,
          if (puestoObjetivo != null) 'puesto_objetivo': puestoObjetivo,
        },
        ClaudeVideoCoachResult.fromJson,
      );

  // ── 3. Generador de Bio ────────────────────────────────────────────────────

  /// Genera bio profesional personalizada desde los datos del perfil.
  /// [tono] puede ser: "profesional" | "creativo" | "conciso"
  /// Si el backend no está configurado, usa Gemini 2.0 Flash como fallback.
  Future<ClaudeBioResult> generarBio({
    required Map<String, dynamic> candidato,
    String tono = 'profesional',
  }) async {
    // Si hay backend configurado, usarlo
    if (_baseUrl.isNotEmpty) {
      return _post(
        '/ai/generar-bio',
        {'candidato': candidato, 'tono': tono},
        ClaudeBioResult.fromJson,
      );
    }

    // ── Fallback: Gemini 2.0 Flash directo ──
    const geminiKey = String.fromEnvironment(
      'GEMINI_API_KEY',
      // ⚠️ NUNCA poner API keys como defaultValue — se compilan en el APK.
      // Inyectar vía: flutter build apk --dart-define=GEMINI_API_KEY=...
      defaultValue: '',
    );

    if (geminiKey.isEmpty) {
      // Sin key → fallback local ultra básico
      final nombre = candidato['nombre'] ?? 'Profesional';
      final skills = (candidato['habilidades'] as List?)?.take(3).join(', ') ?? 'múltiples áreas';
      return ClaudeBioResult(
        bioCorta: '$nombre | Profesional con experiencia en $skills',
        bioCompleta: '$nombre es un profesional comprometido con experiencia en $skills. '
            'Apasionado por el crecimiento profesional y la innovación.',
        titularProfesional: '$nombre | $skills',
        palabrasClave: (candidato['habilidades'] as List?)?.cast<String>().take(5).toList()
            ?? ['profesional', 'experiencia', 'innovación'],
      );
    }

    final prompt = '''
Eres un experto en recursos humanos y copywriting profesional.
Genera una bio profesional para esta persona:

Nombre: ${candidato['nombre'] ?? 'Profesional'}
Habilidades: ${candidato['habilidades'] ?? []}
Experiencia: ${candidato['experiencia_anios'] ?? 0} años
Ciudad: ${candidato['ciudad'] ?? 'Latam'}
Educación: ${candidato['educacion'] ?? 'No especificada'}
Idiomas: ${candidato['idiomas'] ?? ['Español']}

Tono solicitado: $tono

Responde SOLO en JSON válido con esta estructura exacta:
{
  "bio_corta": "Bio de 1-2 oraciones para headline",
  "bio_completa": "Bio de 3-4 oraciones para perfil completo",
  "titular_profesional": "Titular corto tipo LinkedIn",
  "palabras_clave": ["keyword1", "keyword2", "keyword3", "keyword4", "keyword5"]
}
''';

    try {
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 500,
            'responseMimeType': 'application/json',
          },
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Gemini error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = ((data['candidates'] as List?)?.first['content']['parts'] as List?)
          ?.first['text'] as String? ?? '{}';
      final parsed = jsonDecode(text) as Map<String, dynamic>;
      return ClaudeBioResult.fromJson(parsed);
    } catch (e) {
      debugPrint('⚠️ Gemini bio fallback error: $e');
      // Fallback local ultra básico
      final nombre = candidato['nombre'] ?? 'Profesional';
      final skills = (candidato['habilidades'] as List?)?.take(3).join(', ') ?? 'múltiples áreas';
      return ClaudeBioResult(
        bioCorta: '$nombre | Profesional con experiencia en $skills',
        bioCompleta: '$nombre es un profesional comprometido con experiencia en $skills. '
            'Apasionado por el crecimiento profesional y la innovación.',
        titularProfesional: '$nombre | $skills',
        palabrasClave: (candidato['habilidades'] as List?)?.cast<String>().take(5).toList() 
            ?? ['profesional', 'experiencia', 'innovación'],
      );
    }
  }

  // ── 4. Recomendaciones de Ofertas ──────────────────────────────────────────

  /// Recomienda las mejores ofertas para un candidato, ordenadas por score.
  Future<ClaudeRecomendacionesResult> recomendaciones({
    required Map<String, dynamic> candidato,
    required List<Map<String, dynamic>> ofertas,
  }) =>
      _post(
        '/ai/recomendaciones',
        {'candidato': candidato, 'ofertas': ofertas},
        ClaudeRecomendacionesResult.fromJson,
      );

  // ── 5. Skill Assessment Quiz Generator ─────────────────────────────────────

  /// Genera un quiz de 5 preguntas para evaluar una skill.
  /// Si el backend no soporta el endpoint, genera un quiz local.
  Future<SkillQuiz> generateSkillQuiz({
    required String skillName,
    String difficulty = 'intermediate',
  }) async {
    try {
      if (_baseUrl.isEmpty) throw Exception('Backend no configurado');
      final response = await http.post(
        Uri.parse('$_baseUrl/ai/skill-quiz'),
        headers: {
          'Content-Type': 'application/json',
          if (_apiKey.isNotEmpty) 'X-API-Key': _apiKey,
        },
        body: jsonEncode({
          'skill_name': skillName,
          'difficulty': difficulty,
          'num_questions': 5,
        }),
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Quiz endpoint error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final questions = (data['data']?['questions'] as List<dynamic>? ?? [])
          .map((q) {
            final m = q as Map<String, dynamic>;
            return QuizQuestion(
              question: m['question']?.toString() ?? '',
              options: List<String>.from(m['options'] ?? []),
              correctIndex: (m['correct_index'] as num?)?.toInt() ?? 0,
            );
          }).toList();

      return SkillQuiz(skillName: skillName, questions: questions);
    } catch (e) {
      debugPrint('⚠️ ClaudeAIService.generateSkillQuiz fallback: $e');
      // Fallback: retorna null para que el caller use su propio fallback
      rethrow;
    }
  }
}

// ── Skill Quiz Models (used by both ClaudeAIService and SkillAssessmentService) ──
class SkillQuiz {
  final String skillName;
  final List<QuizQuestion> questions;
  const SkillQuiz({required this.skillName, required this.questions});
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  const QuizQuestion({required this.question, required this.options, required this.correctIndex});
}
