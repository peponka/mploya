import 'package:flutter/cupertino.dart';

import '../../services/headhunter_clients_service.dart';
import '../../widgets/ds/mploya_ds.dart';
import 'headhunter_client_form_screen.dart';

/// Mis clientes (Headhunter).
///
/// RECONSTRUCCIÓN de `headhunter clientes.png` (05_Headhunter_Mis_Clientes),
/// el mockup canónico — no del canvas de Claude Design armado antes en la
/// sesión, que era una referencia de trabajo, no la fuente de verdad.
///
/// Reemplaza el passthrough a `HeadhunterPipelineScreen` que había quedado
/// acá (sin commitear, ver git diff previo a este cambio): esa versión hacía
/// que la pestaña "Clientes" del nav abriera una pantalla de candidatos, no
/// de clientes — confusión real, ya en el working tree. Antes de esta
/// versión, el screen tenía un estado vacío honesto ("Mploya todavía no
/// tiene un registro de clientes") porque la tabla no existía; ahora existe
/// (`headhunter_clients`, migraciones 039/041) así que se construye la
/// pantalla real.
///
/// `search_count`/`in_process_count` por cliente salen de
/// `listHeadhunterClientsWithStats` (join en Dart contra `jobs`/
/// `job_applications`, ver el service) — son 0 hasta que el headhunter
/// vincule vacantes a este cliente, cosa que todavía no tiene pantalla
/// propia (queda para la siguiente etapa, junto con "Búsquedas activas").
class HeadhunterClientsScreen extends StatefulWidget {
  const HeadhunterClientsScreen({super.key});

  @override
  State<HeadhunterClientsScreen> createState() =>
      _HeadhunterClientsScreenState();
}

class _HeadhunterClientsScreenState extends State<HeadhunterClientsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _clients = const [];
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final clients = await listHeadhunterClientsWithStats();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _agregarCliente() async {
    final creado = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(builder: (_) => const HeadhunterClientFormScreen()),
    );
    if (creado == true) _load();
  }

  Future<void> _editarCliente(Map<String, dynamic> c) async {
    final editado = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => HeadhunterClientFormScreen(existingClient: c),
      ),
    );
    if (editado == true) _load();
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_filter == 0) return _clients;
    final status = switch (_filter) {
      1 => 'active',
      2 => 'paused',
      _ => 'finished',
    };
    return _clients.where((c) => c['status'] == status).toList();
  }

  int _count(String? status) => status == null
      ? _clients.length
      : _clients.where((c) => c['status'] == status).length;

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
                  title: 'Mis clientes',
                  subtitle: 'Gestioná las empresas para las que reclutás y '
                      'sus búsquedas activas.',
                  actions: [
                    MpIconButton(icon: CupertinoIcons.add, solid: true, onPressed: _agregarCliente),
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
    if (_clients.isEmpty) {
      return [
        const SizedBox(height: MpTokens.space32),
        MpEmptyState(
          icon: CupertinoIcons.building_2_fill,
          title: 'Sin clientes todavía',
          message: 'Agregá las empresas para las que reclutás y empezá a '
              'crear búsquedas para ellas.',
          actionLabel: 'Agregar cliente',
          onAction: _agregarCliente,
        ),
      ];
    }

    return [
      MpSegmentedFilter(
        options: [
          MpFilterOption('Todos', count: _count(null)),
          MpFilterOption('Activos', count: _count('active')),
          MpFilterOption('En pausa', count: _count('paused')),
          MpFilterOption('Finalizados', count: _count('finished')),
        ],
        selectedIndex: _filter,
        onChanged: (i) => setState(() => _filter = i),
      ),
      const SizedBox(height: MpTokens.space16),
      for (final c in _filtrados) ...[
        _clientCard(c),
        const SizedBox(height: MpTokens.space12),
      ],
      const SizedBox(height: MpTokens.space8),
      MpBanner(
        icon: CupertinoIcons.person_2_fill,
        title: 'Sumá nuevos clientes',
        message: 'Agregá empresas y empezá a crear búsquedas para encontrar '
            'el mejor talento.',
        actionLabel: 'Agregar cliente',
        onAction: _agregarCliente,
      ),
    ];
  }

  Widget _clientCard(Map<String, dynamic> c) {
    final s = context.mp;
    final name = (c['company_name'] as String?)?.trim() ?? '';
    final industry = (c['industry'] as String?)?.trim();
    final size = (c['company_size'] as String?)?.trim();
    final city = (c['city'] as String?)?.trim();
    final country = (c['country'] as String?)?.trim();
    final status = (c['status'] as String?) ?? 'active';
    final searchCount = (c['search_count'] as int?) ?? 0;
    final inProcess = (c['in_process_count'] as int?) ?? 0;

    final metaParts = [
      if (industry != null && industry.isNotEmpty) industry,
      if (size != null && size.isNotEmpty) size,
    ].join(' · ');
    final location = [
      if (city != null && city.isNotEmpty) city,
      if (country != null && country.isNotEmpty) country,
    ].join(', ');

    return MpCard(
      onTap: () => _editarCliente(c),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClientLogo(name: name),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Cliente sin nombre' : name,
                  style: MpTokens.title.copyWith(color: s.text),
                ),
                if (metaParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(metaParts, style: MpTokens.caption.copyWith(color: s.textSecondary)),
                ],
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(CupertinoIcons.location_solid, size: 12, color: s.textTertiary),
                      const SizedBox(width: 4),
                      Text(location, style: MpTokens.caption.copyWith(color: s.textTertiary)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: MpTokens.space12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MpStatusBadge(label: _statusLabel(status), status: _statusToMpStatus(status)),
              const SizedBox(height: MpTokens.space16),
              Row(
                children: [
                  _statNumero('$searchCount', searchCount == 1 ? 'Búsqueda' : 'Búsquedas'),
                  const SizedBox(width: MpTokens.space16),
                  _statNumero('$inProcess', 'En proceso'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statNumero(String value, String label) {
    final s = context.mp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value, style: MpTokens.bodyStrong.copyWith(color: s.text, fontSize: 16)),
        Text(label, style: MpTokens.micro.copyWith(color: s.textTertiary)),
      ],
    );
  }

  String _statusLabel(String status) => switch (status) {
        'paused' => 'En pausa',
        'finished' => 'Finalizado',
        _ => 'Activo',
      };

  MpStatus _statusToMpStatus(String status) => switch (status) {
        'paused' => MpStatus.paused,
        'finished' => MpStatus.finished,
        _ => MpStatus.active,
      };
}

/// Logo de cliente: cuadrado con la inicial, coloreado a partir del nombre
/// (paleta fija, no aleatoria por build) — mismo espíritu que el logo de
/// vacante en `headhunter_dashboard_screen.dart`, pero por ahora sin ícono
/// de empresa real: no hay carga de logo en el modelo de datos.
class _ClientLogo extends StatelessWidget {
  const _ClientLogo({required this.name});

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
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(MpTokens.radiusMD),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
