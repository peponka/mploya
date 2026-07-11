import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../navigation/main_navigation.dart';
import 'nex_avatar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Textos de transcripción IA (placeholder hasta que el servicio de
// transcripción real devuelva los segmentos vía Deepgram/ai_transcript_json).
// En producción se reemplazarán con los datos reales del campo
// `ai_transcript_json` del post o perfil del usuario.
// ─────────────────────────────────────────────────────────────────────────────
const _kTranscriptLines = [
  '— [IA]  Analizando video-pitch…',
  '— [IA]  Extrayendo palabras clave de tu presentación…',
  '— [IA]  Evaluando tono y claridad del mensaje…',
  '— [IA]  Identificando habilidades mencionadas…',
  '— [IA]  Generando resumen ejecutivo del pitch…',
];

// ─────────────────────────────────────────────────────────────────────────────
// PostCard
// ─────────────────────────────────────────────────────────────────────────────

class PostCard extends StatefulWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  bool _isMatched = false;
  late int _matchCount;
  late AnimationController _matchAnim;
  late Animation<double> _matchScale;

  @override
  void initState() {
    super.initState();
    _isMatched = widget.post.isLiked;
    _matchCount = widget.post.likes;

    _matchAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _matchScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _matchAnim, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _matchAnim.dispose();
    super.dispose();
  }

  void _toggleMatch() {
    setState(() {
      _isMatched = !_isMatched;
      _matchCount += _isMatched ? 1 : -1;
    });
    _matchAnim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isVideo = post.type == PostType.video;

    return Container(
      margin: const EdgeInsets.only(bottom: MployaTheme.spaceSM),
      decoration: BoxDecoration(
        color: context.cardColor,
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          _CardHeader(post: post),

          // ── Texto de la publicación ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: _PostContent(text: post.content),
          ),

          // ── Media: Video ──
          if (isVideo) _VideoBlock(post: post),

          // ── Media: Imagen ──
          if (post.type == PostType.image) const _ImageBlock(),

          // ── Artículo ──
          if (post.type == PostType.article) const _ArticleBlock(),

          // ── Indicadores de engagement profesional ──
          _EngagementRow(
            matchCount: _matchCount,
            aportesCount: post.comments,
            compartidosCount: post.reposts,
            isMatched: _isMatched,
          ),

          // ── Divider ──
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 16,
            endIndent: 16,
            color: context.dividerColor,
          ),

          // ── Botón HACER MATCH (CTA principal) ──
          _MatchCTA(
            isMatched: _isMatched,
            scaleAnimation: _matchScale,
            onTap: _toggleMatch,
          ),

          // ── Acciones secundarias ──
          _SecondaryActions(post: post),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final Post post;
  const _CardHeader({required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NexAvatar(user: post.author, size: 48, showBadge: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        post.author.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (post.author.isPremium) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        CupertinoIcons.star_circle_fill,
                        size: 15,
                        color: MployaTheme.premiumGold,
                      ),
                    ],
                    // Badge Identidad Verificada
                    if (post.author.isPremium) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MployaTheme.openToWork.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                              MployaTheme.radiusPill),
                          border: Border.all(
                            color:
                                MployaTheme.openToWork.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.checkmark_seal_fill,
                              size: 10,
                              color: MployaTheme.openToWork,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Verificado',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: MployaTheme.openToWork,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  post.author.headline,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.textSecondary,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      post.timeAgo,
                      style: TextStyle(
                          fontSize: 12, color: context.textTertiary),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text('·',
                          style: TextStyle(
                              fontSize: 12, color: context.textTertiary)),
                    ),
                    Icon(CupertinoIcons.globe,
                        size: 12, color: context.textTertiary),
                  ],
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            minimumSize: Size.zero,
            onPressed: null,
            child: Icon(CupertinoIcons.ellipsis,
                size: 20, color: context.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bloque de Video con Play real + Badge Match % + Overlay Glass Transcript IA
// ─────────────────────────────────────────────────────────────────────────────

class _VideoBlock extends StatefulWidget {
  final Post post;
  const _VideoBlock({required this.post});

  @override
  State<_VideoBlock> createState() => _VideoBlockState();
}

class _VideoBlockState extends State<_VideoBlock> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _hasError = false;

  // Pestaña del sidebar en la que vive esta card. Si el usuario cambia de
  // sección, VisibilityDetector puede seguir reportando esta card como
  // "visible" (geométricamente lo es dentro del IndexedStack inactivo), así
  // que sin este guard el video revive el audio en otra sección.
  late final int _ownerTabIndex = currentMainTabNotifier.value;

  @override
  void initState() {
    super.initState();
    currentMainTabNotifier.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!mounted || _controller == null) return;
    if (currentMainTabNotifier.value != _ownerTabIndex) {
      if (_controller!.value.isPlaying) _controller!.pause();
      if (kIsWeb) _controller!.setVolume(0);
    }
  }

  String get _durationLabel {
    if (!_isInitialized || _controller == null) return 'Video-Pitch';
    final d = _controller!.value.duration;
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return 'Video-Pitch · $m:$s';
  }

  Future<void> _initAndPlay() async {
    final url = widget.post.videoUrl;
    debugPrint('▶ _initAndPlay() disparado para url: $url');
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }
    
    if (_isLoading || _isInitialized) return;
    
    if (mounted) setState(() => _isLoading = true);

    try {
      debugPrint('Inicializando controlador network...');
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await _controller!.initialize();
      debugPrint('Controlador inicializado con exito.');
      
      _controller!.setLooping(true); // Estilo TikTok (bucle infinito)
      _controller!.addListener(_videoListener);
      
      await _controller!.play();
      debugPrint('Video reproduciendo.');
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error initAndPlay Video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _videoListener() {
    if (_controller == null || !mounted) return;
    setState(() {});
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    
    final value = _controller!.value;
    setState(() {
      value.isPlaying ? _controller!.pause() : _controller!.play();
    });
  }

  void _handleVisibility(VisibilityInfo info) {
    if (!mounted) return;
    final fraction = info.visibleFraction;
    if (currentMainTabNotifier.value != _ownerTabIndex) return;

    if (fraction > 0.6) {
      // Auto-play cuando cruza el 60% de exposición
      if (!_isInitialized && !_isLoading && !_hasError) {
        _initAndPlay();
      } else if (_isInitialized && _controller != null && !_controller!.value.isPlaying) {
        _controller!.play();
      }
    } else if (fraction < 0.2) {
      // Auto-pause cuando se va de pantalla para ahorrar rendimiento
      if (_isInitialized && _controller != null && _controller!.value.isPlaying) {
        _controller!.pause();
      }
    }
  }

  @override
  void dispose() {
    currentMainTabNotifier.removeListener(_onTabChanged);
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video-${widget.post.id}'),
      onVisibilityChanged: _handleVisibility,
      child: Container(
        width: double.infinity,
        color: context.isDark ? const Color(0xFF151515) : const Color(0xFFEBEBEB),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500),
            child: AspectRatio(
              aspectRatio: _isInitialized && _controller != null
                  ? _controller!.value.aspectRatio
                  : 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Fondo / Video ──
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: context.isDark
                          ? const [Color(0xFF1C1C1E), Color(0xFF2C2C2E)]
                          : const [Color(0xFFD8D8D8), Color(0xFFC0C0C0)],
                    ),
                  ),
          child: _isInitialized && _controller != null && !_hasError
              ? GestureDetector(
                  onTap: _togglePlayPause,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                )
              : _hasError
                  ? const Center(
                      child: Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.white54, size: 36),
                    )
                  : null,
        ),

        // ── Botón de play inicial / loading ──
        if (!_isInitialized && !_hasError)
          GestureDetector(
            onTap: _initAndPlay,
            child: _isLoading
                ? const CupertinoActivityIndicator(color: Colors.white, radius: 18)
                : Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: MployaTheme.brandAccent.withValues(alpha: 0.93),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: const Icon(
                      CupertinoIcons.play_arrow_solid,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
          ),

        // ── Icono de pausa semitransparente táctil ──
        if (_isInitialized && _controller != null && !_controller!.value.isPlaying)
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.50),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.play_arrow_solid,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),

        // ── Badge Match % (top right) ──
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.6)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.bolt_fill, color: MployaTheme.brandAccent, size: 13),
                SizedBox(width: 4),
                Text(
                  '87% Match',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Duración (top left) ──
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.video_camera, color: Colors.white70, size: 12),
                const SizedBox(width: 4),
                Text(
                  _durationLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Glassmorphism AI Transcript Overlay ──
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _GlassTranscriptOverlay(),
        ),
      ],
    ),
          ),
        ),
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glassmorphism Overlay — Subtítulos IA dinámicos
// ─────────────────────────────────────────────────────────────────────────────

class _GlassTranscriptOverlay extends StatefulWidget {
  const _GlassTranscriptOverlay();

  @override
  State<_GlassTranscriptOverlay> createState() =>
      _GlassTranscriptOverlayState();
}

class _GlassTranscriptOverlayState
    extends State<_GlassTranscriptOverlay>
    with SingleTickerProviderStateMixin {
  int _lineIndex = 0;
  Timer? _timer;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    // Rotación cada 3 segundos
    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      // Fade out
      await _fadeCtrl.reverse();
      if (mounted) {
        setState(() {
          _lineIndex = (_lineIndex + 1) % _kTranscriptLines.length;
        });
        // Fade in
        _fadeCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = !context.isDark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding:
              const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: isLight
                ? Colors.white.withValues(alpha: 0.88)
                : Colors.black.withValues(alpha: 0.72),
            border: Border(
              top: BorderSide(
                color: isLight
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge IA
              Container(
                margin: const EdgeInsets.only(top: 1, right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: MployaTheme.brandAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'IA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Texto de transcripción con fade
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Text(
                    _kTranscriptLines[_lineIndex],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isLight
                          ? const Color(0xFF1C1C1E)
                          : Colors.white.withValues(alpha: 0.92),
                      height: 1.4,
                      fontFamily: '.SF Pro Text',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Indicador "en vivo"
              Container(
                margin: const EdgeInsets.only(left: 8, top: 2),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: MployaTheme.brandAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bloque de imagen
// ─────────────────────────────────────────────────────────────────────────────

class _ImageBlock extends StatelessWidget {
  const _ImageBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      width: double.infinity,
      color: context.isDark
          ? const Color(0xFF262626)
          : const Color(0xFFEEEEEE),
      child: Center(
        child: Icon(
          CupertinoIcons.photo,
          size: 44,
          color: context.textTertiary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bloque de artículo
// ─────────────────────────────────────────────────────────────────────────────

class _ArticleBlock extends StatelessWidget {
  const _ArticleBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: context.dividerColor),
        borderRadius: BorderRadius.circular(MployaTheme.radiusMD),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: MployaTheme.brandAccent.withValues(alpha: 0.08),
              borderRadius:
                  BorderRadius.circular(MployaTheme.radiusSM),
            ),
            child: const Icon(
              CupertinoIcons.doc_text_fill,
              color: MployaTheme.brandAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Artículo Profesional',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Lectura · 8 min',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fila de engagement profesional (sin likes genéricos)
// ─────────────────────────────────────────────────────────────────────────────

class _EngagementRow extends StatelessWidget {
  final int matchCount;
  final int aportesCount;
  final int compartidosCount;
  final bool isMatched;

  const _EngagementRow({
    required this.matchCount,
    required this.aportesCount,
    required this.compartidosCount,
    required this.isMatched,
  });

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          // Icono de chispa match
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isMatched
                  ? MployaTheme.brandAccent
                  : context.textTertiary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.bolt_fill,
                size: 11,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '${_fmt(matchCount)} intereses profesionales',
            style: TextStyle(
              fontSize: 12.5,
              color: context.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '${_fmt(aportesCount)} aportes',
            style: TextStyle(
              fontSize: 12.5,
              color: context.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CTA Principal — Hacer Match
// ─────────────────────────────────────────────────────────────────────────────

class _MatchCTA extends StatelessWidget {
  final bool isMatched;
  final Animation<double> scaleAnimation;
  final VoidCallback onTap;

  const _MatchCTA({
    required this.isMatched,
    required this.scaleAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: ScaleTransition(
        scale: scaleAnimation,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: 48,
            decoration: BoxDecoration(
              gradient: isMatched
                  ? null
                  : const LinearGradient(
                      colors: [
                        NexTheme.brandAccent,
                        NexTheme.premiumEnd,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
              color: isMatched
                  ? MployaTheme.brandAccent.withValues(alpha: 0.12)
                  : null,
              borderRadius:
                  BorderRadius.circular(MployaTheme.radiusPill),
              border: isMatched
                  ? Border.all(
                      color: MployaTheme.brandAccent.withValues(alpha: 0.5),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isMatched
                      ? CupertinoIcons.bolt_fill
                      : CupertinoIcons.bolt,
                  size: 18,
                  color: isMatched
                      ? MployaTheme.brandAccent
                      : Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  isMatched
                      ? 'Match enviado  ✓'
                      : 'Hacer Match  —  Mostrar Interés',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isMatched
                        ? MployaTheme.brandAccent
                        : Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Acciones secundarias (sin Like)
// ─────────────────────────────────────────────────────────────────────────────

class _SecondaryActions extends StatelessWidget {
  final Post post;
  const _SecondaryActions({required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          // Aportar
          _SecBtn(
            icon: CupertinoIcons.chat_bubble_text,
            label: 'Aportar',
            onTap: () {},
          ),
          // Compartir
          _SecBtn(
            icon: CupertinoIcons.arrowshape_turn_up_right,
            label: 'Compartir',
            onTap: () {},
          ),
          // Guardar
          _SecBtn(
            icon: CupertinoIcons.bookmark,
            label: 'Guardar',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _SecBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 10),
        minimumSize: Size.zero,
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: context.textSecondary),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Texto expandible de la publicación
// ─────────────────────────────────────────────────────────────────────────────

class _PostContent extends StatefulWidget {
  final String text;
  const _PostContent({required this.text});

  @override
  State<_PostContent> createState() => _PostContentState();
}

class _PostContentState extends State<_PostContent> {
  bool _expanded = false;
  static const int _maxLength = 200;

  @override
  Widget build(BuildContext context) {
    final shouldTruncate = widget.text.length > _maxLength;
    final displayText = shouldTruncate && !_expanded
        ? '${widget.text.substring(0, _maxLength)}...'
        : widget.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayText,
          style: TextStyle(
            fontSize: 14.5,
            color: context.textPrimary,
            height: 1.45,
          ),
        ),
        if (shouldTruncate && !_expanded)
          GestureDetector(
            onTap: () => setState(() => _expanded = true),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '...ver más',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.brandAccent,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
