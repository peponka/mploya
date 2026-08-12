import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import 'empresa_proceso_data.dart';
import 'empresa_publicar_vacante_screen.dart';

/// Rendimiento comparado de las vacantes de la Empresa.
///
/// DERIVACIÓN CONTROLADA del bloque "Vacantes con mejor rendimiento" de
/// `analytics de vacantes.png` (24, escritorio), llevado a una columna.
///
/// POR QUÉ NO DUPLICA NADA. El Dashboard mira el embudo AGREGADO (cuántos en
/// cada etapa) y el Analytics de una vacante mira UNA en profundidad. Acá la
/// unidad es la comparación ENTRE vacantes: cuál atrae y cuál no. Es la única
/// de las tres que responde "¿qué vacante hay que corregir?".
///
/// OMITIDO del mockup: visualizaciones, tasa de conversión sobre visitas, costo
/// por contratación, tiempo promedio para contratar e índice de calidad. No hay
/// tracking de vistas ni registro de fechas de contratación, así que ninguno se
/// puede calcular.
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
class EmpresaRendimientoScreen extends StatefulWidget {
  /// Datos ya resueltos, para los golden tests.
  final RendimientoData? previewData;

  const EmpresaRendimientoScreen({super.key, this.previewData});

  @override
  State<EmpresaRendimientoScreen> createState() =>
      _EmpresaRendimientoScreenState();
}

class _EmpresaRendimientoScreenState extends State<EmpresaRendimientoScreen> {
  RendimientoData _data = RendimientoData.empty;
  bool _loading = true;

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
    final data = await loadRendimiento();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: MpTokens.lightBg,
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
                        delegate: SliverChildListDelegate(_cuerpo()),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  List<Widget> _cuerpo() {
    final s = context.mp;

    if (_data.vacantes.isEmpty) return [_encabezado(), _vacio()];

    final sinPostulaciones = _data.sinPostulaciones;

    return [
      _encabezado(),
      const SizedBox(height: MpTokens.space20),
      _resumen(),
      const SizedBox(height: MpTokens.space24),
      Text(
        'Vacantes por postulaciones',
        style: MpTokens.h2.copyWith(color: s.text, fontSize: 17),
      ),
      const SizedBox(height: MpTokens.space12),
      MpCard(
        radius: MpTokens.radiusXL,
        child: Column(
          children: [
            for (var i = 0; i < _data.vacantes.length; i++) ...[
              if (i > 0) ...[
                const SizedBox(height: MpTokens.space16),
                Container(height: 1, color: s.border),
                const SizedBox(height: MpTokens.space16),
              ],
              _fila(_data.vacantes[i]),
            ],
          ],
        ),
      ),
      if (sinPostulaciones.isNotEmpty) ...[
        const SizedBox(height: MpTokens.space24),
        _avisoSinPostulaciones(sinPostulaciones.length),
      ],
      const SizedBox(height: MpTokens.space16),
      _queNoSeMide(),
    ];
  }

  Widget _encabezado() {
    final s = context.mp;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (Navigator.of(context).canPop()) ...[
          MpIconButton(
            icon: CupertinoIcons.chevron_left,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: MpTokens.space12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rendimiento', style: MpTokens.h1.copyWith(color: s.text)),
              const SizedBox(height: MpTokens.space4),
              Text(
                'Qué vacantes atraen candidatos y cuáles no.',
                style: MpTokens.body.copyWith(
                  color: s.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: MpTokens.space8),
        MpIconButton(icon: CupertinoIcons.refresh, onPressed: _load),
      ],
    );
  }

  Widget _vacio() {
    return Padding(
      padding: const EdgeInsets.only(top: MpTokens.space32),
      child: MpEmptyState(
        icon: _data.error
            ? CupertinoIcons.exclamationmark_triangle
            : CupertinoIcons.chart_bar,
        title: _data.error
            ? 'No pudimos cargar el rendimiento'
            : 'Todavía no publicaste vacantes',
        message: _data.error
            ? 'Revisá tu conexión y volvé a intentar.'
            : 'Con dos o más vacantes vas a poder compararlas y ver cuál '
                'funciona mejor.',
        actionLabel: _data.error ? 'Reintentar' : 'Publicar vacante',
        onAction: _data.error
            ? _load
            : () => Navigator.of(context)
                .push(
                  CupertinoPageRoute(
                    builder: (_) => const EmpresaPublicarVacanteScreen(),
                  ),
                )
                .then((_) => _load()),
      ),
    );
  }

  Widget _resumen() {
    final s = context.mp;

    final items = <({String valor, String etiqueta})>[
      (valor: '${_data.vacantes.length}', etiqueta: 'Vacantes'),
      (valor: '${_data.activas}', etiqueta: 'Activas'),
      (valor: '${_data.totalPostulaciones}', etiqueta: 'Postulaciones'),
      if (!_data.entrevistasNoDisponibles)
        (valor: '${_data.totalEntrevistas}', etiqueta: 'Entrevistas'),
    ];

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.symmetric(
        horizontal: MpTokens.space8,
        vertical: MpTokens.space16,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Container(width: 1, color: s.border),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        items[i].valor,
                        style: MpTokens.stat.copyWith(
                          color: s.text,
                          fontSize: 21,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        items[i].etiqueta,
                        style: MpTokens.micro.copyWith(
                          color: s.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fila(RendimientoVacante v) {
    final s = context.mp;
    final maximo = _data.maxPostulaciones;
    final fraccion = maximo == 0 ? 0.0 : v.postulaciones / maximo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                v.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MpTokens.label.copyWith(color: s.text),
              ),
            ),
            if (!v.activa) ...[
              const SizedBox(width: MpTokens.space8),
              const MpStatusBadge(label: 'Pausada', status: MpStatus.paused),
            ],
          ],
        ),
        const SizedBox(height: MpTokens.space8),
        Row(
          children: [
            Expanded(
              child: MpProgressBar(
                value: fraccion,
                color: v.postulaciones == 0
                    ? MpTokens.danger
                    : MpTokens.primary,
              ),
            ),
            const SizedBox(width: MpTokens.space12),
            Text(
              '${v.postulaciones}',
              style: MpTokens.label.copyWith(
                color: v.postulaciones == 0 ? MpTokens.danger : s.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: MpTokens.space4),
        Text(
          [
            '${v.postulaciones} '
                '${v.postulaciones == 1 ? 'postulación' : 'postulaciones'}',
            if (!_data.entrevistasNoDisponibles)
              '${v.entrevistas} '
                  '${v.entrevistas == 1 ? 'entrevista' : 'entrevistas'}',
          ].join('  ·  '),
          style: MpTokens.micro.copyWith(color: s.textTertiary),
        ),
      ],
    );
  }

  Widget _avisoSinPostulaciones(int cuantas) {
    return MpBanner(
      icon: CupertinoIcons.exclamationmark_circle,
      title: cuantas == 1
          ? 'Una vacante sin postulaciones'
          : '$cuantas vacantes sin postulaciones',
      message: 'Revisá que tengan descripción y habilidades cargadas: sin eso '
          'el match no las puede recomendar a nadie.',
      color: MpTokens.premium,
    );
  }

  Widget _queNoSeMide() {
    final s = context.mp;

    return MpBanner(
      icon: CupertinoIcons.info,
      title: 'Qué no se mide todavía',
      message: 'No hay registro de cuántas veces se vio cada vacante, así que '
          'no se puede calcular conversión sobre visitas, costo por '
          'contratación ni tiempo hasta contratar.',
      color: s.textTertiary,
    );
  }
}
