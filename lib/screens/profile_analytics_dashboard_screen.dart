import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/profile_analytics_service.dart';

class ProfileAnalyticsDashboardScreen extends StatefulWidget {
  const ProfileAnalyticsDashboardScreen({super.key});
  @override
  State<ProfileAnalyticsDashboardScreen> createState() => _ProfileAnalyticsDashboardScreenState();
}

class _ProfileAnalyticsDashboardScreenState extends State<ProfileAnalyticsDashboardScreen> {
  AnalyticsSummary? _week;
  List<DailyAnalytics> _month = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final week = await ProfileAnalyticsService.instance.weekSummary();
    final month = await ProfileAnalyticsService.instance.fetchAnalytics(days: 30);
    if (mounted) setState(() { _week = week; _month = month; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(middle: Text('Analytics'), previousPageTitle: 'Perfil'),
      child: _loading ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : SafeArea(child: ListView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(16), children: [
              // Header
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0A66C2), Color(0xFF004E99)]),
                borderRadius: BorderRadius.circular(MployaTheme.radiusLG),
                boxShadow: [BoxShadow(color: const Color(0xFF004E99).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(CupertinoIcons.chart_bar_alt_fill, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text('Resumen Semanal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    _kpiCard('Vistas', '${_week?.totalViews ?? 0}', CupertinoIcons.eye_fill),
                    const SizedBox(width: 10),
                    _kpiCard('Matches', '${_week?.totalMatches ?? 0}', CupertinoIcons.heart_fill),
                    const SizedBox(width: 10),
                    _kpiCard('Videos', '${_week?.totalVideoPlays ?? 0}', CupertinoIcons.play_fill),
                  ]),
                ])),
              const SizedBox(height: 20),

              // Stats cards
              Row(children: [
                Expanded(child: _statCard('Búsquedas', '${_week?.totalSearchAppearances ?? 0}', const Color(0xFF34C759), CupertinoIcons.search)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Mensajes', '${_week?.totalMessages ?? 0}', const Color(0xFF5F3DC4), CupertinoIcons.chat_bubble_fill)),
              ]),
              const SizedBox(height: 20),

              // Mini chart (simple bar visualization)
              const Text('Últimos 30 días', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]),
                child: Column(children: [
                  SizedBox(height: 120, child: _month.isEmpty
                      ? const Center(child: Text('Sin datos aún', style: TextStyle(color: Color(0xFF8E8E93))))
                      : Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(_month.length.clamp(0, 30), (i) {
                          final d = _month[i];
                          final maxV = _month.map((x) => x.views).reduce((a, b) => a > b ? a : b);
                          final h = maxV > 0 ? (d.views / maxV) * 80 : 2.0;
                          return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Container(height: h.clamp(2.0, 80.0), decoration: BoxDecoration(
                              color: const Color(0xFF0A66C2).withValues(alpha: 0.7), borderRadius: BorderRadius.circular(2)))));
                        }))),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_month.isNotEmpty ? '${_month.first.date.day}/${_month.first.date.month}' : '', style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
                    Text(_month.isNotEmpty ? '${_month.last.date.day}/${_month.last.date.month}' : '', style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
                  ]),
                ])),
              const SizedBox(height: 100),
            ])),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon) => Expanded(child: Container(
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Icon(icon, color: Colors.white70, size: 18),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
    ])));

  Widget _statCard(String label, String value, Color c, IconData icon) => Container(
    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: c, size: 20)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
      ]),
    ]));
}
