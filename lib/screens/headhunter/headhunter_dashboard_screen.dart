import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/ds/mploya_ds.dart';
import '../../services/my_profile_service.dart';
import 'headhunter_analytics_screen.dart';
import 'headhunter_interviews_screen.dart';

/// Dashboard de Headhunter.
///
/// RECONSTRUIDO contra `headhunter dashboard.png`, primera pantalla migrada
/// al sistema de diseño (18/8/2026) — el resto de las 8 pantallas medianas
/// de Headhunter deberían copiar este mismo patrón en vez de remapear
/// widget por widget:
///
///   · Banda hero          → [MpHeroBand] + [MpHeroMetric] (violeta,
///     `MpTokens.heroGradient`, ya trae el degradado y los divisores).
///   · Grilla de stats      → [MpStatTile] (ícono + número grande + label +
///     enlace opcional). Este widget ya estaba documentado contra ESTE
///     mockup antes de este cambio (ver el doc-comment de la clase).
///   · Encabezado de sección → [MpSectionHeader].
///   · Lista de vacantes    → [MpRowGroup] de [MpListRow] (leading
///     [MpIconTile], sin chevron: no hay pantalla de detalle de vacante
///     para Headhunter todavía).
///   · Estado vacío inline  → tarjeta compacta ([MpCard] + [MpIconTile]
///     circular + texto), NO [MpEmptyState] (ese widget es para vacíos de
///     pantalla completa; acá es un bloque más dentro de una lista).
///
/// DIFERENCIAS DELIBERADAS CONTRA EL MOCKUP (dato real no alcanza, no se
/// inventa — misma regla que Empresa):
///   · El mockup muestra 6 tarjetas en la grilla ("Clientes activos",
///     "Shortlists enviadas", etc.). Se dibujan 3: Vacantes publicadas,
///     Entrevistas, Colocaciones (con enlace a Analytics, agregado el
///     19/8 cuando se construyó `headhunter_analytics_screen.dart`). Las
///     otras 3 dependen de conceptos que no tienen una cifra propia
///     todavía — "Shortlists enviadas" existe como feature pero no como
///     conteo agregado en el dashboard, y un conteo de "candidatos en
///     proceso" DISTINTO de "candidatos presentados" sería el mismo dato
///     real, `_applications.length`, así que se muestra una sola vez, en
///     la banda hero, y no se duplica en la grilla con otra etiqueta. Un
///     test existente (`dashboard muestra sólo conteos derivados`) frenó
///     exactamente ese intento la primera vez).
///   · Los deltas ("+2 vs. semana pasada") del mockup no se muestran: no
///     hay dato de período anterior sin agregar una consulta nueva, y este
///     cambio es sólo visual.
///   · El selector de rango de fechas ("12 – 18 May, 2025") del mockup no
///     se implementó: no filtra nada hoy en el equivalente de Empresa
///     tampoco (ver `_pickPeriod` en `empresa_dashboard_screen.dart`, es
///     cosmético) y agregarlo acá sería UI nueva sin dato real detrás.
///   · "Entrevistas" quedó con enlace ("Ver agenda") porque apunta a una
///     pantalla de Headhunter que ya existe — mismo patrón que los KPI de
///     `empresa_dashboard_screen.dart`. "Vacantes publicadas" quedó sin
///     enlace: no hay una pantalla de "mis vacantes" propia de Headhunter
///     todavía.
class HeadhunterDashboardData {
  const HeadhunterDashboardData({
    this.name = '',
    this.jobs = const [],
    this.applications = const [],
    this.interviews = const [],
  });

  final String name;
  final List<Map<String, dynamic>> jobs;
  final List<Map<String, dynamic>> applications;
  final List<Map<String, dynamic>> interviews;
}

class HeadhunterDashboardScreen extends StatefulWidget {
  const HeadhunterDashboardScreen({super.key, this.previewData});

  final HeadhunterDashboardData? previewData;

  @override
  State<HeadhunterDashboardScreen> createState() =>
      _HeadhunterDashboardScreenState();
}

class _HeadhunterDashboardScreenState extends State<HeadhunterDashboardScreen> {
  bool _loading = true;
  String _name = '';
  List<Map<String, dynamic>> _jobs = const [];
  List<Map<String, dynamic>> _applications = const [];
  List<Map<String, dynamic>> _interviews = const [];

  @override
  void initState() {
    super.initState();
    final preview = widget.previewData;
    if (preview != null) {
      _assign(preview);
      _loading = false;
    } else {
      _load();
    }
  }

  void _assign(HeadhunterDashboardData data) {
    _name = data.name;
    _jobs = data.jobs;
    _applications = data.applications;
    _interviews = data.interviews;
  }

  Future<void> _load() async {
    if (widget.previewData != null) return;
    final db = Supabase.instance.client;
    final uid = db.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final me = await loadMyProfile(client: db);
      final jobs = List<Map<String, dynamic>>.from(
        await db
            .from('jobs')
            .select('id, title, search_status, created_at')
            .eq('company_id', uid)
            .order('created_at', ascending: false),
      );
      final ids = jobs.map((row) => row['id'].toString()).toList();
      final applications = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await db
                  .from('job_applications')
                  .select('job_id, status')
                  .inFilter('job_id', ids),
            );
      final interviews = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await db
                  .from('interviews')
                  .select('id, job_id, status')
                  .inFilter('job_id', ids),
            );
      if (!mounted) return;
      setState(() {
        _assign(
          HeadhunterDashboardData(
            name: me?['name']?.toString() ?? '',
            jobs: jobs,
            applications: applications,
            interviews: interviews,
          ),
        );
        _loading = false;
      });
    } catch (error) {
      debugPrint('Headhunter dashboard: $error');
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _hired => _applications.where((row) {
    final status = row['status']?.toString().toLowerCase();
    return status == 'hired' || status == 'accepted';
  }).length;

  /// Búsquedas abiertas. `jobs.search_status` es la columna real (migración
  /// 042; no existe `jobs.status`, y `is_active`/`paused_at` no alcanzan
  /// para distinguir Abierta/En proceso/En pausa/Cerrada).
  int get _activeJobs =>
      _jobs.where((row) => row['search_status'] == 'abierta').length;

  void _push(Widget screen) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final wide = mpIsWide(context);

    return MpSurface(
      style: MpSurfaceStyle.light,
      child: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 15))
            : CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _load),
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: wide ? 1180 : double.infinity,
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            wide ? MpTokens.space32 : MpTokens.screenPadding,
                            MpTokens.space8,
                            wide ? MpTokens.space32 : MpTokens.screenPadding,
                            MpTokens.space32,
                          ),
                          child: _content(wide),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _content(bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _greeting(),
        SizedBox(height: wide ? MpTokens.space24 : MpTokens.space20),
        _heroBand(),
        SizedBox(height: wide ? MpTokens.space32 : MpTokens.space24),
        const MpSectionHeader(title: 'Resumen general'),
        const SizedBox(height: MpTokens.space12),
        _statGrid(wide),
        SizedBox(height: wide ? MpTokens.space32 : MpTokens.space24),
        const MpSectionHeader(title: 'Vacantes recientes'),
        const SizedBox(height: MpTokens.space12),
        _recentJobs(),
      ],
    );
  }

  // ── Saludo ────────────────────────────────────────────────────────────────

  Widget _greeting() {
    final s = context.mp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _name.trim().isEmpty ? 'Hola 👋' : 'Hola, ${_name.trim()} 👋',
          style: MpTokens.h1.copyWith(color: s.text, letterSpacing: -1.0),
        ),
        const SizedBox(height: MpTokens.space4),
        Text(
          'Bienvenido a tu dashboard Headhunter',
          style: MpTokens.body.copyWith(color: s.textSecondary),
        ),
      ],
    );
  }

  // ── Banda hero ────────────────────────────────────────────────────────────

  Widget _heroBand() {
    return MpHeroBand(
      metrics: [
        MpHeroMetric(
          icon: CupertinoIcons.briefcase,
          label: 'Búsquedas\nactivas',
          value: '$_activeJobs',
        ),
        MpHeroMetric(
          icon: CupertinoIcons.person_2,
          label: 'Candidatos\npresentados',
          value: '${_applications.length}',
        ),
        MpHeroMetric(
          icon: CupertinoIcons.checkmark_alt_circle,
          label: 'Colocaciones',
          value: '$_hired',
        ),
      ],
    );
  }

  // ── Grilla de stats ───────────────────────────────────────────────────────

  Widget _statGrid(bool wide) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MpStatTile(
              icon: CupertinoIcons.briefcase_fill,
              color: MpTokens.primary,
              value: '${_jobs.length}',
              label: 'Vacantes\npublicadas',
              compact: !wide,
            ),
          ),
          SizedBox(width: wide ? MpTokens.space16 : MpTokens.space8),
          Expanded(
            child: MpStatTile(
              icon: CupertinoIcons.calendar,
              // ADENDA 11/9/2026: mismo criterio que ya se aplicó en
              // Empresa (ver `_kpiRow` en empresa_dashboard_screen.dart y
              // `_metrica` en empresa_vacantes_screen.dart) — tres métricas
              // del mismo tipo (contadores lado a lado) usan un único acento
              // violeta en vez de un color distinto por tarjeta sin ningún
              // significado detrás.
              color: MpTokens.primary,
              value: '${_interviews.length}',
              label: 'Entrevistas',
              linkLabel: 'Ver agenda',
              onLinkTap: () => _push(const HeadhunterInterviewsScreen()),
              compact: !wide,
            ),
          ),
          SizedBox(width: wide ? MpTokens.space16 : MpTokens.space8),
          Expanded(
            child: MpStatTile(
              icon: CupertinoIcons.checkmark_alt_circle,
              color: MpTokens.primary,
              value: '$_hired',
              label: 'Colocaciones',
              linkLabel: 'Ver analytics',
              onLinkTap: () => _push(const HeadhunterAnalyticsScreen()),
              compact: !wide,
            ),
          ),
        ],
      ),
    );
  }

  // ── Vacantes recientes ────────────────────────────────────────────────────

  Widget _recentJobs() {
    if (_jobs.isEmpty) return _emptyJobsCard();

    return MpRowGroup(
      rows: [
        for (final job in _jobs.take(4))
          MpListRow(
            leading: const MpIconTile(
              icon: CupertinoIcons.briefcase_fill,
              color: MpTokens.primary,
              size: 36,
            ),
            title: job['title']?.toString().trim().isNotEmpty == true
                ? job['title'].toString()
                : 'Vacante sin título',
            showChevron: false,
          ),
      ],
    );
  }

  Widget _emptyJobsCard() {
    final s = context.mp;
    return MpCard(
      padding: const EdgeInsets.symmetric(
        horizontal: MpTokens.space16,
        vertical: MpTokens.space24,
      ),
      child: Column(
        children: [
          MpIconTile(
            icon: CupertinoIcons.briefcase,
            color: s.textTertiary,
            size: 40,
            circular: true,
          ),
          const SizedBox(height: MpTokens.space12),
          Text(
            'Todavía no publicaste vacantes',
            style: MpTokens.title.copyWith(color: s.text),
          ),
        ],
      ),
    );
  }
}
