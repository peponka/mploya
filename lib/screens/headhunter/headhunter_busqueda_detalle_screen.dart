import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../services/headhunter_pipeline_candidates_service.dart';
import '../../services/headhunter_placements_service.dart';
import '../../services/headhunter_shortlist_service.dart';
import '../../utils/headhunter_candidate_privacy.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../../widgets/headhunter/headhunter_candidate_thumb.dart';
import '../profile_screen.dart';
import 'headhunter_shortlist_screen.dart';

/// Detalle de una búsqueda (Headhunter) — tabs Candidatos y Pipeline.
///
/// RECONSTRUCCIÓN de `Headhunter_Detalle_Busqueda.png` (tab Candidatos) y
/// `_Headhunter_Pipeline_Busqueda.png` (tab Pipeline). No existen mockups
/// canónicos para las tabs "Resumen/Actividades/Notas/Configuración" (no
/// hay archivo 11 ni 14 en FINAL_SCREENS) — no se construyen, no se inventa
/// contenido para ellas.
///
/// DESVIACIONES DELIBERADAS CONTRA EL MOCKUP:
///   · El Kanban SÍ tiene drag-and-drop (`LongPressDraggable`/`DragTarget`):
///     mantener presionado y arrastrar a otra columna. El botón "···" de
///     cada tarjeta abre el mismo cambio de etapa por menú — respaldo
///     accesible para quien no pueda arrastrar (y evita el choque de gestos
///     entre "arrastrar" y "scroll horizontal de las columnas").
///   · [HeadhunterCandidateThumb] (`widgets/headhunter/`) muestra un frame
///     REAL del video del candidato vía `video_thumbnail` en móvil — nunca
///     una duración inventada como el "0:52" del mockup (eso exigiría
///     cargar el video entero con `video_player` por tarjeta, carísimo para
///     una lista; un frame es barato y es dato real). En Flutter Web cae al
///     avatar de siempre: `video_thumbnail` no tiene implementación web.
///   · Sin la tarjeta de "Métricas del pipeline" aparte: los contadores por
///     columna del Kanban ya son esa métrica, mostrarla dos veces es
///     redundante.
class HeadhunterBusquedaDetalleScreen extends StatefulWidget {
  const HeadhunterBusquedaDetalleScreen({super.key, required this.job});

  /// Fila de `listHeadhunterSearches()` (headhunter_searches_service.dart):
  /// trae id/title/client_name/search_status/location/created_at.
  final Map<String, dynamic> job;

  @override
  State<HeadhunterBusquedaDetalleScreen> createState() =>
      _HeadhunterBusquedaDetalleScreenState();
}

class _HeadhunterBusquedaDetalleScreenState
    extends State<HeadhunterBusquedaDetalleScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _candidates = const [];
  int _tab = 0;
  int _stageFilter = -1; // -1 = todos
  final _search = TextEditingController();

  String get _jobId => widget.job['id'].toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final candidates = await listPipelineCandidates(_jobId);
      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _descubrirMatches() async {
    await discoverMatchesForJob(jobId: _jobId);
    _load();
  }

  Future<void> _agregarCandidato() async {
    final added = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(builder: (_) => _AgregarCandidatoScreen(jobId: _jobId)),
    );
    if (added == true) _load();
  }

  Future<void> _crearShortlist() async {
    if (_candidates.isEmpty) return;
    final creada = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => HeadhunterShortlistScreen.crear(
          jobId: _jobId,
          clientId: widget.job['client_id']?.toString(),
          pipelineCandidates: _candidates,
        ),
      ),
    );
    if (creada == true && mounted) _verShortlists();
  }

  Future<void> _verShortlists() async {
    final shortlists = await listShortlists(jobId: _jobId);
    if (!mounted) return;
    if (shortlists.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Sin shortlists'),
          content: const Text('Todavía no creaste una shortlist para esta búsqueda.'),
          actions: [
            CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => HeadhunterShortlistScreen.ver(shortlistId: shortlists.first['id'].toString()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final title = (widget.job['title'] as String?)?.trim() ?? '';
    final clientName = (widget.job['client_name'] as String?)?.trim();
    final status = (widget.job['search_status'] as String?) ?? 'abierta';

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
                  title: title.isEmpty ? 'Búsqueda' : title,
                  subtitle: clientName,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MpTokens.screenPadding),
                child: Row(
                  children: [
                    MpStatusBadge(label: _statusLabel(status), status: _statusToMpStatus(status)),
                    const Spacer(),
                    Text('${_candidates.length} candidatos',
                        style: MpTokens.caption.copyWith(color: s.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: MpTokens.space12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MpTokens.screenPadding),
                child: MpSegmentedFilter(
                  options: const [MpFilterOption('Candidatos'), MpFilterOption('Pipeline')],
                  selectedIndex: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              const SizedBox(height: MpTokens.space12),
              Expanded(
                child: _loading
                    ? const Center(child: CupertinoActivityIndicator(radius: 15))
                    : _tab == 0
                        ? _candidatosTab()
                        : _pipelineTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab Candidatos ─────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _visibleCandidates {
    var rows = _candidates;
    if (_stageFilter >= 0) {
      final stage = kPipelineStages[_stageFilter];
      rows = rows.where((c) => c['stage'] == stage).toList();
    }
    final query = _search.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      rows = rows.where((c) {
        final profile = c['profile'] as Map<String, dynamic>?;
        final name = (profile?['name'] as String?)?.toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    }
    return rows;
  }

  Widget _candidatosTab() {
    final s = context.mp;
    if (_candidates.isEmpty) return _emptyPipeline();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            MpTokens.screenPadding, 0, MpTokens.screenPadding, MpTokens.space32,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              MpTextField(
                controller: _search,
                placeholder: 'Buscar candidato por nombre...',
                icon: CupertinoIcons.search,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: MpTokens.space12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _stageChip('Todos', -1, _candidates.length),
                    for (var i = 0; i < kPipelineStages.length; i++)
                      _stageChip(
                        pipelineStageLabel(kPipelineStages[i]),
                        i,
                        _candidates.where((c) => c['stage'] == kPipelineStages[i]).length,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: MpTokens.space16),
              if (_visibleCandidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
                  child: Center(
                    child: Text('Sin candidatos en este filtro.',
                        style: MpTokens.body.copyWith(color: s.textSecondary)),
                  ),
                )
              else
                MpRowGroup(rows: [for (final c in _visibleCandidates) _candidateRow(c)]),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _stageChip(String label, int index, int count) {
    final s = context.mp;
    final selected = _stageFilter == index;
    return Padding(
      padding: const EdgeInsets.only(right: MpTokens.space8),
      child: GestureDetector(
        onTap: () => setState(() => _stageFilter = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: MpTokens.space12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? s.accent : s.fill,
            borderRadius: BorderRadius.circular(MpTokens.radiusPill),
          ),
          child: Text(
            '$label ($count)',
            style: MpTokens.label.copyWith(
              color: selected ? const Color(0xFFFFFFFF) : s.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _candidateRow(Map<String, dynamic> c) {
    final profile = (c['profile'] as Map<String, dynamic>?) ?? const {};
    final name = (profile['name'] as String?)?.trim().isNotEmpty == true
        ? profile['name'].toString()
        : 'Candidato';
    final headline = (profile['headline'] as String?)?.trim();
    final avatar = (profile['avatar_url'] as String?)?.trim();
    final video = (profile['video_url'] as String?)?.trim();
    final matchScore = c['match_score'] as num?;
    final stage = (c['stage'] as String?) ?? 'descubierto';

    return MpListRow(
      leading: HeadhunterCandidateThumb(name: name, avatarUrl: avatar, videoUrl: video, size: 46),
      title: name,
      subtitle: headline?.isEmpty ?? true ? null : headline,
      badge: MpTypeChip(label: pipelineStageLabel(stage), color: MpTokens.primary),
      trailingText: matchScore == null ? null : '${(matchScore * 100).round()}%',
      onTap: () => _openProfile(c),
    );
  }

  Future<void> _openProfile(Map<String, dynamic> c) async {
    final profile = c['profile'] as Map<String, dynamic>?;
    if (profile == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ProfileScreen(
          user: NexUser.fromJson(profile),
          viewerAccountType: 'headhunter',
        ),
      ),
    );
  }

  // ── Tab Pipeline (Kanban) ──────────────────────────────────────────────

  Widget _pipelineTab() {
    return Column(
      children: [
        Expanded(
          child: _candidates.isEmpty
              ? _emptyPipeline()
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: MpTokens.screenPadding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final stage in kPipelineStages) ...[
                        _stageColumn(stage),
                        const SizedBox(width: MpTokens.space12),
                      ],
                    ],
                  ),
                ),
        ),
        _quickActions(),
      ],
    );
  }

  Widget _emptyPipeline() {
    return MpEmptyState(
      icon: CupertinoIcons.person_3,
      title: 'Sin candidatos todavía',
      message: 'Descubrí matches reales o agregá candidatos desde el Talent '
          'Pool para armar el pipeline de esta búsqueda.',
      actionLabel: 'Descubrir matches',
      onAction: _descubrirMatches,
    );
  }

  /// Columna del Kanban + destino de arrastre. Soltar una tarjeta acá cambia
  /// su etapa a `stage` (mismo `setPipelineCandidateStage` que usa el menú
  /// de respaldo en `_moverEtapa`).
  Widget _stageColumn(String stage) {
    final s = context.mp;
    final rows = _candidates.where((c) => c['stage'] == stage).toList();

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) => details.data['stage'] != stage,
      onAcceptWithDetails: (details) => _cambiarEtapa(details.data, stage),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return Container(
          width: 168,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: hovering ? s.tint(s.accent, alpha: 0.08) : null,
            borderRadius: BorderRadius.circular(MpTokens.radiusMD),
            border: hovering ? Border.all(color: s.accent, width: 1.5) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: MpTokens.space12, vertical: 8),
                decoration: BoxDecoration(
                  color: s.fill,
                  borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                ),
                child: Text(
                  '${pipelineStageLabel(stage)} (${rows.length})',
                  style: MpTokens.label.copyWith(color: s.text),
                ),
              ),
              const SizedBox(height: MpTokens.space8),
              for (final c in rows) ...[
                _kanbanCard(c),
                const SizedBox(height: MpTokens.space8),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Long-press arrastra la tarjeta a otra columna (mismo gesto no choca con
  /// el tap corto, que abre el perfil). El botón "···" abre el mismo cambio
  /// de etapa por menú — respaldo accesible para quien no pueda arrastrar.
  Widget _kanbanCard(Map<String, dynamic> c) {
    final card = _kanbanCardContent(c);

    return LongPressDraggable<Map<String, dynamic>>(
      data: c,
      feedback: SizedBox(width: 152, child: card),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: GestureDetector(
        onTap: () => _openProfile(c),
        behavior: HitTestBehavior.opaque,
        child: card,
      ),
    );
  }

  Widget _kanbanCardContent(Map<String, dynamic> c) {
    final s = context.mp;
    final profile = (c['profile'] as Map<String, dynamic>?) ?? const {};
    final name = (profile['name'] as String?)?.trim().isNotEmpty == true
        ? profile['name'].toString()
        : 'Candidato';
    final avatar = (profile['avatar_url'] as String?)?.trim();
    final video = (profile['video_url'] as String?)?.trim();
    final matchScore = c['match_score'] as num?;

    return MpCard(
      padding: const EdgeInsets.all(MpTokens.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeadhunterCandidateThumb(name: name, avatarUrl: avatar, videoUrl: video, size: 40),
              const Spacer(),
              GestureDetector(
                onTap: () => _moverEtapa(c),
                behavior: HitTestBehavior.opaque,
                child: Icon(CupertinoIcons.ellipsis, size: 16, color: s.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space8),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: MpTokens.label.copyWith(color: s.text)),
          if (matchScore != null) ...[
            const SizedBox(height: 2),
            Text('${(matchScore * 100).round()}% match',
                style: MpTokens.micro.copyWith(color: MpTokens.successDeep)),
          ],
        ],
      ),
    );
  }

  Future<void> _moverEtapa(Map<String, dynamic> c) async {
    final stage = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Mover a etapa'),
        actions: [
          for (final st in kPipelineStages)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, st),
              child: Text(pipelineStageLabel(st)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (stage == null) return;
    await _cambiarEtapa(c, stage);
  }

  /// Cambia la etapa de un candidato. Si el destino es `colocado`, primero
  /// abre "Registrar colocación" (fee opcional) — mover a colocado sin
  /// registrar la colocación dejaría el KPI de Analytics desalineado con el
  /// Kanban, así que el registro es automático y sólo el fee es opcional
  /// (Guardar/Omitir crean el `headhunter_placements` igual).
  Future<void> _cambiarEtapa(Map<String, dynamic> c, String stage) async {
    await setPipelineCandidateStage(c['id'].toString(), stage);
    if (stage == 'colocado') await _registrarColocacion(c);
    _load();
  }

  Future<void> _registrarColocacion(Map<String, dynamic> c) async {
    final feeController = TextEditingController();
    final feeText = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Registrar colocación'),
        content: Column(
          children: [
            const SizedBox(height: MpTokens.space8),
            const Text('Fee acordado (opcional, se puede cargar después)'),
            const SizedBox(height: MpTokens.space8),
            CupertinoTextField(
              controller: feeController,
              placeholder: 'Monto en USD',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Omitir'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, feeController.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final fee = double.tryParse((feeText ?? '').replaceAll(',', '.'));
    try {
      await registerPlacement(
        pipelineCandidateId: c['id'].toString(),
        jobId: _jobId,
        candidateId: c['candidate_id'].toString(),
        clientId: widget.job['client_id']?.toString(),
        feeAmount: fee,
      );
    } catch (_) {
      // El candidato ya quedó en 'colocado' aunque el registro de la
      // colocación falle (p.ej. sin red) — no revertimos la etapa por eso.
    }
  }

  Widget _quickActions() {
    return Padding(
      padding: const EdgeInsets.all(MpTokens.screenPadding),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: MpButton(
                  label: 'Agregar candidato',
                  icon: CupertinoIcons.person_add,
                  variant: MpButtonVariant.neutral,
                  expand: true,
                  onPressed: _agregarCandidato,
                ),
              ),
              const SizedBox(width: MpTokens.space8),
              Expanded(
                child: MpButton(
                  label: 'Descubrir matches',
                  icon: CupertinoIcons.sparkles,
                  variant: MpButtonVariant.neutral,
                  expand: true,
                  onPressed: _descubrirMatches,
                ),
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space8),
          Row(
            children: [
              Expanded(
                child: MpButton(
                  label: 'Crear shortlist',
                  icon: CupertinoIcons.star,
                  variant: MpButtonVariant.outline,
                  expand: true,
                  onPressed: _candidates.isEmpty ? null : _crearShortlist,
                ),
              ),
              const SizedBox(width: MpTokens.space8),
              Expanded(
                child: MpButton(
                  label: 'Ver shortlist',
                  icon: CupertinoIcons.list_bullet,
                  expand: true,
                  onPressed: _verShortlists,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'en_proceso' => 'En proceso',
        'en_pausa' => 'En pausa',
        'cerrada' => 'Cerrada',
        _ => 'Abierta',
      };

  MpStatus _statusToMpStatus(String status) => switch (status) {
        'en_proceso' => MpStatus.info,
        'en_pausa' => MpStatus.paused,
        'cerrada' => MpStatus.finished,
        _ => MpStatus.active,
      };
}

/// Picker simple para "Agregar candidato" — mismo dato/filtro que
/// `headhunter_talent_pool_screen.dart` (`get_explore_pins`, excluye
/// empresa/headhunter/confidencial), acotado a esta búsqueda.
class _AgregarCandidatoScreen extends StatefulWidget {
  const _AgregarCandidatoScreen({required this.jobId});
  final String jobId;

  @override
  State<_AgregarCandidatoScreen> createState() => _AgregarCandidatoScreenState();
}

class _AgregarCandidatoScreenState extends State<_AgregarCandidatoScreen> {
  final _search = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];
  final _adding = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await Supabase.instance.client.rpc('get_explore_pins', params: {
        'p_lat': -25.2867, 'p_lng': -57.3333, 'p_radius_km': 500.0,
      });
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(result ?? const []).where((row) {
          final type = (row['pin_type'] ?? 'candidato').toString();
          return type != 'empresa' && type != 'headhunter' && !isConfidentialAccountType(type);
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _add(Map<String, dynamic> row) async {
    final id = (row['pin_id'] ?? row['id']).toString();
    setState(() => _adding.add(id));
    await addCandidateToPipeline(jobId: widget.jobId, candidateId: id);
    if (!mounted) return;
    setState(() => _adding.remove(id));
  }

  List<Map<String, dynamic>> get _visible {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((r) => (r['pin_name'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

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
                  MpTokens.screenPadding, MpTokens.space8, MpTokens.screenPadding, 0,
                ),
                child: MpHeader(
                  title: 'Agregar candidato',
                  subtitle: 'Del Talent Pool público',
                  onBack: () => Navigator.of(context).pop(true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MpTokens.screenPadding, MpTokens.space12, MpTokens.screenPadding, MpTokens.space12,
                ),
                child: CupertinoSearchTextField(
                  controller: _search,
                  placeholder: 'Buscar por nombre',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CupertinoActivityIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          MpTokens.screenPadding, 0, MpTokens.screenPadding, MpTokens.space32,
                        ),
                        children: [
                          MpRowGroup(rows: [for (final r in _visible) _row(r)]),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> row) {
    final id = (row['pin_id'] ?? row['id']).toString();
    final name = (row['pin_name'] ?? '').toString();
    final headline = (row['pin_headline'] ?? '').toString();
    final adding = _adding.contains(id);

    return MpListRow(
      leading: MpAvatar(name: name, size: 44),
      title: name,
      subtitle: headline.isEmpty ? null : headline,
      showChevron: false,
      trailing: MpButton(
        label: adding ? '' : 'Agregar',
        icon: adding ? null : CupertinoIcons.add,
        size: MpButtonSize.small,
        loading: adding,
        onPressed: adding ? null : () => _add(row),
      ),
    );
  }
}
