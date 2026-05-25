/// Implementación mobile del servicio de cámara.
///
/// Usa el plugin `camera` para acceso a cámara nativa
/// y grabación de video en Android/iOS.
library;

import 'dart:developer' as developer;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:mploya/core/services/camera/camera_service.dart';

/// Implementación mobile usando el plugin camera.
class CameraServiceImpl implements CameraService {
  CameraController? _controller;
  bool _isReady = false;
  bool _permissionDenied = false;
  bool _audioEnabled = true;
  bool _videoEnabled = true;

  @override
  bool get isReady => _isReady;

  @override
  bool get permissionDenied => _permissionDenied;

  @override
  Future<void> initialize({bool frontCamera = true, bool audio = true}) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _permissionDenied = true;
        return;
      }

      // Seleccionar cámara frontal o trasera
      final direction = frontCamera
          ? CameraLensDirection.front
          : CameraLensDirection.back;

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == direction,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: audio,
      );

      await _controller!.initialize();
      _isReady = true;
      _permissionDenied = false;
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      _permissionDenied = true;
      _isReady = false;
    }
  }

  @override
  Widget buildPreview(String viewId) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(_controller!);
  }

  @override
  Future<void> startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.startVideoRecording();
  }

  @override
  Future<String?> stopRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      return null;
    }
    final file = await _controller!.stopVideoRecording();
    return file.path;
  }

  @override
  Widget buildPlayback(
    String viewId,
    String url, {
    String objectFit = 'cover',
    bool mirror = true,
    bool loop = true,
    bool autoplay = true,
    bool muted = false,
    bool controls = false,
    String? borderRadius,
    String background = '#000',
  }) {
    return _MobileVideoPlayer(
      key: ValueKey(viewId),
      filePath: url,
      loop: loop,
      autoplay: autoplay,
      muted: muted,
    );
  }

  @override
  void setAudioEnabled(bool enabled) {
    _audioEnabled = enabled;
    developer.log('Audio ${enabled ? "enabled" : "disabled"}');
  }

  @override
  void setVideoEnabled(bool enabled) {
    _videoEnabled = enabled;
    if (_controller != null && _controller!.value.isInitialized) {
      if (enabled) {
        _controller!.resumePreview();
      } else {
        _controller!.pausePreview();
      }
    }
    developer.log('Video ${enabled ? "enabled" : "disabled"}');
  }

  @override
  Future<void> setFlashMode(bool enabled) async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.setFlashMode(
        enabled ? FlashMode.torch : FlashMode.off,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isReady = false;
  }
}

// ─── Mobile Video Player Widget ──────────────────────────────────────

class _MobileVideoPlayer extends StatefulWidget {
  const _MobileVideoPlayer({
    super.key,
    required this.filePath,
    this.loop = true,
    this.autoplay = true,
    this.muted = false,
  });

  final String filePath;
  final bool loop;
  final bool autoplay;
  final bool muted;

  @override
  State<_MobileVideoPlayer> createState() => _MobileVideoPlayerState();
}

class _MobileVideoPlayerState extends State<_MobileVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath))
      ..setLooping(widget.loop)
      ..setVolume(widget.muted ? 0 : 1)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          if (widget.autoplay) _controller.play();
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
    if (!_initialized) {
      return Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFF6B35),
          ),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
