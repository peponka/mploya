import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/web_ui.dart';
import '../widgets/mploya_toast.dart';
import '../services/ai_interview_service.dart';
import 'interview_flow_screen.dart';
import 'interview_report_screen.dart';
import 'premium_paywall_screen.dart';

// ═══════════════════════════════════════════════════════════════
// DEMO DATA
// ═══════════════════════════════════════════════════════════════
// Datos de muestra mientras no haya candidatos reales. 4 etapas distintas
// (pendiente / revision / entrevista / contratar) para que cada columna del
// Kanban tenga gente diferente, con caras y nombres variados.
final _demoCandidates = [
  // ── Pendientes ──
  _C(name: 'Valentina Ríos', role: 'UX/UI Designer', match: 94, skills: ['Figma', 'Research', 'Prototipado'], photo: 'https://randomuser.me/api/portraits/women/44.jpg', stage: 'pendiente', hasVideo: true, pitchTitle: 'PITCH · UX/UI DESIGNER'),
  _C(name: 'Mateo Herrera', role: 'Frontend Developer', match: 91, skills: ['React', 'TypeScript', 'Next.js'], photo: 'https://randomuser.me/api/portraits/men/32.jpg', stage: 'pendiente', hasVideo: true, pitchTitle: 'PITCH · FRONTEND DEVELOPER'),
  _C(name: 'Camila Duarte', role: 'Data Analyst', match: 87, skills: ['SQL', 'Power BI', 'Python'], photo: 'https://randomuser.me/api/portraits/women/68.jpg', stage: 'pendiente', hasVideo: false, pitchTitle: 'PITCH · DATA ANALYST'),
  // ── Revisión Inicial ──
  _C(name: 'Sebastián Vega', role: 'Backend Engineer', match: 89, skills: ['Go', 'AWS', 'PostgreSQL'], photo: 'https://randomuser.me/api/portraits/men/45.jpg', stage: 'revision', hasVideo: true, pitchTitle: 'PITCH · BACKEND ENGINEER'),
  _C(name: 'Martina Ortiz', role: 'Product Manager', match: 85, skills: ['Agile', 'Analytics', 'Roadmap'], photo: 'https://randomuser.me/api/portraits/women/12.jpg', stage: 'revision', hasVideo: true, pitchTitle: 'PITCH · PRODUCT MANAGER'),
  _C(name: 'Tomás Aguirre', role: 'DevOps Engineer', match: 83, skills: ['Docker', 'K8s', 'Terraform'], photo: 'https://randomuser.me/api/portraits/men/60.jpg', stage: 'revision', hasVideo: false, pitchTitle: 'PITCH · DEVOPS ENGINEER'),
  // ── Listo para Entrevista ──
  _C(name: 'Lucía Fernández', role: 'Data Scientist', match: 96, skills: ['Python', 'ML', 'TensorFlow'], photo: 'https://randomuser.me/api/portraits/women/25.jpg', stage: 'entrevista', hasVideo: true, pitchTitle: 'PITCH · DATA SCIENTIST'),
  _C(name: 'Nicolás Rojas', role: 'Mobile Developer', match: 90, skills: ['Flutter', 'Dart', 'Firebase'], photo: 'https://randomuser.me/api/portraits/men/51.jpg', stage: 'entrevista', hasVideo: true, pitchTitle: 'PITCH · MOBILE DEVELOPER'),
  _C(name: 'Julieta Sosa', role: 'QA Engineer', match: 82, skills: ['Cypress', 'Selenium', 'Jest'], photo: 'https://randomuser.me/api/portraits/women/33.jpg', stage: 'entrevista', hasVideo: false, pitchTitle: 'PITCH · QA ENGINEER'),
  // ── Listo para Contratar ──
  _C(name: 'Diego Molina', role: 'Fullstack Developer', match: 93, skills: ['Node', 'React', 'MongoDB'], photo: 'https://randomuser.me/api/portraits/men/3.jpg', stage: 'contratar', hasVideo: true, pitchTitle: 'PITCH · FULLSTACK DEVELOPER'),
  _C(name: 'Florencia Castro', role: 'Marketing Lead', match: 88, skills: ['SEO', 'Ads', 'Growth'], photo: 'https://randomuser.me/api/portraits/women/57.jpg', stage: 'contratar', hasVideo: true, pitchTitle: 'PITCH · MARKETING LEAD'),
  _C(name: 'Bruno Silva', role: 'Sales Manager', match: 80, skills: ['CRM', 'Negociación', 'B2B'], photo: 'https://randomuser.me/api/portraits/men/72.jpg', stage: 'contratar', hasVideo: false, pitchTitle: 'PITCH · SALES MANAGER'),
];

class _C {
  final String name, role, photo, stage, pitchTitle;
  final int match;
  final List<String> skills;
  final bool hasVideo;
  const _C({required this.name, required this.role, required this.match, required this.skills, required this.photo, required this.stage, required this.hasVideo, required this.pitchTitle});
}

// ═══════════════════════════════════════════════════════════════

class AtsDashboardScreen extends StatefulWidget {
  /// `embedded` = true cuando se muestra dentro del hub "Panel" (sin su propio
  /// título/scaffold, porque el hub ya los provee).
  final bool embedded;
  const AtsDashboardScreen({super.key, this.embedded = false});
  @override
  State<AtsDashboardScreen> createState() => _AtsDashboardScreenState();
}

class _AtsDashboardScreenState extends State<AtsDashboardScreen> {
  int _tabIdx = 0; // 0=Pendientes, 1=Contactos, 2=Confidencial
  bool _confidencialUnlocked = false;
  final _tabs = ['Pendientes', 'Contactos', 'Confidencial'];
  // Nombres de candidatos ya aceptados/rechazados en esta sesión (Modo Demo,
  // no persiste) — se sacan de las columnas del Kanban al actuar sobre ellos.
  final Set<String> _actedOn = {};

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _embeddedBody(context);
    final wide = isWebWide(context);
    if (wide) return _webLayout(context);
    return _mobileLayout(context);
  }

  // Cuerpo sin título ni scaffold, para el hub "Panel": tabs + contenido.
  Widget _embeddedBody(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _webTabs(context),
        const SizedBox(height: 16),
        if (_tabIdx == 0) _pendientesWeb(context),
        if (_tabIdx == 1) _contactosWeb(context),
        if (_tabIdx == 2) _confidencialWeb(context),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // WEB LAYOUT
  // ═══════════════════════════════════════════════════════════════
  Widget _webLayout(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      child: WebPage(
        title: 'Candidatos',
        actions: [
          _filterDropdown('Rol'),
          const SizedBox(width: 6),
          _filterDropdown('Ubicación'),
          const SizedBox(width: 6),
          _filterDropdown('Coincidencia'),
          const SizedBox(width: 6),
          _filterDropdown('Experiencia'),
        ],
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Tabs
            _webTabs(context),
            const SizedBox(height: 16),
            // Content by tab
            if (_tabIdx == 0) _pendientesWeb(context),
            if (_tabIdx == 1) _contactosWeb(context),
            if (_tabIdx == 2) _confidencialWeb(context),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _filterDropdown(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(width: 4),
        const Icon(CupertinoIcons.chevron_down, size: 12, color: Color(0xFF94A3B8)),
      ]),
    );
  }

  Widget _webTabs(BuildContext context) {
    return Row(children: List.generate(3, (i) {
      final active = i == _tabIdx;
      return GestureDetector(
        onTap: () => setState(() => _tabIdx = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          child: Text(_tabs[i], style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? const Color(0xFF1E293B) : const Color(0xFF94A3B8))),
        ),
      );
    }));
  }

  Widget _pendientesWeb(BuildContext context) {
    List<_C> byStage(String stage) =>
        _demoCandidates.where((c) => c.stage == stage && !_actedOn.contains(c.name)).toList();
    final cols = [
      ('Pendientes', byStage('pendiente'), const Color(0xFF185FA5)),
      ('Revisión Inicial', byStage('revision'), const Color(0xFF3B82F6)),
      ('Listo para Entrevista', byStage('entrevista'), const Color(0xFF10B981)),
      ('Listo para Contratar', byStage('contratar'), const Color(0xFF8B5CF6)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (_, cons) {
          // Ancho suficiente para las 4 columnas (~240px c/u): se reparten el
          // ancho y entran completas. Si no, scroll horizontal con ancho fijo.
          if (cons.maxWidth >= 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < cols.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  Expanded(child: _kanbanCol(context, cols[i].$1, cols[i].$2, cols[i].$3)),
                ],
              ],
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < cols.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  SizedBox(width: 300, child: _kanbanCol(context, cols[i].$1, cols[i].$2, cols[i].$3)),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: 32),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: _aiSourcingPanel(context),
        ),
      ],
    );
  }

  Widget _kanbanCol(BuildContext context, String title, List<_C> candidates, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      if (candidates.isEmpty)
        Container(
          padding: const EdgeInsets.all(20),
          alignment: Alignment.center,
          child: const Text('Sin candidatos', style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
        )
      else
        ...candidates.map((c) => _kanbanCard(context, c, color)),
    ]);
  }

  Widget _kanbanCard(BuildContext context, _C c, Color stageColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4))],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ClipOval(child: CachedNetworkImage(imageUrl: c.photo, width: 54, height: 54, fit: BoxFit.cover,
            placeholder: (_, __) => Container(width: 54, height: 54, color: Colors.grey.shade200),
            errorWidget: (_, __, ___) => Container(width: 54, height: 54, color: Colors.grey.shade300))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const SizedBox(height: 3),
            Text('Coincidencia ${c.match}%', style: TextStyle(fontSize: 13, color: stageColor, fontWeight: FontWeight.w700)),
          ])),
          if (c.hasVideo) const Icon(CupertinoIcons.play_circle_fill, size: 24, color: Color(0xFF3B82F6)),
        ]),
        const SizedBox(height: 14),
        // Skills
        Wrap(spacing: 6, runSpacing: 6, children: c.skills.map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
          child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        )).toList()),
        const SizedBox(height: 16),
        // Buttons
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showCandidatePreview(context, c),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: (c.hasVideo ? const Color(0xFF185FA5) : const Color(0xFF64748B)).withValues(alpha: c.hasVideo ? 0.1 : 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(c.hasVideo ? 'Revisar Pitch' : 'Ver Perfil',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.hasVideo ? const Color(0xFF185FA5) : const Color(0xFF64748B)))),
          ),
        ),
        const SizedBox(height: 8),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _handleIAInterview(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'Entrevista IA ✨',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _acceptCandidate(context, c),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('Aceptar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF10B981)))),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _rejectCandidate(context, c),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('Rechazar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)))),
            ),
          )),
        ]),
      ]),
    );
  }

  void _acceptCandidate(BuildContext context, _C c) {
    HapticFeedback.mediumImpact();
    setState(() => _actedOn.add(c.name));
    MployaToast.success(context, '${c.name} aceptado — pasa a la siguiente etapa');
  }

  void _rejectCandidate(BuildContext context, _C c) {
    HapticFeedback.lightImpact();
    setState(() => _actedOn.add(c.name));
    MployaToast.removed(context, '${c.name} fue rechazado');
  }

  void _showCandidatePreview(BuildContext context, _C c) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(c.name),
        message: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(alignment: Alignment.center, children: [
                CachedNetworkImage(imageUrl: c.photo.replaceAll('w=200&h=200', 'w=500&h=500'), width: 220, height: 220, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(width: 220, height: 220, color: Colors.grey.shade200),
                  errorWidget: (_, __, ___) => Container(width: 220, height: 220, color: Colors.grey.shade300)),
                if (c.hasVideo)
                  Container(width: 56, height: 56,
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
                    child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 26)),
              ]),
            ),
            const SizedBox(height: 12),
            Text('${c.role} · Coincidencia ${c.match}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: c.skills.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            )).toList()),
            if (!c.hasVideo) ...[
              const SizedBox(height: 10),
              const Text('Este candidato todavía no subió un video-pitch.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ],
        ),
        actions: [
          if (c.hasVideo)
            CupertinoActionSheetAction(
              child: const Text('Reproducir video-pitch (demo)'),
              onPressed: () {
                Navigator.pop(ctx);
                MployaToast.info(context, 'Reproduciendo pitch de ${c.name} (demo)');
              },
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ),
    );
  }

  Widget _aiSourcingPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF185FA5), Color(0xFF0C447C)]), borderRadius: BorderRadius.circular(8)),
            child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 14)),
          const SizedBox(width: 8),
          const Text('Búsqueda con IA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
        ]),
        const SizedBox(height: 6),
        const Text('Encontrá candidatos automáticamente según el perfil que buscás. La IA prioriza a los que mejor coinciden con tu vacante.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 16),
        _aiFilterField('Rol'),
        const SizedBox(height: 8),
        _aiFilterField('Ubicación'),
        const SizedBox(height: 8),
        _aiFilterField('Coincidencia'),
        const SizedBox(height: 8),
        _aiFilterField('Estado del candidato'),
        const SizedBox(height: 16),
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF334155)]), borderRadius: BorderRadius.circular(10)),
          child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(CupertinoIcons.lock_fill, color: Colors.white, size: 14),
            SizedBox(width: 6),
            Text('Buscar talento', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ])),
        ),
        const SizedBox(height: 8),
        Center(child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF185FA5), Color(0xFF0C447C)]), shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: const Color(0xFF185FA5).withValues(alpha: 0.3), blurRadius: 8)]),
          child: const Icon(CupertinoIcons.plus, color: Colors.white, size: 16),
        )),
      ]),
    );
  }

  Widget _aiFilterField(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
        const Spacer(),
        const Icon(CupertinoIcons.chevron_down, size: 12, color: Color(0xFF94A3B8)),
      ]),
    );
  }

  // ── Contactos tab ──
  Widget _contactosWeb(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Contactos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _demoCandidates.map((c) => _contactCard(c)).toList(),
      ),
    ]);
  }

  Widget _contactCard(_C c) {
    return Container(
      width: 330,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: c.photo,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(width: 54, height: 54, color: Colors.grey.shade200),
                  errorWidget: (_, __, ___) => Container(width: 54, height: 54, color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.role,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.ellipsis, size: 20, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 14),
          // Skills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: c.skills.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            )).toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            'Perfil completo con historial detallado de experiencia y evaluación de habilidades técnicas.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: const Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Coincidencia General',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              Text(
                '${c.match}%',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Buttons
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showScheduleInterview(context, c),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Agendar entrevista',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _handleIAInterview(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Entrevista IA ✨',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showScheduleInterview(BuildContext context, _C c) {
    const slots = ['Mañana 10:00', 'Mañana 15:30', 'Pasado mañana 09:00'];
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Agendar entrevista con ${c.name}'),
        message: const Text('Elegí un horario (Modo Demo, no se envía ninguna invitación real).'),
        actions: slots.map((slot) => CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(ctx);
            HapticFeedback.mediumImpact();
            MployaToast.success(context, 'Entrevista con ${c.name} agendada para $slot');
          },
          child: Text(slot),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  // ── Confidencial tab ──
  Widget _confidencialWeb(BuildContext context) {
    if (!_confidencialUnlocked) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                child: const Icon(CupertinoIcons.lock_shield_fill, size: 28, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              const Text('Base de datos confidencial', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              const SizedBox(height: 6),
              const Text('Accedé a candidatos que mantienen su perfil en modo confidencial. Requiere plan premium.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              const SizedBox(height: 20),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const PremiumPaywallScreen()),
                  ).then((_) {
                    setState(() => _confidencialUnlocked = true);
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF185FA5), Color(0xFF0C447C)]), borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('Desbloquear acceso', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Unlocked view: show the confidential candidates!
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Candidatos Confidenciales',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(_demoCandidates.length, (index) {
            final c = _demoCandidates[index];
            return _confidencialCandidateCard(c, index);
          }),
        ),
      ],
    );
  }

  Widget _confidencialCandidateCard(_C c, int index) {
    final confidentialId = 100 + index * 17;
    return Container(
      width: 330,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Blurred or lock avatar
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(CupertinoIcons.eye_slash_fill, size: 22, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Talento Confidencial #$confidentialId',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.role,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.lock_fill, size: 10, color: Color(0xFF64748B)),
                    SizedBox(width: 4),
                    Text('Premium', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Skills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: c.skills.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            )).toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            'Este candidato prefiere mantener su perfil en modo confidencial. Revisa su video pitch o solicita contacto directo.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: const Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Coincidencia por IA',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              Text(
                '${c.match}%',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Buttons
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const PremiumPaywallScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF185FA5), Color(0xFF0C447C)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Solicitar Identidad (Match)',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _handleIAInterview(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Entrevista IA ✨',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MOBILE LAYOUT
  // ═══════════════════════════════════════════════════════════════
  // Mismo contenido que la web (_pendientesWeb/_contactosWeb/_confidencialWeb ya
  // son responsive: Wrap y scroll horizontal con ancho fijo, no dependen de estar
  // en pantalla ancha) — antes esto era un carrusel de "un candidato a la vez" con
  // diseño propio, y ni siquiera se podía llegar a Contactos/Confidencial en mobile.
  Widget _mobileLayout(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.bgColor,
      child: SafeArea(child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false,
            largeTitle: Text('Candidatos', style: TextStyle(color: context.textPrimary, fontSize: 26, letterSpacing: -0.4, fontWeight: FontWeight.w800)),
            backgroundColor: context.bgColor,
            border: null,
          ),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _webTabs(context),
          )),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _tabIdx == 0
                ? _pendientesWeb(context)
                : _tabIdx == 1
                    ? _contactosWeb(context)
                    : _confidencialWeb(context),
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      )),
    );
  }

  Future<void> _handleIAInterview(BuildContext context) async {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Entrevistas por IA'),
        message: const Text('Selecciona una opción. El Modo Demo funciona instantáneamente de forma local.'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Simular Entrevista (Candidato) - Modo Demo 🚀'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const InterviewFlowScreen(interviewId: 'demo-pending'),
                ),
              );
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Ver Reporte IA (Reclutador) - Modo Demo 📊'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const InterviewReportScreen(interviewId: 'demo-completed'),
                ),
              );
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Simular Entrevista (Base de Datos Real)'),
            onPressed: () {
              Navigator.pop(context);
              _launchDemoInterview(context, isCandidate: true);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Ver Reporte IA (Base de Datos Real)'),
            onPressed: () {
              Navigator.pop(context);
              _launchDemoInterview(context, isCandidate: false);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Future<void> _launchDemoInterview(BuildContext context, {required bool isCandidate}) async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator(radius: 16)),
    );

    try {
      final client = Supabase.instance.client;
      final jobs = await client.from('jobs').select('id').limit(1).timeout(const Duration(seconds: 3));
      final users = await client.from('users').select('id').limit(1).timeout(const Duration(seconds: 3));

      if (!mounted) return;
      Navigator.pop(context); // Quitar loader

      if (jobs.isEmpty || users.isEmpty) {
        _showDemoFallbackDialog(context, isCandidate, 'Falta de registros');
        return;
      }

      final jobId = jobs[0]['id'] as String;
      final candidateId = users[0]['id'] as String;

      final existing = await client
          .from('interviews')
          .select('id')
          .eq('job_id', jobId)
          .eq('candidate_id', candidateId)
          .limit(1)
          .timeout(const Duration(seconds: 3));

      String interviewId;
      if (existing.isNotEmpty) {
        interviewId = existing[0]['id'] as String;
      } else {
        final interview = await AIInterviewService.instance.createInterview(
          jobId: jobId,
          candidateId: candidateId,
        ).timeout(const Duration(seconds: 3));
        if (interview == null) throw Exception('No se pudo crear el registro de entrevista.');
        interviewId = interview.id;
      }

      if (!mounted) return;
      if (isCandidate) {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => InterviewFlowScreen(interviewId: interviewId),
          ),
        );
      } else {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => InterviewReportScreen(interviewId: interviewId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Quitar loader en caso de error
        _showDemoFallbackDialog(context, isCandidate, 'Timeout o error de red');
      }
    }
  }

  void _showDemoFallbackDialog(BuildContext context, bool isCandidate, String reason) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Conexión Supabase'),
        content: Text(
          'No se pudo conectar a la base de datos de Supabase ($reason).\n\n'
          '¿Deseas probar el flujo usando el Modo de Demostración Local?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Modo Demo'),
            onPressed: () {
              Navigator.pop(context);
              final demoId = isCandidate ? 'demo-pending' : 'demo-completed';
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => isCandidate
                      ? InterviewFlowScreen(interviewId: demoId)
                      : InterviewReportScreen(interviewId: demoId),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}