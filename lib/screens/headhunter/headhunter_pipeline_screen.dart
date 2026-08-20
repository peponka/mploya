import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../utils/headhunter_candidate_privacy.dart';
import '../../utils/user_columns.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../profile_screen.dart';

/// Pipeline de candidatos de Headhunter.
///
/// Migrada al sistema de diseño (18/8/2026), 2ª pantalla tras
/// `headhunter_dashboard_screen.dart` — mismo patrón documentado ahí.
///
/// SIN mockup 1:1 aplicable, a diferencia de Dashboard. Hay TRES mockups
/// con "pipeline"/"búsqueda" en el nombre
/// (`_Headhunter_Pipeline_Busqueda.png`, `Headhunter_Detalle_Busqueda.png`,
/// `10_Headhunter_Busquedas_Activas.png`) pero los tres describen un
/// producto más grande del que existe hoy: un Kanban de escritorio de 7
/// etapas por vacante individual, con match%, video-thumbnails y
/// sub-navegación (Resumen/Candidatos/Pipeline/Actividades/Notas). La
/// pantalla real es una lista global de candidatos (todas las vacantes
/// juntas) filtrada por 6 estados de `job_applications.status` — no hay
/// concepto de "una búsqueda específica" en el código. Copiar la
/// composición del mockup habría sido inventar una pantalla distinta, así
/// que se extrajo el PATRÓN VISUAL reutilizable en vez de la composición:
///
///   · Selector de estado    → [MpSegmentedFilter] (`scrollable: true`),
///     reemplaza el `ListView` horizontal de `Container`s a mano. Mismo
///     patrón de "Todos 18 | Abiertas 12 | ..." que muestran los 3
///     mockups, aplicado a los 6 estados reales.
///   · Tarjeta de candidato  → [MpRowGroup] de [MpListRow], leading
///     [MpAvatar] (initials de fallback, nunca las de un candidato
///     confidencial — ver abajo), trailing el mismo botón "···" que ya
///     abría el `CupertinoActionSheet` de cambio de etapa.
///   · Estado vacío          → mismo patrón compacto que Dashboard
///     ([MpCard] + [MpIconTile] circular + texto), no [MpEmptyState].
///
/// PRIVACIDAD: un candidato confidencial nunca debe mostrar ni una inicial
/// real. `MpAvatar(name: ...)` usa la primera letra de `name` como
/// fallback — para confidenciales se pasa `name: null` a propósito (cae en
/// "?"), no el nombre protegido (`headhunterProtectedCandidateName`
/// también arrancaría con una letra real: "P" de "Perfil").
class HeadhunterPipelineCandidate {
  const HeadhunterPipelineCandidate({
    required this.applicationId,
    required this.candidate,
    required this.jobTitle,
    required this.status,
    this.appliedAt,
  });

  final String applicationId;
  final NexUser candidate;
  final String jobTitle;
  final String status;
  final DateTime? appliedAt;

  bool get isConfidential => isConfidentialCandidate(candidate);

  HeadhunterPipelineCandidate withStatus(String nextStatus) =>
      HeadhunterPipelineCandidate(
        applicationId: applicationId,
        candidate: candidate,
        jobTitle: jobTitle,
        status: nextStatus,
        appliedAt: appliedAt,
      );
}

const headhunterPipelineStatuses = <String>[
  'pending',
  'viewed',
  'interviewing',
  'accepted',
  'hired',
  'rejected',
];

class HeadhunterPipelineData {
  const HeadhunterPipelineData({required this.candidates, this.error = false});

  final List<HeadhunterPipelineCandidate> candidates;
  final bool error;

  static const empty = HeadhunterPipelineData(candidates: []);
}

class HeadhunterPipelineScreen extends StatefulWidget {
  const HeadhunterPipelineScreen({super.key, this.previewData});

  final HeadhunterPipelineData? previewData;

  @override
  State<HeadhunterPipelineScreen> createState() =>
      _HeadhunterPipelineScreenState();
}

class _HeadhunterPipelineScreenState extends State<HeadhunterPipelineScreen> {
  HeadhunterPipelineData _data = HeadhunterPipelineData.empty;
  bool _loading = true;
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    if (widget.previewData != null) {
      _data = widget.previewData!;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final jobs =
          await client.from('jobs').select('id,title').eq('company_id', uid)
              as List<dynamic>;
      final titles = <String, String>{
        for (final raw in jobs)
          (raw as Map)['id'].toString():
              raw['title']?.toString() ?? 'Vacante sin titulo',
      };
      if (titles.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final applications =
          await client
                  .from('job_applications')
                  .select('id,job_id,candidate_id,status,created_at')
                  .inFilter('job_id', titles.keys.toList())
                  .order('created_at', ascending: false)
              as List<dynamic>;
      final candidateIds = {
        for (final raw in applications)
          if ((raw as Map)['candidate_id'] != null)
            raw['candidate_id'].toString(),
      };
      final users = candidateIds.isEmpty
          ? <dynamic>[]
          : await client
                    .from('accessible_user_profiles')
                    .select(kUserColumns)
                    .inFilter('id', candidateIds.toList())
                as List<dynamic>;
      final protectedUsers = <String, NexUser>{};
      for (final raw in users) {
        final candidate = NexUser.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        protectedUsers[candidate.id] = protectCandidateForHeadhunter(
          candidate,
          'headhunter',
        );
      }

      final rows = <HeadhunterPipelineCandidate>[];
      for (final raw in applications) {
        final row = raw as Map;
        final status = row['status']?.toString().toLowerCase() ?? '';
        final candidate = protectedUsers[row['candidate_id']?.toString()];
        if (candidate == null || !headhunterPipelineStatuses.contains(status)) {
          continue;
        }
        rows.add(
          HeadhunterPipelineCandidate(
            applicationId: row['id']?.toString() ?? '',
            candidate: candidate,
            jobTitle: titles[row['job_id']?.toString()] ?? 'Vacante sin titulo',
            status: status,
            appliedAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _data = HeadhunterPipelineData(candidates: rows);
        _loading = false;
      });
    } catch (error) {
      debugPrint('Headhunter pipeline: $error');
      if (!mounted) return;
      setState(() {
        _data = const HeadhunterPipelineData(candidates: [], error: true);
        _loading = false;
      });
    }
  }

  List<HeadhunterPipelineCandidate> get _visible => _data.candidates
      .where((candidate) => candidate.status == _status)
      .toList();

  List<String> _allowedTransitions(String status) => switch (status) {
    'pending' => const ['viewed', 'interviewing', 'accepted', 'rejected'],
    'viewed' => const ['pending', 'interviewing', 'accepted', 'rejected'],
    'interviewing' => const ['viewed', 'accepted', 'rejected'],
    'accepted' => const ['interviewing', 'hired', 'rejected'],
    'hired' => const ['accepted', 'rejected'],
    'rejected' => const ['pending', 'viewed', 'interviewing', 'accepted'],
    _ => const [],
  };

  Future<void> _chooseStatus(HeadhunterPipelineCandidate row) async {
    final transitions = _allowedTransitions(row.status);
    if (transitions.isEmpty) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Cambiar etapa'),
        message: Text(
          row.isConfidential
              ? headhunterProtectedCandidateName
              : row.candidate.name,
        ),
        actions: [
          for (final status in transitions)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _updateStatus(row, status);
              },
              child: Text(_label(status)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Future<void> _updateStatus(
    HeadhunterPipelineCandidate row,
    String nextStatus,
  ) async {
    try {
      if (widget.previewData == null) {
        await Supabase.instance.client.rpc(
          'update_application_status',
          params: {
            'p_application_id': row.applicationId,
            'p_status': nextStatus,
          },
        );
      }
      if (!mounted) return;
      setState(() {
        _data = HeadhunterPipelineData(
          candidates: [
            for (final candidate in _data.candidates)
              if (candidate.applicationId == row.applicationId)
                candidate.withStatus(nextStatus)
              else
                candidate,
          ],
        );
        _status = nextStatus;
      });
    } catch (error) {
      debugPrint('Headhunter pipeline update: $error');
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('No se pudo cambiar la etapa'),
          content: const Text('La postulacion conserva su estado anterior.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: const Color(0x00000000),
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Pipeline'),
          border: null,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MpTokens.screenPadding,
                  MpTokens.space20,
                  MpTokens.screenPadding,
                  MpTokens.space4,
                ),
                child: _header(),
              ),
              const SizedBox(height: MpTokens.space16),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MpTokens.screenPadding,
                ),
                child: _statusSelector(),
              ),
              const SizedBox(height: MpTokens.space16),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final s = context.mp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pipeline de candidatos',
          style: MpTokens.h2.copyWith(color: s.text, fontSize: 24),
        ),
        const SizedBox(height: MpTokens.space4),
        Text(
          'Postulaciones reales a tus vacantes, por estado',
          style: MpTokens.body.copyWith(color: s.textSecondary),
        ),
      ],
    );
  }

  Widget _statusSelector() {
    return MpSegmentedFilter(
      scrollable: true,
      selectedIndex: headhunterPipelineStatuses.indexOf(_status),
      onChanged: (index) =>
          setState(() => _status = headhunterPipelineStatuses[index]),
      options: [
        for (final status in headhunterPipelineStatuses)
          MpFilterOption(
            _label(status),
            count: _data.candidates.where((c) => c.status == status).length,
          ),
      ],
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CupertinoActivityIndicator());
    if (_data.error) {
      return _empty(
        CupertinoIcons.exclamationmark_triangle,
        'No pudimos cargar el pipeline',
        'Revisa tu conexion y proba de nuevo.',
      );
    }
    if (_visible.isEmpty) {
      return _empty(
        CupertinoIcons.person_2,
        'No hay candidatos en ${_label(_status).toLowerCase()}',
        'El estado cambia solo cuando existe una postulacion real.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        0,
        MpTokens.screenPadding,
        MpTokens.space32,
      ),
      children: [
        MpRowGroup(rows: [for (final row in _visible) _candidateRow(row)]),
      ],
    );
  }

  Widget _candidateRow(HeadhunterPipelineCandidate row) {
    final confidential = row.isConfidential;
    final s = context.mp;

    return MpListRow(
      leading: MpAvatar(
        image: confidential || (row.candidate.avatarUrl?.isEmpty ?? true)
            ? null
            : NetworkImage(row.candidate.avatarUrl!),
        // Nunca la inicial de un nombre real para un confidencial.
        name: confidential ? null : row.candidate.name,
        size: 48,
      ),
      title: confidential ? headhunterProtectedCandidateName : row.candidate.name,
      subtitle: confidential ? 'Perfil protegido' : row.jobTitle,
      showChevron: false,
      trailing: CupertinoButton(
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(36, 36),
        onPressed: () => _chooseStatus(row),
        child: Icon(
          CupertinoIcons.ellipsis_vertical,
          size: 18,
          color: s.textSecondary,
        ),
      ),
      onTap: confidential
          ? null
          : () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => ProfileScreen(
                  user: row.candidate,
                  viewerAccountType: 'headhunter',
                ),
              ),
            ),
    );
  }

  Widget _empty(IconData icon, String title, String subtitle) {
    final s = context.mp;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MpTokens.space32),
        child: MpCard(
          padding: const EdgeInsets.symmetric(
            horizontal: MpTokens.space16,
            vertical: MpTokens.space24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MpIconTile(icon: icon, color: s.textTertiary, size: 40, circular: true),
              const SizedBox(height: MpTokens.space12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: MpTokens.title.copyWith(color: s.text),
              ),
              const SizedBox(height: MpTokens.space4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: MpTokens.caption.copyWith(color: s.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _label(String status) => switch (status) {
    'pending' => 'Nuevos',
    'viewed' => 'Revisados',
    'interviewing' => 'Entrevista',
    'accepted' => 'Aceptados',
    'hired' => 'Contratados',
    'rejected' => 'Descartados',
    _ => status,
  };
}
