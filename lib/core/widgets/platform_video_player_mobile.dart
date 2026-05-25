/// Implementación mobile del reproductor de video.
///
/// Usa el plugin `video_player` para reproducir videos
/// nativamente en Android/iOS.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Construye un reproductor de video mobile usando video_player.
Widget buildPlatformVideoPlayer({
  required String viewId,
  required String url,
  String objectFit = 'cover',
  bool mirror = false,
  bool loop = true,
  bool autoplay = true,
  bool muted = false,
  bool controls = false,
  String? borderRadius,
  String background = '#000',
  String? transform,
  String? filter,
}) {
  return _MobileVideoPlayer(
    url: url,
    loop: loop,
    autoplay: autoplay,
    muted: muted,
    objectFit: objectFit,
  );
}

/// Widget stateful que maneja el VideoPlayerController.
class _MobileVideoPlayer extends StatefulWidget {
  const _MobileVideoPlayer({
    required this.url,
    required this.loop,
    required this.autoplay,
    required this.muted,
    required this.objectFit,
  });

  final String url;
  final bool loop;
  final bool autoplay;
  final bool muted;
  final String objectFit;

  @override
  State<_MobileVideoPlayer> createState() => _MobileVideoPlayerState();
}

class _MobileVideoPlayerState extends State<_MobileVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    // Detectar si es URL de red o archivo local
    if (widget.url.startsWith('http://') || widget.url.startsWith('https://')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    } else {
      _controller = VideoPlayerController.file(File(widget.url));
    }

    await _controller.initialize();
    _controller.setLooping(widget.loop);
    _controller.setVolume(widget.muted ? 0.0 : 1.0);

    if (widget.autoplay) {
      await _controller.play();
    }

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    // Ajustar el fit según objectFit
    final fit = widget.objectFit == 'contain' ? BoxFit.contain : BoxFit.cover;

    return FittedBox(
      fit: fit,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
