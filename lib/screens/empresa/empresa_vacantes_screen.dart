import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import 'empresa_actividad_screen.dart';
import 'empresa_publicar_vacante_screen.dart';
import 'empresa_vacante_detalle_screen.dart';
import 'empresa_vacantes_data.dart';

/// Vacantes de la Empresa.
///
/// DERIVACIÓN CONTROLADA: no existe un PNG de "Vacantes Empresa" entre los 87.
/// La jerarquía visual se toma de `10_Headhunter_Busquedas_Activas.png`
/// —encabezado con marca, título grande, buscador + filtros, chips de estado
/// con contador, fila de métricas, listado y banner de creación— y se adapta a
/// Empresa: acá la vacante es propia, así que desaparece todo lo de cliente,
/// mandato y búsqueda para terceros.
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
class EmpresaVacantesScreen extends StatefulWidget {
  /// Datos ya resueltos, para renderizar sin backend en los golden tests.
  final VacantesData? previewData;

  const EmpresaVacantesScreen({super.key, this.previewData});

  @override
  State<EmpresaVacantesScreen> createState() => _EmpresaVacantesScreenState();
}

class _EmpresaVacantesScreenState extends State<EmpresaVacantesScreen> {
  VacantesData _data = VacantesData.empty;
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  String _query = '';
  int _filtro = 0;
  String _orden = 'Más recientes';

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.previewData != null) return;
    if (!mounted) return;
    setState(() => _loading = true);
    final data = await loadEmpresaVacantes();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  /// Filtros disponibles. Sin campo de estado en la base, sólo "Todas".
  List<MpFilterOption> get _filtros {
    if (!_data.soportaEstados) {
      return [MpFilterOption('Todas', count: _data.total)];
    }
    return [
      MpFilterOption('Todas', count: _data.total),
      MpFilterOption('Activas', count: _data.activas),
      MpFilterOption('Pausadas', count: _data.pausadas),
    ];
  }

  List<Vacante> get _visibles {
    var lista = _data.vacantes;

    if (_data.soportaEstados) {
      if (_filtro == 1) {
        lista = lista.where((v) => v.estado == VacanteEstado.activa).toList();
      } else if (_filtro == 2) {
        lista = lista.where((v) => v.estado == VacanteEstado.pausada).toList();
      }
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      lista = lista.where((v) {
        return v.titulo.toLowerCase().contains(q) ||
            (v.ubicacion?.toLowerCase().contains(q) ?? false) ||
            v.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    final ordenada = [...lista];
    if (_orden == 'Más candidatos') {
      ordenada.sort((a, b) => b.candidatos.compareTo(a.candidatos));
    } else {
      ordenada.sort((a, b) {
        final da = a.creada;
        final db = b.creada;
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });
    }
    return ordenada;
  }

  Future<void> _nuevaVacante() async {
    final creada = await Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const EmpresaPublicarVacanteScreen()),
    );
    if (creada == true) await _load();
  }

  Future<void> _pickOrden() async {
    const opciones = ['Más recientes', 'Más candidatos'];
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Ordenar por'),
        actions: [
          for (final opcion in opciones)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                setState(() => _orden = opcion);
              },
              child: Text(opcion),
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
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 15))
            : CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _load),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      MpTokens.screenPadding,
                      MpTokens.space8,
                      MpTokens.screenPadding,
                      MpTokens.space32,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _topBar(),
                        const SizedBox(height: MpTokens.space20),
                        _titulo(),
                        if (_data.error) ...[
                          const SizedBox(height: MpTokens.space32),
                          ..._listado(),
                        ] else ...[
                          const SizedBox(height: MpTokens.space16),
                          _buscador(),
                          const SizedBox(height: MpTokens.space12),
                          MpSegmentedFilter(
                            options: _filtros,
                            selectedIndex: _filtro,
                            onChanged: (i) => setState(() => _filtro = i),
                            scrollable: _filtros.length > 2,
                          ),
                          const SizedBox(height: MpTokens.space16),
                          _metricas(),
                          const SizedBox(height: MpTokens.space24),
                          _encabezadoLista(),
                          const SizedBox(height: MpTokens.space12),
                          ..._listado(),
                          const SizedBox(height: MpTokens.space20),
                          _bannerCrear(),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Encabezado ────────────────────────────────────────────────────────────

  Widget _topBar() {
    return Row(
      children: [
        MpIconButton(
          icon: CupertinoIcons.chevron_left,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const Expanded(child: Center(child: MpWordmark(fontSize: 24))),
        MpIconButton(
          icon: CupertinoIcons.bell,
          onPressed: () => Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => const EmpresaActividadScreen()),
          ),
        ),
      ],
    );
  }

  Widget _titulo() {
    final s = context.mp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vacantes', style: MpTokens.h1.copyWith(color: s.text)),
        const SizedBox(height: MpTokens.space4),
        Text(
          'Gestioná tus vacantes, seguí su progreso y encontrá al mejor talento.',
          style: MpTokens.body.copyWith(color: s.textSecondary, fontSize: 14.5),
        ),
      ],
    );
  }

  Widget _buscador() {
    final s = context.mp;

    return Row(
      children: [
        Expanded(
          child: MpTextField(
            controller: _searchCtrl,
            placeholder: 'Buscar vacante…',
            icon: CupertinoIcons.search,
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const SizedBox(width: MpTokens.space8),
        GestureDetector(
          onTap: _pickOrden,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: s.card,
              borderRadius: BorderRadius.circular(MpTokens.radiusMD),
              border: Border.all(color: s.borderStrong),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.slider_horizontal_3,
                  size: 18,
                  color: s.text,
                ),
                const SizedBox(width: 7),
                Text('Orden', style: MpTokens.label.copyWith(color: s.text)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Métricas ──────────────────────────────────────────────────────────────

  Widget _metricas() {
    // Sólo se muestran métricas derivables de datos reales.
    final tiles = <Widget>[
      _metrica(
        icon: CupertinoIcons.briefcase,
        color: MpTokens.primary,
        valor: '${_data.total}',
        etiqueta: 'Vacantes',
        pie: 'Totales',
      ),
      if (_data.soportaEstados)
        _metrica(
          icon: CupertinoIcons.play_circle,
          color: MpTokens.primary,
          valor: '${_data.activas}',
          etiqueta: 'Activas',
          pie: _porcentaje(_data.activas),
        ),
      if (_data.soportaEstados)
        _metrica(
          icon: CupertinoIcons.pause_circle,
          color: MpTokens.primary,
          valor: '${_data.pausadas}',
          etiqueta: 'Pausadas',
          pie: _porcentaje(_data.pausadas),
        ),
      _metrica(
        icon: CupertinoIcons.person_2,
        color: MpTokens.primary,
        valor: _data.conteoNoDisponible ? '—' : '${_data.candidatos}',
        etiqueta: 'Candidatos',
        pie: _data.conteoNoDisponible ? 'Sin acceso' : 'Postulaciones',
      ),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: MpTokens.space8),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }

  String _porcentaje(int valor) {
    if (_data.total == 0) return '0%';
    return '${(valor / _data.total * 100).toStringAsFixed(1)}%';
  }

  Widget _metrica({
    required IconData icon,
    required Color color,
    required String valor,
    required String etiqueta,
    required String pie,
  }) {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.symmetric(
        horizontal: MpTokens.space8,
        vertical: MpTokens.space12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MpIconTile(icon: icon, color: color, size: 34, circular: true),
          const SizedBox(height: MpTokens.space8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: MpTokens.stat.copyWith(color: s.text, fontSize: 22),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              etiqueta,
              style: MpTokens.micro.copyWith(color: s.text, fontSize: 11.5),
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              pie,
              style: MpTokens.micro.copyWith(
                color: s.textTertiary,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Listado ───────────────────────────────────────────────────────────────

  Widget _encabezadoLista() {
    final s = context.mp;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Todas las vacantes',
            style: MpTokens.h2.copyWith(color: s.text, fontSize: 18),
          ),
        ),
        GestureDetector(
          onTap: _pickOrden,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _orden,
                style: MpTokens.label.copyWith(color: s.textSecondary),
              ),
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_down,
                size: 13,
                color: s.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _listado() {
    if (_data.error) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: MpEmptyState(
            icon: CupertinoIcons.exclamationmark_triangle,
            title: 'No pudimos cargar tus vacantes',
            message: 'Revisá tu conexión y volvé a intentarlo.',
            actionLabel: 'Reintentar',
            onAction: _load,
          ),
        ),
      ];
    }
    final visibles = _visibles;

    if (visibles.isEmpty) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: MpEmptyState(
            icon: CupertinoIcons.briefcase,
            title: _data.total == 0
                ? 'Todavía no publicaste vacantes'
                : 'Sin resultados',
            message: _data.total == 0
                ? 'Publicá tu primera vacante y empezá a recibir candidatos.'
                : 'Probá con otra búsqueda o cambiá el filtro.',
            actionLabel: _data.total == 0 ? 'Publicar vacante' : null,
            onAction: _data.total == 0 ? _nuevaVacante : null,
          ),
        ),
      ];
    }

    return [
      for (final vacante in visibles) ...[
        _fila(vacante),
        const SizedBox(height: MpTokens.space8),
      ],
    ];
  }

  Widget _fila(Vacante vacante) {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space12),
      // Detalle de vacante de EMPRESA (no el `JobDetailScreen` del repo, que es
      // la vista de Candidato y lleva "Postularme").
      onTap: () async {
        await Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => EmpresaVacanteDetalleScreen(vacante: vacante),
          ),
        );
        // El detalle puede pausar o reactivar la vacante: al volver se refresca
        // para que la lista no muestre un estado viejo.
        await _load();
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sin logo de cliente: la vacante es de la propia empresa.
          MpIconTile(
            icon: vacante.confidencial
                ? CupertinoIcons.lock_fill
                : CupertinoIcons.briefcase_fill,
            color: vacante.confidencial ? MpTokens.catIndigo : MpTokens.primary,
            size: 46,
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      // Dos líneas: títulos como "Especialista en Marketing
                      // Digital" no entran en una sola junto al chip de estado.
                      child: Text(
                        vacante.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MpTokens.title.copyWith(
                          color: s.text,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                    if (vacante.estado != VacanteEstado.desconocido) ...[
                      const SizedBox(width: MpTokens.space8),
                      MpStatusBadge(
                        label: vacante.estado == VacanteEstado.activa
                            ? 'Activa'
                            : 'Pausada',
                        status: vacante.estado == VacanteEstado.activa
                            ? MpStatus.active
                            : MpStatus.paused,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                // El salario va en el Wrap y no en la fila de candidatos: ahí
                // competía por el ancho y se cortaba ("USD 2.200 –…").
                Wrap(
                  spacing: 12,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (vacante.ubicacion != null)
                      _meta(CupertinoIcons.placemark, vacante.ubicacion!),
                    if (vacante.modalidad != null)
                      _meta(CupertinoIcons.globe, vacante.modalidad!),
                    if (vacante.antiguedad != null)
                      _meta(CupertinoIcons.clock, vacante.antiguedad!),
                    if (vacante.salario != null)
                      _meta(CupertinoIcons.money_dollar, vacante.salario!),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.person_2,
                      size: 14,
                      color: vacante.candidatos > 0
                          ? MpTokens.primary
                          : s.textTertiary,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        _data.conteoNoDisponible
                            ? 'Candidatos no disponibles'
                            : '${vacante.candidatos} '
                                  '${vacante.candidatos == 1 ? 'candidato' : 'candidatos'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MpTokens.label.copyWith(
                          color: vacante.candidatos > 0
                              ? MpTokens.primary
                              : s.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: MpTokens.space4),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: s.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String label) {
    final s = context.mp;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: s.textTertiary),
        const SizedBox(width: 4),
        Text(
          label,
          style: MpTokens.caption.copyWith(
            color: s.textSecondary,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }

  Widget _bannerCrear() {
    return MpBanner(
      icon: CupertinoIcons.briefcase,
      title: '¿Querés publicar una nueva vacante?',
      message: 'Creá una vacante y encontrá al talento ideal más rápido.',
      actionLabel: 'Nueva vacante',
      onAction: _nuevaVacante,
    );
  }
}
