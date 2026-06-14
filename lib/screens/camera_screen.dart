import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/ia_coach_service.dart';
import '../services/claude_ai_service.dart';
import 'ia_coach_result_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  int _activeCameraIndex = 0;
  bool _isRecording = false;
  bool _isUploading = false;
  bool _isAnalyzing = false;
  int _seconds = 0;
  Timer? _countdownTimer;
  Timer? _secondsTimer;
  // Timer & Teleprompter
  bool _isCountingDown = false;
  int _countdown = 0;
  bool _showTeleprompter = false;
  
  late ScrollController _teleprompterScrollController;

  // Texto dinámico — vacío hasta que el usuario genera su guion con IA
  String _teleprompterText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _teleprompterScrollController = ScrollController();
    _initCamera();
  }

  Future<void> _initCamera({int? cameraIndex}) async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        debugPrint('⚠️ Permiso de cámara denegado');
        return;
      }
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) return;

      // Primera vez: preferir cámara frontal
      if (cameraIndex == null) {
        _activeCameraIndex = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        if (_activeCameraIndex == -1) _activeCameraIndex = 0;
      } else {
        _activeCameraIndex = cameraIndex;
      }

      _cameraController = CameraController(
        _cameras[_activeCameraIndex],
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Error inicializando cámara: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isRecording || _isCountingDown) return;
    setState(() => _isCameraInitialized = false);
    await _cameraController?.dispose();
    final nextIndex = (_activeCameraIndex + 1) % _cameras.length;
    await _initCamera(cameraIndex: nextIndex);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  void _startRecordingProcess() {
    setState(() {
      _isCountingDown = true;
      _countdown = 3;
    });
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        
        if (_isCameraInitialized && !_cameraController!.value.isRecordingVideo) {
          try {
            await _cameraController!.startVideoRecording();
          } catch(e) {
            debugPrint('Error iniciando camara: $e');
          }
        }

        setState(() {
          _isCountingDown = false;
          _isRecording = true;
          _seconds = 0;
        });
        
        _secondsTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          setState(() => _seconds++);
        });
        
        // Auto-scroll teleprompter setup based on text length
        if (_showTeleprompter) {
          _startTeleprompterScroll();
        }
      }
    });
  }

  void _startTeleprompterScroll() {
    Future.delayed(const Duration(seconds: 2), () {
      if (_isRecording && _showTeleprompter && _teleprompterScrollController.hasClients) {
        _teleprompterScrollController.animateTo(
          _teleprompterScrollController.position.maxScrollExtent,
          duration: const Duration(seconds: 60),
          curve: Curves.linear,
        );
      }
    });
  }

  void _toggleRecording() async {
    if (_isCountingDown) return;

    if (_isRecording) {
      // STOP
      _countdownTimer?.cancel();
      _secondsTimer?.cancel();
      setState(() => _isRecording = false);
      
      XFile? recordedFile;
      if (_isCameraInitialized && _cameraController!.value.isRecordingVideo) {
        try {
          recordedFile = await _cameraController!.stopVideoRecording();
        } catch(e) {
          debugPrint('Error deteniendo camara: $e');
        }
      }
      
      if (!mounted) return;

      _showPostRecordingSheet(recordedFile, _seconds);
    } else {
      // START
      _startRecordingProcess();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _secondsTimer?.cancel();
    _teleprompterScrollController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file != null && mounted) {
      _showPostRecordingSheet(file, 30); // Estimated duration for gallery videos
    }
  }

  Future<void> _uploadAndUsePitch(XFile file) async {
    final session = AuthService.instance.currentSession;
    if (session == null) {
      _showError('Debes iniciar sesión para subir un Pitch.');
      return;
    }
    
    final userId = session.user.id;
    
    setState(() => _isUploading = true);

    final url = await StorageService.instance.uploadPitchVideo(userId, file);
    
    if (!mounted) return;

    if (url != null) {
      final error = await AuthService.instance.updatePitchUrl(userId, url);
      if (error == null) {
        bool isStealth = false;
        try {
          final userData = await Supabase.instance.client.from('users').select('account_type').eq('id', userId).single();
          isStealth = userData['account_type'] == 'confidencial';
        } catch(_) {}

        if (!mounted) return;
        setState(() => _isUploading = false);
        
        if (isStealth) {
           await showCupertinoDialog(
              context: context,
              builder: (ctx) => CupertinoAlertDialog(
                title: const Text('Excelente. Aplicando encriptación...'),
                content: const Text('Ninguna empresa podrá ver tu rostro ni este video sin tu permiso y sin desbloquear su acceso previamente.'),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('Entendido'),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              )
           );
        }
        
        if (mounted) Navigator.pop(context, true); // Devolver true = video subido OK
      } else {
        setState(() => _isUploading = false);
        _showError(error);
      }
    } else {
      setState(() => _isUploading = false);
      _showError(StorageService.instance.lastError ?? 'Error desconocido');
    }
  }

  // ── Post-Recording Sheet with IA Coach option ──────────────────────────────

  void _showPostRecordingSheet(XFile? file, int recordedSeconds) {
    if (!mounted) return;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xF2111111),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(top: BorderSide(color: Color(0x22FFFFFF), width: 0.5)),
            ),
            padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).padding.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: MployaTheme.brandAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(CupertinoIcons.checkmark_circle_fill, color: MployaTheme.brandAccent, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¡Pitch Grabado!',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Video de $recordedSeconds segundos listo',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── IA Coach Button (primary) ──
                _SheetActionButton(
                  icon: CupertinoIcons.wand_stars,
                  label: 'Analizar con IA',
                  subtitle: 'Obtené feedback para mejorar tu pitch',
                  gradient: const LinearGradient(
                    colors: [NexTheme.brandAccent, NexTheme.premiumEnd],
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (file != null) {
                      _analyzeWithIACoach(file, recordedSeconds);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // ── Claude AI Coach ──
                _SheetActionButton(
                  icon: CupertinoIcons.sparkles,
                  label: 'Analizar con Claude AI',
                  subtitle: 'Feedback profundo con IA avanzada',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C3FC8), Color(0xFF9B6FE8)],
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (file != null) {
                      _showClaudeTranscriptionSheet(file, recordedSeconds);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // ── Subir sin analizar ──
                _SheetActionButton(
                  icon: CupertinoIcons.arrow_up_circle_fill,
                  label: 'Subir Pitch Directo',
                  subtitle: 'Publicar sin análisis de IA',
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (file != null) {
                      _uploadAndUsePitch(file);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // ── Descartar ──
                CupertinoButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _seconds = 0);
                  },
                  child: Text(
                    'Descartar',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── IA Coach Analysis Flow ─────────────────────────────────────────────────

  Future<void> _analyzeWithIACoach(XFile file, int recordedSeconds) async {
    final session = AuthService.instance.currentSession;
    if (session == null) {
      _showError('Debes iniciar sesión.');
      return;
    }

    setState(() => _isAnalyzing = true);

    final userId = session.user.id;

    // Step 1: Upload temporarily for analysis
    final url = await StorageService.instance.uploadPitchVideo(userId, file);

    if (!mounted) return;

    if (url == null) {
      setState(() => _isAnalyzing = false);
      _showError('No se pudo subir el video para análisis.');
      return;
    }

    // Step 2: Analyze with IA Coach
    try {
      final analysis = await IACoachService.instance.analyzePitch(
        videoUrl: url,
        durationSeconds: recordedSeconds,
      );

      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      // Step 3: Show results screen
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => IACoachResultScreen(
            analysis: analysis,
            onReRecord: () {
              // Reset and allow re-recording
              setState(() => _seconds = 0);
            },
            onPublish: () {
              // The video is already uploaded, just update the user profile
              _finalizePitchUpload(userId, url);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      _showError('Error al analizar: $e');
    }
  }

  // ── Claude AI Video Coach Flow ─────────────────────────────────────────────

  void _showClaudeTranscriptionSheet(XFile file, int recordedSeconds) {
    final controller = TextEditingController();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          color: const Color(0xFF1C1C1E),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escribí tu pitch',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Claude analizará el texto de lo que dijiste en el video.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: controller,
                placeholder: 'Ej: Soy desarrollador con 3 años de experiencia en Flutter...',
                maxLines: 5,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                placeholderStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: const Color(0xFF6C3FC8),
                  borderRadius: BorderRadius.circular(14),
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(ctx);
                    _analyzeWithClaude(file, recordedSeconds, text);
                  },
                  child: const Text('Analizar con Claude', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _analyzeWithClaude(XFile file, int recordedSeconds, String transcripcion) async {
    final session = AuthService.instance.currentSession;
    if (session == null) {
      _showError('Debes iniciar sesión.');
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final result = await ClaudeAIService.instance.videoCoach(
        transcripcion: transcripcion,
        nombreCandidato: session.user.userMetadata?['name'] as String? ?? 'Candidato',
      );

      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => _ClaudeVideoCoachSheet(result: result),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      _showError('Error al analizar con Claude: $e');
    }
  }

  /// Finalizes the pitch upload (updates user profile with the URL)
  Future<void> _finalizePitchUpload(String userId, String url) async {
    setState(() => _isUploading = true);

    final error = await AuthService.instance.updatePitchUrl(userId, url);
    if (!mounted) return;

    if (error == null) {
      bool isStealth = false;
      try {
        final userData = await Supabase.instance.client.from('users').select('account_type').eq('id', userId).single();
        isStealth = userData['account_type'] == 'confidencial';
      } catch(_) {}

      if (!mounted) return;
      setState(() => _isUploading = false);

      if (isStealth) {
        await showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Excelente. Aplicando encriptación...'),
            content: const Text('Ninguna empresa podrá ver tu rostro ni este video sin tu permiso y sin desbloquear su acceso previamente.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('Entendido'),
                onPressed: () => Navigator.pop(ctx),
              )
            ],
          ),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() => _isUploading = false);
      _showError(error);
    }
  }

  void _showTeleprompterSetup() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _TeleprompterSetupSheet(
        onScriptGenerated: (script) {
          setState(() {
            _teleprompterText = script;
            _showTeleprompter = true;
          });
        },
      ),
    );
  }

  void _showError(String errMsg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Ups'),
        content: Text(errMsg),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          )
        ],
      )
    );
  }

  String _formatTime(int sec) {
    final m = (sec / 60).floor().toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // ── Camera Preview ──
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
              child: Container(
                color: const Color(0xFF1E1E1E), // Dark blank background
                child: _isCameraInitialized
                    ? SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize?.height ?? MediaQuery.of(context).size.width,
                            height: _cameraController!.value.previewSize?.width ?? MediaQuery.of(context).size.height,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.video_camera, size: 60, color: Colors.white.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'Cámara Inactiva\n(Inicializando o permisos denegados)',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13, height: 1.5),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),

          // ── Countdown Overlay ──
          if (_isCountingDown)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Text(
                      '$_countdown',
                      key: ValueKey(_countdown),
                      style: const TextStyle(
                        fontSize: 120,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 20)],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Teleprompter Overlay (Glassmorphism & Fade) ──
          if (_showTeleprompter)
            Positioned(
              top: 100, // Pegado arriba cerca del lente
              left: 16,
              right: 16,
              height: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                    ),
                    child: Stack(
                      children: [
                        // Scrollable content with ShaderMask for fading edges
                        ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                              stops: [0.0, 0.2, 0.8, 1.0],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            child: SingleChildScrollView(
                              controller: _teleprompterScrollController,
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: [
                                  // Espacio superior para que la primera linea comience en el lente
                                  const SizedBox(height: 80),
                                  Text(
                                    _teleprompterText,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      height: 1.3,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 100), // Espacio extra abajo
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Eye-line indicator (Línea de visión a la altura del lente)
                        const Positioned(
                          top: 90,
                          left: 12,
                          child: Icon(CupertinoIcons.play_arrow_solid, color: MployaTheme.brandAccent, size: 24),
                        ),
                        const Positioned(
                          top: 90,
                          right: 12,
                          child: RotatedBox(
                            quarterTurns: 2,
                            child: Icon(CupertinoIcons.play_arrow_solid, color: MployaTheme.brandAccent, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Header / Volver / Teleprompter Toggle ──
          if (!_isRecording && !_isCountingDown)
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.all(12),
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(30),
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 24),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (_showTeleprompter) {
                        // Ya está encendido → apagar
                        setState(() => _showTeleprompter = false);
                      } else if (_teleprompterText.isNotEmpty) {
                        // Tiene guion → encender directo
                        setState(() => _showTeleprompter = true);
                      } else {
                        // Sin guion → abrir setup modal de IA
                        _showTeleprompterSetup();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _showTeleprompter
                            ? MployaTheme.brandAccent
                            : Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _showTeleprompter
                              ? Colors.transparent
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _teleprompterText.isNotEmpty
                                ? CupertinoIcons.text_badge_checkmark
                                : CupertinoIcons.wand_stars,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _teleprompterText.isNotEmpty
                                ? 'Teleprompter ON'
                                : 'Teleprompter (Opcional)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Controles Inferiores ──
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isRecording && !_isCountingDown && _teleprompterText.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Puedes grabar libremente o usar el Teleprompter arriba ☝️',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                  ),
                Container(
                  height: 140,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                       AnimatedOpacity(
                        opacity: _isRecording || _isCountingDown ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: GestureDetector(
                          onTap: _isRecording || _isCountingDown ? null : _pickFromGallery,
                          child: Icon(CupertinoIcons.photo_on_rectangle, color: Colors.white.withValues(alpha: 0.8), size: 28),
                        ),
                      ),
                  
                  // Botón rojo central interactivo
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isRecording ? MployaTheme.danger.withValues(alpha: 0.4) : Colors.white, 
                          width: _isRecording ? 6 : 4
                        ),
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: _isRecording ? 36 : 68,
                          height: _isRecording ? 36 : 68,
                          decoration: BoxDecoration(
                            color: MployaTheme.danger,
                            borderRadius: BorderRadius.circular(_isRecording ? 8 : 40),
                          ),
                        ),
                      ),
                    ),
                  ),

                  AnimatedOpacity(
                    opacity: _isRecording || _isCountingDown ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: _switchCamera,
                      child: Icon(CupertinoIcons.switch_camera, color: Colors.white.withValues(alpha: 0.8), size: 28),
                    ),
                  ),
                 ],
               ),
             ),
           ],
         ),
       ),
          
          // ── Badge Superior (Tiempo / Nombre) ──
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _isCountingDown ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isRecording ? MployaTheme.danger.withValues(alpha: 0.9) : MployaTheme.brandAccent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isRecording ? _formatTime(_seconds) : 'Video-Pitch',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Overlay de Carga de Pitch ──
          if (_isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoActivityIndicator(radius: 20, color: MployaTheme.brandAccent),
                    SizedBox(height: 24),
                    Text(
                      'Subiendo y procesando Pitch...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Overlay de Análisis IA ──
          if (_isAnalyzing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated IA logo
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      builder: (ctx, val, child) => Transform.scale(
                        scale: val,
                        child: child,
                      ),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [MployaTheme.brandAccent, NexTheme.premiumEnd],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: MployaTheme.brandAccent.withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(CupertinoIcons.wand_stars, color: Colors.white, size: 36),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Analizando tu Pitch...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'La IA está evaluando comunicación,\ncontenido, técnica e impacto',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const CupertinoActivityIndicator(radius: 14, color: MployaTheme.brandAccent),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Teleprompter Setup Sheet — Generación de Guion con IA
// ─────────────────────────────────────────────────────────────────────────────

class _ScriptRole {
  final String emoji;
  final String title;
  final String subtitle;
  final String script;

  const _ScriptRole({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.script,
  });
}

const _kScriptRoles = [
  _ScriptRole(
    emoji: '👨‍💻',
    title: 'Programador / Tech',
    subtitle: 'Dev, arquitecto, data engineer…',
    script:
        'Hola. Soy desarrollador de software y llevo años construyendo productos digitales que escalan.\n\n'
        'Me especializo en arquitecturas modernas, APIs robustas y experiencias de usuario que funcionan de verdad. '
        'He optimizado sistemas lentos, liderado migraciones críticas y entregado features que duplicaron la retención de usuarios.\n\n'
        'No solo escribo código que funciona: escribo código que el equipo puede leer, mantener y mostrar con orgullo en un code review. '
        'Creo en la documentación, en los tests y en los deploys sin drama.\n\n'
        'Si estás buscando a alguien que une mentalidad técnica con visión de producto, y que no le teme a un repositorio heredado de 10 años, '
        'me encantaría explorar cómo puedo sumar a tu equipo.\n\n'
        'Hablemos.',
  ),
  _ScriptRole(
    emoji: '🎨',
    title: 'Diseñador UI/UX',
    subtitle: 'Product design, sistemas de diseño…',
    script:
        'Diseño experiencias que hacen que los usuarios digan "esto se siente increíble" sin saber exactamente por qué.\n\n'
        'Vengo de un background mixto: empecé en diseño gráfico, migré al producto digital, y hoy vivo en la intersección del diseño de sistemas '
        'y la psicología del usuario. Mi proceso siempre arranca del problema real, no de la pantalla en blanco.\n\n'
        'Entrevisto usuarios, construyo journeys, itero prototipos de baja y alta fidelidad, y entrego handoffs de Figma '
        'que hacen felices a los desarrolladores. He construido design systems desde cero que redujeron el tiempo de desarrollo un 35%.\n\n'
        'Últimamente estoy obsesionado con la accesibilidad y el diseño inclusivo. Creo que el mejor diseño es invisible, funcional y justo para todos.\n\n'
        '¿Tu producto necesita claridad, coherencia y un poco de magia? Hablemos.',
  ),
  _ScriptRole(
    emoji: '💼',
    title: 'Ventas / Marketing',
    subtitle: 'Growth, performance, copywriting…',
    script:
        'Hola. Llevo años convirtiendo atención en conversión y conversión en ingresos predecibles.\n\n'
        'He gestionado estrategias de performance marketing con budgets de cinco cifras mensuales, '
        'optimizado funnels de ventas B2B y B2C, y construido pipelines de prospección que funcionan mientras duermo. '
        'Los números me gustan, pero lo que realmente me mueve es entender por qué la gente compra.\n\n'
        'No soy solo ejecutor: soy estratega. He detectado oportunidades de mercado que el equipo tenía frente a los ojos '
        'y no estaba viendo, y he pivotado campañas en tiempo real cuando los datos lo pedían.\n\n'
        'Si tu empresa necesita alguien que cierre deals, escale canales digitales y hable el lenguaje del ROI, '
        'soy tu próximo fichaje.\n\n'
        'Hagamos match.',
  ),
  _ScriptRole(
    emoji: '🎬',
    title: 'Creativo / Audiovisual',
    subtitle: 'Video, motion, dirección creativa…',
    script:
        'Cuento historias que la gente no puede ignorar.\n\n'
        'He producido contenido para marcas con millones de seguidores, dirigido campañas audiovisuales de 360 grados '
        'y editado piezas que se viralizaron sin presupuesto de medios. El storytelling no es solo una habilidad para mí, '
        'es la lente con la que veo todos los proyectos.\n\n'
        'Manejo el proceso completo: concepto, guion, producción, postproducción y distribución. '
        'Me adapto igual de bien a un brief de 10 páginas que a "necesitamos algo para mañana".\n\n'
        'Trabajo bien en equipo, mejor aún cuando me dan la suficiente autonomía creativa para sorprender. '
        'He colaborado con agencias, startups y equipos in-house, y siempre entrego antes del deadline.\n\n'
        'Si buscas a alguien que convierta tu visión en imágenes que impactan, empecemos hoy.',
  ),
  _ScriptRole(
    emoji: '📊',
    title: 'Data / Analítica',
    subtitle: 'BI, ciencia de datos, producto…',
    script:
        'Convierto datos en decisiones que mueven el negocio.\n\n'
        'Tengo experiencia construyendo dashboards ejecutivos, modelos predictivos y pipelines de datos '
        'que alimentan decisiones en tiempo real. He trabajado con equipos de producto, marketing y finanzas, '
        'ayudando a cada uno a hacer las preguntas correctas antes de buscar las respuestas.\n\n'
        'No soy solo alguien que corre queries: soy el puente entre el dato crudo y la estrategia. '
        'He encontrado oportunidades de revenue escondidas en datasets que nadie estaba mirando '
        'y he construido alertas que previenen problemas antes de que escalen.\n\n'
        'Domino SQL, Python y las herramientas de BI más usadas en la industria. '
        'Pero más importante que las herramientas es la curiosidad: siempre quiero entender el "por qué" detrás del número.\n\n'
        'Si tu empresa quiere tomar mejores decisiones más rápido, hablemos.',
  ),
];

class _TeleprompterSetupSheet extends StatefulWidget {
  final void Function(String script) onScriptGenerated;

  const _TeleprompterSetupSheet({required this.onScriptGenerated});

  @override
  State<_TeleprompterSetupSheet> createState() =>
      _TeleprompterSetupSheetState();
}

class _TeleprompterSetupSheetState extends State<_TeleprompterSetupSheet> {
  bool _isGenerating = false;
  String _generatingLabel = '';
  late final TextEditingController _customScriptController;

  @override
  void initState() {
    super.initState();
    _customScriptController = TextEditingController();
  }

  @override
  void dispose() {
    _customScriptController.dispose();
    super.dispose();
  }

  Future<void> _selectRole(_ScriptRole role) async {
    setState(() {
      _isGenerating = true;
      _generatingLabel = role.title;
    });

    // Simula el tiempo de generación IA (1.2 s — se siente más natural que 1 s exacto)
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    widget.onScriptGenerated(role.script);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xF2161616),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(color: Color(0x28FFFFFF), width: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Asa ──
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MployaTheme.brandAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        CupertinoIcons.wand_stars,
                        color: MployaTheme.brandAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Generar Guion con IA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: '.SF Pro Display',
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'Selecciona tu perfil profesional',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                            fontFamily: '.SF Pro Text',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Lista de roles / Loading overlay ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _isGenerating
                    ? Padding(
                        key: const ValueKey('loading'),
                        padding: EdgeInsets.only(
                            top: 28, bottom: 28 + bottomPadding),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CupertinoActivityIndicator(
                              radius: 16,
                              color: MployaTheme.brandAccent,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'La IA está escribiendo tu guion…',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                fontFamily: '.SF Pro Text',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _generatingLabel,
                              style: const TextStyle(
                                color: MployaTheme.brandAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: '.SF Pro Text',
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        key: const ValueKey('roles'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: CupertinoTextField(
                                    controller: _customScriptController,
                                    placeholder: 'Escribe o pega aquí tu propio guion...',
                                    placeholderStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    maxLines: 3,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                CupertinoButton(
                                  padding: const EdgeInsets.all(12),
                                  color: MployaTheme.brandAccent,
                                  borderRadius: BorderRadius.circular(12),
                                  minimumSize: const Size(0, 0),
                                  onPressed: () {
                                    if (_customScriptController.text.trim().isNotEmpty) {
                                      widget.onScriptGenerated(_customScriptController.text.trim());
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.white, size: 20),
                                ),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'O elige una plantilla generada por IA:',
                                style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          ..._kScriptRoles.map((role) => _RoleRow(
                                role: role,
                                onTap: () => _selectRole(role),
                              )),
                          SizedBox(height: 12 + bottomPadding),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  final _ScriptRole role;
  final VoidCallback onTap;

  const _RoleRow({required this.role, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.07),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Emoji avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(role.emoji,
                    style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: '.SF Pro Text',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                      fontFamily: '.SF Pro Text',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 14,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Sheet Action Button — Used in post-recording bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SheetActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Gradient? gradient;
  final Color? backgroundColor;
  final VoidCallback onTap;

  const _SheetActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.gradient,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? (backgroundColor ?? Colors.white.withValues(alpha: 0.06)) : null,
          borderRadius: BorderRadius.circular(16),
          border: gradient == null
              ? Border.all(color: Colors.white.withValues(alpha: 0.08))
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: gradient != null ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: gradient != null ? 0.8 : 0.45),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Claude Video Coach Result Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ClaudeVideoCoachSheet extends StatelessWidget {
  final ClaudeVideoCoachResult result;

  const _ClaudeVideoCoachSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    final score = result.puntuacionGeneral;
    final scoreColor = score >= 75
        ? NexTheme.premiumEnd
        : score >= 50
            ? const Color(0xFFFFB800)
            : const Color(0xFFFF4444);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        color: const Color(0xFF111111),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$score',
                        style: TextStyle(color: scoreColor, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Análisis Claude AI',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          result.resumen,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
                children: [
                  // Puntuaciones
                  if (result.puntuaciones.isNotEmpty) ...[
                    const Text('Puntuaciones', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    ...result.puntuaciones.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(e.key[0].toUpperCase() + e.key.substring(1), style: const TextStyle(color: Colors.white, fontSize: 14))),
                          Text('${e.value}/10', style: TextStyle(color: scoreColor, fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),
                  ],
                  // Puntos fuertes
                  if (result.puntosFuertes.isNotEmpty) ...[
                    const Text('Puntos fuertes', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    ...result.puntosFuertes.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('✓ ', style: TextStyle(color: NexTheme.premiumEnd, fontSize: 14)),
                          Expanded(child: Text(p, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4))),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),
                  ],
                  // Áreas de mejora
                  if (result.areasMejora.isNotEmpty) ...[
                    const Text('Áreas de mejora', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    ...result.areasMejora.map((a) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.area, style: const TextStyle(color: Color(0xFFFFB800), fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(a.sugerencia, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                        ],
                      ),
                    )),
                  ],
                  // Frase destacada
                  if (result.fraseDestacada != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6C3FC8), Color(0xFF9B6FE8)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Frase destacada', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          Text('"${result.fraseDestacada}"', style: const TextStyle(color: Colors.white, fontSize: 14, fontStyle: FontStyle.italic, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}