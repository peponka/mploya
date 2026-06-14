import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/transcription_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReelSubtitleOverlay — Subtítulos sincronizados sobre el video pitch
//
// Muestra texto con animación karaoke-style:
//   - Carga segmentos de `users.ai_transcript_json` via TranscriptionService
//   - Escucha el video controller para encontrar el segmento activo
//   - Animación fade-in con glassmorphism pill
//   - Botón toggle (CC) para activar/desactivar
// ─────────────────────────────────────────────────────────────────────────────

class ReelSubtitleOverlay extends StatefulWidget {
  final VideoPlayerController? controller;
  final String authorId;
  final bool isInitialized;

  const ReelSubtitleOverlay({
    super.key,
    required this.controller,
    required this.authorId,
    required this.isInitialized,
  });

  @override
  State<ReelSubtitleOverlay> createState() => _ReelSubtitleOverlayState();
}

class _ReelSubtitleOverlayState extends State<ReelSubtitleOverlay>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _segments = [];
  bool _loaded = false;
  bool _enabled = true;
  String? _currentText;
  VoidCallback? _listener;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadTranscript();
    _attachListener();
  }

  @override
  void didUpdateWidget(ReelSubtitleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachListener();
      _attachListener();
    }
    if (oldWidget.authorId != widget.authorId) {
      _loadTranscript();
    }
  }

  void _attachListener() {
    if (widget.controller == null) return;
    _listener = () {
      if (!mounted || !_enabled || _segments.isEmpty) return;
      final pos = widget.controller!.value.position.inMilliseconds / 1000.0;
      final seg = TranscriptionService.findActiveSegment(_segments, pos);
      final newText = seg?['text']?.toString();
      if (newText != _currentText) {
        setState(() => _currentText = newText);
        if (newText != null) {
          _fadeController.forward(from: 0);
        }
      }
    };
    widget.controller!.addListener(_listener!);
  }

  void _detachListener() {
    if (_listener != null && widget.controller != null) {
      widget.controller!.removeListener(_listener!);
    }
    _listener = null;
  }

  Future<void> _loadTranscript() async {
    if (_loaded) return;
    try {
      final segments = await TranscriptionService.instance
          .getTranscript(widget.authorId);
      if (mounted) {
        setState(() {
          _segments = segments;
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Subtitle load failed: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  void dispose() {
    _detachListener();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isInitialized || _segments.isEmpty) {
      return const SizedBox.shrink();
    }

    // ── TikTok-style: just subtitle text, tap to toggle ──
    if (!_enabled || _currentText == null) {
      // Show nothing, but allow tap to re-enable
      return GestureDetector(
        onTap: () => setState(() => _enabled = true),
        child: const SizedBox(height: 30, width: double.infinity),
      );
    }

    return GestureDetector(
      onTap: () => setState(() {
        _enabled = false;
        _currentText = null;
      }),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Text(
          _currentText!.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: 0.5,
            decoration: TextDecoration.none,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 8),
              Shadow(color: Colors.black, blurRadius: 20),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
