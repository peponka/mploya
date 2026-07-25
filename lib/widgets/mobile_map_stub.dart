import 'package:flutter/widgets.dart';

// Stub para web. En web el mapa lo dibuja el iframe Leaflet (web_map.dart), así
// que esta implementación nunca se usa; existe solo para que el import
// condicional compile sin arrastrar webview_flutter al build web.
Widget buildMobileMap({
  required double centerLat,
  required double centerLng,
  required double zoom,
  required List<Map<String, dynamic>> pins,
  String? selectedId,
  required void Function(String id) onPinTap,
}) =>
    const SizedBox.shrink();
