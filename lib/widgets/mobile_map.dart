import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Implementación MÓVIL del mapa: un WebView con el mismo mapa Leaflet que usamos
// en web. flutter_map en Android (Impeller y Skia) descarga los tiles pero no los
// pinta → mapa gris con los pines flotando. Leaflet los dibuja como <img> reales
// del WebView del sistema, así que se ven siempre (mismo fix que en web, pero acá
// con webview_flutter en vez de <iframe>).
//
// Puente Flutter ⇄ JS:
//   JS → Dart:  MployaMap.postMessage(JSON.stringify({ready:true}))  y  {pinTap:<id>}
//   Dart → JS:  window.mployaSetView(lat,lng,zoom)  y  window.mployaSetPins(pins, selectedId)

Widget buildMobileMap({
  required double centerLat,
  required double centerLng,
  required double zoom,
  required List<Map<String, dynamic>> pins,
  String? selectedId,
  required void Function(String id) onPinTap,
}) {
  return _MobileMap(
    centerLat: centerLat,
    centerLng: centerLng,
    zoom: zoom,
    pins: pins,
    selectedId: selectedId,
    onPinTap: onPinTap,
  );
}

class _MobileMap extends StatefulWidget {
  final double centerLat;
  final double centerLng;
  final double zoom;
  final List<Map<String, dynamic>> pins;
  final String? selectedId;
  final void Function(String id) onPinTap;

  const _MobileMap({
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    required this.pins,
    required this.selectedId,
    required this.onPinTap,
  });

  @override
  State<_MobileMap> createState() => _MobileMapState();
}

class _MobileMapState extends State<_MobileMap> {
  late final WebViewController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF8F9FB))
      ..addJavaScriptChannel('MployaMap', onMessageReceived: _onJsMessage)
      ..loadHtmlString(_html);
  }

  void _onJsMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message);
      if (data is! Map) return;
      if (data['ready'] == true) {
        _ready = true;
        _pushView();
        _pushPins();
      } else if (data['pinTap'] != null) {
        widget.onPinTap(data['pinTap'].toString());
      }
    } catch (_) {
      // Mensaje no-JSON: ignorar.
    }
  }

  void _pushView() {
    _controller.runJavaScript(
        'window.mployaSetView(${widget.centerLat}, ${widget.centerLng}, ${widget.zoom});');
  }

  void _pushPins() {
    final pinsJson = jsonEncode(widget.pins);
    final sel = jsonEncode(widget.selectedId ?? '');
    _controller.runJavaScript('window.mployaSetPins($pinsJson, $sel);');
  }

  @override
  void didUpdateWidget(covariant _MobileMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;
    // Recentrar cuando cambia la selección O el centro/zoom (cambio de ciudad,
    // botón "Mi ubicación"). Antes solo miraba selectedId: al elegir otra ciudad
    // el mapa se quedaba donde estaba aunque la etiqueta ya mostrara la nueva.
    final movio = widget.centerLat != oldWidget.centerLat ||
        widget.centerLng != oldWidget.centerLng ||
        widget.zoom != oldWidget.zoom;
    if (movio || widget.selectedId != oldWidget.selectedId) _pushView();
    _pushPins();
  }

  @override
  Widget build(BuildContext context) {
    // EagerGestureRecognizer: el WebView reclama los gestos aunque esté dentro de
    // un scroll/sheet, así el mapa panea y hace zoom sin robárselos el contenedor.
    return WebViewWidget(
      controller: _controller,
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
    );
  }
}

const String _html = r'''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0" />
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    html, body, #map { height: 100%; margin: 0; padding: 0; background: #F8F9FB; }
    .leaflet-div-icon { background: transparent; border: none; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    var map = L.map('map', { zoomControl: false, attributionControl: false })
      .setView([-34.6037, -58.3816], 13);
    L.tileLayer(
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
      { maxZoom: 19 }
    ).addTo(map);

    var markers = [];
    window.mployaSetPins = function (pins, selectedId) {
      markers.forEach(function (m) { map.removeLayer(m); });
      markers = [];
      (pins || []).forEach(function (p) {
        var sel = (p.id === selectedId);
        var size = sel ? 44 : 36;
        var inner = p.avatar
          ? '<img src="' + p.avatar + '" style="width:100%;height:100%;object-fit:cover" onerror="this.style.display=\'none\'"/>'
          : '';
        var html =
          '<div style="width:' + size + 'px;height:' + size + 'px;border-radius:50%;'
          + 'border:' + (sel ? 3 : 2) + 'px solid ' + p.color + ';background:#fff;overflow:hidden;'
          + 'box-shadow:0 2px 8px rgba(0,0,0,.35);">' + inner + '</div>';
        var icon = L.divIcon({ html: html, className: '', iconSize: [size, size], iconAnchor: [size / 2, size / 2] });
        var mk = L.marker([p.lat, p.lng], { icon: icon }).addTo(map);
        mk.on('click', function () { MployaMap.postMessage(JSON.stringify({ pinTap: p.id })); });
        markers.push(mk);
      });
    };

    window.mployaSetView = function (lat, lng, zoom) {
      map.setView([lat, lng], zoom, { animate: true });
    };

    setTimeout(function () { map.invalidateSize(); }, 200);
    MployaMap.postMessage(JSON.stringify({ ready: true }));
  </script>
</body>
</html>
''';
