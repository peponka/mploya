import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/skill_assessment_service.dart';
import '../services/claude_ai_service.dart';

class SkillAssessmentScreen extends StatefulWidget {
  const SkillAssessmentScreen({super.key});
  @override
  State<SkillAssessmentScreen> createState() => _SkillAssessmentScreenState();
}

class _SkillAssessmentScreenState extends State<SkillAssessmentScreen> {
  List<SkillCatalogItem> _catalog = [];
  List<SkillBadge> _myBadges = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final catalog = await SkillAssessmentService.instance.fetchCatalog();
    final badges = await SkillAssessmentService.instance.fetchMyBadges();
    if (mounted) setState(() { _catalog = catalog; _myBadges = badges; _isLoading = false; });
  }

  String? _getBadgeLevel(String name) =>
      _myBadges.where((b) => b.skillName == name).firstOrNull?.badgeLevel;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(middle: Text('Skill Assessment'), previousPageTitle: 'Perfil'),
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : SafeArea(child: ListView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(16), children: [
              _headerCard(),
              const SizedBox(height: 14),
              _howItWorksCard(),
              const SizedBox(height: 20),
              if (_myBadges.isNotEmpty) ...[
                _section('Mis Badges'), const SizedBox(height: 8), _badgesRow(), const SizedBox(height: 24),
              ],
              _section('Tus Skills'), const SizedBox(height: 4),
              const Padding(padding: EdgeInsets.only(left: 4, bottom: 10),
                child: Text('Basadas en tu perfil. Completá un quiz de 5 preguntas para verificar cada una.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)))),
              ..._catalog.where((s) => s.category == 'technical').map(_skillCard),
              if (_catalog.any((s) => s.category == 'soft')) ...[
                const SizedBox(height: 20),
                _section('Soft Skills'), const SizedBox(height: 8),
                ..._catalog.where((s) => s.category == 'soft').map(_skillCard),
              ],
              const SizedBox(height: 100),
            ])),
    );
  }

  Widget _headerCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
      borderRadius: BorderRadius.circular(MployaTheme.radiusLG),
      boxShadow: [BoxShadow(color: const Color(0xFF1A1A2E).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: const Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFFFFD700), size: 24)),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Skill Assessment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
          SizedBox(height: 2),
          Text('Verificá tus skills y destacá ante reclutadores', style: TextStyle(fontSize: 13, color: Colors.white70)),
        ])),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        _chip('${_myBadges.length}', 'Badges', const Color(0xFFFFD700)),
        const SizedBox(width: 10),
        _chip('${_myBadges.where((b) => b.badgeLevel == 'gold').length}', 'Gold', const Color(0xFFFFD700)),
        const SizedBox(width: 10),
        _chip('${_myBadges.where((b) => b.badgeLevel == 'silver').length}', 'Silver', const Color(0xFFC0C0C0)),
      ]),
    ]),
  );

  Widget _howItWorksCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(CupertinoIcons.lightbulb_fill, size: 16, color: Color(0xFFFF9500)),
        SizedBox(width: 8),
        Text('¿Cómo funciona?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
      ]),
      const SizedBox(height: 12),
      _step('1', 'Elegí un skill', 'Seleccioná una habilidad de tu perfil'),
      const SizedBox(height: 8),
      _step('2', 'Respondé 5 preguntas', 'Quiz generado con IA según tu nivel'),
      const SizedBox(height: 8),
      _step('3', 'Ganá un badge', 'Los reclutadores ven tus badges verificados'),
    ]),
  );

  Widget _step(String n, String title, String desc) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 24, height: 24, decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(n, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: MployaTheme.brandAccent)))),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E))),
      Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
    ])),
  ]);

  Widget _chip(String v, String l, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c)),
      const SizedBox(width: 6),
      Text(l, style: const TextStyle(fontSize: 12, color: Colors.white60)),
    ]),
  );

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(left: 4),
    child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E), letterSpacing: -0.3)));

  Widget _badgesRow() => SizedBox(height: 80, child: ListView.separated(
    scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 4),
    itemCount: _myBadges.length, separatorBuilder: (_, __) => const SizedBox(width: 10),
    itemBuilder: (_, i) => _BadgePill(badge: _myBadges[i]),
  ));

  Widget _skillCard(SkillCatalogItem skill) {
    final badge = _getBadgeLevel(skill.skillName);
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: GestureDetector(
      onTap: () => _start(skill),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(MployaTheme.radiusMD),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(
            color: (skill.category == 'technical' ? const Color(0xFF007AFF) : const Color(0xFF34C759)).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12)),
            child: Icon(skill.category == 'technical' ? CupertinoIcons.chevron_left_slash_chevron_right : CupertinoIcons.person_2_fill,
              size: 20, color: skill.category == 'technical' ? const Color(0xFF007AFF) : const Color(0xFF34C759))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(skill.skillName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
              if (badge != null) ...[const SizedBox(width: 8), _BadgeDot(level: badge)],
            ]),
            if (skill.description != null)
              Text(skill.description!, style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(8)),
            child: Text(skill.difficulty == 'beginner' ? 'Fácil' : (skill.difficulty == 'advanced' ? 'Avanzado' : 'Medio'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93)))),
          const SizedBox(width: 8),
          const Icon(CupertinoIcons.chevron_right, size: 16, color: Color(0xFFAEAEB2)),
        ]),
      ),
    ));
  }

  Future<void> _start(SkillCatalogItem skill) async {
    HapticFeedback.mediumImpact();
    final can = await SkillAssessmentService.instance.canRetake(skill.skillName);
    if (!can && mounted) {
      showCupertinoDialog(context: context, builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Cooldown Activo'),
        content: const Text('Ya tomaste este assessment hoy. Podés volver a intentarlo mañana.'),
        actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
      ));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => _QuizScreen(skill: skill, onComplete: _loadData)));
  }
}

// ── Quiz Screen ──
class _QuizScreen extends StatefulWidget {
  final SkillCatalogItem skill;
  final VoidCallback onComplete;
  const _QuizScreen({required this.skill, required this.onComplete});
  @override
  State<_QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<_QuizScreen> {
  SkillQuiz? _quiz;
  bool _loading = true;
  int _qi = 0;
  final List<int> _answers = [];
  int? _sel;
  SkillAssessmentResult? _result;
  late Stopwatch _sw;
  Timer? _timer;
  int _secs = 0;

  @override
  void initState() {
    super.initState();
    _sw = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _secs = _sw.elapsed.inSeconds); });
    _load();
  }

  @override
  void dispose() { _sw.stop(); _timer?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final q = await SkillAssessmentService.instance.generateQuiz(widget.skill.skillName, difficulty: widget.skill.difficulty);
    if (mounted) setState(() { _quiz = q; _loading = false; });
  }

  Future<void> _next() async {
    if (_sel == null) return;
    HapticFeedback.lightImpact();
    _answers.add(_sel!);
    if (_qi < (_quiz!.questions.length - 1)) {
      setState(() { _qi++; _sel = null; });
    } else {
      _sw.stop(); _timer?.cancel();
      final r = await SkillAssessmentService.instance.submitAssessment(
        skillName: widget.skill.skillName, skillCategory: widget.skill.category,
        answers: _answers, correctAnswers: _quiz!.questions.map((q) => q.correctIndex).toList(),
        timeTakenSeconds: _secs);
      if (mounted) { setState(() => _result = r); widget.onComplete(); if (r.passed) HapticFeedback.heavyImpact(); }
    }
  }

  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _resultUI();
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(middle: Text(widget.skill.skillName),
        trailing: Text(_fmt(_secs), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MployaTheme.brandAccent))),
      child: _loading ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CupertinoActivityIndicator(radius: 16), SizedBox(height: 16),
        Text('Generando quiz con IA...', style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)))]))
          : SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              _progress(),
              const SizedBox(height: 24),
              Expanded(child: _questionUI()),
              SizedBox(width: double.infinity, child: CupertinoButton(
                color: _sel != null ? MployaTheme.brandAccent : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(14),
                onPressed: _sel != null ? _next : null,
                child: Text(_qi < (_quiz!.questions.length - 1) ? 'Siguiente' : 'Finalizar',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _sel != null ? Colors.white : const Color(0xFFAEAEB2))))),
            ]))),
    );
  }

  Widget _progress() {
    final p = (_qi + 1) / (_quiz?.questions.length ?? 5);
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Pregunta ${_qi + 1} de ${_quiz?.questions.length ?? 5}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93))),
        Text('${(p * 100).round()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: MployaTheme.brandAccent)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: p, backgroundColor: const Color(0xFFE5E5EA), valueColor: const AlwaysStoppedAnimation(MployaTheme.brandAccent), minHeight: 6)),
    ]);
  }

  Widget _questionUI() {
    final q = _quiz!.questions[_qi];
    return ListView(physics: const BouncingScrollPhysics(), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(MployaTheme.radiusLG),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]),
        child: Text(q.question, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E), height: 1.4))),
      const SizedBox(height: 16),
      ...List.generate(q.options.length, (i) {
        final sel = _sel == i;
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); setState(() => _sel = i); },
          child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sel ? MployaTheme.brandAccent.withValues(alpha: 0.08) : CupertinoColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sel ? MployaTheme.brandAccent : const Color(0xFFE5E5EA), width: sel ? 2 : 1)),
            child: Row(children: [
              Container(width: 28, height: 28, decoration: BoxDecoration(color: sel ? MployaTheme.brandAccent : const Color(0xFFF2F2F7), shape: BoxShape.circle),
                child: Center(child: Text(String.fromCharCode(65 + i), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sel ? Colors.white : const Color(0xFF8E8E93))))),
              const SizedBox(width: 14),
              Expanded(child: Text(q.options[i], style: TextStyle(fontSize: 15, fontWeight: sel ? FontWeight.w600 : FontWeight.w500, color: const Color(0xFF1C1C1E)))),
              if (sel) const Icon(CupertinoIcons.checkmark_circle_fill, color: MployaTheme.brandAccent, size: 22),
            ]),
          ),
        ));
      }),
    ]);
  }

  Widget _resultUI() {
    final r = _result!;
    final c = r.badgeLevel == 'gold' ? const Color(0xFFFFD700) : r.badgeLevel == 'silver' ? const Color(0xFFC0C0C0) : r.badgeLevel == 'bronze' ? const Color(0xFFCD7F32) : const Color(0xFFEF4444);
    return CupertinoPageScaffold(backgroundColor: const Color(0xFFF2F2F7), child: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 100, height: 100, decoration: BoxDecoration(color: c.withValues(alpha: 0.15), shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.withValues(alpha: 0.3), blurRadius: 30)]),
        child: Icon(r.passed ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.xmark_circle_fill, size: 48, color: c)),
      const SizedBox(height: 24),
      Text(r.passed ? '¡Badge Obtenido!' : 'Seguí practicando', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF1C1C1E), letterSpacing: -0.5)),
      const SizedBox(height: 8),
      Text(r.passed ? '${r.badgeLevel?.toUpperCase() ?? ''} Badge en ${r.skillName}' : 'Necesitás 60% para obtener el badge', style: const TextStyle(fontSize: 15, color: Color(0xFF8E8E93))),
      const SizedBox(height: 32),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(MployaTheme.radiusLG),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _stat('${r.score}%', 'Score', c),
          Container(width: 0.5, height: 40, color: const Color(0xFFE5E5EA)),
          _stat('${r.questionsCorrect}/${r.questionsTotal}', 'Correctas', const Color(0xFF34C759)),
          Container(width: 0.5, height: 40, color: const Color(0xFFE5E5EA)),
          _stat(_fmt(r.timeTakenSeconds), 'Tiempo', const Color(0xFF007AFF)),
        ])),
      const Spacer(),
      SizedBox(width: double.infinity, child: CupertinoButton(color: MployaTheme.brandAccent, borderRadius: BorderRadius.circular(14),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Volver', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)))),
    ]))));
  }

  Widget _stat(String v, String l, Color c) => Column(children: [
    Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
    const SizedBox(height: 4),
    Text(l, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
  ]);
}

// ── Badge Pill ──
class _BadgePill extends StatelessWidget {
  final SkillBadge badge;
  const _BadgePill({required this.badge});
  @override
  Widget build(BuildContext context) {
    final c = badge.badgeLevel == 'gold' ? const Color(0xFFFFD700) : badge.badgeLevel == 'silver' ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(CupertinoIcons.checkmark_seal_fill, color: c, size: 28),
        const SizedBox(height: 4),
        Text(badge.skillName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
        Text('${badge.score}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
      ]));
  }
}

class _BadgeDot extends StatelessWidget {
  final String level;
  const _BadgeDot({required this.level});
  @override
  Widget build(BuildContext context) {
    final c = level == 'gold' ? const Color(0xFFFFD700) : level == 'silver' ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(CupertinoIcons.checkmark_seal_fill, color: c, size: 12),
        const SizedBox(width: 3),
        Text(level.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: c)),
      ]));
  }
}
