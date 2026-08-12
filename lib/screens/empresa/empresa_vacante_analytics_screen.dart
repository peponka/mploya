import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import 'empresa_vacante_analytics_data.dart';
import 'empresa_vacantes_data.dart';

/// Analytics de UNA vacante (Empresa móvil).
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 11/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// DERIVACIÓN CONTROLADA de `analytics de vacantes.png` (Pantalla 24), que es de
/// escritorio: barra lateral, cinco KPI en fila, gráfico de cuatro series y
/// embudo con porcentajes. Acá esa jerarquía baja a una columna: banda de KPI,
/// evolución, embudo y desglose por estado.
///
/// DATOS — y esta es la diferencia grande con el mockup. El PNG encabeza con
/// "Visualizaciones 128.4K" y sigue con fuentes de tráfico, tasa de conversión,
/// costo por contratación, tiempo promedio para contratar e índice de calidad.
/// El proyecto NO registra impresiones ni vistas de una vacante en ningún lado:
/// no hay tabla, ni evento, ni contador. Sin esa base, toda la mitad superior
/// del mockup sería inventada, así que no está.
///
/// Lo que sí se calcula, fila por fila: postulaciones (`job_applications`), su
/// reparto por estado, su evolución diaria por `created_at`, y las entrevistas
/// de la vacante (`interviews`).
class EmpresaVacanteAnalyticsScreen extends StatefulWidget {
  final Vacante vacante;

  /// Datos ya resueltos, para los golden tests.
  final VacanteAnalytics? previewData;

  const EmpresaVacanteAnalyticsScreen({
    super.key,
    required this.vacante,
    this.previewData,
  });

  @override
  State<EmpresaVacanteAnalyticsScreen> createState() =>
      _EmpresaVacanteAnalyticsScreenState();
}

class _EmpresaVacanteAnalyticsScreenState
    extends State<EmpresaVacanteAnalyticsScreen> {
  VacanteAnalytics _data = VacanteAnalytics.empty;
  bool _loading = true;

  /// Traducción de los estados crudos de `job_applications`. Si aparece uno que
  /// no está mapeado se muestra tal cual: inventarle nombre sería peor.
  static const _estados = {
    'pending': 'Pendientes',
    'reviewed': 'Revisadas',
    'shortlisted': 'En shortlist',
    'rejected': 'Descartadas',
    'unlocked': 'Desbloqueadas',
    'hired': 'Contratadas',
    'sin estado': 'Sin estado',
  };

  static const _colores = [
    MpTokens.primary,
    MpTokens.catBlue,
    MpTokens.catGreen,
    MpTokens.catOrange,
    MpTokens.catPurple,
    MpTokens.danger,
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
    final data = await loadVacanteAnalytics(widget.vacante.id);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: MpTokens.lightBg,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MpTokens.screenPadding,
                  MpTokens.space8,
                  MpTokens.screenPadding,
                  0,
                ),
                child: MpHeader(
                  title: 'Analytics',
                  subtitle: widget.vacante.titulo,
                  onBack: () => Navigator.of(context).maybePop(),
                  actions: [
                    MpIconButton(
                      icon: CupertinoIcons.refresh,
                      onPressed: _load,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CupertinoActivityIndicator(radius: 15))
                    : CustomScrollView(
                        slivers: [
                          CupertinoSliverRefreshControl(onRefresh: _load),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              MpTokens.screenPadding,
                              MpTokens.space16,
                              MpTokens.screenPadding,
                              MpTokens.space32,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate(_cuerpo()),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _cuerpo() {
    if (_data.error) return [_errorCarga()];
    if (_data.sinDatos) return [_vacio()];

    return [
      _kpis(),
      const SizedBox(height: MpTokens.space24),
      _evolucion(),
      const SizedBox(height: MpTokens.space24),
      _embudo(),
      const SizedBox(height: MpTokens.space24),
      _porEstado(),
      const SizedBox(height: MpTokens.space24),
      _queNoSeMide(),
    ];
  }

  Widget _errorCarga() {
    return Padding(
      padding: const EdgeInsets.only(top: MpTokens.space32),
      child: MpEmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'No pudimos cargar las métricas',
        message: 'Revisá tu conexión y volvé a intentar.',
        actionLabel: 'Reintentar',
        onAction: _load,
      ),
    );
  }

  Widget _vacio() {
    return Padding(
      padding: const EdgeInsets.only(top: MpTokens.space32),
      child: const MpEmptyState(
        icon: CupertinoIcons.chart_bar,
        title: 'Todavía no hay nada que medir',
        message: 'Cuando esta vacante reciba postulaciones vas a ver acá su '
            'evolución, su reparto por estado y cuántas llegaron a entrevista.',
      ),
    );
  }

  // ── KPI ────────────────────────────────────────────────────────────────────

  Widget _kpis() {
    final s = context.mp;
    final variacion = _data.variacionSemanal;
    final tasa = _data.tasaEntrevista;

    final items = <({String valor, String etiqueta, String? pie})>[
      (
        valor: '${_data.postulaciones}',
        etiqueta: 'Postulaciones',
        pie: variacion == null
            ? null
            : '${variacion >= 0 ? '+' : ''}$variacion% vs. semana previa',
      ),
      (
        valor: _data.entrevistasNoDisponibles ? '—' : '${_data.entrevistas}',
        etiqueta: 'Entrevistas',
        pie: tasa == null ? null : '$tasa% de las postulaciones',
      ),
      (
        valor: '${_data.pico}',
        etiqueta: 'Pico diario',
        pie: 'En ${_data.dias} días',
      ),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: MpTokens.space8),
            Expanded(
              child: MpCard(
                radius: MpTokens.radiusLG,
                padding: const EdgeInsets.symmetric(
                  horizontal: MpTokens.space8,
                  vertical: MpTokens.space16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        items[i].valor,
                        style: MpTokens.stat.copyWith(
                          color: s.text,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        items[i].etiqueta,
                        style: MpTokens.micro.copyWith(
                          color: s.text,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (items[i].pie != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        items[i].pie!,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: MpTokens.micro.copyWith(
                          color: s.textTertiary,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Evolución ──────────────────────────────────────────────────────────────

  Widget _evolucion() {
    final s = context.mp;
    final serie = _data.serie;

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Postulaciones por día',
            style: MpTokens.title.copyWith(color: s.text),
          ),
          const SizedBox(height: MpTokens.space4),
          Text(
            'Últimos ${_data.dias} días.',
            style: MpTokens.micro.copyWith(color: s.textTertiary),
          ),
          const SizedBox(height: MpTokens.space16),
          MpLineChart(
            series: [
              MpLineSeries(
                values: [for (final p in serie) p.cantidad.toDouble()],
                color: MpTokens.primary,
                filled: true,
              ),
            ],
            labels: [
              for (var i = 0; i < serie.length; i++)
                // Sólo las puntas y el medio: catorce fechas no entran.
                if (i == 0 || i == serie.length - 1 || i == serie.length ~/ 2)
                  '${serie[i].dia.day}/${serie[i].dia.month}'
                else
                  '',
            ],
            height: 150,
            showAxis: true,
          ),
        ],
      ),
    );
  }

  // ── Embudo ─────────────────────────────────────────────────────────────────

  Widget _embudo() {
    final s = context.mp;
    final postulaciones = _data.postulaciones;
    final entrevistas = _data.entrevistas;

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'De postulación a entrevista',
            style: MpTokens.title.copyWith(color: s.text),
          ),
          const SizedBox(height: MpTokens.space16),
          _pasoEmbudo('Postulaciones', postulaciones, postulaciones,
              MpTokens.primary),
          const SizedBox(height: MpTokens.space12),
          if (_data.entrevistasNoDisponibles)
            Text(
              'No pudimos leer las entrevistas de esta vacante.',
              style: MpTokens.caption.copyWith(color: s.textTertiary),
            )
          else
            _pasoEmbudo(
              'Entrevistas',
              entrevistas,
              postulaciones,
              MpTokens.catGreen,
            ),
        ],
      ),
    );
  }

  Widget _pasoEmbudo(String etiqueta, int valor, int total, Color color) {
    final s = context.mp;
    final fraccion = total == 0 ? 0.0 : (valor / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                etiqueta,
                style: MpTokens.label.copyWith(color: s.text),
              ),
            ),
            Text(
              '$valor',
              style: MpTokens.label.copyWith(color: color),
            ),
            if (total > 0 && valor != total) ...[
              const SizedBox(width: 6),
              Text(
                '${(fraccion * 100).round()}%',
                style: MpTokens.micro.copyWith(color: s.textTertiary),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        MpProgressBar(value: fraccion, color: color),
      ],
    );
  }

  // ── Por estado ─────────────────────────────────────────────────────────────

  Widget _porEstado() {
    final s = context.mp;
    final entradas = _data.porEstado.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Postulaciones por estado',
            style: MpTokens.title.copyWith(color: s.text),
          ),
          const SizedBox(height: MpTokens.space16),
          MpDonutChart(
            size: 120,
            thickness: 22,
            compact: true,
            slices: [
              for (var i = 0; i < entradas.length; i++)
                MpDonutSlice(
                  label: _estados[entradas[i].key] ?? entradas[i].key,
                  value: entradas[i].value.toDouble(),
                  color: _colores[i % _colores.length],
                ),
            ],
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_data.postulaciones}',
                  style: MpTokens.stat.copyWith(color: s.text, fontSize: 22),
                ),
                Text(
                  'total',
                  style: MpTokens.micro.copyWith(
                    color: s.textTertiary,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Decir qué NO se mide es parte del dato: sin esto, el recruiter podría creer
  /// que la vacante no tuvo visitas, cuando en realidad nadie las cuenta.
  Widget _queNoSeMide() {
    final s = context.mp;

    return MpBanner(
      icon: CupertinoIcons.info,
      title: 'Qué no se mide todavía',
      message: 'Mploya no registra cuántas veces se vio esta vacante, así que '
          'no hay visualizaciones, fuentes de tráfico ni tasa de conversión '
          'sobre visitas. Las métricas de arriba salen de postulaciones y '
          'entrevistas reales.',
      color: s.textTertiary,
    );
  }
}
