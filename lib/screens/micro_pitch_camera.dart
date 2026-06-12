import 'dart:async';
import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/storage_service.dart';
import '../services/nexus_service.dart';
import '../theme/app_theme.dart';

// Web-only imports conditionally  
import 'micro_pitch_web_stub.dart' if (dart.library.html) 'micro_pitch_web_recorder.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MicroPitchCamera — Cámara de 60 seg para responder con video a una empresa
//
// En móvil: usa ImagePicker con cámara nativa
// En web: usa getUserMedia + MediaRecorder del browser
// ─────────────────────────────────────────────────────────────────────────────

class MicroPitchCamera extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const MicroPitchCamera({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<MicroPitchCamera> createState() => _MicroPitchCameraState();
}

class _MicroPitchCameraState extends State<MicroPitchCamera>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isUploading = false;
  bool _isDone = false;
  int _seconds = 0;
  Timer? _timer;
  String? _error;

  late AnimationController _doneController;
  late Animation<double> _doneScale;

  @override
  void initState() {
    super.initState();
    _doneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _doneScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _doneController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _doneController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _seconds = 0;
      _error = null;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() => _seconds++);
        if (_seconds >= 60) {
          _timer?.cancel();
          // Auto-stop handled by platform
        }
      }
    });

    XFile? file;

    if (kIsWeb) {
      // Web: Use native browser MediaRecorder
      file = await WebRecorderHelper.recordVideo(context);
    } else {
      // Mobile: Use native camera
      final picker = ImagePicker();
      file = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 60),
        preferredCameraDevice: CameraDevice.front,
      );
    }

    _timer?.cancel();

    if (file == null) {
      if (mounted) setState(() => _isRecording = false);
      return;
    }

    // ── Subir video ──
    setState(() {
      _isRecording = false;
      _isUploading = true;
    });

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _isUploading = false;
        _error = 'Sin sesión activa';
      });
      return;
    }

    final videoUrl = await StorageService.instance.uploadMicroPitch(uid, widget.receiverId, file);

    if (videoUrl == null) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _error = StorageService.instance.lastError ?? 'Error al subir video';
        });
      }
      return;
    }

    // ── Crear señal micro_pitch ──
    final sendError = await NexusService.instance.sendMicroPitch(
      widget.receiverId,
      videoUrl,
    );

    if (mounted) {
      if (sendError != null) {
        setState(() {
          _isUploading = false;
          _error = sendError;
        });
      } else {
        setState(() {
          _isUploading = false;
          _isDone = true;
        });
        _doneController.forward();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF0A1A14),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.transparent,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 22),
        ),
        middle: const Text(
          'Micro-Pitch',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // ── Header con contexto ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      NexTheme.brandAccent.withValues(alpha: 0.15),
                      NexTheme.premiumEnd.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: NexTheme.brandAccent.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      CupertinoIcons.videocam_fill,
                      color: NexTheme.brandAccent,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Responde a ${widget.receiverName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Graba un video de máximo 60 segundos explicando por qué te interesa conectar.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Estado central ──
              if (_isDone) ...[
                ScaleTransition(
                  scale: _doneScale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [NexTheme.brandAccent, NexTheme.premiumEnd],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: NexTheme.brandAccent.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(CupertinoIcons.checkmark_alt, color: Colors.white, size: 60),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '¡Micro-Pitch enviado!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.receiverName} recibirá tu video.',
                  style: const TextStyle(color: Colors.white54, fontSize: 15),
                ),
              ] else if (_isUploading) ...[
                const CupertinoActivityIndicator(radius: 24, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  'Subiendo tu micro-pitch...',
                  style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ] else if (_isRecording) ...[
                // Timer grande
                Text(
                  _formattedTime,
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: _seconds >= 55 ? const Color(0xFFFF3B30) : Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Grabando...',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ] else ...[
                // Tips
                const _TipRow(icon: CupertinoIcons.lightbulb, text: 'Preséntate en 5 seg'),
                const SizedBox(height: 12),
                const _TipRow(icon: CupertinoIcons.star, text: 'Menciona por qué te interesa'),
                const SizedBox(height: 12),
                const _TipRow(icon: CupertinoIcons.hand_thumbsup, text: 'Cierra con tu propuesta de valor'),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const Spacer(),

              // ── Botón de grabación ──
              if (!_isDone && !_isUploading)
                GestureDetector(
                  onTap: _isRecording ? null : _startRecording,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _isRecording
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFFFF3B30), Color(0xFFFF6B6B)],
                            ),
                      color: _isRecording ? const Color(0xFF333333) : null,
                      border: Border.all(color: Colors.white24, width: 4),
                      boxShadow: _isRecording
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Center(
                      child: _isRecording
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : const Icon(
                              CupertinoIcons.videocam_fill,
                              color: Colors.white,
                              size: 32,
                            ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              if (!_isDone && !_isUploading && !_isRecording)
                const Text(
                  kIsWeb ? 'Tu webcam se activará al tocar' : 'Toca para grabar (máx 60 seg)',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: NexTheme.brandAccent, size: 18),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}