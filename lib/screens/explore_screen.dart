import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math';
import 'explore_demo_data.dart' as demo;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/user_provider.dart';
import 'story_viewer_screen.dart';
import 'trending_hashtags_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/spring_interaction.dart';
import '../services/search_service.dart';
import '../widgets/search_overlay.dart';
import 'profile_screen.dart';
import 'messaging_screen.dart';
import 'saved_jobs_screen.dart';
import '../services/hashtag_service.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// SQL REQUERIDO â€” Ejecuta esta función en Supabase SQL Editor una sola vez.
// No requiere extensión PostGIS; usa la fórmula de Haversine pura en SQL.
// CREATE OR REPLACE FUNCTION get_nearby_users(
//   id           uuid,
//   name         text,
//   headline     text,
//   video_url    text,
//   account_type text,
//   latitude     double precision,
//   longitude    double precision,
//   distance_km  double precision
// )
// LANGUAGE sql STABLE SECURITY DEFINER AS $$
//   -- LEY DE CRUCE SERVER-SIDE: candidatos ven empresas y viceversa.
//   -- IMPORTANTE: agregar account_type al SELECT y al WHERE para que la RPC
//   -- aplique la ley de cruce y no devuelva usuarios del mismo tipo.
//   SELECT * FROM (
//     SELECT
//       id, name, headline, video_url, account_type, latitude, longitude,
//       ( 6371 * acos( LEAST(1.0,
//           cos(radians(user_lat)) * cos(radians(latitude))
//           * cos(radians(longitude) - radians(user_lng))
//           + sin(radians(user_lat)) * sin(radians(latitude))
//       ))) AS distance_km
//     FROM users
//     WHERE id != auth.uid()
//       AND latitude     IS NOT NULL
//       AND longitude    IS NOT NULL
//       AND (
//         (caller_type = 'empresa'    AND account_type != 'empresa')
//         OR
//         (caller_type != 'empresa'   AND account_type  = 'empresa')
//       )
//   ) sub
//   WHERE distance_km <= radius_km
//   ORDER BY distance_km ASC
//   LIMIT max_results;
// $$;
// NOTA: Pasar caller_type desde Dart con el account_type del usuario actual.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Modelo interno: datos devueltos por la RPC get_nearby_users
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _UserPinData {
  final String id;
  final String name;
  final String headline;
  final String? videoUrl;
  final LatLng point;
  final double distanceKm;
  final String accountType; // 'candidato', 'empresa', 'confidencial', 'stealth'

  const _UserPinData({
    required this.id,
    required this.name,
    required this.headline,
    this.videoUrl,
    required this.point,
    required this.distanceKm,
    this.accountType = 'candidato',
  });

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get isCompany => accountType == 'empresa';

  String get distanceLabel {
    if (distanceKm < 1) return 'A ${(distanceKm * 1000).round()} m';
    return 'A ${distanceKm.toStringAsFixed(1)} km';
  }

  String get commuteLabel {
    final mins = (distanceKm * 2.4).round();
    if (mins < 3) return 'A la vuelta ðŸš¶â€â™‚ï¸';
    return '~$mins min ðŸš—';
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get typeLabel => isCompany ? 'Empresa' : 'Candidato';
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// ExploreScreen
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  // â”€â”€ Zoom constants â”€â”€
  static const double _zoomLocal    = 14.0;
  static const double _zoomRegional = 10.0;  // ~50km visible
  static const double _zoomTactical = 10.0;

  // â”€â”€ Fallback coordinates (Buenos Aires) â”€â”€
  static const double _fallbackLat = -34.6037;
  static const double _fallbackLng = -58.3816;

  final _searchController = TextEditingController();
  // Scroll del panel de resultados (versión web: panel fijo a la derecha).
  final ScrollController _panelScroll = ScrollController();
  int _selectedFilter = 1;
  bool _showSearchOverlay = false;
  bool _showLocationActions = false;
  String? _selectedCityName; // Nombre de ciudad seleccionada manualmente

  // ── Filtros avanzados del panel (web) — la RPC get_nearby_users solo trae
  // id/name/headline/video_url/account_type/lat/lng, así que filtramos sobre
  // esos campos reales (headline suele incluir cargo y empresa, ej. "CTO ·
  // actual Globant"). No hay skills/salario en el pin, no se inventan. ──
  String _exploreTextFilter = '';
  String _exploreTypeFilter = 'todos'; // todos | candidato | empresa

  // IDs de conexiones aceptadas reales — para marcar en el mapa qué pines ya
  // son un match tuyo, como en el mockup (callout "Matches" sobre un pin).
  Set<String> _connectionIds = {};

  Future<void> _loadConnectionIds() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('connections')
          .select('requester_id, addressee_id')
          .or('requester_id.eq.$uid,addressee_id.eq.$uid')
          .eq('status', 'accepted');
      final ids = rows.map<String>((r) {
        final req = r['requester_id']?.toString() ?? '';
        final add = r['addressee_id']?.toString() ?? '';
        return req == uid ? add : req;
      }).where((id) => id.isNotEmpty).toSet();
      if (mounted) setState(() => _connectionIds = ids);
    } catch (_) {}
  }

  List<_UserPinData> _applyExploreFilters(List<_UserPinData> users) {
    var out = users;
    if (_exploreTypeFilter == 'candidato') {
      out = out.where((u) => u.accountType != 'empresa').toList();
    } else if (_exploreTypeFilter == 'empresa') {
      out = out.where((u) => u.accountType == 'empresa').toList();
    }
    if (_exploreTextFilter.trim().isNotEmpty) {
      final q = _exploreTextFilter.trim().toLowerCase();
      out = out.where((u) => u.headline.toLowerCase().contains(q) || u.name.toLowerCase().contains(q)).toList();
    }
    return out;
  }

  Widget _buildExploreFilterBar(BuildContext context) {
    Widget typeChip(String value, String label) {
      final active = _exploreTypeFilter == value;
      return GestureDetector(
        onTap: () => setState(() => _exploreTypeFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? MployaTheme.brandAccent : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? CupertinoColors.white : const Color(0xFF3C3C43),
              )),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FILTROS AVANZADOS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF8E8E93))),
          const SizedBox(height: 10),
          CupertinoTextField(
            placeholder: 'Buscar por cargo o empresa...',
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            prefix: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(CupertinoIcons.search, size: 15, color: Color(0xFF8E8E93))),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(10),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => setState(() => _exploreTextFilter = v),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              typeChip('todos', 'Todos'),
              const SizedBox(width: 8),
              typeChip('candidato', 'Candidatos'),
              const SizedBox(width: 8),
              typeChip('empresa', 'Empresas'),
            ],
          ),
        ],
      ),
    );
  }

  // ── GPS state ──
  Position? _userPosition;
  bool _locationLoading = true;
  bool _permissionDenied = false;
  bool _gpsActivating = false;
  late final MapController _mapController;

  // ── Datos de usuarios cercanos (RPC server-side) ──
  Future<List<_UserPinData>>? _nearbyFuture;

  // Centro real del mapa: posición GPS del usuario o fallback (Buenos Aires)
  LatLng get _center => _userPosition != null
      ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
      : const LatLng(_fallbackLat, _fallbackLng);

  // Zoom adaptado al radio
  double get _zoomForFilter {
    if (_selectedFilter == 0) return _zoomLocal;    // 5 km
    if (_selectedFilter == 1) return _zoomRegional;  // 50 km
    return 3.0;                                      // Todos
  }

  // Radio en km para cada filtro
  double get _radiusForFilter {
    if (_selectedFilter == 0) return 5.0;
    if (_selectedFilter == 1) return 50.0;
    return 20000.0; // "Todos" = global
  }

  void _searchCity(String query) {
    final q = demo.normalizeQuery(query);
    if (q.isEmpty) return;
    for (final entry in demo.knownCities.entries) {
      final key = demo.normalizeQuery(entry.key);
      if (key.contains(q) || q.contains(key)) {
        _mapController.move(entry.value, 11.0);
        return;
      }
    }
  }

  // ── 3 filtros funcionales ──
  static const _filters = [
    '📍 Cerca',
    '🏙️ Ciudad',
    '🌍 Todos',
  ];

  static const _avatarColors = [
    MployaTheme.brandAccent,
    Color(0xFF6366F1),
    Color(0xFF0A84FF),
    Color(0xFF34C759),
    Color(0xFFFFB800),
    Color(0xFFFF3B30),
    Color(0xFFAF52DE),
    Color(0xFF5E5CE6),
  ];

  static Color _avatarColor(String id) =>
      _avatarColors[id.hashCode.abs() % _avatarColors.length];

  // ── Inicialización GPS ──

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initLocation();
    _loadConnectionIds();
  }

  Future<void> _initLocation() async {
    try {
      // 1. Check if location service is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ GPS: Location service disabled, prompting user...');
        throw Exception('Location service not enabled');
      }

      // 2. Check/request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Permission denied');
      }

      // 3. Try GPS with Android hardware (bypass Google Play Services)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            forceLocationManager: true,
            timeLimit: const Duration(seconds: 15),
          ),
        );
      } catch (e) {
        debugPrint('GPS init getCurrentPosition failed: $e');
      }

      // 4. Fallback: position stream
      if (position == null) {
        try {
          final stream = Geolocator.getPositionStream(
            locationSettings: AndroidSettings(
              accuracy: LocationAccuracy.high,
              forceLocationManager: true,
              distanceFilter: 0,
              intervalDuration: const Duration(seconds: 1),
            ),
          );
          position = await stream.first.timeout(const Duration(seconds: 15));
        } catch (e) {
          debugPrint('GPS init stream failed: $e');
        }
      }

      // 5. Last resort: FusedLocationProvider
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 10),
            ),
          );
        } catch (e) {
          debugPrint('GPS init fused failed: $e');
        }
      }

      if (position == null) throw Exception('GPS: no position available');

      debugPrint('GPS init OK: ${position.latitude}, ${position.longitude}');

      if (!mounted) return;
      setState(() {
        _userPosition = position;
        _locationLoading = false;
      });
      _mapController.move(LatLng(position!.latitude, position.longitude), _zoomRegional);
      _savePositionAndLoad(position);
    } catch (e) {
      debugPrint('⚠️ GPS error: $e');
      if (!mounted) return;
      final fallbackPos = Position(
        longitude: _fallbackLng,
        latitude: _fallbackLat,
        timestamp: DateTime.now(),
        accuracy: 100,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );

      setState(() {
        _userPosition = fallbackPos;
        _locationLoading = false;
        _permissionDenied = true;
      });
      _loadNearbyUsers();
    }
  }

  /// Called when user explicitly taps "Activar GPS" button.
  Future<void> _activateGps() async {
    if (_gpsActivating) return;
    setState(() => _gpsActivating = true);

    try {
      // 1. Check if GPS service is on
      bool serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        await Geolocator.openLocationSettings();
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(seconds: 1));
          serviceOn = await Geolocator.isLocationServiceEnabled();
          if (serviceOn) break;
        }
        if (!serviceOn) throw 'GPS desactivado en el dispositivo';
      }

      // 2. Check/request permission
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        if (!mounted) return;
        setState(() => _gpsActivating = false);
        return;
      }
      if (perm == LocationPermission.denied) throw 'Permiso GPS denegado';

      // 3. Try getCurrentPosition with Android hardware GPS
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            forceLocationManager: true,
            timeLimit: const Duration(seconds: 15),
          ),
        );
      } catch (e) {
        debugPrint('getCurrentPosition failed: $e, trying stream...');
      }

      // 4. Fallback: use position stream (more reliable on some devices)
      if (pos == null) {
        try {
          final stream = Geolocator.getPositionStream(
            locationSettings: AndroidSettings(
              accuracy: LocationAccuracy.high,
              forceLocationManager: true,
              distanceFilter: 0,
              intervalDuration: const Duration(seconds: 1),
            ),
          );
          pos = await stream.first.timeout(const Duration(seconds: 15));
        } catch (e) {
          debugPrint('Position stream also failed: $e');
        }
      }

      // 5. Last resort: try with FusedLocationProvider (Google Play Services)
      if (pos == null) {
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 10),
            ),
          );
        } catch (e) {
          debugPrint('FusedLocation also failed: $e');
        }
      }

      if (pos == null) throw 'No se pudo obtener la ubicación GPS';

      debugPrint('GPS OK: ${pos.latitude}, ${pos.longitude}');

      if (!mounted) return;
      setState(() {
        _userPosition = pos;
        _locationLoading = false;
        _permissionDenied = false;
        _selectedCityName = null;
        _gpsActivating = false;
      });
      _mapController.move(LatLng(pos!.latitude, pos.longitude), _zoomRegional);
      _savePositionAndLoad(pos);
    } catch (e) {
      debugPrint('GPS FAILED: $e');
      if (!mounted) return;
      setState(() {
        _gpsActivating = false;
        _permissionDenied = true;
      });
      // Show visible error to user
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('GPS'),
            content: Text('No se pudo obtener tu ubicación.\n\nError: $e\n\nUsá "Elegir Ciudad" para seleccionar manualmente.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    }
  }

  // â”€â”€ City Picker Modal â€” Fallback cuando GPS no está disponible â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showCityPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _CityPickerSheet(
        onCitySelected: (name, coords) {
          Navigator.pop(ctx);
          final pos = Position(
            longitude: coords.longitude,
            latitude: coords.latitude,
            timestamp: DateTime.now(),
            accuracy: 100,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
          setState(() {
            _userPosition = pos;
            _selectedCityName = name;
          });
          _mapController.move(coords, _zoomForFilter);
          _loadNearbyUsers();
        },
      ),
    );
  }

  Future<void> _savePositionAndLoad(Position position) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        await Supabase.instance.client.from('users').update({
          'latitude': position.latitude,
          'longitude': position.longitude,
        }).eq('id', uid);
      }
    } catch (e) {
      debugPrint('Error actualizando ubicación: $e');
    }
    _loadNearbyUsers();
  }

  // â”€â”€ Carga server-side via RPC Haversine â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Llama a la función SQL get_nearby_users con el radio correspondiente
  /// al filtro activo. Solo trae los usuarios con ubicación registrada,
  /// ordenados por distancia, con un tope de 60 registros.
  void _loadNearbyUsers() {
    if (!mounted) return;
    setState(() {
      _nearbyFuture = _fetchNearbyUsers();
    });
  }

  /// Resuelve coordenadas de una ciudad usando el diccionario local.
  // ignore: unused_element
  LatLng? _resolveCityCoords(String? city) {
    if (city == null || city.isEmpty) return null;
    final q = demo.normalizeQuery(city);
    if (q.isEmpty) return null;
    for (final entry in demo.knownCities.entries) {
      final key = demo.normalizeQuery(entry.key);
      if (q.contains(key) || key.contains(q)) return entry.value;
    }
    final words = q.split(RegExp(r'[\s,]+'));
    for (final word in words) {
      if (word.length < 3) continue;
      for (final entry in demo.knownCities.entries) {
        final key = demo.normalizeQuery(entry.key);
        if (key == word || (word.length >= 4 && key.contains(word))) {
          return entry.value;
        }
      }
    }
    return null;
  }

  Future<List<_UserPinData>> _fetchNearbyUsers() async {
    final pos = _userPosition;
    if (pos == null) return [];

    // â”€â”€ Determinar tipo del usuario actual para filtro cruzado â”€â”€
    final currentUser = ref.read(currentUserProvider).value;
    final String myType = currentUser?.accountType ?? 'candidato';
    final bool iAmCompany = myType == 'empresa';

    List<_UserPinData> results = [];
    final double radius = _radiusForFilter;

    try {
      final res = await Supabase.instance.client.rpc(
        'get_explore_pins',
        params: {
          'p_lat': pos.latitude,
          'p_lng': pos.longitude,
          'p_radius_km': radius.clamp(0, 50),
        },
      );

      final rows = res as List<dynamic>;
      debugPrint('Mapa: ${rows.length} pines recibidos de Supabase RPC');

      for (int i = 0; i < rows.length; i++) {
        final r = rows[i] as Map<String, dynamic>;
        final pinId = r['pin_id']?.toString() ?? '';
        if (pinId.isEmpty) continue;

        double? lat = (r['latitude'] as num?)?.toDouble();
        double? lng = (r['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final String accountType = r['pin_type']?.toString() ?? 'candidato';
        final bool pinIsCompany = accountType == 'empresa';
        if (iAmCompany && pinIsCompany) continue;
        if (!iAmCompany && !pinIsCompany) continue;

        // Spiral scatter para evitar pines superpuestos
        final double radiusOffset = (i * 0.005);
        final double angle = i * 2.39996;
        lat += radiusOffset * cos(angle);
        lng += radiusOffset * sin(angle);

        results.add(_UserPinData(
          id: pinId,
          name: r['pin_name']?.toString() ?? (accountType == 'empresa' ? 'Empresa' : 'Candidato'),
          headline: r['pin_headline']?.toString() ?? '',
          videoUrl: null,
          point: LatLng(lat, lng),
          distanceKm: (r['distance_km'] as num?)?.toDouble() ?? 0.0,
          accountType: accountType,
        ));
      }
    } catch (e) {
      debugPrint('Error al cargar pines del mapa: $e');
    }

    return results;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    _panelScroll.dispose();
    super.dispose();
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    // â”€â”€ Cargando GPS â”€â”€
    if (_locationLoading) {
      return const CupertinoPageScaffold(
        backgroundColor: Color(0xFFE8E8E3),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(radius: 18),
              SizedBox(height: 16),
              Text(
                'Obteniendo tu ubicaciónâ€¦',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8E8E93),
                  fontFamily: '.SF Pro Text',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // â”€â”€ GPS denegado: ya no bloqueamos la pantalla.
    //    El mapa se muestra con posición fallback (Buenos Aires).
    //    Un banner sutil se agrega en el Stack si _permissionDenied == true.

    // â”€â”€ Vista principal con GPS real â”€â”€
    return FutureBuilder<List<_UserPinData>>(
      future: _nearbyFuture,
      builder: (context, snap) {
        final allUsers = snap.data ?? <_UserPinData>[];
        final users = _applyExploreFilters(allUsers);
        final isLoading = snap.connectionState == ConnectionState.waiting;

        // En web: mapa a la izquierda + panel de resultados fijo a la derecha.
        // En móvil: mapa full-screen + hoja arrastrable.
        final wide = MediaQuery.of(context).size.width > 900;
        final mapStack = Stack(
            children: [
              // â”€â”€ 1. MAPA centrado en la posición real del usuario â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Positioned.fill(
                child: _MapBackground(
                  center: _center,
                  users: users,
                  mapController: _mapController,
                  initialZoom: _zoomForFilter,
                  connectionIds: _connectionIds,
                ),
              ),

              // â”€â”€ 2. BARRA SUPERIOR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: _TopSearchBar(
                    controller: _searchController,
                    cityName: _selectedCityName ?? 'Ciudad Autónoma de Buenos Aires',
                    gpsActivating: _gpsActivating,
                    onChooseCity: _showCityPicker,
                    onActivateGps: _activateGps,
                    onCitySearch: (q) {
                      _searchCity(q);
                      setState(() => _showSearchOverlay = false);
                      SearchService.instance.cancel();
                    },
                    onSearchChanged: (q) {
                      if (q.trim().length >= 2) {
                        SearchService.instance.search(q);
                        if (!_showSearchOverlay) {
                          setState(() => _showSearchOverlay = true);
                        }
                      } else {
                        SearchService.instance.cancel();
                        if (_showSearchOverlay) {
                          setState(() => _showSearchOverlay = false);
                        }
                      }
                    },
                  ),
                ),
              ),

              // â”€â”€ 2.5. CONTROLES DE ZOOM â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Positioned(
                right: 16,
                bottom: MediaQuery.of(context).size.height * 0.4 + 16,
                child: Column(
                  children: [
                    // Botón Mi Ubicación
                    _ZoomButton(
                      icon: CupertinoIcons.location_fill,
                      onTap: () {
                        _mapController.move(_center, _zoomLocal);
                      },
                    ),
                    const SizedBox(height: 8),
                    // Zoom In
                    _ZoomButton(
                      icon: CupertinoIcons.plus,
                      onTap: () {
                        final currentZoom = _mapController.camera.zoom;
                        _mapController.move(
                          _mapController.camera.center,
                          (currentZoom + 1).clamp(2.0, 18.0),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    // Zoom Out
                    _ZoomButton(
                      icon: CupertinoIcons.minus,
                      onTap: () {
                        final currentZoom = _mapController.camera.zoom;
                        _mapController.move(
                          _mapController.camera.center,
                          (currentZoom - 1).clamp(2.0, 18.0),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // â”€â”€ 3. HOJA INFERIOR con perfiles reales (solo móvil) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              if (!wide)
                DraggableScrollableSheet(
                initialChildSize: 0.38,
                minChildSize: 0.13,
                maxChildSize: 0.88,
                snap: true,
                snapSizes: const [0.13, 0.38, 0.88],
                builder: (ctx, scrollController) => _BottomSheet(
                  scrollController: scrollController,
                  users: users,
                  isLoading: isLoading,
                  avatarColor: _avatarColor,
                  onUserTap: (userPin) {
                    _mapController.move(userPin.point, 14.0);
                  },
                ),
              ),

              // â”€â”€ 4. SEARCH OVERLAY â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              if (_showSearchOverlay)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 70,
                  left: 0,
                  right: 0,
                  child: SearchOverlay(
                    visible: _showSearchOverlay,
                    onUserTap: (userId) async {
                      setState(() => _showSearchOverlay = false);
                      SearchService.instance.cancel();
                      _searchController.clear();
                      // Fetch full user data and navigate to profile
                      try {
                        final data = await Supabase.instance.client
                            .from('users')
                            .select()
                            .eq('id', userId)
                            .maybeSingle();
                        if (data != null && context.mounted) {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => ProfileScreen(user: NexUser.fromJson(data)),
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('Error loading profile: $e');
                      }
                    },
                    onTagTap: (tag) {
                      setState(() => _showSearchOverlay = false);
                      _searchController.text = tag;
                      _searchCity(tag);
                    },
                  ),
                ),

              // GPS banner removed — location controls now in top search bar
            ],
          );
        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFFE8E8E3),
          child: wide
              ? Row(
                  children: [
                    Expanded(child: mapStack),
                    // ── Panel de resultados (web): fijo a la derecha ──
                    Container(
                      width: 384,
                      decoration: const BoxDecoration(
                        color: CupertinoColors.white,
                        border: Border(left: BorderSide(color: Color(0x14000000), width: 0.5)),
                      ),
                      child: SafeArea(
                        left: false,
                        child: Column(
                          children: [
                            _buildExploreFilterBar(context),
                            Expanded(
                              child: _BottomSheet(
                                scrollController: _panelScroll,
                                users: users,
                                isLoading: isLoading,
                                avatarColor: _avatarColor,
                                onUserTap: (userPin) => _mapController.move(userPin.point, 14.0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (MediaQuery.of(context).size.width > 1300)
                      _buildFeaturedPanel(context, users),
                  ],
                )
              : mapStack,
        );
      },
    );
  }

  // ── Panel destacado (solo pantallas muy anchas): un perfil real cercano +
  // el match más reciente del usuario, con datos reales de Supabase — nada
  // inventado, si no hay datos la sección correspondiente simplemente no
  // se muestra. ──
  Widget _buildFeaturedPanel(BuildContext context, List<_UserPinData> users) {
    final featured = users.isNotEmpty ? users.first : null;
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        border: Border(left: BorderSide(color: Color(0x14000000), width: 0.5)),
      ),
      child: SafeArea(
        left: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PERFIL DESTACADO',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF8E8E93))),
              const SizedBox(height: 10),
              if (featured == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEDEFF2)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(CupertinoIcons.person_crop_circle, color: MployaTheme.brandAccent, size: 22),
                      ),
                      const SizedBox(height: 10),
                      Text('Sin perfiles cerca todavía',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Ampliá el radio o cambiá de ciudad para ver profesionales.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: context.textTertiary, height: 1.3)),
                    ],
                  ),
                )
              else
                _FeaturedProfileCard(pin: featured),
              const SizedBox(height: 20),
              _RecentMatchCard(),
              const SizedBox(height: 20),
              Center(
                child: Text('¡Dale Play a tu carrera!',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textTertiary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Featured profile card: perfil real cercano con foto/tags reales ──
class _FeaturedProfileCard extends StatelessWidget {
  final _UserPinData pin;
  const _FeaturedProfileCard({required this.pin});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: Supabase.instance.client
          .from('users')
          .select('avatar_url, tags, company')
          .eq('id', pin.id)
          .maybeSingle(),
      builder: (context, snap) {
        final avatarUrl = snap.data?['avatar_url']?.toString();
        final tags = (snap.data?['tags'] as List?)?.map((t) => t.toString()).toList() ?? [];
        return GestureDetector(
          onTap: () async {
            final data = await Supabase.instance.client.from('users').select().eq('id', pin.id).maybeSingle();
            if (data != null && context.mounted) {
              Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: NexUser.fromJson(data))));
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    color: const Color(0xFFEFEFEF),
                    child: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover)
                        : Center(
                            child: Text(pin.name.isNotEmpty ? pin.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Color(0xFFBBBBBB))),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(pin.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1C1C1E))),
              if (pin.headline.isNotEmpty)
                Text(pin.headline, style: const TextStyle(fontSize: 12.5, color: Color(0xFF8E8E93)), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5, runSpacing: 5,
                  children: tags.take(6).map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                        child: Text('#$t', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: MployaTheme.brandAccent)),
                      )).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Card de match más reciente: solo se muestra si existe uno real ──
class _RecentMatchCard extends StatelessWidget {
  const _RecentMatchCard();

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return const SizedBox.shrink();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('connections')
          .select('requester_id, addressee_id, updated_at')
          .or('requester_id.eq.$uid,addressee_id.eq.$uid')
          .eq('status', 'accepted')
          .order('updated_at', ascending: false)
          .limit(1),
      builder: (context, snap) {
        final rows = snap.data ?? [];
        if (rows.isEmpty) return const SizedBox.shrink();
        final r = rows.first;
        final otherId = r['requester_id']?.toString() == uid ? r['addressee_id']?.toString() : r['requester_id']?.toString();
        if (otherId == null) return const SizedBox.shrink();
        return FutureBuilder<Map<String, dynamic>?>(
          future: Supabase.instance.client.from('users').select('name, headline, company').eq('id', otherId).maybeSingle(),
          builder: (context, userSnap) {
            final name = userSnap.data?['name']?.toString();
            if (name == null) return const SizedBox.shrink();
            final headline = userSnap.data?['headline']?.toString() ?? '';
            final company = userSnap.data?['company']?.toString();
            final subtitle = [headline, company].where((s) => s != null && s.isNotEmpty).join(' · ');
            return GestureDetector(
              onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => MessagingScreen())),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MployaTheme.brandAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26, height: 26,
                      decoration: const BoxDecoration(color: MployaTheme.brandAccent, shape: BoxShape.circle),
                      child: const Icon(CupertinoIcons.bolt_fill, color: CupertinoColors.white, size: 13),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('¡Match!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1C1C1E))),
                          Text('con $name${subtitle.isNotEmpty ? ' · $subtitle' : ''}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// 1 · MAP BACKGROUND â€” centro dinámico desde GPS real
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MapBackground extends StatelessWidget {
  final LatLng center;
  final List<_UserPinData> users;
  final MapController mapController;
  final double initialZoom;
  final Set<String> connectionIds;
  const _MapBackground({
    required this.center,
    required this.users,
    required this.mapController,
    required this.initialZoom,
    this.connectionIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: initialZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.example.mploya',
        ),
        MarkerLayer(
          markers: [
            // Pines de usuarios reales â€” empresas y candidatos
            ...users.map((u) {
              final isMatch = connectionIds.contains(u.id);
              return Marker(
                point: u.point,
                width: 150,
                height: isMatch ? 92 : 68,
                alignment: Alignment.topCenter,
                child: SpringInteraction(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    mapController.move(u.point, 14.0);
                  },
                  child: _LocationPin(
                    label: u.name,
                    hasVideo: u.hasVideo,
                    isCompany: u.isCompany,
                    isMatch: isMatch,
                  ),
                ),
              );
            }),
            // Tu señal GPS en el centro de la zona
            Marker(
              point: center,
              width: 200,
              height: 200,
              alignment: Alignment.center,
              child: const _RadarPulse(color: MployaTheme.brandAccent),
            ),
          ],
        ),
      ],
    );
  }
}

class _LocationPin extends StatelessWidget {
  final String label;
  final bool hasVideo;
  final bool isCompany;
  final bool isMatch;
  const _LocationPin({
    required this.label,
    required this.hasVideo,
    this.isCompany = false,
    this.isMatch = false,
  });

  @override
  Widget build(BuildContext context) {
    // Empresas = azul/índigo, Candidatos = Verde(video) o Gris
    final Color pinColor;
    final IconData pinIcon;
    
    if (isCompany) {
      pinColor = const Color(0xFF5856D6); // Índigo Apple
      pinIcon = CupertinoIcons.building_2_fill;
    } else if (hasVideo) {
      pinColor = const Color(0xFF34C759); // Verde Apple
      pinIcon = CupertinoIcons.video_camera_solid;
    } else {
      pinColor = const Color(0xFF8E8E93);
      pinIcon = CupertinoIcons.person_solid;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 0. Callout "Match" — solo si ya es una conexión aceptada real.
        if (isMatch) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: MployaTheme.brandAccent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: MployaTheme.brandAccent.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.bolt_fill, size: 10, color: CupertinoColors.white),
                SizedBox(width: 3),
                Text('Match', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: CupertinoColors.white)),
              ],
            ),
          ),
          const SizedBox(height: 3),
        ],
        // 1. Círculo principal del Pin (Estilo Zenly/Apple Maps fluido)
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pinColor,
            border: Border.all(color: CupertinoColors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: pinColor.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              const BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(pinIcon, size: 18, color: CupertinoColors.white),
          ),
        ),
        const SizedBox(height: 5),
        // 2. Etiqueta flotante con el nombre
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x99000000), // Negro semi-transparente
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x22FFFFFF), width: 0.5),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.white,
                  fontFamily: '.SF Pro Text',
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RadarPulse extends StatefulWidget {
  final Color color;
  const _RadarPulse({required this.color});

  @override
  State<_RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<_RadarPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Onda del Radar expandiéndose
            Opacity(
              opacity: 1.0 - scale,
              child: Container(
                width: 200 * scale,
                height: 200 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.3),
                  border: Border.all(color: widget.color, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: widget.color.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 4),
                  ],
                ),
              ),
            ),
            // Avatar central fijo del usuario
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: CupertinoColors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
              ),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: widget.color, shape: BoxShape.circle),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// —————————————————————————————————————————————————————————————————————————————————————————————————
// 2 · TOP SEARCH BAR + FILTER PILLS
// —————————————————————————————————————————————————————————————————————————————————————————————————

class _TopSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onCitySearch;
  final ValueChanged<String>? onSearchChanged;
  final String? cityName;
  final bool gpsActivating;
  final VoidCallback onChooseCity;
  final VoidCallback onActivateGps;

  const _TopSearchBar({
    required this.controller,
    required this.onCitySearch,
    this.onSearchChanged,
    this.cityName,
    this.gpsActivating = false,
    required this.onChooseCity,
    required this.onActivateGps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xEEFFFFFF),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x1C000000),
                        blurRadius: 28,
                        offset: Offset(0, 6)),
                    BoxShadow(
                        color: Color(0x0CFFFFFF),
                        blurRadius: 1,
                        offset: Offset(0, 1)),
                  ],
                ),
                child: CupertinoSearchTextField(
                  controller: controller,
                  placeholder: 'Buscar personas, empresas, ciudades...',
                  backgroundColor: const Color(0x00000000),
                  style: const TextStyle(
                    color: Color(0xFF1C1C1E),
                    fontFamily: '.SF Pro Text',
                    fontSize: 16,
                  ),
                  placeholderStyle: const TextStyle(
                    color: Color(0xFFAEAEB2),
                    fontFamily: '.SF Pro Text',
                    fontSize: 16,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  onChanged: onSearchChanged,
                  onSubmitted: onCitySearch,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── Location bar + hashtag button ──
          Row(
            children: [
              // Location icon + city name
              const Icon(CupertinoIcons.location_fill,
                  size: 14, color: MployaTheme.brandAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  cityName ?? 'Sin ubicación',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1C1C1E),
                    fontFamily: '.SF Pro Text',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Elegir Ciudad button
              SpringInteraction(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChooseCity();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: MployaTheme.brandAccent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: MployaTheme.brandAccent.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Elegir Ciudad',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.white,
                      fontFamily: '.SF Pro Text',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Activar GPS: botón ícono compacto (acción rápida de un toque,
              // no compite en ancho con el nombre de ciudad ni con "Elegir Ciudad").
              Semantics(
                button: true,
                label: 'Activar GPS y usar mi ubicación actual',
                child: SpringInteraction(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onActivateGps();
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xE0FFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: gpsActivating
                        ? const Center(
                            child: SizedBox(
                              width: 14, height: 14,
                              child: CupertinoActivityIndicator(radius: 6),
                            ),
                          )
                        : const Icon(
                            CupertinoIcons.location_fill,
                            size: 16,
                            color: MployaTheme.brandAccent,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Trending hashtag button
              Semantics(
                button: true,
                label: 'Explorar hashtags trending',
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const TrendingHashtagsScreen()),
                    );
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [NexTheme.premiumStart, NexTheme.premiumEnd],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: NexTheme.brandAccent.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.number, size: 16, color: CupertinoColors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// 3 · BOTTOM SHEET con perfiles reales de Supabase
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BottomSheet extends StatelessWidget {
  final ScrollController scrollController;
  final List<_UserPinData> users;
  final bool isLoading;
  final Color Function(String) avatarColor;
  final void Function(_UserPinData)? onUserTap;

  const _BottomSheet({
    required this.scrollController,
    required this.users,
    required this.isLoading,
    required this.avatarColor,
    this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    final extra = MediaQuery.of(context).padding.bottom + 80.0;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xF5FFFFFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Color(0x1C000000), blurRadius: 32, offset: Offset(0, -8)),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // â”€â”€ Drag handle â”€â”€
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D1D6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                // â”€â”€ Header: Título + conteo + guardados â”€â”€
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 16, 0),
                  child: Row(
                    children: [
                      const Text(
                        'Cerca de ti',
                        style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800,
                          color: Color(0xFF1C1C1E),
                          fontFamily: '.SF Pro Display', letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${users.length}',
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: MployaTheme.brandAccent,
                          fontFamily: '.SF Pro Text',
                        ),
                      ),
                      const Spacer(),
                      // â”€â”€ Saved / Bookmark button â”€â”€
                      Semantics(
                        button: true,
                        label: 'Ver perfiles guardados',
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).push(
                              CupertinoPageRoute(builder: (_) => const SavedJobsScreen()),
                            );
                          },
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: MployaTheme.brandAccent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(CupertinoIcons.bookmark_fill, size: 16, color: MployaTheme.brandAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // â”€â”€ Content â”€â”€
                if (isLoading)
                  const SizedBox(
                    height: 180,
                    child: Center(child: CupertinoActivityIndicator(radius: 14)),
                  )
                else if (users.isEmpty)
                  SizedBox(
                    height: 180,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.map_pin_slash, size: 36, color: const Color(0xFFD1D1D6)),
                          const SizedBox(height: 10),
                          const Text(
                            'Sin profesionales en esta zona',
                            style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93), fontFamily: '.SF Pro Text'),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Ampliá el radio para ver más resultados',
                            style: TextStyle(fontSize: 12, color: Color(0xFFAEAEB2), fontFamily: '.SF Pro Text'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 160,
                    child: ListView.separated(
                      clipBehavior: Clip.none,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => SpringInteraction(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (onUserTap != null) onUserTap!(users[i]);
                        },
                        child: _UserCard(user: users[i], color: avatarColor(users[i].id)),
                      ),
                    ),
                  ),
                // ── Hashtags en tendencia: rellena el panel con contenido útil
                // aunque no haya resultados en la zona, e invita a explorar por
                // skill/tema en vez de solo por ubicación. ──
                const SizedBox(height: 20),
                _TrendingHashtagsSection(),
                SizedBox(height: extra),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hashtags en tendencia: pills naranjas tipo "AI tags", tocar navega a
// buscar candidatos/empresas por ese skill/tema. ──
class _TrendingHashtagsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HashtagData>>(
      future: HashtagService.instance.getTrendingHashtags(limit: 12),
      builder: (context, snap) {
        final tags = snap.data ?? [];
        if (tags.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.flame_fill, size: 15, color: MployaTheme.brandAccent),
                  const SizedBox(width: 6),
                  const Text(
                    'Tendencias',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1C1C1E)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((h) => GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => TrendingHashtagsScreen(initialTag: h.tag)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: MployaTheme.brandAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.18), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('#${h.tag}', style: const TextStyle(color: MployaTheme.brandAccent, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 5),
                        Text('${h.count}', style: TextStyle(color: MployaTheme.brandAccent.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User Card
// ─────────────────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final _UserPinData user;
  final Color color;

  const _UserCard({required this.user, required this.color});

  @override
  Widget build(BuildContext context) {
    final typeColor = user.isCompany ? const Color(0xFF5856D6) : MployaTheme.brandAccent;

    return Container(
      width: 240,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0C000000), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // â”€â”€ Avatar + Name + Headline â”€â”€
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Center(
                    child: Text(
                      user.initials,
                      style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w700, fontSize: 16, fontFamily: '.SF Pro Display'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E), fontFamily: '.SF Pro Display', letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.headline.isNotEmpty ? user.headline : 'Profesional en Mploya',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF8E8E93), fontFamily: '.SF Pro Text'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            // â”€â”€ Bottom: Type pill + Distance + CTA â”€â”€
            Row(
              children: [
                // Type pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(user.isCompany ? CupertinoIcons.building_2_fill : CupertinoIcons.person_solid, size: 10, color: typeColor),
                      const SizedBox(width: 3),
                      Text(user.typeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: typeColor, fontFamily: '.SF Pro Text')),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Distance
                Icon(CupertinoIcons.location_solid, size: 10, color: const Color(0xFFAEAEB2)),
                const SizedBox(width: 2),
                Text(user.commuteLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFAEAEB2), fontFamily: '.SF Pro Text')),
                const Spacer(),
                // CTA
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    final nexUser = NexUser(
                      id: user.id, name: user.name, headline: user.headline,
                      videoUrl: user.videoUrl, latitude: user.point.latitude, longitude: user.point.longitude,
                    );
                    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => StoryViewerScreen(users: [nexUser])));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: MployaTheme.brandAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Ver', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CupertinoColors.white, fontFamily: '.SF Pro Text')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Zoom Control Button â€” estilo Apple Maps
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CupertinoColors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0x22000000),
                width: 0.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 18, color: const Color(0xFF1C1C1E)),
            ),
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// City Picker Sheet — Clean autocomplete with Nominatim API
// ─────────────────────────────────────────────────────────────────────────────

class _CityPickerSheet extends StatefulWidget {
  final void Function(String name, LatLng coords) onCitySelected;
  const _CityPickerSheet({required this.onCitySelected});

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _query = '';
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<_CityEntry> _results = [];
  bool _loading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() => _query = query);
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _hasSearched = false;
      });
      return;
    }

    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 150), () {
      _searchCities(query.trim());
    });
  }

  Future<void> _searchCities(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&addressdetails=1'
        '&limit=8'
        '&featuretype=city'
        '&accept-language=es',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'Mploya/1.0 (contact@mploya.com)',
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final cities = <_CityEntry>[];
        final seen = <String>{};

        for (final item in data) {
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          if (lat == null || lon == null) continue;

          final addr = item['address'] as Map<String, dynamic>? ?? {};
          final city = item['display_name']?.toString().split(',').first.trim() ?? '';
          final country = addr['country']?.toString() ?? '';

          final dedupeKey = '${city.toLowerCase()}_${country.toLowerCase()}';
          if (seen.contains(dedupeKey)) continue;
          seen.add(dedupeKey);

          cities.add(_CityEntry(
            displayName: city,
            country: country,
            coords: LatLng(lat, lon),
          ));
        }

        setState(() {
          _results = cities;
          _loading = false;
          _hasSearched = true;
        });
      } else {
        setState(() { _loading = false; _hasSearched = true; });
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Nominatim error: $e');
      setState(() { _loading = false; _hasSearched = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle ──
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D1D6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // ── Search Field ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CupertinoTextField(
              controller: _controller,
              focusNode: _focusNode,
              placeholder: 'Buscá tu ciudad...',
              prefix: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(CupertinoIcons.search, size: 18, color: Color(0xFF8E8E93)),
              ),
              suffix: _query.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _controller.clear();
                        _onSearchChanged('');
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(CupertinoIcons.clear_circled_solid, size: 18, color: Color(0xFFD1D1D6)),
                      ),
                    )
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              style: const TextStyle(fontSize: 17, color: Color(0xFF1C1C1E)),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(14),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          // ── Results area ──
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _loading
                  ? const Padding(
                      key: ValueKey('loading'),
                      padding: EdgeInsets.only(top: 40),
                      child: CupertinoActivityIndicator(radius: 12),
                    )
                  : _query.isEmpty
                      ? _buildEmptyState()
                      : _results.isEmpty && _hasSearched
                          ? _buildNoResults()
                          : ListView.builder(
                              key: ValueKey('results_${_results.length}'),
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _results.length,
                              itemBuilder: (ctx, i) => _buildAnimatedTile(i),
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      key: const ValueKey('empty'),
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(CupertinoIcons.globe, size: 48, color: const Color(0xFFD1D1D6)),
          const SizedBox(height: 12),
          const Text(
            'Escribí el nombre de tu ciudad',
            style: TextStyle(fontSize: 15, color: Color(0xFF8E8E93)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return const Padding(
      key: ValueKey('no_results'),
      padding: EdgeInsets.only(top: 60),
      child: Text(
        'No se encontró esa ciudad',
        style: TextStyle(fontSize: 15, color: Color(0xFF8E8E93)),
      ),
    );
  }

  Widget _buildAnimatedTile(int index) {
    final city = _results[index];
    return TweenAnimationBuilder<double>(
      key: ValueKey('${city.displayName}_${city.country}'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 150 + (index * 40)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onCitySelected(city.displayName, city.coords);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF2F2F7), width: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: MployaTheme.brandAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.location_solid, size: 15, color: MployaTheme.brandAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHighlightedName(city.displayName),
                    const SizedBox(height: 2),
                    Text(city.country, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.chevron_right, size: 13, color: Color(0xFFD1D1D6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedName(String name) {
    if (_query.isEmpty) {
      return Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)));
    }
    final lowerName = name.toLowerCase();
    final lowerQuery = _query.toLowerCase().trim();
    final matchIdx = lowerName.indexOf(lowerQuery);
    if (matchIdx == -1) {
      return Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)));
    }
    final before = name.substring(0, matchIdx);
    final match = name.substring(matchIdx, matchIdx + lowerQuery.length);
    final after = name.substring(matchIdx + lowerQuery.length);
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1C1C1E)),
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          TextSpan(text: match, style: const TextStyle(fontWeight: FontWeight.w800, color: MployaTheme.brandAccent)),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
    );
  }
}

class _CityEntry {
  final String displayName;
  final String country;
  final LatLng coords;
  const _CityEntry({required this.displayName, required this.country, required this.coords});
}
