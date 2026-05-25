/// Stub del reproductor de video multiplataforma.
///
/// Lanza [UnsupportedError] — nunca debería ejecutarse.
library;

import 'package:flutter/widgets.dart';

/// Construye el widget de video — stub que lanza error.
Widget buildPlatformVideoPlayer({
  required String viewId,
  required String url,
  String objectFit = 'cover',
  bool mirror = false,
  bool loop = true,
  bool autoplay = true,
  bool muted = false,
  bool controls = false,
  String? borderRadius,
  String background = '#000',
  String? transform,
  String? filter,
}) {
  throw UnsupportedError(
    'PlatformVideoPlayer no soportado en esta plataforma.',
  );
}
