import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/story_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CreateStoryScreen — Grabar o elegir video para publicar como historia
//
// Flujo:
//  1. Abre cámara para grabar (máx 30 seg)
//  2. O elige video de galería
//  3. Preview del video
//  4. Agregar caption (opcional)
//  5. Publicar → upload a Supabase Storage + insert en stories table
// ─────────────────────────────────────────────────────────────────────────────

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> with WidgetsBindingObserver {
  // Camera
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;
  bool _isRecording = false;
  bool _isFrontCamera = true;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  static const int _maxSeconds = 30;

  // Preview
  XFile? _recordedFile;
  VideoPlayerController? _previewController;
  bool _isPreviewing = false;

  // Publishing
  bool _isPublishing = false;
  final TextEditingController _captionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) _showError('No se encontró ninguna cámara');
        return;
      }

      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Error camera init: $e');
      if (mounted) _showError('Error al iniciar la cámara');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    HapticFeedback.selectionClick();

    setState(() {
      _isCameraReady = false;
      _isFrontCamera = !_isFrontCamera;
    });

    await _cameraController?.dispose();

    final newCamera = _cameras.firstWhere(
      (c) => c.lensDirection == (_isFrontCamera ? CameraLensDirection.front : CameraLensDirection.back),
      orElse: () => _cameras.first,
    );

    _cameraController = CameraController(newCamera, ResolutionPreset.high, enableAudio: true);
    await _cameraController!.initialize();
    if (mounted) setState(() => _isCameraReady = true);
  }

  // ── Recording ──

  Future<void> _startRecording() async {
    if (_cameraController == null || _isRecording) return;
    HapticFeedback.mediumImpact();

    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordSeconds++);
        if (_recordSeconds >= _maxSeconds) _stopRecording();
      });
    } catch (e) {
      debugPrint('Start recording error: $e');
      _showError('Error al iniciar la grabación');
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_isRecording) return;
    HapticFeedback.mediumImpact();
    _recordTimer?.cancel();

    try {
      final file = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _recordedFile = file;
      });
      _showPreview();
    } catch (e) {
      debugPrint('Stop recording error: $e');
      setState(() => _isRecording = false);
    }
  }

  // ── Gallery ──

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );

    if (file != null) {
      setState(() => _recordedFile = file);
      _showPreview();
    }
  }

  // ── Preview ──

  Future<void> _showPreview() async {
    if (_recordedFile == null) return;

    _previewController?.dispose();
    if (kIsWeb) {
      // On web, XFile.path is a blob URL - use networkUrl
      final blobUri = Uri.parse(_recordedFile!.path);
      _previewController = VideoPlayerController.networkUrl(blobUri);
    } else {
      // On mobile, use file path
      _previewController = VideoPlayerController.networkUrl(Uri.file(_recordedFile!.path));
    }
    try {
      await _previewController!.initialize();
      _previewController!.setLooping(true);
      _previewController!.play();
    } catch (e) {
      debugPrint('Preview init error: $e');
    }

    setState(() => _isPreviewing = true);
  }

  void _retakeVideo() {
    _previewController?.dispose();
    _previewController = null;
    setState(() {
      _isPreviewing = false;
      _recordedFile = null;
      _recordSeconds = 0;
    });
  }

  // ── Publish ──

  Future<void> _publishStory() async {
    if (_recordedFile == null || _isPublishing) return;
    HapticFeedback.mediumImpact();

    setState(() => _isPublishing = true);

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        _showError('Sesión no válida');
        setState(() => _isPublishing = false);
        return;
      }

      // 1. Subir video a Storage
      final videoUrl = await StorageService.instance.uploadStoryVideo(uid, _recordedFile!);

      if (videoUrl == null) {
        _showError(StorageService.instance.lastError ?? 'Error al subir el video');
        setState(() => _isPublishing = false);
        return;
      }

      // 2. Crear registro en tabla stories
      final caption = _captionController.text.trim().isEmpty ? null : _captionController.text.trim();
      final success = await StoryService.instance.publishStory(videoUrl, caption: caption);

      if (success && mounted) {
        HapticFeedback.heavyImpact();
        Navigator.of(context).pop(true);
      } else {
        _showError('Error al publicar la historia');
        setState(() => _isPublishing = false);
      }
    } catch (e) {
      debugPrint('Publish story error: $e');
      _showError('Error inesperado');
      setState(() => _isPublishing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordTimer?.cancel();
    _cameraController?.dispose();
    _previewController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: _isPreviewing ? _buildPreview() : _buildCamera(),
    );
  }

  // ─── Camera View ───

  Widget _buildCamera() {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        if (_isCameraReady && _cameraController != null && _cameraController!.value.isInitialized)
          Center(child: CameraPreview(_cameraController!))
        else
          const Center(child: CupertinoActivityIndicator(radius: 16, color: Colors.white)),

        // ── Top bar ──
        Positioned(
          top: topPad + 12,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleBtn(CupertinoIcons.xmark, () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop();
              }),
              const Text(
                'Nueva Historia',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)]),
              ),
              _circleBtn(CupertinoIcons.camera_rotate, _switchCamera),
            ],
          ),
        ),

        // ── Recording timer ──
        if (_isRecording)
          Positioned(
            top: topPad + 70,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFF3B30), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      '0:${_recordSeconds.toString().padLeft(2, '0')} / 0:${_maxSeconds.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Progress bar ──
        if (_isRecording)
          Positioned(
            top: topPad + 58,
            left: 20, right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _recordSeconds / _maxSeconds,
                minHeight: 3,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFF3B30)),
              ),
            ),
          ),

        // ── Bottom controls ──
        Positioned(
          bottom: bottomPad + 30,
          left: 0, right: 0,
          child: Column(
            children: [
              if (!_isRecording)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text('Máximo 30 segundos',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery
                  GestureDetector(
                    onTap: _isRecording ? null : _pickFromGallery,
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(CupertinoIcons.photo, color: Colors.white, size: 22),
                    ),
                  ),
                  // Record button
                  GestureDetector(
                    onTap: _isRecording ? _stopRecording : _startRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _isRecording ? 30 : 64,
                          height: _isRecording ? 30 : 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30),
                            borderRadius: _isRecording ? BorderRadius.circular(6) : BorderRadius.circular(32),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48, height: 48),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Preview View ───

  Widget _buildPreview() {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_previewController != null && _previewController!.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _previewController!.value.size.width,
              height: _previewController!.value.size.height,
              child: VideoPlayer(_previewController!),
            ),
          ),

        // Bottom gradient
        Positioned(
          bottom: 0, left: 0, right: 0, height: 250,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
              ),
            ),
          ),
        ),

        // Top bar
        Positioned(
          top: topPad + 12,
          left: 16, right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleBtn(CupertinoIcons.arrow_left, _retakeVideo),
              const Text('Tu Historia', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 40),
            ],
          ),
        ),

        // Caption + Publish
        Positioned(
          bottom: bottomPad + 20,
          left: 16, right: 16,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: CupertinoTextField(
                  controller: _captionController,
                  placeholder: 'Agrega un texto... (opcional)',
                  placeholderStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 2,
                  maxLength: 100,
                  padding: const EdgeInsets.all(14),
                  decoration: null,
                  cursorColor: NexTheme.brandAccent,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      onPressed: _isPublishing ? null : _retakeVideo,
                      child: const Text('Volver a grabar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: NexTheme.brandAccent,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: _isPublishing ? null : _publishStory,
                      child: _isPublishing
                          ? const CupertinoActivityIndicator(color: Colors.white, radius: 10)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.bolt_fill, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text('Publicar Historia', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}