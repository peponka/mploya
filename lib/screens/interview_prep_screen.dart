import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/interview_prep_service.dart';

class InterviewPrepScreen extends StatefulWidget {
  final String jobTitle;
  final List<String> candidateSkills;
  final String? companyName;
  const InterviewPrepScreen({super.key, required this.jobTitle, required this.candidateSkills, this.companyName});

  @override
  State<InterviewPrepScreen> createState() => _InterviewPrepScreenState();
}

class _InterviewPrepScreenState extends State<InterviewPrepScreen> {
  InterviewPrepResult? _result;
  bool _loading = true;
  final Set<int> _expandedTips = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final r = await InterviewPrepService.instance.generateQuestions(
      candidateSkills: widget.candidateSkills, jobTitle: widget.jobTitle, companyName: widget.companyName);
    if (mounted) setState(() { _result = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(middle: Text('Prep. Entrevistas'), previousPageTitle: 'Atrás'),
      child: _loading
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CupertinoActivityIndicator(radius: 16), SizedBox(height: 16),
              Text('Generando preguntas con IA...', style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)))]))
          : SafeArea(child: ListView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(16), children: [
              // Header
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF5F3DC4), Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.circular(MployaTheme.radiusLG),
                boxShadow: [BoxShadow(color: const Color(0xFF5F3DC4).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(CupertinoIcons.lightbulb_fill, color: Color(0xFFFFD700), size: 24)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Prep. Entrevistas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text(widget.jobTitle, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                    ])),
                  ]),
                  const SizedBox(height: 12),
                  Text('${_result?.questions.length ?? 0} preguntas personalizadas', style: const TextStyle(fontSize: 13, color: Colors.white60)),
                ])),
              const SizedBox(height: 20),

              // Questions
              ...List.generate(_result?.questions.length ?? 0, (i) {
                final q = _result!.questions[i];
                final expanded = _expandedTips.contains(i);
                final catColor = q.category == 'technical' ? const Color(0xFF007AFF)
                    : q.category == 'behavioral' ? const Color(0xFF34C759) : MployaTheme.brandAccent;
                return Padding(padding: const EdgeInsets.only(bottom: 12), child: GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); setState(() { expanded ? _expandedTips.remove(i) : _expandedTips.add(i); }); },
                  child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(q.category == 'technical' ? 'Técnica' : q.category == 'behavioral' ? 'Conductual' : 'Motivación',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: catColor))),
                        const Spacer(),
                        Text('${i + 1}/${_result!.questions.length}', style: const TextStyle(fontSize: 12, color: Color(0xFFAEAEB2))),
                      ]),
                      const SizedBox(height: 10),
                      Text(q.question, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E), height: 1.4)),
                      if (expanded && q.tip != null) ...[
                        const SizedBox(height: 12),
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10)),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(CupertinoIcons.lightbulb_fill, color: Color(0xFFFFCC00), size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(q.tip!, style: const TextStyle(fontSize: 13, color: Color(0xFF6D4C00), height: 1.3))),
                          ])),
                      ],
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text(expanded ? 'Ocultar tip' : 'Ver tip', style: TextStyle(fontSize: 12, color: catColor, fontWeight: FontWeight.w600)),
                        Icon(expanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down, size: 14, color: catColor),
                      ]),
                    ])),
                ));
              }),

              // General Tips
              if (_result?.generalTips.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                const Text('Tips Generales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]),
                  child: Column(children: _result!.generalTips.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(CupertinoIcons.checkmark_circle_fill, color: Color(0xFF34C759), size: 16),
                      const SizedBox(width: 10),
                      Expanded(child: Text(t, style: const TextStyle(fontSize: 14, color: Color(0xFF1C1C1E), height: 1.3))),
                    ]))).toList())),
              ],
              const SizedBox(height: 100),
            ])),
    );
  }
}
