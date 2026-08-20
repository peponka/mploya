import 'package:flutter/cupertino.dart';

import '../../services/headhunter_shortlist_service.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../../widgets/headhunter/headhunter_candidate_thumb.dart';

/// Feedback del cliente sobre una shortlist ya enviada.
///
/// RECONSTRUCCIÓN de `Headhunter_Feedback_Cliente.png`. El headhunter carga
/// acá la decisión que el cliente le contó por fuera de la app (no hay
/// portal de cliente en el proyecto — ver migración 043).
///
/// Las 4 tabs del mockup (Pendiente/Entrevista/Rechazados/Contratado) NO
/// salen las 4 de la misma columna: las primeras 3 derivan de
/// `shortlist_candidates.client_decision`; "Contratado" deriva del `stage`
/// del candidato en `headhunter_pipeline_candidates` (`colocado`) — eso es
/// un hecho posterior y real del pipeline principal, no una decisión de
/// shortlist. Un candidato "colocado" aparece en Contratado sin importar su
/// `client_decision`.
class HeadhunterShortlistFeedbackScreen extends StatefulWidget {
  const HeadhunterShortlistFeedbackScreen({super.key, required this.shortlistId});

  final String shortlistId;

  @override
  State<HeadhunterShortlistFeedbackScreen> createState() =>
      _HeadhunterShortlistFeedbackScreenState();
}

class _HeadhunterShortlistFeedbackScreenState
    extends State<HeadhunterShortlistFeedbackScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _candidates = const [];
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final candidates = await listShortlistCandidatesWithProfiles(widget.shortlistId);
    if (!mounted) return;
    setState(() {
      _candidates = candidates;
      _loading = false;
    });
  }

  String _bucket(Map<String, dynamic> c) {
    if (c['pipeline_stage'] == 'colocado') return 'contratado';
    final decision = (c['client_decision'] as String?) ?? 'pendiente';
    if (decision == 'avanzar' || decision == 'entrevistar') return 'entrevista';
    if (decision == 'rechazar') return 'rechazado';
    return 'pendiente';
  }

  List<Map<String, dynamic>> get _filtrados {
    const buckets = ['pendiente', 'entrevista', 'rechazado', 'contratado'];
    final bucket = buckets[_tab];
    return _candidates.where((c) => _bucket(c) == bucket).toList();
  }

  int _count(String bucket) => _candidates.where((c) => _bucket(c) == bucket).length;

  Future<void> _decidir(Map<String, dynamic> c, String decision) async {
    final controller = TextEditingController(text: (c['client_comment'] as String?) ?? '');
    final comentario = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(_decisionLabel(decision)),
        content: Padding(
          padding: const EdgeInsets.only(top: MpTokens.space8),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Comentario (opcional)',
            maxLines: 3,
          ),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (comentario == null) return;
    await setShortlistCandidateDecision(
      c['id'].toString(),
      decision,
      comment: comentario.isEmpty ? null : comentario,
    );
    _load();
  }

  String _decisionLabel(String decision) => switch (decision) {
        'avanzar' => 'Avanzar a siguiente etapa',
        'entrevistar' => 'Agendar entrevista',
        'rechazar' => 'Rechazar candidato',
        _ => decision,
      };

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
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
                  MpTokens.screenPadding, MpTokens.space8, MpTokens.screenPadding, 0,
                ),
                child: MpHeader(
                  title: 'Feedback del cliente',
                  subtitle: 'Registrá la decisión sobre cada candidato.',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: MpTokens.space8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MpTokens.screenPadding),
                child: MpSegmentedFilter(
                  scrollable: true,
                  options: [
                    MpFilterOption('Pendiente', count: _count('pendiente')),
                    MpFilterOption('Entrevista', count: _count('entrevista')),
                    MpFilterOption('Rechazados', count: _count('rechazado')),
                    MpFilterOption('Contratado', count: _count('contratado')),
                  ],
                  selectedIndex: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CupertinoActivityIndicator(radius: 15))
                    : _filtrados.isEmpty
                        ? Center(
                            child: Text(
                              'Nadie en esta categoría todavía.',
                              style: MpTokens.body.copyWith(color: s.textSecondary),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(
                              MpTokens.screenPadding, MpTokens.space12,
                              MpTokens.screenPadding, MpTokens.space24,
                            ),
                            children: [for (final c in _filtrados) _candidateCard(c)],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _candidateCard(Map<String, dynamic> c) {
    final s = context.mp;
    final profile = (c['profile'] as Map<String, dynamic>?) ?? const {};
    final name = (profile['name'] as String?)?.trim().isNotEmpty == true
        ? profile['name'].toString()
        : 'Candidato';
    final headline = (profile['headline'] as String?)?.trim();
    final avatar = (profile['avatar_url'] as String?)?.trim();
    final video = (profile['video_url'] as String?)?.trim();
    final matchScore = c['match_score'] as num?;
    final comment = (c['client_comment'] as String?)?.trim();
    final bucket = _bucket(c);
    final decidible = bucket != 'contratado';

    return Padding(
      padding: const EdgeInsets.only(bottom: MpTokens.space12),
      child: MpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                HeadhunterCandidateThumb(name: name, avatarUrl: avatar, videoUrl: video, size: 46),
                const SizedBox(width: MpTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, style: MpTokens.title.copyWith(color: s.text)),
                      if (headline != null && headline.isNotEmpty)
                        Text(headline, style: MpTokens.caption.copyWith(color: s.textSecondary)),
                    ],
                  ),
                ),
                if (matchScore != null)
                  Text('${(matchScore * 100).round()}%',
                      style: MpTokens.bodyStrong.copyWith(color: MpTokens.successDeep)),
              ],
            ),
            if (comment != null && comment.isNotEmpty) ...[
              const SizedBox(height: MpTokens.space12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(MpTokens.space12),
                decoration: BoxDecoration(color: s.fill, borderRadius: BorderRadius.circular(MpTokens.radiusMD)),
                child: Text(comment, style: MpTokens.caption.copyWith(color: s.textSecondary)),
              ),
            ],
            if (decidible) ...[
              const SizedBox(height: MpTokens.space12),
              Text('Tu decisión', style: MpTokens.label.copyWith(color: s.textTertiary)),
              const SizedBox(height: MpTokens.space8),
              Row(
                children: [
                  Expanded(
                    child: MpButton(
                      label: 'Avanzar',
                      icon: CupertinoIcons.checkmark_circle,
                      size: MpButtonSize.small,
                      color: MpTokens.success,
                      expand: true,
                      onPressed: () => _decidir(c, 'avanzar'),
                    ),
                  ),
                  const SizedBox(width: MpTokens.space8),
                  Expanded(
                    child: MpButton(
                      label: 'Entrevistar',
                      icon: CupertinoIcons.calendar,
                      size: MpButtonSize.small,
                      color: MpTokens.premium,
                      expand: true,
                      onPressed: () => _decidir(c, 'entrevistar'),
                    ),
                  ),
                  const SizedBox(width: MpTokens.space8),
                  Expanded(
                    child: MpButton(
                      label: 'Rechazar',
                      icon: CupertinoIcons.xmark_circle,
                      size: MpButtonSize.small,
                      color: MpTokens.danger,
                      expand: true,
                      onPressed: () => _decidir(c, 'rechazar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
