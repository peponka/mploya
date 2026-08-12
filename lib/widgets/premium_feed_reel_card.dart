import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../models/models.dart';
import '../navigation/main_navigation.dart';
import '../providers/user_provider.dart';
import '../screens/profile_screen.dart';
import '../services/coach_mark_service.dart';
import '../services/social_service.dart';
import '../services/video_preload_manager.dart';
import 'reel_card_video.dart';

class PremiumFeedReelCard extends ConsumerStatefulWidget {
  final Post post;
  final bool webMode;
  final bool isFirstCard;

  const PremiumFeedReelCard({
    super.key,
    required this.post,
    this.webMode = false,
    this.isFirstCard = false,
  });

  @override
  ConsumerState<PremiumFeedReelCard> createState() =>
      _PremiumFeedReelCardState();
}

class _PremiumFeedReelCardState extends ConsumerState<PremiumFeedReelCard>
    with RouteAware {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _usesPreloaded = false;
  bool _isMatched = false;
  bool _isBookmarked = false;
  int _matchCount = 0;
  bool _wasPlayingBeforeRoute = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _isMatched = widget.post.isLiked;
    _matchCount = widget.post.likes;
    _initVideo();
    currentMainTabNotifier.addListener(_onTabChanged);
    _loadBookmarkState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<dynamic>) {
      feedRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    currentMainTabNotifier.removeListener(_onTabChanged);
    if (_controller != null && !_usesPreloaded) {
      _controller!.dispose();
    }
    super.dispose();
  }

  @override
  void didPushNext() {
    if (_controller == null) return;
    _wasPlayingBeforeRoute = _controller!.value.isPlaying;
    if (_wasPlayingBeforeRoute) {
      _controller!.pause();
      _controller!.setVolume(0);
    }
  }

  @override
  void didPopNext() {
    if (!mounted || _controller == null) return;
    if (_wasPlayingBeforeRoute && currentMainTabNotifier.value == 0) {
      _controller!.setVolume(_isMuted ? 0 : 1);
      _controller!.play();
    }
    _wasPlayingBeforeRoute = false;
  }

  void _onTabChanged() {
    if (!mounted || _controller == null) return;
    if (currentMainTabNotifier.value != 0 && _controller!.value.isPlaying) {
      _controller!.pause();
      _controller!.setVolume(0);
    }
  }

  Future<void> _loadBookmarkState() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('saved_profiles')
          .select('saved_user_id')
          .eq('user_id', myId)
          .eq('saved_user_id', widget.post.author.id)
          .maybeSingle();
      if (mounted) {
        setState(() => _isBookmarked = row != null);
      }
    } catch (_) {}
  }

  Future<void> _initVideo() async {
    final url = widget.post.videoUrl;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }
    if (mounted) {
      setState(() {
        _isInitialized = false;
        _hasError = false;
      });
    }

    final preloaded = VideoPreloadManager.instance.getController(url);
    if (preloaded != null) {
      if (_controller != null && !_usesPreloaded) await _controller!.dispose();
      _controller = preloaded;
      _usesPreloaded = true;
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        _controller!.setVolume(_isMuted ? 0 : 1);
        _controller!.play();
      }
      return;
    }

    VideoPreloadManager.instance.onReady(url, () {
      if (!mounted) return;
      if (VideoPreloadManager.instance.hasError(url)) {
        setState(() => _hasError = true);
        return;
      }
      final ready = VideoPreloadManager.instance.getController(url);
      if (ready == null) return;
      _controller = ready;
      _usesPreloaded = true;
      setState(() {
        _isInitialized = true;
        _hasError = false;
      });
      _controller!.setVolume(_isMuted ? 0 : 1);
      _controller!.play();
    });
  }

  void _handleVisibility(VisibilityInfo info) {
    if (!_isInitialized || _controller == null) return;
    if (currentMainTabNotifier.value != 0) return;
    if (info.visibleFraction > 0.6) {
      if (!_controller!.value.isPlaying) {
        _controller!.setVolume(_isMuted ? 0 : 1);
        _controller!.play();
      }
    } else if (info.visibleFraction < 0.2 && _controller!.value.isPlaying) {
      _controller!.pause();
      _controller!.setVolume(0);
    }
  }

  void _togglePlayPause() {
    if (!_isInitialized || _controller == null) return;
    HapticFeedback.selectionClick();
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      _controller!.setVolume(0);
    } else {
      _controller!.setVolume(_isMuted ? 0 : 1);
      _controller!.play();
    }
    setState(() {});
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() => _isMuted = !_isMuted);
    _controller!.setVolume(_isMuted ? 0 : 1);
  }

  Future<void> _toggleMatch() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isMatched = !_isMatched;
      _matchCount += _isMatched ? 1 : -1;
    });
    final result = await SocialService.instance.togglePitchLike(
      widget.post.author.id,
    );
    if (mounted && result != null) {
      setState(() {
        _isMatched = result.liked;
        _matchCount = result.likeCount;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;
    final authorId = widget.post.author.id;
    setState(() => _isBookmarked = !_isBookmarked);
    try {
      if (_isBookmarked) {
        await Supabase.instance.client.from('saved_profiles').upsert({
          'user_id': myId,
          'saved_user_id': authorId,
        }, onConflict: 'user_id,saved_user_id');
      } else {
        await Supabase.instance.client
            .from('saved_profiles')
            .delete()
            .eq('user_id', myId)
            .eq('saved_user_id', authorId);
      }
    } catch (_) {
      if (mounted) setState(() => _isBookmarked = !_isBookmarked);
    }
  }

  Future<void> _shareProfile() async {
    final profileUrl = 'https://mploya.ai/u/${widget.post.author.id}';
    await Clipboard.setData(ClipboardData(text: profileUrl));
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Enlace copiado'),
        content: const Text('Ya podes compartir este perfil o vacante.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openProfile() {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: widget.post.author)));
  }

  @override
  Widget build(BuildContext context) {
    final author = widget.post.author;
    final currentUser = ref.watch(currentUserProvider).value;
    final viewerType = (currentUser?.accountType ?? 'candidato').toLowerCase();
    final seesVacancy = viewerType == 'candidato';
    final matchScore = author.matchPercentage > 0
        ? author.matchPercentage.round()
        : (widget.post.matchPercentage > 0
              ? widget.post.matchPercentage.round()
              : 82);
    final tags = author.tags.take(4).toList();
    final years = author.experience.isNotEmpty ? author.experience.length * 2 : 0;
    final location = (author.location ?? '').trim();
    final salary = (author.salaryExpectation ?? '').trim();
    final about = (author.about ?? '').trim();
    final title = author.headline.isNotEmpty
        ? author.headline
        : (author.isCompanyAct ? 'Oportunidad destacada' : author.name);
    final subtitle = author.isCompanyAct ? author.name : author.headline;
    final primaryActionLabel = seesVacancy ? 'Postularme' : 'Interesado';
    final detailActionLabel = seesVacancy ? 'Ver vacante' : 'Ver perfil';
    final pitchLabel = seesVacancy
        ? 'Estamos contratando'
        : 'Talento recomendado';
    final playing = _controller?.value.isPlaying ?? false;

    Widget glassPill(IconData icon, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.26),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    Widget metricBadge() {
      return GestureDetector(
        onTap: _toggleMatch,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.webMode ? 16 : 14,
            vertical: widget.webMode ? 14 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: widget.webMode ? 46 : 40,
                height: widget.webMode ? 46 : 40,
                child: CustomPaint(
                  painter: _ProgressRingPainter(
                    progress: matchScore / 100,
                    color: const Color(0xFF4ADE80),
                  ),
                  child: Center(
                    child: Text(
                      '$matchScore%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.webMode ? 12.5 : 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Match IA',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFFE2E8F0),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    matchScore >= 85 ? 'Muy alto' : 'Compatible',
                    style: TextStyle(
                      fontSize: widget.webMode ? 14 : 12.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget sideAction({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool highlighted = false,
      String? value,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: highlighted ? 72 : 58,
              height: highlighted ? 72 : 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: highlighted
                    ? const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF5B34E6)],
                      )
                    : null,
                color: highlighted
                    ? null
                    : Colors.black.withValues(alpha: 0.30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: highlighted ? 0.26 : 0.14),
                ),
                boxShadow: highlighted
                    ? const [
                        BoxShadow(
                          color: Color(0x663B1FA0),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              child: Icon(icon, color: Colors.white, size: highlighted ? 30 : 24),
            ),
            const SizedBox(height: 8),
            if (value != null)
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: highlighted ? 16 : 13,
                fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final overlay = Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlayPause,
          child: ReelVideoBackground(
            author: author,
            controller: _controller,
            isInitialized: _isInitialized,
            hasError: _hasError,
          ),
        ),
        if (kIsWeb)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlayPause,
            ),
          ),
        Positioned(
          top: widget.webMode ? 28 : 18,
          left: widget.webMode ? 28 : 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFB6A34),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.webMode ? 'Feed Principal' : 'Nuevo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!widget.webMode)
                glassPill(
                  CupertinoIcons.location_solid,
                  location.isNotEmpty ? location : 'Modalidad flexible',
                ),
              if (widget.webMode)
                Container(
                  width: 240,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          author.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    author.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (author.isVerified)
                                  const Icon(
                                    CupertinoIcons.checkmark_seal_fill,
                                    color: Color(0xFF4ADE80),
                                    size: 16,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              author.isCompanyAct
                                  ? 'Empresa verificada'
                                  : 'Perfil con video activo',
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          top: widget.webMode ? 28 : 18,
          right: widget.webMode ? 28 : 18,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              metricBadge(),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  width: widget.webMode ? 52 : 46,
                  height: widget.webMode ? 52 : 46,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.30),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Icon(
                    _isMuted
                        ? CupertinoIcons.speaker_slash_fill
                        : CupertinoIcons.speaker_2_fill,
                    color: Colors.white,
                    size: widget.webMode ? 22 : 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: widget.webMode ? 118 : 102,
          right: widget.webMode ? 28 : 18,
          child: Column(
            children: [
              sideAction(
                icon: _isBookmarked
                    ? CupertinoIcons.bookmark_fill
                    : CupertinoIcons.bookmark,
                label: 'Guardar',
                onTap: _toggleBookmark,
              ),
              const SizedBox(height: 16),
              sideAction(
                icon: CupertinoIcons.heart,
                label: 'Match',
                value: '${_matchCount < 0 ? 0 : _matchCount}',
                onTap: _toggleMatch,
              ),
              const SizedBox(height: 16),
              sideAction(
                icon: CupertinoIcons.arrowshape_turn_up_right,
                label: 'Compartir',
                onTap: _shareProfile,
              ),
              const SizedBox(height: 16),
              sideAction(
                icon: CupertinoIcons.rocket_fill,
                label: primaryActionLabel,
                onTap: _toggleMatch,
                highlighted: true,
              ),
            ],
          ),
        ),
        if (!_hasError && !_isInitialized)
          const Center(
            child: CupertinoActivityIndicator(radius: 18, color: Colors.white),
          ),
        if (!playing && _isInitialized && !_hasError)
          Center(
            child: Container(
              width: widget.webMode ? 108 : 88,
              height: widget.webMode ? 108 : 88,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.32),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.26),
                  width: 2,
                ),
              ),
              child: Icon(
                CupertinoIcons.play_fill,
                color: Colors.white,
                size: widget.webMode ? 42 : 36,
              ),
            ),
          ),
        Positioned(
          left: widget.webMode ? 28 : 18,
          right: widget.webMode ? 138 : 94,
          bottom: widget.webMode ? 28 : 18,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              widget.webMode ? 24 : 18,
              widget.webMode ? 20 : 16,
              widget.webMode ? 24 : 18,
              widget.webMode ? 20 : 16,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 24,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pitchLabel.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB794F4),
                    letterSpacing: 0.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.webMode ? 36 : 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.02,
                  ),
                ),
                const SizedBox(height: 10),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: widget.webMode ? 16 : 14,
                      color: const Color(0xFFE2E8F0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (years > 0)
                      glassPill(CupertinoIcons.briefcase, '$years anos exp.'),
                    glassPill(
                      CupertinoIcons.location_solid,
                      location.isNotEmpty ? location : 'Modalidad flexible',
                    ),
                    if (salary.isNotEmpty)
                      glassPill(CupertinoIcons.money_dollar_circle, salary),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  about.isNotEmpty
                      ? about
                      : 'Video pitch listo para una decision rapida sin salir del feed.',
                  maxLines: widget.webMode ? 3 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.webMode ? 15 : 14,
                    height: 1.5,
                    color: const Color(0xFFF8FAFC),
                  ),
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              t.startsWith('#') ? t : '#$t',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  key: widget.isFirstCard ? cmFeedActionsKey : null,
                  children: [
                    Expanded(
                      child: Container(
                        height: 76,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: CustomPaint(
                                painter: _ProgressRingPainter(
                                  progress: matchScore / 100,
                                  color: matchScore >= 85
                                      ? const Color(0xFF4ADE80)
                                      : const Color(0xFF8B5CF6),
                                ),
                                child: Center(
                                  child: Text(
                                    '$matchScore%',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Match IA',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  fontSize: widget.webMode ? 18 : 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _openProfile,
                      child: Container(
                        height: 76,
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.webMode ? 26 : 22,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6A1A),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          detailActionLabel,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.webMode ? 20 : 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return VisibilityDetector(
      key: Key('premium-feed-${widget.post.id}'),
      onVisibilityChanged: _handleVisibility,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            child: Container(
              margin: EdgeInsets.fromLTRB(
                widget.webMode ? 4 : 2,
                8,
                widget.webMode ? 4 : 2,
                4,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.webMode ? 34 : 28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 26,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.webMode ? 34 : 28),
                child: overlay,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _ProgressRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final bg = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      progress.clamp(0, 1) * 6.2832,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
