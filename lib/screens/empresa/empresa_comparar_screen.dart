import 'package:flutter/cupertino.dart';

import '../../models/models.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../chat_inmail_screen.dart';
import 'empresa_candidato_perfil_screen.dart';
import 'empresa_shortlist_data.dart';
import 'empresa_vacantes_data.dart';

/// Una fila de la tabla comparativa.
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 11/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
class _Fila {
  final IconData icon;
  final String etiqueta;
  final String detalle;

  /// Valor 0–1 para pintar la barra. Null → sólo texto.
  final double? Function(CandidatoShortlist) valor;

  /// Texto de la celda.
  final String Function(CandidatoShortlist) texto;

  const _Fila({
    required this.icon,
    required this.etiqueta,
    required this.detalle,
    required this.valor,
    required this.texto,
  });
}

/// Comparación de candidatos para una vacante.
///
/// RECONSTRUCCIÓN DIRECTA de `comparar candidatos con ia.png` (Pantalla 52):
/// se conservan la tira superior de candidatos con anillo, la tarjeta de
/// recomendación, la tabla comparativa fila por fila con barra y valoración, el
/// bloque por candidato y la barra de acciones al pie.
///
/// DATOS — la diferencia con el mockup. El PNG compara siete dimensiones
/// ("Potencial de crecimiento", "Ajuste cultural", "Comunicación", "Liderazgo")
/// y cierra con un párrafo firmado por la IA. Esas dimensiones no existen en
/// ninguna tabla ni las produce ningún modelo del proyecto: escribirlas sería
/// inventar un análisis. Acá se comparan SÓLO las señales que el matching real
/// calcula y los hechos que la base conoce.
class EmpresaCompararScreen extends StatelessWidget {
  final Vacante vacante;
  final List<CandidatoShortlist> candidatos;

  const EmpresaCompararScreen({
    super.key,
    required this.vacante,
    required this.candidatos,
  });

  /// Habilidades de la vacante, normalizadas para comparar sin importar mayúsculas.
  Set<String> get _requeridas =>
      vacante.tags.map((t) => t.toLowerCase().trim()).toSet();

  List<String> _coincidentes(CandidatoShortlist c) {
    final req = _requeridas;
    return c.tags.where((t) => req.contains(t.toLowerCase().trim())).toList();
  }

  /// Candidato con mejor ajuste. Null si ninguno tiene match calculado.
  CandidatoShortlist? get _mejor {
    final conMatch = candidatos.where((c) => c.match != null).toList();
    if (conMatch.isEmpty) return null;
    conMatch.sort((a, b) => b.match!.compareTo(a.match!));
    return conMatch.first;
  }

  Color _colorBanda(BandaAjuste banda) => switch (banda) {
        BandaAjuste.alta => MpTokens.success,
        BandaAjuste.media => MpTokens.premium,
        BandaAjuste.baja => MpTokens.danger,
      };

  NexUser _usuario(CandidatoShortlist c) => NexUser.fromJson({
        'id': c.id,
        'name': c.nombre,
        'headline': c.headline ?? '',
        'avatar_url': c.avatarUrl,
        'account_type': c.accountType,
        'tags': c.tags,
      });

  List<_Fila> get _filas => [
        _Fila(
          icon: CupertinoIcons.sparkles,
          etiqueta: 'Ajuste total',
          detalle: 'Match con esta vacante',
          valor: (c) => c.match,
          texto: (c) =>
              c.match == null ? '—' : '${(c.match! * 100).round()}%',
        ),
        _Fila(
          icon: CupertinoIcons.doc_text,
          etiqueta: 'Afinidad de perfil',
          detalle: 'Perfil vs. texto de la vacante',
          valor: (c) => c.semantico,
          texto: (c) =>
              c.semantico == null ? '—' : '${(c.semantico! * 100).round()}%',
        ),
        _Fila(
          icon: CupertinoIcons.checkmark_seal,
          etiqueta: 'Coincidencia de skills',
          detalle: 'Habilidades pedidas vs. declaradas',
          valor: (c) => c.skills,
          texto: (c) =>
              c.skills == null ? '—' : '${(c.skills! * 100).round()}%',
        ),
        _Fila(
          icon: CupertinoIcons.tag,
          etiqueta: 'Skills en común',
          detalle: _requeridas.isEmpty
              ? 'La vacante no declara habilidades'
              : 'De ${_requeridas.length} pedidas',
          valor: (c) => _requeridas.isEmpty
              ? null
              : _coincidentes(c).length / _requeridas.length,
          texto: (c) => _requeridas.isEmpty
              ? '—'
              : '${_coincidentes(c).length}/${_requeridas.length}',
        ),
        _Fila(
          icon: CupertinoIcons.paperplane,
          etiqueta: 'Postulación',
          detalle: 'Se postuló a esta vacante',
          valor: (_) => null,
          texto: (c) => !c.postulado
              ? 'No'
              : (c.estadoPostulacion == null ? 'Sí' : c.estadoPostulacion!),
        ),
      ];

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.dark,
      child: Builder(
        builder: (context) => CupertinoPageScaffold(
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
                    title: 'Comparar Candidatos',
                    subtitle: [
                      vacante.titulo,
                      if (vacante.modalidad != null) vacante.modalidad!,
                    ].join('  ·  '),
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Expanded(
                  child: candidatos.length < 2
                      ? _vacio()
                      : CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                MpTokens.screenPadding,
                                MpTokens.space12,
                                MpTokens.screenPadding,
                                MpTokens.space24,
                              ),
                              sliver: SliverList(
                                delegate:
                                    SliverChildListDelegate(_cuerpo(context)),
                              ),
                            ),
                          ],
                        ),
                ),
                if (candidatos.length >= 2) _barraAcciones(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vacio() {
    return const MpEmptyState(
      icon: CupertinoIcons.square_split_2x1,
      title: 'Elegí al menos dos candidatos',
      message: 'La comparación necesita dos perfiles o más.',
    );
  }

  List<Widget> _cuerpo(BuildContext context) {
    return [
      _tira(context),
      const SizedBox(height: MpTokens.space16),
      _resultado(context),
      const SizedBox(height: MpTokens.space16),
      _tabla(context),
      const SizedBox(height: MpTokens.space16),
      _habilidades(context),
    ];
  }

  // ── Tira de candidatos ─────────────────────────────────────────────────────

  Widget _tira(BuildContext context) {
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: candidatos.length,
        separatorBuilder: (_, __) => const SizedBox(width: MpTokens.space8),
        itemBuilder: (context, i) => _cabecera(context, candidatos[i], i + 1),
      ),
    );
  }

  Widget _cabecera(BuildContext context, CandidatoShortlist c, int puesto) {
    final s = context.mp;
    final esMejor = _mejor?.id == c.id;

    return Container(
      width: 152,
      padding: const EdgeInsets.all(MpTokens.space12),
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(MpTokens.radiusXL),
        border: Border.all(
          color: esMejor ? s.accent : s.border,
          width: esMejor ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: s.tint(s.accent, alpha: 0.20),
                  borderRadius: BorderRadius.circular(MpTokens.radiusXS),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$puesto',
                  style: MpTokens.micro.copyWith(
                    color: s.accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              if (c.postulado)
                Icon(
                  CupertinoIcons.paperplane_fill,
                  size: 13,
                  color: MpTokens.catBlue,
                ),
            ],
          ),
          const SizedBox(height: MpTokens.space8),
          // Anillo con el porcentaje adentro, como las cuatro columnas del PNG.
          // Antes el avatar y el número iban sueltos y la tira se leía como una
          // lista de contactos, no como una comparación.
          if (c.match == null)
            MpAvatar(
              name: c.nombreVisible,
              size: 56,
              image: (c.avatarUrl != null && !c.confidencial)
                  ? NetworkImage(c.avatarUrl!)
                  : null,
            )
          else
            MpProgressRing(
              value: c.match!,
              size: 62,
              stroke: 5,
              color: _colorBanda(c.banda!),
              center: MpAvatar(
                name: c.nombreVisible,
                size: 44,
                image: (c.avatarUrl != null && !c.confidencial)
                    ? NetworkImage(c.avatarUrl!)
                    : null,
              ),
            ),
          const SizedBox(height: MpTokens.space8),
          Text(
            c.nombreVisible,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MpTokens.label.copyWith(color: s.text, fontSize: 13),
          ),
          if (c.headline != null)
            Text(
              c.headline!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MpTokens.micro.copyWith(
                color: s.textSecondary,
                fontSize: 10.5,
              ),
            ),
          const SizedBox(height: MpTokens.space8),
          if (c.match == null)
            Text(
              'Sin match calculado',
              style: MpTokens.micro.copyWith(
                color: s.textTertiary,
                fontSize: 10,
              ),
            )
          else ...[
            Text(
              '${c.matchPct}%',
              style: MpTokens.title.copyWith(
                color: _colorBanda(c.banda!),
                fontSize: 17,
              ),
            ),
            Text(
              c.banda!.etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MpTokens.micro.copyWith(
                color: s.textTertiary,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Resultado ──────────────────────────────────────────────────────────────

  /// El mockup pone acá un párrafo de la IA ("tiene alto potencial de
  /// crecimiento y liderazgo demostrado"). Eso no lo generó nadie: lo que sí es
  /// verdad es qué candidato quedó primero y por qué señal.
  Widget _resultado(BuildContext context) {
    final s = context.mp;
    final mejor = _mejor;

    if (mejor == null) {
      return MpAiCard(
        title: 'Sin ajuste calculado',
        child: Text(
          'Ninguno de los candidatos comparados tiene match calculado para '
          'esta vacante, así que no hay un puntaje que los ordene. Podés '
          'compararlos igual por habilidades y postulación.',
          style: MpTokens.body.copyWith(color: s.textSecondary, fontSize: 13.5),
        ),
      );
    }

    final coincidentes = _coincidentes(mejor);

    return MpAiCard(
      title: 'Mejor ajuste',
      tag: 'MATCH IA',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mejor.nombreVisible,
                      style: MpTokens.h2.copyWith(color: s.text, fontSize: 18),
                    ),
                    const SizedBox(height: MpTokens.space4),
                    Text(
                      'Es quien tiene el ajuste más alto de los comparados: '
                      '${mejor.matchPct}%'
                      '${coincidentes.isEmpty ? '' : ', con ${coincidentes.length} '
                          '${coincidentes.length == 1 ? 'habilidad' : 'habilidades'} '
                          'que coinciden con la vacante'}.',
                      style: MpTokens.body.copyWith(
                        color: s.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MpTokens.space12),
              MpProgressRing(
                value: mejor.match!,
                size: 62,
                stroke: 6,
                color: _colorBanda(mejor.banda!),
                center: Text(
                  '${mejor.matchPct}%',
                  style: MpTokens.label.copyWith(color: s.text, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tabla comparativa ──────────────────────────────────────────────────────

  Widget _tabla(BuildContext context) {
    final s = context.mp;
    const anchoEtiqueta = 132.0;
    const anchoColumna = 96.0;

    return MpCard(
      radius: MpTokens.radiusXL,
      padding: const EdgeInsets.symmetric(vertical: MpTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MpTokens.space16),
            child: Text(
              'Comparación',
              style: MpTokens.title.copyWith(color: s.text),
            ),
          ),
          const SizedBox(height: MpTokens.space12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: MpTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con las iniciales de cada candidato.
                Row(
                  children: [
                    const SizedBox(width: anchoEtiqueta),
                    for (final c in candidatos)
                      SizedBox(
                        width: anchoColumna,
                        child: Text(
                          c.nombreVisible,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: MpTokens.micro.copyWith(
                            color: s.textSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: MpTokens.space8),
                for (final fila in _filas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MpTokens.space12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: anchoEtiqueta,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(fila.icon, size: 15, color: s.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fila.etiqueta,
                                      style: MpTokens.micro.copyWith(
                                        color: s.text,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    Text(
                                      fila.detalle,
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
                        ),
                        for (final c in candidatos)
                          SizedBox(
                            width: anchoColumna,
                            child: _celda(context, fila, c),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _celda(BuildContext context, _Fila fila, CandidatoShortlist c) {
    final s = context.mp;
    final valor = fila.valor(c);
    final esMejorEnFila = valor != null &&
        candidatos
                .map(fila.valor)
                .whereType<double>()
                .fold<double>(0, (m, v) => v > m ? v : m) ==
            valor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MpTokens.space4),
      child: Column(
        children: [
          Text(
            fila.texto(c),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: MpTokens.label.copyWith(
              color: esMejorEnFila ? MpTokens.success : s.text,
              fontSize: 13,
              fontWeight: esMejorEnFila ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          if (valor != null) ...[
            const SizedBox(height: 5),
            MpProgressBar(
              value: valor,
              height: 4,
              color: esMejorEnFila ? MpTokens.success : MpTokens.primaryLight,
            ),
          ],
        ],
      ),
    );
  }

  // ── Habilidades por candidato ──────────────────────────────────────────────

  /// Reemplaza al bloque "Fortalezas principales por candidato" del mockup, que
  /// ahí es texto redactado. Acá son las habilidades declaradas de verdad, y se
  /// marca cuáles pide la vacante.
  Widget _habilidades(BuildContext context) {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Habilidades declaradas',
            style: MpTokens.title.copyWith(color: s.text),
          ),
          const SizedBox(height: MpTokens.space4),
          Text(
            _requeridas.isEmpty
                ? 'Esta vacante no declara habilidades, así que no hay con qué '
                    'contrastarlas.'
                : 'En violeta, las que coinciden con las que pide la vacante.',
            style: MpTokens.caption.copyWith(color: s.textSecondary),
          ),
          const SizedBox(height: MpTokens.space16),
          for (final c in candidatos) ...[
            Row(
              children: [
                MpAvatar(
                  name: c.nombreVisible,
                  size: 26,
                  image: (c.avatarUrl != null && !c.confidencial)
                      ? NetworkImage(c.avatarUrl!)
                      : null,
                ),
                const SizedBox(width: MpTokens.space8),
                Expanded(
                  child: Text(
                    c.nombreVisible,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.label.copyWith(color: s.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MpTokens.space8),
            if (c.tags.isEmpty)
              Text(
                'No declaró habilidades.',
                style: MpTokens.micro.copyWith(color: s.textTertiary),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in c.tags)
                    _skill(context, t,
                        _requeridas.contains(t.toLowerCase().trim())),
                ],
              ),
            const SizedBox(height: MpTokens.space16),
          ],
        ],
      ),
    );
  }

  Widget _skill(BuildContext context, String texto, bool coincide) {
    final s = context.mp;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: coincide ? s.tint(s.accent) : s.fill,
        borderRadius: BorderRadius.circular(MpTokens.radiusXS),
        border: Border.all(
          color: coincide ? s.accent.withValues(alpha: 0.45) : s.border,
        ),
      ),
      child: Text(
        texto,
        style: MpTokens.micro.copyWith(
          color: coincide ? s.accent : s.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }

  // ── Barra de acciones ──────────────────────────────────────────────────────

  Widget _barraAcciones(BuildContext context) {
    final s = context.mp;
    final destacado = _mejor ?? candidatos.first;

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
              label: 'Mensaje',
              icon: CupertinoIcons.chat_bubble,
              variant: MpButtonVariant.neutral,
              expand: true,
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) =>
                      ChatInmailScreen(targetUser: _usuario(destacado)),
                ),
              ),
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          Expanded(
            flex: 2,
            child: MpButton(
              label: 'Ver perfil de ${destacado.nombreVisible.split(' ').first}',
              icon: CupertinoIcons.person,
              expand: true,
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => EmpresaCandidatoPerfilScreen(
                    candidatoId: destacado.id,
                    match: destacado.matchPct,
                    vacanteTitulo: vacante.titulo,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
