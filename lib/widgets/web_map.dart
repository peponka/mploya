import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

// Implementación WEB del mapa: un <iframe> con un mapa Leaflet (web/map.html).
// flutter_map NO pinta los tiles en Flutter web (CanvasKit) — los descarga pero
// no los dibuja. Leaflet los renderiza como <img> reales del navegador, así que
// se ven siempre. Mismo patrón que la videollamada web (iframe de Jitsi), usando
// solo dart:html (sin dart:js_util, que ya no existe en este SDK).
//
// Comunicación por postMessage:
//   iframe → Dart:  {mployaMapReady:true}  y  {mployaPinTap:<id>}
//   Dart → iframe:  {mployaPins:[...], selectedId:...}  y  {mployaSetView, lat,lng,zoom}

int _counter = 0;

Widget buildWebMap({
  required double centerLat,
  required double centerLng,
  required double zoom,
  required List<Map<String, dynamic>> pins,
  String? selectedId,
  required void Function(String id) onPinTap,
}) {
  return _WebMap(
    centerLat: centerLat,
    centerLng: centerLng,
    zoom: zoom,
    pins: pins,
    selectedId: selectedId,
    onPinTap: onPinTap,
  );
}

class _WebMap extends StatefulWidget {
  final double centerLat;
  final double centerLng;
  final double zoom;
  final List<Map<String, dynamic>> pins;
  final String? selectedId;
  final void Function(String id) onPinTap;

  const _WebMap({
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    required this.pins,
    required this.selectedId,
    required this.onPinTap,
  });

  @override
  State<_WebMap> createState() => _WebMapState();
}

class _WebMapState extends State<_WebMap> {
  late final String _viewType;
  html.IFrameElement? _iframe;
  StreamSubscription<html.MessageEvent>? _sub;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'mploya-map-${_counter++}';
    _sub = html.window.onMessage.listen(_onMessage);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final f = html.IFrameElement()
        // Ruta ABSOLUTA a la raíz del sitio (no /app/map.html): el service worker
        // de Flutter tiene scope /app/ e intercepta las navegaciones ahí dentro,
        // sirviendo index.html. En la raíz no lo toca, así el iframe carga Leaflet.
        ..src = '/map.html'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = 'auto';
      _iframe = f;
      return f;
    });
  }

  void _onMessage(html.MessageEvent e) {
    final data = e.data;
    if (data is! Map) return;
    if (data['mployaMapReady'] == true) {
      _ready = true;
      _postView();
      _postPins();
    } else if (data.containsKey('mployaPinTap')) {
      final id = data['mployaPinTap'];
      if (id != null) widget.onPinTap(id.toString());
    }
  }

  void _postView() {
    _iframe?.contentWindow?.postMessage({
      'mployaSetView': true,
      'lat': widget.centerLat,
      'lng': widget.centerLng,
      'zoom': widget.zoom,
    }, '*');
  }

  void _postPins() {
    _iframe?.contentWindow?.postMessage({
      'mployaPins': widget.pins,
      'selectedId': widget.selectedId ?? '',
    }, '*');
  }

  @override
  void didUpdateWidget(covariant _WebMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;
    // Recentrar solo cuando cambió la selección (para no pelear con el paneo).
    if (widget.selectedId != oldWidget.selectedId) _postView();
    _postPins();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
