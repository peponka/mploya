import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/nex_avatar.dart';
import '../services/story_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StoryViewerScreen — Instagram-style story viewer
//
// Carga historias del tipo opuesto de usuario (empresa→candidatos, vice versa).
// Like = "Estoy interesado / Contactame" → notificación al creador.
// ─────────────────────────────────────────────────────────────────────────────

class StoryViewerScreen extends StatefulWidget {
  /// Si se pasan users con videoUrl, se usan como fallback demo.
  /// Si no, se cargan desde StoryService (historias reales de Supabase).
  final List<NexUser> users;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    this.users = const [],
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late PageController _pageController;
  int _currentUserIndex = 0;

  // Datos reales cargados desde Supabase
  List<StoryUser> _storyUsers = [];
  bool _isLoading = true;

  // Video
  VideoPlayerController? _videoController;
  final ValueNotifier<double> _progressNotifier = ValueNotifier(0.0);
  Timer? _progressTimer;
  bool _isClosing = false; // evita múltiples Navigator.pop() al cerrar

  // Like state
  bool _isLiked = false;
  bool _likeAnimating = false;

  // Message
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUserIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentUserIndex);
    _loadStories();
  }

  Future<void> _loadStories() async {
    // Intentar cargar historias reales
    final storyUsers = await StoryService.instance.getStoryUsers();

    if (storyUsers.isNotEmpty) {
      setState(() {
        _storyUsers = storyUsers;
        _isLoading = false;
      });
      _loadVideoForIndex(0);
    } else if (widget.users.isNotEmpty) {
      // Fallback: usar los users pasados como parámetro (pitch videos)
      setState(() {
        _storyUsers = widget.users
            .where((u) => u.videoUrl != null && u.videoUrl!.isNotEmpty)
            .map((u) => StoryUser(
                  user: u,
                  stories: [
                    Story(
                      id: 'demo-${u.id}',
                      userId: u.id,
                      videoUrl: u.videoUrl!,
                      caption: u.headline,
                      createdAt: DateTime.now(),
                      expiresAt: DateTime.now().add(const Duration(hours: 24)),
                    ),
                  ],
                ))
            .toList();
        _isLoading = false;
      });
      if (_storyUsers.isNotEmpty) _loadVideoForIndex(0);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadVideoForIndex(int index) async {
    if (index >= _storyUsers.length) return;
    _cleanupVideo();

    final storyUser = _storyUsers[index];
    if (storyUser.stories.isEmpty) return;

    final videoUrl = resolveVideoUrl(storyUser.stories.first.videoUrl);
    if (videoUrl.isEmpty) return;

    if (videoUrl.startsWith('asset:')) {
      _videoController = VideoPlayerController.asset(videoUrl.replaceAll('asset:', ''));
    } else {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    }

    // ❌ NO usar addListener+setState aquí — reconstruye todo el árbol 60fps y congela el video

    try {
      await _videoController!.initialize();
      debugPrint('📹 Story video initialized: size=${_videoController!.value.size}, duration=${_videoController!.value.duration}');
      if (mounted) {
        setState(() {});
        _videoController!.play();
        debugPrint('📹 Story video play() called, isPlaying=${_videoController!.value.isPlaying}');
        _startProgressTimer();
        _checkLikeStatus(storyUser.stories.first.id);
      }
    } catch (e) {
      debugPrint('❌ Story video error: $e');
    }
  }

  void _cleanupVideo() {
    _progressTimer?.cancel();
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _progressNotifier.value = 0.0;
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _videoController == null || !_videoController!.value.isInitialized) return;

      final position = _videoController!.value.position;
      final duration = _videoController!.value.duration;

      if (duration.inMilliseconds > 0) {
        _progressNotifier.value = position.inMilliseconds / duration.inMilliseconds;

        if (_progressNotifier.value >= 1.0) {
          _nextStory();
        }
      }
    });
  }

  void _nextStory() {
    if (_currentUserIndex < _storyUsers.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Cerrar UNA sola vez. El timer de progreso corre cada 50ms y, durante la
      // animación de pop (~300ms), seguía llamando a _nextStory() => varios
      // Navigator.pop() que cerraban también el feed y dejaban la pantalla en blanco.
      if (_isClosing) return;
      _isClosing = true;
      _progressTimer?.cancel();
      _videoController?.pause();
      Navigator.of(context).pop();
    }
  }

  void _previousStory() {
    if (_currentUserIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;
    if (dx < screenWidth * 0.3) {
      _previousStory();
    } else {
      _nextStory();
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _videoController?.pause();
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _videoController?.play();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentUserIndex = index;
      _isLiked = false;
    });
    _loadVideoForIndex(index);
  }

  Future<void> _checkLikeStatus(String storyId) async {
    final liked = await StoryService.instance.hasLiked(storyId);
    if (mounted) setState(() => _isLiked = liked);
  }

  Future<void> _toggleLike() async {
    if (_currentUserIndex >= _storyUsers.length) return;
    final story = _storyUsers[_currentUserIndex].stories.first;

    HapticFeedback.mediumImpact();

    // Animación
    setState(() => _likeAnimating = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _likeAnimating = false);
    });

    final result = await StoryService.instance.toggleStoryLike(story.id);
    if (mounted) setState(() => _isLiked = result);
  }

  @override
  void dispose() {
    _cleanupVideo();
    _pageController.dispose();
    _messageController.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CupertinoPageScaffold(
        backgroundColor: Colors.black,
        child: Center(child: CupertinoActivityIndicator(radius: 16, color: Colors.white)),
      );
    }

    if (_storyUsers.isEmpty) {
      return CupertinoPageScaffold(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.film, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              const Text(
                'No hay historias por ahora',
                style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Las historias aparecerán aquí cuando\notros usuarios las publiquen',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
              ),
              const SizedBox(height: 32),
              CupertinoButton(
                color: NexTheme.brandAccent,
                borderRadius: BorderRadius.circular(24),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Volver', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: SafeArea(
        top: false,
        // NO usar Dismissible aquí (aplica Transform que congela platform views)
        child: Stack(
            children: [
              // ── Video PageView ──
              PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _storyUsers.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTapDown: _onTapDown,
                    onLongPressStart: _onLongPressStart,
                    onLongPressEnd: _onLongPressEnd,
                    child: Container(
                      color: Colors.black,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Video — NO usar FittedBox/Transform (congela platform view en CanvasKit)
                          // AspectRatio mantiene la proporción original del video:
                          //  - Vertical (9:16, celular): llena pantalla completa
                          //  - Horizontal (16:9, webcam): centrado con franjas negras
                          //  - Cuadrado (1:1): centrado con franjas mínimas
                          if (_videoController != null && _videoController!.value.isInitialized)
                            Positioned.fill(
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: _videoController!.value.aspectRatio,
                                  child: VideoPlayer(_videoController!),
                                ),
                              ),
                            )
                          else
                            const Center(child: CupertinoActivityIndicator(radius: 16)),

                          // Gradiente inferior
                          Positioned(
                            bottom: 0, left: 0, right: 0, height: 180,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                          ),

                          // Gradiente superior
                          Positioned(
                            top: 0, left: 0, right: 0, height: 120,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // ── Progress Bars ──
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                right: 8,
                child: ValueListenableBuilder<double>(
                  valueListenable: _progressNotifier,
                  builder: (context, progress, _) {
                    return Row(
                      children: List.generate(
                        _storyUsers.length,
                        (index) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Container(
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  double width = 0.0;
                                  if (index < _currentUserIndex) {
                                    width = constraints.maxWidth;
                                  } else if (index == _currentUserIndex) {
                                    width = constraints.maxWidth * progress;
                                  }
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      width: width,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Header (Avatar, Name, Close) ──
              Positioned(
                top: MediaQuery.of(context).padding.top + 20,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    NexAvatar(user: _storyUsers[_currentUserIndex].user, size: 38, showStoryRing: false),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _storyUsers[_currentUserIndex].user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                            ),
                          ),
                          Text(
                            _storyUsers[_currentUserIndex].user.headline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Icon(CupertinoIcons.xmark, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Caption overlay ──
              if (_storyUsers[_currentUserIndex].stories.isNotEmpty &&
                  _storyUsers[_currentUserIndex].stories.first.caption != null)
                Positioned(
                  bottom: 120,
                  left: 16,
                  right: 80,
                  child: Text(
                    _storyUsers[_currentUserIndex].stories.first.caption!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                    ),
                  ),
                ),

              // ── Like animation (center) ──
              if (_likeAnimating)
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.5, end: 1.3),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Icon(
                          CupertinoIcons.bolt_fill,
                          size: 80,
                          color: NexTheme.brandAccent.withValues(alpha: 0.9),
                          shadows: [Shadow(color: NexTheme.brandAccent, blurRadius: 30)],
                        ),
                      );
                    },
                  ),
                ),

              // ── Bottom bar (Message + Like) ──
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    // Message field
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: CupertinoTextField(
                          controller: _messageController,
                          placeholder: 'Enviar un mensaje...',
                          placeholderStyle: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w400),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: null,
                          cursorColor: NexTheme.brandAccent,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (text) {
                            if (text.trim().isNotEmpty) {
                              _messageController.clear();
                              FocusScope.of(context).unfocus();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // ⚡ Interesado button (Like = Contactame)
                    GestureDetector(
                      onTap: _toggleLike,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isLiked ? NexTheme.brandAccent : Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: _isLiked ? null : Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          boxShadow: _isLiked
                              ? [BoxShadow(color: NexTheme.brandAccent.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 4))]
                              : null,
                        ),
                        child: const Icon(CupertinoIcons.bolt_fill, color: Colors.white, size: 24),
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