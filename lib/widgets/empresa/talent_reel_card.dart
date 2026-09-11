import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../models/models.dart';
import '../../services/coach_mark_service.dart';
import '../../navigation/main_navigation.dart';
import '../../screens/chat_inmail_screen.dart';
import '../../screens/empresa/empresa_candidato_perfil_screen.dart';
import '../../screens/empresa/empresa_pipeline_screen.dart';
import '../../screens/scheduling_screen.dart';
import '../../services/video_preload_manager.dart';
import '../ds/mploya_ds.dart';
import '../reel_card_video.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Reel de UN candidato para el feed de talento de Empresa.
///
/// ADENDA 30/8/2026: el riel de acciones se metía debajo de la barra
/// superior de la pantalla (el anillo de Match pisaba los botones de sonido
/// y menú). Bug de layout concreto y demostrable, reportado con captura. Ver
/// el comentario de `railTop` en build(). Al mover el riel cambian los
/// goldens `empresa_feed_con_vacante.png` / `empresa_feed_sin_vacante.png`
/// (hay que regenerarlos con --update-goldens); el test que verifica que el
/// riel NO se comprime en 393x852 sigue pasando.
///
/// UI reconstruida desde `video pantalla completa candidato.png`
/// (15. Video a Pantalla Completa - Candidato).
///
/// El objeto es el CANDIDATO: acá el usuario es un recruiter. El riel de
/// acciones del mockup es, en orden: Match IA · Guardar · Mensaje · Invitar ·
/// Interesado (relleno violeta = acción principal) · Compartir.
/// No existe "Postularme".
///
/// INVESTIGADO 11/9/2026 — Pedro reportó "los videos faltan" al ver una
/// CAPTURA de este reel. No era un bug: el video carga y reproduce solo bien
/// (confirmado en vivo en el teléfono), pero una captura nunca muestra
/// movimiento, así que un video andando y una foto fija se ven idénticos en
/// una imagen — es una limitación de probar con capturas, no algo que se
/// arregle en la UI. Se evaluó agregar un ícono de video fijo y se descartó:
/// no prueba nada distinto en una captura y el autoplay ya es el
/// comportamiento correcto (el video arranca solo, sin pedir ningún tap).
class TalentReelCard extends StatefulWidget {
  final NexUser candidate;

  /// Es la página visible del PageView.
  final bool isActive;

  /// La pantalla que lo contiene está en primer plano. Se separa de [isActive]
  /// porque el feed puede vivir como pestaña o como ruta empujada.
  final bool screenVisible;

  /// Silencio global del feed, controlado desde la barra superior.
  final bool muted;

  /// Vacante contra la que se calcula el Match. Si es null NO hay porcentaje:
  /// el Match de Empresa es candidato ↔ vacante, nunca un score universal.
  final String? selectedJobTitle;
  final String? selectedJobCompany;
  final String? selectedJobMeta;
  final int? matchPercentage;

  final VoidCallback onSelectJob;
  final VoidCallback? onShortlist;

  /// Primer card del feed embebido: acá se ancla el coach mark que
  /// explica que el Match IA necesita una vacante elegida (29/8/2026).
  final bool isFirstCard;

  const TalentReelCard({
    super.key,
    required this.candidate,
    required this.isActive,
    required this.screenVisible,
    required this.muted,
    required this.onSelectJob,
    this.selectedJobTitle,
    this.selectedJobCompany,
    this.selectedJobMeta,
    this.matchPercentage,
    this.onShortlist,
    this.isFirstCard = false,
  });

  @override
  State<TalentReelCard> createState() => _TalentReelCardState();
}

/// Ícono en placa translúcida para el fondo de respaldo sin video. Mismo
/// lenguaje visual que `_CirculoPlayIdle` del feed de Candidato, sin el
/// triángulo de play (acá no hay nada para reproducir).
class _NoVideoBadge extends StatelessWidget {
  const _NoVideoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0x24FFFFFF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: const Icon(
        CupertinoIcons.videocam,
        size: 28,
        color: Color(0xCCFFFFFF),
      ),
    );
  }
}

class _TalentReelCardState extends State<TalentReelCard> with RouteAware {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _usesPreloaded = false;
  bool _isSaved = false;
  bool _interested = false;
  bool _wasPlayingBeforeRoute = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
    _loadSavedState();
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
  void didUpdateWidget(covariant TalentReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidate.videoUrl != widget.candidate.videoUrl ||
        oldWidget.candidate.id != widget.candidate.id) {
      _initVideo();
      _loadSavedState();
    } else if (oldWidget.isActive != widget.isActive ||
        oldWidget.screenVisible != widget.screenVisible ||
        oldWidget.muted != widget.muted) {
      _syncPlayback();
    }
  }

  @override
  void dispose() {
    feedRouteObserver.unsubscribe(this);
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

  // ── Video ─────────────────────────────────────────────────────────────────

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

  /// Sólo reproduce el candidato visible, y sólo si la pantalla está adelante.
  /// Todo lo demás se pausa y se silencia.
  void _syncPlayback() {
    if (!mounted || _controller == null || !_isInitialized) return;
    if (widget.isActive && widget.screenVisible) {
      _controller!.setVolume(widget.muted ? 0 : 1);
      _controller!.play();
    } else {
      _controller!.pause();
      _controller!.setVolume(0);
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      _controller!.setVolume(0);
    } else {
      _controller!.setVolume(widget.muted ? 0 : 1);
      _controller!.play();
    }
    setState(() {});
  }

  /// Duración del pitch, para la píldora "▶ 0:58" del mockup.
  String? _durationLabel() {
    final duration = _controller?.value.duration;
    if (duration == null || duration.inSeconds <= 0) return null;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // ── Acciones del recruiter ────────────────────────────────────────────────

  Future<void> _loadSavedState() async {
    // El try envuelve también la lectura de `Supabase.instance`: si el cliente
    // todavía no se inicializó, lanza, y acá eso no debe tumbar el reel.
    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      if (myId == null) return;
      final row = await Supabase.instance.client
          .from('saved_profiles')
          .select('saved_user_id')
          .eq('user_id', myId)
          .eq('saved_user_id', widget.candidate.id)
          .maybeSingle();
      if (mounted) setState(() => _isSaved = row != null);
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'talent_reel_card: leer si esta guardado',
        fatal: false,
      );
    }
  }

  Future<void> _toggleSaved() async {
    final next = !_isSaved;
    setState(() => _isSaved = next);
    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      if (myId == null) return;
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

  Future<void> _openProfile() => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => EmpresaCandidatoPerfilScreen(
            candidatoId: widget.candidate.id,
          ),
        ),
      );

  Future<void> _openChat() => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => ChatInmailScreen(targetUser: widget.candidate),
        ),
      );

  Future<void> _openScheduling() => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => const SchedulingScreen(isCompany: true),
        ),
      );

  void _markInterested() {
    setState(() => _interested = !_interested);
    if (widget.onShortlist != null) {
      widget.onShortlist!();
      return;
    }
    // Pipeline de Empresa, no el Kanban legacy: por ahí se llegaba al ATS
    // viejo, que trae datos demo.
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const EmpresaPipelineScreen()),
    );
  }

  Future<void> _share() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(widget.candidate.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openProfile();
            },
            child: const Text('Ver perfil completo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _markInterested();
            },
            child: const Text('Agregar al pipeline'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  // ── Datos derivados ───────────────────────────────────────────────────────

  /// Años de experiencia DERIVADOS de datos reales.
  ///
  /// La versión anterior hacía `experience.length * 2`, o sea inventaba dos
  /// años por puesto. Acá se busca el año más antiguo declarado en las
  /// duraciones ("2020 - 2022") y se cuenta desde ahí. Si no hay ningún año
  /// parseable devuelve null y la línea no se muestra: preferimos no decir nada
  /// antes que decir un número falso.
  int? _experienceYears() {
    var earliest = 9999;
    final yearPattern = RegExp(r'(19|20)\d{2}');

    for (final item in widget.candidate.experience) {
      for (final match in yearPattern.allMatches(item.duration)) {
        final year = int.tryParse(match.group(0)!);
        if (year != null && year < earliest) earliest = year;
      }
    }

    if (earliest == 9999) return null;
    final years = DateTime.now().year - earliest;
    return years > 0 ? years : null;
  }

  String? _availabilityLabel() {
    if (widget.candidate.isOpenToWork) return 'Disponible: Inmediata';
    if (widget.candidate.accountType.toLowerCase().startsWith('confidenc')) {
      return 'Perfil confidencial';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.dark,
      child: GestureDetector(
        onTap: _togglePlayPause,
        behavior: HitTestBehavior.opaque,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Alto real del REEL, que no es el de la pantalla: la barra
            // inferior le resta ~80pt (en un 393x852 el reel mide ~772).
            final alto = constraints.maxHeight;

            // FIX (Pedro, 30/8/2026): la barra superior de la pantalla
            // (volver · Para ti/Explorar · sonido · menú) se dibuja ENCIMA de
            // este card, dentro de un SafeArea, y mide 58pt (42 de botón +
            // 8+8 de padding) más el notch. Acá se reservaba 0 en pantallas
            // altas, así que el riel —alineado abajo, pero más alto que el
            // hueco libre— terminaba metiéndose DEBAJO de esa barra: el
            // anillo de Match ("Elegí vacante" / "Match IA") quedaba pisando
            // los botones de sonido y menú. El golden test no lo detectaba
            // porque monta el card solo, sin la barra de la pantalla.
            final topInset = MediaQuery.of(context).padding.top;
            final railTop = topInset + 66;

            // Separador inferior. El bloque de datos sólo ocupa TODO el ancho
            // en su última fila (la tarjeta de vacante, ~85pt); el resto del
            // texto ya se angosta solo para no cruzarse con el riel. 130
            // despeja esa tarjeta con margen y, al mismo tiempo, le devuelve
            // al riel el alto que ahora se reserva arriba, para que siga
            // entrando a tamaño natural en vez de comprimirse.
            final railBottom =
                alto >= 740 ? 130.0 : (alto >= 620 ? 120.0 : 100.0);

            return Stack(
          fit: StackFit.expand,
          children: [
            // Con video se usa el fondo compartido. Ante error se dibuja un
            // respaldo propio: el del widget compartido centra dos líneas de
            // texto que quedaban PISANDO el nombre del candidato. Fondo
            // degradado (no negro plano) + ícono en placa + una sola línea,
            // todo por encima de donde arranca el bloque de datos.
            if (_hasError)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1B1436),
                      Color(0xFF241A46),
                      MpTokens.darkBg,
                    ],
                  ),
                ),
                child: Align(
                  // Arriba del bloque de datos, no detrás del nombre.
                  alignment: Alignment(0, -0.32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NoVideoBadge(),
                      SizedBox(height: 12),
                      Text(
                        'Sin video pitch todavía',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: Color(0xBFFFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ReelVideoBackground(
                author: widget.candidate,
                controller: _controller,
                isInitialized: _isInitialized,
                hasError: _hasError,
              ),
            // Velo inferior: sin esto el texto blanco no se lee sobre el video.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xF2000000),
                    Color(0xA6000000),
                    Color(0x00000000),
                  ],
                  stops: [0.0, 0.45, 0.82],
                ),
              ),
            ),
            if (!_isInitialized && !_hasError)
              const Center(
                child: CupertinoActivityIndicator(
                  radius: 16,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            // El riel mide ~546pt. En pantallas bajas (iPhone SE 667, teclado
            // abierto, DevTools acoplado abajo) no entraba y se salía por
            // arriba, encimándose con la barra superior.
            //
            // Se le acota el alto REAL disponible y se reduce en bloque con
            // FittedBox: en 852pt sobra espacio, así que no escala nada y la
            // pantalla aprobada queda idéntica. Sólo comprime cuando hace falta,
            // y lo hace de forma uniforme (no achica sólo el texto).
            Positioned(
              right: MpTokens.space12,
              bottom: railBottom,
              top: railTop,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomCenter,
                child: _actionRail(),
              ),
            ),
            // El bloque inferior ocupa todo el ancho; sólo el TEXTO se angosta
            // para no meterse debajo del riel. La tarjeta de vacante va a ancho
            // completo, como en el PNG — así su texto no se corta.
            Positioned(
              left: MpTokens.screenPadding,
              right: MpTokens.screenPadding,
              bottom: MpTokens.space12,
              child: _candidateInfo(),
            ),
          ],
            );
          },
        ),
      ),
    );
  }

  // ── Riel de acciones ──────────────────────────────────────────────────────

  Widget _actionRail() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KeyedSubtree(
          key: widget.isFirstCard ? cmEmpresaFeedMatchKey : null,
          child: _matchIndicator(),
        ),
        const SizedBox(height: 18),
        _railAction(
          icon: _isSaved
              ? CupertinoIcons.bookmark_fill
              : CupertinoIcons.bookmark,
          label: 'Guardar',
          active: _isSaved,
          onTap: _toggleSaved,
        ),
        const SizedBox(height: 18),
        _railAction(
          icon: CupertinoIcons.chat_bubble_text,
          label: 'Mensaje',
          onTap: _openChat,
        ),
        const SizedBox(height: 18),
        _railAction(
          icon: CupertinoIcons.calendar,
          label: 'Invitar',
          onTap: _openScheduling,
        ),
        const SizedBox(height: 18),
        // Acción principal del recruiter: relleno violeta en el mockup.
        _railAction(
          icon: CupertinoIcons.hand_thumbsup_fill,
          label: 'Interesado',
          solid: true,
          onTap: _markInterested,
        ),
        const SizedBox(height: 18),
        _railAction(
          icon: CupertinoIcons.arrowshape_turn_up_right,
          label: 'Compartir',
          onTap: _share,
        ),
      ],
    );
  }

  /// Anillo de Match. Sin vacante seleccionada NO hay porcentaje: se invita a
  /// elegir vacante, porque el Match de Empresa es contra una vacante.
  Widget _matchIndicator() {
    final match = widget.matchPercentage;

    return GestureDetector(
      onTap: widget.onSelectJob,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Disco oscuro bajo el anillo, como en el mockup.
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: Color(0xCC0A0A12),
                    shape: BoxShape.circle,
                  ),
                ),
                if (match != null)
                  MpProgressRing(
                    value: match / 100,
                    size: 58,
                    stroke: 4.5,
                    color: MpTokens.primaryLight,
                    center: Text(
                      '$match%',
                      style: MpTokens.label.copyWith(
                        color: const Color(0xFFFFFFFF),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  const Icon(
                    CupertinoIcons.sparkles,
                    size: 25,
                    color: Color(0xFFFFFFFF),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: 78,
            child: Text(
              match != null ? 'Match IA' : 'Elegí vacante',
              textAlign: TextAlign.center,
              style: MpTokens.micro.copyWith(
                color: const Color(0xFFFFFFFF),
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _railAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool solid = false,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: solid
                  ? MpTokens.primary
                  : (active ? const Color(0xCC2A2A38) : const Color(0xB31A1A22)),
              shape: BoxShape.circle,
              boxShadow: solid ? MpTokens.glow(MpTokens.primary) : null,
            ),
            child: Icon(icon, size: 24, color: const Color(0xFFFFFFFF)),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: 78,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MpTokens.micro.copyWith(
                color: const Color(0xFFFFFFFF),
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Información del candidato ─────────────────────────────────────────────

  Widget _candidateInfo() {
    const white = Color(0xFFFFFFFF);
    final candidate = widget.candidate;
    final years = _experienceYears();
    final skills = candidate.tags.take(4).toList();
    final extra = candidate.tags.length - skills.length;
    final availability = _availabilityLabel();
    final duration = _durationLabel();

    // Reserva para el riel de acciones: 54 del botón + 12 de margen + aire.
    const railInset = 78.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: railInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
        GestureDetector(
          onTap: _openProfile,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  candidate.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.h1.copyWith(
                    color: white,
                    fontSize: 24,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              if (candidate.isVerified) ...[
                const SizedBox(width: 7),
                const MpVerifiedBadge(size: 18, color: MpTokens.primaryLight),
              ],
            ],
          ),
        ),
        if (candidate.headline.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            candidate.headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MpTokens.bodyStrong.copyWith(
              color: MpTokens.primaryLight,
              fontSize: 15.5,
            ),
          ),
        ],
        const SizedBox(height: 9),
        // Sin separador "·": cuando la meta pasa a dos líneas el punto quedaba
        // colgando al final de la primera. El espaciado ya separa los datos.
        Wrap(
          spacing: 14,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (candidate.location?.isNotEmpty ?? false)
              _meta(CupertinoIcons.placemark, candidate.location!),
            if (years != null)
              _meta(CupertinoIcons.briefcase, '$years años exp.'),
          ],
        ),
        if (availability != null) ...[
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.bolt_fill,
                size: 15,
                color: Color(0xFF3DDC84),
              ),
              const SizedBox(width: 5),
              Text(
                availability,
                style: MpTokens.bodyStrong.copyWith(
                  color: const Color(0xFF3DDC84),
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ],
        if (skills.isNotEmpty) ...[
          const SizedBox(height: 11),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final skill in skills) _skillChip(skill),
              if (extra > 0) _skillChip('+$extra'),
            ],
          ),
        ],
        if (candidate.about?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          _quote(candidate.about!),
        ],
        if (duration != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xB31A1A22),
                  borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.play_fill,
                      size: 12,
                      color: white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      duration,
                      style: MpTokens.micro.copyWith(color: white, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Video Pitch',
                style: MpTokens.micro.copyWith(
                  color: const Color(0xB3FFFFFF),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _jobContextCard(),
      ],
    );
  }

  Widget _meta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xE6FFFFFF)),
        const SizedBox(width: 5),
        Text(
          label,
          style: MpTokens.body.copyWith(
            color: const Color(0xE6FFFFFF),
            fontSize: 14.5,
          ),
        ),
      ],
    );
  }

  /// Cita del pitch con las comillas decorativas del mockup.
  Widget _quote(String text) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 22, right: 18),
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: MpTokens.body.copyWith(
              color: const Color(0xFFFFFFFF),
              fontSize: 14.5,
              height: 1.42,
            ),
          ),
        ),
        const Positioned(
          left: 0,
          top: -4,
          child: Text(
            '“',
            style: TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _skillChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xA61A1A22),
        borderRadius: BorderRadius.circular(MpTokens.radiusPill),
      ),
      child: Text(
        label,
        style: MpTokens.micro.copyWith(
          color: const Color(0xFFFFFFFF),
          fontSize: 13,
        ),
      ),
    );
  }

  /// Tarjeta de contexto: contra qué vacante se mira a este candidato.
  ///
  /// El mockup pone acá un botón violeta "Ver vacante". Como la Empresa no está
  /// buscando trabajo, el botón hace la acción del recruiter: elegir o cambiar
  /// la vacante contra la que se calcula el Match.
  Widget _jobContextCard() {
    final hasJob = widget.selectedJobTitle != null;
    const white = Color(0xFFFFFFFF);

    return GestureDetector(
      onTap: widget.onSelectJob,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xB3121218),
          borderRadius: BorderRadius.circular(MpTokens.radiusLG),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Row(
          children: [
            // Con nombre de empresa real se usa su monograma; sin él va un
            // ícono, no un monograma sacado del título de la vacante.
            if (widget.selectedJobCompany != null)
              MpCompanyLogo(
                name: widget.selectedJobCompany!,
                color: const Color(0xFF16161E),
                size: 48,
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: hasJob
                      ? const Color(0xFF16161E)
                      : MpTokens.primary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(MpTokens.radiusMD),
                ),
                child: Icon(
                  hasJob ? CupertinoIcons.briefcase_fill : CupertinoIcons.add,
                  size: 22,
                  color: hasJob ? white : MpTokens.primaryLight,
                ),
              ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasJob ? widget.selectedJobTitle! : 'Seleccionar vacante',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.title.copyWith(color: white, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  if (hasJob && widget.selectedJobCompany != null)
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.selectedJobCompany!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MpTokens.micro.copyWith(
                              color: white,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const MpVerifiedBadge(
                          size: 12,
                          color: MpTokens.primaryLight,
                        ),
                      ],
                    ),
                  if (widget.selectedJobMeta != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.briefcase,
                          size: 11,
                          color: Color(0x99FFFFFF),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.selectedJobMeta!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MpTokens.micro.copyWith(
                              color: const Color(0x99FFFFFF),
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!hasJob)
                    // Dos líneas: la frase completa no entra en una sola en
                    // 393pt y antes quedaba en "…para calcu…".
                    Text(
                      'Elegí una vacante para calcular el Match',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MpTokens.micro.copyWith(
                        color: const Color(0x99FFFFFF),
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: MpTokens.primary,
                borderRadius: BorderRadius.circular(MpTokens.radiusMD),
              ),
              child: Text(
                hasJob ? 'Cambiar' : 'Elegir',
                style: MpTokens.label.copyWith(
                  color: white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
