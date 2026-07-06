import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

// Implementación WEB: embebe la sala de Jitsi como un <iframe> dentro de la app
// (platform view), así la videollamada se ve DENTRO de Mploya y no en otra
// pestaña. Agora no soporta web de forma fiable; Jitsi por iframe sí.

final Set<String> _registered = {};

Widget buildJitsiWebView(String room) {
  final viewType = 'jitsi-view-$room';
  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = 'https://meet.jit.si/$room'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'camera; microphone; fullscreen; display-capture; autoplay; clipboard-write';
      return iframe;
    });
  }
  return HtmlElementView(viewType: viewType);
}
