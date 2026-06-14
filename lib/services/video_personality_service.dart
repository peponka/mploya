import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VideoPersonalityService — IA Análisis de Personalidad del Video Pitch
//
// Analiza el video-pitch y genera scores de 5 soft skills:
//   1. Comunicación: claridad, ritmo, articulación
//   2. Energía: entusiasmo, tono positivo, dinamismo
//   3. Confianza: seguridad, pausas intencionales, firmeza
//   4. Liderazgo: iniciativa, toma de decisiones, visión
//   5. Empatía: escucha activa, conexión, calidez
//
// Flujo:
//   1. Se envía transcripción + metadata del video
//   2. Gemini analiza el texto y genera scores + insights
//   3. Los resultados se guardan en users.personality_scores
//   4. El frontend muestra un radar chart con los 5 ejes
// ─────────────────────────────────────────────────────────────────────────────

/// Resultado del análisis de personalidad
class PersonalityAnalysis {
  final int overallScore;
  final SoftSkillScore communication;
  final SoftSkillScore energy;
  final SoftSkillScore confidence;
  final SoftSkillScore leadership;
  final SoftSkillScore empathy;
  final String summary;
  final String personalityType; // "Líder Carismático", "Comunicador Empático", etc.
  final List<String> strengths;
  final List<String> developmentAreas;
  final String idealRole; // Rol ideal sugerido

  const PersonalityAnalysis({
    required this.overallScore,
    required this.communication,
    required this.energy,
    required this.confidence,
    required this.leadership,
    required this.empathy,
    required this.summary,
    required this.personalityType,
    required this.strengths,
    required this.developmentAreas,
    required this.idealRole,
  });

  List<SoftSkillScore> get allScores =>
      [communication, energy, confidence, leadership, empathy];

  Map<String, dynamic> toJson() => {
        'overall_score': overallScore,
        'communication': communication.score,
        'energy': energy.score,
        'confidence': confidence.score,
        'leadership': leadership.score,
        'empathy': empathy.score,
        'personality_type': personalityType,
        'ideal_role': idealRole,
        'summary': summary,
        'strengths': strengths,
        'development_areas': developmentAreas,
      };
}

/// Score individual por soft skill
class SoftSkillScore {
  final String name;
  final String emoji;
  final int score; // 0-100
  final String insight; // Frase corta de feedback

  const SoftSkillScore({
    required this.name,
    required this.emoji,
    required this.score,
    required this.insight,
  });
}

class VideoPersonalityService {
  VideoPersonalityService._();
  static final VideoPersonalityService instance = VideoPersonalityService._();

  final _supabase = Supabase.instance.client;

  // ⚠️ Gemini API key — inject via: flutter build --dart-define=GEMINI_API_KEY=...
  // NEVER put real keys as defaultValue — they get compiled into the APK binary.
  static const String _geminiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Analiza la personalidad del usuario basado en su video pitch.
  ///
  /// [userId] — ID del usuario a analizar
  /// [transcript] — Transcripción del video (opcional, se busca en DB)
  /// [headline] — Headline del perfil
  /// [skills] — Lista de skills del usuario
  Future<PersonalityAnalysis> analyzePersonality({
    required String userId,
    String? transcript,
    String headline = '',
    List<String> skills = const [],
  }) async {
    // 1. Obtener transcripción si no se provee
    String transcriptText = transcript ?? '';
    if (transcriptText.isEmpty) {
      try {
        final result = await _supabase
            .from('users')
            .select('ai_transcript_json')
            .eq('id', userId)
            .maybeSingle();
        final raw = result?['ai_transcript_json'];
        if (raw is List) {
          transcriptText = raw
              .map((s) => (s as Map<String, dynamic>)['text']?.toString() ?? '')
              .join(' ');
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching transcript: $e');
      }
    }

    // 2. Intentar Gemini API
    if (_geminiKey.isNotEmpty) {
      try {
        final geminiResult = await _analyzeWithGemini(
          transcriptText,
          headline,
          skills,
        );
        // 3. Guardar en DB
        await _saveToDb(userId, geminiResult);
        return geminiResult;
      } catch (e) {
        debugPrint('⚠️ Gemini personality analysis failed: $e');
      }
    }

    // 4. Fallback local
    final local = _analyzeLocally(transcriptText, headline, skills);
    await _saveToDb(userId, local);
    return local;
  }

  /// Obtener análisis guardado de un usuario
  Future<PersonalityAnalysis?> getSavedAnalysis(String userId) async {
    try {
      final result = await _supabase
          .from('users')
          .select('personality_scores')
          .eq('id', userId)
          .maybeSingle();

      final raw = result?['personality_scores'];
      if (raw == null || raw is! Map<String, dynamic>) return null;

      return PersonalityAnalysis(
        overallScore: (raw['overall_score'] as num?)?.toInt() ?? 0,
        communication: SoftSkillScore(
          name: 'Comunicación', emoji: '🗣️',
          score: (raw['communication'] as num?)?.toInt() ?? 0,
          insight: 'Cargado desde perfil',
        ),
        energy: SoftSkillScore(
          name: 'Energía', emoji: '⚡',
          score: (raw['energy'] as num?)?.toInt() ?? 0,
          insight: 'Cargado desde perfil',
        ),
        confidence: SoftSkillScore(
          name: 'Confianza', emoji: '💪',
          score: (raw['confidence'] as num?)?.toInt() ?? 0,
          insight: 'Cargado desde perfil',
        ),
        leadership: SoftSkillScore(
          name: 'Liderazgo', emoji: '👑',
          score: (raw['leadership'] as num?)?.toInt() ?? 0,
          insight: 'Cargado desde perfil',
        ),
        empathy: SoftSkillScore(
          name: 'Empatía', emoji: '🤝',
          score: (raw['empathy'] as num?)?.toInt() ?? 0,
          insight: 'Cargado desde perfil',
        ),
        summary: raw['summary']?.toString() ?? '',
        personalityType: raw['personality_type']?.toString() ?? 'Sin analizar',
        strengths: List<String>.from(raw['strengths'] ?? []),
        developmentAreas: List<String>.from(raw['development_areas'] ?? []),
        idealRole: raw['ideal_role']?.toString() ?? '',
      );
    } catch (e) {
      debugPrint('❌ Error loading personality: $e');
      return null;
    }
  }

  // ── Gemini Analysis ──────────────────────────────────────────────────────

  Future<PersonalityAnalysis> _analyzeWithGemini(
    String transcript,
    String headline,
    List<String> skills,
  ) async {
    final prompt = '''
Sos un experto en psicología laboral y análisis de soft skills.
Analizá la siguiente transcripción de un video-pitch laboral y evaluá 5 soft skills del 0 al 100.

TRANSCRIPCIÓN: "$transcript"
HEADLINE: "$headline"  
SKILLS: ${skills.join(', ')}

Respondé SOLO con un JSON válido (sin markdown, sin explicación) con esta estructura exacta:
{
  "overall_score": 75,
  "communication": {"score": 80, "insight": "frase corta"},
  "energy": {"score": 70, "insight": "frase corta"},
  "confidence": {"score": 75, "insight": "frase corta"},
  "leadership": {"score": 65, "insight": "frase corta"},
  "empathy": {"score": 72, "insight": "frase corta"},
  "personality_type": "Tipo en 2-3 palabras",
  "summary": "Resumen de 1-2 oraciones sobre la personalidad profesional",
  "strengths": ["fortaleza1", "fortaleza2", "fortaleza3"],
  "development_areas": ["area1", "area2"],
  "ideal_role": "Rol ideal sugerido"
}
''';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiKey',
    );

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.3,
              'maxOutputTokens': 1024,
            },
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No candidates in Gemini response');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    String rawText = parts?.first['text']?.toString() ?? '';

    // Clean markdown fences if present
    rawText = rawText
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final parsed = jsonDecode(rawText) as Map<String, dynamic>;

    return _buildFromJson(parsed);
  }

  PersonalityAnalysis _buildFromJson(Map<String, dynamic> j) {
    SoftSkillScore parseSkill(dynamic raw, String name, String emoji) {
      if (raw is Map<String, dynamic>) {
        return SoftSkillScore(
          name: name,
          emoji: emoji,
          score: ((raw['score'] as num?)?.toInt() ?? 70).clamp(0, 100),
          insight: raw['insight']?.toString() ?? 'Sin datos',
        );
      }
      return SoftSkillScore(
        name: name, emoji: emoji, score: 70, insight: 'Sin datos',
      );
    }

    return PersonalityAnalysis(
      overallScore: ((j['overall_score'] as num?)?.toInt() ?? 70).clamp(0, 100),
      communication: parseSkill(j['communication'], 'Comunicación', '🗣️'),
      energy: parseSkill(j['energy'], 'Energía', '⚡'),
      confidence: parseSkill(j['confidence'], 'Confianza', '💪'),
      leadership: parseSkill(j['leadership'], 'Liderazgo', '👑'),
      empathy: parseSkill(j['empathy'], 'Empatía', '🤝'),
      summary: j['summary']?.toString() ?? 'Análisis completado.',
      personalityType: j['personality_type']?.toString() ?? 'Profesional Versátil',
      strengths: List<String>.from(j['strengths'] ?? []),
      developmentAreas: List<String>.from(j['development_areas'] ?? []),
      idealRole: j['ideal_role']?.toString() ?? 'No especificado',
    );
  }

  // ── Local Fallback ───────────────────────────────────────────────────────

  PersonalityAnalysis _analyzeLocally(
    String transcript,
    String headline,
    List<String> skills,
  ) {
    final lower = transcript.toLowerCase();
    final words = transcript.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final wordCount = words.length;

    // Communication
    int commScore = 68;
    String commInsight = 'Buena base comunicativa';
    if (wordCount > 50) {
      commScore += 12;
      commInsight = 'Discurso articulado y completo';
    }
    if (lower.contains('soy ') || lower.contains('me llamo')) {
      commScore += 5;
    }
    final fillers = ['ehh', 'emmm', 'este', 'bueno bueno', 'o sea'];
    for (final f in fillers) {
      if (RegExp(f).allMatches(lower).length > 2) commScore -= 5;
    }

    // Energy
    int energyScore = 65;
    String energyInsight = 'Energía moderada';
    final excl = '!'.allMatches(transcript).length;
    if (excl > 1) {
      energyScore += 10;
      energyInsight = 'Entusiasmo notable en el discurso';
    }
    final positiveWords = ['pasión', 'encanta', 'amo', 'disfruto', 'motiva', 'entusiasma', 'apasiona'];
    for (final p in positiveWords) {
      if (lower.contains(p)) { energyScore += 5; break; }
    }

    // Confidence
    int confScore = 66;
    String confInsight = 'Nivel de confianza adecuado';
    final actionVerbs = ['logré', 'lideré', 'construí', 'implementé', 'diseñé', 'optimicé', 'creé'];
    int actionCount = 0;
    for (final v in actionVerbs) {
      if (lower.contains(v)) actionCount++;
    }
    if (actionCount >= 2) {
      confScore += 15;
      confInsight = 'Usa verbos de acción que transmiten seguridad';
    } else if (actionCount == 1) {
      confScore += 8;
    }
    // Hedging phrases reduce confidence
    final hedges = ['creo que', 'tal vez', 'no sé si', 'podría ser', 'quizás'];
    for (final h in hedges) {
      if (lower.contains(h)) confScore -= 5;
    }

    // Leadership
    int leadScore = 60;
    String leadInsight = 'Potencial de liderazgo presente';
    final leadWords = ['equipo', 'lideré', 'dirigí', 'coordiné', 'a cargo', 'responsable', 'estrategia', 'visión'];
    for (final l in leadWords) {
      if (lower.contains(l)) { leadScore += 8; break; }
    }
    if (lower.contains('personas') || lower.contains('equipo')) {
      leadScore += 5;
      leadInsight = 'Orientación hacia equipos y personas';
    }

    // Empathy
    int empScore = 70;
    String empInsight = 'Buena conexión interpersonal';
    final empWords = ['escuchar', 'entender', 'ayudar', 'colaborar', 'compartir', 'juntos', 'nosotros'];
    for (final e in empWords) {
      if (lower.contains(e)) { empScore += 5; break; }
    }
    if (lower.contains('?')) {
      empScore += 5;
      empInsight = 'Muestra interés y apertura al diálogo';
    }

    // Clamp all
    commScore = commScore.clamp(0, 100);
    energyScore = energyScore.clamp(0, 100);
    confScore = confScore.clamp(0, 100);
    leadScore = leadScore.clamp(0, 100);
    empScore = empScore.clamp(0, 100);

    final overall = ((commScore + energyScore + confScore + leadScore + empScore) / 5).round();

    // Personality type
    final scores = {
      'Comunicador': commScore,
      'Energético': energyScore,
      'Seguro': confScore,
      'Líder': leadScore,
      'Empático': empScore,
    };
    final topTwo = (scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(2);
    final personalityType = '${topTwo.first.key} ${topTwo.last.key}';

    // Strengths & development
    final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final strengths = sorted.take(3).map((e) => '${e.key} (${e.value}/100)').toList();
    final devAreas = sorted.reversed.take(2).map((e) => 'Mejorar ${e.key.toLowerCase()}').toList();

    // Ideal role
    String idealRole = 'Analista / Especialista';
    if (leadScore > 75) idealRole = 'Team Lead / Manager';
    if (commScore > 80 && energyScore > 75) idealRole = 'Sales / Account Manager';
    if (empScore > 80) idealRole = 'Customer Success / HR';

    return PersonalityAnalysis(
      overallScore: overall,
      communication: SoftSkillScore(name: 'Comunicación', emoji: '🗣️', score: commScore, insight: commInsight),
      energy: SoftSkillScore(name: 'Energía', emoji: '⚡', score: energyScore, insight: energyInsight),
      confidence: SoftSkillScore(name: 'Confianza', emoji: '💪', score: confScore, insight: confInsight),
      leadership: SoftSkillScore(name: 'Liderazgo', emoji: '👑', score: leadScore, insight: leadInsight),
      empathy: SoftSkillScore(name: 'Empatía', emoji: '🤝', score: empScore, insight: empInsight),
      summary: wordCount > 0
          ? 'Tu perfil de personalidad muestra fortaleza en ${topTwo.first.key.toLowerCase()} con potencial de desarrollo en ${sorted.last.key.toLowerCase()}.'
          : 'Grabá tu video-pitch para obtener un análisis completo de tu personalidad profesional.',
      personalityType: personalityType,
      strengths: strengths,
      developmentAreas: devAreas,
      idealRole: idealRole,
    );
  }

  // ── Persist ──────────────────────────────────────────────────────────────

  Future<void> _saveToDb(String userId, PersonalityAnalysis analysis) async {
    try {
      await _supabase.from('users').update({
        'personality_scores': analysis.toJson(),
      }).eq('id', userId);
      debugPrint('✅ Personality scores saved for $userId');
    } catch (e) {
      debugPrint('⚠️ Error saving personality scores: $e');
    }
  }
}
