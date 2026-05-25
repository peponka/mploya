/// Implementación stub del servicio de cámara.
///
/// Lanza [UnsupportedError] en todas las operaciones.
/// Se usa como fallback cuando no hay plataforma detectada.
library;

import 'package:flutter/widgets.dart';

import 'package:mploya/core/services/camera/camera_service.dart';

/// Stub que lanza error — nunca debería ejecutarse en producción.
class CameraServiceImpl implements CameraService {
  @override
  Future<void> initialize({bool frontCamera = true, bool audio = true}) {
    throw UnsupportedError(
      'CameraService no soportado en esta plataforma.',
    );
  }

  @override
  bool get isReady => false;

  @override
  bool get permissionDenied => false;

  @override
  Widget buildPreview(String viewId) {
    throw UnsupportedError(
      'CameraService.buildPreview no soportado en esta plataforma.',
    );
  }

  @override
  Future<void> startRecording() {
    throw UnsupportedError(
      'CameraService.startRecording no soportado en esta plataforma.',
    );
  }

  @override
  Future<String?> stopRecording() {
    throw UnsupportedError(
      'CameraService.stopRecording no soportado en esta plataforma.',
    );
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
    throw UnsupportedError(
      'CameraService.buildPlayback no soportado en esta plataforma.',
    );
  }

  @override
  void setAudioEnabled(bool enabled) {
    throw UnsupportedError(
      'CameraService.setAudioEnabled no soportado en esta plataforma.',
    );
  }

  @override
  void setVideoEnabled(bool enabled) {
    throw UnsupportedError(
      'CameraService.setVideoEnabled no soportado en esta plataforma.',
    );
  }

  @override
  Future<void> setFlashMode(bool enabled) {
    throw UnsupportedError(
      'CameraService.setFlashMode no soportado en esta plataforma.',
    );
  }

  @override
  void dispose() {
    // No-op en stub
  }
}
