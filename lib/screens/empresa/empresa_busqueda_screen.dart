import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import 'empresa_busqueda_data.dart';
import 'empresa_candidato_perfil_screen.dart';
import 'empresa_confidenciales_screen.dart';
import 'empresa_perfil_screen.dart';

/// Búsqueda de talento (Empresa móvil).
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 11/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ║ Su golden es protección de regresión: si falla, averiguar por qué     ║
/// ║ antes de regenerarlo.                                                 ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// RECONSTRUCCIÓN DIRECTA de `usqueda IA avanada.png` (Pantalla 11), que es
/// móvil y trae la barra inferior de Empresa: título con la chispa, buscador
/// grande, "Búsquedas recientes", las cuatro tarjetas de búsqueda inteligente,
/// los filtros rápidos en filas con valor a la derecha y el CTA "Buscar con IA".
/// Los resultados siguen el patrón de `busqueda global de talento.png` (25),
/// que es la versión de escritorio: ficha con match, ubicación y etiquetas.
///
/// DATOS. Dos motores, ambos reales y bien diferenciados, porque no significan
/// lo mismo:
///   · TEXTO — `ilike` sobre nombre y titular + coincidencia de etiquetas. No
///     produce score, así que las fichas salen SIN porcentaje.
///   · IA — `match_users_by_embedding` (migración 019). Devuelve un score real
///     y ahí sí se muestra el porcentaje.
///
/// OMITIDO. Del PNG no están: el dictado por voz (no hay reconocimiento de voz
/// en el proyecto), "Búsquedas recientes" persistidas (no hay tabla; las de esta
/// sesión sí se guardan en memoria), los filtros de idioma, disponibilidad y
/// salario esperado —`users` no tiene esos campos como dato consultable— y el
/// mapa de calor de talento por país.
class EmpresaBusquedaScreen extends StatefulWidget {
  /// Datos ya resueltos, para los golden tests.
  final BusquedaData? previewData;

  /// Etiquetas ya resueltas, para los golden tests.
  final List<String>? previewEtiquetas;

  const EmpresaBusquedaScreen({
    super.key,
    this.previewData,
    this.previewEtiquetas,
  });

  @override
  State<EmpresaBusquedaScreen> createState() => _EmpresaBusquedaScreenState();
}

class _EmpresaBusquedaScreenState extends State<EmpresaBusquedaScreen> {
  final _buscador = TextEditingController();

  BusquedaData? _data;
  List<String> _etiquetas = const [];
  final _elegidas = <String>{};
  final _recientes = <String>[];

  bool _buscando = false;
  bool _cargandoEtiquetas = true;

  @override
  void initState() {
    super.initState();
    if (widget.previewData != null || widget.previewEtiquetas != null) {
      _data = widget.previewData;
      _etiquetas = widget.previewEtiquetas ?? const [];
      _cargandoEtiquetas = false;
      return;
    }
    _cargarEtiquetas();
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargarEtiquetas() async {
    final tags = await loadEtiquetasFrecuentes();
    if (!mounted) return;
    setState(() {
      _etiquetas = tags;
      _cargandoEtiquetas = false;
    });
  }

  bool get _hayCriterio =>
      _buscador.text.trim().isNotEmpty || _elegidas.isNotEmpty;

  Future<void> _buscarTexto() async {
    if (!_hayCriterio || _buscando) return;
    FocusScope.of(context).unfocus();

    final termino = _buscador.text.trim();
    setState(() => _buscando = true);

    final data = await buscarTalentoPorTexto(
      termino,
      etiquetas: _elegidas.toList(),
    );
    if (!mounted) return;

    setState(() {
      _data = data;
      _buscando = false;
      if (termino.isNotEmpty) {
        _recientes.remove(termino);
        _recientes.insert(0, termino);
        if (_recientes.length > 5) _recientes.removeLast();
      }
    });
  }

  Future<void> _buscarIa() async {
    if (_buscando) return;
    FocusScope.of(context).unfocus();
    setState(() => _buscando = true);

    final data = await buscarTalentoConIa();
    if (!mounted) return;
    setState(() {
      _data = data;
      _buscando = false;
    });
  }

  void _limpiar() {
    setState(() {
      _buscador.clear();
      _elegidas.clear();
      _data = null;
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
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        MpTokens.screenPadding,
                        MpTokens.space8,
                        MpTokens.screenPadding,
                        MpTokens.space24 +
                            MediaQuery.of(context).viewInsets.bottom,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(_cuerpo()),
                      ),
                    ),
                  ],
                ),
              ),
              _barraAcciones(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _cuerpo() {
    return [
      // Ritmo vertical: cada bloque respira más que sus elementos internos, así
      // se leen como secciones y no como una lista continua.
      _encabezado(),
      const SizedBox(height: MpTokens.space20),
      _buscadorWidget(),
      if (_recientes.isNotEmpty) ...[
        const SizedBox(height: MpTokens.space20),
        _busquedasRecientes(),
      ],
      const SizedBox(height: MpTokens.space24),
      _filtrosRapidos(),
      const SizedBox(height: MpTokens.space24),
      _atajoConfidenciales(),
      const SizedBox(height: MpTokens.space32),
      ..._resultados(),
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
              Row(
                children: [
                  Text(
                    'Buscar talento',
                    style: MpTokens.h1.copyWith(color: s.text),
                  ),
                  const SizedBox(width: MpTokens.space8),
                  const Icon(
                    CupertinoIcons.sparkles,
                    size: 20,
                    color: MpTokens.primary,
                  ),
                ],
              ),
              const SizedBox(height: MpTokens.space4),
              Text(
                'Encontrá el talento ideal más rápido.',
                style: MpTokens.body.copyWith(
                  color: s.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buscadorWidget() {
    return MpTextField(
      controller: _buscador,
      placeholder: 'Ej: UX Designer con experiencia en Fintech',
      icon: CupertinoIcons.search,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _busquedasRecientes() {
    final s = context.mp;

    return MpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Búsquedas de esta sesión',
                  style: MpTokens.title.copyWith(color: s.text, fontSize: 15),
                ),
              ),
              MpButton(
                label: 'Limpiar',
                variant: MpButtonVariant.ghost,
                size: MpButtonSize.small,
                onPressed: () => setState(_recientes.clear),
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space4),
          // El mockup las muestra persistidas; no hay tabla donde guardarlas,
          // así que se dice con todas las letras que duran lo que la sesión.
          Text(
            'No se guardan al cerrar la app.',
            style: MpTokens.micro.copyWith(color: s.textTertiary),
          ),
          const SizedBox(height: MpTokens.space8),
          for (final r in _recientes)
            GestureDetector(
              onTap: () {
                _buscador.text = r;
                _buscarTexto();
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.clock, size: 15, color: s.textTertiary),
                    const SizedBox(width: MpTokens.space8),
                    Expanded(
                      child: Text(
                        r,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MpTokens.body.copyWith(
                          color: s.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _recientes.remove(r)),
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 14,
                        color: s.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Los "filtros rápidos" del PNG, con el único eje que la base sabe filtrar
  /// de verdad: las etiquetas que los candidatos tienen cargadas.
  Widget _filtrosRapidos() {
    final s = context.mp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Filtrar por habilidad',
                style: MpTokens.h2.copyWith(color: s.text, fontSize: 17),
              ),
            ),
            if (_elegidas.isNotEmpty)
              MpButton(
                label: 'Limpiar todo',
                variant: MpButtonVariant.ghost,
                size: MpButtonSize.small,
                onPressed: _limpiar,
              ),
          ],
        ),
        const SizedBox(height: MpTokens.space12),
        if (_cargandoEtiquetas)
          const Center(child: CupertinoActivityIndicator())
        else if (_etiquetas.isEmpty)
          Text(
            'Todavía no hay habilidades cargadas en los perfiles.',
            style: MpTokens.caption.copyWith(color: s.textTertiary),
          )
        else
          // Chips livianos a propósito: son un filtro, no una acción. Compiten
          // visualmente con los CTA si llevan el peso de un botón.
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final t in _etiquetas)
                GestureDetector(
                  onTap: () => setState(() {
                    if (!_elegidas.remove(t)) _elegidas.add(t);
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _elegidas.contains(t)
                          ? s.tint(s.accent, alpha: 0.10)
                          : s.fill,
                      borderRadius: BorderRadius.circular(MpTokens.radiusXS),
                      border: Border.all(
                        color: _elegidas.contains(t)
                            ? s.accent.withValues(alpha: 0.55)
                            : s.border,
                      ),
                    ),
                    child: Text(
                      t,
                      style: MpTokens.micro.copyWith(
                        color:
                            _elegidas.contains(t) ? s.accent : s.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// Acceso secundario, no un filtro más: va separado del bloque de filtros,
  /// sobre superficie tintada y con su propio color de rol (índigo
  /// confidencial), para que se lea como otra sección del producto.
  Widget _atajoConfidenciales() {
    final s = context.mp;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => const EmpresaConfidencialesScreen(),
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(MpTokens.space16),
        decoration: BoxDecoration(
          color: s.tint(MpTokens.catIndigo, alpha: 0.06),
          borderRadius: BorderRadius.circular(MpTokens.radiusXL),
          border: Border.all(
            color: MpTokens.catIndigo.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            const MpIconTile(
              icon: CupertinoIcons.lock_fill,
              color: MpTokens.catIndigo,
              size: 44,
              circular: true,
            ),
            const SizedBox(width: MpTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Talento confidencial',
                    style: MpTokens.title.copyWith(color: s.text, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Perfiles reservados que se desbloquean con créditos.',
                    style: MpTokens.caption.copyWith(color: s.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: MpTokens.space8),
            Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: MpTokens.catIndigo,
            ),
          ],
        ),
      ),
    );
  }

  // ── Resultados ─────────────────────────────────────────────────────────────

  List<Widget> _resultados() {
    final s = context.mp;
    final data = _data;

    if (_buscando) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: MpTokens.space32),
          child: Center(child: CupertinoActivityIndicator(radius: 14)),
        ),
      ];
    }

    if (data == null) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: const MpEmptyState(
            icon: CupertinoIcons.search,
            title: 'Buscá tu próximo candidato',
            message: 'Escribí un puesto o elegí habilidades, y buscá. O dejá '
                'que la IA te recomiende perfiles afines a tu empresa.',
          ),
        ),
      ];
    }

    if (data.error) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: MpEmptyState(
            icon: CupertinoIcons.exclamationmark_triangle,
            title: 'La búsqueda falló',
            message: 'Revisá tu conexión y volvé a intentar.',
            actionLabel: 'Reintentar',
            onAction: data.modo == ModoBusqueda.ia ? _buscarIa : _buscarTexto,
          ),
        ),
      ];
    }

    if (data.sinEmbedding) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: MpEmptyState(
            icon: CupertinoIcons.sparkles,
            title: 'La IA todavía no puede recomendarte',
            message: 'Necesita el perfil de tu empresa cargado para saber qué '
                'buscás. Completá tu descripción y volvé a intentar.',
            // El vacío nombra la causa y ofrece la salida exacta, en vez de
            // dejar al usuario adivinando qué le falta.
            actionLabel: 'Completar perfil',
            // Va al Perfil de Empresa, no al formulario legacy. La edición
            // (`EmpresaEditarPerfilScreen`) necesita la empresa ya cargada, y
            // el Perfil es justamente quien la carga y ofrece "Completar
            // perfil" en primer plano cuando está incompleto.
            onAction: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => const EmpresaPerfilScreen(),
              ),
            ),
          ),
        ),
      ];
    }

    if (data.total == 0) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: const MpEmptyState(
            icon: CupertinoIcons.person_2,
            title: 'Sin resultados',
            message: 'Probá con otras palabras o quitá algún filtro.',
          ),
        ),
      ];
    }

    return [
      Row(
        children: [
          Expanded(
            child: Text(
              '${data.total} '
              '${data.total == 1 ? 'candidato' : 'candidatos'}',
              style: MpTokens.h2.copyWith(color: s.text, fontSize: 17),
            ),
          ),
          MpTypeChip(
            label: data.modo == ModoBusqueda.ia ? 'Por IA' : 'Por texto',
            color: data.modo == ModoBusqueda.ia
                ? MpTokens.primary
                : MpTokens.catBlue,
            icon: data.modo == ModoBusqueda.ia
                ? CupertinoIcons.sparkles
                : CupertinoIcons.search,
          ),
        ],
      ),
      const SizedBox(height: MpTokens.space4),
      Text(
        data.modo == ModoBusqueda.ia
            ? 'Ordenados por afinidad con el perfil de tu empresa.'
            : 'Coinciden con el texto o las habilidades que pediste. La '
                'búsqueda por texto no calcula match.',
        style: MpTokens.micro.copyWith(color: s.textTertiary),
      ),
      const SizedBox(height: MpTokens.space12),
      for (final r in data.resultados) ...[
        _ficha(r),
        const SizedBox(height: MpTokens.space8),
      ],
    ];
  }

  Widget _ficha(ResultadoTalento r) {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space12),
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => EmpresaCandidatoPerfilScreen(
            candidatoId: r.usuario.id,
            match: r.match,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MpAvatar(
            name: r.nombreVisible,
            size: 46,
            image: (r.usuario.avatarUrl != null && !r.confidencial)
                ? NetworkImage(r.usuario.avatarUrl!)
                : null,
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
                        r.nombreVisible,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MpTokens.title.copyWith(
                          color: s.text,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (r.usuario.isVerified) ...[
                      const SizedBox(width: 5),
                      const MpVerifiedBadge(size: 13),
                    ],
                  ],
                ),
                if (r.usuario.headline.isNotEmpty)
                  Text(
                    r.usuario.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.micro.copyWith(color: s.textSecondary),
                  ),
                if ((r.usuario.location?.isNotEmpty ?? false) &&
                    !r.confidencial)
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.placemark,
                        size: 11,
                        color: s.textTertiary,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          r.usuario.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MpTokens.micro.copyWith(
                            color: s.textTertiary,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (r.usuario.tags.isNotEmpty) ...[
                  const SizedBox(height: MpTokens.space8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in r.usuario.tags.take(3))
                        MpTagChip(label: t.replaceAll('#', '').trim()),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (r.match != null) ...[
            const SizedBox(width: MpTokens.space8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${r.match}%',
                  style: MpTokens.title.copyWith(
                    color: MpTokens.successDeep,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Match IA',
                  style: MpTokens.micro.copyWith(
                    color: s.textTertiary,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Barra de acciones ──────────────────────────────────────────────────────

  Widget _barraAcciones() {
    final s = context.mp;

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
            child: MpButton(
              label: 'Buscar',
              icon: CupertinoIcons.search,
              variant: MpButtonVariant.neutral,
              expand: true,
              onPressed: _hayCriterio ? _buscarTexto : null,
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          Expanded(
            flex: 2,
            child: MpButton(
              label: 'Buscar con IA',
              icon: CupertinoIcons.sparkles,
              expand: true,
              loading: _buscando,
              onPressed: _buscarIa,
            ),
          ),
        ],
      ),
    );
  }
}
