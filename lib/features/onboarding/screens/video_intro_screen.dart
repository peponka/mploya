/// Pantalla de grabación de video introductorio del onboarding.
///
/// Después de completar el formulario de perfil, el usuario debe
/// grabar un video corto (hasta 60 segundos) presentándose.
/// Usa la cámara y micrófono reales del dispositivo.
library;

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/features/feed/providers/feed_provider.dart';
import 'package:mploya/features/profile/models/company_profile_store.dart';

class VideoIntroScreen extends ConsumerStatefulWidget {
  const VideoIntroScreen({super.key});

  @override
  ConsumerState<VideoIntroScreen> createState() => _VideoIntroScreenState();
}

class _VideoIntroScreenState extends ConsumerState<VideoIntroScreen>
    with TickerProviderStateMixin {
  final _isCompany = CompanyProfileStore.isCompany;

  bool _isRecording = false;
  bool _hasRecorded = false;
  bool _cameraReady = false;
  bool _permissionDenied = false;
  int _secondsRemaining = 60;
  int _secondsRecorded = 0;
  Timer? _timer;

  // ── New state flags ──
  bool _showIntro = true;
  bool _showCountdown = false;
  int _countdownValue = 3;
  bool _teleprompterEnabled = false;

  // Teleprompter scroll controller
  final ScrollController _teleprompterScrollController = ScrollController();
  Timer? _teleprompterTimer;

  // Countdown animation controller
  AnimationController? _countdownAnimController;
  Animation<double>? _countdownScaleAnim;
  Animation<double>? _countdownFadeAnim;

  html.MediaStream? _mediaStream;
  html.VideoElement? _videoElement;
  html.MediaRecorder? _mediaRecorder;
  final List<html.Blob> _recordedChunks = [];
  String? _recordedBlobUrl;
  
  // View IDs para la cámara y el playback
  final String _cameraViewId = 'mploya-cam-${DateTime.now().millisecondsSinceEpoch}';
  String? _playbackViewId;

  @override
  void initState() {
    super.initState();
    _countdownAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _countdownScaleAnim = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: _countdownAnimController!, curve: Curves.easeOutBack),
    );
    _countdownFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _countdownAnimController!, curve: Curves.easeOut),
    );
    // Init camera immediately so it's ready when user taps record
    _initCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _teleprompterTimer?.cancel();
    _teleprompterScrollController.dispose();
    _countdownAnimController?.dispose();
    _stopCamera();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 720},
          'height': {'ideal': 1280},
        },
        'audio': true,
      });

      _mediaStream = stream;

      _videoElement = html.VideoElement()
        ..srcObject = stream
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform = 'scaleX(-1)'
        ..style.background = '#000';

      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        _cameraViewId,
        (int viewId) => _videoElement!,
      );

      if (mounted) {
        setState(() => _cameraReady = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _permissionDenied = true);
      }
    }
  }

  void _stopCamera() {
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _mediaStream = null;
  }

  /// Called when user taps record from the intro screen or camera view.
  /// Initiates the 3-2-1 countdown, then starts recording.
  void _onRecordPressed() {
    if (_showIntro) {
      // Camera is already initializing/ready in background.
      // Dismiss intro, then start countdown once camera is confirmed ready.
      setState(() => _showIntro = false);
      if (_cameraReady) {
        // Camera already ready — short delay for the view transition, then countdown
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _cameraReady) _startCountdown();
        });
      } else if (_permissionDenied) {
        // Permission was denied — user will see the denied UI
      } else {
        // Camera still loading — show a snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esperando cámara...'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else if (_cameraReady) {
      _startCountdown();
    } else {
      // Camera view is showing but camera not ready yet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esperando cámara...'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _startCountdown() {
    setState(() {
      _showCountdown = true;
      _countdownValue = 3;
    });
    _countdownAnimController?.forward(from: 0);

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownValue <= 1) {
        timer.cancel();
        setState(() => _showCountdown = false);
        _startRecording();
      } else {
        setState(() => _countdownValue--);
        _countdownAnimController?.forward(from: 0);
      }
    });
  }

  void _startRecording() {
    if (_mediaStream == null) return;
    
    _recordedChunks.clear();
    _recordedBlobUrl = null;

    _mediaRecorder = html.MediaRecorder(_mediaStream!, {
      'mimeType': 'video/webm;codecs=vp9,opus',
    });

    _mediaRecorder!.addEventListener('dataavailable', (event) {
      final blobEvent = event as html.BlobEvent;
      if (blobEvent.data != null && blobEvent.data!.size > 0) {
        _recordedChunks.add(blobEvent.data!);
      }
    });

    _mediaRecorder!.addEventListener('stop', (_) {
      final blob = html.Blob(_recordedChunks, 'video/webm');
      _recordedBlobUrl = html.Url.createObjectUrlFromBlob(blob);
      
      // Crear video de playback
      _playbackViewId = 'mploya-playback-${DateTime.now().millisecondsSinceEpoch}';
      final playbackVideo = html.VideoElement()
        ..src = _recordedBlobUrl!
        ..autoplay = true
        ..loop = true
        ..muted = false
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain'
        ..style.transform = 'scaleX(-1)'
        ..style.borderRadius = '24px'
        ..style.background = '#000';

      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        _playbackViewId!,
        (int viewId) => playbackVideo,
      );

      if (mounted) {
        setState(() {});
        // Show post-recording dialog
        _showPostRecordingDialog();
      }
    });

    _mediaRecorder!.start(100); // chunks cada 100ms

    setState(() {
      _isRecording = true;
      _secondsRemaining = 60;
      _secondsRecorded = 0;
    });

    // Start teleprompter auto-scroll if enabled
    if (_teleprompterEnabled) {
      _startTeleprompterScroll();
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isRecording) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
        _secondsRecorded++;
      });
      if (_secondsRemaining <= 0) {
        _stopRecording();
      }
    });
  }

  void _stopRecording() {
    _timer?.cancel();
    _teleprompterTimer?.cancel();
    _mediaRecorder?.stop();
    setState(() {
      _isRecording = false;
      _hasRecorded = true;
    });
  }

  void _retakeVideo() {
    _recordedBlobUrl = null;
    _playbackViewId = null;
    _recordedChunks.clear();
    setState(() {
      _hasRecorded = false;
      _isRecording = false;
      _secondsRemaining = 60;
      _secondsRecorded = 0;
    });
  }

  void _continueToHome({bool published = false}) {
    _stopCamera();
    if (published && _recordedBlobUrl != null) {
      ref.read(videoPublishedProvider.notifier).state = _recordedBlobUrl;
    }
    context.go('/home');
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _startTeleprompterScroll() {
    _teleprompterTimer?.cancel();
    _teleprompterTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || !_teleprompterScrollController.hasClients) return;
      final maxScroll = _teleprompterScrollController.position.maxScrollExtent;
      final current = _teleprompterScrollController.offset;
      if (current < maxScroll) {
        _teleprompterScrollController.jumpTo(current + 0.5);
      }
    });
  }

  void _showPostRecordingDialog() {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            _isCompany ? '¡Video Excelente! 🎉' : '¡Pitch Excelente! 🎉',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        content: Text(
          _isCompany
              ? 'Tu equipo ya tiene voz.\n¿Listo para entrar a Mploya?'
              : 'Ya queremos que la red te escuche.\n¿Listo para entrar a Mploya?',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _retakeVideo();
            },
            child: Text(
              'Grabar de nuevo',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: MployaColors.orange,
              ),
            ),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _continueToHome(published: true);
            },
            child: Text(
              '¡Entrar a Mploya!',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MployaColors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A) Show intro screen before camera
    if (_showIntro) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(child: _buildIntroScreen()),
      );
    }

    // B) Post-recording state (scrollable, not full-screen camera)
    if (_hasRecorded) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/landing'),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _isCompany ? 'Tu Video Cultura' : 'Tu Video de Presentación',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // balance for close button
                  ],
                ),
              ),
              Text(
                'Paso 2 de 2',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _buildPostRecordingState()),
            ],
          ),
        ),
      );
    }

    // C) Full-screen camera view (like new_story_screen.dart)
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ─── Camera preview fills entire screen ─────────────
            if (_cameraReady)
              HtmlElementView(viewType: _cameraViewId)
            else if (_permissionDenied)
              _buildPermissionDenied()
            else
              _buildLoadingCamera(),

            // ─── Top gradient overlay ────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ─── Bottom gradient overlay ─────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 200,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ─── Recording progress bar ──────────────────────────
            if (_isRecording)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _secondsRecorded / 60,
                  backgroundColor: Colors.transparent,
                  color: MployaColors.orange,
                  minHeight: 4,
                ),
              ),

            // ─── Header overlay ──────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    // Close button
                    GestureDetector(
                      onTap: () {
                        _stopCamera();
                        context.go('/landing');
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Title
                    Text(
                      _isCompany ? 'Tu Video Cultura' : 'Tu Video de Presentación',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    // Flip camera icon
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Cambiar cámara no disponible en web',
                              style: GoogleFonts.inter(),
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.flip_camera_ios_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Step indicator ──────────────────────────────────
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Paso 2 de 2',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),

            // ─── Timer badge (when recording) ────────────────────
            if (_isRecording)
              Positioned(
                top: 90,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: MployaColors.red.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: AppSpacing.sm),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ).animate(
                          onPlay: (c) => c.repeat(reverse: true),
                        ).fadeOut(duration: 600.ms),
                        Text(
                          '${_formatTime(_secondsRecorded)} / 1:00',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ─── Teleprompter toggle (when not recording) ────────
            if (!_isRecording && _cameraReady)
              Positioned(
                top: 90,
                left: 0,
                right: 0,
                child: _buildTeleprompterToggle(),
              ),

            // ─── Teleprompter overlay ────────────────────────────
            if (_teleprompterEnabled && (_isRecording || _cameraReady))
              _buildTeleprompterOverlay(),

            // ─── Bottom hint text (when idle) ────────────────────
            if (!_isRecording && _cameraReady)
              Positioned(
                bottom: 160,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: Text(
                  'Puedes grabar libremente o usar el Teleprompter arriba 👌',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),

            // ─── Bottom controls ─────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _buildPreRecordingActions(),
              ),
            ),

            // ─── Countdown overlay ───────────────────────────────
            if (_showCountdown) _buildCountdownOverlay(),
          ],
        ),
      ),
    );
  }

  // ─── A) Pre-recording Intro Screen ──────────────────────────────────

  Widget _buildIntroScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),

          // Close button
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => context.go('/landing'),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Title: ¡Hola! 👋
          Center(
            child: Text(
              '¡Hola! 👋',
              style: GoogleFonts.outfit(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, end: 0),

          const SizedBox(height: AppSpacing.sm),

          Center(
            child: Text(
              _isCompany ? 'Queremos conocer tu empresa.' : 'Queremos escucharte.',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms),

          const SizedBox(height: AppSpacing.lg),

          // Body text
          Text(
            _isCompany
                ? 'En Mploya, los candidatos eligen dónde trabajar. Mostrá la cultura real de tu equipo.'
                : 'En Mploya, los currículums de papel no existen. Las empresas quieren ver tu energía real.',
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

          const SizedBox(height: AppSpacing.lg),

          // ── Camera & Microphone permission section ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Necesitamos acceso a tu cámara y micrófono',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                // Camera status
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_cameraReady) ...[
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Cámara lista',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ] else if (_permissionDenied) ...[
                      const Icon(
                        Icons.error_rounded,
                        color: MployaColors.red,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          'Permiso denegado. Habilitá la cámara y micrófono en los ajustes del navegador.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: MployaColors.red,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: MployaColors.orange,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Solicitando permisos...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_permissionDenied) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: _initCamera,
                    icon: const Icon(Icons.refresh_rounded, color: MployaColors.orange, size: 18),
                    label: Text(
                      'Reintentar',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MployaColors.orange,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 250.ms),

          const SizedBox(height: AppSpacing.lg),

          // Instructions
          Text(
            _isCompany ? 'Grabá tu primer Video Cultura contando:' : 'Graba tu primer Pitch contando:',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 300.ms),

          const SizedBox(height: AppSpacing.md),

          _buildNumberedItem(
            number: '1',
            text: _isCompany
                ? 'Qué hace única a tu empresa.'
                : 'Qué sabes hacer (lo que ofreces).',
            delay: 350,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildNumberedItem(
            number: '2',
            text: _isCompany
                ? 'La cultura y beneficios de tu equipo.'
                : 'El tipo de empleo que buscas.',
            delay: 400,
          ),

          const SizedBox(height: AppSpacing.lg),

          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MployaColors.blue.withValues(alpha: 0.15),
                  MployaColors.orange.withValues(alpha: 0.10),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: MployaColors.blue.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: MployaColors.blue,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _isCompany
                        ? 'Es obligatorio tener un Video Cultura para poder ver los perfiles de los candidatos.'
                        : 'Es obligatorio tener un Video-Pitch para poder ver los perfiles de los demás.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 450.ms),

          const SizedBox(height: AppSpacing.xxl),

          // Bottom actions: Upload MP4 on left, Record button center
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Upload MP4 text button
              TextButton.icon(
                onPressed: () {
                  // TODO: Implement file upload
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Subir MP4 - próximamente'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: Icon(
                  Icons.folder_open_rounded,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 20,
                ),
                label: Text(
                  'Subir MP4',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),

              const SizedBox(width: AppSpacing.xl),

              // Record button (big red circle)
              GestureDetector(
                onTap: _onRecordPressed,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: MployaColors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.videocam_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 500.ms, delay: 500.ms).slideY(begin: 0.2, end: 0),

          const SizedBox(height: AppSpacing.md),

          Center(
            child: Text(
              'Presioná para grabar',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildNumberedItem({
    required String number,
    required String text,
    required int delay,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: MployaColors.orange.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MployaColors.orange,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: delay.ms).slideX(begin: 0.1, end: 0);
  }

  // ─── B) Countdown Overlay ───────────────────────────────────────────

  Widget _buildCountdownOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: AnimatedBuilder(
            animation: _countdownAnimController!,
            builder: (context, child) {
              return Opacity(
                opacity: _countdownFadeAnim!.value,
                child: Transform.scale(
                  scale: _countdownScaleAnim!.value,
                  child: Text(
                    '$_countdownValue',
                    style: GoogleFonts.outfit(
                      fontSize: 96,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── C) Teleprompter Toggle ─────────────────────────────────────────

  Widget _buildTeleprompterToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: GestureDetector(
        onTap: () {
          if (mounted) {
            setState(() => _teleprompterEnabled = !_teleprompterEnabled);
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Video-Pitch badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: MployaColors.orange,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                _isCompany ? 'Video Cultura' : 'Video-Pitch',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Teleprompter (Opcional)',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            CupertinoSwitch(
              value: _teleprompterEnabled,
              activeTrackColor: MployaColors.orange,
              onChanged: (val) {
                if (mounted) setState(() => _teleprompterEnabled = val);
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ─── C) Teleprompter Overlay ────────────────────────────────────────

  Widget _buildTeleprompterOverlay() {
    final teleprompterText = _isCompany
        ? 'Hola, somos [nombre de la empresa].\n\n'
          'Contá qué hace única a tu empresa.\n\n'
          '¿Cuál es la cultura de tu equipo?\n\n'
          '¿Qué beneficios ofrecen?\n\n'
          '¿Qué perfiles están buscando?\n\n'
          '\n\n\n\n'
        : 'Hola, soy [nombre].\n\n'
          'Tengo [X] años de experiencia en [industria].\n\n'
          'Me especializo en [skills].\n\n'
          'Busco oportunidades de [tipo].\n\n'
          'Lo que me hace único es [diferenciador].\n\n'
          '\n\n\n\n';

    return Positioned(
      bottom: _isRecording ? 8 : 0,
      left: 0,
      right: 0,
      height: 120,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
              Colors.black.withValues(alpha: 0.85),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: SingleChildScrollView(
          controller: _teleprompterScrollController,
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: Text(
              teleprompterText,
              style: GoogleFonts.inter(
                fontSize: 16,
                height: 1.8,
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Post-recording state ─────────────────────────────────────────

  Widget _buildPostRecordingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),

          // Video playback preview (smaller)
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_playbackViewId != null)
                  HtmlElementView(viewType: _playbackViewId!),
                // Duration badge
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_secondsRecorded}s grabados',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1, 1),
                duration: 400.ms,
              ),

          const SizedBox(height: AppSpacing.lg),

          // ¡Pitch Grabado! title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _isCompany ? '¡Video Grabado!' : '¡Pitch Grabado!',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

          const SizedBox(height: AppSpacing.xs),

          // Duration display
          Text(
            'Duración: ${_formatTime(_secondsRecorded)}',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 250.ms),

          const SizedBox(height: AppSpacing.lg),

          // ── Action buttons ──

          // 1. Analizar con IA
          _buildActionCard(
            index: 0,
            icon: Icons.auto_awesome_rounded,
            title: 'Analizar con IA',
            description: _isCompany
                ? 'Obtené feedback inteligente sobre tu video'
                : 'Obtené feedback inteligente sobre tu pitch',
            gradient: MployaColors.orangeGradient,
            onTap: () {
              // TODO: Implement AI analysis
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Analizando con IA...'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // 2. Analizar con Claude AI
          _buildActionCard(
            index: 1,
            icon: Icons.psychology_rounded,
            title: 'Analizar con Claude AI',
            description: 'Análisis profundo con inteligencia avanzada',
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF6D28D9)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            onTap: () {
              // TODO: Implement Claude analysis
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Analizando con Claude AI...'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // 3. Subir Pitch Directo
          _buildActionCard(
            index: 2,
            icon: Icons.cloud_upload_outlined,
            title: _isCompany ? 'Subir Video Directo' : 'Subir Pitch Directo',
            description: 'Publicá tu video sin análisis previo',
            gradient: const LinearGradient(
              colors: [Color(0xFF34D399), Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            onTap: () => _continueToHome(published: true),
          ),

          const SizedBox(height: AppSpacing.md),

          // 4. Descartar (destructive text button)
          TextButton.icon(
            onPressed: _retakeVideo,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: MployaColors.red,
              size: 20,
            ),
            label: Text(
              'Descartar y volver a grabar',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: MployaColors.red,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 500.ms),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required int index,
    required IconData icon,
    required String title,
    required String description,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (300 + index * 80).ms)
        .slideX(begin: 0.1, end: 0);
  }

  // ─── Pre-recording / recording actions ────────────────────────────

  Widget _buildPreRecordingActions() {
    if (_isRecording) {
      return Center(
        child: SizedBox(
          width: 72,
          height: 72,
          child: GestureDetector(
            onTap: _stopRecording,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Container(
                decoration: BoxDecoration(
                  color: MployaColors.red,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Record button
        GestureDetector(
          onTap: _cameraReady ? _onRecordPressed : null,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            padding: const EdgeInsets.all(6),
            child: Container(
              decoration: BoxDecoration(
                color: _cameraReady
                    ? MployaColors.red
                    : MployaColors.red.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Presioná para grabar',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _continueToHome,
          child: Text(
            'Omitir por ahora',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Helper widgets ───────────────────────────────────────────────

  Widget _buildLoadingCamera() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: MployaColors.orange,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Activando cámara...',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Permiso de cámara denegado',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Habilitá la cámara y micrófono\nen los ajustes del navegador',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton.icon(
              onPressed: _initCamera,
              icon: const Icon(Icons.refresh_rounded, color: MployaColors.orange),
              label: Text(
                'Reintentar',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MployaColors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

