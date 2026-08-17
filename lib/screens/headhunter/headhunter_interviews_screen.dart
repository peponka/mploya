import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../utils/headhunter_candidate_privacy.dart';
import '../../utils/user_columns.dart';
import 'headhunter_interview_flow_screen.dart';

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
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Entrevistas'),
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
                'Entrevistas',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                  letterSpacing: -0.7,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Seguimiento real de entrevistas por vacante',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B778C)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _metric(
                      'Pendientes',
                      pending,
                      const Color(0xFFFF9F0A),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _metric(
                      'En curso',
                      inProgress,
                      const Color(0xFF4C2CF3),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _metric(
                      'Completadas',
                      completed,
                      const Color(0xFF24A66A),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, int value, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: CupertinoColors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFE5E9F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(CupertinoIcons.calendar, color: color, size: 20),
        const SizedBox(height: 12),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: Color(0xFF172033),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B778C)),
        ),
      ],
    ),
  );

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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: _data.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _interviewCard(_data.items[index]),
    );
  }

  Widget _interviewCard(HeadhunterInterviewItem item) {
    final confidential = item.isConfidential;
    return GestureDetector(
      onTap: item.id.isEmpty
          ? null
          : () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) =>
                    HeadhunterInterviewFlowScreen(interviewId: item.id),
              ),
            ),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E9F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFFEDEAFF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                confidential
                    ? CupertinoIcons.lock_fill
                    : CupertinoIcons.person_fill,
                color: const Color(0xFF4C2CF3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    confidential
                        ? headhunterProtectedCandidateName
                        : item.candidate.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF172033),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    confidential ? 'Perfil protegido' : item.jobTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B778C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dateLabel(
                      item.completedAt ?? item.createdAt,
                      completed: item.completedAt != null,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8994A7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: _statusColor(item.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel(item.status),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _statusColor(item.status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  String _statusLabel(String status) => switch (status) {
    'in_progress' => 'En curso',
    'completed' => 'Completada',
    _ => 'Pendiente',
  };

  Color _statusColor(String status) => switch (status) {
    'in_progress' => const Color(0xFF4C2CF3),
    'completed' => const Color(0xFF24A66A),
    _ => const Color(0xFFFF8A00),
  };

  String _dateLabel(DateTime date, {required bool completed}) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '${completed ? 'Completada' : 'Creada'} el $day/$month/$year';
  }
}
