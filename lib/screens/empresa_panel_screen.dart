import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/web_ui.dart';
import '../services/ai_match_service.dart';
import 'nueva_vacante_screen.dart';
import 'vacantes_screen.dart';
import 'ats_kanban_screen.dart';
import 'profile_screen.dart';
import '../models/models.dart';

/// Panel de empresa — dashboard SaaS premium nivel inversor.
class EmpresaPanelScreen extends StatefulWidget {
  const EmpresaPanelScreen({super.key});
  @override
  State<EmpresaPanelScreen> createState() => _EmpresaPanelScreenState();
}

class _EmpresaPanelScreenState extends State<EmpresaPanelScreen>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _loading = true;

  int _vacantes = 0, _postulantes = 0, _entrevistas = 0, _contratados = 0;
  final Map<String, int> _funnel = {'applied': 0, 'interview': 0, 'offer': 0, 'hired': 0};
  List<Map<String, dynamic>> _topCandidates = [];
  String _companyName = 'tu empresa';
  String _selectedFilter = 'Todo';

  late AnimationController _fadeCtrl;

  // ── Demo data para inversores (9 candidatos) ──
  static const _dN = ['Sofía Martínez', 'Lucas Fernández', 'Valentina López', 'Mateo García', 'Camila Rodríguez', 'Santiago Pérez', 'Martina Gómez', 'Tomás Herrera', 'Florencia Díaz'];
  static const _dH = ['Product Designer · Globant', 'Sr. Frontend Dev · MercadoLibre', 'Data Scientist · Ualá', 'UX Lead · Rappi', 'Backend Engineer · Auth0', 'Growth PM · Naranja X', 'DevOps Lead · Despegar', 'Mobile Dev · Pedidos Ya', 'QA Automation · Tiendanube'];
  static const _dS = [
    ['Figma', 'UX Research', 'Design Systems', 'Prototyping'],
    ['React', 'TypeScript', 'Next.js', 'GraphQL'],
    ['Python', 'ML', 'TensorFlow', 'SQL'],
    ['User Research', 'Figma', 'A/B Testing', 'Agile'],
    ['Go', 'Kubernetes', 'PostgreSQL', 'gRPC'],
    ['Analytics', 'SQL', 'Product Strategy', 'OKRs'],
    ['AWS', 'Docker', 'Terraform', 'CI/CD'],
    ['Flutter', 'Swift', 'Kotlin', 'Firebase'],
    ['Selenium', 'Cypress', 'Jest', 'Python'],
  ];
  static const _dM = [98, 96, 95, 93, 91, 89, 87, 85, 83];
  static const _dSrc = ['Video Postulación', 'Match IA', 'Referido', 'Video Postulación', 'Búsqueda directa', 'Match IA', 'Video Postulación', 'Referido', 'Match IA'];
  static const _dSt = ['postulante', 'postulante', 'postulante', 'pendiente', 'pendiente', 'pendiente', 'exitoso', 'exitoso', 'confidencial'];
  static const _dLoc = ['Buenos Aires', 'CABA', 'Córdoba', 'Buenos Aires', 'Rosario', 'Mendoza', 'CABA', 'Montevideo', 'Santiago'];
  static const _dExp = ['5 años', '7 años', '4 años', '8 años', '6 años', '3 años', '9 años', '5 años', '4 años'];

  @override
  void initState() { super.initState(); _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700)); _load(); }
  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) { if (mounted) setState(() => _loading = false); return; }
    try {
      try { final me = await _supabase.from('users').select('name').eq('id', uid).maybeSingle(); _companyName = (me?['name'] ?? 'tu empresa').toString(); } catch (_) {}
      final jobs = List<Map<String, dynamic>>.from(await _supabase.from('jobs').select('id, title').eq('company_id', uid).order('created_at', ascending: false));
      _vacantes = jobs.length;
      final jobIds = jobs.map((j) => j['id'].toString()).toList();
      if (jobIds.isNotEmpty) {
        try {
          final apps = List<Map<String, dynamic>>.from(await _supabase.from('job_applications').select('status').inFilter('job_id', jobIds));
          _postulantes = apps.length;
          for (final a in apps) { final s = (a['status'] ?? 'applied').toString(); if (s == 'hired' || s == 'accepted') { _funnel['hired'] = (_funnel['hired'] ?? 0) + 1; _contratados++; } else if (s == 'offer') _funnel['offer'] = (_funnel['offer'] ?? 0) + 1; else if (s == 'interview') _funnel['interview'] = (_funnel['interview'] ?? 0) + 1; }
          _funnel['applied'] = _postulantes;
        } catch (_) {}
        try { final iv = List<Map<String, dynamic>>.from(await _supabase.from('interviews').select('id').inFilter('job_id', jobIds)); _entrevistas = iv.length; } catch (_) {}
        try { _topCandidates = await AIMatchService.instance.getCandidatesForJob(jobIds.first, limit: 5); } catch (_) {}
      }
    } catch (e) { debugPrint('Panel empresa load: $e'); }
    if (_vacantes == 0) _vacantes = 8;
    if (_postulantes == 0) _postulantes = 47;
    if (_entrevistas == 0) _entrevistas = 18;
    if (_contratados == 0) _contratados = 9;
    if (_funnel['applied'] == 0) { _funnel['applied'] = 47; _funnel['interview'] = 18; _funnel['offer'] = 9; _funnel['hired'] = 9; }
    if (mounted) { setState(() => _loading = false); _fadeCtrl.forward(); }
  }

  void _openCreate() { Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const NuevaVacanteScreen())).then((ok) { if (ok == true) _load(); }); }
  bool get _useDemo => _topCandidates.isEmpty;
  int get _cnt => _useDemo ? _dN.length : _topCandidates.length;

  @override
  Widget build(BuildContext context) {
    final wide = isWebWide(context);
    return WebPage(
      title: 'Panel',
      subtitle: 'Hola, $_companyName. Gestioná candidatos, contactos y vía rápida confidencial.',
      actions: [
        _pill(context, CupertinoIcons.chart_bar_fill, 'Vacantes', false, () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const VacantesScreen()))),
        const SizedBox(width: 8),
        _pill(context, CupertinoIcons.add, 'Nueva vacante', true, _openCreate),
      ],
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : FadeTransition(
              opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 48),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _kpiRow(context),
                  const SizedBox(height: 24),
                  _pipelineSection(context),
                  const SizedBox(height: 24),
                  // ── Hero: Match del día ──
                  _heroMatchCard(context),
                  const SizedBox(height: 24),
                  // ── AI Insight + CTA ──
                  wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 2, child: _aiInsightCard(context)),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: _ctaBanner(context)),
                  ]) : Column(children: [_aiInsightCard(context), const SizedBox(height: 16), _ctaBanner(context)]),
                  const SizedBox(height: 24),
                  // ── Candidate columns + sidebar ──
                  wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: _candidateColumns(context)),
                    const SizedBox(width: 18),
                    SizedBox(width: 230, child: _sidebar(context)),
                  ]) : Column(children: [_candidateColumns(context), const SizedBox(height: 18), _sidebar(context)]),
                ]),
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  KPI ROW — Cards grandes con tendencia
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _kpiRow(BuildContext ctx) {
    return LayoutBuilder(builder: (_, cons) {
      final cols = cons.maxWidth > 800 ? 5 : (cons.maxWidth > 500 ? 3 : 2);
      const gap = 12.0;
      final tw = (cons.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        SizedBox(width: tw, child: _kpiCompact(ctx, 'Nuevos Postulantes', '$_postulantes', '+12%', CupertinoIcons.person_badge_plus_fill, MployaTheme.brandAccent)),
        SizedBox(width: tw, child: _kpiCompact(ctx, 'Acciones Pendientes', '$_entrevistas', '+5%', CupertinoIcons.tray_fill, const Color(0xFFEA580C))),
        SizedBox(width: tw, child: _kpiCompact(ctx, 'Contactos Directos', '$_contratados', '+8%', CupertinoIcons.bolt_fill, kMployaBlue)),
        SizedBox(width: tw, child: _kpiCompact(ctx, 'Vacantes Activas', '$_vacantes', '+3%', CupertinoIcons.briefcase_fill, const Color(0xFF10B981))),
        SizedBox(width: tw, child: _creditKpi(ctx)),
      ]);
    });
  }

  Widget _kpiCompact(BuildContext ctx, String label, String value, String trend, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ctx.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ctx.dividerColor.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: ctx.textTertiary, fontSize: 10.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Row(children: [
            Text(value, style: TextStyle(color: ctx.textPrimary, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -1)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(CupertinoIcons.arrow_up_right, size: 10, color: Color(0xFF10B981)),
                Text(trend, style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ])),
      ]),
    );
  }

  Widget _creditKpi(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ctx.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: MployaTheme.brandAccent.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFBBF24)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(CupertinoIcons.lock_shield_fill, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Créditos Confidenciales', style: TextStyle(color: ctx.textTertiary, fontSize: 10.5, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(CupertinoIcons.lock_fill, size: 9, color: MployaTheme.brandAccent),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            Text('5', style: TextStyle(color: ctx.textPrimary, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -1)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [MployaTheme.brandAccent.withValues(alpha: 0.15), MployaTheme.brandAccent.withValues(alpha: 0.05)]),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Premium', style: TextStyle(color: MployaTheme.brandAccent, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ]),
        ])),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PIPELINE — Barra con números
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _pipelineSection(BuildContext ctx) {
    final segs = [
      _Seg('Postulantes', 47, MployaTheme.brandAccent, 0.40),
      _Seg('Favoritos', 18, const Color(0xFFFBBF24), 0.22),
      _Seg('Exitosos', 9, kMployaBlue, 0.15),
      _Seg('Confidencial 🔒', 5, const Color(0xFF9CA3AF), 0.13),
      _Seg('Contratados', 4, const Color(0xFF10B981), 0.10),
    ];
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ctx.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ctx.dividerColor.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 18, runSpacing: 8, children: [
          for (final s in segs)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${s.label} ', style: TextStyle(color: ctx.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(height: 14, child: Row(children: [
            for (int i = 0; i < segs.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(flex: (segs[i].frac * 100).round().clamp(1, 100), child: Container(
                decoration: BoxDecoration(color: segs[i].color, borderRadius: BorderRadius.circular(4)),
              )),
            ],
          ])),
        ),
        const SizedBox(height: 10),
        Row(children: [
          for (int i = 0; i < segs.length; i++) ...[
            if (i > 0) const Spacer(),
            Text('${segs[i].count}', style: TextStyle(color: segs[i].color, fontSize: 13, fontWeight: FontWeight.w800)),
          ],
        ]),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HERO — Match del día 🏆
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _heroMatchCard(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ctx.isDark
              ? [const Color(0xFF1A1520), const Color(0xFF0F1117)]
              : [const Color(0xFFFFF7ED), const Color(0xFFFFFBF5)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: MployaTheme.brandAccent.withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFBBF24)]),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('🏆', style: TextStyle(fontSize: 13)),
              SizedBox(width: 5),
              Text('Match del Día', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
          ),
          const Spacer(),
          Text('Recomendado por IA', style: TextStyle(color: ctx.textTertiary, fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(CupertinoIcons.sparkles, size: 14, color: MployaTheme.brandAccent),
        ]),
        const SizedBox(height: 20),
        // Content
        LayoutBuilder(builder: (_, cons) {
          final wide = cons.maxWidth > 600;
          final content = [
            // Left: Avatar + info
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Big avatar
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFBBF24)]),
                  boxShadow: [BoxShadow(color: MployaTheme.brandAccent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ctx.cardColor),
                  alignment: Alignment.center,
                  child: Text('SM', style: TextStyle(color: MployaTheme.brandAccent, fontSize: 24, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sofía Martínez', style: TextStyle(color: ctx.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('Product Designer · Globant', style: TextStyle(color: ctx.textSecondary, fontSize: 14)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(CupertinoIcons.location_solid, size: 13, color: ctx.textTertiary),
                  const SizedBox(width: 4),
                  Text('Buenos Aires', style: TextStyle(color: ctx.textTertiary, fontSize: 12.5)),
                  const SizedBox(width: 12),
                  Icon(CupertinoIcons.briefcase, size: 13, color: ctx.textTertiary),
                  const SizedBox(width: 4),
                  Text('5 años exp.', style: TextStyle(color: ctx.textTertiary, fontSize: 12.5)),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final s in ['Figma', 'UX Research', 'Design Systems', 'Prototyping', 'User Testing'])
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ctx.isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(s, style: TextStyle(color: ctx.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ),
                ]),
              ])),
            ]),
            const SizedBox(width: 24, height: 20),
            // Right: Match ring + actions
            Column(children: [
              // Big match ring
              SizedBox(
                width: 100, height: 100,
                child: Stack(alignment: Alignment.center, children: [
                  CustomPaint(size: const Size(100, 100), painter: _RingPainter(0.98, MployaTheme.brandAccent, ctx.dividerColor.withValues(alpha: 0.15))),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('98%', style: TextStyle(color: MployaTheme.brandAccent, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1)),
                    Text('match', style: TextStyle(color: ctx.textTertiary, fontSize: 11)),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              // Action buttons
              Row(mainAxisSize: MainAxisSize.min, children: [
                _heroBtn(ctx, CupertinoIcons.play_circle_fill, 'Ver Video', MployaTheme.brandAccent),
                const SizedBox(width: 10),
                _heroBtn(ctx, CupertinoIcons.calendar, 'Agendar', kMployaBlue),
                const SizedBox(width: 10),
                _heroBtn(ctx, CupertinoIcons.chat_bubble_fill, 'Chat', const Color(0xFF10B981)),
              ]),
            ]),
          ];
          if (wide) return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: content[0]), content[1], content[2]]);
          return Column(crossAxisAlignment: CrossAxisAlignment.center, children: content);
        }),
      ]),
    );
  }

  Widget _heroBtn(BuildContext ctx, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  AI INSIGHT CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _aiInsightCard(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ctx.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kMployaPurple.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: kMployaPurple.withValues(alpha: 0.06), blurRadius: 20)],
      ),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [kMployaPurple.withValues(alpha: 0.15), kMployaPurple.withValues(alpha: 0.05)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(CupertinoIcons.sparkles, color: kMployaPurple, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Insight IA', style: TextStyle(color: kMployaPurple, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            const SizedBox(width: 8),
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text('Ahora', style: TextStyle(color: ctx.textTertiary, fontSize: 10)),
          ]),
          const SizedBox(height: 6),
          Text('Tenés 3 candidatos con +95% de match esperando respuesta. Los perfiles con video tienen 4.2x más probabilidad de ser contratados.',
              style: TextStyle(color: ctx.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500, height: 1.45)),
          const SizedBox(height: 8),
          Row(children: [
            Text('Ver candidatos recomendados', style: TextStyle(color: kMployaPurple, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            const Icon(CupertinoIcons.arrow_right, size: 13, color: kMployaPurple),
          ]),
        ])),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CTA BANNER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _ctaBanner(BuildContext ctx) {
    return GestureDetector(
      onTap: _openCreate,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFB923C), Color(0xFFF59E0B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 14)),
            const SizedBox(width: 8),
            const Text('IA', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 14),
          const Text('Publicá una nueva\nbúsqueda', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text('La IA la redacta por vos.', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))]),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(CupertinoIcons.sparkles, color: Color(0xFF9A3412), size: 14), SizedBox(width: 6), Text('Nueva vacante', style: TextStyle(color: Color(0xFF9A3412), fontSize: 13, fontWeight: FontWeight.w700))]),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CANDIDATE COLUMNS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _candidateColumns(BuildContext ctx) {
    final groups = <String, List<int>>{'Postulantes': [], 'Pendientes': [], 'Confidencial': []};
    for (int i = 0; i < _cnt; i++) {
      final st = _useDemo ? _dSt[i] : 'postulante';
      if (st == 'pendiente') groups['Pendientes']!.add(i);
      else if (st == 'confidencial' || st == 'exitoso') groups['Confidencial']!.add(i);
      else groups['Postulantes']!.add(i);
    }
    return LayoutBuilder(builder: (_, cons) {
      final wide = cons.maxWidth > 680;
      if (wide) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _colGroup(ctx, 'Postulantes', groups['Postulantes']!)),
        const SizedBox(width: 14),
        Expanded(child: _colGroup(ctx, 'Pendientes', groups['Pendientes']!)),
        const SizedBox(width: 14),
        Expanded(child: _colGroup(ctx, 'Confidencial', groups['Confidencial']!)),
      ]);
      return Column(children: [
        _colGroup(ctx, 'Postulantes', groups['Postulantes']!),
        const SizedBox(height: 14),
        _colGroup(ctx, 'Pendientes', groups['Pendientes']!),
        const SizedBox(height: 14),
        _colGroup(ctx, 'Confidencial', groups['Confidencial']!),
      ]);
    });
  }

  Widget _colGroup(BuildContext ctx, String title, List<int> ids) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(title, style: TextStyle(color: ctx.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
          child: Text('${ids.length}', style: const TextStyle(color: MployaTheme.brandAccent, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      ]),
      const SizedBox(height: 12),
      for (final i in ids) ...[_card(ctx, i), const SizedBox(height: 14)],
      if (ids.isEmpty) Container(
        height: 100, alignment: Alignment.center,
        decoration: BoxDecoration(color: ctx.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: ctx.dividerColor.withValues(alpha: 0.15))),
        child: Text('Sin candidatos', style: TextStyle(color: ctx.textTertiary, fontSize: 12)),
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CANDIDATE CARD — Grande y rica
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _card(BuildContext ctx, int i) {
    final name = _useDemo ? _dN[i] : (_topCandidates[i]['name'] ?? 'Candidato');
    final hl = _useDemo ? _dH[i] : (_topCandidates[i]['headline'] ?? '');
    final match = _useDemo ? _dM[i] : ((_topCandidates[i]['match_percentage'] as num?)?.round() ?? 0);
    final skills = _useDemo ? _dS[i] : <String>[];
    final src = _useDemo ? _dSrc[i] : 'Match IA';
    final loc = _useDemo ? _dLoc[i] : '';
    final exp = _useDemo ? _dExp[i] : '';
    final ini = _ini(name.toString());
    final hi = match >= 95;
    final srcColor = src.contains('Video') ? MployaTheme.brandAccent : src.contains('Referido') ? const Color(0xFF10B981) : src.contains('directa') ? kMployaBlue : kMployaPurple;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ctx.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hi ? MployaTheme.brandAccent.withValues(alpha: 0.3) : ctx.dividerColor.withValues(alpha: 0.2), width: hi ? 1.5 : 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6)),
          if (hi) BoxShadow(color: MployaTheme.brandAccent.withValues(alpha: 0.06), blurRadius: 24),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar + name + match
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [MployaTheme.brandAccent.withValues(alpha: 0.2), MployaTheme.brandAccent.withValues(alpha: 0.05)]),
              border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.3), width: 2),
            ),
            alignment: Alignment.center,
            child: Text(ini, style: const TextStyle(color: MployaTheme.brandAccent, fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.toString(), style: TextStyle(color: ctx.textPrimary, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            Text(hl.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ctx.textTertiary, fontSize: 12, height: 1.4)),
            if (loc.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(children: [
                Icon(CupertinoIcons.location_solid, size: 11, color: ctx.textTertiary),
                const SizedBox(width: 3),
                Text(loc, style: TextStyle(color: ctx.textTertiary, fontSize: 11)),
                if (exp.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Text('· $exp exp.', style: TextStyle(color: ctx.textTertiary, fontSize: 11)),
                ],
              ]),
            ),
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(CupertinoIcons.checkmark_seal_fill, size: 13, color: Color(0xFF10B981)),
              const SizedBox(width: 4),
              Text('$match%', style: const TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        // Source
        Text('Match application', style: TextStyle(color: ctx.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: srcColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(src, style: TextStyle(color: srcColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        // Skills
        if (skills.isNotEmpty) ...[
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in skills.take(4))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: ctx.isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(7)),
                child: Text(s, style: TextStyle(color: ctx.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 14),
        ],
        // Actions
        Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: ctx.dividerColor.withValues(alpha: 0.15)))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _actBtn(ctx, CupertinoIcons.play_circle_fill, 'Ver Video', MployaTheme.brandAccent),
            _actBtn(ctx, CupertinoIcons.calendar, 'Agendar Entrevista', kMployaBlue),
            _actBtn(ctx, CupertinoIcons.chat_bubble_fill, 'Chat', const Color(0xFF10B981)),
          ]),
        ),
      ]),
    );
  }

  Widget _actBtn(BuildContext ctx, IconData ic, String label, Color c) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Icon(ic, size: 18, color: c),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: ctx.textTertiary, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SIDEBAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _sidebar(BuildContext ctx) {
    return Column(children: [
      _sideCard(ctx, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FILTRAR POR ESTADO', style: TextStyle(color: MployaTheme.brandAccent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        const SizedBox(height: 14),
        for (final f in ['Todo', 'Nuevo videocall', 'Pre-seleccionado', 'Oferta', 'Descartes'])
          GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: _selectedFilter == f ? MployaTheme.brandAccent.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: _selectedFilter == f ? Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.25)) : null,
              ),
              child: Text(f, style: TextStyle(color: _selectedFilter == f ? MployaTheme.brandAccent : ctx.textSecondary, fontSize: 13.5, fontWeight: _selectedFilter == f ? FontWeight.w700 : FontWeight.w500)),
            ),
          ),
      ])),
      const SizedBox(height: 16),
      _sideCard(ctx, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ÚLTIMAS RESEÑAS', style: TextStyle(color: MployaTheme.brandAccent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        const SizedBox(height: 14),
        _rev(ctx, 'Sofía M.', 'Tec', '"Excelente proceso, la entrevista IA fue muy práctica y moderna..."'),
        const SizedBox(height: 12),
        _rev(ctx, 'Lucas F.', 'Dev', '"La plataforma de video es increíble, me sentí cómodo presentando mi perfil."'),
        const SizedBox(height: 12),
        _rev(ctx, 'Valentina L.', 'Data', '"El match con IA fue super preciso, encontré justo lo que buscaba."'),
      ])),
      const SizedBox(height: 16),
      // Actividad reciente
      _sideCard(ctx, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ACTIVIDAD RECIENTE', style: TextStyle(color: MployaTheme.brandAccent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        const SizedBox(height: 14),
        _actItem(ctx, CupertinoIcons.videocam_fill, 'Nuevo video pitch', 'Sofía M. subió su video', 'Hace 2 min', MployaTheme.brandAccent),
        const SizedBox(height: 10),
        _actItem(ctx, CupertinoIcons.checkmark_circle_fill, 'Match confirmado', 'Lucas F. aceptó entrevista', 'Hace 15 min', const Color(0xFF10B981)),
        const SizedBox(height: 10),
        _actItem(ctx, CupertinoIcons.person_badge_plus_fill, 'Nueva postulación', 'Martina G. aplicó a UX Lead', 'Hace 1h', kMployaBlue),
        const SizedBox(height: 10),
        _actItem(ctx, CupertinoIcons.star_fill, 'Reseña recibida', '⭐⭐⭐⭐⭐ de Santiago P.', 'Hace 3h', const Color(0xFFFBBF24)),
        const SizedBox(height: 10),
        _actItem(ctx, CupertinoIcons.bolt_fill, 'Contacto directo', 'Camila R. abrió tu perfil', 'Hace 5h', kMployaPurple),
      ])),
    ]);
  }

  Widget _sideCard(BuildContext ctx, {required Widget child}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: ctx.cardColor, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: ctx.dividerColor.withValues(alpha: 0.25)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 6))],
    ),
    child: child,
  );

  Widget _rev(BuildContext ctx, String name, String tag, String text) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Text(name, style: TextStyle(color: ctx.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(width: 6),
      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: kMployaBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
        child: Text(tag, style: const TextStyle(color: kMployaBlue, fontSize: 10, fontWeight: FontWeight.w700))),
    ]),
    const SizedBox(height: 4),
    Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: ctx.textTertiary, fontSize: 12, fontStyle: FontStyle.italic, height: 1.4)),
  ]);

  Widget _actItem(BuildContext ctx, IconData icon, String title, String desc, String time, Color color) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: ctx.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
        Text(desc, style: TextStyle(color: ctx.textTertiary, fontSize: 11, height: 1.3)),
        Text(time, style: TextStyle(color: ctx.textTertiary.withValues(alpha: 0.6), fontSize: 10)),
      ])),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _pill(BuildContext ctx, IconData ic, String label, bool filled, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      height: 42, padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: filled ? null : ctx.cardColor,
        gradient: filled ? const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFB923C)]) : null,
        borderRadius: BorderRadius.circular(999),
        border: filled ? null : Border.all(color: ctx.dividerColor.withValues(alpha: 0.5)),
        boxShadow: filled ? [BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 5))] : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 16, color: filled ? Colors.white : ctx.textSecondary),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(color: filled ? Colors.white : ctx.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
      ]),
    ));
  }

  String _ini(String n) { final p = n.trim().split(RegExp(r'\s+')); if (p.isEmpty || p.first.isEmpty) return '?'; if (p.length == 1) return p.first[0].toUpperCase(); return (p.first[0] + p.last[0]).toUpperCase(); }
}

class _Seg { final String label; final int count; final Color color; final double frac; _Seg(this.label, this.count, this.color, this.frac); }

class _RingPainter extends CustomPainter {
  final double progress; final Color color; final Color bg;
  _RingPainter(this.progress, this.color, this.bg);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    canvas.drawCircle(c, r, Paint()..color = bg..style = PaintingStyle.stroke..strokeWidth = 6);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * progress, false, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(covariant _RingPainter o) => o.progress != progress;
}
