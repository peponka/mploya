import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

// Implementación WEB: embebe la sala de Jitsi como un <iframe> dentro de la app
// (platform view), así la videollamada se ve DENTRO de Mploya y no en otra
// pestaña. Agora no soporta web de forma fiable; Jitsi por iframe sí.

final Set<String> _registered = {};

Widget buildJitsiWebView(String room, String displayName) {
  final viewType = 'jitsi-view-$room';
  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    // Config en el fragment de la URL: saltar la pantalla previa (que pedía
    // nombre/código) y entrar directo con el nombre del usuario ya seteado.
    final name = Uri.encodeComponent('"$displayName"');
    final src = 'https://meet.jit.si/$room'
        '#config.prejoinConfig.enabled=false'
        '&config.prejoinPageEnabled=false'
        '&userInfo.displayName=$name';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = src
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'camera; microphone; fullscreen; display-capture; autoplay; clipboard-write';
      return iframe;
    });
  }
  return HtmlElementView(viewType: viewType);
}
