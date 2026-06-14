import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IACoachService — Motor de coaching IA para Video-Pitches
//
// Analiza el video-pitch del candidato ANTES de publicarlo y devuelve
// feedback accionable en 4 categorías:
//   1. Comunicación: velocidad del habla, claridad, muletillas
//   2. Contenido: mención de experiencia, presentación, propuesta de valor
//   3. Técnico: (placeholder — requiere análisis de imagen server-side)
//   4. Impacto: energía, estructura, cierre
//
// Flujo:
//   1. Se envía el video (o su URL temporal) a la Edge Function `analyze-pitch`
//   2. La EF transcribe con Deepgram/Whisper + analiza con LLM
//   3. Devuelve PitchAnalysis con scores y tips
//   4. Si la EF no está disponible, se usa análisis local por transcripción
// ─────────────────────────────────────────────────────────────────────────────

/// Resultado del análisis de un video-pitch
class PitchAnalysis {
  final int overallScore;         // 0-100
  final CategoryScore communication;
  final CategoryScore content;
  final CategoryScore technical;
  final CategoryScore impact;
  final String summary;
  final List<String> topTips;
  final int wordCount;
  final int estimatedWPM;
  final int durationSeconds;

  const PitchAnalysis({
    required this.overallScore,
    required this.communication,
    required this.content,
    required this.technical,
    required this.impact,
    required this.summary,
    required this.topTips,
    required this.wordCount,
    required this.estimatedWPM,
    required this.durationSeconds,
  });
}

/// Score individual por categoría
class CategoryScore {
  final String name;
  final String emoji;
  final int score; // 0-100
  final String label; // "Excelente", "Bueno", "Mejorable"
  final List<String> tips;

  const CategoryScore({
    required this.name,
    required this.emoji,
    required this.score,
    required this.label,
    required this.tips,
  });
}

class IACoachService {
  IACoachService._();
  static final IACoachService instance = IACoachService._();

  final _supabase = Supabase.instance.client;

  /// Analiza un video-pitch completo.
  ///
  /// [videoUrl] — URL del video en Supabase Storage (ya subido temporalmente)
  /// [durationSeconds] — Duración del video en segundos
  ///
  /// Intenta usar la Edge Function `analyze-pitch` primero.
  /// Si falla, ejecuta análisis local con transcripción existente.
  Future<PitchAnalysis> analyzePitch({
    required String videoUrl,
    required int durationSeconds,
    String? existingTranscript,
  }) async {
    // ── Intentar Edge Function (análisis completo server-side) ──
    try {
      final response = await _supabase.functions.invoke(
        'analyze-pitch',
        body: {
          'video_url': videoUrl,
          'duration_seconds': durationSeconds,
          'language': 'es',
        },
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return _parseServerResponse(data, durationSeconds);
      }
    } catch (e) {
      debugPrint('⚠️ Edge Function analyze-pitch no disponible: $e');
    }

    // ── Fallback: análisis local por transcripción ──
    return _analyzeLocally(
      transcript: existingTranscript ?? '',
      durationSeconds: durationSeconds,
    );
  }

  /// Parsea la respuesta del servidor (Edge Function)
  PitchAnalysis _parseServerResponse(
    Map<String, dynamic> data,
    int duration,
  ) {
    try {
      return PitchAnalysis(
        overallScore: (data['overall_score'] as num?)?.toInt() ?? 70,
        communication: _parseCategoryFromServer(
          data['communication'],
          'Comunicación',
          '🗣️',
        ),
        content: _parseCategoryFromServer(
          data['content'],
          'Contenido',
          '📋',
        ),
        technical: _parseCategoryFromServer(
          data['technical'],
          'Técnico',
          '🎬',
        ),
        impact: _parseCategoryFromServer(
          data['impact'],
          'Impacto',
          '⚡',
        ),
        summary: data['summary']?.toString() ?? 'Análisis completado.',
        topTips: List<String>.from(data['top_tips'] ?? []),
        wordCount: (data['word_count'] as num?)?.toInt() ?? 0,
        estimatedWPM: (data['wpm'] as num?)?.toInt() ?? 0,
        durationSeconds: duration,
      );
    } catch (e) {
      debugPrint('❌ Error parsing server response: $e');
      return _analyzeLocally(transcript: '', durationSeconds: duration);
    }
  }

  CategoryScore _parseCategoryFromServer(
    dynamic raw,
    String name,
    String emoji,
  ) {
    if (raw is! Map<String, dynamic>) {
      return CategoryScore(
        name: name,
        emoji: emoji,
        score: 70,
        label: 'Bueno',
        tips: ['Análisis no disponible para esta categoría.'],
      );
    }
    final score = (raw['score'] as num?)?.toInt() ?? 70;
    return CategoryScore(
      name: name,
      emoji: emoji,
      score: score,
      label: _scoreLabel(score),
      tips: List<String>.from(raw['tips'] ?? []),
    );
  }

  // ── Análisis Local (fallback inteligente) ──────────────────────────────────

  PitchAnalysis _analyzeLocally({
    required String transcript,
    required int durationSeconds,
  }) {
    final words = transcript
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final wordCount = words.length;
    final duration = durationSeconds > 0 ? durationSeconds : 30;
    final wpm = wordCount > 0 ? ((wordCount / duration) * 60).round() : 0;

    // ── Comunicación ──
    final commTips = <String>[];
    int commScore = 70;

    if (wordCount == 0) {
      commScore = 50;
      commTips.add('No pudimos detectar audio. Asegúrate de hablar claro y cerca del micrófono.');
    } else {
      if (wpm > 170) {
        commScore -= 15;
        commTips.add('Hablaste a ~$wpm palabras/min. Intentá bajar a 130-150 para mayor claridad.');
      } else if (wpm < 90) {
        commScore -= 10;
        commTips.add('Tu ritmo fue de ~$wpm palabras/min. Podés ser un poco más dinámico sin perder claridad.');
      } else {
        commScore += 10;
        commTips.add('Buen ritmo de habla (~$wpm palabras/min). Perfecto para transmitir confianza.');
      }

      // Detectar muletillas comunes
      final fillerWords = ['ehh', 'emmm', 'este', 'bueno', 'o sea', 'tipo', 'como que', 'digamos'];
      final foundFillers = <String>[];
      final lowerTranscript = transcript.toLowerCase();
      for (final filler in fillerWords) {
        final count = RegExp(filler).allMatches(lowerTranscript).length;
        if (count >= 2) foundFillers.add('"$filler" (${count}x)');
      }
      if (foundFillers.isNotEmpty) {
        commScore -= 10;
        commTips.add('Detectamos muletillas: ${foundFillers.join(", ")}. Intentá reemplazarlas con pausas breves.');
      }
    }
    commScore = commScore.clamp(0, 100);

    // ── Contenido ──
    final contentTips = <String>[];
    int contentScore = 65;

    if (wordCount > 0) {
      final lower = transcript.toLowerCase();

      // ¿Se presentó?
      final hasIntro = lower.contains('soy ') || lower.contains('me llamo') ||
          lower.contains('mi nombre es') || lower.contains('hola');
      if (hasIntro) {
        contentScore += 10;
        contentTips.add('✓ Buena presentación inicial.');
      } else {
        contentTips.add('No detectamos una presentación. Arrancá con "Hola, soy [tu nombre]..."');
      }

      // ¿Mencionó experiencia?
      final hasExperience = lower.contains('experiencia') || lower.contains('trabajé') ||
          lower.contains('años') || lower.contains('proyecto') ||
          lower.contains('logré') || lower.contains('resultado') ||
          lower.contains('empresa') || lower.contains('equipo');
      if (hasExperience) {
        contentScore += 10;
        contentTips.add('✓ Mencionaste experiencia concreta. Eso genera confianza.');
      } else {
        contentTips.add('Agregá un dato concreto de tu experiencia (años, logros, proyectos).');
      }

      // ¿Propuesta de valor?
      final hasProposal = lower.contains('puedo aportar') || lower.contains('mi objetivo') ||
          lower.contains('me especializo') || lower.contains('valor') ||
          lower.contains('diferencia') || lower.contains('pasión');
      if (hasProposal) {
        contentScore += 10;
        contentTips.add('✓ Tu propuesta de valor es clara.');
      } else {
        contentTips.add('Cerrá con tu propuesta de valor: ¿qué te hace diferente?');
      }

      // ¿Call to action / cierre?
      final hasCTA = lower.contains('hablemos') || lower.contains('contacto') ||
          lower.contains('conectemos') || lower.contains('disponible');
      if (hasCTA) {
        contentScore += 5;
      } else {
        contentTips.add('Agregá un cierre accionable: "Hablemos" o "Estoy disponible para..."');
      }
    } else {
      contentTips.add('Grabá tu pitch mencionando: quién sos, qué hiciste, y qué podés aportar.');
    }
    contentScore = contentScore.clamp(0, 100);

    // ── Técnico (análisis limitado sin server-side) ──
    int techScore = 72;
    final techTips = <String>[];

    if (duration < 15) {
      techScore -= 15;
      techTips.add('Tu video dura solo $duration seg. Apuntá a 30-60 segundos para un pitch completo.');
    } else if (duration > 90) {
      techScore -= 10;
      techTips.add('Tu video dura ${duration}s. Intentá mantenerlo en 60 seg máx para retener atención.');
    } else {
      techScore += 5;
      techTips.add('✓ Buena duración ($duration seg). Ideal para un pitch.');
    }

    techTips.add('Tip: Grabá con buena iluminación (luz natural frente a vos), fondo limpio y audio sin ruido.');
    techScore = techScore.clamp(0, 100);

    // ── Impacto ──
    int impactScore = 68;
    final impactTips = <String>[];

    if (wordCount > 0) {
      // Energía: ¿usa exclamaciones, pregunta retórica?
      final exclamations = '!'.allMatches(transcript).length;
      final questions = '?'.allMatches(transcript).length;
      if (exclamations > 0 || questions > 0) {
        impactScore += 8;
        impactTips.add('✓ Buen uso de preguntas o énfasis. Eso conecta con el reclutador.');
      }

      // Palabras de acción/logro
      final actionWords = ['logré', 'lideré', 'construí', 'optimicé', 'crecí',
          'implementé', 'reduje', 'aumenté', 'creé', 'mejoré', 'diseñé'];
      final foundActions = actionWords.where((w) => transcript.toLowerCase().contains(w)).toList();
      if (foundActions.isNotEmpty) {
        impactScore += 12;
        impactTips.add('✓ Usaste verbos de impacto (${foundActions.take(3).join(", ")}). Excelente.');
      } else {
        impactTips.add('Usá verbos de acción: "Logré...", "Lideré...", "Construí..." para mayor impacto.');
      }
    }

    if (duration >= 20 && duration <= 60 && wordCount >= 50) {
      impactScore += 5;
      impactTips.add('✓ Tu pitch tiene buen balance entre duración y contenido.');
    } else if (wordCount < 30 && wordCount > 0) {
      impactTips.add('Tu mensaje es muy breve. Un pitch convincente tiene al menos 50-80 palabras.');
    }
    impactScore = impactScore.clamp(0, 100);

    // ── Score general (promedio ponderado) ──
    final overall = ((commScore * 0.25) + (contentScore * 0.35) + (techScore * 0.15) + (impactScore * 0.25)).round();

    // ── Top Tips (los 3 más importantes — priorizando los no-check) ──
    final allTips = <String>[
      ...commTips.where((t) => !t.startsWith('✓')),
      ...contentTips.where((t) => !t.startsWith('✓')),
      ...impactTips.where((t) => !t.startsWith('✓')),
      ...techTips.where((t) => !t.startsWith('✓')),
    ];
    final topTips = allTips.take(3).toList();
    if (topTips.isEmpty) {
      topTips.add('¡Excelente pitch! Está listo para publicar.');
    }

    // ── Summary ──
    String summary;
    if (overall >= 85) {
      summary = '¡Pitch excelente! Tenés un video muy completo que va a captar la atención de los reclutadores.';
    } else if (overall >= 70) {
      summary = 'Buen pitch. Con algunos ajustes menores podés llevar tu presentación al siguiente nivel.';
    } else if (overall >= 50) {
      summary = 'Tu pitch tiene potencial. Revisá los tips para mejorar tu comunicación y contenido.';
    } else {
      summary = 'Te recomendamos re-grabar teniendo en cuenta los tips. ¡Cada intento es una mejora!';
    }

    return PitchAnalysis(
      overallScore: overall.clamp(0, 100),
      communication: CategoryScore(
        name: 'Comunicación',
        emoji: '🗣️',
        score: commScore,
        label: _scoreLabel(commScore),
        tips: commTips,
      ),
      content: CategoryScore(
        name: 'Contenido',
        emoji: '📋',
        score: contentScore,
        label: _scoreLabel(contentScore),
        tips: contentTips,
      ),
      technical: CategoryScore(
        name: 'Técnico',
        emoji: '🎬',
        score: techScore,
        label: _scoreLabel(techScore),
        tips: techTips,
      ),
      impact: CategoryScore(
        name: 'Impacto',
        emoji: '⚡',
        score: impactScore,
        label: _scoreLabel(impactScore),
        tips: impactTips,
      ),
      summary: summary,
      topTips: topTips,
      wordCount: wordCount,
      estimatedWPM: wpm,
      durationSeconds: duration,
    );
  }

  String _scoreLabel(int score) {
    if (score >= 85) return 'Excelente';
    if (score >= 70) return 'Bueno';
    if (score >= 50) return 'Mejorable';
    return 'Necesita trabajo';
  }
}
