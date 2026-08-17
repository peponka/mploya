import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/my_profile_service.dart';

class HeadhunterDashboardData {
  const HeadhunterDashboardData({
    this.name = '',
    this.jobs = const [],
    this.applications = const [],
    this.interviews = const [],
  });

  final String name;
  final List<Map<String, dynamic>> jobs;
  final List<Map<String, dynamic>> applications;
  final List<Map<String, dynamic>> interviews;
}

class HeadhunterDashboardScreen extends StatefulWidget {
  const HeadhunterDashboardScreen({super.key, this.previewData});

  final HeadhunterDashboardData? previewData;

  @override
  State<HeadhunterDashboardScreen> createState() =>
      _HeadhunterDashboardScreenState();
}

class _HeadhunterDashboardScreenState extends State<HeadhunterDashboardScreen> {
  bool _loading = true;
  String _name = '';
  List<Map<String, dynamic>> _jobs = const [];
  List<Map<String, dynamic>> _applications = const [];
  List<Map<String, dynamic>> _interviews = const [];

  @override
  void initState() {
    super.initState();
    final preview = widget.previewData;
    if (preview != null) {
      _assign(preview);
      _loading = false;
    } else {
      _load();
    }
  }

  void _assign(HeadhunterDashboardData data) {
    _name = data.name;
    _jobs = data.jobs;
    _applications = data.applications;
    _interviews = data.interviews;
  }

  Future<void> _load() async {
    final db = Supabase.instance.client;
    final uid = db.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final me = await loadMyProfile(client: db);
      final jobs = List<Map<String, dynamic>>.from(
        await db
            .from('jobs')
            .select('id, title, status, created_at')
            .eq('company_id', uid)
            .order('created_at', ascending: false),
      );
      final ids = jobs.map((row) => row['id'].toString()).toList();
      final applications = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await db
                  .from('job_applications')
                  .select('job_id, status')
                  .inFilter('job_id', ids),
            );
      final interviews = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await db
                  .from('interviews')
                  .select('id, job_id, status')
                  .inFilter('job_id', ids),
            );
      if (!mounted) return;
      setState(() {
        _assign(
          HeadhunterDashboardData(
            name: me?['name']?.toString() ?? '',
            jobs: jobs,
            applications: applications,
            interviews: interviews,
          ),
        );
        _loading = false;
      });
    } catch (error) {
      debugPrint('Headhunter dashboard: $error');
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _hired => _applications.where((row) {
    final status = row['status']?.toString().toLowerCase();
    return status == 'hired' || status == 'accepted';
  }).length;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      child: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
                children: [
                  Text(
                    _name.trim().isEmpty
                        ? 'Dashboard'
                        : 'Hola, ${_name.trim()}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF172033),
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Actividad real de tu cuenta Headhunter',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B778C)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3820D8), Color(0xFF185FA5)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _heroMetric('Vacantes', _jobs.length)),
                        _heroDivider(),
                        Expanded(
                          child: _heroMetric(
                            'Postulaciones',
                            _applications.length,
                          ),
                        ),
                        _heroDivider(),
                        Expanded(child: _heroMetric('Contratados', _hired)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Resumen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF263247),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _metricCard(
                          CupertinoIcons.briefcase_fill,
                          'Vacantes publicadas',
                          _jobs.length,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _metricCard(
                          CupertinoIcons.calendar,
                          'Entrevistas',
                          _interviews.length,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Vacantes recientes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF263247),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_jobs.isEmpty)
                    _emptyCard()
                  else
                    ..._jobs.take(4).map(_jobCard),
                ],
              ),
      ),
    );
  }

  Widget _heroMetric(String label, int value) => Column(
    children: [
      Text(
        '$value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 27,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFDDE8FF), fontSize: 11.5),
      ),
    ],
  );

  Widget _heroDivider() => Container(
    width: 1,
    height: 48,
    color: Colors.white.withValues(alpha: 0.22),
  );

  Widget _metricCard(IconData icon, String label, int value) => Container(
    height: 122,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFE4E9F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF3820D8)),
        const Spacer(),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF202B3D),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF6D798D)),
        ),
      ],
    ),
  );

  Widget _emptyCard() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFE4E9F0)),
    ),
    child: const Column(
      children: [
        Icon(CupertinoIcons.briefcase, color: Color(0xFF9AA7B8), size: 34),
        SizedBox(height: 10),
        Text(
          'Todavía no publicaste vacantes',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
      ],
    ),
  );

  Widget _jobCard(Map<String, dynamic> job) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFE4E9F0)),
    ),
    child: Row(
      children: [
        const Icon(
          CupertinoIcons.briefcase_fill,
          size: 19,
          color: Color(0xFF185FA5),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            job['title']?.toString().trim().isNotEmpty == true
                ? job['title'].toString()
                : 'Vacante sin título',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF263247),
            ),
          ),
        ),
      ],
    ),
  );
}
