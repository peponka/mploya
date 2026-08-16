import 'package:flutter/cupertino.dart';

import '../../models/models.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../chat_inmail_screen.dart';
import 'empresa_candidato_perfil_screen.dart';
import 'empresa_comparar_screen.dart';
import 'empresa_match_ia_screen.dart';
import 'empresa_shortlist_data.dart';
import 'empresa_vacantes_data.dart';

/// Shortlist Inteligente de una vacante.
///
/// RECONSTRUCCIÓN DIRECTA de `shortlist inteligente.png` (Pantalla 53), que es
/// una pantalla de Empresa móvil: barra inferior Inicio · Vacantes · (+) ·
/// Mensajes · Perfil, encabezado con la vacante y ranking de candidatos.
/// Se conserva su superficie OSCURA, su banda de métricas, los filtros por
/// compatibilidad, las tarjetas numeradas con anillo de ajuste y la barra de
/// acción al pie.
///
/// DATOS. Los porcentajes salen enteros de `match_candidates_for_job`
/// (migración 019: 70% señal semántica del embedding + 30% coincidencia de
/// skills). El mockup muestra además puntaje con estrellas, "tiempo promedio en
/// etapa" y "listo para entrevista": nada de eso existe en la base, así que no
/// se dibuja. Un candidato sin score (se postuló pero no tiene embedding) se
/// muestra SIN porcentaje, no con un número inventado.
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
class EmpresaShortlistScreen extends StatefulWidget {
  final Vacante vacante;

  /// Datos ya resueltos, para los golden tests.
  final ShortlistData? previewData;

  const EmpresaShortlistScreen({
    super.key,
    required this.vacante,
    this.previewData,
  });

  @override
  State<EmpresaShortlistScreen> createState() => _EmpresaShortlistScreenState();
}

class _EmpresaShortlistScreenState extends State<EmpresaShortlistScreen> {
  ShortlistData _data = ShortlistData.empty;
  bool _loading = true;

  int _filtro = 0;
  final _seleccionados = <String>{};

  /// Tope de la comparación: el mockup de comparar muestra cuatro columnas.
  static const _maxComparar = 4;

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
    final data = await loadShortlist(widget.vacante.id);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
      _seleccionados.removeWhere(
        (id) => !data.candidatos.any((c) => c.id == id),
      );
    });
  }

  List<MpFilterOption> get _filtros => [
    MpFilterOption('Todos', count: _data.total),
        MpFilterOption(
          'Alta',
          count: _data.enBanda(BandaAjuste.alta),
        ),
        MpFilterOption(
          'Media',
          count: _data.enBanda(BandaAjuste.media),
        ),
        MpFilterOption(
          'Baja',
          count: _data.enBanda(BandaAjuste.baja),
        ),
    MpFilterOption('Postulados', count: _data.postulados),
  ];

  List<CandidatoShortlist> get _visibles => switch (_filtro) {
        1 => _data.candidatos
            .where((c) => c.banda == BandaAjuste.alta)
            .toList(),
        2 => _data.candidatos
            .where((c) => c.banda == BandaAjuste.media)
            .toList(),
        3 => _data.candidatos
            .where((c) => c.banda == BandaAjuste.baja)
            .toList(),
        4 => _data.candidatos.where((c) => c.postulado).toList(),
        _ => _data.candidatos,
      };

  void _alternarSeleccion(CandidatoShortlist c) {
    setState(() {
      if (_seleccionados.contains(c.id)) {
        _seleccionados.remove(c.id);
      } else if (_seleccionados.length < _maxComparar) {
        _seleccionados.add(c.id);
      }
    });
  }

  void _comparar() {
    final elegidos =
        _data.candidatos.where((c) => _seleccionados.contains(c.id)).toList();
    if (elegidos.length < 2) return;

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => EmpresaCompararScreen(
          vacante: widget.vacante,
          candidatos: elegidos,
        ),
      ),
    );
  }

  NexUser _usuario(CandidatoShortlist c) => NexUser.fromJson({
    'id': c.id,
    'name': c.nombre,
    'headline': c.headline ?? '',
    'avatar_url': c.avatarUrl,
    'account_type': c.accountType,
    'tags': c.tags,
  });

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.dark,
      child: CupertinoPageScaffold(
        backgroundColor: MpTokens.darkBg,
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
                  title: 'Shortlist Inteligente',
                  subtitle: 'Mejores candidatos para esta vacante',
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
                              MpTokens.space12,
                              MpTokens.screenPadding,
                              MpTokens.space24,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate(_cuerpo()),
                            ),
                          ),
                        ],
                      ),
              ),
              if (!_loading && _data.total > 0) _barraAcciones(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _cuerpo() {
    if (_data.total == 0) return [_vacio()];

    return [
      _bandaVacante(),
      const SizedBox(height: MpTokens.space12),
      _metricas(),
      const SizedBox(height: MpTokens.space16),
      MpSegmentedFilter(
        options: _filtros,
        selectedIndex: _filtro,
        onChanged: (i) => setState(() => _filtro = i),
        scrollable: true,
      ),
      const SizedBox(height: MpTokens.space16),
      ..._listado(),
      const SizedBox(height: MpTokens.space20),
      _comoSeCalcula(),
    ];
  }

  Widget _vacio() {
    return Padding(
      padding: const EdgeInsets.only(top: MpTokens.space32),
      child: MpEmptyState(
        icon: _data.matchError
            ? CupertinoIcons.exclamationmark_triangle
            : CupertinoIcons.person_2,
        title: _data.matchError
            ? 'No pudimos calcular la shortlist'
            : 'Todavía no hay candidatos para esta vacante',
        message: _data.matchError
            ? 'Revisá tu conexión y volvé a intentar.'
            : 'El match necesita que la vacante tenga descripción y '
                  'habilidades cargadas, y que haya perfiles con esas '
                  'habilidades. Cuando los haya, aparecen acá ordenados.',
        actionLabel: 'Reintentar',
        onAction: _load,
      ),
    );
  }

  // ── Vacante ────────────────────────────────────────────────────────────────

  Widget _bandaVacante() {
    final s = context.mp;
    final v = widget.vacante;

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space12),
      child: Row(
        children: [
          MpIconTile(
            icon: v.confidencial
                ? CupertinoIcons.lock_fill
                : CupertinoIcons.briefcase_fill,
            color: v.confidencial ? MpTokens.catIndigo : MpTokens.primary,
            size: 42,
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  v.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.title.copyWith(color: s.text, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (v.ubicacion != null) v.ubicacion!,
                    if (v.jornada != null) v.jornada!,
                    if (v.modalidad != null) v.modalidad!,
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.micro.copyWith(color: s.textSecondary),
                ),
              ],
            ),
          ),
          if (v.estado != VacanteEstado.desconocido) ...[
            const SizedBox(width: MpTokens.space8),
            MpStatusBadge(
              label: v.estado == VacanteEstado.activa ? 'Activa' : 'Pausada',
              status: v.estado == VacanteEstado.activa
                  ? MpStatus.active
                  : MpStatus.paused,
            ),
          ],
        ],
      ),
    );
  }

  // ── Métricas ───────────────────────────────────────────────────────────────

  Widget _metricas() {
    final s = context.mp;
    final promedio = _data.ajustePromedio;
    final mejor = _data.mejorAjuste;

    final items = <({String valor, String etiqueta})>[
      (valor: '${_data.total}', etiqueta: 'En shortlist'),
      (
        valor: promedio == null ? '—' : '${(promedio * 100).round()}%',
        etiqueta: 'Ajuste promedio',
      ),
      (
        valor: mejor == null ? '—' : '${(mejor * 100).round()}%',
        etiqueta: 'Mejor ajuste',
      ),
      (valor: '${_data.postulados}', etiqueta: 'Postulados'),
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

  // ── Listado ────────────────────────────────────────────────────────────────

  List<Widget> _listado() {
    final visibles = _visibles;

    if (visibles.isEmpty) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: const MpEmptyState(
            icon: CupertinoIcons.search,
            title: 'Sin candidatos en este filtro',
            message: 'Probá con otro filtro de compatibilidad.',
          ),
        ),
      ];
    }

    return [
      for (var i = 0; i < visibles.length; i++) ...[
        _tarjeta(visibles[i], i + 1),
        const SizedBox(height: MpTokens.space12),
      ],
    ];
  }

  Color _colorBanda(BandaAjuste banda) => switch (banda) {
    BandaAjuste.alta => MpTokens.success,
    BandaAjuste.media => MpTokens.premium,
    BandaAjuste.baja => MpTokens.danger,
  };

  Widget _tarjeta(CandidatoShortlist c, int puesto) {
    final s = context.mp;
    final seleccionado = _seleccionados.contains(c.id);
    final banda = c.banda;

    return Container(
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(MpTokens.radiusXL),
        border: Border.all(
          color: seleccionado ? s.accent : s.border,
          width: seleccionado ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(MpTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _puesto(puesto),
              const SizedBox(width: MpTokens.space8),
              MpAvatar(
                name: c.nombreVisible,
                size: 46,
                image: (c.avatarUrl != null && !c.confidencial)
                    ? NetworkImage(c.avatarUrl!)
                    : null,
              ),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.nombreVisible,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          MpTokens.title.copyWith(color: s.text, fontSize: 15.5),
                    ),
                    if (c.headline != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        c.headline!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MpTokens.micro.copyWith(
                          color: s.textSecondary,
                        ),
                      ),
                    ],
                    if (banda != null) ...[
                      const SizedBox(height: MpTokens.space8),
                      MpTypeChip(
                        label: banda.etiqueta,
                        color: _colorBanda(banda),
                      ),
                    ],
                    if (c.postulado) ...[
                      const SizedBox(height: MpTokens.space8),
                      MpTypeChip(
                        label: c.estadoPostulacion == null
                            ? 'Se postuló'
                            : 'Se postuló · ${c.estadoPostulacion}',
                        color: MpTokens.catBlue,
                        icon: CupertinoIcons.paperplane,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: MpTokens.space8),
              _anillo(c),
            ],
          ),
          if (c.tags.isNotEmpty) ...[
            const SizedBox(height: MpTokens.space12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in c.tags.take(4)) MpTagChip(label: t),
              ],
            ),
          ],
          if (c.match != null) ...[
            const SizedBox(height: MpTokens.space12),
            _desglose(c),
          ],
          const SizedBox(height: MpTokens.space12),
          Row(
            children: [
              Expanded(
                child: MpButton(
                  label: 'Ver perfil',
                  icon: CupertinoIcons.person,
                  size: MpButtonSize.small,
                  variant: MpButtonVariant.neutral,
                  expand: true,
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => EmpresaCandidatoPerfilScreen(
                        candidatoId: c.id,
                        // El score ya está calculado para ESTA vacante: se pasa
                        // en vez de recalcular, que daría otro número.
                        match: c.matchPct,
                        vacanteTitulo: widget.vacante.titulo,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: MpTokens.space8),
              Expanded(
                child: MpButton(
                  label: 'Mensaje',
                  icon: CupertinoIcons.chat_bubble,
                  size: MpButtonSize.small,
                  variant: MpButtonVariant.neutral,
                  expand: true,
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => ChatInmailScreen(targetUser: _usuario(c)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: MpTokens.space8),
              _casilla(c, seleccionado),
            ],
          ),
          const SizedBox(height: MpTokens.space8),
          MpButton(
            label: 'Ver Match IA',
            icon: CupertinoIcons.sparkles,
            size: MpButtonSize.small,
            expand: true,
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => EmpresaMatchIaScreen(
                  jobId: widget.vacante.id,
                  candidatoId: c.id,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _puesto(int puesto) {
    final s = context.mp;

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: s.tint(s.accent, alpha: 0.20),
        borderRadius: BorderRadius.circular(MpTokens.radiusXS),
      ),
      alignment: Alignment.center,
      child: Text(
        '$puesto',
        style: MpTokens.micro.copyWith(
          color: s.accent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _anillo(CandidatoShortlist c) {
    final s = context.mp;
    final pct = c.matchPct;

    if (pct == null) {
      return SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.minus_circle, size: 22, color: s.textTertiary),
            const SizedBox(height: MpTokens.space4),
            Text(
              'Sin match\ncalculado',
              textAlign: TextAlign.center,
              style: MpTokens.micro.copyWith(
                color: s.textTertiary,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 62,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MpProgressRing(
            value: c.match!,
            size: 54,
            stroke: 5,
            color: _colorBanda(c.banda!),
            center: Text(
              '$pct%',
              style: MpTokens.label.copyWith(color: s.text, fontSize: 13),
            ),
          ),
          const SizedBox(height: MpTokens.space4),
          Text(
            'Ajuste',
            style: MpTokens.micro.copyWith(color: s.textTertiary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// Desglose real del score: el RPC devuelve las dos señales por separado.
  Widget _desglose(CandidatoShortlist c) {
    final s = context.mp;

    Widget barra(String etiqueta, double valor, Color color) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  etiqueta,
                  style: MpTokens.micro.copyWith(
                    color: s.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ),
              Text(
                '${(valor * 100).round()}%',
                style: MpTokens.micro.copyWith(color: s.text, fontSize: 10.5),
              ),
            ],
          ),
          const SizedBox(height: 4),
          MpProgressBar(value: valor, color: color, height: 5),
        ],
      );
    }

    return Row(
      children: [
        if (c.semantico != null)
          Expanded(
            child: barra('Perfil', c.semantico!, MpTokens.primaryLight),
          ),
        if (c.semantico != null && c.skills != null)
          const SizedBox(width: MpTokens.space12),
        if (c.skills != null)
          Expanded(child: barra('Skills', c.skills!, MpTokens.catBlue)),
      ],
    );
  }

  Widget _casilla(CandidatoShortlist c, bool seleccionado) {
    final s = context.mp;
    final bloqueado =
        !seleccionado && _seleccionados.length >= _maxComparar;

    return GestureDetector(
      onTap: bloqueado ? null : () => _alternarSeleccion(c),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: seleccionado ? s.accent : s.fill,
          borderRadius: BorderRadius.circular(MpTokens.radiusXS),
          border: Border.all(color: seleccionado ? s.accent : s.border),
        ),
        child: Icon(
          seleccionado
              ? CupertinoIcons.check_mark
              : CupertinoIcons.square_split_2x1,
          size: 15,
          color: seleccionado
              ? const Color(0xFFFFFFFF)
              : (bloqueado ? s.textTertiary : s.textSecondary),
        ),
      ),
    );
  }

  // ── Cómo se calcula ────────────────────────────────────────────────────────

  /// El mockup cierra con "Insights de IA" y un resumen redactado. Redactar ese
  /// texto acá sería inventar una conclusión de IA que nadie generó, así que en
  /// su lugar se explica —con datos verificables— cómo se calculó el número.
  Widget _comoSeCalcula() {
    final s = context.mp;
    final promedio = _data.ajustePromedio;

    return MpAiCard(
      title: 'Cómo se calcula el ajuste',
      tag: 'MATCH IA',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'El ajuste combina dos señales: 70% la afinidad entre el texto del '
            'perfil y el de la vacante, y 30% las habilidades que coinciden '
            'con las que pediste.',
            style: MpTokens.body.copyWith(color: s.textSecondary, fontSize: 13.5),
          ),
          if (_data.conMatch.isNotEmpty) ...[
            const SizedBox(height: MpTokens.space16),
            MpDonutChart(
              size: 104,
              thickness: 20,
              compact: true,
              slices: [
                for (final banda in BandaAjuste.values)
                  if (_data.enBanda(banda) > 0)
                    MpDonutSlice(
                      label: banda.etiqueta,
                      value: _data.enBanda(banda).toDouble(),
                      color: _colorBanda(banda),
                    ),
              ],
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_data.conMatch.length}',
                    style: MpTokens.stat.copyWith(color: s.text, fontSize: 20),
                  ),
                  Text(
                    'con match',
                    style: MpTokens.micro.copyWith(
                      color: s.textTertiary,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (promedio != null) ...[
            const SizedBox(height: MpTokens.space12),
            Text(
              'Promedio de ajuste de esta shortlist: '
              '${(promedio * 100).round()}%.',
              style: MpTokens.micro.copyWith(color: s.textTertiary),
            ),
          ],
          if (_data.candidatos.any((c) => c.match == null)) ...[
            const SizedBox(height: MpTokens.space8),
            Text(
              'Los candidatos sin porcentaje se postularon pero todavía no '
              'tienen match calculado.',
              style: MpTokens.micro.copyWith(color: s.textTertiary),
            ),
          ],
        ],
      ),
    );
  }

  // ── Barra de acciones ──────────────────────────────────────────────────────

  Widget _barraAcciones() {
    final s = context.mp;
    final n = _seleccionados.length;

    return Container(
      padding: EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space12,
        MpTokens.screenPadding,
        MediaQuery.of(context).padding.bottom + MpTokens.space12,
      ),
      decoration: BoxDecoration(
        color: s.card,
        border: Border(top: BorderSide(color: s.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              n == 0
                  ? 'Elegí hasta $_maxComparar candidatos para comparar'
                  : '$n de $_maxComparar seleccionados',
              style: MpTokens.micro.copyWith(color: s.textSecondary),
            ),
          ),
          const SizedBox(width: MpTokens.space12),
          MpButton(
            label: 'Comparar',
            icon: CupertinoIcons.square_split_2x1,
            onPressed: n >= 2 ? _comparar : null,
          ),
        ],
      ),
    );
  }
}
