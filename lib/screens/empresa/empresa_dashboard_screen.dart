import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import 'empresa_actividad_screen.dart';
import 'empresa_dashboard_data.dart';
import 'empresa_entrevistas_screen.dart';
import 'empresa_mensajes_screen.dart';
import 'empresa_pipeline_screen.dart';
import 'empresa_publicar_vacante_screen.dart';
import 'empresa_rendimiento_screen.dart';
import 'empresa_talent_feed_screen.dart';
import 'empresa_vacantes_screen.dart';

/// Dashboard de Empresa.
///
/// RECONSTRUIDO desde `dashboard empresa.png` (09. Dashboard Empresa).
/// La composición nace del PNG, no de la pantalla anterior.
///
/// Orden exacto del mockup, de arriba hacia abajo:
///   1. Saludo "Hola, {empresa} 👋" + subtítulo, campana suelta con badge
///   2. Cuatro KPI en una fila: ícono tenue, número grande, etiqueta 2 líneas, enlace
///   3. "Pipeline general" + enlace  →  tarjeta de 5 etapas con chevrons,
///      barra de píldoras y porcentajes
///   4. "Rendimiento" + selector de período  →  DOS tarjetas lado a lado
///   5. "Evolución de contrataciones" con eje y curva
///   6. "Accesos rápidos": 5 tarjetas, sólo la primera con círculo relleno
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// Auditada y contenida el 12/8/2026. El KPI dice "Ofertas aceptadas" porque
/// eso es lo que cuenta (`job_applications.status = accepted`): el sistema no
/// puede registrar contrataciones. El embudo ATS, la evolución de
/// contrataciones, las fuentes y los tiempos por etapa están OCULTOS porque su
/// backend no existe o es semánticamente inconfiable. Queda más corto que el
/// mockup, y es a propósito.
///
class EmpresaDashboardScreen extends StatefulWidget {
  final int unreadNotifications;

  /// Datos ya resueltos. Sirve para renderizar la pantalla sin backend
  /// (comparación visual contra el PNG en los golden tests). En producción va
  /// nulo y los datos se cargan de Supabase.
  final EmpresaDashboardData? previewData;

  const EmpresaDashboardScreen({
    super.key,
    this.unreadNotifications = 0,
    this.previewData,
  });

  @override
  State<EmpresaDashboardScreen> createState() => _EmpresaDashboardScreenState();
}

class _EmpresaDashboardScreenState extends State<EmpresaDashboardScreen> {
  EmpresaDashboardData _data = EmpresaDashboardData.empty;
  bool _loading = true;
  String _period = 'Este mes';

  /// Colores de las 5 etapas del embudo, en el orden del mockup.
  static const _stageColors = <Color>[
    MpTokens.primary,
    MpTokens.catBlue,
    MpTokens.catOrange,
    MpTokens.catGreen,
    Color(0xFF4ADE80),
  ];

  static const _stageIcons = <IconData>[
    CupertinoIcons.doc_text,
    CupertinoIcons.search,
    CupertinoIcons.person_2,
    CupertinoIcons.check_mark_circled,
    CupertinoIcons.person_badge_plus,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.previewData != null) {
      _data = widget.previewData!;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (widget.previewData != null) return;
    if (!mounted) return;
    setState(() => _loading = true);
    final data = await loadEmpresaDashboard();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  void _push(Widget screen) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => screen));
  }

  Future<void> _pickPeriod() async {
    const options = ['Esta semana', 'Este mes', 'Este trimestre', 'Este año'];
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Período'),
        actions: [
          for (final option in options)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                setState(() => _period = option);
              },
              child: Text(option),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancelar'),
        ),
      ),
    );
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
                        // En escritorio la MISMA composición, centrada y con
                        // más aire. No se convierte en otro dashboard.
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
        _greeting(wide),
        SizedBox(height: wide ? MpTokens.space24 : MpTokens.space20),
        _kpiRow(wide),
        SizedBox(height: wide ? MpTokens.space32 : MpTokens.space24),
        // PIPELINE GENERAL — oculto mientras el pipeline ATS no esté soportado
        // de punta a punta. El embudo mezclaba etapas confiables
        // (`job_applications`) con una que no lo es: "Contratados" leía
        // `ats_status = 'hired'`, un valor que ninguna ruta productiva escribe.
        // Un embudo con una etapa muerta no es "casi correcto": sus porcentajes
        // salen mal enteros. En producción `funnel` viene vacío y este bloque
        // no se dibuja.
        if (_data.hasFunnel) ...[
          _sectionTitle('Pipeline general', 'Ver pipeline completo',
              () => _push(const EmpresaPipelineScreen())),
          const SizedBox(height: MpTokens.space12),
          _pipelineCard(wide),
          SizedBox(height: wide ? MpTokens.space32 : MpTokens.space24),
        ],
        _performanceHeader(),
        const SizedBox(height: MpTokens.space12),
        // Las dos tarjetas van LADO A LADO también en móvil: así está el PNG.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _sourcesCard(wide)),
              SizedBox(width: wide ? MpTokens.space16 : MpTokens.space12),
              Expanded(child: _stageTimeCard(wide)),
            ],
          ),
        ),
        SizedBox(height: wide ? MpTokens.space16 : MpTokens.space12),
        _trendCard(wide),
        SizedBox(height: wide ? MpTokens.space32 : MpTokens.space24),
        _quickActions(wide),
      ],
    );
  }

  // ── 1. Saludo ─────────────────────────────────────────────────────────────

  Widget _greeting(bool wide) {
    final s = context.mp;
    final name = _data.companyName.isEmpty ? 'tu empresa' : _data.companyName;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, $name 👋',
                style: MpTokens.h1.copyWith(
                  color: s.text,
                  fontSize: wide ? 30 : 26,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: MpTokens.space4),
              Text(
                'Así va tu proceso de contratación',
                style: MpTokens.body.copyWith(
                  color: s.textSecondary,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: MpTokens.space12),
        // Campana SUELTA: en el mockup no tiene contenedor ni fondo.
        GestureDetector(
          onTap: () => _push(const EmpresaActividadScreen()),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(top: 2, right: 2),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(CupertinoIcons.bell, size: 27, color: s.text),
                if (widget.unreadNotifications > 0)
                  Positioned(
                    top: -8,
                    right: -9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      constraints: const BoxConstraints(minWidth: 22),
                      decoration: BoxDecoration(
                        color: MpTokens.primary,
                        borderRadius: BorderRadius.circular(
                          MpTokens.radiusPill,
                        ),
                        border: Border.all(color: s.bg, width: 2),
                      ),
                      child: Text(
                        '${widget.unreadNotifications}',
                        textAlign: TextAlign.center,
                        style: MpTokens.micro.copyWith(
                          color: const Color(0xFFFFFFFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 2. KPIs ───────────────────────────────────────────────────────────────

  Widget _kpiRow(bool wide) {
    final kpis = <_Kpi>[
      _Kpi(
        icon: CupertinoIcons.briefcase,
        color: MpTokens.primary,
        value: _data.vacantesActivas,
        label: 'Vacantes\nactivas',
        link: 'Ver todas',
        onTap: () => _push(const EmpresaVacantesScreen()),
      ),
      _Kpi(
        icon: CupertinoIcons.person_2,
        color: MpTokens.catGreen,
        value: _data.candidatosEnProceso,
        label: 'Candidatos\nen proceso',
        link: 'Ver pipeline',
        onTap: () => _push(const EmpresaPipelineScreen()),
      ),
      _Kpi(
        icon: CupertinoIcons.calendar,
        color: MpTokens.catOrange,
        value: _data.entrevistasSemana,
        label: 'Entrevistas\nesta semana',
        link: 'Ver agenda',
        onTap: () => _push(const EmpresaEntrevistasScreen()),
      ),
      _Kpi(
        icon: CupertinoIcons.check_mark_circled,
        color: MpTokens.catBlue,
        value: _data.contratacionesMes,
        // `accepted` de job_applications. NO es una contratación: el sistema
        // todavía no puede registrar contrataciones.
        label: 'Ofertas\naceptadas',
        link: 'Ver informes',
        onTap: () => _push(const EmpresaRendimientoScreen()),
      ),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < kpis.length; i++) ...[
            if (i > 0)
              SizedBox(width: wide ? MpTokens.space16 : MpTokens.space8),
            Expanded(child: _kpiCard(kpis[i], wide)),
          ],
        ],
      ),
    );
  }

  Widget _kpiCard(_Kpi kpi, bool wide) {
    final s = context.mp;

    return MpCard(
      onTap: kpi.onTap,
      radius: MpTokens.radiusXL,
      padding: EdgeInsets.all(wide ? MpTokens.space20 : MpTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ícono de contorno sobre un cuadrado de tinte MUY tenue.
          Container(
            width: wide ? 46 : 40,
            height: wide ? 46 : 40,
            decoration: BoxDecoration(
              color: kpi.color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(MpTokens.radiusSM),
            ),
            child: Icon(kpi.icon, size: wide ? 24 : 21, color: kpi.color),
          ),
          SizedBox(height: wide ? MpTokens.space16 : MpTokens.space12),
          // El número es el elemento dominante de la tarjeta.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${kpi.value}',
              style: MpTokens.stat.copyWith(
                color: s.text,
                fontSize: wide ? 38 : 30,
                letterSpacing: -1.4,
              ),
            ),
          ),
          SizedBox(height: wide ? MpTokens.space8 : 6),
          // FittedBox y no wrap: con cuatro tarjetas en 393pt, "Contrataciones"
          // no entra y el wrap la partía a mitad de palabra ("Contratac /
          // iones"). Encogerla mantiene las dos líneas del mockup.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              kpi.label,
              style: MpTokens.body.copyWith(
                color: s.text,
                fontSize: wide ? 14.5 : 12.5,
                height: 1.28,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          SizedBox(height: wide ? MpTokens.space16 : MpTokens.space12),
          // El enlace se lee entero ("Ver pipeline", no "Ver pipel…").
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              kpi.link,
              maxLines: 1,
              style: MpTokens.label.copyWith(
                color: MpTokens.primary,
                fontSize: wide ? 14 : 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Encabezado de sección ─────────────────────────────────────────────────

  Widget _sectionTitle(String title, String? action, VoidCallback? onAction) {
    final s = context.mp;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: MpTokens.h2.copyWith(color: s.text, fontSize: 19),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Text(
              action,
              style: MpTokens.label.copyWith(
                color: MpTokens.primary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  // ── 3. Pipeline ───────────────────────────────────────────────────────────

  Widget _pipelineCard(bool wide) {
    final s = context.mp;
    final stages = _data.funnel;
    final total = stages.isEmpty ? 0 : stages.first.value;

    return MpCard(
      radius: MpTokens.radiusXL,
      padding: EdgeInsets.symmetric(
        horizontal: wide ? MpTokens.space24 : MpTokens.space12,
        vertical: wide ? MpTokens.space24 : MpTokens.space20,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < stages.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: Icon(
                      CupertinoIcons.chevron_right,
                      size: 12,
                      color: s.textTertiary,
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      // Ícono de contorno SIN fondo: así está en el mockup.
                      Icon(
                        _stageIcons[i],
                        size: wide ? 26 : 22,
                        color: _stageColors[i],
                      ),
                      SizedBox(height: wide ? MpTokens.space12 : MpTokens.space8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${stages[i].value}',
                          style: MpTokens.stat.copyWith(
                            color: s.text,
                            fontSize: wide ? 24 : 19,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          stages[i].label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: MpTokens.caption.copyWith(
                            color: s.textSecondary,
                            fontSize: wide ? 13 : 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: wide ? MpTokens.space20 : MpTokens.space16),
          // En el mockup los tramos son de ancho PAREJO: la barra ordena las
          // etapas y el dato cuantitativo lo llevan los porcentajes de abajo.
          // Una etapa sin movimiento no ocupa tramo y deja cola gris.
          MpFunnelBar(
            height: wide ? 10 : 8,
            segments: [
              for (var i = 0; i < stages.length; i++)
                if (stages[i].value > 0)
                  MpFunnelSegment(
                    fraction: 1 / stages.length,
                    color: _stageColors[i],
                  ),
            ],
          ),
          SizedBox(height: wide ? MpTokens.space12 : MpTokens.space8),
          Row(
            children: [
              for (var i = 0; i < stages.length; i++)
                Expanded(
                  child: Text(
                    total <= 0
                        ? '0%'
                        : '${(stages[i].value / total * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: MpTokens.caption.copyWith(
                      color: s.textSecondary,
                      fontSize: wide ? 13 : 11,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 4. Rendimiento ────────────────────────────────────────────────────────

  Widget _performanceHeader() {
    final s = context.mp;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Rendimiento',
            style: MpTokens.h2.copyWith(color: s.text, fontSize: 19),
          ),
        ),
        GestureDetector(
          onTap: _pickPeriod,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: s.card,
              borderRadius: BorderRadius.circular(MpTokens.radiusMD),
              border: Border.all(color: s.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.briefcase, size: 15, color: s.text),
                const SizedBox(width: 7),
                Text(
                  _period,
                  style: MpTokens.label.copyWith(color: s.text, fontSize: 13),
                ),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 12,
                  color: s.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _perfCard(bool wide, String title, Widget child) {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusXL,
      padding: EdgeInsets.all(wide ? MpTokens.space20 : MpTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MpTokens.title.copyWith(
              color: s.text,
              fontSize: wide ? 16 : 13.5,
            ),
          ),
          SizedBox(height: wide ? MpTokens.space16 : MpTokens.space12),
          child,
        ],
      ),
    );
  }

  Widget _sourcesCard(bool wide) {
    return _perfCard(
      wide,
      'Fuentes de candidatos',
      _data.hasSources
          ? MpDonutChart(
              size: wide ? 130 : 62,
              thickness: wide ? 26 : 14,
              compact: !wide,
              slices: [
                for (var i = 0; i < _data.sources.length; i++)
                  MpDonutSlice(
                    label: _data.sources[i].label,
                    value: _data.sources[i].value.toDouble(),
                    color: _stageColors[i % _stageColors.length],
                  ),
              ],
            )
          : _noData(
              wide,
              CupertinoIcons.chart_pie,
              'Todavía no registramos el origen de cada postulación.',
            ),
    );
  }

  Widget _stageTimeCard(bool wide) {
    final s = context.mp;

    return _perfCard(
      wide,
      'Tiempo promedio por etapa',
      _data.hasStageDays
          ? Column(
              children: [
                for (final entry in _data.stageDays.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MpTokens.space12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: MpTokens.caption.copyWith(
                                  color: s.text,
                                  fontSize: wide ? 13.5 : 11.5,
                                ),
                              ),
                            ),
                            Text(
                              '${entry.value.toStringAsFixed(1)} días',
                              style: MpTokens.caption.copyWith(
                                color: s.text,
                                fontSize: wide ? 13.5 : 11.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        MpProgressBar(value: (entry.value / 10).clamp(0, 1)),
                      ],
                    ),
                  ),
              ],
            )
          : _noData(
              wide,
              CupertinoIcons.time,
              'Necesitamos más movimientos en el pipeline para calcularlo.',
            ),
    );
  }

  /// Vacío compacto: mantiene la altura del bloque sin romper la composición.
  Widget _noData(bool wide, IconData icon, String message) {
    final s = context.mp;

    return SizedBox(
      height: wide ? 150 : 118,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: wide ? 26 : 22, color: s.textTertiary),
          const SizedBox(height: MpTokens.space8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: MpTokens.caption.copyWith(
              color: s.textTertiary,
              fontSize: wide ? 12.5 : 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Evolución ──────────────────────────────────────────────────────────

  Widget _trendCard(bool wide) {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusXL,
      padding: EdgeInsets.all(wide ? MpTokens.space20 : MpTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evolución de contrataciones',
            style: MpTokens.title.copyWith(
              color: s.text,
              fontSize: wide ? 16 : 15,
            ),
          ),
          SizedBox(height: wide ? MpTokens.space20 : MpTokens.space16),
          if (!_data.hasTrend)
            _noData(
              wide,
              CupertinoIcons.graph_square,
              'Sin contrataciones registradas en los últimos 6 meses.',
            )
          else
            MpLineChart(
              showPointValues: true,
              showAxis: true,
              height: wide ? 200 : 150,
              labels: [for (final point in _data.hiringTrend) point.label],
              series: [
                MpLineSeries(
                  values: [for (final p in _data.hiringTrend) p.value],
                  color: MpTokens.primary,
                  filled: true,
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── 6. Accesos rápidos ────────────────────────────────────────────────────

  Widget _quickActions(bool wide) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: CupertinoIcons.add,
        label: 'Publicar\nvacante',
        color: MpTokens.primary,
        // Sólo la primera lleva círculo relleno, como en el mockup.
        solid: true,
        onTap: () => _push(const EmpresaPublicarVacanteScreen()),
      ),
      _QuickAction(
        icon: CupertinoIcons.person_2,
        label: 'Buscar\ncandidatos',
        color: MpTokens.catBlue,
        onTap: () => _push(const EmpresaTalentFeedScreen()),
      ),
      _QuickAction(
        icon: CupertinoIcons.calendar,
        label: 'Agenda de\nentrevistas',
        color: MpTokens.catOrange,
        onTap: () => _push(const EmpresaEntrevistasScreen()),
      ),
      _QuickAction(
        icon: CupertinoIcons.chart_bar_alt_fill,
        label: 'Informes y\nmétricas',
        color: MpTokens.catGreen,
        onTap: () => _push(const EmpresaRendimientoScreen()),
      ),
      _QuickAction(
        icon: CupertinoIcons.chat_bubble_2,
        label: 'Mensajes\nrecientes',
        color: MpTokens.primary,
        onTap: () => _push(const EmpresaMensajesScreen()),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Accesos rápidos', null, null),
        const SizedBox(height: MpTokens.space12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0)
                  SizedBox(width: wide ? MpTokens.space16 : MpTokens.space8),
                Expanded(child: _quickActionCard(actions[i], wide)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickActionCard(_QuickAction action, bool wide) {
    final s = context.mp;

    return MpCard(
      onTap: action.onTap,
      radius: MpTokens.radiusLG,
      padding: EdgeInsets.symmetric(
        horizontal: MpTokens.space4,
        vertical: wide ? MpTokens.space20 : MpTokens.space16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (action.solid)
            Container(
              width: wide ? 44 : 36,
              height: wide ? 44 : 36,
              decoration: BoxDecoration(
                color: action.color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                action.icon,
                size: wide ? 24 : 20,
                color: const Color(0xFFFFFFFF),
              ),
            )
          else
            // Ícono desnudo, sin fondo: así están las otras cuatro.
            SizedBox(
              width: wide ? 44 : 36,
              height: wide ? 44 : 36,
              child: Icon(
                action.icon,
                size: wide ? 27 : 24,
                color: action.color,
              ),
            ),
          SizedBox(height: wide ? MpTokens.space12 : MpTokens.space8),
          // Mismo motivo que en los KPI: "entrevistas" no entra en 1/5 del
          // ancho y se partía. Se encoge en vez de romperse.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              action.label,
              textAlign: TextAlign.center,
              style: MpTokens.caption.copyWith(
                color: s.text,
                fontSize: wide ? 13.5 : 11,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi {
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  final String link;
  final VoidCallback onTap;

  const _Kpi({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.link,
    required this.onTap,
  });
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool solid;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.solid = false,
  });
}
