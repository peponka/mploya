import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'claude_ai_service.dart';

/// Service para Skill Assessment Badges.
/// Genera quizzes de 5 preguntas con la IA, evalúa respuestas,
/// y guarda los badges obtenidos en Supabase.
class SkillAssessmentService {
  SkillAssessmentService._();
  static final instance = SkillAssessmentService._();

  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  // ── Catálogo de skills — dinámico desde perfil del usuario ──
  Future<List<SkillCatalogItem>> fetchCatalog() async {
    // 1. Priorizar catálogo personalizado según perfil y rol del usuario
    try {
      final userCatalog = await _buildUserCatalog();
      if (userCatalog.isNotEmpty) {
        return userCatalog;
      }
    } catch (e) {
      debugPrint('SkillAssessment: error building personalized catalog: $e');
    }

    // 2. Fallback: tabla de catálogo real si el dinámico falla o está vacío
    try {
      final rows = await _supabase
          .from('skill_assessment_catalog')
          .select()
          .eq('is_active', true)
          .order('category')
          .order('skill_name');
      if (rows.isNotEmpty) {
        return rows.map((r) => SkillCatalogItem.fromJson(r)).toList();
      }
    } catch (e) {
      debugPrint('SkillAssessment: catalog table not available: $e');
    }

    return [];
  }

  /// Construye un catálogo personalizado leyendo los skills y tags
  /// del perfil del usuario. Si está vacío, usa fallback por rol.
  Future<List<SkillCatalogItem>> _buildUserCatalog() async {
    if (_uid == null) return _fallbackByRole('candidato');

    try {
      final row = await _supabase
          .from('users')
          .select('skills, tags, account_type, headline')
          .eq('id', _uid!)
          .maybeSingle();

      if (row == null) return _fallbackByRole('candidato');

      final accountType = row['account_type']?.toString() ?? 'candidato';
      final headline = row['headline']?.toString().toLowerCase() ?? '';
      final skills = (row['skills'] as List?)?.cast<String>() ?? <String>[];
      final tags = (row['tags'] as List?)?.cast<String>() ?? <String>[];

      // Unir skills + tags, sin duplicados
      final allSkills = <String>{...skills, ...tags};

      final List<SkillCatalogItem> catalog = [];
      int idx = 0;

      final isNonTech = _isNonTechHeadline(headline);

      // Agregar skills del usuario como assessments técnicos
      for (final skill in allSkills) {
        if (skill.trim().isEmpty) continue;

        // Si el usuario es de un perfil no técnico, filtramos las habilidades de programador/desarrollador
        if (isNonTech && _isDeveloperSkill(skill)) {
          continue;
        }

        idx++;
        catalog.add(SkillCatalogItem(
          id: 'user_$idx',
          skillName: skill.trim(),
          category: _classifySkill(skill),
          description: _descriptionForSkill(skill),
          difficulty: 'intermediate',
        ));
      }

      // Si el usuario no tiene suficientes skills, agregar por rol
      if (catalog.length < 4) {
        final roleSkills = _fallbackByRole(accountType, headline: headline);
        for (final rs in roleSkills) {
          if (!catalog.any((c) => c.skillName.toLowerCase() == rs.skillName.toLowerCase())) {
            catalog.add(rs);
          }
          if (catalog.length >= 10) break;
        }
      }

      // Siempre agregar soft skills universales al final
      for (final soft in _universalSoftSkills) {
        if (!catalog.any((c) => c.skillName.toLowerCase() == soft.skillName.toLowerCase())) {
          catalog.add(soft);
        }
      }

      return catalog;
    } catch (e) {
      debugPrint('SkillAssessment: _buildUserCatalog error: $e');
      return _fallbackByRole('candidato');
    }
  }

  bool _isNonTechHeadline(String h) {
    if (h.isEmpty) return false;
    final hl = h.toLowerCase();
    // Si contiene palabras clave de tecnología, asumimos que es tech
    if (hl.contains('developer') ||
        hl.contains('programm') ||
        hl.contains('engineer') ||
        hl.contains('desarrolla') ||
        hl.contains('tech') ||
        hl.contains('sistemas') ||
        hl.contains('informática') ||
        hl.contains('programador') ||
        hl.contains('tecnología')) {
      return false;
    }
    // Si contiene palabras clave no técnicas
    return hl.contains('cfo') ||
        hl.contains('finanz') ||
        hl.contains('financ') ||
        hl.contains('contad') ||
        hl.contains('admin') ||
        hl.contains('marketing') ||
        hl.contains('market') ||
        hl.contains('publicidad') ||
        hl.contains('community') ||
        hl.contains('rrhh') ||
        hl.contains('recursos') ||
        hl.contains('talent') ||
        hl.contains('people') ||
        hl.contains('ventas') ||
        hl.contains('sales') ||
        hl.contains('comercial') ||
        hl.contains('ceo') ||
        hl.contains('coo') ||
        hl.contains('negocio') ||
        hl.contains('business') ||
        hl.contains('gerente') ||
        hl.contains('director') ||
        hl.contains('abogado') ||
        hl.contains('legal') ||
        hl.contains('psicolog');
  }

  bool _isDeveloperSkill(String skill) {
    final s = skill.toLowerCase().trim();
    final devSkills = {
      'flutter', 'react', 'javascript', 'js', 'typescript', 'ts', 'angular', 'node', 'nodejs', 'vue',
      'html', 'css', 'git', 'github', 'docker', 'kubernetes', 'aws', 'backend', 'frontend', 'fullstack',
      'c#', 'c++', 'java', 'kotlin', 'swift', 'dart', 'php', 'ruby', 'go', 'rust',
      'programación', 'programming', 'software', 'web development', 'mobile development',
      'desarrollo de software', 'desarrollo de apps'
    };
    if (devSkills.contains(s)) return true;
    if (s.contains('desarrollo web') ||
        s.contains('desarrollo mobile') ||
        s.contains('desarrollador') ||
        s.contains('programador') ||
        s.contains('react native') ||
        s.contains('frontend') ||
        s.contains('backend')) {
      return true;
    }
    return false;
  }

  /// Clasifica un skill como 'technical' o 'soft' heurísticamente.
  String _classifySkill(String skill) {
    final s = skill.toLowerCase();
    const softKeywords = ['liderazgo', 'comunicación', 'trabajo en equipo', 'negociación',
      'creatividad', 'resolución', 'empatía', 'adaptabilidad', 'gestión del tiempo',
      'leadership', 'communication', 'teamwork', 'negotiation', 'creativity',
      'problem solving', 'empathy', 'management', 'coaching', 'mentoring',
      'ventas', 'atención al cliente', 'presentaciones', 'oratoria'];
    for (final kw in softKeywords) {
      if (s.contains(kw)) return 'soft';
    }
    return 'technical';
  }

  /// Genera una descripción corta para un skill del usuario.
  String _descriptionForSkill(String skill) {
    final s = skill.toLowerCase();
    if (s.contains('excel')) return 'Fórmulas, tablas dinámicas y macros';
    if (s.contains('finanz') || s.contains('financ')) return 'Análisis financiero y reportes';
    if (s.contains('market')) return 'Estrategia y campañas digitales';
    if (s.contains('ventas') || s.contains('sales')) return 'Técnicas y pipeline de ventas';
    if (s.contains('contab') || s.contains('account')) return 'Normas contables y auditoría';
    if (s.contains('rrhh') || s.contains('recurso')) return 'Gestión del talento humano';
    if (s.contains('project') || s.contains('proyecto')) return 'Planificación y metodologías ágiles';
    if (s.contains('python')) return 'Sintaxis, estructuras de datos y libs';
    if (s.contains('react')) return 'Componentes, hooks, estado y routing';
    if (s.contains('flutter')) return 'Widgets y state management';
    if (s.contains('sql')) return 'Consultas, joins, indexes y optimización';
    if (s.contains('javascript') || s.contains('js')) return 'ES6+, closures, async/await';
    if (s.contains('design') || s.contains('diseño')) return 'Principios de diseño y UX';
    if (s.contains('data') || s.contains('datos')) return 'Análisis y visualización de datos';
    return 'Evaluá tus conocimientos en ${skill.trim()}';
  }

  /// Fallback skills por tipo de cuenta / headline.
  List<SkillCatalogItem> _fallbackByRole(String accountType, {String headline = ''}) {
    final h = headline.toLowerCase();
    // Detectar rol por headline
    if (h.contains('cfo') || h.contains('finanz') || h.contains('financ') || h.contains('contad')) {
      return _financeCatalog;
    }
    if (h.contains('marketing') || h.contains('market') || h.contains('publicidad') || h.contains('community')) {
      return _marketingCatalog;
    }
    if (h.contains('ventas') || h.contains('sales') || h.contains('comercial')) {
      return _salesCatalog;
    }
    if (h.contains('rrhh') || h.contains('recursos') || h.contains('talent') || h.contains('people')) {
      return _hrCatalog;
    }
    if (h.contains('developer') || h.contains('programm') || h.contains('engineer') || h.contains('desarrolla')) {
      return _techCatalog;
    }
    if (accountType == 'empresa' || accountType == 'headhunter') {
      return _businessCatalog;
    }
    // Default: mix general
    return _generalCatalog;
  }

  static final _financeCatalog = [
    SkillCatalogItem(id: 'f1', skillName: 'Análisis Financiero', category: 'technical', description: 'Estados financieros, ratios y proyecciones', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'f2', skillName: 'Excel Avanzado', category: 'technical', description: 'Fórmulas, tablas dinámicas y macros', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'f3', skillName: 'Contabilidad', category: 'technical', description: 'Normas contables y auditoría', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'f4', skillName: 'Presupuestos', category: 'technical', description: 'Planificación y control presupuestario', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'f5', skillName: 'Gestión de Riesgos', category: 'technical', description: 'Identificación y mitigación de riesgos', difficulty: 'advanced'),
  ];

  static final _marketingCatalog = [
    SkillCatalogItem(id: 'm1', skillName: 'Marketing Digital', category: 'technical', description: 'SEO, SEM, redes sociales y analytics', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'm2', skillName: 'Content Marketing', category: 'technical', description: 'Estrategia de contenidos y copywriting', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'm3', skillName: 'Analytics', category: 'technical', description: 'Google Analytics, métricas y KPIs', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'm4', skillName: 'Branding', category: 'soft', description: 'Identidad de marca y posicionamiento', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'm5', skillName: 'Diseño Gráfico', category: 'technical', description: 'Canva, Figma y principios de diseño', difficulty: 'beginner'),
  ];

  static final _salesCatalog = [
    SkillCatalogItem(id: 's1', skillName: 'Técnicas de Venta', category: 'technical', description: 'Prospecting, cierre y seguimiento', difficulty: 'intermediate'),
    SkillCatalogItem(id: 's2', skillName: 'CRM', category: 'technical', description: 'Salesforce, HubSpot y gestión de pipeline', difficulty: 'intermediate'),
    SkillCatalogItem(id: 's3', skillName: 'Negociación', category: 'soft', description: 'Estrategias y técnicas de negociación', difficulty: 'intermediate'),
    SkillCatalogItem(id: 's4', skillName: 'Presentaciones', category: 'soft', description: 'Pitch, storytelling y persuasión', difficulty: 'beginner'),
    SkillCatalogItem(id: 's5', skillName: 'Atención al Cliente', category: 'soft', description: 'Servicio, resolución y fidelización', difficulty: 'beginner'),
  ];

  static final _hrCatalog = [
    SkillCatalogItem(id: 'h1', skillName: 'Reclutamiento', category: 'technical', description: 'Sourcing, entrevistas y selección', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'h2', skillName: 'Gestión del Talento', category: 'technical', description: 'Desarrollo, retención y planes de carrera', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'h3', skillName: 'Legislación Laboral', category: 'technical', description: 'Normativa, contratos y compliance', difficulty: 'advanced'),
    SkillCatalogItem(id: 'h4', skillName: 'Cultura Organizacional', category: 'soft', description: 'Clima laboral y engagement', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'h5', skillName: 'Compensaciones', category: 'technical', description: 'Estructura salarial y beneficios', difficulty: 'intermediate'),
  ];

  static final _techCatalog = [
    SkillCatalogItem(id: 't1', skillName: 'JavaScript', category: 'technical', description: 'ES6+, closures, async/await y DOM', difficulty: 'intermediate'),
    SkillCatalogItem(id: 't2', skillName: 'Python', category: 'technical', description: 'Sintaxis, estructuras de datos y libs', difficulty: 'intermediate'),
    SkillCatalogItem(id: 't3', skillName: 'SQL', category: 'technical', description: 'Consultas, joins, indexes y optimización', difficulty: 'intermediate'),
    SkillCatalogItem(id: 't4', skillName: 'React', category: 'technical', description: 'Componentes, hooks, estado y routing', difficulty: 'intermediate'),
    SkillCatalogItem(id: 't5', skillName: 'Git', category: 'technical', description: 'Branching, merging y workflows', difficulty: 'beginner'),
  ];

  static final _businessCatalog = [
    SkillCatalogItem(id: 'b1', skillName: 'Gestión de Proyectos', category: 'technical', description: 'Scrum, Kanban y metodologías ágiles', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'b2', skillName: 'Estrategia de Negocio', category: 'technical', description: 'Análisis FODA, OKRs y planificación', difficulty: 'advanced'),
    SkillCatalogItem(id: 'b3', skillName: 'Excel Avanzado', category: 'technical', description: 'Fórmulas, tablas dinámicas y macros', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'b4', skillName: 'Análisis de Datos', category: 'technical', description: 'Métricas, dashboards y reportes', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'b5', skillName: 'Finanzas Corporativas', category: 'technical', description: 'P&L, flujo de caja y presupuestos', difficulty: 'intermediate'),
  ];

  static final _generalCatalog = [
    SkillCatalogItem(id: 'g1', skillName: 'Excel', category: 'technical', description: 'Fórmulas, gráficos y tablas dinámicas', difficulty: 'beginner'),
    SkillCatalogItem(id: 'g2', skillName: 'Gestión de Proyectos', category: 'technical', description: 'Planificación, seguimiento y entrega', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'g3', skillName: 'Análisis de Datos', category: 'technical', description: 'Interpretar métricas y tomar decisiones', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'g4', skillName: 'Marketing Digital', category: 'technical', description: 'Redes sociales, SEO y analytics', difficulty: 'beginner'),
    SkillCatalogItem(id: 'g5', skillName: 'Inglés Profesional', category: 'soft', description: 'Vocabulario de negocios y comunicación', difficulty: 'intermediate'),
  ];

  static final _universalSoftSkills = [
    SkillCatalogItem(id: 'u1', skillName: 'Liderazgo', category: 'soft', description: 'Gestión de equipos y mentoría', difficulty: 'intermediate'),
    SkillCatalogItem(id: 'u2', skillName: 'Comunicación', category: 'soft', description: 'Escucha activa y expresión clara', difficulty: 'beginner'),
    SkillCatalogItem(id: 'u3', skillName: 'Trabajo en Equipo', category: 'soft', description: 'Colaboración y resolución de conflictos', difficulty: 'beginner'),
  ];

  // ── Badges del usuario actual ──
  Future<List<SkillBadge>> fetchMyBadges() async {
    if (_uid == null) return [];
    try {
      final rows = await _supabase
          .rpc('get_user_badges', params: {'p_user_id': _uid});
      if (rows is List) {
        return rows.map((r) => SkillBadge.fromJson(r as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('SkillAssessment: Error fetching badges: $e');
      return [];
    }
  }

  // ── Badges de otro usuario (público) ──
  Future<List<SkillBadge>> fetchUserBadges(String userId) async {
    try {
      final rows = await _supabase
          .rpc('get_user_badges', params: {'p_user_id': userId});
      if (rows is List) {
        return rows.map((r) => SkillBadge.fromJson(r as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('SkillAssessment: Error fetching user badges: $e');
      return [];
    }
  }

  // ── Generar Quiz con IA ──
  Future<SkillQuiz> generateQuiz(String skillName, {String difficulty = 'intermediate'}) async {
    try {
      final result = await ClaudeAIService.instance.generateSkillQuiz(
        skillName: skillName,
        difficulty: difficulty,
      );
      return result;
    } catch (e) {
      debugPrint('SkillAssessment: Error generating quiz, using fallback: $e');
      return _fallbackQuiz(skillName);
    }
  }

  // ── Evaluar respuestas y guardar resultado ──
  Future<SkillAssessmentResult> submitAssessment({
    required String skillName,
    required String skillCategory,
    required List<int> answers,
    required List<int> correctAnswers,
    required int timeTakenSeconds,
  }) async {
    int correct = 0;
    for (int i = 0; i < answers.length && i < correctAnswers.length; i++) {
      if (answers[i] == correctAnswers[i]) correct++;
    }

    final score = ((correct / correctAnswers.length) * 100).round();
    final passed = score >= 60;
    String? badgeLevel;
    if (score >= 90) {
      badgeLevel = 'gold';
    } else if (score >= 80) {
      badgeLevel = 'silver';
    } else if (score >= 60) {
      badgeLevel = 'bronze';
    }

    final result = SkillAssessmentResult(
      skillName: skillName,
      score: score,
      passed: passed,
      badgeLevel: badgeLevel,
      questionsTotal: correctAnswers.length,
      questionsCorrect: correct,
      timeTakenSeconds: timeTakenSeconds,
    );

    // Guardar en DB
    if (_uid != null) {
      try {
        await _supabase.from('skill_assessments').insert({
          'user_id': _uid,
          'skill_name': skillName,
          'skill_category': skillCategory,
          'score': score,
          'passed': passed,
          'questions_total': correctAnswers.length,
          'questions_correct': correct,
          'badge_level': badgeLevel,
          'time_taken_seconds': timeTakenSeconds,
          'expires_at': DateTime.now().add(const Duration(days: 180)).toUtc().toIso8601String(),
        });
      } catch (e) {
        debugPrint('SkillAssessment: Error saving result: $e');
      }
    }

    return result;
  }

  // ── Check: can retake? (24h cooldown) ──
  Future<bool> canRetake(String skillName) async {
    if (_uid == null) return true;
    try {
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final rows = await _supabase
          .from('skill_assessments')
          .select('id')
          .eq('user_id', _uid!)
          .eq('skill_name', skillName)
          .eq('assessment_date', today)
          .limit(1);
      return (rows as List).isEmpty;
    } catch (e) {
      return true;
    }
  }

  // ── Fallback quiz cuando IA no disponible ──
  SkillQuiz _fallbackQuiz(String skillName) {
    return SkillQuiz(
      skillName: skillName,
      questions: [
        QuizQuestion(
          question: '¿Cuál de estas es una buena práctica en $skillName?',
          options: ['Documentar el código', 'Ignorar los tests', 'No usar control de versiones', 'Copiar código sin entender'],
          correctIndex: 0,
        ),
        QuizQuestion(
          question: '¿Qué herramienta es más común en proyectos de $skillName?',
          options: ['Excel', 'Git', 'Paint', 'Notepad'],
          correctIndex: 1,
        ),
        QuizQuestion(
          question: '¿Qué significa DRY en programación?',
          options: ['Do Repeat Yourself', 'Don\'t Repeat Yourself', 'Do Return Yields', 'Don\'t Run Yolo'],
          correctIndex: 1,
        ),
        QuizQuestion(
          question: '¿Cuál es un principio clave de diseño de software?',
          options: ['Complejidad máxima', 'Acoplamiento alto', 'Cohesión alta', 'Código duplicado'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: '¿Qué es un code review?',
          options: ['Borrar código viejo', 'Revisar código entre peers', 'Escribir más rápido', 'Compilar el proyecto'],
          correctIndex: 1,
        ),
      ],
    );
  }


}

// ═══════════════════════════════════════════════════════════════════════════════
// Data Models
// ═══════════════════════════════════════════════════════════════════════════════

class SkillCatalogItem {
  final String id;
  final String skillName;
  final String category;
  final String? description;
  final String? iconName;
  final String difficulty;

  const SkillCatalogItem({
    required this.id,
    required this.skillName,
    required this.category,
    this.description,
    this.iconName,
    this.difficulty = 'intermediate',
  });

  factory SkillCatalogItem.fromJson(Map<String, dynamic> json) {
    return SkillCatalogItem(
      id: json['id']?.toString() ?? '',
      skillName: json['skill_name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'technical',
      description: json['description']?.toString(),
      iconName: json['icon_name']?.toString(),
      difficulty: json['difficulty']?.toString() ?? 'intermediate',
    );
  }
}

class SkillBadge {
  final String skillName;
  final String badgeLevel; // gold, silver, bronze
  final int score;
  final String category;
  final DateTime earnedAt;

  const SkillBadge({
    required this.skillName,
    required this.badgeLevel,
    required this.score,
    required this.category,
    required this.earnedAt,
  });

  factory SkillBadge.fromJson(Map<String, dynamic> json) {
    return SkillBadge(
      skillName: json['skill_name']?.toString() ?? '',
      badgeLevel: json['badge_level']?.toString() ?? 'bronze',
      score: (json['score'] as num?)?.toInt() ?? 0,
      category: json['skill_category']?.toString() ?? 'technical',
      earnedAt: DateTime.tryParse(json['earned_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class SkillAssessmentResult {
  final String skillName;
  final int score;
  final bool passed;
  final String? badgeLevel;
  final int questionsTotal;
  final int questionsCorrect;
  final int timeTakenSeconds;

  const SkillAssessmentResult({
    required this.skillName,
    required this.score,
    required this.passed,
    this.badgeLevel,
    required this.questionsTotal,
    required this.questionsCorrect,
    required this.timeTakenSeconds,
  });
}
