import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../widgets/ds/mploya_ds.dart';
import '../../services/my_profile_service.dart';
import '../camera_screen.dart';

/// Video pitch de Headhunter.
///
/// Migrada al sistema de diseño (18/8/2026), 8ª pantalla — mismo patrón de
/// `headhunter_dashboard_screen.dart`. Ya tenía `MpSurface(style: light)`
/// desde antes de este trabajo (era la única con algo de adopción), pero
/// nada más: 0 widgets de `ds/`, todo el resto hardcodeado.
///
/// Además de los tokens, esta migración corrige el mismo bug de threading
/// de contexto documentado en `headhunter_interview_report_screen.dart`
/// (`context.mp` con el `context` implícito del State nunca encuentra el
/// `MpSurface` local) — acá era invisible por ser `.light`, pero se
/// corrigió igual para no repetir el patrón incorrecto en código nuevo.
///
/// Patrón:
///   · Tarjeta de video → mismo `Container` con `MpTokens.heroGradient` +
///     `MpTokens.glow` que la tarjeta de candidato de Interview Flow (no
///     es `MpHeroBand`, esto no es una banda de métricas).
///   · Botones sobre la tarjeta oscura → [MpButton] variant `neutral`
///     (píldora blanca, texto oscuro — contraste correcto sobre el
///     degradado violeta, más allá de que la pantalla en sí sea clara) y
///     `ghost` con `color` blanco para la acción secundaria.
///   · Tarjeta de consejos → [MpCard], checklist a mano (no hay widget de
///     ds/ para "lista con check" fuera de [MpCard] simple).
///
/// STRINGS FIJOS verificados por `headhunter_polish_6_test.dart`: 'Tu
/// video está publicado', 'Ver video', 'Todavía no cargaste un video',
/// 'Grabar video', 'No pudimos leer tu video'.
class HeadhunterVideoPitchData {
  const HeadhunterVideoPitchData({this.videoUrl, this.error = false});

  final String? videoUrl;
  final bool error;

  bool get hasVideo => videoUrl?.isNotEmpty == true;
}

class HeadhunterVideoPitchScreen extends StatefulWidget {
  const HeadhunterVideoPitchScreen({
    super.key,
    this.previewData,
    this.loadOverride,
  });

  final HeadhunterVideoPitchData? previewData;
  final Future<HeadhunterVideoPitchData> Function()? loadOverride;

  @override
  State<HeadhunterVideoPitchScreen> createState() =>
      _HeadhunterVideoPitchScreenState();
}

class _HeadhunterVideoPitchScreenState
    extends State<HeadhunterVideoPitchScreen> {
  HeadhunterVideoPitchData _data = const HeadhunterVideoPitchData();
  bool _loading = true;
  bool _removing = false;
  String? _message;

  static const _tips = [
    'Presentate y contá tu experiencia como headhunter.',
    'Explicá en qué perfiles e industrias te especializás.',
    'Contá qué tipo de clientes acompañás.',
    'Mostrá tu metodología y propuesta de valor.',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.previewData case final data?) {
      _data = data;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.previewData != null) return;
    if (mounted) setState(() => _loading = true);
    if (widget.loadOverride != null) {
      final data = await widget.loadOverride!();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      return;
    }
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    try {
      if (uid == null) throw StateError('Sin sesión');
      final row = await loadMyProfile(client: client);
      final url = row?['video_url']?.toString().trim() ?? '';
      if (!mounted) return;
      setState(() {
        _data = HeadhunterVideoPitchData(videoUrl: url.isEmpty ? null : url);
        _loading = false;
      });
    } catch (error) {
      debugPrint('Headhunter video pitch: $error');
      if (!mounted) return;
      setState(() {
        _data = const HeadhunterVideoPitchData(error: true);
        _loading = false;
      });
    }
  }

  Future<void> _record() async {
    if (widget.previewData != null) return;
    await Navigator.of(
      context,
    ).push<bool>(CupertinoPageRoute(builder: (_) => const CameraScreen()));
    await _load();
  }

  Future<void> _remove() async {
    if (widget.previewData != null || _removing) return;
    setState(() {
      _removing = true;
      _message = null;
    });
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw StateError('Sin sesión');
      await setMyProfileVideo(
        videoUrl: null,
        completeOnboarding: false,
        client: client,
      );
      await _load();
    } catch (error) {
      debugPrint('Headhunter video pitch remove: $error');
      if (mounted) _message = 'No pudimos quitar el video. Probá de nuevo.';
    } finally {
      if (mounted) setState(() => _removing = false);
    }
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
              middle: const Text('Video pitch personal'),
              previousPageTitle: 'Perfil',
              backgroundColor: s.card,
              border: null,
              trailing: _data.hasVideo && !_loading
                  ? CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _remove,
                      child: _removing
                          ? const CupertinoActivityIndicator()
                          : const Icon(CupertinoIcons.trash, size: 20),
                    )
                  : null,
            ),
            child: SafeArea(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator(radius: 15))
                  : _body(context),
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context) {
    final s = context.mp;
    if (_data.error) {
      return _state(
        context,
        CupertinoIcons.exclamationmark_triangle,
        'No pudimos leer tu video',
        'Revisá tu conexión y volvé a intentar.',
        action: 'Reintentar',
        onAction: _load,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space20,
        MpTokens.screenPadding,
        MpTokens.space32,
      ),
      children: [
        Text(
          'Tu carta de presentación',
          style: MpTokens.h1.copyWith(color: s.text, fontSize: 28),
        ),
        const SizedBox(height: MpTokens.space8),
        Text(
          'Contá quién sos, qué talento buscás y qué valor aportás a tus clientes.',
          style: MpTokens.body.copyWith(color: s.textSecondary, height: 1.45),
        ),
        const SizedBox(height: MpTokens.space20),
        _videoCard(),
        if (_message != null) ...[
          const SizedBox(height: MpTokens.space12),
          Text(_message!, style: const TextStyle(color: MpTokens.danger)),
        ],
        const SizedBox(height: MpTokens.space16),
        MpCard(
          radius: MpTokens.radiusXXL,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Consejos para tu video (60 seg.)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MpTokens.primary,
                ),
              ),
              const SizedBox(height: MpTokens.space12),
              for (final tip in _tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: MpTokens.space12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        size: 17,
                        color: MpTokens.primaryLight,
                      ),
                      const SizedBox(width: MpTokens.space8),
                      Expanded(
                        child: Text(
                          tip,
                          style: TextStyle(color: s.text, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _videoCard() {
    final hasVideo = _data.hasVideo;
    return Container(
      padding: const EdgeInsets.all(MpTokens.space20),
      decoration: BoxDecoration(
        gradient: MpTokens.heroGradient,
        borderRadius: BorderRadius.circular(MpTokens.radiusXXL),
        boxShadow: MpTokens.glow(MpTokens.primary),
      ),
      child: Column(
        children: [
          Icon(
            hasVideo ? CupertinoIcons.play_circle_fill : CupertinoIcons.videocam,
            size: 58,
            color: const Color(0xFFFFFFFF),
          ),
          const SizedBox(height: MpTokens.space12),
          Text(
            hasVideo ? 'Tu video está publicado' : 'Todavía no cargaste un video',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: MpTokens.space8),
          Text(
            hasVideo
                ? 'Se muestra en tu perfil profesional.'
                : 'Podés grabarlo con la cámara y publicarlo en tu perfil.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFCDC6E8), height: 1.35),
          ),
          const SizedBox(height: MpTokens.space16),
          MpButton(
            label: hasVideo ? 'Ver video' : 'Grabar video',
            variant: MpButtonVariant.neutral,
            onPressed: hasVideo
                ? () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => _VideoPlayerPage(videoUrl: _data.videoUrl!),
                    ),
                  )
                : _record,
          ),
          if (hasVideo) ...[
            const SizedBox(height: MpTokens.space4),
            MpButton(
              label: 'Grabar uno nuevo',
              variant: MpButtonVariant.ghost,
              color: const Color(0xFFFFFFFF),
              onPressed: _record,
            ),
          ],
        ],
      ),
    );
  }

  Widget _state(
    BuildContext context,
    IconData icon,
    String title,
    String message, {
    String? action,
    VoidCallback? onAction,
  }) {
    final s = context.mp;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MpTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: MpTokens.primaryLight),
            const SizedBox(height: MpTokens.space16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: s.text, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: MpTokens.space8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: s.textSecondary)),
            if (action != null)
              CupertinoButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

class _VideoPlayerPage extends StatefulWidget {
  const _VideoPlayerPage({required this.videoUrl});
  final String videoUrl;

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    _controller = controller;
    controller
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((_) {
          if (mounted) setState(() => _error = true);
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
    final ready = controller?.value.isInitialized == true;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Video pitch'),
        backgroundColor: CupertinoColors.black,
      ),
      child: Center(
        child: _error
            ? const Text(
                'No pudimos reproducir el video.',
                style: TextStyle(color: CupertinoColors.white),
              )
            : !ready
            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
            : GestureDetector(
                onTap: () => setState(
                  () => controller.value.isPlaying
                      ? controller.pause()
                      : controller.play(),
                ),
                child: AspectRatio(
                  aspectRatio: controller!.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
      ),
    );
  }
}
