import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../screens/profile_screen.dart';
import '../screens/match_celebration_screen.dart';
import '../services/social_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../navigation/main_navigation.dart';
import '../screens/b2b_paywall_screen.dart';
import '../services/revenuecat_service.dart';
import '../services/nexus_service.dart';
import '../screens/story_viewer_screen.dart';
import '../screens/create_story_screen.dart';

import '../services/error_handler.dart';
import '../services/video_preload_manager.dart';
import '../services/claude_ai_service.dart';
import '../services/hashtag_match_service.dart';
import '../services/coach_mark_service.dart';
import 'reel_card_moderation.dart';
import 'reel_card_comments.dart';
import 'reel_card_helpers.dart';
import 'reel_card_video.dart';
import 'reel_card_overlays.dart';
import 'reel_card_info.dart';
import 'reel_card_actions.dart';
import 'double_tap_heart.dart';
import 'reel_card_subtitles.dart';
import '../screens/video_reply_screen.dart';

class TikTokReelCard extends ConsumerStatefulWidget {
  final Post post;

  /// Estilo web (TikTok web): video en tarjeta redondeada y acciones a la
  /// derecha, fuera del video, sobre fondo blanco.
  final bool webMode;

  /// Primer card del feed: attach GlobalKeys para el coach mark tour.
  final bool isFirstCard;

  const TikTokReelCard({super.key, required this.post, this.webMode = false, this.isFirstCard = false});

  @override
  ConsumerState<TikTokReelCard> createState() => _TikTokReelCardState();
}

class _TikTokReelCardState extends ConsumerState<TikTokReelCard>
    with ReelCardModerationMixin, RouteAware {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _usesPreloaded = false;
  bool _isMatched = false;
  int _matchCount = 0;
  bool _nexusSent = false;
  bool _showBoltAnimation = false;
  bool _isBookmarked = false;
  bool _showReactions = false;
  bool _metadataLoaded = false;
  String? _activeReaction;
  Map<String, int> _reactionCounts = {};
  bool _premiumUnlocked = false;

  // ── Claude AI Match ──
  ClaudeMatchResult? _claudeMatchResult;
  bool _claudeMatchLoading = false;

  // ── Conexión & Mutuals ──
  String _connectionStatus = 'none';
  List<Map<String, dynamic>> _mutualConnections = [];

  // ── Video Reply ──
  String? _replyVideoUrl;
  String? _replySenderName;

  // Recuerda si el video estaba sonando antes de abrir otra pantalla encima,
  // para reanudarlo (solo ese) al volver al feed. Ver [didPushNext]/[didPopNext].
  bool _wasPlayingBeforeRoute = false;

  @override
  void initState() {
    super.initState();
    _isMatched = widget.post.isLiked;
    _matchCount = widget.post.likes;
    _initVideo();
    currentMainTabNotifier.addListener(_onTabChanged);
    HashtagMatchService.instance.loadFrequencies();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Suscribirse al observador de rutas para pausar el video cuando se abra
    // otra pantalla encima del feed (perfil, mensajes, modales, etc.).
    final route = ModalRoute.of(context);
    if (route is ModalRoute<dynamic>) {
      feedRouteObserver.subscribe(this, route);
    }
  }

  /// Se abrió otra ruta ENCIMA del feed → pausar y silenciar este video.
  @override
  void didPushNext() {
    if (_controller == null) return;
    _wasPlayingBeforeRoute = _controller!.value.isPlaying;
    if (_wasPlayingBeforeRoute) {
      _controller!.pause();
      if (kIsWeb) _controller!.setVolume(0);
    }
  }

  /// Volvimos al feed (se cerró la pantalla de encima) → reanudar solo el video
  /// que estaba sonando, y solo si el feed sigue siendo la pestaña activa.
  @override
  void didPopNext() {
    if (!mounted || _controller == null) return;
    if (_wasPlayingBeforeRoute && currentMainTabNotifier.value == 0) {
      if (kIsWeb) _controller!.setVolume(1.0);
      _controller!.play();
    }
    _wasPlayingBeforeRoute = false;
  }

  // ─── Data Loading ─────────────────────────────────────────────────────────

  Future<void> _loadMetadata() async {
    final authorId = widget.post.author.id;
    try {
      final res = await Supabase.instance.client.rpc('get_card_metadata_batch', params: {'p_target_user_id': authorId});
      
      if (mounted && res != null && res['error'] == null) {
        setState(() {
          _nexusSent = res['nexus_sent'] == true;
          _connectionStatus = res['connection_status']?.toString() ?? 'none';
          _isBookmarked = res['is_bookmarked'] == true;
          _activeReaction = res['active_reaction']?.toString();
          
          final counts = res['reaction_counts'] as Map<String, dynamic>? ?? {};
          _reactionCounts = counts.map((k, v) => MapEntry(k, int.tryParse(v.toString()) ?? 0));
          
          final replyUrl = res['reply_video_url']?.toString();
          if (replyUrl != null && replyUrl.isNotEmpty) {
            _replyVideoUrl = replyUrl;
            _replySenderName = 'Reply Recibido';
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error cargando Batch Metadata: $e');
    }
    _fetchMutuals(authorId);
  }

  Future<void> _fetchMutuals(String authorId) async {
    try {
      final count = await SocialService.instance.getMutualCount(authorId);
      if (mounted) setState(() => _mutualConnections = List.generate(count, (_) => <String, dynamic>{}));
    } catch (e) {
      debugPrint('❌ Error fetching mutuals: $e');
    }
  }

  // ─── Mutators ─────────────────────────────────────────────────────────────

  Future<void> _toggleBookmark() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;
    final authorId = widget.post.author.id;
    setState(() => _isBookmarked = !_isBookmarked);
    try {
      if (_isBookmarked) {
        await Supabase.instance.client.from('saved_profiles').upsert({'user_id': myId, 'saved_user_id': authorId}, onConflict: 'user_id,saved_user_id');
      } else {
        await Supabase.instance.client.from('saved_profiles').delete().eq('user_id', myId).eq('saved_user_id', authorId);
      }
    } catch (e) {
      if (mounted) setState(() => _isBookmarked = !_isBookmarked);
    }
  }

  Future<void> _saveReaction(String? emoji) async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;
    final authorId = widget.post.author.id;
    try {
      if (emoji == null) {
        await Supabase.instance.client.from('pitch_reactions').delete().eq('user_id', myId).eq('target_user_id', authorId);
      } else {
        await Supabase.instance.client.from('pitch_reactions').upsert({'user_id': myId, 'target_user_id': authorId, 'emoji': emoji}, onConflict: 'user_id,target_user_id');
      }
      _loadMetadata();
    } catch (e) {debugPrint('❌ Error saving reaction: $e');}
  }

  Future<void> _toggleMatch() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isMatched = !_isMatched;
      _matchCount += _isMatched ? 1 : -1;
    });
    final result = await SocialService.instance.togglePitchLike(widget.post.author.id);
    if (mounted && result != null) {
      setState(() {
        _isMatched   = result.liked;
        _matchCount  = result.likeCount;
      });
    }
  }

  // ─── Video ────────────────────────────────────────────────────────────────

  void _onTabChanged() {
    if (!mounted || _controller == null) return;
    if (currentMainTabNotifier.value != 0) {
      if (_controller!.value.isPlaying) _controller!.pause();
      if (kIsWeb) _controller!.setVolume(0);
    }
  }

  @override
  void didUpdateWidget(TikTokReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.videoUrl != oldWidget.post.videoUrl && widget.post.videoUrl != null) {
      _hasError = false;
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final url = widget.post.videoUrl;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }
    if (mounted) setState(() { _isInitialized = false; _hasError = false; });

    final preloaded = VideoPreloadManager.instance.getController(url);
    if (preloaded != null) {
      if (_controller != null && !_usesPreloaded) await _controller!.dispose();
      _controller = preloaded;
      _usesPreloaded = true;
      if (mounted) {
        setState(() { _isInitialized = true; _hasError = false; });
        _controller!.play();
      }
      return;
    }

    // Todavía no está listo (recién empezó a precargarse o sigue en curso) —
    // esperamos al MISMO controller vía onReady() en vez de crear uno nuevo
    // para la misma URL: dos VideoPlayerController simultáneos sobre el mismo
    // video colgaban el reproductor en web (doble descarga del archivo).
    VideoPreloadManager.instance.onReady(url, () {
      if (!mounted) return;
      if (VideoPreloadManager.instance.hasError(url)) {
        setState(() => _hasError = true);
        return;
      }
      final ready = VideoPreloadManager.instance.getController(url);
      if (ready == null) return; // evicteado mientras esperábamos
      _controller = ready;
      _usesPreloaded = true;
      setState(() { _isInitialized = true; _hasError = false; });
      _controller!.play();
    });
  }

  void _handleVisibility(VisibilityInfo info) {
    if (!mounted) return;
    final fraction = info.visibleFraction;
    if (fraction > 0.6 && !_metadataLoaded) {
      _metadataLoaded = true;
      _loadMetadata();
    }
    if (!_isInitialized || _controller == null) return;
    // IndexedStack mantiene TODAS las pestañas con el mismo tamaño aunque solo
    // pinte la activa, así que VisibilityDetector puede seguir reportando esta
    // card como "visible" (geométricamente lo es) incluso estando en otra
    // sección — sin este guard, revivía el video justo después de que
    // _onTabChanged lo pausaba (por eso se seguía escuchando en otras pestañas).
    if (currentMainTabNotifier.value != 0) return;
    if (fraction > 0.6) {
      if (!_controller!.value.isPlaying) {
        if (kIsWeb) _controller!.setVolume(1.0);
        _controller!.play();
      }
    } else if (fraction < 0.2) {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        if (kIsWeb) _controller!.setVolume(0);
      }
    }
  }

  void _togglePlayPause() {
    if (!_isInitialized || _controller == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        if (kIsWeb) _controller!.setVolume(0);
      } else {
        if (kIsWeb) _controller!.setVolume(1.0);
        _controller!.play();
      }
    });
  }

  // ─── Stealth / Premium ────────────────────────────────────────────────────

  void _showStealthAlert() async {
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(builder: (_) => const B2BPaywallScreen()),
    );
    if (result == true && mounted) {
      await RevenueCatService.instance.forceRefreshFromSupabase();
      ref.invalidate(currentUserProvider);
      setState(() => _premiumUnlocked = true);
    }
  }

  // ─── Share ────────────────────────────────────────────────────────────────

  void _shareProfile(NexUser author) {
    HapticFeedback.selectionClick();
    final profileUrl = 'https://mploya.ai/u/${author.id}';
    final displayName = author.isConfidential ? 'Perfil Confidencial' : author.name;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Compartir perfil de $displayName'),
        message: Text(profileUrl, style: const TextStyle(fontSize: 12)),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final myId = Supabase.instance.client.auth.currentUser?.id;
                if (myId == null) return;
                await Supabase.instance.client.from('social_reposts').upsert({
                  'user_id': myId,
                  'reposted_user_id': author.id,
                }, onConflict: 'user_id,reposted_user_id');
                if (mounted) {
                  MployaErrorHandler.instance.showSuccess(context, 'Pitch reposteado en tu feed');
                }
              } catch (e) {
                debugPrint('❌ Repost error: $e');
                if (mounted) {
                  MployaErrorHandler.instance.showSuccess(context, 'Pitch compartido');
                }
              }
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.arrow_2_squarepath, size: 18),
                SizedBox(width: 8),
                Text('Repostear en mi feed'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              await Clipboard.setData(ClipboardData(text: profileUrl));
              if (mounted) {
                MployaErrorHandler.instance.showSuccess(context, 'Enlace copiado al portapapeles');
              }
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.link, size: 18),
                SizedBox(width: 8),
                Text('Copiar enlace'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  // ─── Moderation & Comments (delegated) ────────────────────────────────────

  void _showMoreOptions(NexUser author) {
    HapticFeedback.selectionClick();
    showMoreOptions(author);
  }

  void _openCommentsSheet(BuildContext ctx, NexUser author) {
    openReelCommentsSheet(ctx, author, contactInfoChecker: containsContactInfo);
  }

  // ─── Claude AI Match ──────────────────────────────────────────────────────

  Future<void> _analyzeWithClaude(NexUser currentUser, NexUser author) async {
    if (_claudeMatchLoading) return;
    setState(() => _claudeMatchLoading = true);
    try {
      final result = await ClaudeAIService.instance.matchScore(
        candidato: {
          'nombre': currentUser.name,
          'habilidades': currentUser.skills.isNotEmpty ? currentUser.skills : currentUser.tags,
          'experiencia_anios': currentUser.experience.length * 2,
          'ciudad': currentUser.boostTargetCity ?? 'No especificada',
        },
        oferta: {
          'titulo': author.headline,
          'empresa': author.name,
          'habilidades_requeridas': author.skills.isNotEmpty ? author.skills : author.tags,
          'experiencia_minima': 1,
          'ciudad': author.boostTargetCity ?? 'No especificada',
          'descripcion': author.headline,
        },
      );
      if (mounted) setState(() => _claudeMatchResult = result);
    } catch (e) {
      debugPrint('❌ Claude match: $e');
    } finally {
      if (mounted) setState(() => _claudeMatchLoading = false);
    }
  }

  void _showMatchDetails(BuildContext context, NexUser author, int tagScore) {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;
    if (_claudeMatchResult == null && !_claudeMatchLoading) {
      _analyzeWithClaude(currentUser, author);
    }

    showCupertinoModalPopup(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final result = _claudeMatchResult;
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    const Icon(CupertinoIcons.sparkles, color: NexTheme.brandAccent, size: 20),
                    const SizedBox(width: 8),
                    const Text('Análisis de compatibilidad', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('con ${author.name.split(' ').first}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _claudeMatchLoading && result == null
                      ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          CupertinoActivityIndicator(color: NexTheme.brandAccent, radius: 14),
                          SizedBox(height: 16),
                          Text('Claude está analizando...', style: TextStyle(color: Colors.white54, fontSize: 14)),
                        ]))
                      : result == null
                          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(CupertinoIcons.bolt_circle, color: NexTheme.brandAccent, size: 48),
                              const SizedBox(height: 12),
                              const Text('Score rápido', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Text('$tagScore% por etiquetas', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                              const SizedBox(height: 24),
                              CupertinoButton(
                                color: NexTheme.brandAccent,
                                borderRadius: BorderRadius.circular(14),
                                onPressed: () { _analyzeWithClaude(currentUser, author); setModalState(() {}); },
                                child: const Text('Analizar con Claude ✨'),
                              ),
                            ]))
                          : SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  ReelScoreBadge(score: result.score),
                                  const SizedBox(width: 16),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(result.nivel, style: TextStyle(color: nivelColor(result.nivel), fontSize: 20, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(result.recomendacion, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                                  ])),
                                ]),
                                const SizedBox(height: 20),
                                if (result.fortalezas.isNotEmpty) ...[
                                  const ReelSectionTitle(icon: CupertinoIcons.checkmark_seal_fill, label: 'Fortalezas', color: NexTheme.brandAccent),
                                  const SizedBox(height: 8),
                                  ...result.fortalezas.map((f) => ReelBulletItem(text: f, positive: true)),
                                  const SizedBox(height: 16),
                                ],
                                if (result.habilidadesFaltantes.isNotEmpty) ...[
                                  const ReelSectionTitle(icon: CupertinoIcons.xmark_circle_fill, label: 'Habilidades faltantes', color: Color(0xFFFF6B6B)),
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 8, runSpacing: 8, children: result.habilidadesFaltantes.map((s) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.4)),
                                    ),
                                    child: Text(s, style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12, fontWeight: FontWeight.w600)),
                                  )).toList()),
                                  const SizedBox(height: 20),
                                ],
                              ]),
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  int _calculateMatchScore(NexUser? currentUser, NexUser author) {
    if (currentUser == null) return 0;
    if (currentUser.id == author.id) return 100;
    return HashtagMatchService.instance.score(
      myTags: currentUser.tags,
      mySkills: currentUser.skills,
      theirTags: author.tags,
      theirSkills: author.skills,
    );
  }

  void _playReplyVideo() {
    if (_replyVideoUrl == null) return;
    _controller?.pause();
    showCupertinoModalPopup(
      context: context,
      builder: (_) => ReplyVideoModal(videoUrl: _replyVideoUrl!, senderName: _replySenderName ?? 'Empresa'),
    ).then((_) {
      if (mounted && _controller != null && _isInitialized) _controller!.play();
    });
  }

  @override
  void dispose() {
    feedRouteObserver.unsubscribe(this);
    currentMainTabNotifier.removeListener(_onTabChanged);
    if (!_usesPreloaded) _controller?.dispose();
    super.dispose();
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final author = widget.post.author;
    final currentUser = ref.watch(currentUserProvider).value;
    final int matchScore = _calculateMatchScore(currentUser, author);
    
    final bool userIsPremium = (currentUser?.isPremium ?? false) || RevenueCatService.instance.isPremium || _premiumUnlocked;
    final bool isLocked = author.isConfidential && !userIsPremium;
    
    // Compute insight for analytics badge
    final myTags = (currentUser?.tags ?? []).map((t) => t.toLowerCase()).toSet();
    final theirTags = author.tags.map((t) => t.toLowerCase()).toSet();
    final shared = myTags.intersection(theirTags);
    String insightText;
    IconData insightIcon;
    if (shared.isNotEmpty) {
      insightText = shared.take(1).map((t) => t.startsWith('#') ? t : '#$t').join(', ');
      insightIcon = CupertinoIcons.sparkles;
    } else if (author.headline.toLowerCase().contains('senior') || author.headline.toLowerCase().contains('lead')) {
      insightText = 'Senior'; insightIcon = CupertinoIcons.star_fill;
    } else {
      insightText = 'Activo'; insightIcon = CupertinoIcons.bolt_fill;
    }

    // Rail de acciones (reutilizable: overlay en móvil, columna lateral en web).
    final actionsBar = ReelActionsBar(
      author: author,
      currentUser: currentUser,
      isLocked: isLocked,
      connectionStatus: _connectionStatus,
      isMatched: _isMatched,
      matchCount: _matchCount,
      isBookmarked: _isBookmarked,
      nexusSent: _nexusSent,
      showReactions: _showReactions,
      activeReaction: _activeReaction,
      reactionCounts: _reactionCounts,
      lightMode: widget.webMode,
      onAvatarTap: () {
        final me = ref.read(currentUserProvider).value;
        if (author.accountType == 'confidencial' && me?.isPremium != true) {
          Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const B2BPaywallScreen()));
          return;
        }
        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: author)));
      },
      onConnectTap: () async {
        if (_connectionStatus == 'accepted' || _connectionStatus == 'pending') return;
        final me = ref.read(currentUserProvider).value;
        if (author.accountType == 'confidencial' && me?.isPremium != true) {
          Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const B2BPaywallScreen()));
          return;
        }
        HapticFeedback.lightImpact();
        setState(() => _connectionStatus = 'pending');
        await SocialService.instance.sendConnectionRequest(author.id);
      },
      onMatchToggle: _toggleMatch,
      onReactionsToggle: () => setState(() => _showReactions = !_showReactions),
      onReactionSelected: (emoji) {
        setState(() {
          _activeReaction = emoji;
          _showReactions = false;
          if (!_isMatched && emoji != null) _toggleMatch();
        });
        _saveReaction(emoji);
      },
      onCommentsTap: () {
        _controller?.pause();
        Navigator.of(context).push(
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (_) => VideoReplyScreen(targetUser: author),
          ),
        ).then((_) {
          if (mounted && _controller != null && _isInitialized) _controller!.play();
        });
      },
      onBookmarkTap: _toggleBookmark,
      onShareTap: () => _shareProfile(author),
      onNexusTap: () {
        NexusService.instance.sendInterest(author.id).then((err) {
          if (err == null && mounted) setState(() => _nexusSent = true);
        });
      },
      onMoreTap: () => _showMoreOptions(author),
    );

    final stack = Stack(
        fit: StackFit.expand,
        children: [
          // ── Video Background with double-tap heart animation ──
          DoubleTapHeartOverlay(
            onSingleTap: isLocked ? _showStealthAlert : _togglePlayPause,
            enableDoubleTap: !widget.webMode,
            onDoubleTap: () {
              if (isLocked || _nexusSent) return;
              HapticFeedback.heavyImpact();
              NexusService.instance.sendInterest(author.id).then((err) {
                if (err == null && mounted) {
                  setState(() { _nexusSent = true; _showBoltAnimation = true; });
                  Future.delayed(const Duration(milliseconds: 800), () {
                    if (mounted) setState(() => _showBoltAnimation = false);
                  });
                  // Celebración "¡Nuevo Match!" (render #3)
                  MatchCelebrationScreen.show(context, author, matchPct: matchScore > 0 ? matchScore : null);
                }
              });
            },
            child: ReelVideoBackground(
              author: author,
              controller: _controller,
              isInitialized: _isInitialized,
              hasError: _hasError,
            ),
          ),

          // ── Web: capa de tap sobre el video (el <video> HTML no llega al
          //    GestureDetector padre, así que la ponemos explícita encima). ──
          if (kIsWeb)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isLocked ? _showStealthAlert : _togglePlayPause,
              ),
            ),

          // ── Stealth Overlay ──
          if (isLocked)
            ReelStealthOverlay(
              author: author,
              currentUser: currentUser,
              onUnlockTap: _showStealthAlert,
            ),

          // ── Dark Gradient ──
          const ReelBottomGradient(),

          // ── Play/Pause Icon ──
          if (_isInitialized && _controller != null && !_controller!.value.isPlaying && !isLocked)
            const ReelPlayPauseOverlay(),

          // ── Subtitles Overlay (center area, TikTok-style) ──
          Positioned(
            bottom: 200,
            left: 24,
            right: 24,
            child: ReelSubtitleOverlay(
              controller: _controller,
              authorId: author.id,
              isInitialized: _isInitialized,
            ),
          ),

          // ── Info Panel (tarjeta blanca de ancho completo, estilo mockup) ──
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: ReelInfoPanel(
              author: author,
              postContent: widget.post.content,
              isLocked: isLocked,
              mutualConnections: _mutualConnections,
              replyVideoUrl: _replyVideoUrl,
              onPlayReply: _playReplyVideo,
              matchScore: matchScore,
              onMatchTap: () => _showMatchDetails(context, author, matchScore),
            ),
          ),

          // ── Bolt Animation ──
          if (_showBoltAnimation)
            const ReelBoltAnimation(),

          // ── Actions Bar (overlay solo en móvil, sobre el video, por encima
          // de la tarjeta blanca de info; en web va al costado) ──
          if (!widget.webMode)
            Positioned(
              right: 8,
              bottom: 230,
              child: ClipRRect(
                key: widget.isFirstCard ? cmFeedActionsKey : null,
                borderRadius: BorderRadius.circular(NexTheme.radiusXL),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(NexTheme.radiusXL),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                        width: 0.5,
                      ),
                    ),
                    child: actionsBar,
                  ),
                ),
              ),
            ),


          // ── Match Badge (top right, glassmorphism pill) ──
          if (matchScore > 0 && !isLocked)
            Positioned(
              top: 100,
              right: 14,
              child: GestureDetector(
                key: widget.isFirstCard ? cmFeedMatchBadgeKey : null,
                onTap: () => _showMatchDetails(context, author, matchScore),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [NexTheme.brandAccent, NexTheme.brandAccent.withValues(alpha: 0.85)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: NexTheme.brandAccent.withValues(alpha: 0.5),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            '✦ $matchScore% match',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Create Story Button (left of pill) ──
          Positioned(
            top: 100,
            left: 14,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // + Create button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(CupertinoPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => const CreateStoryScreen(),
                    ));
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: NexTheme.brandAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: NexTheme.brandAccent.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.add, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                // Stories pill
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(CupertinoPageRoute(
                      builder: (_) => const StoryViewerScreen(),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 52,
                          height: 24,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              for (var i = 0; i < 3; i++)
                                Positioned(
                                  left: i * 14.0,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: [const Color(0xFF3B82F6), const Color(0xFFEC4899), const Color(0xFF22C55E)][i],
                                      border: Border.all(color: Colors.black, width: 1.5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        ['M', 'A', 'R'][i],
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Historias',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(CupertinoIcons.chevron_right, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
    );

    // ── Web (TikTok web): video redondeado + acciones al costado, sobre blanco ──
    // Margen vertical para que se vean las esquinas redondeadas (si no, el video
    // ocupa todo el alto y las puntas quedan fuera del viewport).
    final content = widget.webMode
        ? Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: stack,
                  ),
                ),
                const SizedBox(width: 14),
                Padding(
                  key: widget.isFirstCard ? cmFeedActionsKey : null,
                  padding: const EdgeInsets.only(bottom: 28),
                  child: actionsBar,
                ),
              ],
            ),
          )
        : stack;

    return VisibilityDetector(
      key: Key('tiktok-${widget.post.id}'),
      onVisibilityChanged: _handleVisibility,
      child: content,
    );
  }

  // ── Badge "EXPERTISE: tag1 · tag2 · tag3" (glassmorphism, top-left) ──
  Widget _expertiseBadge(List<String> tags) {
    final label = tags.take(3).map((t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1)).join('  ·  ');
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: 'EXPERTISE: ',
                style: TextStyle(color: NexTheme.brandAccent, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
              TextSpan(text: label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  // ── Badge "Top Talent" (premium gold gradient, top-right) ──
  Widget _topTalentBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.sparkles, color: Colors.white, size: 12),
          SizedBox(width: 5),
          Text('Top Talent', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

// ── Extracted widgets now live in: ──
// • reel_card_helpers.dart (ScoreBadge, SectionTitle, BulletItem, LiveTranscriptBubble, ReplyVideoModal)
// • reel_card_moderation.dart (Report, Block, Contact info detection)
// • reel_card_comments.dart (Comments sheet)
// • reel_card_video.dart (Video background — no-video, error, loading, playback)
// • reel_card_overlays.dart (Stealth overlay, gradient, play/pause, bolt animation, analytics badges)
// • reel_card_info.dart (Info panel — tags, name, status, mutuals, reply button)
// • reel_card_actions.dart (Right action bar — avatar, connect, reactions, bookmark, share, nexus, more)
