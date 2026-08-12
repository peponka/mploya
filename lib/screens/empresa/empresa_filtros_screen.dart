import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import 'empresa_candidato_perfil_screen.dart';
import 'empresa_filtros_data.dart';

/// Filtros avanzados de talento.
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// RECONSTRUCCIÓN de `ffiltros avanzados.png`, con `busqueda global de
/// talento.png` de apoyo para la ficha de resultado.
///
/// REGLA DE ESTA PANTALLA: cada control que se ve MODIFICA la consulta. No hay
/// un solo filtro decorativo. Por eso el panel es más corto que el mockup.
///
/// OMITIDO del PNG, y por qué. El mockup trae "Años de experiencia" (slider
/// 0–15+), "Nivel de experiencia" (Jr/Semi Sr/Sr/SSr/Director), "Modalidad"
/// (Remoto/Híbrido/Presencial), "Certificaciones", "Idiomas", "Educación
/// mínima", "Disponibilidad" y un toggle "Búsqueda con IA activa".
/// **Ninguno tiene una columna detrás en `users`**: no hay años numéricos, ni
/// seniority, ni certificaciones, ni idiomas, ni nivel educativo estructurado,
/// y la modalidad es un atributo de la VACANTE, no de la persona. Dibujarlos
/// sería poner controles que no cambian nada — el defecto que esta pantalla
/// justamente viene a no cometer.
///
/// El salario tampoco lleva slider: `users.salary_expectation` es texto libre
/// ("USD 2.500", "a convenir", "2000 a 2500"), así que un rango numérico daría
/// resultados falsos. Lo honesto que sí se puede es filtrar por quién lo
/// declaró.
class EmpresaFiltrosScreen extends StatefulWidget {
  /// Filtros con los que abrir. Permite volver a entrar sin perder lo elegido.
  final FiltrosTalento? inicial;

  /// Datos ya resueltos, para los golden tests.
  final ResultadoBusqueda? previewData;

  /// Sugerencias ya resueltas, para los golden tests.
  final List<String>? previewSugerencias;

  const EmpresaFiltrosScreen({
    super.key,
    this.inicial,
    this.previewData,
    this.previewSugerencias,
  });

  @override
  State<EmpresaFiltrosScreen> createState() => _EmpresaFiltrosScreenState();
}

class _EmpresaFiltrosScreenState extends State<EmpresaFiltrosScreen> {
  late FiltrosTalento _f = widget.inicial ?? FiltrosTalento.vacios;
  late final TextEditingController _texto =
      TextEditingController(text: _f.texto);
  late final TextEditingController _ciudad =
      TextEditingController(text: _f.ciudad);

  ResultadoBusqueda _res = ResultadoBusqueda.vacio;
  List<String> _sugerencias = const [];
  bool _loading = true;
  bool _panelAbierto = true;

  static const _radios = [5, 10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    if (widget.previewData != null) {
      _res = widget.previewData!;
      _sugerencias = widget.previewSugerencias ?? const [];
      _loading = false;
      _panelAbierto = false;
      return;
    }
    _cargarSugerencias();
    _buscar();
  }

  @override
  void dispose() {
    _texto.dispose();
    _ciudad.dispose();
    super.dispose();
  }

  Future<void> _cargarSugerencias() async {
    final s = await sugerenciasDeSkills();
    if (!mounted) return;
    setState(() => _sugerencias = s);
  }

  Future<void> _buscar() async {
    if (widget.previewData != null) return;
    if (!mounted) return;
    setState(() => _loading = true);
    final r = await buscarTalento(_f);
    if (!mounted) return;
    setState(() {
      _res = r;
      _loading = false;
    });
  }

  /// Aplica y vuelve a los resultados: cierra el panel y consulta de nuevo.
  Future<void> _aplicar() async {
    setState(() {
      _f = _f.copyWith(texto: _texto.text, ciudad: _ciudad.text);
      _panelAbierto = false;
    });
    await _buscar();
  }

  Future<void> _quitar(String clave) async {
    setState(() {
      _f = _f.sin(clave);
      if (clave == 'texto') _texto.clear();
      if (clave == 'ciudad') _ciudad.clear();
    });
    await _buscar();
  }

  Future<void> _limpiarTodos() async {
    setState(() {
      _f = FiltrosTalento.vacios;
      _texto.clear();
      _ciudad.clear();
    });
    await _buscar();
  }

  void _alternarSkill(String s) {
    setState(() {
      final actuales = [..._f.skills];
      if (actuales.contains(s)) {
        actuales.remove(s);
      } else {
        actuales.add(s);
      }
      _f = _f.copyWith(skills: actuales);
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
                  title: 'Filtros avanzados',
                  subtitle: 'Refiná tu búsqueda de talento.',
                  onBack: () => Navigator.of(context).maybePop(),
                  actions: [
                    MpIconButton(
                      icon: _panelAbierto
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.slider_horizontal_3,
                      onPressed: () =>
                          setState(() => _panelAbierto = !_panelAbierto),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
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
    return [
      if (_f.hayAlguno) ...[
        _chipsActivos(),
        const SizedBox(height: MpTokens.space16),
      ],
      if (_panelAbierto) ...[
        ..._panel(),
        const SizedBox(height: MpTokens.space16),
      ],
      ..._resultados(),
    ];
  }

  // ── Filtros activos, quitables uno por uno ──
  Widget _chipsActivos() {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_f.cantidad} ${_f.cantidad == 1 ? "filtro activo" : "filtros activos"}',
                  style: MpTokens.title.copyWith(color: s.text, fontSize: 14),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: _limpiarTodos,
                child: Text(
                  'Limpiar todos',
                  style: MpTokens.micro.copyWith(
                    color: MpTokens.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space8),
          Wrap(
            spacing: MpTokens.space8,
            runSpacing: MpTokens.space8,
            children: [
              for (final a in _f.activos)
                MpTagChip(
                  label: a.etiqueta,
                  onRemove: () => _quitar(a.clave),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Panel de filtros ──
  List<Widget> _panel() {
    final s = context.mp;

    return [
      const MpSectionHeader(
        title: 'Rol',
        subtitle: 'Busca dentro del titular del perfil.',
      ),
      const SizedBox(height: MpTokens.space12),
      MpTextField(
        controller: _texto,
        placeholder: 'Ej: Product Manager',
        icon: CupertinoIcons.briefcase,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: MpTokens.space24),

      MpSectionHeader(
        title: 'Habilidades',
        subtitle: _sugerencias.isEmpty
            ? 'Todavía no hay habilidades cargadas por candidatos.'
            : 'Las más usadas por los candidatos reales.',
      ),
      const SizedBox(height: MpTokens.space12),
      if (_sugerencias.isNotEmpty)
        Wrap(
          spacing: MpTokens.space8,
          runSpacing: MpTokens.space8,
          children: [
            for (final t in _sugerencias)
              GestureDetector(
                onTap: () => _alternarSkill(t),
                child: Opacity(
                  opacity: _f.skills.contains(t) ? 1 : 0.55,
                  child: MpTagChip(label: t),
                ),
              ),
          ],
        ),
      const SizedBox(height: MpTokens.space24),

      const MpSectionHeader(title: 'Ubicación'),
      const SizedBox(height: MpTokens.space12),
      MpTextField(
        controller: _ciudad,
        placeholder: 'Ciudad',
        icon: CupertinoIcons.placemark,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: MpTokens.space12),
      Text(
        'Radio desde tu empresa',
        style: MpTokens.micro.copyWith(color: s.textSecondary),
      ),
      const SizedBox(height: MpTokens.space8),
      Wrap(
        spacing: MpTokens.space8,
        runSpacing: MpTokens.space8,
        children: [
          for (final km in _radios)
            GestureDetector(
              onTap: () => setState(
                () => _f = _f.radioKm == km
                    ? _f.copyWith(limpiarRadio: true)
                    : _f.copyWith(radioKm: km),
              ),
              child: Opacity(
                opacity: _f.radioKm == km ? 1 : 0.55,
                child: MpTagChip(label: '$km km'),
              ),
            ),
        ],
      ),
      const SizedBox(height: MpTokens.space24),

      const MpSectionHeader(title: 'Otros'),
      const SizedBox(height: MpTokens.space12),
      MpRowGroup(
        rows: [
          MpListRow(
            title: 'Disponibles para propuestas',
            subtitle: 'El candidato marcó que está abierto a ofertas.',
            showChevron: false,
            titleMaxLines: 2,
            trailing: CupertinoSwitch(
              value: _f.soloDisponibles,
              activeTrackColor: MpTokens.primary,
              onChanged: (v) =>
                  setState(() => _f = _f.copyWith(soloDisponibles: v)),
            ),
          ),
          MpListRow(
            title: 'Sólo perfiles verificados',
            showChevron: false,
            titleMaxLines: 2,
            trailing: CupertinoSwitch(
              value: _f.soloVerificados,
              activeTrackColor: MpTokens.primary,
              onChanged: (v) =>
                  setState(() => _f = _f.copyWith(soloVerificados: v)),
            ),
          ),
          MpListRow(
            title: 'Con expectativa salarial declarada',
            subtitle: 'El monto es texto libre, así que no se puede filtrar '
                'por rango: sólo por si lo declaró.',
            showChevron: false,
            titleMaxLines: 3,
            trailing: CupertinoSwitch(
              value: _f.soloConExpectativa,
              activeTrackColor: MpTokens.primary,
              onChanged: (v) =>
                  setState(() => _f = _f.copyWith(soloConExpectativa: v)),
            ),
          ),
        ],
      ),
      const SizedBox(height: MpTokens.space16),
      MpButton(
        label: 'Aplicar filtros',
        icon: CupertinoIcons.search,
        expand: true,
        onPressed: _aplicar,
      ),
    ];
  }

  // ── Resultados ──
  List<Widget> _resultados() {
    final s = context.mp;

    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: MpTokens.space32),
          child: Center(child: CupertinoActivityIndicator(radius: 15)),
        ),
      ];
    }

    if (_res.error) {
      return [
        MpEmptyState(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: 'No pudimos buscar',
          message: 'Revisá tu conexión y volvé a intentar.',
          actionLabel: 'Reintentar',
          onAction: _buscar,
        ),
      ];
    }

    final bloques = <Widget>[];

    if (_res.sinCoordenadasPropias) {
      bloques
        ..add(
          const MpBanner(
            icon: CupertinoIcons.placemark,
            title: 'No pudimos aplicar el radio',
            message: 'Tu empresa todavía no tiene ubicación cargada, así que no '
                'hay desde dónde medir la distancia.',
            color: MpTokens.premium,
          ),
        )
        ..add(const SizedBox(height: MpTokens.space16));
    }

    if (_res.talentos.isEmpty) {
      bloques.add(
        MpEmptyState(
          icon: CupertinoIcons.person_2,
          title: _f.hayAlguno
              ? 'Ningún candidato con esos filtros'
              : 'Todavía no hay candidatos',
          message: _f.hayAlguno
              ? 'Probá quitando alguno: cada filtro achica la lista de verdad.'
              : 'Cuando haya perfiles cargados vas a poder filtrarlos acá.',
          actionLabel: _f.hayAlguno ? 'Limpiar todos' : null,
          onAction: _f.hayAlguno ? _limpiarTodos : null,
        ),
      );
      return bloques;
    }

    bloques
      ..add(
        Text(
          '${_res.talentos.length} '
          '${_res.talentos.length == 1 ? "candidato" : "candidatos"}',
          style: MpTokens.h2.copyWith(color: s.text, fontSize: 17),
        ),
      )
      ..add(const SizedBox(height: MpTokens.space12));

    for (final t in _res.talentos) {
      bloques
        ..add(_ficha(t))
        ..add(const SizedBox(height: MpTokens.space8));
    }

    return bloques;
  }

  Widget _ficha(TalentoEncontrado t) {
    final s = context.mp;
    final detalle = <String>[
      if (t.ciudad != null) t.ciudad!,
      if (t.distanciaKm != null)
        t.distanciaKm! < 1
            ? '<1 km'
            : '${t.distanciaKm!.toStringAsFixed(t.distanciaKm! < 10 ? 1 : 0)} km',
      if (t.expectativa != null) t.expectativa!,
    ];

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space12),
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => EmpresaCandidatoPerfilScreen(candidatoId: t.id),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MpAvatar(
            name: t.nombre,
            size: 46,
            image: t.avatarUrl == null ? null : NetworkImage(t.avatarUrl!),
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        t.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MpTokens.title
                            .copyWith(color: s.text, fontSize: 15),
                      ),
                    ),
                    if (t.verificado) ...[
                      const SizedBox(width: 4),
                      const MpVerifiedBadge(size: 14),
                    ],
                  ],
                ),
                if (t.headline != null)
                  Text(
                    t.headline!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.micro.copyWith(color: s.textSecondary),
                  ),
                if (detalle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detalle.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.micro.copyWith(color: s.textTertiary),
                  ),
                ],
                if (t.tags.isNotEmpty) ...[
                  const SizedBox(height: MpTokens.space8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in t.tags.take(3)) MpTagChip(label: tag),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (t.disponible) ...[
            const SizedBox(width: MpTokens.space8),
            const MpStatusBadge(label: 'Disponible', status: MpStatus.active),
          ],
        ],
      ),
    );
  }
}
