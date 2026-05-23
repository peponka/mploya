/// Pantalla de lobby para videollamada (estilo Jitsi Meet) en mploya.
///
/// Muestra preview de cámara, controles de audio/video, y estado
/// de espera para unirse a una entrevista.
library;

import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

// ─── Screen ────────────────────────────────────────────────────────

class VideoCallLobbyScreen extends ConsumerStatefulWidget {
  const VideoCallLobbyScreen({
    this.meetingTitle = 'Entrevista Mploya',
    super.key,
  });

  final String meetingTitle;

  @override
  ConsumerState<VideoCallLobbyScreen> createState() =>
      _VideoCallLobbyScreenState();
}

class _VideoCallLobbyScreenState extends ConsumerState<VideoCallLobbyScreen> {
  bool _isMicOn = true;
  bool _isVideoOn = true;
  bool _isAudioOn = true;
  bool _isWaiting = true;

  // ─── Camera state ──────────────────────────────────────────────
  bool _cameraReady = false;
  bool _permissionDenied = false;
  html.MediaStream? _mediaStream;
  html.VideoElement? _videoElement;

  final String _cameraViewId =
      'mploya-lobby-cam-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
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
        ..style.borderRadius = '16px'
        ..style.background = '#2A2A2A';

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

  void _toggleMic() {
    setState(() => _isMicOn = !_isMicOn);
    // Toggle audio tracks on the stream
    _mediaStream?.getAudioTracks().forEach((track) {
      track.enabled = _isMicOn;
    });
  }

  void _toggleVideo() {
    setState(() => _isVideoOn = !_isVideoOn);
    // Toggle video tracks on the stream
    _mediaStream?.getVideoTracks().forEach((track) {
      track.enabled = _isVideoOn;
    });
  }

  void _toggleAudio() {
    setState(() => _isAudioOn = !_isAudioOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      _stopCamera();
                      Navigator.of(context).pop();
                    },
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Lobby',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 28), // Balance for close button
                ],
              ),
            ),

            // ─── Meeting Title Banner (Blue) ───────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam, color: Colors.white, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    widget.meetingTitle,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ─── Camera Preview ────────────────────────────────────
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Camera feed or placeholder
                      if (_isVideoOn && _cameraReady)
                        HtmlElementView(viewType: _cameraViewId)
                      else if (_isVideoOn && !_cameraReady && !_permissionDenied)
                        _buildLoadingCamera()
                      else if (_isVideoOn && _permissionDenied)
                        _buildPermissionDenied()
                      else
                        // Video OFF: show avatar placeholder
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: const Color(0xFF3A3A3A),
                                child: Text(
                                  'U',
                                  style: GoogleFonts.outfit(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white60,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Cámara apagada',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Name overlay at bottom
                      if (_isVideoOn && _cameraReady)
                        Positioned(
                          bottom: AppSpacing.md,
                          left: AppSpacing.md,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              'Tú',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ─── 3 Control Buttons in dark circles ─────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ControlButton(
                  icon: _isMicOn ? Icons.mic : Icons.mic_off,
                  isActive: _isMicOn,
                  onTap: _toggleMic,
                ),
                const SizedBox(width: AppSpacing.lg),
                _ControlButton(
                  icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                  isActive: _isVideoOn,
                  onTap: _toggleVideo,
                ),
                const SizedBox(width: AppSpacing.lg),
                _ControlButton(
                  icon: _isAudioOn ? Icons.headphones : Icons.headphones_battery,
                  isActive: _isAudioOn,
                  onTap: _toggleAudio,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // ─── Waiting Status with white spinner ─────────────────
            if (_isWaiting) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Pidiendo entrar a la reunión...',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Text(
                  'Podrás entrar tan pronto te acepten tu solicitud.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // ─── Blue 'Soy el anfitrión' Button ───────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _isWaiting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Entrando como anfitrión...'),
                        backgroundColor: Color(0xFF1E88E5),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  child: Text(
                    'Soy el anfitrión',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  // ─── Helper widgets ──────────────────────────────────────────────

  Widget _buildLoadingCamera() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
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
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
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
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Habilitá la cámara en los\najustes del navegador',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Control Button Widget ─────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF3A3A3A)
              : MployaColors.red.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : MployaColors.red,
          size: 26,
        ),
      ),
    );
  }
}
