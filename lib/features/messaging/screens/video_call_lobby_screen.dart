/// Pantalla de lobby para videollamada (estilo Google Meet) en mploya.
///
/// Video fullscreen con controles superpuestos, estado de espera
/// y botón de anfitrión.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:mploya/config/env.dart';
import 'package:mploya/config/theme.dart';
import 'package:mploya/core/services/camera/camera_service.dart';

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
  bool _cameraTimedOut = false;
  late final CameraService _cameraService;

  final String _cameraViewId =
      'mploya-lobby-cam-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService();
    _initCamera();
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final result = await _cameraService.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (mounted) {
            setState(() => _cameraTimedOut = true);
          }
        },
      );

      if (mounted && !_cameraTimedOut) {
        if (_cameraService.isReady) {
          setState(() => _cameraReady = true);
        } else {
          setState(() => _permissionDenied = true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cameraTimedOut = true);
      }
    }
  }

  void _retryCamera() {
    setState(() {
      _cameraTimedOut = false;
      _cameraReady = false;
      _permissionDenied = false;
    });
    _initCamera();
  }

  void _stopCamera() {
    _cameraService.dispose();
  }

  void _toggleMic() {
    setState(() => _isMicOn = !_isMicOn);
    _cameraService.setAudioEnabled(_isMicOn);
  }

  void _toggleVideo() {
    setState(() => _isVideoOn = !_isVideoOn);
    _cameraService.setVideoEnabled(_isVideoOn);
  }

  void _toggleAudio() {
    setState(() => _isAudioOn = !_isAudioOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─── FULLSCREEN Camera / Placeholder ──────────────────
          if (_isVideoOn && _cameraReady)
            SizedBox.expand(
              child: _cameraService.buildPreview(_cameraViewId),
            )
          else if (_isVideoOn && _cameraTimedOut)
            _buildCameraTimeout()
          else if (_isVideoOn && !_cameraReady && !_permissionDenied)
            _buildLoadingCamera()
          else if (_isVideoOn && _permissionDenied)
            _buildPermissionDenied()
          else
            // Video OFF: dark bg with avatar
            Container(
              color: const Color(0xFF1A1A2E),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      child: Text(
                        'U',
                        style: GoogleFonts.outfit(
                          fontSize: 36,
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
            ),

          // ─── Top gradient ──────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 160,
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

          // ─── Bottom gradient ───────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 320,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // ─── Header: Close + Meeting pill ─────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    // Close button
                    GestureDetector(
                      onTap: () {
                        _stopCamera();
                        context.pop();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
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
                    const SizedBox(width: 12),
                    // Meeting title pill
                    Flexible(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam_rounded,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    widget.meetingTitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
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
              ),
            ),
          ),

          // ─── "Tú" name tag on camera ──────────────────────────
          if (_isVideoOn && _cameraReady)
            Positioned(
              left: AppSpacing.lg,
              bottom: MediaQuery.of(context).size.height * 0.35,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
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

          // ─── Bottom controls area ─────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── 3 Control Buttons ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ControlButton(
                          icon: _isMicOn ? Icons.mic : Icons.mic_off,
                          isActive: _isMicOn,
                          onTap: _toggleMic,
                        ),
                        const SizedBox(width: 24),
                        _ControlButton(
                          icon: _isVideoOn
                              ? Icons.videocam
                              : Icons.videocam_off,
                          isActive: _isVideoOn,
                          onTap: _toggleVideo,
                        ),
                        const SizedBox(width: 24),
                        _ControlButton(
                          icon: _isAudioOn
                              ? Icons.headphones
                              : Icons.headphones_battery,
                          isActive: _isAudioOn,
                          onTap: _toggleAudio,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Waiting status ──
                    if (_isWaiting) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Pidiendo entrar a la reunión...',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Podrás entrar tan pronto te acepten tu solicitud.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── "Soy el anfitrión" button ──
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          setState(() => _isWaiting = false);

                          // Build Jitsi room URL
                          final room = widget.meetingTitle
                              .replaceAll(' ', '-')
                              .replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '');
                          final jitsiUrl = Uri.parse(
                            '${Env.jitsiServerUrl}/$room'
                            '#config.startWithAudioMuted=${!_isMicOn}'
                            '&config.startWithVideoMuted=${!_isVideoOn}',
                          );

                          if (await canLaunchUrl(jitsiUrl)) {
                            _stopCamera();
                            await launchUrl(
                              jitsiUrl,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No se pudo abrir la videollamada'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        child: Text(
                          'Soy el anfitrión',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helper widgets ──────────────────────────────────────────────

  Widget _buildLoadingCamera() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
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
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Container(
      color: const Color(0xFF1A1A2E),
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
      ),
    );
  }

  Widget _buildCameraTimeout() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_off_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'La cámara tardó demasiado',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No se pudo inicializar la cámara\nen el tiempo esperado',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            GestureDetector(
              onTap: _retryCamera,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Reintentar',
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
          ],
        ),
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
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.2)
              : MployaColors.red.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
