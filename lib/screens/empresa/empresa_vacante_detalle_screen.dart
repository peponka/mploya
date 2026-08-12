import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import 'empresa_candidato_perfil_screen.dart';
import 'empresa_comparar_screen.dart';
import 'empresa_pipeline_screen.dart';
import 'empresa_shortlist_data.dart';
import 'empresa_shortlist_screen.dart';
import 'empresa_vacante_analytics_screen.dart';
import 'empresa_vacante_detalle_data.dart';
import 'empresa_vacantes_data.dart';

/// Detalle de una vacante PROPIA (rol Empresa).
///
/// DERIVACIÓN CONTROLADA. El PNG `detalle de vacantes.png` (Pantalla 44) es la
/// ficha vista por un CANDIDATO: su acción principal es "Postularme ahora",
/// muestra "¿Por qué te mostramos esta vacante?" y "Consejo de IA" dirigido al
/// postulante. Nada de eso existe cuando la vacante es tuya.
///
/// Lo que SÍ se conserva del PNG, porque es su estructura:
///   · ficha con logo, título, chips de estado y meta (modalidad · ubicación)
///   · la fila de cuatro datos duros (salario · experiencia · jornada · horario)
///   · el cuerpo por pestañas (Descripción · Requisitos · …)
///   · la barra de acciones fija al pie
///
/// Y se reemplaza el eje candidato por el de empresa: postulantes reales,
/// shortlist, pipeline y pausar/activar. El bloque de métricas toma su forma de
/// `analytics de vacantes.png`, pero sólo con los números que la base da.
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
class EmpresaVacanteDetalleScreen extends StatefulWidget {
  /// Vacante de la lista. Se usa para pintar la ficha al instante mientras
  /// llega el detalle completo.
  final Vacante vacante;

  /// Detalle ya resuelto, para los golden tests (sin backend).
  final VacanteDetalle? previewData;

  const EmpresaVacanteDetalleScreen({
    super.key,
    required this.vacante,
    this.previewData,
  });

  @override
  State<EmpresaVacanteDetalleScreen> createState() =>
      _EmpresaVacanteDetalleScreenState();
}

class _EmpresaVacanteDetalleScreenState
    extends State<EmpresaVacanteDetalleScreen> {
  VacanteDetalle? _detalle;
  bool _loading = true;
  bool _cambiandoEstado = false;
  String? _aviso;

  int _tab = 0;

  @override
  void initState() {
    super.initState();
    if (widget.previewData != null) {
      _detalle = widget.previewData;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (widget.previewData != null) return;
    if (!mounted) return;
    setState(() => _loading = true);
    final detalle = await loadVacanteDetalle(widget.vacante.id);
    if (!mounted) return;
    setState(() {
      _detalle = detalle;
      _loading = false;
    });
  }

  Vacante get _vacante => _detalle?.vacante ?? widget.vacante;

  Future<void> _alternarEstado() async {
    final actual = _vacante.estado;
    if (actual == VacanteEstado.desconocido || _cambiandoEstado) return;

    final activar = actual == VacanteEstado.pausada;
    setState(() {
      _cambiandoEstado = true;
      _aviso = null;
    });

    final ok = await setVacanteActiva(_vacante.id, activar);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _cambiandoEstado = false;
        _aviso = 'No pudimos cambiar el estado de la vacante.';
      });
      return;
    }

    await _load();
    if (!mounted) return;
    setState(() => _cambiandoEstado = false);
  }

  void _abrirShortlist() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => EmpresaShortlistScreen(vacante: _vacante),
      ),
    );
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
                  title: 'Detalle de Vacante',
                  centerTitle: true,
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
              if (!_loading) _barraAcciones(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _cuerpo() {
    return [
      _ficha(),
      const SizedBox(height: MpTokens.space12),
      if (_datosDuros().isNotEmpty) ...[
        _filaDatosDuros(),
        const SizedBox(height: MpTokens.space12),
      ],
      _metricas(),
      if (_aviso != null) ...[
        const SizedBox(height: MpTokens.space12),
        _bannerAviso(),
      ],
      const SizedBox(height: MpTokens.space20),
      MpSegmentedFilter(
        options: [
          const MpFilterOption('Descripción'),
          MpFilterOption('Requisitos', count: _vacante.tags.length),
          MpFilterOption(
            'Candidatos',
            count: _detalle?.postulantesNoDisponibles == true
                ? null
                : _detalle?.totalPostulantes ?? _vacante.candidatos,
          ),
        ],
        selectedIndex: _tab,
        onChanged: (i) => setState(() => _tab = i),
        scrollable: true,
      ),
      const SizedBox(height: MpTokens.space16),
      ..._contenidoTab(),
      const SizedBox(height: MpTokens.space24),
      _accesos(),
    ];
  }

  // ── Ficha ──────────────────────────────────────────────────────────────────

  Widget _ficha() {
    final s = context.mp;
    final v = _vacante;

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MpIconTile(
                icon: v.confidencial
                    ? CupertinoIcons.lock_fill
                    : CupertinoIcons.briefcase_fill,
                color: v.confidencial ? MpTokens.catIndigo : MpTokens.primary,
                size: 54,
              ),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.titulo,
                      style: MpTokens.h2.copyWith(color: s.text),
                    ),
                    const SizedBox(height: MpTokens.space8),
                    Wrap(
                      spacing: MpTokens.space8,
                      runSpacing: MpTokens.space8,
                      children: [
                        if (v.estado != VacanteEstado.desconocido)
                          MpStatusBadge(
                            label: v.estado == VacanteEstado.activa
                                ? 'Activa'
                                : 'Pausada',
                            status: v.estado == VacanteEstado.activa
                                ? MpStatus.active
                                : MpStatus.paused,
                          ),
                        if (v.confidencial)
                          const MpTypeChip(
                            label: 'Confidencial',
                            color: MpTokens.catIndigo,
                            icon: CupertinoIcons.lock,
                          ),
                        if (v.modalidad != null)
                          MpTypeChip(
                            label: v.modalidad!,
                            color: MpTokens.catGreen,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space12),
          Wrap(
            spacing: MpTokens.space12,
            runSpacing: MpTokens.space4,
            children: [
              if (v.ubicacion != null)
                _meta(CupertinoIcons.placemark, v.ubicacion!),
              if (v.antiguedad != null)
                _meta(CupertinoIcons.clock, v.antiguedad!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String texto) {
    final s = context.mp;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: s.textTertiary),
        const SizedBox(width: 5),
        Text(
          texto,
          style: MpTokens.caption.copyWith(color: s.textSecondary),
        ),
      ],
    );
  }

  // ── Datos duros ────────────────────────────────────────────────────────────

  /// Sólo los campos que la fila trae. El mockup muestra cuatro siempre; acá si
  /// la vacante no declara salario, no hay casilla de salario.
  List<({IconData icon, String valor, String etiqueta})> _datosDuros() {
    final v = _vacante;
    final d = _detalle;

    return [
      if (v.salario != null)
        (
          icon: CupertinoIcons.money_dollar_circle,
          valor: v.salario!,
          etiqueta: 'Rango salarial',
        ),
      if (d?.experiencia != null)
        (
          icon: CupertinoIcons.chart_bar,
          valor: d!.experiencia!,
          etiqueta: 'Experiencia',
        ),
      if (v.jornada != null)
        (
          icon: CupertinoIcons.briefcase,
          valor: v.jornada!,
          etiqueta: 'Tipo de trabajo',
        ),
      if (d?.horario != null)
        (
          icon: CupertinoIcons.time,
          valor: d!.horario!,
          etiqueta: 'Horario',
        ),
    ];
  }

  Widget _filaDatosDuros() {
    final s = context.mp;
    final datos = _datosDuros();

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
            for (var i = 0; i < datos.length; i++) ...[
              if (i > 0)
                Container(width: 1, color: s.border),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MpTokens.space8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(datos[i].icon, size: 16, color: s.textSecondary),
                      const SizedBox(height: MpTokens.space8),
                      Text(
                        datos[i].valor,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MpTokens.micro.copyWith(
                          color: s.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        datos[i].etiqueta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MpTokens.micro.copyWith(
                          color: s.textTertiary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Métricas ───────────────────────────────────────────────────────────────

  Widget _metricas() {
    final d = _detalle;

    final tiles = <Widget>[
      MpStatTile(
        icon: CupertinoIcons.person_2,
        color: MpTokens.primary,
        value: d?.postulantesNoDisponibles == true
            ? '—'
            : '${d?.totalPostulantes ?? _vacante.candidatos}',
        label: 'Postulaciones',
        compact: true,
      ),
      if (d?.entrevistas != null)
        MpStatTile(
          icon: CupertinoIcons.calendar,
          color: MpTokens.catBlue,
          value: '${d!.entrevistas}',
          label: 'Entrevistas',
          compact: true,
        ),
      MpStatTile(
        icon: CupertinoIcons.tag,
        color: MpTokens.catGreen,
        value: '${_vacante.tags.length}',
        label: 'Requisitos',
        compact: true,
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

  Widget _bannerAviso() {
    return MpBanner(
      icon: CupertinoIcons.exclamationmark_triangle,
      title: 'No se pudo aplicar el cambio',
      message: _aviso!,
      color: MpTokens.danger,
    );
  }

  // ── Pestañas ───────────────────────────────────────────────────────────────

  List<Widget> _contenidoTab() {
    return switch (_tab) {
      0 => _tabDescripcion(),
      1 => _tabRequisitos(),
      _ => _tabCandidatos(),
    };
  }

  List<Widget> _tabDescripcion() {
    final s = context.mp;
    final d = _detalle;

    if (d == null || !d.tieneDescripcion) {
      return [
        MpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sin descripción',
                style: MpTokens.title.copyWith(color: s.text),
              ),
              const SizedBox(height: MpTokens.space4),
              Text(
                'Esta vacante se publicó sin descripción. Los candidatos ven '
                'sólo el título, los requisitos y las condiciones.',
                style: MpTokens.body.copyWith(
                  color: s.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      MpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Descripción del puesto',
              style: MpTokens.title.copyWith(color: s.text),
            ),
            const SizedBox(height: MpTokens.space12),
            Text(
              d.descripcion!,
              style: MpTokens.body.copyWith(color: s.textSecondary),
            ),
          ],
        ),
      ),
      if (d.extras != null) ...[
        const SizedBox(height: MpTokens.space12),
        MpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Extras', style: MpTokens.title.copyWith(color: s.text)),
              const SizedBox(height: MpTokens.space8),
              Text(
                d.extras!,
                style: MpTokens.body.copyWith(
                  color: s.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _tabRequisitos() {
    final s = context.mp;
    final tags = _vacante.tags;

    if (tags.isEmpty) {
      return [
        MpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sin requisitos cargados',
                style: MpTokens.title.copyWith(color: s.text),
              ),
              const SizedBox(height: MpTokens.space4),
              Text(
                'Los requisitos son las habilidades con las que el match busca '
                'candidatos. Sin ellos el match usa sólo el texto de la vacante.',
                style: MpTokens.body.copyWith(
                  color: s.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      MpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Habilidades requeridas',
              style: MpTokens.title.copyWith(color: s.text),
            ),
            const SizedBox(height: MpTokens.space12),
            Wrap(
              spacing: MpTokens.space8,
              runSpacing: MpTokens.space8,
              children: [for (final t in tags) MpTagChip(label: t)],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _tabCandidatos() {
    final s = context.mp;
    final d = _detalle;

    if (d != null && d.postulantesNoDisponibles) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: MpEmptyState(
            icon: CupertinoIcons.exclamationmark_triangle,
            title: 'No pudimos leer las postulaciones',
            message: 'Puede ser un problema de conexión o de permisos.',
            actionLabel: 'Reintentar',
            onAction: _load,
          ),
        ),
      ];
    }

    final postulantes = d?.postulantes ?? const <PostulanteVacante>[];
    if (postulantes.isEmpty) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: MpEmptyState(
            icon: CupertinoIcons.person_2,
            title: 'Todavía no hay postulaciones',
            message: 'Mientras tanto podés buscar candidatos compatibles con '
                'la shortlist inteligente.',
            actionLabel: 'Ver shortlist',
            onAction: _abrirShortlist,
          ),
        ),
      ];
    }

    return [
      MpRowGroup(
        dividerIndent: 62,
        rows: [
          for (final p in postulantes)
            MpListRow(
              leading: MpAvatar(
                name: p.nombre,
                size: 42,
                image: p.avatarUrl == null ? null : NetworkImage(p.avatarUrl!),
              ),
              title: p.nombre,
              subtitle: p.headline,
              trailingText: _fecha(p.postuladoEl),
              badge: p.estado == null
                  ? null
                  : MpTypeChip(label: p.estado!, color: MpTokens.catBlue),
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => EmpresaCandidatoPerfilScreen(
                    candidatoId: p.candidatoId,
                    vacanteTitulo: _vacante.titulo,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: MpTokens.space12),
      Text(
        'Postulaciones reales a esta vacante.',
        style: MpTokens.micro.copyWith(color: s.textTertiary),
      ),
    ];
  }

  String? _fecha(DateTime? fecha) {
    if (fecha == null) return null;
    final diff = DateTime.now().difference(fecha);
    if (diff.inDays >= 1) return 'Hace ${diff.inDays} d';
    if (diff.inHours >= 1) return 'Hace ${diff.inHours} h';
    return 'Recién';
  }

  // ── Accesos y barra de acciones ────────────────────────────────────────────

  Widget _accesos() {
    final d = _detalle;
    final puedeComparar = (d?.postulantes.length ?? 0) >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MpSectionHeader(title: 'Acciones'),
        const SizedBox(height: MpTokens.space12),
        MpRowGroup(
          dividerIndent: 62,
          rows: [
            MpListRow(
              leading: const MpIconTile(
                icon: CupertinoIcons.sparkles,
                color: MpTokens.primary,
                size: 42,
              ),
              title: 'Shortlist inteligente',
              subtitle: 'Candidatos ordenados por match con esta vacante.',
              onTap: _abrirShortlist,
            ),
            MpListRow(
              leading: const MpIconTile(
                icon: CupertinoIcons.chart_bar_alt_fill,
                color: MpTokens.catBlue,
                size: 42,
              ),
              title: 'Analytics de la vacante',
              subtitle: 'Postulaciones, evolución y entrevistas.',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) =>
                      EmpresaVacanteAnalyticsScreen(vacante: _vacante),
                ),
              ),
            ),
            MpListRow(
              leading: const MpIconTile(
                icon: CupertinoIcons.person_2,
                color: MpTokens.catOrange,
                size: 42,
              ),
              title: 'Pipeline',
              subtitle: 'Seguimiento por etapa de todos tus candidatos.',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const EmpresaPipelineScreen()),
              ),
            ),
            if (puedeComparar)
              MpListRow(
                leading: const MpIconTile(
                  icon: CupertinoIcons.square_split_2x1,
                  color: MpTokens.catBlue,
                  size: 42,
                ),
                title: 'Comparar postulantes',
                subtitle: 'Compará los perfiles que se postularon.',
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => EmpresaCompararScreen(
                      vacante: _vacante,
                      candidatos: [
                        for (final p in d!.postulantes.take(4))
                          candidatoDesdePostulante(p),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _barraAcciones() {
    final s = context.mp;
    final v = _vacante;
    final puedePausar = v.estado != VacanteEstado.desconocido;

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
          if (puedePausar) ...[
            Expanded(
              child: MpButton(
                label: v.estado == VacanteEstado.activa ? 'Pausar' : 'Activar',
                icon: v.estado == VacanteEstado.activa
                    ? CupertinoIcons.pause
                    : CupertinoIcons.play,
                variant: MpButtonVariant.neutral,
                expand: true,
                loading: _cambiandoEstado,
                onPressed: _alternarEstado,
              ),
            ),
            const SizedBox(width: MpTokens.space8),
          ],
          Expanded(
            flex: puedePausar ? 1 : 2,
            child: MpButton(
              label: 'Ver shortlist',
              icon: CupertinoIcons.sparkles,
              expand: true,
              onPressed: _abrirShortlist,
            ),
          ),
        ],
      ),
    );
  }
}
