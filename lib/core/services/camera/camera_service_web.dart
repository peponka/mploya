/// Implementación web del servicio de cámara.
///
/// Usa `dart:html` para acceso a cámara (getUserMedia),
/// grabación (MediaRecorder) y reproducción (VideoElement).
/// Mantiene el comportamiento exacto del código original.
library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:mploya/config/constants.dart';
import 'package:mploya/core/services/camera/camera_service.dart';

/// Implementación web usando dart:html.
class CameraServiceImpl implements CameraService {
  html.MediaStream? _mediaStream;
  html.VideoElement? _videoElement;
  html.MediaRecorder? _mediaRecorder;
  final List<html.Blob> _recordedChunks = [];
  String? _lastBlobUrl;
  String? _resolvedMimeType;

  bool _isReady = false;
  bool _permissionDenied = false;
  bool _previewRegistered = false;

  @override
  bool get isReady => _isReady;

  @override
  bool get permissionDenied => _permissionDenied;

  @override
  Future<void> initialize({bool frontCamera = true, bool audio = true}) async {
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': frontCamera ? 'user' : 'environment',
          'width': {'ideal': 720},
          'height': {'ideal': 1280},
        },
        'audio': audio,
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

      _isReady = true;
      _permissionDenied = false;
    } catch (e) {
      debugPrint('Error initializing web camera: $e');
      _permissionDenied = true;
      _isReady = false;
    }
  }

  @override
  Widget buildPreview(String viewId) {
    if (!_previewRegistered && _videoElement != null) {
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        viewId,
        (int id) => _videoElement!,
      );
      _previewRegistered = true;
    }
    return HtmlElementView(viewType: viewId);
  }

  @override
  Future<void> startRecording() async {
    if (_mediaStream == null) return;

    _recordedChunks.clear();
    _lastBlobUrl = null;

    // Resolve a supported MIME type with fallback chain.
    _resolvedMimeType = _pickSupportedMimeType();
    final recorderOptions = <String, dynamic>{};
    if (_resolvedMimeType != null) {
      recorderOptions['mimeType'] = _resolvedMimeType;
    }

    _mediaRecorder = html.MediaRecorder(_mediaStream!, recorderOptions);

    _mediaRecorder!.addEventListener('dataavailable', (event) {
      final blobEvent = event as html.BlobEvent;
      if (blobEvent.data != null && blobEvent.data!.size > 0) {
        _recordedChunks.add(blobEvent.data!);
      }
    });

    _mediaRecorder!.start(100); // chunks cada 100ms
  }

  @override
  Future<String?> stopRecording() async {
    if (_mediaRecorder == null) return null;

    if (_mediaRecorder!.state == 'recording') {
      _mediaRecorder!.stop();
    }

    // Pequeña espera para que se procesen los chunks pendientes
    await Future.delayed(
      const Duration(milliseconds: kCameraWebRecordingDelayMs),
    );

    final mimeType = _resolvedMimeType ?? 'video/webm';
    final blob = html.Blob(_recordedChunks, mimeType);
    _lastBlobUrl = html.Url.createObjectUrlFromBlob(blob);
    return _lastBlobUrl;
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
    final playbackVideo = html.VideoElement()
      ..src = url
      ..autoplay = autoplay
      ..loop = loop
      ..muted = muted
      ..controls = controls
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = objectFit
      ..style.transform = mirror ? 'scaleX(-1)' : ''
      ..style.background = background;

    if (borderRadius != null) {
      playbackVideo.style.borderRadius = borderRadius;
    }

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int id) => playbackVideo,
    );

    return HtmlElementView(viewType: viewId);
  }

  @override
  void setAudioEnabled(bool enabled) {
    _mediaStream?.getAudioTracks().forEach((track) {
      track.enabled = enabled;
    });
  }

  @override
  void setVideoEnabled(bool enabled) {
    _mediaStream?.getVideoTracks().forEach((track) {
      track.enabled = enabled;
    });
  }

  @override
  Future<void> setFlashMode(bool enabled) async {
    // Flash/torch no soportado en web
  }

  @override
  void dispose() {
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _mediaStream = null;
    _videoElement = null;
    _mediaRecorder = null;
    _recordedChunks.clear();
    _previewRegistered = false;
    _resolvedMimeType = null;
  }

  // ─── MIME type fallback ─────────────────────────────────────────────

  /// Preferred MIME types in priority order.
  static const _mimeTypeCandidates = [
    'video/webm;codecs=vp9,opus',
    'video/webm;codecs=vp8,opus',
    'video/webm',
  ];

  /// Returns the first supported MIME type, or `null` to let the browser
  /// choose its default.
  static String? _pickSupportedMimeType() {
    for (final mime in _mimeTypeCandidates) {
      if (html.MediaRecorder.isTypeSupported(mime)) return mime;
    }
    debugPrint(
      '⚠️ CameraServiceWeb: ningún MIME candidato soportado, '
      'usando default del navegador.',
    );
    return null;
  }
}
