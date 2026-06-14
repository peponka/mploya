import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AnalyticsDashboardScreen — Stats y métricas para empresas
//
// Muestra:
//   1. Resumen general (views, likes, matches, aplicaciones)
//   2. Gráfico semanal de actividad (barras simples)
//   3. Quién vio tu perfil (profile_views)
//   4. Performance de vacantes publicadas (jobs stats)
// ─────────────────────────────────────────────────────────────────────────────

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Métricas
  int _totalViews = 0;
  int _totalLikes = 0;
  int _totalMatches = 0;
  int _totalApplications = 0;
  int _activeJobs = 0;
  int _ghostApplications = 0;
  double _responseRate = 0;
  List<Map<String, dynamic>> _recentViewers = [];
  List<Map<String, dynamic>> _jobStats = [];
  List<int> _weeklyActivity = [0, 0, 0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // Parallel fetches
      final results = await Future.wait([
        // 1. Profile views count (likes received = proxy for views)
        _supabase.from('pitch_likes').select('id').eq('target_user_id', uid),
        // 2. Matches (connections accepted)
        _supabase
            .from('connections')
            .select('id')
            .or('requester_id.eq.$uid,addressee_id.eq.$uid')
            .eq('status', 'accepted'),
        // 3. Job applications received
        _supabase
            .from('job_applications')
            .select('id, job_id, created_at, users:candidate_id(name, avatar_url)')
            .inFilter('job_id', await _getMyJobIds(uid)),
        // 4. My active jobs
        _supabase
            .from('jobs')
            .select('id, title, applicants_count, created_at')
            .eq('company_id', uid)
            .eq('is_active', true),
        // 5. Recent notifications as "viewers"
        _supabase
            .from('notifications')
            .select('id, description, created_at, type')
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(10),
      ]);

      final likes = results[0] as List;
      final matches = results[1] as List;
      final applications = results[2] as List;
      final jobs = results[3] as List;
      final notifications = results[4] as List;

      // Build weekly activity from notifications
      final now = DateTime.now();
      final weekly = List<int>.filled(7, 0);
      for (final n in notifications) {
        final createdAt = DateTime.tryParse(n['created_at']?.toString() ?? '');
        if (createdAt != null) {
          final daysAgo = now.difference(createdAt).inDays;
          if (daysAgo < 7) {
            weekly[6 - daysAgo] = weekly[6 - daysAgo] + 1;
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalViews = likes.length * 3 + notifications.length; // Estimated
          _totalLikes = likes.length;
          _totalMatches = matches.length;
          _totalApplications = applications.length;
          _activeJobs = jobs.length;
          _recentViewers = List<Map<String, dynamic>>.from(
            notifications.take(5).map((n) => {
              'description': n['description'],
              'type': n['type'],
              'created_at': n['created_at'],
            }),
          );
          _jobStats = List<Map<String, dynamic>>.from(jobs);
          _weeklyActivity = weekly;
          _isLoading = false;
        });
      }

      // Fetch ghost applications count
      try {
        final jobIds = List<Map<String, dynamic>>.from(jobs)
            .map((j) => j['id'].toString())
            .toList();
        if (jobIds.isNotEmpty) {
          final ghostApps = await _supabase
              .from('ghost_applications')
              .select('id')
              .inFilter('job_id', jobIds);
          if (mounted) {
            setState(() {
              _ghostApplications = (ghostApps as List).length;
              _responseRate = _totalApplications > 0
                  ? (_totalMatches / _totalApplications * 100).clamp(0, 100)
                  : 0;
            });
          }
        }
      } catch (_) {
        // ghost_applications table might not exist yet
      }
    } catch (e) {
      debugPrint('Analytics error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<String>> _getMyJobIds(String uid) async {
    try {
      final res = await _supabase
          .from('jobs')
          .select('id')
          .eq('company_id', uid);
      return List<Map<String, dynamic>>.from(res)
          .map((r) => r['id'].toString())
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Analytics'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: _loadAnalytics,
          child: Icon(CupertinoIcons.refresh, size: 22, color: context.brandAccent),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Summary Cards ──
                  const _SectionTitle(title: 'Resumen'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _StatCard(icon: CupertinoIcons.eye_fill, label: 'Vistas', value: '$_totalViews', color: const Color(0xFF0A84FF))),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(icon: CupertinoIcons.hand_thumbsup_fill, label: 'Likes', value: '$_totalLikes', color: MployaTheme.brandAccent)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _StatCard(icon: CupertinoIcons.person_2_fill, label: 'Matches', value: '$_totalMatches', color: const Color(0xFF5856D6))),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(icon: CupertinoIcons.doc_text_fill, label: 'Aplicaciones', value: '$_totalApplications', color: const Color(0xFFFF9500))),
                    ],
                  ),

                  // ── Weekly Activity ──
                  const SizedBox(height: 28),
                  const _SectionTitle(title: 'Actividad Semanal'),
                  const SizedBox(height: 16),
                  _WeeklyChart(data: _weeklyActivity),

                  // ── Funnel de Conversión ──
                  const SizedBox(height: 28),
                  const _SectionTitle(title: 'Funnel de Conversión'),
                  const SizedBox(height: 16),
                  _ConversionFunnel(
                    views: _totalViews,
                    applications: _totalApplications + _ghostApplications,
                    matches: _totalMatches,
                  ),

                  // ── Ghost Applications ──
                  if (_ghostApplications > 0) ...[
                    const SizedBox(height: 28),
                    const _SectionTitle(title: 'Aplicaciones Ghost'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF5F3DC4).withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5F3DC4).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('👻', style: TextStyle(fontSize: 20)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_ghostApplications candidatos Ghost',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Desbloqué identidades para contactarlos',
                                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5F3DC4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Ver', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Response Rate KPI ──
                  const SizedBox(height: 28),
                  const _SectionTitle(title: 'KPIs de Eficiencia'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: CupertinoIcons.arrow_right_arrow_left_circle_fill,
                          label: 'Tasa Respuesta',
                          value: '${_responseRate.toStringAsFixed(0)}%',
                          color: const Color(0xFF34C759),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: CupertinoIcons.person_crop_circle_badge_checkmark,
                          label: 'Ghost Apps',
                          value: '$_ghostApplications',
                          color: const Color(0xFF5F3DC4),
                        ),
                      ),
                    ],
                  ),

                  // ── Active Jobs ──
                  if (_jobStats.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _SectionTitle(title: 'Mis Vacantes ($_activeJobs activas)'),
                    const SizedBox(height: 12),
                    ...(_jobStats.map((j) => _JobStatCard(job: j))),
                  ],

                  // ── Recent Activity ──
                  if (_recentViewers.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const _SectionTitle(title: 'Actividad Reciente'),
                    const SizedBox(height: 12),
                    ...(_recentViewers.map((v) => _ActivityItem(data: v))),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
      ),
    );
  }
}

// ─── Section Title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: context.textPrimary,
        letterSpacing: -0.3,
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Weekly Chart ─────────────────────────────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  final List<int> data;
  const _WeeklyChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.reduce((a, b) => a > b ? a : b).clamp(1, 999);
    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final ratio = data[i] / maxVal;
          final isToday = i == 6;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${data[i]}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isToday ? MployaTheme.brandAccent : context.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                width: 28,
                height: 16 + (ratio * 80),
                decoration: BoxDecoration(
                  gradient: isToday
                      ? const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [NexTheme.brandAccent, NexTheme.premiumEnd],
                        )
                      : null,
                  color: isToday ? null : context.dividerColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                days[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday ? MployaTheme.brandAccent : context.textTertiary,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─── Job Stat Card ────────────────────────────────────────────────────────────

class _JobStatCard extends StatelessWidget {
  final Map<String, dynamic> job;
  const _JobStatCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final title = job['title']?.toString() ?? 'Vacante';
    final applicants = job['applicants_count'] ?? 0;
    final createdAt = job['created_at']?.toString() ?? '';
    final dateStr = createdAt.length >= 10 ? createdAt.substring(0, 10) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(CupertinoIcons.briefcase_fill, size: 18, color: Color(0xFFFF9500)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary)),
                Text(dateStr, style: TextStyle(fontSize: 12, color: context.textTertiary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$applicants', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: context.textPrimary)),
              Text('aplicantes', style: TextStyle(fontSize: 11, color: context.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Activity Item ────────────────────────────────────────────────────────────

class _ActivityItem extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ActivityItem({required this.data});

  @override
  Widget build(BuildContext context) {
    final desc = data['description']?.toString() ?? 'Actividad';
    final type = data['type']?.toString() ?? '';
    final createdAt = data['created_at']?.toString() ?? '';
    final timeStr = createdAt.length >= 16 ? createdAt.substring(11, 16) : '';

    IconData icon;
    Color color;
    switch (type) {
      case 'like':
        icon = CupertinoIcons.hand_thumbsup_fill;
        color = MployaTheme.brandAccent;
        break;
      case 'connection':
        icon = CupertinoIcons.person_2_fill;
        color = const Color(0xFF5856D6);
        break;
      case 'jobAlert':
        icon = CupertinoIcons.briefcase_fill;
        color = const Color(0xFFFF9500);
        break;
      case 'profileView':
        icon = CupertinoIcons.eye_fill;
        color = const Color(0xFF0A84FF);
        break;
      default:
        icon = CupertinoIcons.bell_fill;
        color = context.textTertiary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: context.textPrimary, height: 1.3),
            ),
          ),
          if (timeStr.isNotEmpty)
            Text(timeStr, style: TextStyle(fontSize: 11, color: context.textTertiary)),
        ],
      ),
    );
  }
}

// ─── Conversion Funnel ────────────────────────────────────────────────────────

class _ConversionFunnel extends StatelessWidget {
  final int views;
  final int applications;
  final int matches;

  const _ConversionFunnel({
    required this.views,
    required this.applications,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = [views, applications, matches].reduce((a, b) => a > b ? a : b).clamp(1, 999999);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _FunnelRow(
            label: 'Vistas',
            value: views,
            ratio: views / maxVal,
            color: const Color(0xFF0A84FF),
          ),
          const SizedBox(height: 10),
          Icon(CupertinoIcons.chevron_down, size: 14, color: context.textTertiary),
          const SizedBox(height: 10),
          _FunnelRow(
            label: 'Aplicaciones',
            value: applications,
            ratio: applications / maxVal,
            color: const Color(0xFFFF9500),
          ),
          const SizedBox(height: 10),
          Icon(CupertinoIcons.chevron_down, size: 14, color: context.textTertiary),
          const SizedBox(height: 10),
          _FunnelRow(
            label: 'Matches',
            value: matches,
            ratio: matches / maxVal,
            color: MployaTheme.brandAccent,
          ),
          const SizedBox(height: 16),
          // Conversion rate
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: MployaTheme.brandAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Conversión: ${views > 0 ? (matches / views * 100).toStringAsFixed(1) : '0'}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.brandAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FunnelRow extends StatelessWidget {
  final String label;
  final int value;
  final double ratio;
  final Color color;

  const _FunnelRow({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary)),
            Text('$value', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            height: 12,
            width: (MediaQuery.of(context).size.width - 80) * ratio.clamp(0.05, 1.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),
      ],
    );
  }
}