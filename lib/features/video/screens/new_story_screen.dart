/// Pantalla de Nueva Historia (Story) en mploya.
///
/// Vista fullscreen tipo cámara para grabar stories de máximo 30 segundos.
/// Usa la cámara y micrófono reales del dispositivo.
library;

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

// ─── Screen ────────────────────────────────────────────────────────

class NewStoryScreen extends ConsumerStatefulWidget {
  const NewStoryScreen({super.key});

  @override
  ConsumerState<NewStoryScreen> createState() => _NewStoryScreenState();
}

class _NewStoryScreenState extends ConsumerState<NewStoryScreen> {
  _StoryRecordingState _state = _StoryRecordingState.idle;
  int _elapsedSeconds = 0;
  static const _maxDuration = 30;
  bool _flashOn = false;
  Timer? _timer;

  // ─── Camera ──────────────────────────────────────────────────
  bool _cameraReady = false;
  bool _permissionDenied = false;
  html.MediaStream? _mediaStream;
  html.VideoElement? _videoElement;
  html.MediaRecorder? _mediaRecorder;
  final List<html.Blob> _recordedChunks = [];
  String? _recordedBlobUrl;

  final String _cameraViewId =
      'mploya-story-cam-${DateTime.now().millisecondsSinceEpoch}';
  String? _playbackViewId;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
          'mploya-story-play-${DateTime.now().millisecondsSinceEpoch}';
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
      _state = _StoryRecordingState.recording;
      _elapsedSeconds = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _state != _StoryRecordingState.recording) {
        timer.cancel();
        return;
      }
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds >= _maxDuration) {
        _stopRecording();
      }
    });
  }

  void _stopRecording() {
    _timer?.cancel();
    _mediaRecorder?.stop();
    setState(() => _state = _StoryRecordingState.preview);
  }

  void _retake() {
    _recordedBlobUrl = null;
    _playbackViewId = null;
    _recordedChunks.clear();
    setState(() {
      _state = _StoryRecordingState.idle;
      _elapsedSeconds = 0;
    });
  }

  Future<void> _publish() async {
    setState(() => _state = _StoryRecordingState.publishing);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String get _timerText {
    final mins = _elapsedSeconds ~/ 60;
    final secs = _elapsedSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')} / 0:$_maxDuration';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ─── Camera preview / Playback / Placeholder ─────────
            if (_state == _StoryRecordingState.preview &&
                _playbackViewId != null)
              HtmlElementView(viewType: _playbackViewId!)
            else if (_cameraReady)
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
            if (_state == _StoryRecordingState.recording)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _elapsedSeconds / _maxDuration,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(MployaColors.red),
                  minHeight: 3,
                ),
              ),

            // ─── Header ──────────────────────────────────────────
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
                        Navigator.of(context).pop();
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
                      'Nueva Historia',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    // Flash toggle
                    GestureDetector(
                      onTap: () => setState(() => _flashOn = !_flashOn),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _flashOn
                              ? MployaColors.orange.withValues(alpha: 0.8)
                              : Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _flashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Camera flip icon
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
                          Icons.cameraswitch,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Timer badge ─────────────────────────────────────
            if (_state == _StoryRecordingState.recording)
              Positioned(
                top: 70,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
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
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ).animate(
                          onPlay: (c) => c.repeat(reverse: true),
                        ).fadeOut(duration: 600.ms),
                        const SizedBox(width: 8),
                        Text(
                          _timerText,
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

            // ─── Publishing State ────────────────────────────────
            if (_state == _StoryRecordingState.publishing)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: MployaColors.orange,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Publicando historia...',
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

            // ─── Bottom Controls ─────────────────────────────────
            if (_state != _StoryRecordingState.publishing)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _state == _StoryRecordingState.preview
                      ? _buildPreviewControls()
                      : _buildRecordingControls(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Loading camera ──────────────────────────────────────────

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
              'Habilitá la cámara en los ajustes\ndel navegador',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Recording Controls ──────────────────────────────────────

  Widget _buildRecordingControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_state == _StoryRecordingState.idle)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Máximo 30 segundos',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white60,
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Gallery picker
            GestureDetector(
              onTap: () {
                // Open gallery
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: Colors.white54, width: 2),
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.xl),

            // Record button
            GestureDetector(
              onTap: _state == _StoryRecordingState.idle
                  ? (_cameraReady ? _startRecording : null)
                  : _stopRecording,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width:
                        _state == _StoryRecordingState.recording ? 28 : 56,
                    height:
                        _state == _StoryRecordingState.recording ? 28 : 56,
                    decoration: BoxDecoration(
                      color: _cameraReady
                          ? MployaColors.red
                          : MployaColors.red.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(
                        _state == _StoryRecordingState.recording ? 6 : 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Spacer to balance layout
            const SizedBox(width: AppSpacing.xl),
            const SizedBox(width: 44),
          ],
        ),
      ],
    );
  }

  // ─── Preview Controls ────────────────────────────────────────

  Widget _buildPreviewControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Retake button
        Expanded(
          child: OutlinedButton(
            onPressed: _retake,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: Text(
              'Repetir',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // Publish button
        Expanded(
          child: ElevatedButton(
            onPressed: _publish,
            style: ElevatedButton.styleFrom(
              backgroundColor: MployaColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: Text(
              'Publicar',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _StoryRecordingState {
  idle,
  recording,
  preview,
  publishing,
}
