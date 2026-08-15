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
import '../theme/mploya_tokens.dart';
import '../utils/headhunter_candidate_privacy.dart';
import '../screens/profile_screen.dart';
import '../services/coach_mark_service.dart';
import '../services/social_service.dart';
import '../services/video_preload_manager.dart';
import 'reel_card_video.dart';

class PremiumFeedReelCard extends ConsumerStatefulWidget {
  final Post post;
  final bool webMode;
  final bool isFirstCard;

  /// Render aislado (tests y capturas): no abre el video ni consulta el estado
  /// de guardado. En producción es `false` y el comportamiento es el de antes.
  final bool esPreview;
  final String? viewerAccountType;

  const PremiumFeedReelCard({
    super.key,
    required this.post,
    this.webMode = false,
    this.isFirstCard = false,
    this.esPreview = false,
    this.viewerAccountType,
  });

  @override
  ConsumerState<PremiumFeedReelCard> createState() =>
      _PremiumFeedReelCardState();
}

/// Estira [hijo] sólo en los formatos anchos; en mobile lo deja a su tamaño
/// natural, para que el CTA de al lado no quede recortado.
Widget _flexible(bool estirar, Widget hijo) =>
    estirar ? Expanded(child: hijo) : hijo;

/// Fondo violeta del reel mientras el video todavía no está listo para
/// reproducirse. Es el mismo lenguaje visual de la composición aprobada
/// (`cand_inicio_preview.dart` → `_Reel`): degradado violeta oscuro + círculo
/// de play + "Video pitch". Sustituye sólo el negro plano que dejaba el
/// spinner de carga; los estados reales de error y "sin video" de
/// `ReelVideoBackground` —compartido con el feed de talento de Empresa— no
/// se tocan.
Widget _fondoVideoIdle() {
  return const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1B1436), Color(0xFF2E1F63), Color(0xFF0E0A1E)],
      ),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CirculoPlayIdle(),
          SizedBox(height: 14),
          Text(
            'Video pitch',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: Color(0xBFFFFFFF),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CirculoPlayIdle extends StatelessWidget {
  const _CirculoPlayIdle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: const Icon(
        CupertinoIcons.play_fill,
        size: 30,
        color: Colors.white,
      ),
    );
  }
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
    currentMainTabNotifier.addListener(_onTabChanged);
    // En render aislado no hay plugin de video ni sesión: se dibuja la portada
    // del reel sin abrir nada.
    if (widget.esPreview) return;
    _initVideo();
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

  // La composición aprobada no tiene botón de mute visible, así que este
  // método quedó sin disparador en la UI. Se conserva intacto —igual que
  // `_isMuted`, que sigue gobernando el volumen real del controller— por si
  // vuelve a exponerse un control de audio; no es lógica muerta a borrar,
  // es lógica de video que la instrucción pidió no tocar.
  // ignore: unused_element
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
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ProfileScreen(
          user: widget.post.author,
          viewerAccountType: widget.viewerAccountType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final author = widget.post.author;
    // `valueOrNull` y no `value`: con la sesión en error, `value` relanza la
    // excepción y tira abajo el render de la tarjeta entera.
    final currentUser = widget.esPreview
        ? null
        : ref.watch(currentUserProvider).valueOrNull;
    final viewerType =
        (widget.viewerAccountType ?? currentUser?.accountType ?? 'candidato')
            .toLowerCase();
    final seesVacancy = viewerType == 'candidato';
    // Sin match calculado no se dibuja el badge. Antes caía en un 82 % fijo:
    // un número inventado presentado como resultado de la IA.
    final int? matchScore = author.matchPercentage > 0
        ? author.matchPercentage.round()
        : (widget.post.matchPercentage > 0
              ? widget.post.matchPercentage.round()
              : null);
    final location = (author.location ?? '').trim();
    final salary = (author.salaryExpectation ?? '').trim();
    final title = author.headline.isNotEmpty
        ? author.headline
        : (author.isCompanyAct ? 'Oportunidad destacada' : author.name);
    final subtitle = author.isCompanyAct ? author.name : author.headline;
    final detailActionLabel = seesVacancy ? 'Ver vacante' : 'Ver perfil';
    final playing = _controller?.value.isPlaying ?? false;
    // El reel llega a Supabase sin abrir el video en el render aislado
    // (tests, capturas): ahí queda siempre en el fondo violeta de espera.
    final mostrarFondoIdle =
        (author.videoUrl ?? '').isNotEmpty && !_isInitialized && !_hasError;
    final protectedForHeadhunter =
        widget.viewerAccountType?.toLowerCase() == 'headhunter' &&
        isConfidentialAccountType(author.accountType);

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

    // Los cuatro botones de la composición aprobada son Guardar, Match,
    // Comentar y Compartir. Comentar se deja afuera a propósito: no hay
    // ningún conteo real de comentarios en el camino productivo (`Post.
    // comments` no lo llena ninguna consulta), así que mostrarlo sería
    // inventar un dato — la fidelidad visual cede ante "no inventar".
    Widget sideAction({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      String? value,
      bool activo = false,
    }) {
      final tamano = widget.webMode ? 50.0 : 46.0;
      return GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: tamano,
              height: tamano,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activo
                    ? MpTokens.primary
                    : Colors.black.withValues(alpha: 0.30),
                border: activo
                    ? null
                    : Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: widget.webMode ? 23 : 21,
              ),
            ),
            const SizedBox(height: 6),
            if (value != null)
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
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
          child: protectedForHeadhunter
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF14233A), Color(0xFF24476D)],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.lock_shield_fill,
                          size: 54,
                          color: Color(0xFFD6E7F7),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Identidad protegida',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : mostrarFondoIdle
              ? _fondoVideoIdle()
              : ReelVideoBackground(
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
        // Acciones laterales simples: Guardar, Match, Compartir. Sin badges
        // de match ni botón de mute arriba — la composición aprobada no los
        // tiene; el % de match vive sólo en la barra inferior.
        Positioned(
          top: widget.webMode ? 24 : 20,
          right: widget.webMode ? 24 : 14,
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
                icon: _isMatched ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                label: 'Match',
                value: '${_matchCount < 0 ? 0 : _matchCount}',
                onTap: _toggleMatch,
                activo: true,
              ),
              const SizedBox(height: 16),
              sideAction(
                icon: CupertinoIcons.arrowshape_turn_up_right,
                label: 'Compartir',
                onTap: _shareProfile,
              ),
            ],
          ),
        ),
        if (mostrarFondoIdle || protectedForHeadhunter)
          const SizedBox.shrink()
        else if (!_hasError && !_isInitialized)
          const Center(
            child: CupertinoActivityIndicator(radius: 18, color: Colors.white),
          )
        else if (!playing && _isInitialized && !_hasError)
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
        // Información de la vacante: compacta, directo sobre el video —sin
        // caja oscura envolvente—, y la barra de match+CTA como único
        // elemento con superficie propia (blanca), igual que en la
        // composición aprobada.
        Positioned(
          left: widget.webMode ? 28 : 16,
          right: widget.webMode ? 138 : 86,
          bottom: widget.webMode ? 28 : 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: widget.webMode ? 40 : 34,
                    height: widget.webMode ? 40 : 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      author.initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: widget.webMode ? 15 : 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      subtitle.isNotEmpty ? subtitle : author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: widget.webMode ? 14 : 13,
                      ),
                    ),
                  ),
                  if (author.isVerified) ...[
                    const SizedBox(width: 5),
                    const Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      color: Color(0xFF4ADE80),
                      size: 14,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.webMode ? 32 : 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.05,
                ),
              ),
              if (salary.isNotEmpty || location.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (salary.isNotEmpty)
                      glassPill(CupertinoIcons.money_dollar_circle, salary),
                    if (location.isNotEmpty)
                      glassPill(CupertinoIcons.location_solid, location),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              // La fila de acciones se ajusta al ancho REAL de la ficha, no
              // al formato: en desktop el reel se acota a 470 px, así que con
              // las medidas anchas el CTA salía recortado ("Ver v…").
              LayoutBuilder(
                builder: (context, restriccion) {
                  final compacto = restriccion.maxWidth < 340;
                  final alto = compacto ? 58.0 : 72.0;
                  return Row(
                    key: widget.isFirstCard ? cmFeedActionsKey : null,
                    children: [
                      // Sin match calculado la ficha no dibuja el anillo: se
                      // dejaba un porcentaje inventado donde no había dato.
                      if (matchScore != null) ...[
                        _flexible(
                          !compacto,
                          Container(
                            height: alto,
                            padding: EdgeInsets.symmetric(
                              horizontal: compacto ? 11 : 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: compacto ? 36 : 42,
                                  height: compacto ? 36 : 42,
                                  child: CustomPaint(
                                    painter: _ProgressRingPainter(
                                      progress: matchScore / 100,
                                      color: matchScore >= 85
                                          ? const Color(0xFF4ADE80)
                                          : MpTokens.primary,
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
                                if (!compacto) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Match IA',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.black.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ] else
                        const Spacer(),
                      Expanded(
                        child: GestureDetector(
                          onTap: _openProfile,
                          child: Container(
                            height: alto,
                            padding: EdgeInsets.symmetric(
                              horizontal: compacto ? 14 : 26,
                            ),
                            decoration: BoxDecoration(
                              color: MpTokens.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              detailActionLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compacto ? 15 : 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );

    // Mobile va a pantalla completa, sin margen ni esquinas redondeadas: es
    // la superficie principal, no una tarjeta dentro de otra pantalla.
    // Tablet y desktop conservan el tratamiento de tarjeta con borde
    // redondeado de la composición aprobada.
    final llenoCompleto = !widget.webMode;

    return VisibilityDetector(
      key: Key('premium-feed-${widget.post.id}'),
      onVisibilityChanged: _handleVisibility,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (llenoCompleto) {
            return SizedBox(
              height: constraints.maxHeight,
              width: constraints.maxWidth,
              child: overlay,
            );
          }
          return SizedBox(
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            child: Container(
              margin: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(34)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 26,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(34)),
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
