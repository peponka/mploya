import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Extracted widgets from tiktok_reel_card.dart
// ─────────────────────────────────────────────────────────────────────────────

// ── Claude Match helpers ─────────────────────────────────────────────────────

class ReelScoreBadge extends StatelessWidget {
  final int score;
  const ReelScoreBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80 ? NexTheme.brandAccent : score >= 60 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15), border: Border.all(color: color, width: 2.5)),
      child: Center(child: Text('$score', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900))),
    );
  }
}

class ReelSectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const ReelSectionTitle({super.key, required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: color ?? Colors.white60),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    ]);
  }
}

class ReelBulletItem extends StatelessWidget {
  final String text;
  final bool positive;
  const ReelBulletItem({super.key, required this.text, required this.positive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(positive ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.xmark_circle_fill, size: 14, color: positive ? NexTheme.brandAccent : const Color(0xFFEF4444)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
      ]),
    );
  }
}

Color nivelColor(String nivel) {
  switch (nivel) {
    case 'Excelente': return NexTheme.brandAccent;
    case 'Bueno': return const Color(0xFF4CAF50);
    case 'Regular': return const Color(0xFFFF9800);
    default: return const Color(0xFFFF6B6B);
  }
}

// ── Live Transcript Bubble ───────────────────────────────────────────────────

class LiveTranscriptBubble extends StatefulWidget {
  final String text;
  const LiveTranscriptBubble({super.key, required this.text});

  @override
  State<LiveTranscriptBubble> createState() => _LiveTranscriptBubbleState();
}

class _LiveTranscriptBubbleState extends State<LiveTranscriptBubble> {
  late List<String> _chunks;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _chunks = _generateChunks(widget.text);
    if (_chunks.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
        if (mounted) setState(() => _currentIndex = (_currentIndex + 1) % _chunks.length);
      });
    }
  }

  List<String> _generateChunks(String text) {
    final words = text.split(' ');
    if (words.length < 4) return [text, 'Me encantaría unirme a', 'tu equipo de trabajo y', 'crecer juntos profesionalmente.', text];
    List<String> results = [];
    for (int i = 0; i < words.length; i += 4) {
      results.add(words.sublist(i, (i + 4 > words.length ? words.length : i + 4)).join(' '));
    }
    return results;
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_chunks.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(MployaTheme.radiusMD),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(MployaTheme.radiusMD), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(CupertinoIcons.wand_stars, color: Colors.white54, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(anim), child: child)),
              child: Text(_chunks[_currentIndex], key: ValueKey<int>(_currentIndex), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: -0.2), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Reply Video Modal ────────────────────────────────────────────────────────

class ReplyVideoModal extends StatefulWidget {
  final String videoUrl;
  final String senderName;
  const ReplyVideoModal({super.key, required this.videoUrl, required this.senderName});

  @override
  State<ReplyVideoModal> createState() => _ReplyVideoModalState();
}

class _ReplyVideoModalState extends State<ReplyVideoModal> {
  late VideoPlayerController _ctrl;
  bool _ready = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _ctrl.initialize().then((_) {
      if (mounted) { setState(() => _ready = true); _ctrl.play(); _ctrl.setLooping(true); }
    }).catchError((_) { if (mounted) setState(() => _error = true); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              const Icon(CupertinoIcons.play_circle_fill, color: Color(0xFF5F3DC4), size: 20),
              const SizedBox(width: 8),
              Text('Respuesta de ${widget.senderName}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              CupertinoButton(padding: EdgeInsets.zero, onPressed: () => Navigator.pop(context), child: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white38, size: 28)),
            ]),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _error
                  ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.yellow, size: 48), SizedBox(height: 16), Text('Error al reproducir', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))]))
                  : !_ready
                      ? const Center(child: CupertinoActivityIndicator(color: Colors.white, radius: 16))
                      : GestureDetector(
                          onTap: () { _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play(); setState(() {}); },
                          child: Stack(fit: StackFit.expand, children: [
                            FittedBox(fit: BoxFit.cover, child: SizedBox(width: _ctrl.value.size.width, height: _ctrl.value.size.height, child: VideoPlayer(_ctrl))),
                            if (!_ctrl.value.isPlaying) Container(color: Colors.black26, child: const Center(child: Icon(CupertinoIcons.play_fill, color: Colors.white, size: 48))),
                            Positioned(bottom: 0, left: 0, right: 0, child: VideoProgressIndicator(_ctrl, allowScrubbing: true, colors: const VideoProgressColors(playedColor: NexTheme.brandAccent, bufferedColor: Colors.white24, backgroundColor: Colors.white10))),
                          ]),
                        ),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}
