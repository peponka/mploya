import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/headhunter_clients_service.dart';
import '../../services/headhunter_shortlist_service.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../../widgets/headhunter/headhunter_candidate_thumb.dart';
import 'headhunter_shortlist_feedback_screen.dart';

/// Shortlist (Headhunter) — dos modos sobre la misma pantalla.
///
/// **Crear** reconstruye `Headhunter_Crear_Shortlist.png`: checkboxes sobre
/// los candidatos del pipeline de una búsqueda, ordenados por match%.
/// **Ver** reconstruye `_Headhunter_Shortlist_Cliente..png`: detalle de una
/// shortlist ya creada, con acción de marcarla enviada.
///
/// SIN descarga de PDF (no hay generación de PDF en el proyecto — no se
/// simula un botón que no hace nada real). "Enviar recordatorio" SÍ es real:
/// abre WhatsApp o el cliente de mail del propio headhunter (`url_launcher`,
/// ya estaba en el proyecto) con un mensaje pre-armado con datos reales —
/// no manda nada por su cuenta, no hay integración de envío en el proyecto.
class HeadhunterShortlistScreen extends StatefulWidget {
  const HeadhunterShortlistScreen._({
    super.key,
    this.jobId,
    this.clientId,
    this.pipelineCandidates,
    this.shortlistId,
  });

  factory HeadhunterShortlistScreen.crear({
    Key? key,
    required String jobId,
    String? clientId,
    required List<Map<String, dynamic>> pipelineCandidates,
  }) =>
      HeadhunterShortlistScreen._(
        key: key,
        jobId: jobId,
        clientId: clientId,
        pipelineCandidates: pipelineCandidates,
      );

  factory HeadhunterShortlistScreen.ver({Key? key, required String shortlistId}) =>
      HeadhunterShortlistScreen._(key: key, shortlistId: shortlistId);

  final String? jobId;
  final String? clientId;
  final List<Map<String, dynamic>>? pipelineCandidates;
  final String? shortlistId;

  bool get _isCrear => shortlistId == null;

  @override
  State<HeadhunterShortlistScreen> createState() => _HeadhunterShortlistScreenState();
}

class _HeadhunterShortlistScreenState extends State<HeadhunterShortlistScreen> {
  final _selected = <String>{};
  bool _guardando = false;

  bool _loadingVer = true;
  Map<String, dynamic>? _shortlist;
  List<Map<String, dynamic>> _shortlistCandidates = const [];
  String? _jobTitle;
  bool _enviandoRecordatorio = false;

  @override
  void initState() {
    super.initState();
    if (!widget._isCrear) _loadShortlist();
  }

  Future<void> _loadShortlist() async {
    final shortlist = await getShortlist(widget.shortlistId!);
    final candidates = await listShortlistCandidatesWithProfiles(widget.shortlistId!);
    if (shortlist != null) {
      final job = await Supabase.instance.client
          .from('jobs')
          .select('title')
          .eq('id', shortlist['job_id'])
          .maybeSingle();
      _jobTitle = job?['title']?.toString();
    }
    if (!mounted) return;
    setState(() {
      _shortlist = shortlist;
      _shortlistCandidates = candidates;
      _loadingVer = false;
    });
  }

  List<Map<String, dynamic>> get _sortedPipeline {
    final list = List<Map<String, dynamic>>.from(widget.pipelineCandidates ?? const []);
    list.sort((a, b) {
      final sa = (a['match_score'] as num?) ?? -1;
      final sb = (b['match_score'] as num?) ?? -1;
      return sb.compareTo(sa);
    });
    return list;
  }

  Future<void> _continuar() async {
    if (_selected.isEmpty || _guardando) return;
    setState(() => _guardando = true);
    final chosen = _sortedPipeline.where((c) => _selected.contains(c['id'].toString())).toList();
    try {
      final shortlist = await createShortlist(
        jobId: widget.jobId!,
        clientId: widget.clientId,
        selectedPipelineCandidates: chosen,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (_) => HeadhunterShortlistScreen.ver(shortlistId: shortlist['id'].toString()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
    }
  }

  Future<void> _marcarEnviada() async {
    final shortlist = await markShortlistSent(widget.shortlistId!);
    if (!mounted) return;
    setState(() => _shortlist = shortlist);
  }

  /// Abre WhatsApp o el mail del propio headhunter con un recordatorio
  /// pre-armado — nunca manda nada por su cuenta: el headhunter revisa y
  /// aprieta enviar en su propia app. `contact_channel` del cliente decide
  /// el canal (whatsapp → wa.me, cualquier otra cosa → mailto).
  Future<void> _enviarRecordatorio() async {
    final clientId = _shortlist?['client_id']?.toString();
    if (clientId == null) {
      _mostrarAviso('Esta shortlist no tiene un cliente vinculado.');
      return;
    }
    setState(() => _enviandoRecordatorio = true);
    final cliente = await getHeadhunterClient(clientId);
    if (!mounted) return;
    setState(() => _enviandoRecordatorio = false);
    if (cliente == null) {
      _mostrarAviso('No pudimos encontrar los datos de contacto del cliente.');
      return;
    }

    final puesto = _jobTitle ?? 'la búsqueda';
    final contacto = (cliente['contact_first_name'] as String?)?.trim() ?? '';
    final mensaje = 'Hola $contacto, te escribo para saber si tuviste chance '
        'de revisar la shortlist de $puesto (${_shortlistCandidates.length} '
        'candidatos) que te enviamos. ¡Quedo atento a tu feedback!';

    final channel = (cliente['contact_channel'] as String?) ?? 'email';
    Uri uri;
    if (channel == 'whatsapp') {
      final phone = (cliente['contact_phone'] as String?)?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';
      uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(mensaje)}');
    } else {
      final email = (cliente['contact_email'] as String?) ?? '';
      uri = Uri(
        scheme: 'mailto',
        path: email,
        query: 'subject=${Uri.encodeComponent('Shortlist: $puesto')}&body=${Uri.encodeComponent(mensaje)}',
      );
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      _mostrarAviso('No pudimos abrir ${channel == 'whatsapp' ? 'WhatsApp' : 'tu app de mail'}.');
    }
  }

  void _mostrarAviso(String mensaje) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(mensaje),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: MpTokens.lightBg,
        child: SafeArea(
          bottom: false,
          child: widget._isCrear ? _crearBody() : _verBody(),
        ),
      ),
    );
  }

  // ── Crear ───────────────────────────────────────────────────────────────

  Widget _crearBody() {
    final s = context.mp;
    final candidates = _sortedPipeline;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MpTokens.screenPadding, MpTokens.space8, MpTokens.screenPadding, 0,
          ),
          child: MpHeader(
            title: 'Crear shortlist',
            subtitle: 'Seleccioná los mejores candidatos para presentar a tu cliente.',
            onBack: () => Navigator.of(context).maybePop(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MpTokens.screenPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Seleccionados ', style: MpTokens.caption.copyWith(color: s.textSecondary)),
              Text('${_selected.length}',
                  style: MpTokens.bodyStrong.copyWith(color: s.accent)),
              Text(' / ${candidates.length}',
                  style: MpTokens.caption.copyWith(color: s.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: MpTokens.space8),
        Expanded(
          child: candidates.isEmpty
              ? MpEmptyState(
                  icon: CupertinoIcons.person_3,
                  title: 'Sin candidatos en el pipeline',
                  message: 'Agregá candidatos a esta búsqueda antes de armar una shortlist.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    MpTokens.screenPadding, 0, MpTokens.screenPadding, MpTokens.space24,
                  ),
                  children: [for (final c in candidates) _selectableRow(c)],
                ),
        ),
        _crearFooter(),
      ],
    );
  }

  Widget _selectableRow(Map<String, dynamic> c) {
    final s = context.mp;
    final id = c['id'].toString();
    final profile = (c['profile'] as Map<String, dynamic>?) ?? const {};
    final name = (profile['name'] as String?)?.trim().isNotEmpty == true
        ? profile['name'].toString()
        : 'Candidato';
    final headline = (profile['headline'] as String?)?.trim();
    final avatar = (profile['avatar_url'] as String?)?.trim();
    final video = (profile['video_url'] as String?)?.trim();
    final matchScore = c['match_score'] as num?;
    final selected = _selected.contains(id);

    return Padding(
      padding: const EdgeInsets.only(bottom: MpTokens.space8),
      child: MpCard(
        onTap: () => setState(() => selected ? _selected.remove(id) : _selected.add(id)),
        highlighted: selected,
        child: Row(
          children: [
            MpCheckbox(value: selected, onChanged: (_) {
              setState(() => selected ? _selected.remove(id) : _selected.add(id));
            }),
            const SizedBox(width: MpTokens.space12),
            HeadhunterCandidateThumb(name: name, avatarUrl: avatar, videoUrl: video, size: 46),
            const SizedBox(width: MpTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: MpTokens.title.copyWith(color: s.text, fontSize: 15)),
                  if (headline != null && headline.isNotEmpty)
                    Text(headline, style: MpTokens.caption.copyWith(color: s.textSecondary)),
                ],
              ),
            ),
            if (matchScore != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${(matchScore * 100).round()}%',
                      style: MpTokens.bodyStrong.copyWith(color: MpTokens.successDeep)),
                  Text('Match IA', style: MpTokens.micro.copyWith(color: s.textTertiary)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _crearFooter() {
    final s = context.mp;
    return Container(
      padding: EdgeInsets.fromLTRB(
        MpTokens.screenPadding, MpTokens.space12, MpTokens.screenPadding,
        MediaQuery.of(context).padding.bottom + MpTokens.space12,
      ),
      decoration: BoxDecoration(color: s.card, border: Border(top: BorderSide(color: s.border))),
      child: Row(
        children: [
          Expanded(
            child: MpButton(
              label: 'Cancelar',
              variant: MpButtonVariant.neutral,
              expand: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          Expanded(
            flex: 2,
            child: MpButton(
              label: 'Continuar',
              trailingArrow: true,
              expand: true,
              loading: _guardando,
              onPressed: _selected.isEmpty ? null : _continuar,
            ),
          ),
        ],
      ),
    );
  }

  // ── Ver ────────────────────────────────────────────────────────────────

  Widget _verBody() {
    if (_loadingVer) {
      return const Center(child: CupertinoActivityIndicator(radius: 15));
    }
    final s = context.mp;
    final shortlist = _shortlist;
    if (shortlist == null) {
      return const Center(child: Text('No se encontró la shortlist.'));
    }
    final status = shortlist['status'] as String? ?? 'draft';
    final isSent = status == 'sent';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MpTokens.screenPadding, MpTokens.space8, MpTokens.screenPadding, 0,
          ),
          child: MpHeader(
            title: 'Shortlist',
            subtitle: '${_shortlistCandidates.length} candidatos',
            onBack: () => Navigator.of(context).maybePop(),
            actions: [
              MpStatusBadge(
                label: isSent ? 'Enviada' : 'Borrador',
                status: isSent ? MpStatus.active : MpStatus.neutral,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              MpTokens.screenPadding, MpTokens.space12, MpTokens.screenPadding, MpTokens.space24,
            ),
            children: [
              if (isSent) ...[
                MpBanner(
                  icon: CupertinoIcons.paperplane_fill,
                  title: 'Enviada al cliente',
                  message: 'Registrá el feedback una vez que tengas la respuesta del cliente.',
                  actionLabel: 'Ver feedback',
                  onAction: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => HeadhunterShortlistFeedbackScreen(shortlistId: widget.shortlistId!),
                    ),
                  ),
                ),
                const SizedBox(height: MpTokens.space12),
                MpButton(
                  label: 'Enviar recordatorio',
                  icon: CupertinoIcons.bell,
                  variant: MpButtonVariant.outline,
                  expand: true,
                  loading: _enviandoRecordatorio,
                  onPressed: _enviandoRecordatorio ? null : _enviarRecordatorio,
                ),
                const SizedBox(height: MpTokens.space16),
              ],
              for (final c in _shortlistCandidates) ...[
                _shortlistCard(c),
                const SizedBox(height: MpTokens.space12),
              ],
            ],
          ),
        ),
        if (!isSent)
          Container(
            padding: EdgeInsets.fromLTRB(
              MpTokens.screenPadding, MpTokens.space12, MpTokens.screenPadding,
              MediaQuery.of(context).padding.bottom + MpTokens.space12,
            ),
            decoration: BoxDecoration(color: s.card, border: Border(top: BorderSide(color: s.border))),
            child: MpButton(
              label: 'Marcar como enviada',
              icon: CupertinoIcons.paperplane_fill,
              expand: true,
              size: MpButtonSize.large,
              onPressed: _marcarEnviada,
            ),
          ),
      ],
    );
  }

  Widget _shortlistCard(Map<String, dynamic> c) {
    final s = context.mp;
    final profile = (c['profile'] as Map<String, dynamic>?) ?? const {};
    final name = (profile['name'] as String?)?.trim().isNotEmpty == true
        ? profile['name'].toString()
        : 'Candidato';
    final headline = (profile['headline'] as String?)?.trim();
    final avatar = (profile['avatar_url'] as String?)?.trim();
    final video = (profile['video_url'] as String?)?.trim();
    final matchScore = c['match_score'] as num?;
    final note = (c['note'] as String?)?.trim();

    return MpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HeadhunterCandidateThumb(name: name, avatarUrl: avatar, videoUrl: video, size: 48),
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
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: MpTokens.space12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(MpTokens.space12),
              decoration: BoxDecoration(
                color: s.tint(MpTokens.success, alpha: 0.08),
                borderRadius: BorderRadius.circular(MpTokens.radiusMD),
              ),
              child: Text(note, style: MpTokens.caption.copyWith(color: MpTokens.successDeep)),
            ),
          ],
          const SizedBox(height: MpTokens.space8),
          GestureDetector(
            onTap: () => _editarNota(c),
            child: Text(
              note == null || note.isEmpty ? '+ Agregar nota' : 'Editar nota',
              style: MpTokens.label.copyWith(color: s.accent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editarNota(Map<String, dynamic> c) async {
    final controller = TextEditingController(text: (c['note'] as String?) ?? '');
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Nota del candidato'),
        content: Padding(
          padding: const EdgeInsets.only(top: MpTokens.space8),
          child: CupertinoTextField(controller: controller, maxLines: 3),
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
    if (result == null) return;
    await setShortlistCandidateNote(c['id'].toString(), result);
    _loadShortlist();
  }
}
