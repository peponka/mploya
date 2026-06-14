import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../theme/app_theme.dart';
import '../../services/chat_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Message Bubble (No-Line Premium styling)
// ─────────────────────────────────────────────────────────────────────────────

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final int? fileSizeBytes;
  final bool isRead;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.time,
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.fileSizeBytes,
    this.isRead = false,
  });

  bool get _hasFile => fileUrl != null && fileUrl!.isNotEmpty;
  bool get _isImage => fileType == 'image';
  bool get _isVideoReply => text.contains('Video Reply') && text.contains('https://');
  String get _extractVideoUrl {
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('http') && trimmed.contains('.mp4')) return trimmed;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMe) const Spacer(flex: 1),
          Flexible(
            flex: 4,
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isMe ? null : context.cardColor,
                    gradient: isMe
                        ? const LinearGradient(
                            colors: [Color(0xFF004E99), Color(0xFF0A66C2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(isMe ? 22 : 6),
                      bottomRight: Radius.circular(isMe ? 6 : 22),
                    ),
                    boxShadow: isMe
                        ? [BoxShadow(color: const Color(0xFF004E99).withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))]
                        : const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Imagen adjunta ──
                      if (_hasFile && _isImage)
                        GestureDetector(
                          onTap: () => _openUrl(fileUrl!),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(22),
                              topRight: Radius.circular(22),
                            ),
                            child: Image.network(
                              fileUrl!,
                              width: 240,
                              height: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 240,
                                height: 60,
                                color: const Color(0xFFF2F2F7),
                                child: const Center(child: Icon(CupertinoIcons.photo, color: Color(0xFF8E8E93))),
                              ),
                            ),
                          ),
                        ),

                      // ── Archivo adjunto (doc/PDF) ──
                      if (_hasFile && !_isImage)
                        GestureDetector(
                          onTap: () => _openUrl(fileUrl!),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(child: Icon(CupertinoIcons.doc_fill, size: 20, color: Color(0xFFFF3B30))),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName ?? 'Archivo',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isMe ? Colors.white : context.textPrimary,
                                        ),
                                      ),
                                      if (fileSizeBytes != null)
                                        Text(
                                          ChatService.formatFileSize(fileSizeBytes!),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isMe ? Colors.white70 : const Color(0xFF8E8E93),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  CupertinoIcons.arrow_down_circle_fill,
                                  size: 24,
                                  color: isMe ? Colors.white70 : const Color(0xFF007AFF),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── Texto del mensaje (con detección de Video Reply) ──
                      if (text.isNotEmpty)
                        _isVideoReply
                            ? VideoReplyBubble(
                                videoUrl: _extractVideoUrl,
                                isMe: isMe,
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isMe ? CupertinoColors.white : context.textPrimary,
                                    fontFamily: '.SF Pro Text',
                                    height: 1.35,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                    ],
                  ),
                ),
                if (time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFAEAEB2),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // ── Read Receipt Checks ──
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            isRead ? CupertinoIcons.checkmark_alt_circle_fill : CupertinoIcons.checkmark_alt_circle,
                            size: 14,
                            color: isRead ? const Color(0xFF34AADC) : const Color(0xFFAEAEB2),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!isMe) const Spacer(flex: 1),
        ],
      ),
    );
  }

  void _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Video Reply Bubble ──
class VideoReplyBubble extends StatelessWidget {
  final String videoUrl;
  final bool isMe;

  const VideoReplyBubble({super.key, required this.videoUrl, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (_) => FullScreenVideoPlayer(videoUrl: videoUrl),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 220,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    NexTheme.brandAccent.withValues(alpha: 0.3),
                    Colors.black87,
                  ],
                ),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: NexTheme.brandAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: NexTheme.brandAccent.withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 28),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Row(
                children: [
                  const Icon(CupertinoIcons.videocam_fill, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Video Reply',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

// ── Fullscreen Video Player (in-app) ──
class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const FullScreenVideoPlayer({super.key, required this.videoUrl});

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video ──
          Center(
            child: _initialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CupertinoActivityIndicator(color: Colors.white, radius: 16),
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
                const Spacer(),
                const Text(
                  'Video Reply',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                const SizedBox(width: 36),
              ],
            ),
          ),

          // ── Play/Pause tap ──
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                });
              },
              behavior: HitTestBehavior.translucent,
              child: _initialized && !_controller.value.isPlaying
                  ? Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 32),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing Dot Animation ──
class TypingDot extends StatefulWidget {
  final int delay;
  const TypingDot({super.key, required this.delay});

  @override
  State<TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _animation.value),
        child: child,
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFF8E8E93),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
