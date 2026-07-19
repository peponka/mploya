import 'package:flutter/widgets.dart';

// Stub para plataformas no-web (móvil/desktop). En esos targets el mapa lo dibuja
// flutter_map directamente, así que esto nunca se usa. Existe solo para que el
// import condicional compile fuera de web.
Widget buildWebMap({
  required double centerLat,
  required double centerLng,
  required double zoom,
  required List<Map<String, dynamic>> pins,
  String? selectedId,
  required void Function(String id) onPinTap,
}) =>
    const SizedBox.shrink();
