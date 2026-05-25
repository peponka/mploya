/// Servicio de IA generativa con Google Gemini.
///
/// Provee funcionalidades de análisis de video pitches,
/// generación de resúmenes de perfil y sugerencias de hashtags.
/// Degrada graciosamente si la API key no está configurada.
library;

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'package:mploya/config/constants.dart';
import 'package:mploya/config/env.dart';

/// Servicio singleton para interactuar con Google Gemini AI.
///
/// Debe accederse a través de [GeminiService.instance].
/// Si la API key no está configurada, los métodos retornan
/// respuestas por defecto en lugar de lanzar errores.
///
/// ```dart
/// final result = await GeminiService.instance.analyzeVideoPitch(
///   'Transcripción del video...',
/// );
/// ```
class GeminiService {
  GeminiService._();

  static final GeminiService _instance = GeminiService._();

  /// Instancia singleton del servicio.
  static GeminiService get instance => _instance;

  /// Modelo de Gemini (se inicializa lazy cuando hay API key).
  GenerativeModel? _model;

  /// Indica si el servicio está disponible (API key configurada).
  bool get isAvailable => Env.geminiApiKey.isNotEmpty;

  /// Obtiene o crea el modelo de Gemini.
  GenerativeModel? get _geminiModel {
    if (!isAvailable) return null;

    _model ??= GenerativeModel(
      model: kGeminiModel,
      apiKey: Env.geminiApiKey,
    );

    return _model;
  }

  // ─────────────────────────────────────────
  // Análisis de Video Pitch
  // ─────────────────────────────────────────

  /// Analiza la transcripción de un video pitch y retorna métricas.
  ///
  /// Retorna un [Map] con:
  /// - `score` (int 0-100): puntuación general
  /// - `strengths` (List<String>): fortalezas detectadas
  /// - `improvements` (List<String>): áreas de mejora
  /// - `summary` (String): resumen general del análisis
  ///
  /// Si la API key no está configurada, retorna respuesta por defecto.
  Future<Map<String, dynamic>> analyzeVideoPitch(String transcription) async {
    if (!isAvailable || transcription.trim().isEmpty) {
      return _defaultPitchAnalysis();
    }

    try {
      final model = _geminiModel!;
      final prompt = '''
Eres un experto en recursos humanos y coaching profesional.
Analiza la siguiente transcripción de un video pitch de un candidato
buscando empleo. Evalúa su presentación, claridad, confianza y contenido.

Transcripción:
"""
$transcription
"""

Responde EXACTAMENTE en este formato (sin markdown, sin bloques de código):
SCORE: [número del 0 al 100]
SUMMARY: [resumen de 1-2 oraciones en español]
STRENGTHS:
- [fortaleza 1]
- [fortaleza 2]
- [fortaleza 3]
IMPROVEMENTS:
- [mejora 1]
- [mejora 2]
- [mejora 3]
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';

      return _parsePitchResponse(text);
    } catch (e) {
      debugPrint('❌ Error analizando video pitch: $e');
      return _defaultPitchAnalysis();
    }
  }

  /// Parsea la respuesta del análisis de pitch.
  Map<String, dynamic> _parsePitchResponse(String text) {
    try {
      // Extraer score
      final scoreMatch = RegExp(r'SCORE:\s*(\d+)').firstMatch(text);
      final score = scoreMatch != null
          ? int.tryParse(scoreMatch.group(1)!) ?? 70
          : 70;

      // Extraer summary
      final summaryMatch = RegExp(r'SUMMARY:\s*(.+)').firstMatch(text);
      final summary = summaryMatch?.group(1)?.trim() ??
          'Análisis no disponible.';

      // Extraer strengths
      final strengthsSection = RegExp(
        r'STRENGTHS:\s*([\s\S]*?)(?=IMPROVEMENTS:|$)',
      ).firstMatch(text);
      final strengths = _extractBulletPoints(
        strengthsSection?.group(1) ?? '',
      );

      // Extraer improvements
      final improvementsSection = RegExp(
        r'IMPROVEMENTS:\s*([\s\S]*?)$',
      ).firstMatch(text);
      final improvements = _extractBulletPoints(
        improvementsSection?.group(1) ?? '',
      );

      return {
        'score': score.clamp(0, 100),
        'strengths': strengths.isNotEmpty
            ? strengths
            : ['Buena presentación general'],
        'improvements': improvements.isNotEmpty
            ? improvements
            : ['Agregar más detalles sobre experiencia'],
        'summary': summary,
      };
    } catch (e) {
      debugPrint('❌ Error parseando respuesta de pitch: $e');
      return _defaultPitchAnalysis();
    }
  }

  /// Extrae puntos con viñetas de un bloque de texto.
  List<String> _extractBulletPoints(String text) {
    return text
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^\s*[-•]\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// Respuesta por defecto cuando la IA no está disponible.
  Map<String, dynamic> _defaultPitchAnalysis() {
    return {
      'score': 0,
      'strengths': <String>[
        'Video recibido correctamente',
      ],
      'improvements': <String>[
        'Configura GEMINI_API_KEY para obtener análisis detallado',
      ],
      'summary': 'Análisis de IA no disponible. '
          'Configura tu API key de Gemini para habilitar esta función.',
    };
  }

  // ─────────────────────────────────────────
  // Resumen de Perfil
  // ─────────────────────────────────────────

  /// Genera un resumen/análisis de personalidad profesional basado
  /// en los datos del perfil del usuario.
  ///
  /// Si la API key no está configurada, retorna un texto genérico.
  Future<String> generateProfileSummary({
    required String name,
    required String headline,
    required String bio,
    required List<String> skills,
  }) async {
    if (!isAvailable) {
      return 'Configura GEMINI_API_KEY para generar un resumen '
          'personalizado de tu perfil con IA.';
    }

    try {
      final model = _geminiModel!;
      final skillsText = skills.join(', ');
      final prompt = '''
Eres un experto en marca personal y desarrollo profesional.
Genera un análisis breve de personalidad profesional (2-3 párrafos en español)
para un candidato con los siguientes datos:

Nombre: $name
Título profesional: $headline
Bio: $bio
Habilidades: $skillsText

El análisis debe ser motivador, profesional y destacar sus fortalezas únicas.
No uses formato markdown, solo texto plano.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '';

      if (text.isEmpty) {
        return 'No se pudo generar el resumen. Intenta de nuevo más tarde.';
      }

      return text;
    } catch (e) {
      debugPrint('❌ Error generando resumen de perfil: $e');
      return 'Error al generar el resumen. Intenta de nuevo más tarde.';
    }
  }

  // ─────────────────────────────────────────
  // Sugerencias de Hashtags
  // ─────────────────────────────────────────

  /// Sugiere hashtags relevantes basados en una descripción de contenido.
  ///
  /// Retorna una lista de hashtags (con #) o una lista vacía si falla.
  Future<List<String>> suggestHashtags(String description) async {
    if (!isAvailable || description.trim().isEmpty) {
      return <String>[];
    }

    try {
      final model = _geminiModel!;
      final prompt = '''
Genera exactamente 10 hashtags relevantes en español para el siguiente
contenido profesional/laboral. Los hashtags deben ser relevantes para
búsqueda de empleo y networking profesional en Latinoamérica.

Contenido: $description

Responde SOLO con los hashtags, uno por línea, cada uno empezando con #.
No agregues explicaciones ni texto adicional.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';

      final hashtags = text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.startsWith('#') && line.length > 1)
          .take(10)
          .toList();

      return hashtags.isNotEmpty ? hashtags : <String>[];
    } catch (e) {
      debugPrint('❌ Error sugiriendo hashtags: $e');
      return <String>[];
    }
  }
}
