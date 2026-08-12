import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../navigation/main_navigation.dart';
import '../screens/ats_dashboard_screen.dart';
import '../screens/chat_inmail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/scheduling_screen.dart';
import '../services/video_preload_manager.dart';
import '../theme/app_theme.dart';
import 'reel_card_video.dart';

class CandidateTalentReelCard extends StatefulWidget {
  final NexUser candidate;
  final bool isActive;
  final bool webMode;
  final String? selectedJobLabel;
  final int? matchPercentage;
  final VoidCallback onSelectJob;

  const CandidateTalentReelCard({
    super.key,
    required this.candidate,
    required this.isActive,
    required this.webMode,
    required this.onSelectJob,
    this.selectedJobLabel,
    this.matchPercentage,
  });

  @override
  State<CandidateTalentReelCard> createState() =>
      _CandidateTalentReelCardState();
}

class _CandidateTalentReelCardState extends State<CandidateTalentReelCard>
    with RouteAware {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _usesPreloaded = false;
  bool _isSaved = false;
  bool _isMuted = false;
  bool _wasPlayingBeforeRoute = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
    _loadSavedState();
    currentMainTabNotifier.addListener(_syncPlayback);
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
  void didUpdateWidget(covariant CandidateTalentReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidate.videoUrl != widget.candidate.videoUrl ||
        oldWidget.candidate.id != widget.candidate.id) {
      _initVideo();
      _loadSavedState();
    } else if (oldWidget.isActive != widget.isActive) {
      _syncPlayback();
    }
  }

  @override
  void dispose() {
    feedRouteObserver.unsubscribe(this);
    currentMainTabNotifier.removeListener(_syncPlayback);
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
    _syncPlayback();
    _wasPlayingBeforeRoute = false;
  }

  Future<void> _initVideo() async {
    final url = widget.candidate.videoUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
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
      if (_controller != null && !_usesPreloaded) {
        await _controller!.dispose();
      }
      _controller = preloaded;
      _usesPreloaded = true;
      if (mounted) {
        setState(() => _isInitialized = true);
        _syncPlayback();
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
      setState(() => _isInitialized = true);
      _syncPlayback();
    });
  }

  void _syncPlayback() {
    if (!mounted || _controller == null || !_isInitialized) return;
    final shouldPlay = widget.isActive && currentMainTabNotifier.value == 0;
    if (shouldPlay) {
      _controller!.setVolume(_isMuted ? 0 : 1);
      _controller!.play();
    } else {
      _controller!.pause();
      _controller!.setVolume(0);
    }
  }

  Future<void> _loadSavedState() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('saved_profiles')
          .select('saved_user_id')
          .eq('user_id', myId)
          .eq('saved_user_id', widget.candidate.id)
          .maybeSingle();
      if (mounted) {
        setState(() => _isSaved = row != null);
      }
    } catch (_) {}
  }

  Future<void> _toggleSaved() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;
    final next = !_isSaved;
    setState(() => _isSaved = next);
    try {
      if (next) {
        await Supabase.instance.client.from('saved_profiles').upsert({
          'user_id': myId,
          'saved_user_id': widget.candidate.id,
        }, onConflict: 'user_id,saved_user_id');
      } else {
        await Supabase.instance.client
            .from('saved_profiles')
            .delete()
            .eq('user_id', myId)
            .eq('saved_user_id', widget.candidate.id);
      }
    } catch (_) {
      if (mounted) setState(() => _isSaved = !next);
    }
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() => _isMuted = !_isMuted);
    _controller!.setVolume(_isMuted ? 0 : 1);
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      _controller!.setVolume(0);
    } else {
      _controller!.setVolume(_isMuted ? 0 : 1);
      _controller!.play();
    }
    setState(() {});
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => ProfileScreen(user: widget.candidate)),
    );
  }

  Future<void> _openChat() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatInmailScreen(targetUser: widget.candidate),
      ),
    );
  }

  Future<void> _openScheduling() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const SchedulingScreen(isCompany: true),
      ),
    );
  }

  Future<void> _openPipeline() async {
    await Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (_) => const AtsDashboardScreen()));
  }

  // AÑOS DE EXPERIENCIA — ELIMINADO el 12/8/2026.
  //
  // Acá se mostraba `experience.length * 2` como "N+ años", o sea: la cantidad
  // de trabajos cargados multiplicada por dos. Alguien con 3 empleos aparecía
  // como "6+ años" sin que ninguna fecha lo respaldara — podía tener veinte
  // años de carrera o tres pasantías de seis meses.
  //
  // NO se reemplazó por otro cálculo porque el modelo no lo permite:
  // `Experience` guarda `duration` como TEXTO LIBRE ("2020 - 2023", "3 años",
  // "Actualidad"), sin fechas estructuradas. Cualquier parseo sería otra
  // estimación disfrazada.
  //
  // También se fue el texto de respaldo "Experiencia validada": nadie valida
  // nada, y afirmarlo era tan falso como el número.
  //
  // Si algún día `Experience` tiene fechas reales, la píldora vuelve — con la
  // cuenta de verdad.

  List<String> _languageTags() {
    final tags = widget.candidate.tags.map((tag) => tag.toLowerCase()).toList();
    final result = <String>[];
    if (tags.any((tag) => tag.contains('ingl'))) result.add('Inglés');
    if (tags.any((tag) => tag.contains('portu'))) result.add('Portugués');
    if (tags.any((tag) => tag.contains('span'))) result.add('Español');
    return result;
  }

  String _availabilityLabel() {
    if (widget.candidate.isOpenToWork) return 'Disponible';
    if (widget.candidate.accountType.toLowerCase().startsWith('confidenc')) {
      return 'Confidencial';
    }
    return 'Perfil activo';
  }

  // MODALIDAD — ELIMINADA el 12/8/2026.
  //
  // Se deducía buscando "remot" / "hibri" / "presen" dentro de `users.tags`, y
  // cuando no encontraba nada devolvía "Flexible" — un valor que el candidato
  // nunca eligió. La modalidad de trabajo pesa demasiado en una decisión de
  // contratación como para inferirla de etiquetas libres.
  //
  // No hay columna de modalidad en `users`: hasta que exista, no se muestra.

  Widget _metaPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF151C31).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _sideAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? value,
    bool highlighted = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: highlighted ? 68 : 56,
            height: highlighted ? 68 : 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: highlighted
                  ? const LinearGradient(
                      colors: [Color(0xFF6C49FF), Color(0xFF4E2FE3)],
                    )
                  : null,
              color: highlighted ? null : Colors.black.withValues(alpha: 0.32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: highlighted
                  ? [
                      BoxShadow(
                        color: NexTheme.brandAccent.withValues(alpha: 0.32),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, color: Colors.white, size: highlighted ? 28 : 22),
          ),
          const SizedBox(height: 8),
          if (value != null)
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
              fontSize: highlighted ? 15 : 12.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _avatarBadge() {
    final avatar = widget.candidate.avatarUrl;
    return Container(
      width: widget.webMode ? 54 : 48,
      height: widget.webMode ? 54 : 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: avatar != null && avatar.isNotEmpty
            ? Image.network(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initialsFallback(),
              )
            : _initialsFallback(),
      ),
    );
  }

  Widget _initialsFallback() {
    return Container(
      color: const Color(0xFF20283E),
      alignment: Alignment.center,
      child: Text(
        widget.candidate.initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: widget.webMode ? 18 : 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playing = _controller?.value.isPlaying ?? false;
    final skills = widget.candidate.skills.take(4).toList();
    final langs = _languageTags();
    final matchLabel = widget.matchPercentage != null
        ? '${widget.matchPercentage}%'
        : 'Match IA';
    final matchSubtitle = widget.matchPercentage != null
        ? 'contra ${widget.selectedJobLabel ?? 'tu vacante'}'
        : 'Elegí vacante';

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlayPause,
          child: ReelVideoBackground(
            author: widget.candidate,
            controller: _controller,
            isInitialized: _isInitialized,
            hasError: _hasError,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.26),
                Colors.black.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.68),
              ],
              stops: const [0, 0.34, 1],
            ),
          ),
        ),
        Positioned(
          top: widget.webMode ? 28 : 18,
          left: widget.webMode ? 28 : 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF121828).withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.sparkles,
                      color: Color(0xFFB5A6FF),
                      size: 14,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Feed talento',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                constraints: BoxConstraints(
                  maxWidth: widget.webMode ? 300 : 240,
                ),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Row(
                  children: [
                    _avatarBadge(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.candidate.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: widget.webMode ? 18 : 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (widget.candidate.isVerified)
                                const Icon(
                                  CupertinoIcons.checkmark_seal_fill,
                                  color: Color(0xFF4ADE80),
                                  size: 16,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.candidate.headline.isNotEmpty
                                ? widget.candidate.headline
                                : 'Talento en video',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 13,
                              height: 1.3,
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
            children: [
              GestureDetector(
                onTap: widget.onSelectJob,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 210),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        matchLabel,
                        style: TextStyle(
                          color: widget.matchPercentage != null
                              ? const Color(0xFF4ADE80)
                              : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: widget.webMode ? 18 : 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        matchSubtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
          top: widget.webMode ? 136 : 122,
          right: widget.webMode ? 28 : 18,
          child: Column(
            children: [
              _sideAction(
                icon: _isSaved
                    ? CupertinoIcons.bookmark_fill
                    : CupertinoIcons.bookmark,
                label: 'Guardar',
                onTap: _toggleSaved,
              ),
              const SizedBox(height: 16),
              _sideAction(
                icon: CupertinoIcons.chat_bubble_text_fill,
                label: 'Contactar',
                onTap: _openChat,
                highlighted: true,
              ),
              const SizedBox(height: 16),
              _sideAction(
                icon: CupertinoIcons.calendar_badge_plus,
                label: 'Invitar',
                onTap: _openScheduling,
              ),
              const SizedBox(height: 16),
              _sideAction(
                icon: CupertinoIcons.person_crop_circle_fill,
                label: 'Perfil',
                onTap: _openProfile,
              ),
            ],
          ),
        ),
        Positioned(
          left: widget.webMode ? 28 : 18,
          right: widget.webMode ? 140 : 98,
          bottom: widget.webMode ? 34 : 26,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if ((widget.candidate.location ?? '').isNotEmpty)
                    _metaPill(
                      CupertinoIcons.location_solid,
                      widget.candidate.location!,
                    ),
                  _metaPill(
                    CupertinoIcons.check_mark_circled_solid,
                    _availabilityLabel(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(
                  maxWidth: widget.webMode ? 760 : 520,
                ),
                padding: EdgeInsets.all(widget.webMode ? 22 : 18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.candidate.headline.isNotEmpty
                          ? widget.candidate.headline
                          : widget.candidate.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.webMode ? 34 : 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.candidate.about?.trim().isNotEmpty == true
                          ? widget.candidate.about!.trim()
                          : 'Video pitch profesional listo para descubrir experiencia, skills y señales de match.',
                      maxLines: widget.webMode ? 3 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 14.5,
                        height: 1.5,
                      ),
                    ),
                    if (skills.isNotEmpty || langs.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final skill in skills) _tagChip(skill),
                          for (final lang in langs) _tagChip(lang),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _openProfile,
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Ver perfil',
                                style: TextStyle(
                                  color: Color(0xFF111827),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _openPipeline,
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF161E33),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Pipeline',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: widget.onSelectJob,
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6B4DFF),
                                    Color(0xFF4A32D8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: NexTheme.brandAccent.withValues(
                                      alpha: 0.30,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                widget.selectedJobLabel == null
                                    ? 'Seleccionar vacante'
                                    : 'Asociar a ${widget.selectedJobLabel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!playing && _isInitialized) ...[
                const SizedBox(height: 14),
                const Text(
                  'Video en pausa · tocá para continuar',
                  style: TextStyle(
                    color: Color(0xFFD4DCF4),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
