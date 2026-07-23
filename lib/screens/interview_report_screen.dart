import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../models/models.dart';
import '../services/ai_interview_service.dart';
import '../theme/app_theme.dart';

class InterviewReportScreen extends StatefulWidget {
  final String interviewId;

  const InterviewReportScreen({super.key, required this.interviewId});

  @override
  State<InterviewReportScreen> createState() => _InterviewReportScreenState();
}

class _InterviewReportScreenState extends State<InterviewReportScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  Interview? _interview;
  InterviewReport? _report;
  List<InterviewQuestion> _questions = [];
  List<Map<String, dynamic>> _answers = []; // id, question_id, video_url, transcript

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final interview = await AIInterviewService.instance.fetchInterview(widget.interviewId);
      final report = await AIInterviewService.instance.fetchReport(widget.interviewId);
      final questions = await AIInterviewService.instance.fetchQuestions(widget.interviewId);

      // Cargar respuestas del servicio
      final answersRes = await AIInterviewService.instance.fetchAnswers(widget.interviewId);

      setState(() {
        _interview = interview;
        _report = report;
        _questions = questions;
        _answers = answersRes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar el reporte: $e';
      });
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF16A34A); // Green
    if (score >= 60) return const Color(0xFF0C447C); // Orange
    return const Color(0xFFDC2626); // Red
  }

  Map<String, dynamic>? _getAnswerForQuestion(String questionId) {
    try {
      return _answers.firstWhere((a) => a['question_id'] == questionId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CupertinoPageScaffold(
        backgroundColor: Color(0xFFF8FAFC),
        child: Center(child: CupertinoActivityIndicator(radius: 16)),
      );
    }

    if (_errorMessage != null || _report == null) {
      return CupertinoPageScaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Reporte de Entrevista'),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.doc_text_viewfinder, size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage ?? 'El reporte aún no ha sido generado o no se encuentra disponible.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 24),
                  CupertinoButton.filled(
                    onPressed: _loadReportData,
                    child: const Text('Recargar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final report = _report!;
    final scoreColor = _getScoreColor(report.score ?? 0);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Reporte IA de Selección'),
      ),
      child: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            // ── SCORE CARD PREMIUM ──
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 16, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Evaluación Global',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Mploya AI Analyzer',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.bolt_fill, color: scoreColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '${report.score ?? 0}%',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: scoreColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (report.rationale != null) ...[
                    const Divider(height: 32, color: Color(0xFFE2E8F0)),
                    Text(
                      report.rationale!,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.5, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── RESUMEN EJECUTIVO ──
            if (report.summary != null) ...[
              _sectionTitle('Resumen Ejecutivo'),
              _card(
                child: Text(
                  report.summary!,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), height: 1.5),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── COMPETENCIAS EVALUADAS ──
            if (report.competencies != null && report.competencies!.isNotEmpty) ...[
              _sectionTitle('Competencias Detectadas'),
              _card(
                child: Column(
                  children: report.competencies!.map<Widget>((comp) {
                    final name = comp['name']?.toString() ?? 'Competencia';
                    final compScore = (comp['score'] as num?)?.toInt() ?? 0;
                    final note = comp['note']?.toString();
                    final barColor = _getScoreColor(compScore);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                '$compScore/100',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: barColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 6,
                              child: LinearProgressIndicator(
                                value: compScore / 100,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                              ),
                            ),
                          ),
                          if (note != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              note,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── KEYWORDS ──
            if (report.keywords != null && report.keywords!.isNotEmpty) ...[
              _sectionTitle('Palabras Clave Identificadas'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: report.keywords!.map<Widget>((kw) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      kw.toString(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // ── RESPUESTAS EN VIDEO Y TRANSCRIPCIÓN ──
            _sectionTitle('Respuestas y Grabaciones'),
            ..._questions.map((q) {
              final answer = _getAnswerForQuestion(q.id);
              return _QuestionAnswerCard(
                question: q,
                answer: answer,
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.3),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

// ── WIDGET CARD DE PREGUNTA/RESPUESTA ──
class _QuestionAnswerCard extends StatefulWidget {
  final InterviewQuestion question;
  final Map<String, dynamic>? answer;

  const _QuestionAnswerCard({required this.question, this.answer});

  @override
  State<_QuestionAnswerCard> createState() => _QuestionAnswerCardState();
}

class _QuestionAnswerCardState extends State<_QuestionAnswerCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasAnswer = widget.answer != null;
    final videoUrl = widget.answer?['video_url']?.toString();
    final transcript = widget.answer?['transcript']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.all(16),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Pregunta ${widget.question.ord + 1}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(width: 8),
                          if (!hasAnswer)
                            const Text(
                              '• Sin responder',
                              style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.question.text,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.4),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                  size: 16,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
          if (_expanded && hasAnswer)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(color: Color(0xFFF1F5F9), height: 16),
                  if (transcript != null && transcript.isNotEmpty) ...[
                    const Text(
                      'Transcripción de respuesta:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        transcript,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (videoUrl != null && videoUrl.isNotEmpty) ...[
                    const Text(
                      'Video Respuesta:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    _AnswerVideoPlayer(videoUrl: videoUrl),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── MINI REPRODUCTOR DE VIDEO INLINE ──
class _AnswerVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _AnswerVideoPlayer({required this.videoUrl});

  @override
  State<_AnswerVideoPlayer> createState() => _AnswerVideoPlayerState();
}

class _AnswerVideoPlayerState extends State<_AnswerVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
        }
      }).catchError((_) {
        if (mounted) {
          setState(() => _hasError = true);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.videocam, color: Colors.red, size: 24),
              SizedBox(height: 6),
              Text('Error al cargar reproducción', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _controller.value.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: MployaTheme.brandAccent,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
