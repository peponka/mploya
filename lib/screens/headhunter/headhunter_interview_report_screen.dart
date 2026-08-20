import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import 'headhunter_interview_data.dart';

/// Informe de entrevista de Headhunter.
///
/// Migrada al sistema de diseño (18/8/2026), 6ª pantalla — cierra la
/// familia de entrevistas (después de Interviews e Interview Flow).
///
/// ÚNICA pantalla de Headhunter migrada hasta ahora que es OSCURA por
/// diseño (`MpSurfaceStyle.dark`), no clara — coincide con la regla #3 del
/// propio `mploya_ds.dart`: *"El violeta sobre fondo tenue significa 'esto
/// lo hizo la IA'"*. Por eso el contenido generado por IA (Resumen,
/// Fundamento) usa [MpAiCard] (ícono sparkles + tinte violeta), no
/// [MpCard] liso — los datos estructurados (candidato, competencias,
/// palabras clave) sí usan [MpCard]/[MpTagChip] normales, porque no son
/// prosa generada.
///
/// SIN mockup 1:1 (mismo motivo que el resto). Patrón:
///
///   · Resumen / Fundamento → [MpAiCard].
///   · Candidato + score    → [MpCard] + [MpAvatar] + [MpTypeChip] para el
///     puntaje.
///   · Competencias         → [MpCard], layout original preservado (no
///     hay un widget de ds/ para "nombre + score + nota" en una fila).
///   · Palabras clave       → [MpTagChip] en `Wrap`, reemplaza los
///     `Container` violeta a mano — coincide exactamente con el caso de
///     uso documentado de ese widget.
///
/// STRINGS FIJOS verificados por `headhunter_polish_6_test.dart`:
/// 'Resumen', 'Fundamento', 'Competencias', 'Palabras clave', 'Identidad
/// protegida', 'Informe no disponible', 'No pudimos cargar el informe'.
class HeadhunterInterviewReportScreen extends StatefulWidget {
  const HeadhunterInterviewReportScreen({
    super.key,
    required this.interviewId,
    this.previewData,
    this.loadOverride,
  });

  final String interviewId;
  final HeadhunterInterviewReportData? previewData;
  final Future<HeadhunterInterviewReportData> Function(String id)? loadOverride;

  @override
  State<HeadhunterInterviewReportScreen> createState() =>
      _HeadhunterInterviewReportScreenState();
}

class _HeadhunterInterviewReportScreenState
    extends State<HeadhunterInterviewReportScreen> {
  HeadhunterInterviewReportData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.previewData case final data?) {
      _data = data;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final data =
        await (widget.loadOverride?.call(widget.interviewId) ??
            loadHeadhunterInterviewReport(widget.interviewId));
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.dark,
      child: Builder(
        builder: (context) {
          final s = context.mp;
          return CupertinoPageScaffold(
            backgroundColor: s.bg,
            navigationBar: CupertinoNavigationBar(
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).maybePop(),
                child: Icon(CupertinoIcons.chevron_back, color: s.text),
              ),
              middle: Text('Informe de entrevista', style: TextStyle(color: s.text)),
              backgroundColor: s.bg,
              border: null,
            ),
            child: SafeArea(
              child: _loading
                  ? Center(child: CupertinoActivityIndicator(color: s.text))
                  : _body(context),
            ),
          );
        },
      ),
    );
  }

  // `context` es parámetro explícito en ésta y en las próximas tres
  // (no el `context` implícito del State) A PROPÓSITO: `context.mp` busca
  // el MpSurface más cercano HACIA ARRIBA en el árbol, y el `MpSurface`
  // que este widget declara en `build()` queda como DESCENDIENTE del
  // `context` del State (es un hijo de lo que build() devuelve, no un
  // ancestro) — usar el `context` implícito acá caería siempre en el
  // fallback `MpSurfaceStyle.light` de `MpSurface.of()`, sin error visible,
  // así fuera esta pantalla oscura. El `context` que sí ve el MpSurface
  // correcto es el que entrega el `Builder` de `build()`, por eso se
  // threadea a mano en vez de usar el implícito.
  Widget _body(BuildContext context) {
    final data = _data!;
    if (data.error) {
      return _state(
        context,
        'No pudimos cargar el informe',
        'Revisá tu conexión y volvé a intentar.',
        retry: true,
      );
    }
    if (data.notFound || !data.hasContent) {
      return _state(
        context,
        'Informe no disponible',
        'Esta entrevista todavía no tiene un informe real generado.',
      );
    }
    final interview = data.interview;
    final s = context.mp;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space20,
        MpTokens.screenPadding,
        MpTokens.space32,
      ),
      children: [
        Row(
          children: [
            const Icon(CupertinoIcons.sparkles, color: MpTokens.primaryLight),
            const SizedBox(width: MpTokens.space8),
            Expanded(
              child: Text(
                'Resumen de la entrevista',
                style: MpTokens.h1.copyWith(color: s.text, fontSize: 24),
              ),
            ),
          ],
        ),
        const SizedBox(height: MpTokens.space16),
        MpCard(
          child: Row(
            children: [
              MpAvatar(
                // Nunca la inicial de un nombre real para un confidencial.
                name: interview.isConfidential ? null : interview.candidateName,
                size: 48,
              ),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      interview.candidateName,
                      style: TextStyle(
                        color: s.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: MpTokens.space4),
                    Text(
                      interview.isConfidential ? 'Identidad protegida' : interview.jobTitle,
                      style: TextStyle(color: s.textSecondary),
                    ),
                  ],
                ),
              ),
              if (data.score case final score?)
                MpTypeChip(label: '$score/100', color: MpTokens.success),
            ],
          ),
        ),
        if (interview.isConfidential) ...[
          const SizedBox(height: MpTokens.space12),
          MpCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(CupertinoIcons.shield_fill, color: MpTokens.primaryLight),
                const SizedBox(width: MpTokens.space8),
                Expanded(
                  child: Text(
                    'Este informe preserva la identidad, imagen, ubicación, contacto y video del talento.',
                    style: TextStyle(color: s.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!interview.isConfidential && data.summary?.isNotEmpty == true) ...[
          const SizedBox(height: MpTokens.space16),
          MpAiCard(title: 'Resumen', child: Text(data.summary!, style: TextStyle(color: s.textSecondary, height: 1.5))),
        ],
        if (!interview.isConfidential && data.rationale?.isNotEmpty == true) ...[
          const SizedBox(height: MpTokens.space16),
          MpAiCard(title: 'Fundamento', child: Text(data.rationale!, style: TextStyle(color: s.textSecondary, height: 1.5))),
        ],
        if (data.competencies.isNotEmpty) ...[
          const SizedBox(height: MpTokens.space16),
          MpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Competencias',
                  style: TextStyle(color: s.text, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MpTokens.space12),
                for (final item in data.competencies)
                  _competency(context, item, hideFreeText: interview.isConfidential),
              ],
            ),
          ),
        ],
        if (!interview.isConfidential && data.keywords.isNotEmpty) ...[
          const SizedBox(height: MpTokens.space16),
          MpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Palabras clave',
                  style: TextStyle(color: s.text, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MpTokens.space8),
                Wrap(
                  spacing: MpTokens.space8,
                  runSpacing: MpTokens.space8,
                  children: [
                    for (final keyword in data.keywords) MpTagChip(label: keyword),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _competency(
    BuildContext context,
    Map<String, dynamic> item, {
    required bool hideFreeText,
  }) {
    final s = context.mp;
    final name = item['name']?.toString().trim() ?? '';
    final note = hideFreeText ? '' : item['note']?.toString().trim() ?? '';
    final score = item['score'] is num ? (item['score'] as num).round() : null;
    if (name.isEmpty && note.isEmpty && score == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: MpTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? 'Competencia' : name,
                  style: TextStyle(color: s.text, fontWeight: FontWeight.w600),
                ),
              ),
              if (score != null)
                Text('$score/100', style: const TextStyle(color: MpTokens.success)),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: MpTokens.space4),
            Text(note, style: TextStyle(color: s.textSecondary, height: 1.35)),
          ],
        ],
      ),
    );
  }

  Widget _state(
    BuildContext context,
    String title,
    String message, {
    bool retry = false,
  }) {
    final s = context.mp;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MpTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.doc_text_search, size: 48, color: MpTokens.primaryLight),
            const SizedBox(height: MpTokens.space16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: s.text, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: MpTokens.space8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: s.textSecondary)),
            if (retry)
              CupertinoButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
