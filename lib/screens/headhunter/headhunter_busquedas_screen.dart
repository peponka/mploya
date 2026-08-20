import 'package:flutter/cupertino.dart';

import '../../services/headhunter_searches_service.dart';
import '../../widgets/ds/mploya_ds.dart';
import 'headhunter_busqueda_detalle_screen.dart';
import 'headhunter_publish_job_screen.dart';

/// Búsquedas activas (Headhunter).
///
/// RECONSTRUCCIÓN de `10_Headhunter_Busquedas_Activas.png`, el mockup
/// canónico. Reemplaza el `JobsScreen` genérico (compartido con Candidato/
/// Empresa) que ocupaba la ranura 6 ("Búsquedas") para Headhunter — ese
/// screen está pensado para navegar/postularse a vacantes ajenas, no para
/// que un headhunter gestione las suyas.
///
/// Cada fila navega a `headhunter_busqueda_detalle_screen.dart` (tabs
/// Candidatos/Pipeline, migración 043) — el Pipeline por búsqueda y
/// Crear shortlist NO reutilizan `job_applications.status` (6 valores fijos,
/// RLS/matriz de transición blindada en la migración 038, compartida con
/// Empresa): se modelan como sourcing propio de Headhunter en
/// `headhunter_pipeline_candidates`, sin tocar esa tabla. Ver el doc-comment
/// de la 043 para el porqué completo.
///
/// `progress` (barra debajo de cada búsqueda) = postulaciones que ya salieron
/// de `pending` sobre el total — es el único progreso derivable de datos
/// reales sin inventar una fórmula (ver `headhunter_searches_service.dart`).
class HeadhunterBusquedasScreen extends StatefulWidget {
  const HeadhunterBusquedasScreen({super.key});

  @override
  State<HeadhunterBusquedasScreen> createState() =>
      _HeadhunterBusquedasScreenState();
}

class _HeadhunterBusquedasScreenState extends State<HeadhunterBusquedasScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _searches = const [];
  int _filter = 0;
  final _search = TextEditingController();

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
      final searches = await listHeadhunterSearches();
      if (!mounted) return;
      setState(() {
        _searches = searches;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _nuevaBusqueda() async {
    final creada = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(builder: (_) => const HeadhunterPublishJobScreen()),
    );
    if (creada == true) _load();
  }

  static const _statusByFilter = [null, 'abierta', 'en_proceso', 'en_pausa', 'cerrada'];

  List<Map<String, dynamic>> get _filtrados {
    final status = _statusByFilter[_filter];
    final byStatus =
        status == null ? _searches : _searches.where((s) => s['search_status'] == status);
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return byStatus.toList();
    return byStatus.where((s) {
      final title = (s['title'] as String?)?.toLowerCase() ?? '';
      final client = (s['client_name'] as String?)?.toLowerCase() ?? '';
      return title.contains(query) || client.contains(query);
    }).toList();
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
                  MpTokens.screenPadding,
                  MpTokens.space8,
                  MpTokens.screenPadding,
                  0,
                ),
                child: MpHeader(
                  title: 'Búsquedas activas',
                  subtitle: 'Gestioná todas tus búsquedas, seguí su progreso '
                      'y encontrá al mejor talento.',
                  actions: [
                    MpIconButton(icon: CupertinoIcons.add, solid: true, onPressed: _nuevaBusqueda),
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
                              MpTokens.space8,
                              MpTokens.screenPadding,
                              MpTokens.space32,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate(_content()),
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

  List<Widget> _content() {
    if (_searches.isEmpty) {
      return [
        const SizedBox(height: MpTokens.space32),
        MpEmptyState(
          icon: CupertinoIcons.scope,
          title: 'Sin búsquedas todavía',
          message: 'Creá una búsqueda y empezá a encontrar el mejor talento '
              'para tus clientes.',
          actionLabel: 'Nueva búsqueda',
          onAction: _nuevaBusqueda,
        ),
      ];
    }

    final s = context.mp;

    return [
      MpTextField(
        controller: _search,
        placeholder: 'Buscar por cliente o puesto...',
        icon: CupertinoIcons.search,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: MpTokens.space16),
      MpSegmentedFilter(
        scrollable: true,
        options: [
          MpFilterOption('Todas', count: countBySearchStatus(_searches, null)),
          MpFilterOption('Abiertas', count: countBySearchStatus(_searches, 'abierta')),
          MpFilterOption('En proceso', count: countBySearchStatus(_searches, 'en_proceso')),
          MpFilterOption('En pausa', count: countBySearchStatus(_searches, 'en_pausa')),
          MpFilterOption('Cerradas', count: countBySearchStatus(_searches, 'cerrada')),
        ],
        selectedIndex: _filter,
        onChanged: (i) => setState(() => _filter = i),
      ),
      const SizedBox(height: MpTokens.space16),
      Row(
        children: [
          Expanded(
            child: MpStatTile(
              icon: CupertinoIcons.briefcase_fill,
              color: MpTokens.primary,
              value: '${_searches.length}',
              label: 'Totales',
              compact: true,
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          Expanded(
            child: MpStatTile(
              icon: CupertinoIcons.play_circle_fill,
              color: MpTokens.success,
              value: '${countBySearchStatus(_searches, 'abierta')}',
              label: 'Abiertas',
              compact: true,
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          Expanded(
            child: MpStatTile(
              icon: CupertinoIcons.person_2_fill,
              color: MpTokens.premium,
              value: '${countBySearchStatus(_searches, 'en_proceso')}',
              label: 'En proceso',
              compact: true,
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          Expanded(
            child: MpStatTile(
              icon: CupertinoIcons.pause_circle_fill,
              color: MpTokens.danger,
              value: '${countBySearchStatus(_searches, 'en_pausa')}',
              label: 'En pausa',
              compact: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: MpTokens.space20),
      Text('Todas las búsquedas', style: MpTokens.h2.copyWith(color: s.text)),
      const SizedBox(height: MpTokens.space12),
      if (_filtrados.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: Center(
            child: Text(
              'Ninguna búsqueda coincide con este filtro.',
              style: MpTokens.body.copyWith(color: s.textSecondary),
            ),
          ),
        )
      else
        for (final search in _filtrados) ...[
          _searchCard(search),
          const SizedBox(height: MpTokens.space12),
        ],
    ];
  }

  Widget _searchCard(Map<String, dynamic> job) {
    final s = context.mp;
    final title = (job['title'] as String?)?.trim() ?? '';
    final clientName = (job['client_name'] as String?)?.trim();
    final location = (job['location'] as String?)?.trim();
    final status = (job['search_status'] as String?) ?? 'abierta';
    final candidateCount = (job['candidate_count'] as int?) ?? 0;
    final progress = (job['progress'] as double?) ?? 0.0;
    final daysAgo = _daysAgo(job['created_at'] as String?);

    return MpCard(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => HeadhunterBusquedaDetalleScreen(job: job),
        ),
      ).then((_) => _load()),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SearchLogo(name: clientName ?? title),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title.isEmpty ? 'Búsqueda sin título' : title,
                        style: MpTokens.title.copyWith(color: s.text),
                      ),
                    ),
                    const SizedBox(width: MpTokens.space8),
                    MpStatusBadge(
                      label: _statusLabel(status),
                      status: _statusToMpStatus(status),
                    ),
                  ],
                ),
                if (clientName != null && clientName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(clientName, style: MpTokens.caption.copyWith(color: s.textSecondary)),
                ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: MpTokens.space12,
                  runSpacing: 2,
                  children: [
                    if (location != null && location.isNotEmpty)
                      _metaChip(CupertinoIcons.location_solid, location),
                    if (daysAgo != null) _metaChip(CupertinoIcons.clock, daysAgo),
                    _metaChip(CupertinoIcons.person_2, '$candidateCount candidatos'),
                  ],
                ),
                const SizedBox(height: MpTokens.space12),
                MpProgressBar(value: progress),
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).round()}% evaluado',
                  style: MpTokens.micro.copyWith(color: s.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    final s = context.mp;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: s.textTertiary),
        const SizedBox(width: 4),
        Text(text, style: MpTokens.caption.copyWith(color: s.textTertiary)),
      ],
    );
  }

  String? _daysAgo(String? iso) {
    if (iso == null) return null;
    final date = DateTime.tryParse(iso);
    if (date == null) return null;
    final days = DateTime.now().difference(date).inDays;
    if (days <= 0) return 'Hoy';
    if (days == 1) return 'Hace 1 día';
    return 'Hace $days días';
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

/// Mismo espíritu que `_ClientLogo` de `headhunter_clients_screen.dart`:
/// cuadrado con inicial, coloreado a partir del nombre — acá del cliente si
/// tiene, o del puesto si la búsqueda todavía no está vinculada a uno.
class _SearchLogo extends StatelessWidget {
  const _SearchLogo({required this.name});

  final String name;

  static const _palette = [
    Color(0xFF0A0A14),
    MpTokens.info,
    MpTokens.success,
    MpTokens.premium,
    MpTokens.catPurple,
    MpTokens.catIndigo,
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    final color = _palette[trimmed.isEmpty ? 0 : trimmed.codeUnitAt(0) % _palette.length];

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(MpTokens.radiusMD)),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
  }
}
