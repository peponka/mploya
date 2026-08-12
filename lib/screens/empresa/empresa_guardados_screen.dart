import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import '../chat_inmail_screen.dart';
import 'empresa_candidato_perfil_screen.dart';
import 'empresa_guardados_data.dart';
import 'empresa_talent_feed_screen.dart';

/// Candidatos guardados de la Empresa.
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 11/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ║ Su golden es protección de regresión: si falla, averiguar por qué     ║
/// ║ antes de regenerarlo.                                                 ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// DERIVACIÓN CONTROLADA de `ffavoritos y colecciones.png` (Pantalla 54), que es
/// una pantalla de Empresa móvil sobre superficie oscura. Se conservan su banda
/// de métricas, la fila de filtros, la lista de guardados con anillo de match y
/// la fila de acciones rápidas al pie.
///
/// LO QUE NO SE PUDO RECONSTRUIR, y por qué. El mockup gira alrededor de
/// COLECCIONES ("Talento Tech Senior", "Futuros Líderes", "Contrataciones
/// 2026"): carpetas creadas por el usuario, con nombre, descripción y fecha de
/// actualización. En la base existe `saved_profiles` —un vínculo empresa↔
/// candidato y nada más—, no hay tabla de colecciones ni forma de crearlas. Los
/// seis mosaicos de colecciones, el botón "Nueva colección", "Compartir
/// colección" y "Mover a etapa" quedarían como carpetas de mentira.
///
/// En su lugar, la pantalla agrupa por las ETIQUETAS reales de los candidatos
/// guardados: es una agrupación verdadera, calculada sobre los datos que hay, y
/// ocupa el mismo lugar en la jerarquía. Los porcentajes de match del mockup
/// tampoco están: el match es candidato↔vacante y acá no hay vacante elegida.
class EmpresaGuardadosScreen extends StatefulWidget {
  /// Datos ya resueltos, para los golden tests.
  final GuardadosData? previewData;

  const EmpresaGuardadosScreen({super.key, this.previewData});

  @override
  State<EmpresaGuardadosScreen> createState() => _EmpresaGuardadosScreenState();
}

class _EmpresaGuardadosScreenState extends State<EmpresaGuardadosScreen> {
  GuardadosData _data = GuardadosData.empty;
  bool _loading = true;

  final _buscador = TextEditingController();
  String _query = '';

  /// null = todos; si no, el tag elegido.
  String? _tag;

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
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.previewData != null) return;
    if (!mounted) return;
    setState(() => _loading = true);
    final data = await loadGuardados();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
      if (_tag != null &&
          !data.agrupacionesPorTag.any((a) => a.tag == _tag)) {
        _tag = null;
      }
    });
  }

  List<CandidatoGuardado> get _visibles {
    var lista = _data.candidatos;

    if (_tag != null) {
      lista = lista
          .where((c) => c.usuario.tags.any(
                (t) => t.replaceAll('#', '').trim().toLowerCase() ==
                    _tag!.toLowerCase(),
              ))
          .toList();
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      lista = lista.where((c) {
        if (c.confidencial) {
          return c.usuario.headline.toLowerCase().contains(q) ||
              c.usuario.tags.any((t) => t.toLowerCase().contains(q));
        }
        return c.usuario.name.toLowerCase().contains(q) ||
            c.usuario.headline.toLowerCase().contains(q) ||
            c.usuario.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    return lista;
  }

  Future<void> _quitar(CandidatoGuardado c) async {
    final ok = await quitarGuardado(c.usuario.id);
    if (!mounted) return;
    if (ok) {
      await _load();
    } else {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('No se pudo quitar'),
          content: const Text(
            'El candidato sigue guardado. Probá de nuevo en un momento.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  void _abrirPerfil(CandidatoGuardado c) {
    Navigator.of(context)
        .push(
          CupertinoPageRoute(
            builder: (_) => EmpresaCandidatoPerfilScreen(
              candidatoId: c.usuario.id,
            ),
          ),
        )
        // Al volver puede haberse desguardado desde el perfil.
        .then((_) => _load());
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.dark,
      child: CupertinoPageScaffold(
        backgroundColor: MpTokens.darkBg,
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
    if (_data.total == 0) return [_encabezado(), _vacio()];

    return [
      _encabezado(),
      const SizedBox(height: MpTokens.space20),
      _metricas(),
      const SizedBox(height: MpTokens.space16),
      _buscadorWidget(),
      if (_data.agrupacionesPorTag.isNotEmpty) ...[
        const SizedBox(height: MpTokens.space16),
        _agrupaciones(),
      ],
      const SizedBox(height: MpTokens.space20),
      ..._listado(),
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
              Text('Guardados', style: MpTokens.h1.copyWith(color: s.text)),
              const SizedBox(height: MpTokens.space4),
              Text(
                'Tu talento guardado, para no perder a los mejores.',
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
    // Vacío no es lo mismo que muerto: sin guardados, la salida útil es ir a
    // buscar talento, así que el estado ofrece esa acción en vez de dejar la
    // pantalla en negro.
    return Padding(
      padding: const EdgeInsets.only(top: MpTokens.space32),
      child: MpEmptyState(
        icon: _data.error
            ? CupertinoIcons.exclamationmark_triangle
            : CupertinoIcons.bookmark,
        title: _data.error
            ? 'No pudimos cargar tus guardados'
            : 'Todavía no guardaste candidatos',
        message: _data.error
            ? 'Revisá tu conexión y volvé a intentar.'
            : 'Cuando encuentres un perfil que te interese, tocá "Guardar" en '
                'su ficha y va a aparecer acá.',
        actionLabel: _data.error ? 'Reintentar' : 'Explorar talento',
        onAction: _data.error
            ? _load
            : () => Navigator.of(context)
                .push(
                  CupertinoPageRoute(
                    builder: (_) => const EmpresaTalentFeedScreen(),
                  ),
                )
                // Puede haber guardado a alguien desde el feed.
                .then((_) => _load()),
      ),
    );
  }

  // ── Métricas ───────────────────────────────────────────────────────────────

  Widget _metricas() {
    final s = context.mp;

    final items = <({String valor, String etiqueta})>[
      (valor: '${_data.total}', etiqueta: 'Guardados'),
      (valor: '${_data.estaSemana}', etiqueta: 'Esta semana'),
      (valor: '${_data.verificados}', etiqueta: 'Verificados'),
      (valor: '${_data.disponibles}', etiqueta: 'Disponibles'),
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

  Widget _buscadorWidget() {
    return MpTextField(
      controller: _buscador,
      placeholder: 'Buscar en guardados…',
      icon: CupertinoIcons.search,
      onChanged: (v) => setState(() => _query = v),
    );
  }

  // ── Agrupaciones por etiqueta ──────────────────────────────────────────────

  Widget _agrupaciones() {
    final s = context.mp;
    final grupos = _data.agrupacionesPorTag.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Por habilidad',
                style: MpTokens.h2.copyWith(color: s.text, fontSize: 17),
              ),
            ),
            if (_tag != null)
              MpButton(
                label: 'Limpiar',
                variant: MpButtonVariant.ghost,
                size: MpButtonSize.small,
                onPressed: () => setState(() => _tag = null),
              ),
          ],
        ),
        const SizedBox(height: MpTokens.space4),
        Text(
          'Agrupado por las habilidades reales de tus guardados.',
          style: MpTokens.micro.copyWith(color: s.textTertiary),
        ),
        const SizedBox(height: MpTokens.space12),
        Wrap(
          spacing: MpTokens.space8,
          runSpacing: MpTokens.space8,
          children: [
            for (final g in grupos)
              GestureDetector(
                onTap: () => setState(
                  () => _tag = _tag == g.tag ? null : g.tag,
                ),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MpTokens.space12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _tag == g.tag ? s.tint(s.accent, alpha: 0.20) : s.card,
                    borderRadius: BorderRadius.circular(MpTokens.radiusMD),
                    border: Border.all(
                      color: _tag == g.tag ? s.accent : s.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        g.tag,
                        style: MpTokens.label.copyWith(
                          color: _tag == g.tag ? s.accent : s.text,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${g.cantidad}',
                        style: MpTokens.micro.copyWith(
                          color: _tag == g.tag ? s.accent : s.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── Listado ────────────────────────────────────────────────────────────────

  List<Widget> _listado() {
    final s = context.mp;
    final visibles = _visibles;

    if (visibles.isEmpty) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: const MpEmptyState(
            icon: CupertinoIcons.search,
            title: 'Sin resultados',
            message: 'Probá con otra búsqueda o quitá el filtro de habilidad.',
          ),
        ),
      ];
    }

    return [
      Text(
        '${visibles.length} '
        '${visibles.length == 1 ? 'candidato' : 'candidatos'}'
        '${_tag == null ? '' : ' con $_tag'}',
        style: MpTokens.label.copyWith(color: s.textSecondary),
      ),
      const SizedBox(height: MpTokens.space12),
      for (final c in visibles) ...[
        _tarjeta(c),
        const SizedBox(height: MpTokens.space8),
      ],
    ];
  }

  Widget _tarjeta(CandidatoGuardado c) {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space12),
      onTap: () => _abrirPerfil(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MpAvatar(
                name: c.nombreVisible,
                size: 46,
                image: (c.usuario.avatarUrl != null && !c.confidencial)
                    ? NetworkImage(c.usuario.avatarUrl!)
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
                            c.nombreVisible,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MpTokens.title.copyWith(
                              color: s.text,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (c.usuario.isVerified) ...[
                          const SizedBox(width: 5),
                          const MpVerifiedBadge(size: 13),
                        ],
                      ],
                    ),
                    if (c.usuario.headline.isNotEmpty)
                      Text(
                        c.usuario.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MpTokens.micro.copyWith(
                          color: s.textSecondary,
                        ),
                      ),
                    if (c.antiguedad != null)
                      Text(
                        'Guardado ${c.antiguedad!.toLowerCase()}',
                        style: MpTokens.micro.copyWith(
                          color: s.textTertiary,
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _quitar(c),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(MpTokens.space4),
                  child: Icon(
                    CupertinoIcons.bookmark_fill,
                    size: 19,
                    color: s.accent,
                  ),
                ),
              ),
            ],
          ),
          if (c.usuario.tags.isNotEmpty) ...[
            const SizedBox(height: MpTokens.space12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in c.usuario.tags.take(4))
                  MpTagChip(label: t.replaceAll('#', '').trim()),
              ],
            ),
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
                  onPressed: () => _abrirPerfil(c),
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
                      builder: (_) =>
                          ChatInmailScreen(targetUser: c.usuario),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
