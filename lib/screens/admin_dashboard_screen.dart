import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _sb = Supabase.instance.client;

  bool _checkingAccess = true;
  bool _isAdmin = false;
  String? _accessError;

  int _tab = 0;
  static const _tabs = ['Resumen', 'Usuarios', 'Empresas', 'Ofertas', 'Boosts', 'Reportes'];

  @override
  void initState() {
    super.initState();
    _verifyAdmin();
  }

  Future<void> _verifyAdmin() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _checkingAccess = false;
        _isAdmin = false;
        _accessError = 'Necesitás iniciar sesión.';
      });
      return;
    }
    try {
      final row = await _sb.from('users').select('is_admin').eq('id', uid).maybeSingle();
      final isAdmin = row?['is_admin'] == true;
      setState(() {
        _checkingAccess = false;
        _isAdmin = isAdmin;
        if (!isAdmin) _accessError = 'No tenés permisos de administrador.';
      });
    } catch (e) {
      setState(() {
        _checkingAccess = false;
        _isAdmin = false;
        _accessError = 'No se pudo verificar el acceso.\n\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA),
      body: SafeArea(
        child: _checkingAccess
            ? const Center(child: CircularProgressIndicator())
            : !_isAdmin
                ? _AccessDenied(message: _accessError ?? 'Acceso denegado')
                : _buildAdmin(context),
      ),
    );
  }

  Widget _buildAdmin(BuildContext context) {
    return Column(
      children: [
        _AdminTopBar(
          tabs: _tabs,
          current: _tab,
          onTab: (i) => setState(() => _tab = i),
          onClose: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: IndexedStack(
                  index: _tab,
                  children: const [
                    _OverviewTab(),
                    _UsersTab(accountFilter: null, title: 'Usuarios'),
                    _UsersTab(accountFilter: 'empresa', title: 'Empresas'),
                    _JobsTab(),
                    _BoostsTab(),
                    _ReportsTab(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────
class _AdminTopBar extends StatelessWidget {
  final List<String> tabs;
  final int current;
  final ValueChanged<int> onTab;
  final VoidCallback onClose;

  const _AdminTopBar({
    required this.tabs,
    required this.current,
    required this.onTab,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: MployaTheme.brandAccent),
          const SizedBox(width: 10),
          Text(
            'Admin',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _TabChip(
                        label: tabs[i],
                        active: i == current,
                        onTap: () => onTab(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: context.textSecondary),
            tooltip: 'Salir',
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? MployaTheme.brandAccent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? MployaTheme.brandAccent : context.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resumen con gráficos
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewTab extends StatefulWidget {
  const _OverviewTab();
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  final Map<String, int> _kpis = {};
  List<FlSpot> _growthSpots = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<int> _count(String table, {String? col, Object? val}) async {
    var q = _sb.from(table).select('id');
    if (col != null) q = q.eq(col, val!);
    final res = await q.count(CountOption.exact);
    return res.count;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final since24h = DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String();
      final since30d = DateTime.now().toUtc().subtract(const Duration(days: 30)).toIso8601String();

      final results = await Future.wait([
        _count('users'),
        _count('users', col: 'account_type', val: 'candidato'),
        _count('users', col: 'account_type', val: 'empresa'),
        _count('users', col: 'account_type', val: 'headhunter'),
        _count('users', col: 'account_type', val: 'confidencial'),
        _count('jobs'),
        _count('job_applications'),
      ]);

      _kpis['Usuarios'] = results[0];
      _kpis['Candidatos'] = results[1];
      _kpis['Empresas'] = results[2];
      _kpis['Headhunters'] = results[3];
      _kpis['Confidenciales'] = results[4];
      _kpis['Ofertas'] = results[5];
      _kpis['Postulaciones'] = results[6];

      try {
        final b = await _sb.from('users').select('id').gt('boost_ends_at', nowIso).count(CountOption.exact);
        _kpis['Boosts activos'] = b.count;
      } catch (_) { _kpis['Boosts activos'] = 0; }

      try {
        _kpis['Vistas de perfil'] = await _count('profile_views');
      } catch (_) { _kpis['Vistas de perfil'] = 0; }

      try {
        final v = await _sb.from('profile_views').select('id').gte('created_at', since24h).count(CountOption.exact);
        _kpis['Vistas (24h)'] = v.count;
      } catch (_) { _kpis['Vistas (24h)'] = 0; }

      try {
        final r = await _sb.from('user_reports').select('id').eq('status', 'pending').count(CountOption.exact);
        _kpis['Reportes pendientes'] = r.count;
      } catch (_) { _kpis['Reportes pendientes'] = 0; }

      // Crecimiento últimos 30 días
      try {
        final rows = await _sb.from('users').select('created_at').gte('created_at', since30d);
        final Map<int, int> byDay = {};
        final now = DateTime.now();
        for (final row in rows as List) {
          final dt = DateTime.parse(row['created_at'] as String);
          final daysAgo = now.difference(dt).inDays.clamp(0, 30);
          final idx = 30 - daysAgo;
          byDay[idx] = (byDay[idx] ?? 0) + 1;
        }
        _growthSpots = List.generate(31, (i) => FlSpot(i.toDouble(), (byDay[i] ?? 0).toDouble()));
      } catch (_) { _growthSpots = []; }

      setState(() => _loading = false);
    } catch (e) {
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorState(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          // Header
          Row(children: [
            Text('Resumen', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary)),
            const Spacer(),
            IconButton(onPressed: _load, icon: Icon(Icons.refresh, color: context.textSecondary)),
          ]),
          const SizedBox(height: 20),

          // KPI cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _KpiCard(label: 'Usuarios totales', value: _kpis['Usuarios'] ?? 0, icon: Icons.people_alt_outlined, color: const Color(0xFF3B82F6)),
              _KpiCard(label: 'Candidatos', value: _kpis['Candidatos'] ?? 0, icon: Icons.person_outline, color: const Color(0xFF22C55E)),
              _KpiCard(label: 'Empresas', value: _kpis['Empresas'] ?? 0, icon: Icons.business_outlined, color: const Color(0xFF6366F1)),
              _KpiCard(label: 'Headhunters', value: _kpis['Headhunters'] ?? 0, icon: Icons.manage_search, color: const Color(0xFFF59E0B)),
              _KpiCard(label: 'Confidenciales', value: _kpis['Confidenciales'] ?? 0, icon: Icons.visibility_off_outlined, color: const Color(0xFF64748B)),
              _KpiCard(label: 'Ofertas', value: _kpis['Ofertas'] ?? 0, icon: Icons.work_outline, color: const Color(0xFF06B6D4)),
              _KpiCard(label: 'Postulaciones', value: _kpis['Postulaciones'] ?? 0, icon: Icons.send_outlined, color: const Color(0xFF14B8A6)),
              _KpiCard(label: 'Boosts activos', value: _kpis['Boosts activos'] ?? 0, icon: Icons.rocket_launch_outlined, color: MployaTheme.brandAccent),
              _KpiCard(label: 'Vistas de perfil', value: _kpis['Vistas de perfil'] ?? 0, icon: Icons.visibility_outlined, color: const Color(0xFFEC4899)),
              _KpiCard(label: 'Vistas (24h)', value: _kpis['Vistas (24h)'] ?? 0, icon: Icons.trending_up, color: const Color(0xFFF43F5E)),
              _KpiCard(label: 'Reportes pend.', value: _kpis['Reportes pendientes'] ?? 0, icon: Icons.flag_outlined, color: MployaTheme.danger),
            ],
          ),
          const SizedBox(height: 28),

          // Distribución + Actividad
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 620;
            final pie = _buildPieCard(context);
            final act = _buildActivityCard(context);
            if (wide) {
              return IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: pie),
                  const SizedBox(width: 16),
                  Expanded(child: act),
                ]),
              );
            }
            return Column(children: [pie, const SizedBox(height: 16), act]);
          }),
          const SizedBox(height: 16),

          // Gráfico de crecimiento
          _ChartCard(
            title: 'Nuevos usuarios — últimos 30 días',
            child: SizedBox(
              height: 200,
              child: _growthSpots.isEmpty
                  ? Center(child: Text('Sin datos', style: TextStyle(color: context.textTertiary)))
                  : _GrowthLineChart(spots: _growthSpots),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPieCard(BuildContext context) {
    final total = _kpis['Usuarios'] ?? 0;
    final candidatos = _kpis['Candidatos'] ?? 0;
    final empresas = _kpis['Empresas'] ?? 0;
    final headhunters = _kpis['Headhunters'] ?? 0;
    final confidenciales = _kpis['Confidenciales'] ?? 0;

    final hasSections = candidatos + empresas + headhunters + confidenciales > 0;
    final sections = hasSections
        ? [
            if (candidatos > 0) PieChartSectionData(value: candidatos.toDouble(), color: const Color(0xFF22C55E), title: '', radius: 60),
            if (empresas > 0) PieChartSectionData(value: empresas.toDouble(), color: const Color(0xFF6366F1), title: '', radius: 60),
            if (headhunters > 0) PieChartSectionData(value: headhunters.toDouble(), color: const Color(0xFFF59E0B), title: '', radius: 60),
            if (confidenciales > 0) PieChartSectionData(value: confidenciales.toDouble(), color: const Color(0xFF64748B), title: '', radius: 60),
          ]
        : [PieChartSectionData(value: 1, color: const Color(0xFFE5E7EB), title: '', radius: 60)];

    return _ChartCard(
      title: 'Distribución de cuentas',
      child: Row(children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(PieChartData(
                  sections: sections,
                  centerSpaceRadius: 52,
                  sectionsSpace: 2,
                  pieTouchData: PieTouchData(enabled: false),
                )),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$total',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: context.textPrimary, height: 1)),
                  Text('usuarios', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendRow('Candidatos', const Color(0xFF22C55E), candidatos, total),
              const SizedBox(height: 10),
              _LegendRow('Empresas', const Color(0xFF6366F1), empresas, total),
              const SizedBox(height: 10),
              _LegendRow('Headhunters', const Color(0xFFF59E0B), headhunters, total),
              const SizedBox(height: 10),
              _LegendRow('Confidenciales', const Color(0xFF64748B), confidenciales, total),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildActivityCard(BuildContext context) {
    final ofertas = _kpis['Ofertas'] ?? 0;
    final postulaciones = _kpis['Postulaciones'] ?? 0;
    final boosts = _kpis['Boosts activos'] ?? 0;
    final vistas24h = _kpis['Vistas (24h)'] ?? 0;
    final reportes = _kpis['Reportes pendientes'] ?? 0;
    final usuarios = (_kpis['Usuarios'] ?? 1).clamp(1, 999999);

    return _ChartCard(
      title: 'Actividad',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ActivityRow('Ofertas publicadas', Icons.work_outline, const Color(0xFF06B6D4), ofertas, usuarios),
          const SizedBox(height: 14),
          _ActivityRow('Postulaciones', Icons.send_outlined, const Color(0xFF14B8A6), postulaciones, usuarios),
          const SizedBox(height: 14),
          _ActivityRow('Boosts activos', Icons.rocket_launch_outlined, MployaTheme.brandAccent, boosts, usuarios),
          const SizedBox(height: 14),
          _ActivityRow('Vistas (24h)', Icons.visibility_outlined, const Color(0xFFEC4899), vistas24h, (vistas24h + 1)),
          const SizedBox(height: 14),
          _ActivityRow('Reportes pendientes', Icons.flag_outlined, MployaTheme.danger, reportes, 10.clamp(reportes, 999)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI Card mejorada
// ─────────────────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final display = value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : '$value';
    return Container(
      width: 185,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF222222) : const Color(0xFFEDEFF2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 14),
        Text(display,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
              letterSpacing: -1,
              height: 1,
            )),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textSecondary)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chart card wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF222222) : const Color(0xFFEDEFF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leyenda del pie
// ─────────────────────────────────────────────────────────────────────────────
class _LegendRow extends StatelessWidget {
  final String label;
  final Color color;
  final int value;
  final int total;
  const _LegendRow(this.label, this.color, this.value, this.total);

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value * 100 / total).round() : 0;
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary))),
      Text('$value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.textPrimary)),
      const SizedBox(width: 4),
      Text('$pct%', style: TextStyle(fontSize: 11, color: context.textTertiary)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra de actividad
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int value;
  final int max;
  const _ActivityRow(this.label, this.icon, this.color, this.value, this.max);

  @override
  Widget build(BuildContext context) {
    final ratio = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Row(children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary))),
            Text('$value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.textPrimary)),
          ]),
          const SizedBox(height: 5),
          LayoutBuilder(builder: (ctx, c) => Stack(children: [
            Container(height: 5, width: double.infinity,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3))),
            Container(height: 5, width: c.maxWidth * ratio,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          ])),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Line chart de crecimiento
// ─────────────────────────────────────────────────────────────────────────────
class _GrowthLineChart extends StatelessWidget {
  final List<FlSpot> spots;
  const _GrowthLineChart({required this.spots});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final gridColor = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFEDEFF2);
    final labelColor = context.textTertiary;
    final maxY = spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 30,
        minY: 0,
        maxY: (maxY + 1).ceilToDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 0.8),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 5,
              getTitlesWidget: (value, meta) {
                final date = DateTime.now().subtract(Duration(days: 30 - value.toInt()));
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text('${date.day}/${date.month}',
                      style: TextStyle(fontSize: 10, color: labelColor)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value != value.roundToDouble()) return const SizedBox();
                return Text('${value.toInt()}',
                    style: TextStyle(fontSize: 10, color: labelColor));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: MployaTheme.brandAccent,
            barWidth: 2.5,
            isStrokeCapRound: true,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MployaTheme.brandAccent.withValues(alpha: 0.18),
                  MployaTheme.brandAccent.withValues(alpha: 0.0),
                ],
              ),
            ),
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Usuarios / Empresas
// ─────────────────────────────────────────────────────────────────────────────
class _UsersTab extends StatefulWidget {
  final String? accountFilter;
  final String title;
  const _UsersTab({required this.accountFilter, required this.title});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      var q = _sb.from('users').select(
          'id, name, email, account_type, is_verified, is_premium, location, video_url, created_at');
      if (widget.accountFilter != null) q = q.eq('account_type', widget.accountFilter!);
      final data = await q.order('created_at', ascending: false).limit(200);
      setState(() {
        _rows = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _toggleVerified(Map<String, dynamic> u) async {
    final newVal = !(u['is_verified'] == true);
    try {
      await _sb.from('users').update({'is_verified': newVal}).eq('id', u['id']);
      setState(() => u['is_verified'] = newVal);
    } catch (e) {
      _snack('No se pudo actualizar: $e');
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorState(message: _error!, onRetry: _load);

    final filtered = _rows.where((u) {
      if (_search.isEmpty) return true;
      final s = _search.toLowerCase();
      return (u['name'] ?? '').toString().toLowerCase().contains(s) ||
          (u['email'] ?? '').toString().toLowerCase().contains(s);
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(widget.title,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary)),
        const SizedBox(width: 12),
        Text('(${filtered.length})', style: TextStyle(color: context.textTertiary)),
        const Spacer(),
        SizedBox(
          width: 280,
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Buscar…',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      const SizedBox(height: 16),
      if (filtered.isEmpty)
        const Expanded(child: _EmptyState(message: 'Sin resultados'))
      else
        Expanded(
          child: SingleChildScrollView(
            child: SizedBox(
              width: double.infinity,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Nombre')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Tipo')),
                  DataColumn(label: Text('Video')),
                  DataColumn(label: Text('Verificado')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: [
                  for (final u in filtered)
                    DataRow(cells: [
                      DataCell(Text(u['name']?.toString() ?? '—')),
                      DataCell(Text(u['email']?.toString() ?? '—')),
                      DataCell(Text(u['account_type']?.toString() ?? '—')),
                      DataCell(Icon(
                        (u['video_url'] != null && u['video_url'].toString().isNotEmpty)
                            ? Icons.check_circle
                            : Icons.remove_circle_outline,
                        color: (u['video_url'] != null && u['video_url'].toString().isNotEmpty)
                            ? Colors.green
                            : context.textTertiary,
                        size: 18,
                      )),
                      DataCell(Switch(
                        value: u['is_verified'] == true,
                        activeColor: MployaTheme.brandAccent,
                        onChanged: (_) => _toggleVerified(u),
                      )),
                      DataCell(TextButton(
                        onPressed: () => _toggleVerified(u),
                        child: Text(u['is_verified'] == true ? 'Quitar verif.' : 'Verificar'),
                      )),
                    ]),
                ],
              ),
            ),
          ),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ofertas
// ─────────────────────────────────────────────────────────────────────────────
class _JobsTab extends StatefulWidget {
  const _JobsTab();
  @override
  State<_JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<_JobsTab> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _sb
          .from('jobs')
          .select('id, title, company_name, location, modality, created_at')
          .order('created_at', ascending: false)
          .limit(200);
      setState(() { _rows = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _delete(Map<String, dynamic> j) async {
    try {
      await _sb.from('jobs').delete().eq('id', j['id']);
      setState(() => _rows.remove(j));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorState(message: _error!, onRetry: _load);
    if (_rows.isEmpty) return const _EmptyState(message: 'No hay ofertas');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Ofertas (${_rows.length})',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary)),
        const Spacer(),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      const SizedBox(height: 16),
      Expanded(
        child: ListView.separated(
          itemCount: _rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final j = _rows[i];
            return _Card(child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(j['title']?.toString() ?? 'Sin título',
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.textPrimary)),
                const SizedBox(height: 2),
                Text('${j['company_name'] ?? '—'} · ${j['location'] ?? '—'} · ${j['modality'] ?? '—'}',
                    style: TextStyle(fontSize: 13, color: context.textSecondary)),
              ])),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: () => _delete(j),
                icon: const Icon(Icons.delete_outline, color: MployaTheme.danger),
              ),
            ]));
          },
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Boosts activos
// ─────────────────────────────────────────────────────────────────────────────
class _BoostsTab extends StatefulWidget {
  const _BoostsTab();
  @override
  State<_BoostsTab> createState() => _BoostsTabState();
}

class _BoostsTabState extends State<_BoostsTab> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final data = await _sb
          .from('users')
          .select('id, name, email, account_type, boost_ends_at')
          .gt('boost_ends_at', now)
          .order('boost_ends_at', ascending: false);
      setState(() {
        _rows = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  String _fmtDate(dynamic val) {
    if (val == null) return '—';
    try {
      final dt = DateTime.parse(val.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return '—'; }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorState(message: _error!, onRetry: _load);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Boosts activos (${_rows.length})',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary)),
        const Spacer(),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      const SizedBox(height: 16),
      if (_rows.isEmpty)
        const Expanded(child: _EmptyState(message: 'No hay boosts activos'))
      else
        Expanded(
          child: SingleChildScrollView(
            child: SizedBox(
              width: double.infinity,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Nombre')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Tipo')),
                  DataColumn(label: Text('Vence')),
                  DataColumn(label: Text('Días restantes')),
                ],
                rows: [
                  for (final u in _rows)
                    DataRow(cells: [
                      DataCell(Text(u['name']?.toString() ?? '—')),
                      DataCell(Text(u['email']?.toString() ?? '—')),
                      DataCell(Text(u['account_type']?.toString() ?? '—')),
                      DataCell(Text(_fmtDate(u['boost_ends_at']))),
                      DataCell(_DaysChip(boostEndsAt: u['boost_ends_at']?.toString())),
                    ]),
                ],
              ),
            ),
          ),
        ),
    ]);
  }
}

class _DaysChip extends StatelessWidget {
  final String? boostEndsAt;
  const _DaysChip({this.boostEndsAt});

  @override
  Widget build(BuildContext context) {
    if (boostEndsAt == null) return const Text('—');
    final days = DateTime.parse(boostEndsAt!).difference(DateTime.now()).inDays;
    final color = days <= 2
        ? MployaTheme.danger
        : days <= 7
            ? const Color(0xFFF59E0B)
            : const Color(0xFF22C55E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text('$days días',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reportes
// ─────────────────────────────────────────────────────────────────────────────
class _ReportsTab extends StatefulWidget {
  const _ReportsTab();
  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _sb
          .from('user_reports')
          .select('id, reported_id, reporter_id, reason, status, created_at')
          .order('created_at', ascending: false)
          .limit(200);
      setState(() { _rows = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar reportes.\n\n$e';
      });
    }
  }

  Future<void> _resolve(Map<String, dynamic> r) async {
    try {
      await _sb.from('user_reports').update({'status': 'resolved'}).eq('id', r['id']);
      setState(() => r['status'] = 'resolved');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorState(message: _error!, onRetry: _load);
    if (_rows.isEmpty) return const _EmptyState(message: 'No hay reportes');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Reportes (${_rows.length})',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary)),
        const Spacer(),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      const SizedBox(height: 16),
      Expanded(
        child: ListView.separated(
          itemCount: _rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final r = _rows[i];
            final resolved = r['status'] == 'resolved';
            return _Card(child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Motivo: ${r['reason'] ?? '—'}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.textPrimary)),
                const SizedBox(height: 2),
                Text('Reportado: ${r['reported_id'] ?? '—'}  ·  Estado: ${r['status'] ?? '—'}',
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ])),
              if (!resolved)
                FilledButton(onPressed: () => _resolve(r), child: const Text('Marcar resuelto'))
              else
                const Icon(Icons.check_circle, color: Colors.green),
            ]));
          },
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF222222) : const Color(0xFFEDEFF2)),
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_outlined, size: 48, color: context.textTertiary),
        const SizedBox(height: 12),
        Text(message, style: TextStyle(color: context.textSecondary)),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: MployaTheme.danger),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary)),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Reintentar')),
        ]),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  final String message;
  const _AccessDenied({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 56, color: MployaTheme.brandAccent),
          const SizedBox(height: 16),
          Text('Panel de administración',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary)),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Volver')),
        ]),
      ),
    );
  }
}
