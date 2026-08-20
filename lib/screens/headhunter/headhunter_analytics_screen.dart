import 'package:flutter/cupertino.dart';

import '../../services/headhunter_clients_service.dart';
import '../../services/headhunter_placements_service.dart';
import '../../services/headhunter_pipeline_candidates_service.dart';
import '../../widgets/ds/mploya_ds.dart';
import 'headhunter_analytics_data.dart';

/// Colocaciones y Analytics (Headhunter).
///
/// RECONSTRUCCIÓN de `18_Headhunter_Colocaciones_Analytics.png`. Sigue el
/// mismo patrón que `empresa_vacante_analytics_screen.dart`: se construye
/// todo lo que sale de filas reales y se cierra con un banner honesto de
/// "qué no se mide todavía" en vez de inventar el resto — ver el
/// doc-comment de `headhunter_analytics_data.dart` para el detalle de qué
/// es real y qué no.
///
/// Sin ranura de nav propia (las 6 ya están ocupadas): se llega por push
/// desde el Dashboard, mismo patrón que Pipeline/Shortlist.
class HeadhunterAnalyticsScreen extends StatefulWidget {
  const HeadhunterAnalyticsScreen({super.key});

  @override
  State<HeadhunterAnalyticsScreen> createState() => _HeadhunterAnalyticsScreenState();
}

enum _Periodo { esteAnio, ultimos6Meses, todo }

class _HeadhunterAnalyticsScreenState extends State<HeadhunterAnalyticsScreen> {
  HeadhunterAnalytics _data = HeadhunterAnalytics.empty;
  bool _loading = true;
  _Periodo _periodo = _Periodo.todo;
  String? _clientId;
  List<Map<String, dynamic>> _clients = const [];

  static const _fuentes = {
    'busqueda_activa': 'Búsqueda activa',
    'talent_pool': 'Talent Pool',
  };

  static const _colores = [
    MpTokens.primary,
    MpTokens.catBlue,
    MpTokens.catGreen,
    MpTokens.catOrange,
    MpTokens.catPurple,
  ];

  DateTime? get _desde {
    final ahora = DateTime.now();
    switch (_periodo) {
      case _Periodo.esteAnio:
        return DateTime(ahora.year);
      case _Periodo.ultimos6Meses:
        return DateTime(ahora.year, ahora.month - 6, ahora.day);
      case _Periodo.todo:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final clients = await listHeadhunterClients();
    final data = await loadHeadhunterAnalytics(clientId: _clientId, desde: _desde);
    if (!mounted) return;
    setState(() {
      _clients = clients;
      _data = data;
      _loading = false;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────

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
                  title: 'Colocaciones y Analytics',
                  onBack: () => Navigator.of(context).maybePop(),
                  actions: [
                    MpIconButton(icon: CupertinoIcons.refresh, onPressed: _load),
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

    final cuerpo = <Widget>[
      _filtros(),
      const SizedBox(height: MpTokens.space24),
    ];

    if (_data.sinDatos) {
      cuerpo.add(_vacio());
      return cuerpo;
    }

    cuerpo.addAll([
      _kpis(),
      const SizedBox(height: MpTokens.space24),
      _evolucion(),
      const SizedBox(height: MpTokens.space24),
      _porFuente(),
      const SizedBox(height: MpTokens.space24),
      _etapas(),
      const SizedBox(height: MpTokens.space24),
      _topClientes(),
      const SizedBox(height: MpTokens.space24),
      _fees(),
      const SizedBox(height: MpTokens.space24),
      _ultimasColocaciones(),
      const SizedBox(height: MpTokens.space24),
    ]);
    cuerpo.add(_queNoSeMide());
    return cuerpo;
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
    return const MpEmptyState(
      icon: CupertinoIcons.chart_bar,
      title: 'Todavía no hay colocaciones',
      message: 'Cuando muevas un candidato a "Colocado" en el pipeline de una '
          'búsqueda vas a ver acá su evolución, sus fees y tu rendimiento por '
          'cliente.',
    );
  }

  // ── Filtros ────────────────────────────────────────────────────────────

  Widget _filtros() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MpSegmentedFilter(
          options: const [
            MpFilterOption('Este año'),
            MpFilterOption('Últimos 6 meses'),
            MpFilterOption('Todo'),
          ],
          selectedIndex: _periodo.index,
          onChanged: (i) {
            setState(() => _periodo = _Periodo.values[i]);
            _load();
          },
        ),
        const SizedBox(height: MpTokens.space8),
        MpSelectField(
          value: _clientId == null
              ? 'Todos los clientes'
              : (_clients.firstWhere(
                    (c) => c['id'].toString() == _clientId,
                    orElse: () => const {},
                  )['company_name']?.toString() ??
                  'Cliente'),
          icon: CupertinoIcons.building_2_fill,
          isPlaceholder: _clientId == null,
          onTap: _elegirCliente,
        ),
      ],
    );
  }

  Future<void> _elegirCliente() async {
    final id = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Filtrar por cliente'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Todos los clientes'),
          ),
          for (final c in _clients)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, c['id'].toString()),
              child: Text(c['company_name']?.toString() ?? 'Cliente'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (id == _clientId) return;
    setState(() => _clientId = id);
    _load();
  }

  // ── KPIs ───────────────────────────────────────────────────────────────

  Widget _kpis() {
    final s = context.mp;
    final tasa = _data.tasaExito;
    final tiempo = _data.tiempoPromedio;

    final items = <({String valor, String etiqueta})>[
      (valor: '${_data.colocaciones}', etiqueta: 'Colocaciones'),
      (valor: tasa == null ? '—' : '$tasa%', etiqueta: 'Tasa de éxito'),
      (valor: tiempo == null ? '—' : '${tiempo.inDays}d', etiqueta: 'Tiempo promedio'),
      (valor: '${_data.totalJobs}', etiqueta: 'Búsquedas'),
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
                        style: MpTokens.stat.copyWith(color: s.text, fontSize: 22),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        items[i].etiqueta,
                        style: MpTokens.micro.copyWith(color: s.text, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Evolución ──────────────────────────────────────────────────────────

  Widget _evolucion() {
    final s = context.mp;
    final porMes = _data.colocacionesPorMes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (porMes.isEmpty) return const SizedBox.shrink();

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Evolución de colocaciones', style: MpTokens.title.copyWith(color: s.text)),
          const SizedBox(height: MpTokens.space16),
          MpLineChart(
            series: [
              MpLineSeries(
                values: [for (final p in porMes) p.value.toDouble()],
                color: MpTokens.primary,
                filled: true,
              ),
            ],
            labels: [for (final p in porMes) p.key.substring(5)],
            height: 150,
            showAxis: true,
          ),
        ],
      ),
    );
  }

  // ── Por fuente ─────────────────────────────────────────────────────────

  Widget _porFuente() {
    final s = context.mp;
    final entradas = _data.sourceCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entradas.isEmpty) return const SizedBox.shrink();

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Colocaciones por fuente', style: MpTokens.title.copyWith(color: s.text)),
          const SizedBox(height: MpTokens.space16),
          MpDonutChart(
            size: 120,
            thickness: 22,
            compact: true,
            slices: [
              for (var i = 0; i < entradas.length; i++)
                MpDonutSlice(
                  label: _fuentes[entradas[i].key] ?? entradas[i].key,
                  value: entradas[i].value.toDouble(),
                  color: _colores[i % _colores.length],
                ),
            ],
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_data.colocaciones}', style: MpTokens.stat.copyWith(color: s.text, fontSize: 22)),
                Text('total', style: MpTokens.micro.copyWith(color: s.textTertiary, fontSize: 9.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Etapas ─────────────────────────────────────────────────────────────

  Widget _etapas() {
    final s = context.mp;
    final maxHoras = _data.stageAverages.values.isEmpty
        ? 0
        : _data.stageAverages.values.map((d) => d.inHours).reduce((a, b) => a > b ? a : b);

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tiempo promedio por etapa', style: MpTokens.title.copyWith(color: s.text)),
          const SizedBox(height: MpTokens.space4),
          Text(
            'Desde que un candidato entra a una etapa hasta que avanza.',
            style: MpTokens.micro.copyWith(color: s.textTertiary),
          ),
          const SizedBox(height: MpTokens.space16),
          for (final stage in kPipelineStages) ...[
            _filaEtapa(stage, _data.stageAverages[stage], maxHoras),
            if (stage != kPipelineStages.last) const SizedBox(height: MpTokens.space8),
          ],
        ],
      ),
    );
  }

  Widget _filaEtapa(String stage, Duration? promedio, int maxHoras) {
    final s = context.mp;
    final fraccion = promedio == null || maxHoras == 0
        ? 0.0
        : (promedio.inHours / maxHoras).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(pipelineStageLabel(stage), style: MpTokens.label.copyWith(color: s.text)),
            ),
            Text(
              promedio == null ? 'Sin datos todavía' : '${promedio.inDays}d',
              style: MpTokens.micro.copyWith(color: s.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        MpProgressBar(value: fraccion, color: MpTokens.primary),
      ],
    );
  }

  // ── Top clientes ───────────────────────────────────────────────────────

  Widget _topClientes() {
    final s = context.mp;
    final top = _data.topClientes;
    if (top.isEmpty) return const SizedBox.shrink();

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rendimiento por cliente', style: MpTokens.title.copyWith(color: s.text)),
          const SizedBox(height: MpTokens.space16),
          for (var i = 0; i < top.length; i++) ...[
            MpListRow(
              title: top[i].nombre,
              trailingText: '${top[i].colocaciones} colocaciones',
              showChevron: false,
            ),
            if (i != top.length - 1) const SizedBox(height: MpTokens.space4),
          ],
        ],
      ),
    );
  }

  // ── Fees ───────────────────────────────────────────────────────────────

  Widget _fees() {
    final s = context.mp;
    final ticket = _data.ticketPromedio;

    final items = <({String valor, String etiqueta})>[
      (valor: '\$${_data.feesGenerados.toStringAsFixed(0)}', etiqueta: 'Fees generados'),
      (valor: '\$${_data.comisionesCobradas.toStringAsFixed(0)}', etiqueta: 'Cobrado'),
      (valor: '\$${_data.pendienteDeCobro.toStringAsFixed(0)}', etiqueta: 'Pendiente de cobro'),
      (valor: ticket == null ? '—' : '\$${ticket.toStringAsFixed(0)}', etiqueta: 'Ticket promedio'),
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
                        style: MpTokens.stat.copyWith(color: s.text, fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        items[i].etiqueta,
                        style: MpTokens.micro.copyWith(color: s.text, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Últimas colocaciones ───────────────────────────────────────────────

  Widget _ultimasColocaciones() {
    final s = context.mp;
    final ordenadas = [..._data.placements]..sort(
        (a, b) => (b['placed_at']?.toString() ?? '').compareTo(a['placed_at']?.toString() ?? ''));
    final ultimas = ordenadas.take(10).toList();

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Últimas colocaciones', style: MpTokens.title.copyWith(color: s.text)),
          const SizedBox(height: MpTokens.space16),
          for (var i = 0; i < ultimas.length; i++) ...[
            _filaColocacion(ultimas[i]),
            if (i != ultimas.length - 1) const SizedBox(height: MpTokens.space4),
          ],
        ],
      ),
    );
  }

  Widget _filaColocacion(Map<String, dynamic> p) {
    final candidato = _data.candidateNameById[p['candidate_id']?.toString()] ?? 'Candidato';
    final cliente = _data.clientNameById[p['client_id']?.toString()];
    final job = _data.jobTitleById[p['job_id']?.toString()];
    final fee = p['fee_amount'];
    final cobrado = p['payment_status'] == 'cobrado';

    return MpListRow(
      title: candidato,
      subtitle: [if (job != null) job, if (cliente != null) cliente].join(' · '),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fee is num ? '\$${fee.toStringAsFixed(0)}' : 'Sin fee',
            style: MpTokens.label.copyWith(color: context.mp.text),
          ),
          if (fee is num)
            MpStatusBadge(status: cobrado ? MpStatus.active : MpStatus.paused,
                label: cobrado ? 'Cobrado' : 'Pendiente'),
        ],
      ),
      onTap: () => _editarFee(p),
    );
  }

  Future<void> _editarFee(Map<String, dynamic> p) async {
    final controller = TextEditingController(
      text: p['fee_amount'] is num ? (p['fee_amount'] as num).toStringAsFixed(0) : '',
    );
    final result = await showCupertinoDialog<({String fee, bool cobrado})>(
      context: context,
      builder: (ctx) {
        var cobrado = p['payment_status'] == 'cobrado';
        return StatefulBuilder(
          builder: (ctx, setDialogState) => CupertinoAlertDialog(
            title: const Text('Editar fee'),
            content: Column(
              children: [
                const SizedBox(height: MpTokens.space8),
                CupertinoTextField(
                  controller: controller,
                  placeholder: 'Monto en USD',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                ),
                const SizedBox(height: MpTokens.space12),
                Row(
                  children: [
                    const Expanded(child: Text('Marcar como cobrado')),
                    CupertinoSwitch(
                      value: cobrado,
                      onChanged: (v) => setDialogState(() => cobrado = v),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(ctx, (fee: controller.text, cobrado: cobrado)),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );
    if (result == null) return;
    final fee = double.tryParse(result.fee.replaceAll(',', '.'));
    await updatePlacementFee(
      p['id'].toString(),
      feeAmount: fee,
      marcarCobrado: result.cobrado,
    );
    _load();
  }

  /// Decir qué NO se mide es parte del dato: sin esto el headhunter podría
  /// creer que "Referidos"/"Aplicaciones" no tuvieron colocaciones, cuando
  /// en realidad ese flujo no existe en el modelo de sourcing.
  Widget _queNoSeMide() {
    final s = context.mp;
    return MpBanner(
      icon: CupertinoIcons.info,
      title: 'Qué no se mide todavía',
      message: 'Las colocaciones se agrupan sólo por Búsqueda activa o Talent '
          'Pool: acá no hay flujo de Referidos ni de Aplicaciones formales, '
          'así que esas fuentes no aparecen. No hay exportación a PDF.',
      color: s.textTertiary,
    );
  }
}
