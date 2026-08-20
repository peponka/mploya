import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../utils/headhunter_candidate_privacy.dart';
import '../../utils/user_columns.dart';
import '../../widgets/ds/mploya_ds.dart';
import 'headhunter_interview_flow_screen.dart';

/// Lista de entrevistas de Headhunter.
///
/// Migrada al sistema de diseño (18/8/2026), 4ª pantalla — mismo patrón de
/// `headhunter_dashboard_screen.dart`. Primera de la "familia de
/// entrevistas" (ésta, `headhunter_interview_flow_screen.dart`,
/// `headhunter_interview_report_screen.dart`), migradas juntas para
/// reusar decisiones.
///
/// SIN mockup 1:1 (mismo motivo que Pipeline/Talent Pool: "entrevistas
/// nuevas.png"/"entrevistas video.png" son genéricos, no de Headhunter, y
/// no coinciden con el modelo real de datos). Patrón:
///
///   · 3 métricas (Pendientes/En curso/Completadas) → [MpStatTile], igual
///     que la grilla de Dashboard.
///   · Tarjeta de entrevista → [MpRowGroup] de [MpListRow]: `badge` con
///     [MpTypeChip] para el estado (reemplaza el pill manual), `subtitle`
///     con el puesto (o "Perfil protegido"), `trailingText` con la fecha.
///     `showChevron` queda TRUE a propósito, a diferencia de Pipeline: acá
///     cada fila SÍ navega a un detalle (`HeadhunterInterviewFlowScreen`).
///
/// IMPORTANTE PARA LAS OTRAS DOS: `headhunterProtectedCandidateName`
/// ('Talento confidencial') es el nombre, 'Perfil protegido' es el
/// subtítulo — dos strings fijos que los tests verifican literal
/// (`headhunter_polish_4_test.dart`/`headhunter_polish_6_test.dart`). No
/// cambiar ninguno de los dos en las próximas pantallas.
class HeadhunterInterviewItem {
  const HeadhunterInterviewItem({
    required this.id,
    required this.candidate,
    required this.jobTitle,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final NexUser candidate;
  final String jobTitle;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isConfidential => isConfidentialCandidate(candidate);
}

class HeadhunterInterviewsData {
  const HeadhunterInterviewsData({required this.items, this.error = false});

  final List<HeadhunterInterviewItem> items;
  final bool error;

  static const empty = HeadhunterInterviewsData(items: []);
}

class HeadhunterInterviewsScreen extends StatefulWidget {
  const HeadhunterInterviewsScreen({super.key, this.previewData});

  final HeadhunterInterviewsData? previewData;

  @override
  State<HeadhunterInterviewsScreen> createState() =>
      _HeadhunterInterviewsScreenState();
}

class _HeadhunterInterviewsScreenState
    extends State<HeadhunterInterviewsScreen> {
  HeadhunterInterviewsData _data = HeadhunterInterviewsData.empty;
  bool _loading = true;

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
      final interviews =
          await client
                  .from('interviews')
                  .select(
                    'id,job_id,candidate_id,status,created_at,completed_at',
                  )
                  .inFilter('job_id', titles.keys.toList())
                  .order('created_at', ascending: false)
              as List<dynamic>;
      final candidateIds = {
        for (final raw in interviews)
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
      final items = <HeadhunterInterviewItem>[];
      for (final raw in interviews) {
        final row = raw as Map;
        final candidate = protectedUsers[row['candidate_id']?.toString()];
        final createdAt = DateTime.tryParse(
          row['created_at']?.toString() ?? '',
        );
        if (candidate == null || createdAt == null) continue;
        items.add(
          HeadhunterInterviewItem(
            id: row['id']?.toString() ?? '',
            candidate: candidate,
            jobTitle: titles[row['job_id']?.toString()] ?? 'Vacante sin titulo',
            status: row['status']?.toString() ?? 'pending',
            createdAt: createdAt,
            completedAt: DateTime.tryParse(
              row['completed_at']?.toString() ?? '',
            ),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _data = HeadhunterInterviewsData(items: items);
        _loading = false;
      });
    } catch (error) {
      debugPrint('Headhunter interviews: $error');
      if (!mounted) return;
      setState(() {
        _data = const HeadhunterInterviewsData(items: [], error: true);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _data.items
        .where((item) => item.status == 'pending')
        .length;
    final inProgress = _data.items
        .where((item) => item.status == 'in_progress')
        .length;
    final completed = _data.items
        .where((item) => item.status == 'completed')
        .length;

    return MpSurface(
      style: MpSurfaceStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: const Color(0x00000000),
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Entrevistas'),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MpTokens.screenPadding,
                  MpTokens.space16,
                  MpTokens.screenPadding,
                  MpTokens.space16,
                ),
                child: _metricsRow(pending, inProgress, completed),
              ),
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
        Text('Entrevistas', style: MpTokens.h2.copyWith(color: s.text, fontSize: 24)),
        const SizedBox(height: MpTokens.space4),
        Text(
          'Seguimiento real de entrevistas por vacante',
          style: MpTokens.body.copyWith(color: s.textSecondary),
        ),
      ],
    );
  }

  Widget _metricsRow(int pending, int inProgress, int completed) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MpStatTile(
              icon: CupertinoIcons.calendar,
              color: MpTokens.premium,
              value: '$pending',
              label: 'Pendientes',
              compact: true,
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          Expanded(
            child: MpStatTile(
              icon: CupertinoIcons.calendar,
              color: MpTokens.primary,
              value: '$inProgress',
              label: 'En curso',
              compact: true,
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          Expanded(
            child: MpStatTile(
              icon: CupertinoIcons.calendar,
              color: MpTokens.success,
              value: '$completed',
              label: 'Completadas',
              compact: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CupertinoActivityIndicator());
    if (_data.error) {
      return _empty(
        CupertinoIcons.exclamationmark_triangle,
        'No pudimos cargar las entrevistas',
        'Revisa tu conexion y proba de nuevo.',
      );
    }
    if (_data.items.isEmpty) {
      return _empty(
        CupertinoIcons.calendar_badge_plus,
        'Todavia no hay entrevistas',
        'Las entrevistas reales de tus vacantes apareceran aca.',
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
        MpRowGroup(
          rows: [for (final item in _data.items) _interviewRow(item)],
        ),
      ],
    );
  }

  Widget _interviewRow(HeadhunterInterviewItem item) {
    final confidential = item.isConfidential;

    return MpListRow(
      leading: MpIconTile(
        icon: confidential ? CupertinoIcons.lock_fill : CupertinoIcons.person_fill,
        color: MpTokens.primary,
        size: 46,
        circular: true,
      ),
      title: confidential ? headhunterProtectedCandidateName : item.candidate.name,
      subtitle: confidential ? 'Perfil protegido' : item.jobTitle,
      badge: MpTypeChip(
        label: _statusLabel(item.status),
        color: _statusColor(item.status),
      ),
      trailingText: _dateLabel(
        item.completedAt ?? item.createdAt,
        completed: item.completedAt != null,
      ),
      // MpListRow sólo apaga el chevron automáticamente cuando se usa
      // `trailing` (widget); con `trailingText` hay que apagarlo a mano o
      // dibuja los dos y desborda — esto causó un overflow real de 11px en
      // 393pt (visto en headhunter_polish_4_test.dart, "entrevistas
      // normal"). El original tampoco tenía chevron acá.
      showChevron: false,
      onTap: item.id.isEmpty
          ? null
          : () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) =>
                    HeadhunterInterviewFlowScreen(interviewId: item.id),
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

  String _statusLabel(String status) => switch (status) {
    'in_progress' => 'En curso',
    'completed' => 'Completada',
    _ => 'Pendiente',
  };

  Color _statusColor(String status) => switch (status) {
    'in_progress' => MpTokens.primary,
    'completed' => MpTokens.success,
    _ => MpTokens.premium,
  };

  String _dateLabel(DateTime date, {required bool completed}) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '${completed ? 'Completada' : 'Creada'} el $day/$month/$year';
  }
}
