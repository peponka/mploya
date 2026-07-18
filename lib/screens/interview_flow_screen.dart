import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/ai_interview_service.dart';
import '../theme/app_theme.dart';
import 'micro_pitch_web_stub.dart' if (dart.library.html) 'micro_pitch_web_recorder.dart';

class InterviewFlowScreen extends StatefulWidget {
  final String interviewId;

  const InterviewFlowScreen({super.key, required this.interviewId});

  @override
  State<InterviewFlowScreen> createState() => _InterviewFlowScreenState();
}

class _InterviewFlowScreenState extends State<InterviewFlowScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  Interview? _interview;
  List<InterviewQuestion> _questions = [];
  int _currentQuestionIndex = 0;

  bool _isRecording = false;
  bool _isUploading = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _recordingError;

  bool _isGeneratingReport = false;
  bool _reportSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadInterviewData();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInterviewData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final interview = await AIInterviewService.instance.fetchInterview(widget.interviewId);
      if (interview == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No se encontró la entrevista.';
        });
        return;
      }

      var questions = await AIInterviewService.instance.fetchQuestions(widget.interviewId);
      if (questions.isEmpty) {
        // Generar preguntas si no existen
        final generated = await AIInterviewService.instance.triggerQuestionGeneration(widget.interviewId);
        if (generated) {
          questions = await AIInterviewService.instance.fetchQuestions(widget.interviewId);
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No se pudieron generar las preguntas de la entrevista.';
          });
          return;
        }
      }

      setState(() {
        _interview = interview;
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ocurrió un error al cargar la entrevista: $e';
      });
    }
  }

  String get _formattedRecordingTime {
    final m = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecordingFlow() async {
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
      _recordingError = null;
    });

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() => _recordingSeconds++);
        if (_recordingSeconds >= 60) {
          _recordingTimer?.cancel();
        }
      }
    });

    XFile? file;
    try {
      if (kIsWeb) {
        file = await WebRecorderHelper.recordVideo(context);
      } else {
        final picker = ImagePicker();
        file = await picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(seconds: 60),
          preferredCameraDevice: CameraDevice.front,
        );
      }
    } catch (e) {
      setState(() => _recordingError = 'Error de cámara: $e');
    }

    _recordingTimer?.cancel();
    if (file == null) {
      if (mounted) setState(() => _isRecording = false);
      return;
    }

    // ── Subir respuesta ──
    setState(() {
      _isRecording = false;
      _isUploading = true;
    });

    final currentQuestion = _questions[_currentQuestionIndex];
    final success = await AIInterviewService.instance.submitAnswer(
      interviewId: widget.interviewId,
      questionId: currentQuestion.id,
      file: file,
      transcript: '[Respuesta grabada en video]', // Placeholder para simular transcripción
    );

    if (!success) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _recordingError = 'Error al subir la respuesta. Inténtalo de nuevo.';
        });
      }
      return;
    }

    setState(() {
      _isUploading = false;
    });

    _nextQuestion();
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      // Entrevista completada
      _finishInterview();
    }
  }

  Future<void> _finishInterview() async {
    setState(() {
      _isGeneratingReport = true;
    });

    // Invocar Edge Function para generar reporte
    final success = await AIInterviewService.instance.triggerReportGeneration(widget.interviewId);

    if (mounted) {
      setState(() {
        _isGeneratingReport = false;
        _reportSuccess = success;
      });
    }
  }

  Color _getCategoryColor(String? category) {
    if (category == 'technical') return const Color(0xFF007AFF);
    if (category == 'behavioral') return const Color(0xFF34C759);
    return MployaTheme.brandAccent;
  }

  String _getCategoryName(String? category) {
    if (category == 'technical') return 'Técnica';
    if (category == 'behavioral') return 'Conductual';
    return 'Motivación';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CupertinoPageScaffold(
        backgroundColor: Color(0xFFF8FAFC),
        child: Center(
          child: CupertinoActivityIndicator(radius: 16),
        ),
      );
    }

    if (_errorMessage != null) {
      return CupertinoPageScaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Entrevista IA'),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 24),
                  CupertinoButton.filled(
                    onPressed: _loadInterviewData,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_isGeneratingReport) {
      return const CupertinoPageScaffold(
        backgroundColor: Color(0xFF0F172A), // Premium Dark
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoActivityIndicator(radius: 20, color: Colors.white),
                SizedBox(height: 24),
                Text(
                  'Procesando respuestas...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 8),
                Text(
                  'La Inteligencia Artificial está evaluando tus competencias e historial para generar tu informe final de RRHH.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_reportSuccess || _interview?.status == 'completed') {
      return CupertinoPageScaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.checkmark_seal_fill, size: 48, color: Color(0xFF15803D)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '¡Entrevista Completada!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tus respuestas en video han sido analizadas con éxito. El equipo de reclutamiento ha sido notificado y revisará tu reporte IA en las próximas horas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  CupertinoButton.filled(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Volver al Inicio'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;
    final catColor = _getCategoryColor(currentQuestion.category);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Entrevista IA (${_currentQuestionIndex + 1}/${_questions.length})'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.xmark),
          onPressed: () {
            showCupertinoDialog(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: const Text('¿Abandonar entrevista?'),
                content: const Text('Si sales ahora perderás las respuestas no guardadas de este intento.'),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('Continuar'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text('Salir'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(MployaTheme.brandAccent),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Card de Pregunta
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getCategoryName(currentQuestion.category).toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: catColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        currentQuestion.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Recording / Uploading Status
              if (_isRecording)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CupertinoActivityIndicator(radius: 12),
                      const SizedBox(height: 8),
                      Text(
                        'Grabando respuesta... $_formattedRecordingTime / 01:00',
                        style: const TextStyle(color: CupertinoColors.destructiveRed, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              else if (_isUploading)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoActivityIndicator(radius: 12),
                      SizedBox(height: 8),
                      Text(
                        'Subiendo video a Supabase...',
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              else if (_recordingError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _recordingError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13),
                  ),
                ),

              // Botones de acción
              if (!_isRecording && !_isUploading)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  color: MployaTheme.brandAccent,
                  borderRadius: BorderRadius.circular(16),
                  onPressed: _startRecordingFlow,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.videocam_fill, size: 20, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        _currentQuestionIndex == 0 ? 'Iniciar Entrevista' : 'Responder Pregunta',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Nota: Tienes un límite de 60 segundos por respuesta.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
