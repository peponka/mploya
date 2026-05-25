/// Implementación web del reproductor de video.
///
/// Usa `dart:html` VideoElement con HtmlElementView para
/// mostrar video en Flutter web. Mantiene el mismo comportamiento
/// que el código original de cada pantalla.
library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

/// Construye un reproductor de video web usando VideoElement.
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
  // Construir la transformación CSS
  String cssTransform = '';
  if (transform != null) {
    cssTransform = transform;
  } else if (mirror) {
    cssTransform = 'scaleX(-1)';
  }

  final videoEl = html.VideoElement()
    ..src = url
    ..autoplay = autoplay
    ..loop = loop
    ..muted = muted
    ..controls = controls
    ..setAttribute('playsinline', 'true')
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.objectFit = objectFit
    ..style.background = background;

  if (cssTransform.isNotEmpty) {
    videoEl.style.transform = cssTransform;
  }

  if (borderRadius != null) {
    videoEl.style.borderRadius = borderRadius;
  }

  if (filter != null) {
    videoEl.style.filter = filter;
  }

  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int id) => videoEl,
  );

  return HtmlElementView(viewType: viewId);
}
