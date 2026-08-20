import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_thumbnail/video_thumbnail.dart';

import '../ds/mploya_ds.dart';

/// Caché en memoria del proceso: mismo candidato en la lista, el Kanban y la
/// shortlist no vuelve a extraer el frame tres veces.
final _thumbCache = <String, Uint8List?>{};

/// Miniatura real de candidato: un frame del video de perfil si existe, con
/// ícono de reproducir encima — o el avatar de siempre si no hay video.
///
/// SIN duración inventada (el mockup dibuja "0:52" sobre el frame): extraer
/// la duración real exigiría cargar el video entero con `video_player` por
/// cada tarjeta de una lista, que es carísimo. Un frame SÍ es barato
/// (`video_thumbnail` lo pide nativo, sin descargar el video completo) y es
/// dato real — la duración no vale ese costo para esta pantalla.
///
/// Sólo en móvil: `video_thumbnail` es un canal nativo (Android/iOS), no
/// tiene implementación web. En Flutter Web cae directo al avatar — mismo
/// comportamiento que ya tenía la app ahí, no una regresión.
class HeadhunterCandidateThumb extends StatefulWidget {
  const HeadhunterCandidateThumb({
    super.key,
    required this.name,
    this.videoUrl,
    this.avatarUrl,
    this.size = 46,
  });

  final String name;
  final String? videoUrl;
  final String? avatarUrl;
  final double size;

  @override
  State<HeadhunterCandidateThumb> createState() => _HeadhunterCandidateThumbState();
}

class _HeadhunterCandidateThumbState extends State<HeadhunterCandidateThumb> {
  Uint8List? _frame;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HeadhunterCandidateThumb old) {
    super.didUpdateWidget(old);
    if (old.videoUrl != widget.videoUrl) {
      _frame = null;
      _load();
    }
  }

  Future<void> _load() async {
    final url = widget.videoUrl;
    if (kIsWeb || url == null || url.isEmpty) return;
    if (_thumbCache.containsKey(url)) {
      setState(() => _frame = _thumbCache[url]);
      return;
    }
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: url,
        imageFormat: ImageFormat.JPEG,
        maxWidth: (widget.size * 3).round(),
        quality: 60,
      );
      _thumbCache[url] = data;
      if (!mounted) return;
      setState(() => _frame = data);
    } catch (_) {
      _thumbCache[url] = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final avatarUrl = widget.avatarUrl;

    if (_frame == null) {
      return MpAvatar(
        name: widget.name,
        size: size,
        image: (avatarUrl == null || avatarUrl.isEmpty) ? null : NetworkImage(avatarUrl),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(_frame!, fit: BoxFit.cover),
            Container(color: const Color(0x33000000)),
            Center(
              child: Icon(
                CupertinoIcons.play_circle_fill,
                color: const Color(0xFFFFFFFF),
                size: size * 0.44,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

