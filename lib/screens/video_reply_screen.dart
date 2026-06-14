import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/error_handler.dart';
import '../services/social_service.dart';
import 'package:video_player/video_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Video Reply Screen
//
// Allows user to record a short video (max 30s) and send it as a private
// video message to the author of the pitch they're responding to.
// Flow: Camera → Record → Preview → Send
// ─────────────────────────────────────────────────────────────────────────────

class VideoReplyScreen extends StatefulWidget {
  final NexUser targetUser;

  const VideoReplyScreen({super.key, required this.targetUser});

  @override
  State<VideoReplyScreen> createState() => _VideoReplyScreenState();
}

class _VideoReplyScreenState extends State<VideoReplyScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isFrontCamera = true;
  XFile? _recordedFile;
  VideoPlayerController? _previewController;
  bool _isSending = false;
  bool _isSent = false;

  // Timer
  int _recordSeconds = 0;
  Timer? _timer;
  static const int _maxSeconds = 30;

  // Animation
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _sendAnimController;
  late final Animation<double> _sendAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _sendAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _sendAnimation = CurvedAnimation(
      parent: _sendAnimController,
      curve: Curves.elasticOut,
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('❌ Camera init error: $e');
    }
  }

  Future<void> _toggleCamera() async {
    final cameras = await availableCameras();
    if (cameras.length < 2) return;
    setState(() {
      _isInitialized = false;
      _isFrontCamera = !_isFrontCamera;
    });
    await _cameraController?.dispose();
    final target = cameras.firstWhere(
      (c) => c.lensDirection ==
          (_isFrontCamera
              ? CameraLensDirection.front
              : CameraLensDirection.back),
      orElse: () => cameras.first,
    );
    _cameraController = CameraController(
      target,
      ResolutionPreset.high,
      enableAudio: true,
    );
    await _cameraController!.initialize();
    if (mounted) setState(() => _isInitialized = true);
  }

  void _startRecording() async {
    if (_cameraController == null || _isRecording) return;
    HapticFeedback.heavyImpact();
    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _recordSeconds++);
        if (_recordSeconds >= _maxSeconds) {
          _stopRecording();
        }
      });
    } catch (e) {
      debugPrint('❌ Recording start error: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _cameraController == null) return;
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    try {
      final file = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _recordedFile = file;
      });
      _initPreview(file.path);
    } catch (e) {
      debugPrint('❌ Recording stop error: $e');
      setState(() => _isRecording = false);
    }
  }

  void _initPreview(String path) async {
    if (kIsWeb) {
      // On web, XFile.path is a blob URL — use network controller
      _previewController = VideoPlayerController.networkUrl(Uri.parse(path));
    } else {
      // On native, use file path
      _previewController = VideoPlayerController.networkUrl(Uri.parse(path));
    }
    await _previewController!.initialize();
    _previewController!.setLooping(true);
    _previewController!.play();
    if (mounted) setState(() {});
  }

  void _retake() {
    _previewController?.dispose();
    _previewController = null;
    _recordedFile = null;
    _recordSeconds = 0;
    if (mounted) setState(() {});
  }

  Future<void> _sendReply() async {
    if (_recordedFile == null || _isSending) return;
    setState(() => _isSending = true);

    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      if (myId == null) throw Exception('No autenticado');

      // 1. Upload video to storage
      debugPrint('📤 Step 1: Uploading video...');
      final bytes = await _recordedFile!.readAsBytes();
      final fileName = 'video_replies/${myId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await Supabase.instance.client.storage
          .from('videos')
          .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
      final videoUrl = Supabase.instance.client.storage
          .from('videos')
          .getPublicUrl(fileName);
      debugPrint('✅ Step 1 done: $videoUrl');

      // 2. Upload done, now send as chat message
      debugPrint('💬 Step 2: Sending message...');
      final targetId = widget.targetUser.id;

      await Supabase.instance.client.from('messages').insert({
        'sender_id': myId,
        'receiver_id': targetId,
        'content': '🎬 Video Reply\n$videoUrl',
        'type': 'video',
        'media_url': videoUrl,
        'is_read': false,
      });
      debugPrint('✅ Step 2 done: Message sent');

      // 3. Auto-send connection request so it shows in Matches
      debugPrint('🤝 Step 3: Sending connection request...');
      try {
        await SocialService.instance.sendConnectionRequest(targetId);
        debugPrint('✅ Step 3 done: Connection request sent');
      } catch (e) {
        debugPrint('⚠️ Connection request skipped (may already exist): $e');
      }

      // 4. Success animation
      _sendAnimController.forward();
      setState(() {
        _isSending = false;
        _isSent = true;
      });

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e, st) {
      debugPrint('❌ Send reply error: $e\n$st');
      setState(() => _isSending = false);
      if (mounted) {
        MployaErrorHandler.instance.showError(
          context,
          'Error: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}',
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    _previewController?.dispose();
    _pulseController.dispose();
    _sendAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPreview = _recordedFile != null;

    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera / Preview ──
          if (isPreview && _previewController != null && _previewController!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _previewController!.value.size.width,
                  height: _previewController!.value.size.height,
                  child: VideoPlayer(_previewController!),
                ),
              ),
            )
          else if (_isInitialized && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? size.width,
                  height: _cameraController!.value.previewSize?.width ?? size.height,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            const Center(
              child: CupertinoActivityIndicator(color: Colors.white, radius: 16),
            ),

          // ── Dark gradient top ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Top bar ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Video Reply',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'para ${widget.targetUser.isConfidential ? "Perfil Confidencial" : widget.targetUser.name}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!isPreview)
                  GestureDetector(
                    onTap: _toggleCamera,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        CupertinoIcons.switch_camera,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Timer ──
          if (_isRecording)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                      const SizedBox(width: 8),
                      Text(
                        '${_recordSeconds}s / ${_maxSeconds}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Progress bar ──
          if (_isRecording)
            Positioned(
              bottom: 140,
              left: 40,
              right: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _recordSeconds / _maxSeconds,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(NexTheme.brandAccent),
                  minHeight: 4,
                ),
              ),
            ),

          // ── Bottom Controls ──
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 30,
            left: 0,
            right: 0,
            child: isPreview ? _buildPreviewControls() : _buildRecordControls(),
          ),

          // ── Sent Overlay ──
          if (_isSent)
            Container(
              color: Colors.black54,
              child: ScaleTransition(
                scale: _sendAnimation,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: NexTheme.brandAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: NexTheme.brandAccent.withValues(alpha: 0.4),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: const Icon(
                          CupertinoIcons.checkmark_alt,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '¡Video Reply enviado!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Sending overlay ──
          if (_isSending)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoActivityIndicator(color: Colors.white, radius: 18),
                    SizedBox(height: 16),
                    Text(
                      'Enviando...',
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
        ],
      ),
    );
  }

  Widget _buildRecordControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Record button
        GestureDetector(
          onTap: _isRecording ? _stopRecording : _startRecording,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isRecording ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isRecording ? 28 : 60,
                      height: _isRecording ? 28 : 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(
                          _isRecording ? 6 : 30,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Retake
          GestureDetector(
            onTap: _retake,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white30),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.arrow_counterclockwise, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Repetir',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Send
          GestureDetector(
            onTap: _sendReply,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [NexTheme.brandAccent, Color(0xFFFF8A50)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: NexTheme.brandAccent.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.paperplane_fill, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Enviar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
