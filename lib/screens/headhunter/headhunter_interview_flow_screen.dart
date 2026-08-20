import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import 'headhunter_interview_data.dart';
import 'headhunter_interview_report_screen.dart';

/// Detalle de entrevista de Headhunter.
///
/// Migrada al sistema de diseño (18/8/2026), 5ª pantalla — 2ª de la familia
/// de entrevistas (después de `headhunter_interviews_screen.dart`).
///
/// SIN mockup 1:1 (mismo motivo que el resto de Headhunter). Patrón:
///
///   · Tarjeta de candidato → `Container` con `MpTokens.heroGradient` +
///     `MpTokens.glow` (la misma receta que usa [MpHeroBand] por dentro,
///     pero acá el contenido es un perfil, no métricas, así que no encaja
///     en ese widget). Leading [MpAvatar] — confidencial pasa `name: null`
///     a propósito (fallback "?", nunca una inicial real), igual que
///     Pipeline/Talent Pool.
///   · Tarjeta de estado / contador → [MpCard] a mano (el layout —
///     ícono+label a la izquierda arriba, valor grande abajo— no es
///     exactamente [MpStatTile], que lleva el ícono en un [MpIconTile]
///     separado del valor; acá se mantuvo el layout original dentro de un
///     [MpCard] tokenizado).
///   · Contadores (Preguntas/Respuestas) → [MpStatTile], igual que
///     Dashboard/Entrevistas.
///   · CTA → [MpButton] (`variant: primary, expand: true`) en vez de
///     `CupertinoButton.filled` (que hereda el azul de `CupertinoTheme`,
///     no el violeta del sistema).
///
/// STRINGS FIJOS QUE LOS TESTS VERIFICAN LITERAL (no tocar en la 3ª
/// pantalla de la familia): 'Completada', 'Preguntas', 'Respuestas',
/// 'Ver informe de entrevista', 'Identidad protegida', 'ubicación' (dentro
/// de la tarjeta de privacidad), 'Entrevista no disponible', 'No pudimos
/// cargar la entrevista'.
class HeadhunterInterviewFlowScreen extends StatefulWidget {
  const HeadhunterInterviewFlowScreen({
    super.key,
    required this.interviewId,
    this.previewData,
    this.loadOverride,
  });

  final String interviewId;
  final HeadhunterInterviewData? previewData;
  final Future<HeadhunterInterviewData> Function(String id)? loadOverride;

  @override
  State<HeadhunterInterviewFlowScreen> createState() =>
      _HeadhunterInterviewFlowScreenState();
}

class _HeadhunterInterviewFlowScreenState
    extends State<HeadhunterInterviewFlowScreen> {
  HeadhunterInterviewData? _data;
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
            loadHeadhunterInterview(widget.interviewId));
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
        backgroundColor: const Color(0x00000000),
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Detalle de entrevista'),
          previousPageTitle: 'Entrevistas',
          border: null,
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CupertinoActivityIndicator(radius: 15))
              : _body(),
        ),
      ),
    );
  }

  Widget _body() {
    final data = _data!;
    final s = context.mp;
    if (data.error) {
      return _state(
        CupertinoIcons.exclamationmark_triangle,
        'No pudimos cargar la entrevista',
        'Revisá tu conexión y volvé a intentar.',
        action: 'Reintentar',
        onAction: _load,
      );
    }
    if (data.notFound) {
      return _state(
        CupertinoIcons.doc_text_search,
        'Entrevista no disponible',
        'No existe o ya no tenés acceso a esta entrevista.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space20,
        MpTokens.screenPadding,
        MpTokens.space32,
      ),
      children: [
        _candidateCard(data),
        const SizedBox(height: MpTokens.space16),
        _statusCard(data),
        const SizedBox(height: MpTokens.space16),
        _counts(data),
        if (data.isConfidential) ...[
          const SizedBox(height: MpTokens.space16),
          _privacyCard(),
        ],
        if (data.hasReport) ...[
          const SizedBox(height: MpTokens.space20),
          MpButton(
            label: 'Ver informe de entrevista',
            variant: MpButtonVariant.primary,
            expand: true,
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) =>
                    HeadhunterInterviewReportScreen(interviewId: data.id),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: MpTokens.space20),
          Text(
            'El informe aparecerá cuando exista un registro real para esta entrevista.',
            textAlign: TextAlign.center,
            style: MpTokens.caption.copyWith(color: s.textSecondary, height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _candidateCard(HeadhunterInterviewData data) {
    return Container(
      padding: const EdgeInsets.all(MpTokens.space16),
      decoration: BoxDecoration(
        gradient: MpTokens.heroGradient,
        borderRadius: BorderRadius.circular(MpTokens.radiusXL),
        boxShadow: MpTokens.glow(MpTokens.primary),
      ),
      child: Row(
        children: [
          MpAvatar(
            image: !data.isConfidential && data.avatarUrl?.isNotEmpty == true
                ? NetworkImage(data.avatarUrl!)
                : null,
            // Nunca la inicial de un nombre real para un confidencial.
            name: data.isConfidential ? null : data.candidateName,
            size: 56,
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.candidateName,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: MpTokens.space4),
                Text(
                  data.isConfidential
                      ? 'Identidad protegida'
                      : data.candidateHeadline?.isNotEmpty == true
                      ? data.candidateHeadline!
                      : 'Candidato',
                  style: const TextStyle(color: Color(0xFFCDC6E8)),
                ),
                const SizedBox(height: 5),
                Text(
                  data.jobTitle,
                  style: const TextStyle(color: Color(0xFFAFA3D4), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(HeadhunterInterviewData data) {
    final s = context.mp;
    final label = switch (data.status) {
      'completed' => 'Completada',
      'in_progress' => 'En curso',
      _ => 'Pendiente',
    };
    final color = switch (data.status) {
      'completed' => MpTokens.success,
      'in_progress' => MpTokens.primary,
      _ => MpTokens.premium,
    };
    return MpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estado', style: MpTokens.caption.copyWith(color: s.textSecondary)),
          const SizedBox(height: MpTokens.space8),
          Row(
            children: [
              Icon(CupertinoIcons.checkmark_seal_fill, color: color, size: 20),
              const SizedBox(width: MpTokens.space8),
              Text(
                label,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space12),
          Text(
            'Creada ${_date(data.createdAt)}${data.completedAt == null ? '' : ' · Finalizada ${_date(data.completedAt!)}'}',
            style: MpTokens.caption.copyWith(color: s.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _counts(HeadhunterInterviewData data) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MpStatTile(
              icon: CupertinoIcons.question_circle,
              color: MpTokens.primary,
              value: '${data.questionCount}',
              label: 'Preguntas',
              compact: true,
            ),
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: MpStatTile(
              icon: CupertinoIcons.videocam,
              color: MpTokens.primary,
              value: '${data.answerCount}',
              label: 'Respuestas',
              compact: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _privacyCard() {
    final s = context.mp;
    return MpCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.shield_fill, color: MpTokens.primary),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Text(
              'La identidad, imagen, ubicación, contacto y video de este talento están protegidos.',
              style: MpTokens.body.copyWith(color: s.text, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _state(
    IconData icon,
    String title,
    String message, {
    String? action,
    VoidCallback? onAction,
  }) {
    final s = context.mp;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MpTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: s.textSecondary),
            const SizedBox(height: MpTokens.space16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: MpTokens.h2.copyWith(color: s.text, fontSize: 20),
            ),
            const SizedBox(height: MpTokens.space8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: MpTokens.body.copyWith(color: s.textSecondary),
            ),
            if (action != null)
              CupertinoButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
