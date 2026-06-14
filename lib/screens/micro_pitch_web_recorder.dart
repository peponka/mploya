// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

/// Web-only helper that uses getUserMedia + MediaRecorder
/// to record video from the webcam inside the browser.
class WebRecorderHelper {
  /// Opens a full-screen dialog with live webcam preview,
  /// records up to 60 seconds, and returns an XFile with the video blob.
  static Future<XFile?> recordVideo(BuildContext context) async {
    return showCupertinoDialog<XFile?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _WebRecorderDialog(),
    );
  }
}

class _WebRecorderDialog extends StatefulWidget {
  const _WebRecorderDialog();

  @override
  State<_WebRecorderDialog> createState() => _WebRecorderDialogState();
}

class _WebRecorderDialogState extends State<_WebRecorderDialog> {
  html.MediaStream? _stream;
  html.MediaRecorder? _recorder;
  final List<html.Blob> _chunks = [];
  bool _isRecording = false;
  bool _hasError = false;
  String _errorMsg = '';
  int _seconds = 0;
  Timer? _timer;
  String? _viewId;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {'facingMode': 'user', 'width': 1280, 'height': 720},
        'audio': true,
      });

      // Create HTML video element for preview
      final videoElement = html.VideoElement()
        ..srcObject = _stream
        ..autoplay = true
        ..muted = true // Mute preview to avoid feedback
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform = 'scaleX(-1)' // Mirror for selfie
        ..setAttribute('playsinline', 'true');

      _viewId = 'webcam-preview-${DateTime.now().millisecondsSinceEpoch}';

      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId!,
        (int viewId) => videoElement,
      );

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = 'No se pudo acceder a la cámara: $e';
        });
      }
    }
  }

  void _startRecording() {
    if (_stream == null) return;

    _chunks.clear();
    
    // Try webm first, then mp4
    String mimeType = 'video/webm;codecs=vp9,opus';
    if (!html.MediaRecorder.isTypeSupported(mimeType)) {
      mimeType = 'video/webm;codecs=vp8,opus';
    }
    if (!html.MediaRecorder.isTypeSupported(mimeType)) {
      mimeType = 'video/webm';
    }

    _recorder = html.MediaRecorder(_stream!, {'mimeType': mimeType});

    _recorder!.addEventListener('dataavailable', (event) {
      final blobEvent = event as html.BlobEvent;
      if (blobEvent.data != null && blobEvent.data!.size > 0) {
        _chunks.add(blobEvent.data!);
      }
    });

    _recorder!.addEventListener('stop', (_) {
      _onRecordingStopped();
    });

    _recorder!.start(1000); // Collect data every second

    _seconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() => _seconds++);
        if (_seconds >= 60) {
          _stopRecording();
        }
      }
    });

    setState(() => _isRecording = true);
  }

  void _stopRecording() {
    _timer?.cancel();
    if (_recorder?.state == 'recording') {
      _recorder!.stop();
    }
  }

  Future<void> _onRecordingStopped() async {
    if (_chunks.isEmpty) {
      if (mounted) Navigator.of(context).pop(null);
      return;
    }

    final blob = html.Blob(_chunks, 'video/webm');
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Read blob as bytes for XFile
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();
    reader.onLoadEnd.listen((_) {
      final result = reader.result as Uint8List;
      completer.complete(result);
    });
    reader.readAsArrayBuffer(blob);
    final bytes = await completer.future;

    final xfile = XFile.fromData(
      bytes,
      name: 'micropitch_${DateTime.now().millisecondsSinceEpoch}.webm',
      mimeType: 'video/webm',
    );

    html.Url.revokeObjectUrl(url);

    if (mounted) Navigator.of(context).pop(xfile);
  }

  void _cancel() {
    _stopAllMedia();
    Navigator.of(context).pop(null);
  }

  void _stopAllMedia() {
    _timer?.cancel();
    if (_recorder?.state == 'recording') {
      _recorder?.stop();
    }
    _stream?.getTracks().forEach((track) => track.stop());
  }

  @override
  void dispose() {
    _stopAllMedia();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            // ── Camera Preview ──
            if (_viewId != null && !_hasError)
              Positioned.fill(
                child: HtmlElementView(viewType: _viewId!),
              ),

            // ── Error state ──
            if (_hasError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.white54, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _errorMsg,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      CupertinoButton(
                        color: NexTheme.brandAccent,
                        onPressed: _cancel,
                        child: const Text('Volver'),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Top bar ──
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _cancel,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 18),
                    ),
                  ),
                  const Spacer(),
                  if (_isRecording)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
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
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formattedTime,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFamily: '.SF Pro Display',
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  const SizedBox(width: 36), // Balance for close button
                ],
              ),
            ),

            // ── Bottom controls ──
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_hasError)
                    GestureDetector(
                      onTap: _isRecording ? _stopRecording : _startRecording,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? Colors.transparent : null,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _isRecording ? 28 : 60,
                            height: _isRecording ? 28 : 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30),
                              borderRadius: BorderRadius.circular(_isRecording ? 6 : 30),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _isRecording ? 'Toca para detener' : 'Toca para grabar',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}