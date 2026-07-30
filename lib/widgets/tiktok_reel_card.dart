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
import '../services/social_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../navigation/main_navigation.dart';
import '../screens/b2b_paywall_screen.dart';
import '../services/revenuecat_service.dart';

import '../services/error_handler.dart';
import '../services/video_preload_manager.dart';
import '../services/claude_ai_service.dart';
import '../services/hashtag_match_service.dart';
import '../services/coach_mark_service.dart';
import 'reel_card_moderation.dart';
import 'reel_card_helpers.dart';
import 'reel_card_video.dart';
import 'reel_card_overlays.dart';

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
    
    // Rediseño 30/7: el video pasa a ser protagonista (llena casi toda la
    // tarjeta) con la info del candidato sobre un degradado inferior, estilo
    // TikTok — antes el video medía 320px fijos dentro de una card centrada
    // con mucho espacio en blanco alrededor, y el nombre/bio iban en una
    // sección blanca aparte debajo. Mismo layout en web y móvil; el paginado
    // (swipe vertical / flechas web) lo maneja el PageView de home_feed_screen.
    final content = _buildLightReelCard(context, author, matchScore, isLocked);

    return VisibilityDetector(
      key: Key('tiktok-${widget.post.id}'),
      onVisibilityChanged: _handleVisibility,
      child: content,
    );
  }

  Widget _buildLightReelCard(BuildContext context, NexUser author, int matchScore, bool isLocked) {
    const brand = Color(0xFF185FA5);
    final playing = _controller?.value.isPlaying ?? false;
    final tags = author.tags.take(3).toList();

    // Heurística de años (misma que usa _analyzeWithClaude para no introducir
    // otra estimación distinta en la misma pantalla).
    final int? years = author.experience.isNotEmpty ? author.experience.length * 2 : null;
    final location = (author.location ?? '').trim();
    final salary = (author.salaryExpectation ?? '').trim();

    void openProfile() => Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => ProfileScreen(user: author)),
        );

    // Botón de acción. Con label ("Me interesa") es el primario y se envuelve
    // en Expanded afuera para ocupar el ancho sobrante; sin label es un
    // cuadrado fijo (44px) para que los íconos secundarios queden uniformes.
    Widget actionBtn(IconData icon, String? label, VoidCallback onTap, {bool filled = false}) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onTap,
        child: Container(
          height: 44,
          width: label == null ? 44 : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? brand : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: filled ? Colors.white : const Color(0xFF475569)),
              if (label != null) ...[
                const SizedBox(width: 7),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: filled ? Colors.white : const Color(0xFF475569))),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // ── Match card: anillo de progreso + % + explicación breve ──
    // Solo se muestra con un match real calculado (>0): mostrar un número
    // inventado cuando no hay coincidencia sería el mismo problema que se
    // corrigió en el matching del backend (un 0% real disfrazado de "90%").
    final matchCard = (matchScore > 0 && !isLocked)
        ? GestureDetector(
            onTap: () => _showMatchDetails(context, author, matchScore),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 3))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CustomPaint(painter: _MatchRingPainter(progress: matchScore / 100, color: brand)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$matchScore% match',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      const Text('Habilidades y experiencia',
                          style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();

    // ── Layout web (rediseño 30/7): video sin overlay de texto (solo el
    // badge de match) + panel derecho persistente con toda la info y las
    // acciones — en vez de repetir el degradado tipo TikTok, que tiene más
    // sentido en móvil que en una pantalla ancha de escritorio. ──
    if (widget.webMode) {
      final videoOnlyWeb = ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isLocked ? _showStealthAlert : _togglePlayPause,
              child: ReelVideoBackground(
                author: author,
                controller: _controller,
                isInitialized: _isInitialized,
                hasError: _hasError,
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isLocked ? _showStealthAlert : _togglePlayPause,
              ),
            ),
            if (isLocked)
              ReelStealthOverlay(
                author: author,
                currentUser: ref.read(currentUserProvider).value,
                onUnlockTap: _showStealthAlert,
              ),
            if (!playing && !isLocked)
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), shape: BoxShape.circle),
                  child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 26),
                ),
              ),
            Positioned(top: 12, left: 12, child: matchCard),
          ],
        ),
      );

      final rightPanel = Container(
        width: 264,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: openProfile,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    ),
                    const SizedBox(width: 5),
                    const Icon(CupertinoIcons.checkmark_seal_fill, size: 15, color: brand),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(author.headline, style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              if (years != null || location.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    [
                      if (years != null) '$years años de experiencia',
                      if (location.isNotEmpty) location,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                ),
              if (author.isOpenToWork)
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Row(
                    children: [
                      _AvailabilityDot(),
                      SizedBox(width: 7),
                      Text('Disponible inmediatamente',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF3B6D11), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              if (salary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(salary, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('HABILIDADES',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Color(0xFF94A3B8))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: const Color(0xFFE6F1FB), borderRadius: BorderRadius.circular(14)),
                            child: Text(t.startsWith('#') ? t : '#$t',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0C447C))),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: actionBtn(_isMatched ? CupertinoIcons.star_fill : CupertinoIcons.star, 'Me interesa',
                    isLocked ? _showStealthAlert : _toggleMatch, filled: _isMatched),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: actionBtn(CupertinoIcons.play_circle, 'Perfil', openProfile)),
                  const SizedBox(width: 8),
                  actionBtn(_isBookmarked ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark, null, _toggleBookmark),
                  const SizedBox(width: 8),
                  actionBtn(CupertinoIcons.arrowshape_turn_up_right, null, () => _shareProfile(author)),
                ],
              ),
            ],
          ),
        ),
      );

      return LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: videoOnlyWeb),
                  const SizedBox(width: 16),
                  rightPanel,
                ],
              ),
            ),
          );
        },
      );
    }

    // ── Pista visual de swipe (decorativa, el gesto real lo maneja el PageView) ──
    const swipeHints = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.chevron_up, color: Color(0xB3FFFFFF), size: 17),
        SizedBox(height: 6),
        _SwipeTrack(),
        SizedBox(height: 6),
        Icon(CupertinoIcons.chevron_down, color: Color(0xB3FFFFFF), size: 17),
      ],
    );

    // ── Info del candidato sobre el degradado inferior del video ──
    final infoOverlay = GestureDetector(
      onTap: openProfile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 14),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0x8C000000), Color(0xE0000000)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(width: 5),
                const Icon(CupertinoIcons.checkmark_seal_fill, size: 16, color: Color(0xFF5DCAA5)),
              ],
            ),
            const SizedBox(height: 2),
            Text(author.headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFFE2E8F0))),
            if (years != null || location.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  [
                    if (years != null) '$years años de experiencia',
                    if (location.isNotEmpty) location,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                ),
              ),
            if (author.isOpenToWork)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF5DCAA5), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('Disponible inmediatamente', style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                  ],
                ),
              ),
            if (salary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(salary, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
              ),
            if (tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                            child: Text(t.startsWith('#') ? t : '#$t',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );

    final videoArea = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isLocked ? _showStealthAlert : _togglePlayPause,
            child: ReelVideoBackground(
              author: author,
              controller: _controller,
              isInitialized: _isInitialized,
              hasError: _hasError,
            ),
          ),
          // Web: el <video> HTML no deja pasar el tap al GestureDetector padre.
          if (kIsWeb)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isLocked ? _showStealthAlert : _togglePlayPause,
              ),
            ),
          // Perfil confidencial/stealth: blur + CTA de desbloqueo. Sin esto el
          // video se veía sin difuminar aunque el tap ya estuviera bloqueado.
          if (isLocked)
            ReelStealthOverlay(
              author: author,
              currentUser: ref.read(currentUserProvider).value,
              onUnlockTap: _showStealthAlert,
            ),
          if (!playing && !isLocked)
            Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 26),
              ),
            ),
          Positioned(top: 12, left: 12, child: matchCard),
          Positioned(right: 10, top: 0, bottom: 74, child: Center(child: swipeHints)),
          Positioned(left: 0, right: 0, bottom: 0, child: infoOverlay),
        ],
      ),
    );

    final footer = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        key: widget.isFirstCard ? cmFeedActionsKey : null,
        children: [
          Expanded(
            child: actionBtn(_isMatched ? CupertinoIcons.star_fill : CupertinoIcons.star, 'Me interesa',
                isLocked ? _showStealthAlert : _toggleMatch, filled: _isMatched),
          ),
          const SizedBox(width: 8),
          // "Ver video completo": el pitch entero + Conectar/Mensaje viven en
          // el perfil, no duplicados acá.
          actionBtn(CupertinoIcons.play_circle, null, openProfile),
          const SizedBox(width: 8),
          actionBtn(_isBookmarked ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark, null, _toggleBookmark),
          const SizedBox(width: 8),
          actionBtn(CupertinoIcons.arrowshape_turn_up_right, null, () => _shareProfile(author)),
        ],
      ),
    );

    final card = Container(
      margin: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Column(
        children: [
          Expanded(child: videoArea),
          footer,
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(height: constraints.maxHeight, width: constraints.maxWidth, child: card);
      },
    );
  }
}

/// Barrita vertical decorativa entre las flechas de swipe (pista de scroll).
class _SwipeTrack extends StatelessWidget {
  const _SwipeTrack();
  @override
  Widget build(BuildContext context) {
    return Container(width: 3, height: 22, decoration: BoxDecoration(color: const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(2)));
  }
}

/// Puntito verde de "disponible" en el panel derecho del layout web.
class _AvailabilityDot extends StatelessWidget {
  const _AvailabilityDot();
  @override
  Widget build(BuildContext context) {
    return Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF639922), shape: BoxShape.circle));
  }
}

/// Anillo de progreso del match, dibujado a mano (sin depender de
/// CircularProgressIndicator, que trae semántica de "cargando").
class _MatchRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _MatchRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final bg = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.5708, progress.clamp(0, 1) * 6.2832, false, fg);
  }

  @override
  bool shouldRepaint(covariant _MatchRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ── Extracted widgets now live in: ──
// • reel_card_helpers.dart (ScoreBadge, SectionTitle, BulletItem, LiveTranscriptBubble, ReplyVideoModal)
// • reel_card_moderation.dart (Report, Block, Contact info detection)
// • reel_card_comments.dart (Comments sheet)
// • reel_card_video.dart (Video background — no-video, error, loading, playback)
// • reel_card_overlays.dart (Stealth overlay, gradient, play/pause, bolt animation, analytics badges)
// • reel_card_info.dart (Info panel — tags, name, status, mutuals, reply button)
// • reel_card_actions.dart (Right action bar — avatar, connect, reactions, bookmark, share, nexus, more)
