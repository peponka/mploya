import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SoftSkillMatchService — Smart Matching por Soft Skills
//
// Extiende el motor de IA existente para incluir soft skills en el cálculo
// de match entre candidatos y vacantes/empresas.
//
// Soft Skills detectadas:
//   • Del video-pitch: tono, confianza, claridad, energía
//   • Del perfil: tags de personalidad (liderazgo, teamwork, etc.)
//   • De la actividad: consistencia, engagement, respuesta
//
// El resultado se combina con el match por hard skills (embeddings)
// para generar un match_percentage más preciso y humano.
// ─────────────────────────────────────────────────────────────────────────────

/// Categorías de soft skills detectadas
class SoftSkillProfile {
  final int leadership;       // 0-100: Liderazgo
  final int communication;    // 0-100: Comunicación
  final int teamwork;         // 0-100: Trabajo en equipo
  final int adaptability;     // 0-100: Adaptabilidad
  final int problemSolving;   // 0-100: Resolución de problemas
  final int creativity;       // 0-100: Creatividad
  final int emotionalIq;      // 0-100: Inteligencia emocional
  final int proactivity;      // 0-100: Proactividad

  const SoftSkillProfile({
    this.leadership = 50,
    this.communication = 50,
    this.teamwork = 50,
    this.adaptability = 50,
    this.problemSolving = 50,
    this.creativity = 50,
    this.emotionalIq = 50,
    this.proactivity = 50,
  });

  int get overallScore => ((leadership + communication + teamwork +
      adaptability + problemSolving + creativity +
      emotionalIq + proactivity) / 8).round();

  Map<String, int> toMap() => {
    'leadership': leadership,
    'communication': communication,
    'teamwork': teamwork,
    'adaptability': adaptability,
    'problem_solving': problemSolving,
    'creativity': creativity,
    'emotional_iq': emotionalIq,
    'proactivity': proactivity,
  };

  factory SoftSkillProfile.fromJson(Map<String, dynamic> json) {
    return SoftSkillProfile(
      leadership: (json['leadership'] as num?)?.toInt() ?? 50,
      communication: (json['communication'] as num?)?.toInt() ?? 50,
      teamwork: (json['teamwork'] as num?)?.toInt() ?? 50,
      adaptability: (json['adaptability'] as num?)?.toInt() ?? 50,
      problemSolving: (json['problem_solving'] as num?)?.toInt() ?? 50,
      creativity: (json['creativity'] as num?)?.toInt() ?? 50,
      emotionalIq: (json['emotional_iq'] as num?)?.toInt() ?? 50,
      proactivity: (json['proactivity'] as num?)?.toInt() ?? 50,
    );
  }

  /// Genera un perfil a partir de tags y datos del usuario.
  factory SoftSkillProfile.fromUserData({
    required List<String> tags,
    required List<String> skills,
    required String? transcript,
    required int? wpm,
  }) {
    int leadership = 50;
    int communication = 50;
    int teamwork = 50;
    int adaptability = 50;
    int problemSolving = 50;
    int creativity = 50;
    int emotionalIq = 50;
    int proactivity = 50;

    final allKeywords = [...tags, ...skills].map((s) => s.toLowerCase()).toList();

    // ── Map keywords to soft skills ──
    final leadershipKeywords = ['liderazgo', 'leadership', 'director', 'manager', 'gestión', 'ceo', 'cto', 'vp', 'head'];
    final communicationKeywords = ['comunicación', 'communication', 'oratoria', 'presentación', 'negociación', 'ventas'];
    final teamworkKeywords = ['equipo', 'team', 'colaboración', 'agile', 'scrum', 'stakeholders'];
    final adaptabilityKeywords = ['adaptable', 'flexible', 'startup', 'crecimiento', 'growth', 'multitask'];
    final problemSolvingKeywords = ['analytics', 'data', 'solving', 'estrategia', 'strategy', 'optimización'];
    final creativityKeywords = ['design', 'diseño', 'innovación', 'creative', 'ux', 'branding', 'producto'];
    final emotionalIqKeywords = ['empatía', 'cultura', 'people', 'hr', 'coaching', 'mentoring'];
    final proactivityKeywords = ['emprendimiento', 'entrepreneur', 'founder', 'initiative', 'startup'];

    for (final kw in allKeywords) {
      if (leadershipKeywords.any((l) => kw.contains(l))) leadership += 12;
      if (communicationKeywords.any((l) => kw.contains(l))) communication += 12;
      if (teamworkKeywords.any((l) => kw.contains(l))) teamwork += 12;
      if (adaptabilityKeywords.any((l) => kw.contains(l))) adaptability += 12;
      if (problemSolvingKeywords.any((l) => kw.contains(l))) problemSolving += 12;
      if (creativityKeywords.any((l) => kw.contains(l))) creativity += 12;
      if (emotionalIqKeywords.any((l) => kw.contains(l))) emotionalIq += 12;
      if (proactivityKeywords.any((l) => kw.contains(l))) proactivity += 12;
    }

    // ── Analyze transcript for communication signals ──
    if (transcript != null && transcript.isNotEmpty) {
      final lower = transcript.toLowerCase();
      // Confidence from word count
      final wordCount = transcript.split(RegExp(r'\s+')).length;
      if (wordCount > 50) communication += 10;
      if (wordCount > 100) proactivity += 8;

      // WPM analysis
      if (wpm != null) {
        if (wpm >= 120 && wpm <= 160) communication += 15;
        if (wpm > 160) adaptability += 8; // Fast talker = adaptive
      }

      // Action verbs = leadership
      const actionVerbs = ['logré', 'lideré', 'construí', 'implementé', 'diseñé', 'crecí', 'optimicé'];
      final actionCount = actionVerbs.where((v) => lower.contains(v)).length;
      if (actionCount >= 2) leadership += 15;
      if (actionCount >= 4) proactivity += 10;

      // Team mentions
      if (lower.contains('equipo') || lower.contains('team')) teamwork += 12;
      if (lower.contains('cultura') || lower.contains('valores')) emotionalIq += 10;
    }

    return SoftSkillProfile(
      leadership: leadership.clamp(0, 100),
      communication: communication.clamp(0, 100),
      teamwork: teamwork.clamp(0, 100),
      adaptability: adaptability.clamp(0, 100),
      problemSolving: problemSolving.clamp(0, 100),
      creativity: creativity.clamp(0, 100),
      emotionalIq: emotionalIq.clamp(0, 100),
      proactivity: proactivity.clamp(0, 100),
    );
  }
}

class SoftSkillMatchService {
  SoftSkillMatchService._();
  static final SoftSkillMatchService instance = SoftSkillMatchService._();

  final _supabase = Supabase.instance.client;

  // Cache
  SoftSkillProfile? _cachedProfile;
  DateTime? _cacheTime;

  /// Genera y guarda el perfil de soft skills del usuario actual.
  Future<SoftSkillProfile> generateProfile({bool forceRefresh = false}) async {
    // Return cached if available and not forcing refresh
    if (!forceRefresh && _cachedProfile != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < const Duration(minutes: 10)) {
      return _cachedProfile!;
    }

    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return const SoftSkillProfile();

    try {
      final userData = await _supabase
          .from('users')
          .select('tags, skills, ai_transcript')
          .eq('id', uid)
          .maybeSingle();

      if (userData == null) return const SoftSkillProfile();

      final tags = (userData['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final skills = (userData['skills'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final transcript = userData['ai_transcript']?.toString();

      final profile = SoftSkillProfile.fromUserData(
        tags: tags,
        skills: skills,
        transcript: transcript,
        wpm: null,
      );

      // Save to DB
      await _supabase.from('users').update({
        'soft_skills': profile.toMap(),
      }).eq('id', uid);

      _cachedProfile = profile;
      _cacheTime = DateTime.now();

      return profile;
    } catch (e) {
      debugPrint('Error generating soft skill profile: $e');
      return _cachedProfile ?? const SoftSkillProfile();
    }
  }

  /// Calcula el match score combinando hard skills + soft skills.
  ///
  /// Formula:
  ///   finalScore = hardSkillMatch * 0.6 + softSkillMatch * 0.4
  ///
  /// Donde softSkillMatch es la similitud entre los perfiles
  /// de soft skills de ambos usuarios (coseno simplificado).
  int calculateCombinedMatch({
    required int hardSkillScore,
    required SoftSkillProfile candidate,
    required SoftSkillProfile jobRequirements,
  }) {
    // Similitud por categoría ponderada
    int softScore = 0;
    int count = 0;

    final candidateMap = candidate.toMap();
    final requirementsMap = jobRequirements.toMap();

    for (final key in requirementsMap.keys) {
      final required = requirementsMap[key] ?? 50;
      final has = candidateMap[key] ?? 50;

      // Solo penalizar si la diferencia es negativa significativa
      if (required > 60) {
        // This skill matters for the job
        final diff = has - required;
        if (diff >= 0) {
          softScore += 100; // Meets or exceeds
        } else {
          softScore += (100 + diff * 2).clamp(0, 100); // Penalize gap
        }
        count++;
      }
    }

    final softSkillMatch = count > 0 ? (softScore / count).round() : 70;

    // Combine: 60% hard skills, 40% soft skills
    return ((hardSkillScore * 0.6) + (softSkillMatch * 0.4)).round().clamp(0, 100);
  }

  /// Obtiene el perfil de soft skills de un usuario.
  Future<SoftSkillProfile> getProfileFor(String userId) async {
    try {
      final res = await _supabase
          .from('users')
          .select('soft_skills')
          .eq('id', userId)
          .maybeSingle();

      if (res != null && res['soft_skills'] is Map) {
        return SoftSkillProfile.fromJson(Map<String, dynamic>.from(res['soft_skills']));
      }
      return const SoftSkillProfile();
    } catch (e) {
      return const SoftSkillProfile();
    }
  }
}
