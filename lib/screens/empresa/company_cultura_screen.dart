import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../services/company_culture_service.dart';
import '../../widgets/ds/mploya_ds.dart';
import 'empresa_cultura_editor_screen.dart' show iconForCultureValorKey;

/// Vista pública de "Cultura de la Empresa" (Pantalla 40) — la ve cualquier
/// candidato desde el Perfil de Empresa.
///
/// Construida el 29/8/2026 junto con el editor
/// (`empresa_cultura_editor_screen.dart`) y la migración
/// `046_company_culture.sql`, a pedido de Pedro. El poster + reproductor a
/// pantalla completa reutiliza el MISMO patrón que `_CompanyVideoPoster` /
/// `_CompanyVideoPlayerPage` de `empresa_perfil_screen.dart` (pantalla
/// CONGELADA, no se toca) — son privadas a ese archivo, así que acá se
/// declaran de nuevo en vez de exportarlas, para no tocar una pantalla
/// congelada por un cambio ajeno a ella.
///
/// Sin contenido de muestra: si la empresa no cargó nada todavía, se ve un
/// estado vacío real, nunca un video o una historia inventada.
class CompanyCulturaScreen extends StatefulWidget {
  final String companyUserId;
  final String companyName;

  /// Datos ya resueltos, para golden tests.
  final CompanyCulture? previewCulture;
  final List<CompanyCultureStory>? previewStories;

  const CompanyCulturaScreen({
    super.key,
    required this.companyUserId,
    required this.companyName,
    this.previewCulture,
    this.previewStories,
  });

  @override
  State<CompanyCulturaScreen> createState() => _CompanyCulturaScreenState();
}

class _CompanyCulturaScreenState extends State<CompanyCulturaScreen> {
  bool _cargando = true;
  CompanyCulture? _culture;
  List<CompanyCultureStory> _historias = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (widget.previewCulture != null || widget.previewStories != null) {
      _culture = widget.previewCulture;
      _historias = widget.previewStories ?? const [];
      setState(() => _cargando = false);
      return;
    }
    final culture =
        await CompanyCultureService.instance.getCultureFor(widget.companyUserId);
    final historias =
        await CompanyCultureService.instance.getStoriesFor(widget.companyUserId);
    if (!mounted) return;
    setState(() {
      _culture = culture;
      _historias = historias;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: Builder(
        builder: (context) {
          final s = context.mp;
          return CupertinoPageScaffold(
            backgroundColor: s.bg,
            navigationBar: CupertinoNavigationBar(
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).maybePop(),
                child: Icon(CupertinoIcons.chevron_back, color: s.text),
              ),
              middle: Text('Cultura de la empresa', style: TextStyle(color: s.text)),
              backgroundColor: s.bg,
              border: null,
            ),
            child: SafeArea(
              child: _cargando
                  ? const Center(child: CupertinoActivityIndicator())
                  : _body(context),
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context) {
    final culture = _culture;
    final tieneAlgo = (culture?.tieneContenido ?? false) || _historias.isNotEmpty;

    if (!tieneAlgo) {
      return MpEmptyState(
        icon: CupertinoIcons.building_2_fill,
        title: 'Todavía no hay nada cargado',
        message:
            '${widget.companyName} todavía no subió su video institucional ni contó su cultura.',
      );
    }

    final s = context.mp;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space16,
        MpTokens.screenPadding,
        MpTokens.space32,
      ),
      children: [
        if (culture?.tieneVideo ?? false) ...[
          _CompanyCultureVideoPoster(
            videoUrl: culture!.introVideoUrl!,
            label: 'Video institucional',
          ),
          const SizedBox(height: MpTokens.space24),
        ],
        if (culture != null &&
            (culture.foundedYear != null ||
                culture.employeeCount != null ||
                culture.growthPercentage != null)) ...[
          Row(
            children: [
              if (culture.foundedYear != null)
                Expanded(
                  child: MpStatTile(
                    icon: CupertinoIcons.flag_fill,
                    color: MpTokens.catBlue,
                    value: '${culture.foundedYear}',
                    label: 'Fundada',
                    compact: true,
                  ),
                ),
              if (culture.foundedYear != null &&
                  (culture.employeeCount != null || culture.growthPercentage != null))
                const SizedBox(width: MpTokens.space8),
              if (culture.employeeCount != null)
                Expanded(
                  child: MpStatTile(
                    icon: CupertinoIcons.person_3_fill,
                    color: MpTokens.catGreen,
                    value: '${culture.employeeCount}',
                    label: 'Empleados',
                    compact: true,
                  ),
                ),
              if (culture.employeeCount != null && culture.growthPercentage != null)
                const SizedBox(width: MpTokens.space8),
              if (culture.growthPercentage != null)
                Expanded(
                  child: MpStatTile(
                    icon: CupertinoIcons.chart_bar_alt_fill,
                    color: MpTokens.catOrange,
                    value: '${culture.growthPercentage!.toStringAsFixed(0)}%',
                    label: 'Crecimiento anual',
                    compact: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: MpTokens.space24),
        ],
        if (culture != null && culture.valores.isNotEmpty) ...[
          MpSectionHeader(title: 'Nuestros valores'),
          const SizedBox(height: MpTokens.space12),
          Wrap(
            spacing: MpTokens.space12,
            runSpacing: MpTokens.space12,
            children: [
              for (final v in culture.valores)
                SizedBox(
                  width: (MediaQuery.of(context).size.width -
                          (MpTokens.screenPadding * 2) -
                          MpTokens.space12) /
                      2,
                  child: MpCard(
                    // Achicada a pedido de Pedro (29/8/2026): con la tarjeta
                    // de video ya reducida, esta quedaba desproporcionada —
                    // ícono más chico y menos padding, en vez del tamaño por
                    // defecto de MpCard/MpIconTile.
                    padding: const EdgeInsets.all(MpTokens.space12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MpIconTile(
                          icon: iconForCultureValorKey(v.iconKey),
                          color: s.accent,
                          size: 32,
                        ),
                        const SizedBox(height: MpTokens.space8),
                        Text(
                          v.titulo,
                          style: MpTokens.title.copyWith(color: s.text, fontSize: 14),
                        ),
                        if (v.descripcion.isNotEmpty) ...[
                          const SizedBox(height: MpTokens.space4),
                          Text(
                            v.descripcion,
                            style: MpTokens.caption.copyWith(color: s.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: MpTokens.space24),
        ],
        if (_historias.isNotEmpty) ...[
          MpSectionHeader(
            title: 'El equipo cuenta cómo es trabajar acá',
          ),
          const SizedBox(height: MpTokens.space12),
          for (final h in _historias) ...[
            _HistoriaCard(historia: h),
            const SizedBox(height: MpTokens.space12),
          ],
        ],
      ],
    );
  }
}

class _HistoriaCard extends StatelessWidget {
  final CompanyCultureStory historia;

  const _HistoriaCard({required this.historia});

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    return MpCard(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => _CompanyCultureVideoPlayerPage(videoUrl: historia.videoUrl),
        ),
      ),
      child: Row(
        children: [
          const MpIconTile(
            icon: CupertinoIcons.play_circle_fill,
            color: MpTokens.catGreen,
            size: 44,
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  historia.memberName,
                  style: MpTokens.title.copyWith(color: s.text, fontSize: 15),
                ),
                if (historia.memberRole != null)
                  Text(
                    historia.memberRole!,
                    style: MpTokens.caption.copyWith(color: s.textSecondary),
                  ),
                if (historia.quote != null) ...[
                  const SizedBox(height: MpTokens.space4),
                  Text(
                    '"${historia.quote}"',
                    style: MpTokens.caption.copyWith(
                      color: s.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Caché en memoria del proceso: mismo patrón que
/// `HeadhunterCandidateThumb` — si esta pantalla se reconstruye no vuelve a
/// pedir el frame de nuevo.
final _cultureThumbCache = <String, Uint8List?>{};

/// Poster del video institucional. Muestra un frame REAL extraído del
/// video (vía `video_thumbnail`, un canal nativo — no descarga el video
/// completo) en vez de un fondo genérico, para que se vea la cara o las
/// instalaciones sin tocar play. A pedido de Pedro, 29/8/2026.
///
/// Sólo en móvil: `video_thumbnail` no tiene implementación web. Si falla
/// la extracción o estamos en Flutter Web, cae al fondo degradado con el
/// ícono de play — mismo comportamiento que tenía antes, no una regresión.
class _CompanyCultureVideoPoster extends StatefulWidget {
  final String videoUrl;
  final String label;

  const _CompanyCultureVideoPoster({required this.videoUrl, required this.label});

  @override
  State<_CompanyCultureVideoPoster> createState() => _CompanyCultureVideoPosterState();
}

class _CompanyCultureVideoPosterState extends State<_CompanyCultureVideoPoster> {
  Uint8List? _frame;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _CompanyCultureVideoPoster old) {
    super.didUpdateWidget(old);
    if (old.videoUrl != widget.videoUrl) {
      _frame = null;
      _load();
    }
  }

  Future<void> _load() async {
    final url = widget.videoUrl;
    if (kIsWeb || url.isEmpty) return;
    if (_cultureThumbCache.containsKey(url)) {
      if (mounted) setState(() => _frame = _cultureThumbCache[url]);
      return;
    }
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: url,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        quality: 70,
      );
      _cultureThumbCache[url] = data;
      if (!mounted) return;
      setState(() => _frame = data);
    } catch (_) {
      _cultureThumbCache[url] = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;

    // A pedido de Pedro (29/8/2026, aclarado en dos vueltas): el recorte a
    // la mitad es del ANCHO (mitad horizontal), no de la altura — la altura
    // queda como la original (208). Por eso el poster ya no ocupa todo el
    // ancho de pantalla: se calcula a la mitad, igual que las tarjetas de
    // "Nuestros valores", y se alinea a la izquierda en vez de estirarse.
    final anchoMitad =
        (MediaQuery.of(context).size.width - (MpTokens.screenPadding * 2) - MpTokens.space12) / 2;

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => _CompanyCultureVideoPlayerPage(videoUrl: widget.videoUrl),
          ),
        ),
        child: Container(
          height: 208,
          width: anchoMitad,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(MpTokens.radiusLG)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B1436), Color(0xFF2E1F63), Color(0xFF0E0A1E)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (frame != null) ...[
                Image.memory(frame, fit: BoxFit.cover),
                Container(color: const Color(0x4D000000)),
              ],
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x40FFFFFF)),
                      ),
                      child: const Icon(
                        CupertinoIcons.play_fill,
                        size: 26,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.label,
                      style: MpTokens.label.copyWith(
                        color: const Color(0xE6FFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reproductor a pantalla completa — mismo patrón que
/// `_CompanyVideoPlayerPage` de `empresa_perfil_screen.dart`.
class _CompanyCultureVideoPlayerPage extends StatefulWidget {
  final String videoUrl;

  const _CompanyCultureVideoPlayerPage({required this.videoUrl});

  @override
  State<_CompanyCultureVideoPlayerPage> createState() =>
      _CompanyCultureVideoPlayerPageState();
}

class _CompanyCultureVideoPlayerPageState
    extends State<_CompanyCultureVideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller = controller;
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
          controller.play();
        })
        .catchError((_) {
          if (mounted) setState(() => _hasError = true);
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return CupertinoPageScaffold(
      backgroundColor: MpTokens.darkBg,
      child: Stack(
        children: [
          Center(
            child: _hasError
                ? Text(
                    'No pudimos cargar el video.',
                    style: MpTokens.body.copyWith(color: const Color(0xFFFFFFFF)),
                  )
                : !ready
                    ? const CupertinoActivityIndicator(radius: 15, color: Color(0xFFFFFFFF))
                    : GestureDetector(
                        onTap: () => setState(() {
                          controller.value.isPlaying ? controller.pause() : controller.play();
                        }),
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                      ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + MpTokens.space8,
            left: MpTokens.screenPadding,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0x66000810),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.xmark, size: 18, color: Color(0xFFFFFFFF)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
