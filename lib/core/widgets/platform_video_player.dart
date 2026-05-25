/// Widget multiplataforma de reproducción de video.
///
/// Usa conditional imports para seleccionar la implementación
/// correcta según la plataforma (web / mobile / stub).
library;

import 'package:flutter/widgets.dart';

import 'package:mploya/core/widgets/platform_video_player_stub.dart'
    if (dart.library.html) 'package:mploya/core/widgets/platform_video_player_web.dart'
    if (dart.library.io) 'package:mploya/core/widgets/platform_video_player_mobile.dart';

/// Widget de reproducción de video multiplataforma.
///
/// Delega la construcción al factory [buildPlatformVideoPlayer]
/// que se resuelve vía conditional imports.
class PlatformVideoPlayer extends StatelessWidget {
  const PlatformVideoPlayer({
    required this.viewId,
    required this.url,
    this.objectFit = 'cover',
    this.mirror = false,
    this.loop = true,
    this.autoplay = true,
    this.muted = false,
    this.controls = false,
    this.borderRadius,
    this.background = '#000',
    this.transform,
    this.filter,
    super.key,
  });

  /// Identificador único para la platform view.
  final String viewId;

  /// URL del video (blob URL en web, ruta de archivo en mobile).
  final String url;

  /// Ajuste del video en el contenedor (CSS object-fit).
  final String objectFit;

  /// Si se debe espejar horizontalmente.
  final bool mirror;

  /// Si el video debe repetirse.
  final bool loop;

  /// Si el video debe iniciar automáticamente.
  final bool autoplay;

  /// Si el video debe iniciar silenciado.
  final bool muted;

  /// Si se muestran controles nativos del reproductor.
  final bool controls;

  /// Radio de borde (solo afecta en web).
  final String? borderRadius;

  /// Color de fondo (solo afecta en web).
  final String background;

  /// CSS transform adicional (ej: 'scaleX(-1) scale(1.3)').
  final String? transform;

  /// CSS filter adicional (ej: 'blur(30px)').
  final String? filter;

  @override
  Widget build(BuildContext context) {
    return buildPlatformVideoPlayer(
      viewId: viewId,
      url: url,
      objectFit: objectFit,
      mirror: mirror,
      loop: loop,
      autoplay: autoplay,
      muted: muted,
      controls: controls,
      borderRadius: borderRadius,
      background: background,
      transform: transform,
      filter: filter,
    );
  }
}
