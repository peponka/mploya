import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import 'empresa_crear_entrevista_data.dart';

/// Pedir una entrevista con IA a un candidato.
///
/// DERIVACIÓN CONTROLADA del CTA "Nueva entrevista" de `entrevistas nuevas.png`
/// (39, escritorio) y de "Acciones rápidas → Nueva entrevista" de
/// `agenda inteligente.png` (21). Ninguno de los dos desarrolla la pantalla de
/// alta, así que la estructura es la de los listados de Empresa ya aprobados:
/// encabezado, resumen, agrupación por vacante y ficha por candidato.
///
/// POR QUÉ EXISTE. El circuito de entrevista con IA estaba completo en el
/// backend —`createInterview`, la Edge Function `generate-interview-questions`,
/// `generate-interview-report` que además marca `completed`— pero su ÚNICO
/// disparador era `ats_dashboard_screen`, la pantalla legacy, que además lo
/// hacía con ids `demo-`. Sin esta pantalla, una empresa no podía originar una
/// entrevista con IA de verdad, y el Resumen IA aprobado no tenía cómo llenarse.
///
/// SÓLO CANDIDATOS REALES: la lista sale de `get_company_candidates`, o sea de
/// postulaciones existentes. No se ofrece entrevistar a alguien que no se
/// postuló, y quien ya tiene entrevista para esa vacante aparece marcado y no
/// se puede pedir de nuevo.
///
/// Eso último ahora es una garantía de verdad, no una cortesía de la UI: el
/// alta pasa por la RPC `request_ai_interview` (migración 027), que revalida en
/// el servidor que la vacante sea de esta empresa y que el candidato se haya
/// postulado a ella. Lo que la pantalla muestra dejó de ser lo que la pantalla
/// permite.
class EmpresaCrearEntrevistaScreen extends StatefulWidget {
  /// Datos ya resueltos, para los golden tests.
  final CrearEntrevistaData? previewData;

  const EmpresaCrearEntrevistaScreen({super.key, this.previewData});

  @override
  State<EmpresaCrearEntrevistaScreen> createState() =>
      _EmpresaCrearEntrevistaScreenState();
}

class _EmpresaCrearEntrevistaScreenState
    extends State<EmpresaCrearEntrevistaScreen> {
  CrearEntrevistaData _data = CrearEntrevistaData.empty;
  bool _loading = true;
  String? _pidiendo;

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
    final data = await loadCandidatosEntrevistables();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  Future<void> _pedir(CandidatoEntrevistable c) async {
    if (_pidiendo != null || widget.previewData != null) return;
    setState(() => _pidiendo = '${c.vacanteId}·${c.candidatoId}');

    final res = await pedirEntrevista(
      jobId: c.vacanteId,
      candidatoId: c.candidatoId,
    );

    if (!mounted) return;
    setState(() => _pidiendo = null);

    if (!res.ok) {
      await _alerta(
        'No pudimos crear la entrevista',
        res.error ?? 'Probá de nuevo en un momento.',
      );
      return;
    }

    // La entrevista y el aviso los escribe el servidor en una sola transacción,
    // así que o están los dos o no está ninguno. Lo único que puede fallar por
    // separado es la generación de preguntas, que va después.
    final detalle = StringBuffer(
      res.yaExistia
          ? 'Esta persona ya tenía una entrevista pedida para esta vacante. No '
              'se creó otra ni se le volvió a avisar.'
          : 'El candidato ya recibió la invitación.',
    );
    detalle.write(
      res.preguntas.isEmpty
          ? '\n\nLas preguntas todavía no se generaron. Se pueden generar más '
              'tarde: la entrevista queda igual.'
          : '\n\nSe generaron ${res.preguntas.length} preguntas.',
    );

    await _alerta(
      res.yaExistia ? 'La entrevista ya existía' : 'Entrevista creada',
      detalle.toString(),
    );
    await _load();
  }

  Future<void> _alerta(String titulo, String mensaje) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
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
                  title: 'Nueva entrevista con IA',
                  subtitle: 'El candidato responde cuando puede.',
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
    final s = context.mp;
    if (_data.candidatos.isEmpty) return [_vacio()];

    return [
      _comoFunciona(),
      const SizedBox(height: MpTokens.space24),
      for (final entrada in _data.porVacante.entries) ...[
        Text(
          entrada.key,
          style: MpTokens.h2.copyWith(color: s.text, fontSize: 17),
        ),
        const SizedBox(height: MpTokens.space12),
        for (final c in entrada.value) ...[
          _ficha(c),
          const SizedBox(height: MpTokens.space8),
        ],
        const SizedBox(height: MpTokens.space16),
      ],
    ];
  }

  Widget _vacio() {
    return Padding(
      padding: const EdgeInsets.only(top: MpTokens.space32),
      child: MpEmptyState(
        icon: _data.error
            ? CupertinoIcons.exclamationmark_triangle
            : CupertinoIcons.person_2,
        title: _data.error
            ? 'No pudimos cargar tus candidatos'
            : 'Todavía no hay a quién entrevistar',
        message: _data.error
            ? 'Revisá tu conexión y volvé a intentar.'
            : 'La entrevista con IA se le pide a alguien que se postuló a una '
                'de tus vacantes. Cuando recibas postulaciones vas a poder '
                'pedirla desde acá.',
        actionLabel: _data.error ? 'Reintentar' : null,
        onAction: _data.error ? _load : null,
      ),
    );
  }

  Widget _comoFunciona() {
    final s = context.mp;

    return MpAiCard(
      title: 'Cómo funciona',
      tag: 'BETA',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'La IA genera las preguntas a partir de la vacante. El candidato '
            'las responde en video cuando puede, y cuando termina se genera el '
            'informe con su evaluación.',
            style: MpTokens.body.copyWith(
              color: s.textSecondary,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: MpTokens.space8),
          Text(
            'Vas a ver el resultado en Entrevistas, en la sección de IA.',
            style: MpTokens.micro.copyWith(color: s.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _ficha(CandidatoEntrevistable c) {
    final s = context.mp;
    final ocupado = _pidiendo == '${c.vacanteId}·${c.candidatoId}';

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space12),
      child: Row(
        children: [
          MpAvatar(
            name: c.nombre,
            size: 46,
            image: c.avatarUrl == null ? null : NetworkImage(c.avatarUrl!),
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  c.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.title.copyWith(color: s.text, fontSize: 15),
                ),
                if (c.headline != null)
                  Text(
                    c.headline!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.micro.copyWith(color: s.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          if (c.yaTieneEntrevista)
            const MpStatusBadge(label: 'Ya pedida', status: MpStatus.finished)
          else
            MpButton(
              label: 'Pedir',
              icon: CupertinoIcons.sparkles,
              size: MpButtonSize.small,
              loading: ocupado,
              onPressed: () => _pedir(c),
            ),
        ],
      ),
    );
  }
}
