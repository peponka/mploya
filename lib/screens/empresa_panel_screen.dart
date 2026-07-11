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

/// Panel de empresa — dashboard SaaS premium (web-first).
///
/// KPIs (vacantes, postulantes, entrevistas, contratados), mejores candidatos
/// por IA (match_candidates_for_job) con match% + AI-tags, embudo de selección
/// y CTA para publicar. Usa el sistema de diseño web_ui.
class EmpresaPanelScreen extends StatefulWidget {
  const EmpresaPanelScreen({super.key});

  @override
  State<EmpresaPanelScreen> createState() => _EmpresaPanelScreenState();
}

class _EmpresaPanelScreenState extends State<EmpresaPanelScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;

  int _vacantes = 0;
  int _postulantes = 0;
  int _entrevistas = 0;
  int _contratados = 0;
  final Map<String, int> _funnel = {'applied': 0, 'interview': 0, 'offer': 0, 'hired': 0};
  List<Map<String, dynamic>> _topCandidates = [];
  String _companyName = 'tu empresa';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      // Nombre de la empresa
      try {
        final me = await _supabase.from('users').select('name').eq('id', uid).maybeSingle();
        _companyName = (me?['name'] ?? 'tu empresa').toString();
      } catch (_) {}

      // Vacantes de la empresa
      final jobs = List<Map<String, dynamic>>.from(
        await _supabase.from('jobs').select('id, title').eq('company_id', uid).order('created_at', ascending: false),
      );
      _vacantes = jobs.length;
      final jobIds = jobs.map((j) => j['id'].toString()).toList();

      // Postulaciones + embudo
      if (jobIds.isNotEmpty) {
        try {
          final apps = List<Map<String, dynamic>>.from(
            await _supabase.from('job_applications').select('status').inFilter('job_id', jobIds),
          );
          _postulantes = apps.length;
          for (final a in apps) {
            final s = (a['status'] ?? 'applied').toString();
            if (s == 'hired' || s == 'accepted') {
              _funnel['hired'] = (_funnel['hired'] ?? 0) + 1;
              _contratados++;
            } else if (s == 'offer') {
              _funnel['offer'] = (_funnel['offer'] ?? 0) + 1;
            } else if (s == 'interview') {
              _funnel['interview'] = (_funnel['interview'] ?? 0) + 1;
            }
          }
          _funnel['applied'] = _postulantes;
        } catch (_) {}

        // Entrevistas IA
        try {
          final iv = List<Map<String, dynamic>>.from(
            await _supabase.from('interviews').select('id').inFilter('job_id', jobIds),
          );
          _entrevistas = iv.length;
        } catch (_) {}

        // Mejores candidatos por IA (sobre la vacante más reciente)
        try {
          _topCandidates = await AIMatchService.instance.getCandidatesForJob(jobIds.first, limit: 5);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Panel empresa load: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _openCreate() {
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => const NuevaVacanteScreen()))
        .then((created) {
      if (created == true) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWebWide(context);
    return WebPage(
      title: 'Panel',
      subtitle: 'Hola, $_companyName. Esto pasó con tus búsquedas.',
      actions: [
        WebButton(
          icon: CupertinoIcons.rectangle_stack,
          label: 'Pipeline',
          filled: false,
          onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const AtsKanbanScreen())),
        ),
        const SizedBox(width: 10),
        WebButton(icon: CupertinoIcons.add, label: 'Nueva vacante', onTap: _openCreate),
      ],
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 4, bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── KPIs ──
                  _kpiRow(context),
                  const SizedBox(height: 18),
                  // ── Carrusel de candidatos (render #4) ──
                  if (_topCandidates.isNotEmpty) ...[
                    _carouselCard(context),
                    const SizedBox(height: 16),
                  ],
                  // ── Contenido: candidatos + (embudo / CTA) ──
                  wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _topCandidatesCard(context)),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: Column(children: [_funnelCard(context), const SizedBox(height: 16), _ctaBanner(context)])),
                          ],
                        )
                      : Column(
                          children: [
                            _topCandidatesCard(context),
                            const SizedBox(height: 16),
                            _funnelCard(context),
                            const SizedBox(height: 16),
                            _ctaBanner(context),
                          ],
                        ),
                ],
              ),
            ),
    );
  }

  Widget _kpiRow(BuildContext context) {
    final cards = [
      _kpi(context, CupertinoIcons.briefcase_fill, MployaTheme.brandAccent, '$_vacantes', 'Vacantes activas'),
      _kpi(context, CupertinoIcons.person_2_fill, kMployaBlue, '$_postulantes', 'Postulantes'),
      _kpi(context, CupertinoIcons.videocam_fill, kMployaPurple, '$_entrevistas', 'Entrevistas IA'),
      _kpi(context, CupertinoIcons.checkmark_seal_fill, const Color(0xFF0E9F6E), '$_contratados', 'Contratados'),
    ];
    final w = MediaQuery.of(context).size.width;
    final cols = w > 900 ? 4 : 2;
    return LayoutBuilder(builder: (c, cons) {
      const gap = 12.0;
      final tileW = (cons.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [for (final card in cards) SizedBox(width: tileW, child: card)]);
    });
  }

  Widget _kpi(BuildContext context, IconData icon, Color color, String value, String label) {
    return WebCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebIconBadge(icon: icon, color: color, size: 34),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(color: context.textPrimary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: context.textTertiary, fontSize: 12.5)),
        ],
      ),
    );
  }

  // Carrusel horizontal de candidatos con thumbnail + % circular (render #4).
  Widget _carouselCard(BuildContext context) {
    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(CupertinoIcons.play_rectangle_fill, color: MployaTheme.brandAccent, size: 18),
            const SizedBox(width: 8),
            Text('Carrusel de candidatos', style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('ordenados por match IA', style: TextStyle(color: context.textTertiary, fontSize: 12)),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _topCandidates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _carouselItem(context, _topCandidates[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carouselItem(BuildContext context, Map<String, dynamic> c) {
    final user = NexUser.fromJson(c);
    final pct = (c['match_percentage'] as num?)?.round() ?? 0;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: user))),
      child: SizedBox(
        width: 148,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 148, height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2A2A35), Color(0xFF14141B)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(_initials(user.name), style: const TextStyle(color: Colors.white54, fontSize: 30, fontWeight: FontWeight.w800)),
                ),
                const Positioned.fill(child: Center(child: Icon(CupertinoIcons.play_circle_fill, color: Colors.white70, size: 34))),
                // % circular
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0E9F6E), width: 2.5),
                    ),
                    alignment: Alignment.center,
                    child: Text('$pct', style: const TextStyle(color: Color(0xFF0E9F6E), fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
            if (user.headline.isNotEmpty)
              Text(user.headline, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.textTertiary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _topCandidatesCard(BuildContext context) {
    final hairline = context.dividerColor.withValues(alpha: 0.5);
    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(CupertinoIcons.sparkles, color: MployaTheme.brandAccent, size: 18),
            const SizedBox(width: 8),
            Text('Mejores candidatos por IA', style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          if (_topCandidates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Publicá una vacante para ver candidatos recomendados.',
                  textAlign: TextAlign.center, style: TextStyle(color: context.textTertiary, fontSize: 13))),
            )
          else
            ...List.generate(_topCandidates.length, (i) {
              final c = _topCandidates[i];
              final user = NexUser.fromJson(c);
              final pct = (c['match_percentage'] as num?)?.round() ?? 0;
              return Container(
                decoration: BoxDecoration(
                  border: i == _topCandidates.length - 1 ? null : Border(bottom: BorderSide(color: hairline, width: 0.5)),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: user))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(_initials(user.name), style: const TextStyle(color: MployaTheme.brandAccent, fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                              if (user.headline.isNotEmpty)
                                Text(user.headline, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: context.textTertiary, fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF0E9F6E).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                          child: Text('$pct% match', style: const TextStyle(color: Color(0xFF0E9F6E), fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _funnelCard(BuildContext context) {
    final revisados = (_funnel['applied'] ?? 0).toDouble();
    final preseleccionados = ((_funnel['interview'] ?? 0) + (_funnel['offer'] ?? 0)).toDouble();
    final contratados = (_funnel['hired'] ?? 0).toDouble();
    final has = (revisados + preseleccionados + contratados) > 0;

    Widget legend(Color color, String label, double value) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(color: context.textSecondary, fontSize: 12.5))),
            Text('${value.round()}', style: TextStyle(color: context.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        );

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estado del flujo', style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [
            SizedBox(
              width: 92, height: 92,
              child: CustomPaint(
                painter: has
                    ? _DonutPainter(
                        values: [revisados, preseleccionados, contratados],
                        colors: const [MployaTheme.brandAccent, kMployaBlue, Color(0xFF0E9F6E)],
                      )
                    : _DonutPainter(values: const [1], colors: [context.dividerColor.withValues(alpha: 0.3)]),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                children: [
                  legend(MployaTheme.brandAccent, 'Revisados', revisados),
                  legend(kMployaBlue, 'Preseleccionados', preseleccionados),
                  legend(const Color(0xFF0E9F6E), 'Contratados', contratados),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const VacantesScreen())),
            child: Row(children: [
              Text('Ver todas las vacantes', style: TextStyle(color: context.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_right, size: 13, color: context.textTertiary),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _ctaBanner(BuildContext context) {
    return GestureDetector(
      onTap: _openCreate,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: MployaTheme.brandAccent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: MployaTheme.brandAccent.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Publicá una nueva búsqueda', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('La IA la redacta por vos.', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(CupertinoIcons.sparkles, color: Color(0xFF9A3412), size: 16),
                SizedBox(width: 7),
                Text('Nueva vacante', style: TextStyle(color: Color(0xFF9A3412), fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// Donut (anillo) para el estado del flujo. Segmentos proporcionales.
class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  _DonutPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final stroke = radius * 0.32;
    final r = radius - stroke / 2;
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    double start = -1.5707963; // -90°
    for (int i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = (values[i] / total) * 6.2831853;
      final p = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), start, sweep, false, p);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.values != values || old.colors != colors;
}
