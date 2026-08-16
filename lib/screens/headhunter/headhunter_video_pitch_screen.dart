import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../widgets/ds/mploya_ds.dart';
import '../../services/my_profile_service.dart';
import '../camera_screen.dart';

@immutable
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
      child: CupertinoPageScaffold(
        backgroundColor: const Color(0xFFF8F7FC),
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Video pitch personal'),
          previousPageTitle: 'Perfil',
          backgroundColor: CupertinoColors.white,
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
              : _body(),
        ),
      ),
    );
  }

  Widget _body() {
    if (_data.error) {
      return _state(
        CupertinoIcons.exclamationmark_triangle,
        'No pudimos leer tu video',
        'Revisá tu conexión y volvé a intentar.',
        action: 'Reintentar',
        onAction: _load,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        const Text(
          'Tu carta de presentación',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Color(0xFF15163D),
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Contá quién sos, qué talento buscás y qué valor aportás a tus clientes.',
          style: TextStyle(
            fontSize: 15,
            height: 1.45,
            color: Color(0xFF69708F),
          ),
        ),
        const SizedBox(height: 20),
        _videoCard(),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(
            _message!,
            style: const TextStyle(color: CupertinoColors.systemRed),
          ),
        ],
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE4E0F2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Consejos para tu video (60 seg.)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4C2CF3),
                ),
              ),
              const SizedBox(height: 14),
              for (final tip in _tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        size: 17,
                        color: Color(0xFF6C4DFF),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(tip, style: const TextStyle(height: 1.35)),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF17112E), Color(0xFF34256E)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            hasVideo
                ? CupertinoIcons.play_circle_fill
                : CupertinoIcons.videocam,
            size: 58,
            color: CupertinoColors.white,
          ),
          const SizedBox(height: 12),
          Text(
            hasVideo
                ? 'Tu video está publicado'
                : 'Todavía no cargaste un video',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasVideo
                ? 'Se muestra en tu perfil profesional.'
                : 'Podés grabarlo con la cámara y publicarlo en tu perfil.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFCDC6E8), height: 1.35),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: hasVideo
                ? () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) =>
                          _VideoPlayerPage(videoUrl: _data.videoUrl!),
                    ),
                  )
                : _record,
            child: Text(hasVideo ? 'Ver video' : 'Grabar video'),
          ),
          if (hasVideo) ...[
            const SizedBox(height: 4),
            CupertinoButton(
              onPressed: _record,
              child: const Text(
                'Grabar uno nuevo',
                style: TextStyle(color: CupertinoColors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _state(
    IconData icon,
    String title,
    String message, {
    String? action,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF6C4DFF)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(message, textAlign: TextAlign.center),
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
