import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/skill_assessment_service.dart';

/// AI Resume Builder — genera un CV profesional con IA desde los datos del perfil.
/// Si el perfil está incompleto, la IA sugiere contenido profesional.
class ResumeBuilderScreen extends StatefulWidget {
  const ResumeBuilderScreen({super.key});
  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> with TickerProviderStateMixin {
  NexUser? _profile;
  List<SkillBadge> _badges = [];
  bool _loading = true;
  bool _generating = false;
  String? _aiSummary;
  String? _aiStrengths;
  int _variantIndex = 0;
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() { _pulseCtrl.dispose(); _fadeCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await Supabase.instance.client.from('users').select().eq('id', uid).maybeSingle();
      if (row != null) {
        final profile = NexUser.fromJson(row);
        final badges = await SkillAssessmentService.instance.fetchMyBadges();
        if (mounted) setState(() { _profile = profile; _badges = badges; _loading = false; });
        _fadeCtrl.forward();
        // Auto-generate AI summary
        _generateAISummary(profile);
      }
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _generateAISummary(NexUser profile) async {
    setState(() {
      _variantIndex++; // Increment on each call to rotate variants properly
      _generating = true;
    });

    const geminiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

    // Build context from profile
    final skillsList = profile.skills.isNotEmpty ? profile.skills.join(', ') : 'No especificadas';
    final expList = profile.experience.isNotEmpty
        ? profile.experience.map((e) => '${e.role} en ${e.company} (${e.duration})').join('; ')
        : 'Sin experiencia registrada';
    final eduList = profile.education.isNotEmpty
        ? profile.education.map((e) => '${e.degree} en ${e.school}').join('; ')
        : 'Sin educación registrada';

    if (geminiKey.isEmpty) {
      // Fallback sin API key — generar contenido local inteligente
      if (mounted) setState(() {
        _aiSummary = _localSummary(profile, expList);
        _aiStrengths = _localStrengths(profile);
        _generating = false;
      });
      return;
    }

    final prompt = '''
Eres un experto en CV profesionales. Genera un resumen ejecutivo y fortalezas para este perfil:

Nombre: ${profile.name}
Título: ${profile.headline}
Skills: $skillsList
Experiencia: $expList
Educación: $eduList
Ubicación: ${profile.location ?? 'No especificada'}

Responde SOLO en JSON válido:
{
  "resumen": "Resumen profesional de 3-4 oraciones en español, profesional y convincente",
  "fortalezas": "3-4 fortalezas clave separadas por punto y coma"
}
''';

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 400, 'responseMimeType': 'application/json'},
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = ((data['candidates'] as List?)?.first['content']['parts'] as List?)?.first['text'] as String? ?? '{}';
        final parsed = jsonDecode(text) as Map<String, dynamic>;
        if (mounted) setState(() {
          _aiSummary = parsed['resumen'] as String? ?? _localSummary(profile, expList);
          _aiStrengths = parsed['fortalezas'] as String? ?? _localStrengths(profile);
          _generating = false;
        });
        return;
      }
    } catch (e) { debugPrint('AI Resume generation error: $e'); }

    // Fallback — rotate variant
    if (mounted) setState(() {
      _aiSummary = _localSummary(profile, expList);
      _aiStrengths = _localStrengths(profile);
      _generating = false;
    });
  }

  String _localSummary(NexUser p, String exp) {
    final role = p.headline.isNotEmpty ? p.headline : 'Profesional';
    final skills = p.skills.take(3).join(', ');
    final v = _variantIndex % 6; // 6 distinct variants for high diversity!
    final hasExp = p.experience.isNotEmpty;
    final company = hasExp ? p.experience.first.company : '';
    final sk = skills.isNotEmpty ? skills : 'su área de especialidad';
    final rLower = role.toLowerCase();

    // Check if the user is in Finance/CFO
    final isFinance = rLower.contains('cfo') || rLower.contains('finan') || rLower.contains('conta');
    // Check if the user is in Tech/Dev
    final isTech = rLower.contains('dev') || rLower.contains('engineer') || rLower.contains('program') || rLower.contains('sistem');

    if (isFinance) {
      if (v == 0) {
        return hasExp
            ? 'Líder financiero con sólida trayectoria en $company. Especialista en dirección estratégica, optimización de EBITDA, control presupuestario y gestión de proyectos apoyado en $sk.'
            : '$role altamente analítico enfocado en la maximización del valor corporativo, planificación financiera y gestión estratégica en $sk.';
      } else if (v == 1) {
        return hasExp
            ? 'CFO estratégico con track record comprobado liderando áreas de finanzas en $company. Experto en planificación financiera y fiscal, optimización de flujos de caja y $sk.'
            : 'Profesional en finanzas corporativas con sólida formación en control de gestión y toma de decisiones estratégicas basadas en datos de $sk.';
      } else if (v == 2) {
        return hasExp
            ? 'Ejecutivo de finanzas con experiencia en $company. Habilidades sobresalientes en auditoría, modelado financiero y mitigación de riesgos con dominio de $sk.'
            : 'Perfil financiero enfocado en eficiencia operativa, control de costos y diseño de proyecciones financieras complejas para proyectos de $sk.';
      } else if (v == 3) {
        return hasExp
            ? 'Director financiero orientado a resultados con experiencia en $company. Especialista en la implementación de ERPs, análisis de rentabilidad y $sk.'
            : '$role proactivo con gran visión comercial y capacidad de estructuración de deuda, fusiones, adquisiciones y procesos en $sk.';
      } else if (v == 4) {
        return hasExp
            ? 'Especialista en finanzas de alto impacto en $company. Aporta visión analítica en la optimización de procesos internos y control financiero robusto apoyado en $sk.'
            : 'Consultor financiero y CFO con enfoque en planeamiento a largo plazo, control presupuestario y reingeniería de procesos para $sk.';
      } else {
        return hasExp
            ? 'Líder en tesorería y finanzas corporativas con paso destacado por $company. Reconocido por su capacidad de automatización de reportes y dominio en $sk.'
            : '$role dinámico con fuerte orientación al control interno y cumplimiento corporativo, especializado en herramientas y metodologías de $sk.';
      }
    } else if (isTech) {
      if (v == 0) {
        return hasExp
            ? 'Desarrollador de software con experiencia en $company. Especializado en arquitectura de sistemas escalables, código limpio y desarrollo ágil enfocado en $sk.'
            : 'Ingeniero de software con pasión por la innovación tecnológica. Perfil proactivo y analítico con fuerte dominio técnico en $sk.';
      } else if (v == 1) {
        return hasExp
            ? 'Ingeniero de sistemas enfocado en desarrollo fullstack en $company. Experiencia en el ciclo completo de desarrollo y optimización de base de datos con $sk.'
            : 'Desarrollador enfocado en buenas prácticas de programación, integraciones fluidas y creación de productos digitales interactivos usando $sk.';
      } else if (v == 2) {
        return hasExp
            ? 'Developer proactivo con track record en $company. Experto en resolución de problemas complejos, debugging rápido y adopción de tecnologías en $sk.'
            : 'Apasionado de la programación con enfoque en escalabilidad, metodologías DevOps y estructuración de microservicios robustos basados en $sk.';
      } else if (v == 3) {
        return hasExp
            ? 'Desarrollador con experiencia comprobada en desarrollo ágil dentro de $company. Fuerte orientación al trabajo colaborativo e innovación en $sk.'
            : 'Ingeniero enfocado en la automatización de procesos, API RESTful y optimización de rendimiento de aplicaciones web/móviles usando $sk.';
      } else if (v == 4) {
        return hasExp
            ? 'Tech Lead y arquitecto de software con paso por $company. Líder técnico enfocado en guiar equipos a la excelencia utilizando herramientas de $sk.'
            : 'Desarrollador dinámico con gran capacidad de autoaprendizaje, adaptación a nuevos stacks tecnológicos y especialización en $sk.';
      } else {
        return hasExp
            ? 'Ingeniero de software sénior con experiencia en $company. Especialista en integraciones seguras, sistemas de alta disponibilidad y manejo ágil de $sk.'
            : 'Profesional técnico orientado a la creación de interfaces de alta calidad, robustez de backend y soluciones modernas apalancadas en $sk.';
      }
    } else {
      // General fallbacks
      if (v == 0) {
        return hasExp
            ? '$role con trayectoria sólida en $company. Dominio en $sk, con enfoque orientado a resultados y crecimiento continuo.'
            : '$role con fuerte orientación a $sk. Perfil proactivo con capacidad de adaptación y aprendizaje rápido.';
      } else if (v == 1) {
        return hasExp
            ? 'Profesional experimentado como $role, con track record comprobado en $company. Competencias clave en $sk, combinando visión estratégica con ejecución práctica.'
            : '$role comprometido con la excelencia en $sk. Enfoque analítico y colaborativo, orientado a la mejora continua y la innovación.';
      } else if (v == 2) {
        return hasExp
            ? '$role de alto rendimiento con experiencia en $company. Experto en $sk, reconocido por su capacidad de liderazgo y resolución de problemas complejos.'
            : '$role dinámico especializado en $sk. Combina pensamiento crítico con habilidades interpersonales para generar impacto real en cada proyecto.';
      } else if (v == 3) {
        return hasExp
            ? '$role con gran adaptabilidad y foco en resultados en $company. Destaca en la gestión y optimización de tareas clave mediante $sk.'
            : '$role enfocado en la mejora de procesos, comunicación de alto nivel y resolución de desafíos del área con el uso técnico de $sk.';
      } else if (v == 4) {
        return hasExp
            ? 'Profesional en constante evolución con experiencia en $company. Combina habilidades interpersonales sobresalientes con conocimientos avanzados en $sk.'
            : '$role versátil comprometido con la innovación constante y la consecución de objetivos mediante la especialización de $sk.';
      } else {
        return hasExp
            ? 'Especialista en su campo con trayectoria enriquecedora en $company. Aporta visión integradora y capacidad técnica avanzada enfocada en $sk.'
            : 'Perfil profesional proactivo, enfocado en el crecimiento mutuo del equipo y el éxito de cada iniciativa a través de herramientas como $sk.';
      }
    }
  }

  String _localStrengths(NexUser p) {
    final strengths = <String>[];
    
    // Add real profile based strengths
    if (p.experience.isNotEmpty) {
      strengths.add('${p.experience.length} posiciones de experiencia profesional');
    }
    if (p.skills.isNotEmpty) {
      strengths.add('Dominio en ${p.skills.take(3).join(", ")}');
    }
    if (p.education.isNotEmpty) {
      strengths.add('Formación en ${p.education.first.degree}');
    }
    if (_badges.isNotEmpty) {
      strengths.add('${_badges.length} certificaciones verificadas');
    }

    // Role-specific strengths pool based on variant rotation
    final headline = p.headline.toLowerCase();
    final isFinance = headline.contains('cfo') || headline.contains('finan') || headline.contains('conta');
    final isTech = headline.contains('dev') || headline.contains('engineer') || headline.contains('program') || headline.contains('sistem');
    
    final v = _variantIndex % 3;
    
    if (isFinance) {
      if (v == 0) {
        strengths.addAll(['Análisis y Modelado Financiero', 'Planificación Estratégica & Fiscal', 'Gestión de Presupuestos y Costos']);
      } else if (v == 1) {
        strengths.addAll(['Optimización de EBITDA y Flujo de Caja', 'Liderazgo de Equipos de Tesorería', 'Mitigación de Riesgos Corporativos']);
      } else {
        strengths.addAll(['Estructuración Financiera de Proyectos', 'Implementación de Sistemas ERP y Reporting', 'Toma de Decisiones basada en KPIs']);
      }
    } else if (isTech) {
      if (v == 0) {
        strengths.addAll(['Arquitectura de Software Escalable', 'Clean Code y Principios SOLID', 'Metodologías Ágiles (Scrum/Kanban)']);
      } else if (v == 1) {
        strengths.addAll(['Desarrollo Full-Stack Orientado a UI/UX', 'Optimización de Consultas SQL y APIs', 'Control de Versiones y CI/CD']);
      } else {
        strengths.addAll(['Resolución de Problemas Complejos', 'Integración de Microservicios', 'Autoaprendizaje e Innovación Tecnológica']);
      }
    } else {
      if (v == 0) {
        strengths.addAll(['Pensamiento Crítico y Resolución de Problemas', 'Actitud Proactiva y Liderazgo', 'Capacidad de Adaptación al Cambio']);
      } else if (v == 1) {
        strengths.addAll(['Comunicación Efectiva y Storytelling', 'Trabajo en Equipo y Colaboración', 'Orientación al Logro y Resultados']);
      } else {
        strengths.addAll(['Gestión Eficiente del Tiempo', 'Iniciativa y Autonomía de Trabajo', 'Habilidades de Negociación y Negocios']);
      }
    }
    
    return strengths.take(4).join('; '); // Take top 4 strengths for display
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('AI Resume'),
        previousPageTitle: 'Perfil',
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.share, size: 20),
          onPressed: () { HapticFeedback.mediumImpact(); _copyResume(); },
        ),
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : _profile == null
              ? _emptyState()
              : FadeTransition(opacity: _fadeAnim, child: SafeArea(child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _headerCard(),
                    const SizedBox(height: 16),
                    _aiSummaryCard(),
                    if (_profile!.experience.isNotEmpty) ...[const SizedBox(height: 16), _experienceCard()],
                    if (_profile!.education.isNotEmpty) ...[const SizedBox(height: 16), _educationCard()],
                    if (_profile!.skills.isNotEmpty) ...[const SizedBox(height: 16), _skillsCard()],
                    if (_badges.isNotEmpty) ...[const SizedBox(height: 16), _badgesCard()],
                    if (_aiStrengths != null) ...[const SizedBox(height: 16), _strengthsCard()],
                    const SizedBox(height: 20),
                    _actionButtons(),
                    const SizedBox(height: 100),
                  ],
                ))),
    );
  }

  Widget _emptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 80, height: 80, decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: const Icon(CupertinoIcons.doc_text, size: 36, color: MployaTheme.brandAccent)),
    const SizedBox(height: 16),
    const Text('No se pudo cargar tu perfil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
    const SizedBox(height: 8),
    const Text('Completá tu perfil para generar tu CV con IA', style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
  ]));

  Widget _headerCard() {
    final p = _profile!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF1A1A2E).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(p.initials, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)))),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(p.headline, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7), fontStyle: FontStyle.italic)),
          if (p.location != null) ...[const SizedBox(height: 2),
            Row(children: [Icon(CupertinoIcons.location_solid, size: 11, color: Colors.white.withValues(alpha: 0.5)), const SizedBox(width: 4),
              Text(p.location!, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)))])],
        ])),
      ]),
    );
  }

  Widget _aiSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF5F3DC4), Color(0xFFAE3EC9)]), borderRadius: BorderRadius.circular(8)),
            child: const Icon(CupertinoIcons.sparkles, size: 14, color: Colors.white)),
          const SizedBox(width: 10),
          const Text('Resumen Profesional', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(
            color: const Color(0xFF5F3DC4).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: const Text('IA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF5F3DC4)))),
        ]),
        const SizedBox(height: 14),
        if (_generating)
          _shimmerLines()
        else
          Text(_aiSummary ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF3A3A3C), height: 1.6)),
        if (!_generating && _aiSummary != null) ...[const SizedBox(height: 12),
          GestureDetector(onTap: () { _generateAISummary(_profile!); },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(CupertinoIcons.arrow_2_circlepath, size: 13, color: MployaTheme.brandAccent.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text('Regenerar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MployaTheme.brandAccent.withValues(alpha: 0.7))),
            ]))],
      ]),
    );
  }

  Widget _shimmerLines() {
    return AnimatedBuilder(animation: _pulseCtrl, builder: (_, __) {
      final opacity = 0.3 + (_pulseCtrl.value * 0.4);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 12, width: double.infinity, decoration: BoxDecoration(color: Color.fromRGBO(142, 142, 147, opacity), borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 8),
        Container(height: 12, width: MediaQuery.of(context).size.width * 0.8, decoration: BoxDecoration(color: Color.fromRGBO(142, 142, 147, opacity), borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 8),
        Container(height: 12, width: MediaQuery.of(context).size.width * 0.6, decoration: BoxDecoration(color: Color.fromRGBO(142, 142, 147, opacity), borderRadius: BorderRadius.circular(6))),
      ]);
    });
  }

  Widget _sectionCard(String title, IconData icon, Color iconColor, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: iconColor)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
        ]),
        const SizedBox(height: 14),
        ...children,
      ]),
    );
  }

  Widget _experienceCard() => _sectionCard('Experiencia', CupertinoIcons.briefcase_fill, const Color(0xFF2563EB),
    _profile!.experience.map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(
        color: MployaTheme.brandAccent, shape: BoxShape.circle)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e.role, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
        Text('${e.company} · ${e.duration}${e.isCurrent ? ' — Actual' : ''}', style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
        if (e.description != null) Padding(padding: const EdgeInsets.only(top: 4),
          child: Text(e.description!, style: const TextStyle(fontSize: 13, color: Color(0xFF6C6C70), height: 1.4))),
      ])),
    ]))).toList());

  Widget _educationCard() => _sectionCard('Educación', CupertinoIcons.book_fill, const Color(0xFF059669),
    _profile!.education.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(
        color: Color(0xFF059669), shape: BoxShape.circle)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e.degree, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
        Text('${e.school} · ${e.years}', style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
      ])),
    ]))).toList());

  Widget _skillsCard() => _sectionCard('Habilidades', CupertinoIcons.star_fill, const Color(0xFFD97706), [
    Wrap(spacing: 8, runSpacing: 8, children: _profile!.skills.map((s) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.2))),
      child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E))))).toList()),
  ]);

  Widget _badgesCard() => _sectionCard('Certificaciones Verificadas', CupertinoIcons.checkmark_seal_fill, const Color(0xFFFFD700),
    _badges.map((b) {
      final c = b.badgeLevel == 'gold' ? const Color(0xFFFFD700) : b.badgeLevel == 'silver' ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32);
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
        Icon(CupertinoIcons.checkmark_seal_fill, color: c, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(b.skillName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text('${b.score}% ${b.badgeLevel.toUpperCase()}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c))),
      ]));
    }).toList());

  Widget _strengthsCard() {
    final items = _aiStrengths!.split(';').where((s) => s.trim().isNotEmpty).toList();
    return _sectionCard('Fortalezas Clave', CupertinoIcons.bolt_fill, const Color(0xFF8B5CF6),
      items.map((s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(CupertinoIcons.checkmark_alt, size: 14, color: Color(0xFF8B5CF6)),
        const SizedBox(width: 10),
        Expanded(child: Text(s.trim(), style: const TextStyle(fontSize: 14, color: Color(0xFF3A3A3C), height: 1.4))),
      ]))).toList());
  }

  Widget _actionButtons() => Column(children: [
    SizedBox(width: double.infinity, child: CupertinoButton(color: MployaTheme.brandAccent, borderRadius: BorderRadius.circular(14),
      onPressed: _copyResume,
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(CupertinoIcons.doc_on_clipboard, color: Colors.white, size: 18), SizedBox(width: 8),
        Text('Copiar CV completo', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
      ]))),
    const SizedBox(height: 10),
    SizedBox(width: double.infinity, child: CupertinoButton(
      color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(14),
      onPressed: () { HapticFeedback.lightImpact(); _generateAISummary(_profile!); },
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(CupertinoIcons.sparkles, color: Color(0xFF5F3DC4), size: 18), SizedBox(width: 8),
        Text('Regenerar con IA', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF5F3DC4))),
      ]))),
  ]);

  void _copyResume() {
    if (_profile == null) return;
    final p = _profile!;
    final buf = StringBuffer();
    buf.writeln('═══ ${p.name} ═══');
    buf.writeln(p.headline);
    if (p.location != null) buf.writeln('📍 ${p.location}');
    buf.writeln();
    if (_aiSummary != null) { buf.writeln('── RESUMEN PROFESIONAL ──'); buf.writeln(_aiSummary); buf.writeln(); }
    if (p.experience.isNotEmpty) { buf.writeln('── EXPERIENCIA ──');
      for (final e in p.experience) { buf.writeln('▸ ${e.role} — ${e.company} (${e.duration})');
        if (e.description != null) buf.writeln('  ${e.description}'); } buf.writeln(); }
    if (p.education.isNotEmpty) { buf.writeln('── EDUCACIÓN ──');
      for (final e in p.education) buf.writeln('▸ ${e.degree} — ${e.school} (${e.years})'); buf.writeln(); }
    if (p.skills.isNotEmpty) { buf.writeln('── HABILIDADES ──'); buf.writeln(p.skills.join(' · ')); buf.writeln(); }
    if (_badges.isNotEmpty) { buf.writeln('── CERTIFICACIONES ──');
      for (final b in _badges) buf.writeln('✓ ${b.skillName} — ${b.badgeLevel.toUpperCase()} (${b.score}%)'); buf.writeln(); }
    if (_aiStrengths != null) { buf.writeln('── FORTALEZAS ──'); buf.writeln(_aiStrengths); }
    buf.writeln('\nGenerado con Mploya AI');

    Clipboard.setData(ClipboardData(text: buf.toString()));
    HapticFeedback.heavyImpact();
    if (mounted) showCupertinoDialog(context: context, builder: (c) => CupertinoAlertDialog(
      title: const Text('CV Copiado ✓'), content: const Text('Tu CV profesional fue copiado al portapapeles. Podés pegarlo en cualquier app.'),
      actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
  }
}
