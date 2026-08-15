import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../utils/headhunter_candidate_privacy.dart';
import '../../utils/user_columns.dart';
import '../profile_screen.dart';

const headhunterPipelineStatuses = <String>[
  'pending',
  'viewed',
  'interviewing',
  'accepted',
  'hired',
  'rejected',
];

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
                    .from('users')
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
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Pipeline'),
        backgroundColor: CupertinoColors.white,
        border: null,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Pipeline de candidatos',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                  letterSpacing: -0.7,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Postulaciones reales a tus vacantes, por estado',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B778C)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 76,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: headhunterPipelineStatuses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final status = headhunterPipelineStatuses[index];
                  final selected = status == _status;
                  final count = _data.candidates
                      .where((c) => c.status == status)
                      .length;
                  return GestureDetector(
                    onTap: () => setState(() => _status = status),
                    child: Container(
                      width: 116,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF4C2CF3)
                            : CupertinoColors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF4C2CF3)
                              : const Color(0xFFE5E9F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _label(status),
                            style: TextStyle(
                              color: selected
                                  ? CupertinoColors.white
                                  : const Color(0xFF445069),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$count',
                            style: TextStyle(
                              color: selected
                                  ? CupertinoColors.white
                                  : const Color(0xFF172033),
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _body()),
          ],
        ),
      ),
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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: _visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _candidateCard(_visible[index]),
    );
  }

  Widget _candidateCard(HeadhunterPipelineCandidate row) {
    final confidential = row.isConfidential;
    return GestureDetector(
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
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E9F0)),
        ),
        child: Row(
          children: [
            _avatar(row),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    confidential
                        ? headhunterProtectedCandidateName
                        : row.candidate.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF172033),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    confidential ? 'Perfil protegido' : row.jobTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B778C),
                    ),
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(36, 36),
              onPressed: () => _chooseStatus(row),
              child: const Icon(
                CupertinoIcons.ellipsis_vertical,
                size: 18,
                color: Color(0xFF69758A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(HeadhunterPipelineCandidate row) {
    final url = row.isConfidential ? null : row.candidate.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _avatarFallback(),
        ),
      );
    }
    return _avatarFallback();
  }

  Widget _avatarFallback() => Container(
    width: 48,
    height: 48,
    decoration: const BoxDecoration(
      color: Color(0xFFEDEAFF),
      shape: BoxShape.circle,
    ),
    child: const Icon(CupertinoIcons.person_fill, color: Color(0xFF4C2CF3)),
  );

  Widget _empty(IconData icon, String title, String subtitle) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: const Color(0xFF8D98AA)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B778C)),
          ),
        ],
      ),
    ),
  );

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
