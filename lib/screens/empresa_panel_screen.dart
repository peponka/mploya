import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/web_ui.dart';
import '../widgets/mploya_toast.dart';
import '../services/ai_match_service.dart';
import 'nueva_vacante_screen.dart';
import 'vacantes_screen.dart';

/// Panel de empresa — dashboard SaaS premium nivel inversor.
/// `embedded` = true cuando se muestra dentro del hub "Panel" (sin su propio
/// WebPage/título, porque el hub ya los provee).
class EmpresaPanelScreen extends StatefulWidget {
  final bool embedded;
  const EmpresaPanelScreen({super.key, this.embedded = false});
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

  @override
  Widget build(BuildContext context) {
    final content = _loading
        ? const Center(child: CupertinoActivityIndicator())
        : FadeTransition(
            opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Rediseño 23/7: Resumen a base de cards (KPIs 2x2, embudo,
                // match del día, insight IA). El pipeline/candidatos viven en la
                // pestaña "Pipeline" del hub.
                _kpiGrid(context),
                const SizedBox(height: 16),
                _embudoCard(context),
                const SizedBox(height: 16),
                _matchDelDiaCard(context),
                const SizedBox(height: 16),
                _insightBanner(context),
              ]),
            ),
          );

    // Dentro del hub "Panel": sin WebPage/título propio (los provee el hub).
    if (widget.embedded) return content;

    return WebPage(
      title: 'Panel',
      subtitle: 'Hola, $_companyName. Gestioná candidatos, contactos y vía rápida confidencial.',
      actions: [
        _pill(context, CupertinoIcons.chart_bar_fill, 'Vacantes', false, () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const VacantesScreen()))),
        const SizedBox(width: 8),
        _pill(context, CupertinoIcons.add, 'Nueva vacante', true, _openCreate),
      ],
      child: content,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  REDISEÑO 23/7 — Resumen a base de cards
  // ═══════════════════════════════════════════════════════════════════════════

  static const _brand = Color(0xFF185FA5);
  static const _brandTint = Color(0xFFE6F1FB);
  static const _brandDeep = Color(0xFF0C447C);

  Widget _kpiGrid(BuildContext ctx) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _metricCard(ctx, CupertinoIcons.person_badge_plus_fill, '$_postulantes', 'Nuevos postulantes', '+12%')),
          const SizedBox(width: 10),
          Expanded(child: _metricCard(ctx, CupertinoIcons.tray_fill, '$_entrevistas', 'Acciones pendientes', '+5%')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _metricCard(ctx, CupertinoIcons.bolt_fill, '$_contratados', 'Contactos directos', '+8%')),
          const SizedBox(width: 10),
          Expanded(child: _metricCard(ctx, CupertinoIcons.lock_fill, '5', 'Créditos confidenciales', 'Premium', premium: true)),
        ]),
      ],
    );
  }

  Widget _metricCard(BuildContext ctx, IconData icon, String value, String label, String trend, {bool premium = false}) {
    final tintBg = premium ? const Color(0xFFFAEEDA) : _brandTint;
    final iconColor = premium ? const Color(0xFF854F0B) : _brand;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ctx.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ctx.dividerColor.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: tintBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              Text(trend, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: premium ? const Color(0xFF854F0B) : const Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ctx.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: ctx.textTertiary)),
        ],
      ),
    );
  }

  Widget _embudoCard(BuildContext ctx) {
    final applied = (_funnel['applied'] ?? 47).clamp(1, 9999);
    final fav = (_funnel['interview'] ?? 18).clamp(0, 9999);
    final ok = (_funnel['offer'] ?? 9).clamp(0, 9999);
    final hired = (_funnel['hired'] ?? 4).clamp(0, 9999);
    Widget seg(int flex, Color c) => flex <= 0 ? const SizedBox.shrink() : Expanded(flex: flex, child: Container(color: c));
    Widget leg(Color c, String t, int n) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text('$t $n', style: TextStyle(fontSize: 11.5, color: ctx.textSecondary)),
        ]);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ctx.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ctx.dividerColor.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Embudo de contratación', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ctx.textPrimary)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(height: 10, child: Row(children: [
            seg(applied, _brand),
            seg(fav, const Color(0xFFEF9F27)),
            seg(ok, const Color(0xFF378ADD)),
            seg(hired, const Color(0xFF1D9E75)),
          ])),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 8, children: [
          leg(_brand, 'Postulantes', applied),
          leg(const Color(0xFFEF9F27), 'Favoritos', fav),
          leg(const Color(0xFF378ADD), 'Exitosos', ok),
          leg(const Color(0xFF1D9E75), 'Contratados', hired),
        ]),
      ]),
    );
  }

  Widget _matchDelDiaCard(BuildContext ctx) {
    final useDemo = _topCandidates.isEmpty;
    final name = useDemo ? _dN[0] : (_topCandidates[0]['name']?.toString() ?? 'Candidato');
    final hl = useDemo ? _dH[0] : (_topCandidates[0]['headline']?.toString() ?? '');
    final match = useDemo ? _dM[0] : (((_topCandidates[0]['match_percentage'] as num?)?.round()) ?? 90);
    final skills = useDemo ? _dS[0] : (((_topCandidates[0]['skills'] as List?)?.map((e) => e.toString()).toList()) ?? const <String>[]);
    final initials = name.trim().isNotEmpty ? name.trim().split(' ').map((w) => w.isEmpty ? '' : w[0]).take(2).join().toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ctx.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ctx.dividerColor.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _brandTint, borderRadius: BorderRadius.circular(14)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(CupertinoIcons.rosette, size: 13, color: _brand),
              SizedBox(width: 4),
              Text('Match del día', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brandDeep)),
            ]),
          ),
          Text('Recomendado por IA', style: TextStyle(fontSize: 12, color: ctx.textTertiary)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _brandTint),
            alignment: Alignment.center,
            child: Text(initials, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _brandDeep)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ctx.textPrimary)),
            const SizedBox(height: 2),
            Text(hl, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: ctx.textTertiary)),
          ])),
          Column(children: [
            Text('$match%', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: _brand)),
            Text('match', style: TextStyle(fontSize: 10, color: ctx.textTertiary)),
          ]),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: skills.take(3).map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: _brandTint, borderRadius: BorderRadius.circular(13)),
          child: Text(s, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _brandDeep)),
        )).toList()),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => MployaToast.info(ctx, 'Abriendo el video de $name'),
            child: Container(
              height: 38,
              decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('Ver video', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white))),
            ),
          )),
          const SizedBox(width: 8),
          _miniAction(ctx, CupertinoIcons.calendar, () => MployaToast.info(ctx, 'Agendar entrevista con $name')),
          const SizedBox(width: 8),
          _miniAction(ctx, CupertinoIcons.chat_bubble_2, () => MployaToast.info(ctx, 'Chat con $name')),
        ]),
      ]),
    );
  }

  Widget _miniAction(BuildContext ctx, IconData icon, VoidCallback onTap) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        width: 44, height: 38,
        decoration: BoxDecoration(
          color: ctx.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ctx.dividerColor.withValues(alpha: 0.5), width: 0.5),
        ),
        child: Icon(icon, size: 17, color: ctx.textSecondary),
      ),
    );
  }

  Widget _insightBanner(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _brandTint, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(8)),
          child: const Icon(CupertinoIcons.sparkles, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Insight IA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _brandDeep)),
          SizedBox(height: 2),
          Text('Tenés 3 candidatos con +95% de match esperando respuesta. Los perfiles con video se contratan 4.2x más.',
              style: TextStyle(fontSize: 12.5, color: _brandDeep, height: 1.5)),
        ])),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _pill(BuildContext ctx, IconData ic, String label, bool filled, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      height: 42, padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: filled ? null : ctx.cardColor,
        gradient: filled ? const LinearGradient(colors: [Color(0xFF185FA5), Color(0xFF378ADD)]) : null,
        borderRadius: BorderRadius.circular(999),
        border: filled ? null : Border.all(color: ctx.dividerColor.withValues(alpha: 0.5)),
        boxShadow: filled ? [BoxShadow(color: const Color(0xFF185FA5).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 5))] : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 16, color: filled ? Colors.white : ctx.textSecondary),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(color: filled ? Colors.white : ctx.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
      ]),
    ));
  }

}

