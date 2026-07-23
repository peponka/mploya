import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/company_review_service.dart';

class CompanyReviewScreen extends StatefulWidget {
  final String companyId;
  final String companyName;
  const CompanyReviewScreen({super.key, required this.companyId, required this.companyName});
  @override
  State<CompanyReviewScreen> createState() => _CompanyReviewScreenState();
}

class _CompanyReviewScreenState extends State<CompanyReviewScreen> {
  List<CompanyReview> _reviews = [];
  CompanyReviewStats _stats = CompanyReviewStats.empty();
  bool _loading = true;
  bool _hasReviewed = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final reviews = await CompanyReviewService.instance.fetchReviews(widget.companyId);
    final stats = await CompanyReviewService.instance.fetchStats(widget.companyId);
    final has = await CompanyReviewService.instance.hasReviewed(widget.companyId);
    if (mounted) setState(() { _reviews = reviews; _stats = stats; _hasReviewed = has; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(middle: Text(widget.companyName), previousPageTitle: 'Atrás',
        trailing: !_hasReviewed ? CupertinoButton(padding: EdgeInsets.zero, child: const Icon(CupertinoIcons.plus_circle_fill, size: 24),
          onPressed: _showReviewSheet) : null),
      child: _loading ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : SafeArea(child: ListView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(16), children: [
              // Stats card
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(MployaTheme.radiusLG),
                boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]),
                child: Column(children: [
                  Text('${_stats.averageRating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Color(0xFF1C1C1E))),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) =>
                    Icon(CupertinoIcons.star_fill, size: 20, color: i < _stats.averageRating.round() ? const Color(0xFFFFD700) : const Color(0xFFE5E5EA)))),
                  const SizedBox(height: 4),
                  Text('${_stats.totalReviews} reseñas', style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _miniStat('Cultura', _stats.cultureRating, const Color(0xFF34C759))),
                    const SizedBox(width: 12),
                    Expanded(child: _miniStat('Entrevista', _stats.interviewRating, const Color(0xFF007AFF))),
                  ]),
                ])),
              const SizedBox(height: 20),
              // Reviews
              if (_reviews.isEmpty)
                Center(child: Padding(padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    const Icon(CupertinoIcons.text_bubble, size: 48, color: Color(0xFFAEAEB2)),
                    const SizedBox(height: 12),
                    const Text('Sin reviews aún', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93))),
                    if (!_hasReviewed) ...[const SizedBox(height: 12),
                      CupertinoButton(color: MployaTheme.brandAccent, borderRadius: BorderRadius.circular(12),
                        onPressed: _showReviewSheet, child: const Text('Escribir reseña', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)))],
                  ])))
              else
                ...List.generate(_reviews.length, (i) {
                  final r = _reviews[i];
                  return Padding(padding: const EdgeInsets.only(bottom: 10), child: Container(
                    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFF2F2F7), shape: BoxShape.circle),
                          child: Center(child: Text('A', style: TextStyle(fontWeight: FontWeight.w700, color: context.textPrimary)))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Anónimo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E))),
                          Text(_timeAgo(r.createdAt), style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
                        ])),
                        Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (s) =>
                          Icon(CupertinoIcons.star_fill, size: 14, color: s < r.overallRating ? const Color(0xFFFFD700) : const Color(0xFFE5E5EA)))),
                      ]),
                      if (r.pros != null && r.pros!.isNotEmpty) ...[const SizedBox(height: 10),
                        _proConRow('+', r.pros!, const Color(0xFF34C759))],
                      if (r.cons != null && r.cons!.isNotEmpty) ...[const SizedBox(height: 6),
                        _proConRow('-', r.cons!, const Color(0xFFFF3B30))],
                      if (r.interviewExperience != null && r.interviewExperience!.isNotEmpty) ...[const SizedBox(height: 8),
                        Text(r.interviewExperience!, style: const TextStyle(fontSize: 13, color: Color(0xFF6C6C70), height: 1.3))],
                    ])));
                }),
              const SizedBox(height: 100),
            ])),
    );
  }

  Widget _miniStat(String label, double val, Color c) => Container(
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(val > 0 ? val.toStringAsFixed(1) : '-', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c)),
      Text(label, style: TextStyle(fontSize: 11, color: c)),
    ]));

  Widget _proConRow(String icon, String text, Color c) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 18, height: 18, decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Center(child: Text(icon, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c)))),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF1C1C1E), height: 1.3))),
  ]);

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 30) return 'hace ${diff.inDays ~/ 30} meses';
    if (diff.inDays > 0) return 'hace ${diff.inDays} días';
    if (diff.inHours > 0) return 'hace ${diff.inHours}h';
    return 'hace ${diff.inMinutes}m';
  }

  void _showReviewSheet() {
    int overall = 4; int? culture; int? interview;
    final prosCtrl = TextEditingController();
    final consCtrl = TextEditingController();
    final expCtrl = TextEditingController();
    showCupertinoModalPopup(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(color: CupertinoColors.systemBackground.resolveFrom(context),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Escribir reseña', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            const Text('CALIFICACIÓN GENERAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Color(0xFF8E8E93))),
            const SizedBox(height: 8),
            Row(children: List.generate(5, (i) => GestureDetector(
              onTap: () => setS(() => overall = i + 1),
              child: Padding(padding: const EdgeInsets.only(right: 6),
                child: Icon(CupertinoIcons.star_fill, size: 28, color: i < overall ? const Color(0xFFFFD700) : const Color(0xFFE5E5EA)))))),
            const SizedBox(height: 16),
            CupertinoTextField(controller: prosCtrl, placeholder: 'Pros (¿Qué te gustó?)', padding: const EdgeInsets.all(12), maxLines: 2),
            const SizedBox(height: 10),
            CupertinoTextField(controller: consCtrl, placeholder: 'Contras (¿Qué mejorarías?)', padding: const EdgeInsets.all(12), maxLines: 2),
            const SizedBox(height: 10),
            CupertinoTextField(controller: expCtrl, placeholder: 'Experiencia de entrevista', padding: const EdgeInsets.all(12), maxLines: 2),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: CupertinoButton(color: MployaTheme.brandAccent, borderRadius: BorderRadius.circular(14),
              onPressed: () async {
                Navigator.pop(ctx);
                HapticFeedback.heavyImpact();
                final err = await CompanyReviewService.instance.submitReview(companyId: widget.companyId, overallRating: overall,
                  cultureRating: culture, interviewRating: interview, pros: prosCtrl.text, cons: consCtrl.text, interviewExperience: expCtrl.text);
                if (err == null) _load();
                prosCtrl.dispose(); consCtrl.dispose(); expCtrl.dispose();
              },
              child: const Text('Enviar reseña', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)))),
          ]))))),
    );
  }
}
