import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/ds/mploya_ds.dart';
import 'empresa_candidato_perfil_screen.dart';
import 'empresa_informe_entrevista_data.dart';

/// Informe de una entrevista con IA.
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 11/8/2026 — diseño Y lógica aprobados.                   ║
/// ║ No modificar salvo bug real demostrado.                               ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// RECONSTRUCCIÓN. PNG principal `resumenIA de la entrevista.png` (20) —mobile,
/// oscura, con la barra inferior de Empresa—, y `resumen ia video.png` como
/// secundario: su bloque "Evaluación general", con las competencias puntuadas
/// sobre 100 y una barra de color por cada una, es EXACTAMENTE la forma de
/// `interview_reports.competencies` (`[{name, score, note}]`), así que la
/// estructura se toma de ahí.
///
/// `analisis de ia video candidato.png` quedó descartado en el gate: es claro,
/// naranja de marca y del rol CANDIDATO ("Resultados de tu video pitch",
/// "Aplicar mejoras a mi perfil").
///
/// POR QUÉ EXISTE: `interview_reports` (summary, competencies, keywords, score,
/// rationale) y las Edge Functions `generate-interview-questions` y
/// `generate-interview-report` estaban completas y sin una sola pantalla que las
/// aprovechara. El único acceso era el ATS legacy, y encima con
/// `interviewId: 'demo-completed'`, o sea con datos falsos.
///
/// OMITIDO DEL MOCKUP, y por qué:
///   · "Comparación con otros candidatos" — exigiría traer y rankear los
///     informes de todas las entrevistas de la vacante; no hay consulta que lo
///     haga y armarla acá sería N+1 sobre datos que la pantalla no necesita.
///   · "Próximos pasos sugeridos" / "Siguientes pasos recomendados" — la IA no
///     los genera: `interview_reports` no tiene ese campo.
///   · "Descargar PDF" y "Enviar por email" — no hay generación de documentos
///     ni envío de correo.
///   · "Probabilidad de éxito" como número aparte del match — no existe.
///   · "Momentos destacados" con marcas de tiempo — hay video POR RESPUESTA,
///     no clips recortados, así que se muestran las respuestas completas.
class EmpresaInformeEntrevistaScreen extends StatefulWidget {
  final String interviewId;

  /// Datos ya resueltos, para los golden tests.
  final InformeEntrevistaData? previewData;

  const EmpresaInformeEntrevistaScreen({
    super.key,
    required this.interviewId,
    this.previewData,
  });

  @override
  State<EmpresaInformeEntrevistaScreen> createState() =>
      _EmpresaInformeEntrevistaScreenState();
}

class _EmpresaInformeEntrevistaScreenState
    extends State<EmpresaInformeEntrevistaScreen> {
  InformeEntrevistaData _data = const InformeEntrevistaData();
  bool _loading = true;
  bool _resumenExpandido = false;

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

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
    final data = await loadInformeEntrevista(widget.interviewId);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  String _fecha(DateTime f) => '${f.day} ${_meses[f.month - 1]} ${f.year}';

  /// Color por tramo de puntaje. Los cortes son de presentación, no un juicio
  /// nuevo: el número que se muestra es el que devolvió la IA.
  Color _color(int puntaje) {
    if (puntaje >= 75) return MpTokens.success;
    if (puntaje >= 50) return MpTokens.premium;
    return MpTokens.danger;
  }

  Future<void> _verVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                  title: 'Resumen IA',
                  subtitle: 'Generado por Mploya IA',
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
    final informe = _data.informe;
    if (informe == null) return [_sinInforme()];

    return [
      _fichaCandidato(informe),
      const SizedBox(height: MpTokens.space16),
      if (informe.competencias.isNotEmpty) ...[
        _evaluacion(informe),
        const SizedBox(height: MpTokens.space20),
      ],
      if (informe.tieneVeredicto) ...[
        _veredicto(informe),
        const SizedBox(height: MpTokens.space20),
      ],
      if (informe.tieneResumen) ...[
        _resumen(informe),
        const SizedBox(height: MpTokens.space20),
      ],
      if (informe.habilidades.isNotEmpty) ...[
        _habilidades(informe),
        const SizedBox(height: MpTokens.space20),
      ],
      if (informe.respuestas.isNotEmpty) ...[
        _respuestas(informe),
        const SizedBox(height: MpTokens.space20),
      ],
      _comoSeGenero(),
    ];
  }

  /// Sin informe no se rellena nada: se dice en qué punto está el proceso.
  Widget _sinInforme() {
    final motivo = _data.motivo;

    final (titulo, mensaje) = switch (motivo) {
      MotivoSinInforme.entrevistaIncompleta => (
          'La entrevista todavía no terminó',
          'El informe se genera cuando el candidato completa todas sus '
              'respuestas.',
        ),
      MotivoSinInforme.informePendiente => (
          'El informe todavía no está listo',
          'La entrevista está completa y el análisis se genera después. '
              'Probá de nuevo en unos minutos.',
        ),
      _ => (
          'No pudimos abrir el informe',
          'Revisá tu conexión y volvé a intentar.',
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: MpTokens.space32),
      child: MpEmptyState(
        icon: motivo == MotivoSinInforme.informePendiente
            ? CupertinoIcons.clock
            : CupertinoIcons.doc_text,
        title: titulo,
        message: mensaje,
        actionLabel: 'Reintentar',
        onAction: _load,
      ),
    );
  }

  // ── Ficha ──────────────────────────────────────────────────────────────────

  Widget _fichaCandidato(InformeEntrevista i) {
    final s = context.mp;
    final puntaje = i.puntaje;

    return MpCard(
      radius: MpTokens.radiusXL,
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => EmpresaCandidatoPerfilScreen(
            candidatoId: i.entrevista.candidateId,
          ),
        ),
      ),
      child: Row(
        children: [
          MpAvatar(
            name: i.candidato,
            size: 58,
            image: i.candidatoAvatar == null
                ? null
                : NetworkImage(i.candidatoAvatar!),
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  i.candidato,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.h2.copyWith(color: s.text, fontSize: 18),
                ),
                if (i.candidatoHeadline != null)
                  Text(
                    i.candidatoHeadline!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.caption.copyWith(color: s.textSecondary),
                  ),
                const SizedBox(height: MpTokens.space8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (i.vacante != null)
                      MpTypeChip(
                        label: i.vacante!,
                        color: MpTokens.primary,
                        icon: CupertinoIcons.briefcase,
                      ),
                    MpTypeChip(
                      label: _fecha(
                        i.entrevista.completedAt ?? i.entrevista.createdAt,
                      ),
                      color: MpTokens.catBlue,
                      icon: CupertinoIcons.calendar,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // El anillo sólo aparece si la IA puntuó. Sin `score` no se dibuja un
          // 0 que se leería como un candidato malo.
          if (puntaje != null) ...[
            const SizedBox(width: MpTokens.space8),
            MpProgressRing(
              value: puntaje / 100,
              size: 66,
              stroke: 6,
              color: _color(puntaje),
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$puntaje',
                    style: MpTokens.title.copyWith(color: s.text, fontSize: 19),
                  ),
                  Text(
                    '/100',
                    style: MpTokens.micro.copyWith(
                      color: s.textTertiary,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Evaluación general ─────────────────────────────────────────────────────

  Widget _evaluacion(InformeEntrevista i) {
    final s = context.mp;
    final promedio = i.promedioCompetencias;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Evaluación general',
                style: MpTokens.h2.copyWith(color: s.text, fontSize: 17),
              ),
            ),
            if (promedio != null)
              Text(
                'Promedio $promedio',
                style: MpTokens.micro.copyWith(color: s.textTertiary),
              ),
          ],
        ),
        const SizedBox(height: MpTokens.space12),
        MpCard(
          radius: MpTokens.radiusXL,
          child: Column(
            children: [
              for (var n = 0; n < i.competencias.length; n++) ...[
                if (n > 0) ...[
                  const SizedBox(height: MpTokens.space16),
                  Container(height: 1, color: s.border),
                  const SizedBox(height: MpTokens.space16),
                ],
                _competencia(i.competencias[n]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _competencia(CompetenciaEvaluada c) {
    final s = context.mp;
    final p = c.puntaje;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                c.nombre,
                style: MpTokens.label.copyWith(color: s.text),
              ),
            ),
            if (p != null)
              Text(
                '$p',
                style: MpTokens.title.copyWith(
                  color: _color(p),
                  fontSize: 16,
                ),
              )
            else
              Text(
                'sin puntaje',
                style: MpTokens.micro.copyWith(color: s.textTertiary),
              ),
            if (p != null)
              Text(
                '/100',
                style: MpTokens.micro.copyWith(
                  color: s.textTertiary,
                  fontSize: 10,
                ),
              ),
          ],
        ),
        if (p != null) ...[
          const SizedBox(height: MpTokens.space8),
          MpProgressBar(value: p / 100, color: _color(p)),
        ],
        if (c.nota != null) ...[
          const SizedBox(height: MpTokens.space8),
          Text(
            c.nota!,
            style: MpTokens.caption.copyWith(color: s.textSecondary),
          ),
        ],
      ],
    );
  }

  // ── Veredicto ──────────────────────────────────────────────────────────────

  /// El "por qué" del puntaje, tal como lo escribió la IA (`rationale`). No se
  /// reescribe ni se resume: se muestra literal.
  Widget _veredicto(InformeEntrevista i) {
    final s = context.mp;

    return MpAiCard(
      title: 'Veredicto de la IA',
      tag: 'BETA',
      child: Text(
        i.informe.rationale!.trim(),
        style: MpTokens.body.copyWith(color: s.textSecondary, fontSize: 14),
      ),
    );
  }

  // ── Resumen ────────────────────────────────────────────────────────────────

  Widget _resumen(InformeEntrevista i) {
    final s = context.mp;
    final texto = i.informe.summary!.trim();
    final largo = texto.length > 260;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen de la entrevista',
          style: MpTokens.h2.copyWith(color: s.text, fontSize: 17),
        ),
        const SizedBox(height: MpTokens.space12),
        MpCard(
          radius: MpTokens.radiusXL,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                texto,
                maxLines: (_resumenExpandido || !largo) ? null : 5,
                overflow: (_resumenExpandido || !largo)
                    ? TextOverflow.clip
                    : TextOverflow.ellipsis,
                style: MpTokens.body.copyWith(color: s.textSecondary),
              ),
              if (largo) ...[
                const SizedBox(height: MpTokens.space8),
                MpButton(
                  label: _resumenExpandido ? 'Ver menos' : 'Ver más',
                  variant: MpButtonVariant.ghost,
                  size: MpButtonSize.small,
                  onPressed: () => setState(
                    () => _resumenExpandido = !_resumenExpandido,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Habilidades ────────────────────────────────────────────────────────────

  Widget _habilidades(InformeEntrevista i) {
    final s = context.mp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Habilidades detectadas',
          style: MpTokens.h2.copyWith(color: s.text, fontSize: 17),
        ),
        const SizedBox(height: MpTokens.space4),
        Text(
          'Las que la IA identificó en las respuestas.',
          style: MpTokens.micro.copyWith(color: s.textTertiary),
        ),
        const SizedBox(height: MpTokens.space12),
        Wrap(
          spacing: MpTokens.space8,
          runSpacing: MpTokens.space8,
          children: [
            for (final h in i.habilidades) MpTagChip(label: h),
          ],
        ),
      ],
    );
  }

  // ── Respuestas ─────────────────────────────────────────────────────────────

  /// El mockup muestra "Momentos destacados" con marcas de tiempo. No hay clips
  /// recortados: lo que existe es el video y la transcripción de CADA respuesta,
  /// y eso es lo que se lista.
  Widget _respuestas(InformeEntrevista i) {
    final s = context.mp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Respuestas del candidato',
          style: MpTokens.h2.copyWith(color: s.text, fontSize: 17),
        ),
        const SizedBox(height: MpTokens.space12),
        for (final r in i.respuestas) ...[
          MpCard(
            radius: MpTokens.radiusLG,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.pregunta,
                  style: MpTokens.label.copyWith(color: s.text),
                ),
                if (r.tieneTranscripcion) ...[
                  const SizedBox(height: MpTokens.space8),
                  Text(
                    r.transcripcion!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.caption.copyWith(
                      color: s.textSecondary,
                    ),
                  ),
                ],
                if (r.tieneVideo) ...[
                  const SizedBox(height: MpTokens.space12),
                  MpButton(
                    label: 'Ver respuesta en video',
                    icon: CupertinoIcons.play_circle,
                    size: MpButtonSize.small,
                    variant: MpButtonVariant.outline,
                    expand: true,
                    onPressed: () => _verVideo(r.videoUrl!),
                  ),
                ],
                if (!r.tieneVideo && !r.tieneTranscripcion) ...[
                  const SizedBox(height: MpTokens.space4),
                  Text(
                    'Sin respuesta registrada.',
                    style: MpTokens.micro.copyWith(color: s.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: MpTokens.space8),
        ],
      ],
    );
  }

  Widget _comoSeGenero() {
    final s = context.mp;

    return MpBanner(
      icon: CupertinoIcons.info,
      title: 'Cómo se generó',
      message: 'Este informe lo produjo la IA a partir de las respuestas del '
          'candidato. Los puntajes y el texto son los que devolvió el análisis: '
          'no se reescriben ni se completan desde la app.',
      color: s.textTertiary,
    );
  }
}
