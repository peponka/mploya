/// Pantalla de Video Reply en mploya.
///
/// Vista fullscreen tipo cámara para grabar una respuesta en video
/// a un candidato o empresa. Usa cámara y micrófono reales.
/// Al enviar → muestra éxito → navega al chat.
library;

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/features/messaging/models/video_reply_store.dart';

// ─── Screen ────────────────────────────────────────────────────────

class VideoReplyScreen extends ConsumerStatefulWidget {
  const VideoReplyScreen({
    this.recipientName = 'María García',
    super.key,
  });

  final String recipientName;

  @override
  ConsumerState<VideoReplyScreen> createState() => _VideoReplyScreenState();
}

class _VideoReplyScreenState extends ConsumerState<VideoReplyScreen>
    with SingleTickerProviderStateMixin {
  _RecordingState _state = _RecordingState.idle;
  int _elapsedSeconds = 0;
  bool _isFlashOn = false;
  Timer? _timer;

  late final AnimationController _pulseController;

  // ─── Camera ──────────────────────────────────────────────────
  bool _cameraReady = false;
  bool _permissionDenied = false;
  html.MediaStream? _mediaStream;
  html.VideoElement? _videoElement;
  html.MediaRecorder? _mediaRecorder;
  final List<html.Blob> _recordedChunks = [];
  String? _recordedBlobUrl;

  final String _cameraViewId =
      'mploya-reply-cam-${DateTime.now().millisecondsSinceEpoch}';
  String? _playbackViewId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _initCamera();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _stopCamera();
    super.dispose();
  }

  // ─── Camera Init ─────────────────────────────────────────────

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

  // ─── Recording ───────────────────────────────────────────────

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

      // Create playback view
      _playbackViewId =
          'mploya-reply-play-${DateTime.now().millisecondsSinceEpoch}';
      final playbackVideo = html.VideoElement()
        ..src = _recordedBlobUrl!
        ..autoplay = true
        ..loop = true
        ..muted = false
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform = 'scaleX(-1)'
        ..style.background = '#000';

      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        _playbackViewId!,
        (int viewId) => playbackVideo,
      );

      if (mounted) setState(() {});
    });

    _mediaRecorder!.start(100);

    setState(() {
      _state = _RecordingState.recording;
      _elapsedSeconds = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state != _RecordingState.recording || !mounted) {
        timer.cancel();
        return;
      }
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds >= 60) {
        _stopRecording();
      }
    });
  }

  void _stopRecording() {
    _timer?.cancel();
    if (_mediaRecorder?.state == 'recording') {
      _mediaRecorder!.stop();
    }
    setState(() => _state = _RecordingState.preview);
  }

  void _retake() {
    _recordedBlobUrl = null;
    _playbackViewId = null;
    setState(() {
      _state = _RecordingState.idle;
      _elapsedSeconds = 0;
    });
  }

  Future<void> _send() async {
    setState(() => _state = _RecordingState.sending);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    _stopCamera();

    // Store the recorded video so the chat can play it.
    if (_recordedBlobUrl != null) {
      VideoReplyStore.store(
        blobUrl: _recordedBlobUrl!,
        recipientName: widget.recipientName,
      );
    }

    // Show success dialog → navigate to chat
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: MployaColors.teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: MployaColors.teal,
                size: 48,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '¡Video Reply enviado!',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MployaColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tu respuesta en video fue enviada a @${widget.recipientName}. '
              'Podés seguir la conversación en el chat.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MployaColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            // Go to chat button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Navigate to chat with this person
                  context.go('/chat/reply-${widget.recipientName.toLowerCase().replaceAll(' ', '-')}');
                },
                icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                label: Text(
                  'Ir al Chat',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MployaColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Close button
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: Text(
                'Volver al feed',
                style: GoogleFonts.inter(
                  color: MployaColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFlash() {
    setState(() => _isFlashOn = !_isFlashOn);
  }

  String get _timerText {
    final mins = _elapsedSeconds ~/ 60;
    final secs = _elapsedSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String get _timerFullText => '$_timerText / 1:00';

  double get _progress => _elapsedSeconds / 60.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ─── Camera Preview (real) ─────────────────────────
            if (_cameraReady &&
                _state != _RecordingState.preview &&
                _state != _RecordingState.sending)
              HtmlElementView(viewType: _cameraViewId)
            else if (_state == _RecordingState.preview &&
                _playbackViewId != null)
              HtmlElementView(viewType: _playbackViewId!)
            else if (_permissionDenied)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.videocam_off_rounded,
                      size: 48,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Permiso de cámara denegado',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: MployaColors.orange,
                        strokeWidth: 2.5,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Iniciando cámara...',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),

            // ─── Header ──────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Close button
                        _CircleButton(
                          icon: Icons.close,
                          onTap: () {
                            _stopCamera();
                            Navigator.of(context).pop();
                          },
                        ),
                        const Spacer(),
                        // Title area
                        Column(
                          children: [
                            Text(
                              'Responder a @${widget.recipientName}',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Video Reply',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Placeholder for alignment
                        const SizedBox(width: 40),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ─── Timer Display ────────────────────────────────
            if (_state == _RecordingState.recording ||
                _state == _RecordingState.preview)
              Positioned(
                top: 72,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: _state == _RecordingState.recording
                          ? MployaColors.red.withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: _state == _RecordingState.recording
                            ? MployaColors.red.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_state == _RecordingState.recording)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: 0.6 +
                                        _pulseController.value * 0.4,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              );
                            },
                          ),
                        if (_state == _RecordingState.recording)
                          const SizedBox(width: AppSpacing.sm),
                        Text(
                          _state == _RecordingState.recording
                              ? _timerFullText
                              : 'Grabado · $_timerText',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFeatures: [
                              const FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ─── Right Side Controls ─────────────────────────
            if (_state == _RecordingState.idle ||
                _state == _RecordingState.recording)
              Positioned(
                right: AppSpacing.md,
                top: MediaQuery.of(context).size.height * 0.35,
                child: Column(
                  children: [
                    // Flip camera (disabled — front only for reply)
                    _CircleButton(
                      icon: Icons.flip_camera_ios_outlined,
                      onTap: () {},
                      label: 'Girar',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Flash toggle
                    _CircleButton(
                      icon: _isFlashOn
                          ? Icons.flash_on
                          : Icons.flash_off_outlined,
                      onTap: _toggleFlash,
                      label: 'Flash',
                      isActive: _isFlashOn,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Timer shortcut
                    _CircleButton(
                      icon: Icons.timer_outlined,
                      onTap: () {},
                      label: 'Timer',
                    ),
                  ],
                ),
              ),

            // ─── Sending State ────────────────────────────────
            if (_state == _RecordingState.sending)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          color: MployaColors.orange,
                          strokeWidth: 3,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Enviando respuesta...',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'a @${widget.recipientName}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── Bottom Controls ─────────────────────────────
            if (_state != _RecordingState.sending)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: _state == _RecordingState.preview
                      ? _buildPreviewControls()
                      : _buildRecordingControls(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_state == _RecordingState.idle)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text(
              'Toca para grabar · Máx. 60s',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        // Record button with progress ring
        GestureDetector(
          onTap: _state == _RecordingState.idle
              ? _startRecording
              : _stopRecording,
          child: SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Progress ring (when recording)
                if (_state == _RecordingState.recording)
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 3.5,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        MployaColors.red,
                      ),
                    ),
                  ),
                // Outer ring
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _state == _RecordingState.recording
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.white,
                      width: 4,
                    ),
                  ),
                ),
                // Inner fill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: _state == _RecordingState.recording ? 28 : 60,
                  height: _state == _RecordingState.recording ? 28 : 60,
                  decoration: BoxDecoration(
                    color: MployaColors.red,
                    borderRadius: BorderRadius.circular(
                      _state == _RecordingState.recording ? 6 : 30,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play preview label
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_arrow,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Reproducir vista previa',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Action buttons
        Row(
          children: [
            // Retake button
            Expanded(
              child: GestureDetector(
                onTap: _retake,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Repetir',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Send button
            Expanded(
              child: GestureDetector(
                onTap: _send,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: MployaColors.orangeGradient,
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: MployaColors.orange
                            .withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.send,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Enviar',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Circle Button ─────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? MployaColors.orange.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.white,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _RecordingState {
  idle,
  recording,
  preview,
  sending,
}
