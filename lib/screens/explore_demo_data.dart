import 'dart:math';

import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Datos de demostración para ExploreScreen
//
// Extraído del god-file explore_screen.dart para mantener limpia la lógica.
// Contiene: ciudades conocidas (geocoding offline) y pins simulados.
// ─────────────────────────────────────────────────────────────────────────────

/// Ciudades conocidas para búsqueda sin API key de geocoding.
const Map<String, LatLng> knownCities = {
  // 🇪🇸 España
  'madrid':          LatLng(40.4168, -3.7038),
  'barcelona':       LatLng(41.3851,  2.1734),
  'sevilla':         LatLng(37.3891, -5.9845),
  'valencia':        LatLng(39.4699, -0.3763),
  'bilbao':          LatLng(43.2627, -2.9253),
  'malaga':          LatLng(36.7213, -4.4214),
  'zaragoza':        LatLng(41.6488, -0.8891),
  // 🇪🇺 Europa
  'london':          LatLng(51.5074, -0.1278),
  'paris':           LatLng(48.8566,  2.3522),
  'berlin':          LatLng(52.5200, 13.4050),
  'amsterdam':       LatLng(52.3676,  4.9041),
  'rome':            LatLng(41.9028, 12.4964),
  'roma':            LatLng(41.9028, 12.4964),
  'milan':           LatLng(45.4642,  9.1900),
  'lisbon':          LatLng(38.7223, -9.1393),
  'lisboa':          LatLng(38.7223, -9.1393),
  'munich':          LatLng(48.1351, 11.5820),
  'zurich':          LatLng(47.3769,  8.5417),
  'stockholm':       LatLng(59.3293, 18.0686),
  'dublin':          LatLng(53.3498, -6.2603),
  'vienna':          LatLng(48.2082, 16.3738),
  'viena':           LatLng(48.2082, 16.3738),
  'warsaw':          LatLng(52.2297, 21.0122),
  'varsovia':        LatLng(52.2297, 21.0122),
  'prague':          LatLng(50.0755, 14.4378),
  'praga':           LatLng(50.0755, 14.4378),
  'brussels':        LatLng(50.8503,  4.3517),
  'bruselas':        LatLng(50.8503,  4.3517),
  'copenhagen':      LatLng(55.6761, 12.5683),
  'helsinki':         LatLng(60.1699, 24.9384),
  'oslo':            LatLng(59.9139, 10.7522),
  // 🇺🇸 Norteamérica
  'new york':        LatLng(40.7128, -74.0060),
  'nueva york':      LatLng(40.7128, -74.0060),
  'los angeles':     LatLng(34.0522,-118.2437),
  'chicago':         LatLng(41.8781, -87.6298),
  'miami':           LatLng(25.7617, -80.1918),
  'san francisco':   LatLng(37.7749,-122.4194),
  'houston':         LatLng(29.7604, -95.3698),
  'seattle':         LatLng(47.6062,-122.3321),
  'boston':           LatLng(42.3601, -71.0589),
  'austin':          LatLng(30.2672, -97.7431),
  'toronto':         LatLng(43.6532, -79.3832),
  'vancouver':       LatLng(49.2827,-123.1207),
  'montreal':        LatLng(45.5017, -73.5673),
  // 🇲🇽 México
  'cdmx':            LatLng(19.4326, -99.1332),
  'mexico':          LatLng(19.4326, -99.1332),
  'ciudad de mexico':LatLng(19.4326, -99.1332),
  'guadalajara':     LatLng(20.6597,-103.3496),
  'monterrey':       LatLng(25.6866,-100.3161),
  'puebla':          LatLng(19.0414, -98.2063),
  'cancun':          LatLng(21.1619, -86.8515),
  // 🇦🇷 🇨🇴 🇨🇱 🇵🇪 🇧🇷 Sudamérica
  'buenos aires':    LatLng(-34.6037, -58.3816),
  'rosario':         LatLng(-32.9468, -60.6393),
  'cordoba':         LatLng(-31.4201, -64.1888),
  'mendoza':         LatLng(-32.8895, -68.8458),
  'bogota':          LatLng(4.7110,  -74.0721),
  'medellin':        LatLng(6.2442,  -75.5812),
  'cali':            LatLng(3.4516,  -76.5320),
  'barranquilla':    LatLng(10.9685, -74.7813),
  'lima':            LatLng(-12.0464, -77.0428),
  'santiago':        LatLng(-33.4489, -70.6693),
  'sao paulo':       LatLng(-23.5505, -46.6333),
  'rio':             LatLng(-22.9068, -43.1729),
  'rio de janeiro':  LatLng(-22.9068, -43.1729),
  'brasilia':        LatLng(-15.7975, -47.8919),
  'montevideo':      LatLng(-34.9011, -56.1645),
  'quito':           LatLng(-0.1807,  -78.4678),
  'panama':          LatLng(8.9824,  -79.5199),
  'san jose':        LatLng(9.9281,  -84.0907),
  'caracas':         LatLng(10.4806, -66.9036),
  'la paz':          LatLng(-16.5000, -68.1500),
  'asuncion':        LatLng(-25.2637, -57.5759),
  // 🇯🇵 🇦🇪 🇸🇬 Asia & Oceanía
  'tokyo':           LatLng(35.6762, 139.6503),
  'dubai':           LatLng(25.2048,  55.2708),
  'singapore':       LatLng(1.3521,  103.8198),
  'singapur':        LatLng(1.3521,  103.8198),
  'seoul':           LatLng(37.5665, 126.9780),
  'shanghai':        LatLng(31.2304, 121.4737),
  'hong kong':       LatLng(22.3193, 114.1694),
  'bangalore':       LatLng(12.9716, 77.5946),
  'mumbai':          LatLng(19.0760, 72.8777),
  'sydney':          LatLng(-33.8688, 151.2093),
  'melbourne':       LatLng(-37.8136, 144.9631),
  // 🇲🇦 🇿🇦 África
  'cape town':       LatLng(-33.9249, 18.4241),
  'nairobi':         LatLng(-1.2921,  36.8219),
  'lagos':           LatLng(6.5244,   3.3792),
  'cairo':           LatLng(30.0444, 31.2357),
  'casablanca':      LatLng(33.5731, -7.5898),
  // 🌎 Países
  'peru':            LatLng(-12.0464, -77.0428),
  'colombia':        LatLng(4.7110, -74.0721),
  'argentina':       LatLng(-34.6037, -58.3816),
  'chile':           LatLng(-33.4489, -70.6693),
  'uruguay':         LatLng(-34.9011, -56.1645),
  'ecuador':         LatLng(-0.1807, -78.4678),
  'mexico pais':     LatLng(19.4326, -99.1332),
  'españa':          LatLng(40.4168, -3.7038),
  'estados unidos':  LatLng(40.7128, -74.0060),
};

/// Pines simulados para demo — se filtran por distancia y tipo cruzado.
const List<Map<String, dynamic>> simCandidates = [
  // 🇦🇷 Buenos Aires area
  {'name': 'Sofía M.', 'headline': 'UX Designer · 4 años', 'type': 'candidato', 'video': true, 'lat': -34.5890, 'lng': -58.3970},
  {'name': 'Globant', 'headline': 'Hiring Product Managers', 'type': 'empresa', 'video': false, 'lat': -34.6118, 'lng': -58.3640},
  {'name': 'Martín P.', 'headline': 'Frontend React · TypeScript', 'type': 'candidato', 'video': true, 'lat': -34.5730, 'lng': -58.4216},
  {'name': 'MercadoLibre', 'headline': 'Busca DevOps Engineer', 'type': 'empresa', 'video': false, 'lat': -34.6322, 'lng': -58.3700},
  {'name': 'Ualá', 'headline': 'Hiring Backend Engineers', 'type': 'empresa', 'video': false, 'lat': -34.5972, 'lng': -58.3735},
  {'name': 'Auth0', 'headline': 'Busca Security Engineer', 'type': 'empresa', 'video': false, 'lat': -34.6155, 'lng': -58.3816},
  {'name': 'Mariano T.', 'headline': 'DevOps · AWS · Terraform', 'type': 'candidato', 'video': true, 'lat': -34.6250, 'lng': -58.4100},
  {'name': 'Valentina R.', 'headline': 'Product Manager · Agile', 'type': 'candidato', 'video': false, 'lat': -34.5810, 'lng': -58.4350},
  // Zona Norte GBA
  {'name': 'TiendaNube', 'headline': 'Busca Frontend Dev', 'type': 'empresa', 'video': false, 'lat': -34.4730, 'lng': -58.5130},
  {'name': 'Lucía F.', 'headline': 'Data Analyst · SQL', 'type': 'candidato', 'video': true, 'lat': -34.4850, 'lng': -58.4950},
  // Zona Sur GBA
  {'name': 'Franco D.', 'headline': 'QA Automation · Selenium', 'type': 'candidato', 'video': false, 'lat': -34.7100, 'lng': -58.2800},
  {'name': 'Technisys', 'headline': 'Busca Java Developer', 'type': 'empresa', 'video': false, 'lat': -34.6650, 'lng': -58.3650},
  // La Plata (~50km)
  {'name': 'Camila G.', 'headline': 'Diseño UX/UI · Figma', 'type': 'candidato', 'video': true, 'lat': -34.9214, 'lng': -57.9544},
  {'name': 'Despegar', 'headline': 'Hiring Mobile Devs', 'type': 'empresa', 'video': false, 'lat': -34.9100, 'lng': -57.9400},
  // Fuera del radio
  {'name': 'Lucas R.', 'headline': 'Data Scientist · Python', 'type': 'candidato', 'video': true, 'lat': -31.4180, 'lng': -64.1834},
  {'name': 'TechCorp Brasil', 'headline': 'Busca Full Stack Dev', 'type': 'empresa', 'video': false, 'lat': -23.5505, 'lng': -46.6333},
];

/// Normaliza texto: minúsculas, sin acentos, sin espacios extra.
String normalizeQuery(String s) {
  return s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Haversine distance in km between two lat/lng points.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371.0;
  final dLat = (lat2 - lat1) * (pi / 180.0);
  final dLng = (lng2 - lng1) * (pi / 180.0);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * (pi / 180.0)) * cos(lat2 * (pi / 180.0)) *
          sin(dLng / 2) * sin(dLng / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}
