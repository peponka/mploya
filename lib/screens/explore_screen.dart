import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Colors, LinearProgressIndicator, AlwaysStoppedAnimation, CircularProgressIndicator;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/web_ui.dart';
import '../models/models.dart';
import '../screens/vacantes_screen.dart';
import 'profile_screen.dart';
import 'explore_demo_data.dart';
// Mapa Leaflet: flutter_map no pinta los tiles ni en web (CanvasKit) ni en móvil
// (Android) → se usa Leaflet en iframe (web) o en WebView (móvil).
import '../widgets/web_map_stub.dart'
    if (dart.library.html) '../widgets/web_map.dart';
import '../widgets/mobile_map_stub.dart'
    if (dart.library.io) '../widgets/mobile_map.dart';

// Pre-defined high-quality photos mapped to demo names or indices for premium look
String _getItemPhoto(Map<String, dynamic> item) {
  final name = item['name'] as String;
  final isCompany = item['type'] == 'empresa';
  
  if (isCompany) {
    if (name.contains('Globant')) return 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=100&h=100&fit=crop';
    if (name.contains('MercadoLibre')) return 'https://images.unsplash.com/photo-1472851294608-062f824d29cc?w=100&h=100&fit=crop';
    if (name.contains('Ualá')) return 'https://images.unsplash.com/photo-1601597111158-2fceff292cac?w=100&h=100&fit=crop';
    if (name.contains('Auth0')) return 'https://images.unsplash.com/photo-1563986768609-322da13575f3?w=100&h=100&fit=crop';
    if (name.contains('TiendaNube')) return 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=100&h=100&fit=crop';
    if (name.contains('Technisys')) return 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=100&h=100&fit=crop';
    if (name.contains('Despegar')) return 'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=100&h=100&fit=crop';
    return 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=100&h=100&fit=crop'; // default building
  } else {
    // Caras variadas (randomuser.me), género acorde al nombre. Números distintos
    // a los del Dashboard de Candidatos para no repetir ninguna cara entre pantallas.
    if (name.contains('Sofía')) return 'https://randomuser.me/api/portraits/women/20.jpg';
    if (name.contains('Martín')) return 'https://randomuser.me/api/portraits/men/22.jpg';
    if (name.contains('Mariano')) return 'https://randomuser.me/api/portraits/men/76.jpg';
    if (name.contains('Valentina')) return 'https://randomuser.me/api/portraits/women/65.jpg';
    if (name.contains('Lucía')) return 'https://randomuser.me/api/portraits/women/8.jpg';
    if (name.contains('Franco')) return 'https://randomuser.me/api/portraits/men/11.jpg';
    if (name.contains('Camila')) return 'https://randomuser.me/api/portraits/women/50.jpg';
    if (name.contains('Lucas')) return 'https://randomuser.me/api/portraits/men/40.jpg';
    return 'https://randomuser.me/api/portraits/men/40.jpg'; // default avatar
  }
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with TickerProviderStateMixin {
  late final MapController _mapController;
  final TextEditingController _searchController = TextEditingController();

  LatLng _mapCenter = const LatLng(-34.6037, -58.3816); // Buenos Aires default
  double _mapZoom = 13.5;

  Map<String, dynamic>? _selectedItem;
  String _selectedTypeFilter = 'todos'; // 'todos', 'empresa', 'candidato', 'video'
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredItems = [];

  String _currentCityLabel = 'Ciudad Autónoma de Buenos Aires';
  bool _showCityDropdown = false;
  bool _showHashtagDropdown = false;

  final List<String> _trendingTags = ['React', 'DevOps', 'UX Designer', 'Python', 'Product Manager', 'AWS', 'Figma'];

  LatLng _getLatLng(Map<String, dynamic> item) {
    final lat = item['lat'] as num;
    final lng = item['lng'] as num;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  // Construye un NexUser desde los datos del pin del mapa (para abrir el perfil).
  NexUser _userFromPin(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'Candidato';
    return NexUser(
      id: name,
      name: name,
      headline: item['headline']?.toString() ?? '',
      location: 'Buenos Aires, Argentina',
      avatarUrl: _getItemPhoto(item),
      latitude: (item['lat'] as num?)?.toDouble(),
      longitude: (item['lng'] as num?)?.toDouble(),
      isVerified: item['video'] == true,
      accountType: item['type'] == 'empresa' ? 'empresa' : 'candidato',
    );
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _applyFilters();

    // Select the first company or candidate on load
    if (_filteredItems.isNotEmpty) {
      _selectedItem = _filteredItems.first;
      _mapCenter = _getLatLng(_selectedItem!);
    }
  }

  @override
  void dispose() {
    _cityDebounce?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // Smooth custom map panning animation
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(begin: _mapController.camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: _mapController.camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: _mapController.camera.zoom, end: destZoom);

    final controller = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    final animation = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      if (mounted) {
        _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation),
        );
      }
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  void _applyFilters() {
    final normQuery = normalizeQuery(_searchQuery);
    List<Map<String, dynamic>> results = simCandidates;

    // Text search (by name, headline or city name)
    if (normQuery.isNotEmpty) {
      results = results.where((item) {
        final name = normalizeQuery(item['name'] as String);
        final headline = normalizeQuery(item['headline'] as String);
        return name.contains(normQuery) || headline.contains(normQuery);
      }).toList();
    }

    // Category filter
    if (_selectedTypeFilter == 'empresa') {
      results = results.where((item) => item['type'] == 'empresa').toList();
    } else if (_selectedTypeFilter == 'candidato') {
      results = results.where((item) => item['type'] == 'candidato').toList();
    } else if (_selectedTypeFilter == 'video') {
      results = results.where((item) => item['video'] == true).toList();
    }

    setState(() {
      _filteredItems = results;
    });
  }

  // ── Búsqueda de ciudades (geocoding) ─────────────────────────────────────
  // Antes el desplegable tenía 4 ciudades argentinas hardcodeadas y el buscador
  // filtraba candidatos, no ciudades: escribir "Asunción" no daba nada. Ahora se
  // consulta Nominatim (OpenStreetMap, sin API key) con debounce.

  List<Map<String, dynamic>> _cityResults = [];
  bool _searchingCity = false;
  Timer? _cityDebounce;

  void _onCityQueryChanged(String q) {
    _cityDebounce?.cancel();
    final query = q.trim();
    if (query.length < 3) {
      setState(() {
        _cityResults = [];
        _searchingCity = false;
      });
      return;
    }
    setState(() => _searchingCity = true);
    // Nominatim pide máximo 1 consulta por segundo: se espera a que deje de tipear.
    _cityDebounce = Timer(const Duration(milliseconds: 600), () => _searchCities(query));
  }

  Future<void> _searchCities(String query) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '6',
        'accept-language': 'es',
        'featuretype': 'city',
      });
      // Nominatim exige identificar la app en el User-Agent.
      final res = await http.get(uri, headers: {'User-Agent': 'Mploya/1.0 (contacto@mploya.ai)'});
      if (res.statusCode != 200) {
        if (mounted) setState(() => _searchingCity = false);
        return;
      }
      final list = (jsonDecode(res.body) as List).map((e) {
        final name = (e['display_name'] ?? '').toString();
        final partes = name.split(',');
        final corto = partes.length > 2
            ? '${partes.first.trim()}, ${partes.last.trim()}'
            : name;
        return {
          'label': corto,
          'lat': double.tryParse(e['lat']?.toString() ?? '') ?? 0.0,
          'lon': double.tryParse(e['lon']?.toString() ?? '') ?? 0.0,
        };
      }).where((m) => (m['lat'] as double) != 0.0).toList();
      if (mounted) {
        setState(() {
          _cityResults = list;
          _searchingCity = false;
        });
      }
    } catch (e) {
      debugPrint('Búsqueda de ciudad: $e');
      if (mounted) setState(() => _searchingCity = false);
    }
  }

  /// Centra el mapa en la ubicación real del dispositivo.
  Future<void> _goToMyLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _avisar('Activá el GPS del teléfono para usar esta función.');
        return;
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        _avisar('Necesitamos permiso de ubicación para centrar el mapa.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      _selectCity('Mi ubicación', LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      debugPrint('GPS: $e');
      _avisar('No pudimos obtener tu ubicación.');
    }
  }

  /// Fila del desplegable de ciudades.
  Widget _cityOption(String label, double lat, double lon) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      alignment: Alignment.centerLeft,
      onPressed: () => _selectCity(label, LatLng(lat, lon)),
      child: Row(
        children: [
          const Icon(CupertinoIcons.location, size: 14, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5)),
          ),
        ],
      ),
    );
  }

  void _avisar(String msg) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Ubicación'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _selectCity(String name, LatLng coords) {
    setState(() {
      _currentCityLabel = name;
      _showCityDropdown = false;
      _cityResults = [];
      _searchController.clear();
      _mapCenter = coords;
      _animatedMapMove(coords, 13.0);
      
      // Auto select the closest item in the new city
      _applyFilters();
      if (_filteredItems.isNotEmpty) {
        double minDistance = double.infinity;
        Map<String, dynamic>? closest;
        for (final item in _filteredItems) {
          final dist = haversineKm(
            coords.latitude,
            coords.longitude,
            (item['lat'] as num).toDouble(),
            (item['lng'] as num).toDouble(),
          );
          if (dist < minDistance) {
            minDistance = dist;
            closest = item;
          }
        }
        if (closest != null) {
          _selectedItem = closest;
          _animatedMapMove(_getLatLng(closest), 14.5);
        }
      }
    });
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWebWide(context);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      resizeToAvoidBottomInset: false,
      child: SizedBox.expand(
        child: Stack(
          children: [
            // ── Map background (fills screen) ──
            Positioned.fill(
              child: _buildMap(),
            ),
  
            // ── Web (Desktop) Controls ──
            if (wide) ...[
              _buildWebSearchPanel(context),
              _buildWebCityDropdown(),
              _buildWebHashtagsDropdown(),
              _buildWebBottomCard(),
            ],
  
            // ── Mobile Controls ──
            if (!wide) ...[
              _buildMobileSearchPanel(context),
              _buildMobileBottomDrawer(context),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MAP BUILDER & MARKERS
  // ═══════════════════════════════════════════════════════════════
  // Color del pin según tipo, en hex para Leaflet (web).
  String _pinColorHex(Map<String, dynamic> item) {
    final isCompany = item['type'] == 'empresa';
    final hasVideo = item['video'] == true;
    if (isCompany) return '#185FA5';
    return hasVideo ? '#2563EB' : '#6D48E5';
  }

  Widget _buildMap() {
    // flutter_map no pinta los tiles ni en web (CanvasKit) ni en Android
    // (Impeller/Skia): los descarga pero no los dibuja → mapa gris con pines.
    // Se usa el mismo mapa Leaflet en ambos: iframe (web) / WebView (móvil).
    final pins = _filteredItems
        .map((item) => <String, dynamic>{
              'id': item['name'],
              'lat': (item['lat'] as num).toDouble(),
              'lng': (item['lng'] as num).toDouble(),
              'color': _pinColorHex(item),
              'avatar': _getItemPhoto(item),
            })
        .toList();
    void handlePinTap(String id) {
      final item = _filteredItems.firstWhere(
        (e) => e['name'] == id,
        orElse: () => <String, dynamic>{},
      );
      if (item.isEmpty) return;
      setState(() {
        _selectedItem = item;
        _mapCenter = _getLatLng(item);
        _mapZoom = 14.5;
      });
    }

    final builder = kIsWeb ? buildWebMap : buildMobileMap;
    return builder(
      centerLat: _mapCenter.latitude,
      centerLng: _mapCenter.longitude,
      zoom: _mapZoom,
      pins: pins,
      selectedId: _selectedItem?['name'] as String?,
      onPinTap: handlePinTap,
    );
  }


  // ═══════════════════════════════════════════════════════════════
  // WEB LAYOUT WIDGETS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildWebSearchPanel(BuildContext context) {
    return Positioned(
      top: 24,
      left: 24,
      right: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row of Search bar + Controls
          Row(
            children: [
              // Glassmorphic Search Bar
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 8)),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.search, color: Color(0xFF64748B), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CupertinoTextField(
                              controller: _searchController,
                              placeholder: 'Buscar personas, empresas, ciudades...',
                              placeholderStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                              decoration: null,
                              onChanged: _onSearchChanged,
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              child: const Icon(CupertinoIcons.clear_circled_solid, color: Color(0xFF94A3B8), size: 16),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // "Elegir Ciudad" button
              _buildWebGlassButton(
                onTap: () => setState(() => _showCityDropdown = !_showCityDropdown),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.location_solid, size: 15, color: Color(0xFF185FA5)),
                    const SizedBox(width: 6),
                    Text(
                      _currentCityLabel.length > 20 ? '${_currentCityLabel.substring(0, 18)}...' : _currentCityLabel,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    const Icon(CupertinoIcons.chevron_down, size: 12, color: Color(0xFF64748B)),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // GPS Button
              _buildWebGlassButton(
                onTap: () => _animatedMapMove(const LatLng(-34.6037, -58.3816), 13.5),
                child: const Icon(CupertinoIcons.location_fill, size: 16, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 10),

              // Hashtags Toggle Button
              _buildWebGlassButton(
                onTap: () => setState(() => _showHashtagDropdown = !_showHashtagDropdown),
                child: const Icon(CupertinoIcons.number, size: 16, color: Color(0xFF64748B)),
              ),
            ],
          ),
          
          const SizedBox(height: 12),

          // Filters list
          Row(
            children: [
              _buildFilterChip('todos', 'Todos', CupertinoIcons.compass_fill),
              const SizedBox(width: 8),
              _buildFilterChip('empresa', 'Empresas', CupertinoIcons.building_2_fill),
              const SizedBox(width: 8),
              _buildFilterChip('candidato', 'Candidatos', CupertinoIcons.person_fill),
              const SizedBox(width: 8),
              _buildFilterChip('video', 'Video Pitch', CupertinoIcons.videocam_fill),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebGlassButton({required Widget child, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final active = _selectedTypeFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTypeFilter = key;
        });
        _applyFilters();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF185FA5) : Colors.white.withValues(alpha: 0.80),
              border: Border.all(
                color: active ? const Color(0xFF0C447C) : Colors.white.withValues(alpha: 0.4),
                width: 1,
              ),
              boxShadow: active ? [
                BoxShadow(color: const Color(0xFF185FA5).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2)),
              ] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: active ? Colors.white : const Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebCityDropdown() {
    if (!_showCityDropdown) return const SizedBox.shrink();
    final cities = knownCities.entries.where((e) => e.key == 'buenos aires' || e.key == 'rosario' || e.key == 'cordoba' || e.key == 'mendoza' || e.key == 'montevideo').toList();

    return Positioned(
      top: 80,
      right: 120,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: cities.map((entry) {
                final cityName = entry.key.toUpperCase();
                return CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  alignment: Alignment.centerLeft,
                  onPressed: () => _selectCity(cityName, entry.value),
                  child: Text(
                    cityName,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebHashtagsDropdown() {
    if (!_showHashtagDropdown) return const SizedBox.shrink();

    return Positioned(
      top: 80,
      right: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 250,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Filtros Rápidos (#)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _trendingTags.map((tag) {
                    return CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      minSize: 0,
                      onPressed: () {
                        setState(() {
                          _searchController.text = tag;
                          _searchQuery = tag;
                          _showHashtagDropdown = false;
                        });
                        _applyFilters();
                      },
                      child: Text(
                        '#$tag',
                        style: const TextStyle(color: Color(0xFF334155), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebBottomCard() {
    if (_selectedItem == null) return const SizedBox.shrink();
    final item = _selectedItem!;
    final isCompany = item['type'] == 'empresa';
    final hasVideo = item['video'] == true;
    final match = 80 + (item['name'].hashCode.abs() % 18);
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 460,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: _candidateCardBody(item, isCompany, hasVideo, match),
        ),
      ),
    );
  }

  // Cuerpo compartido de la tarjeta de candidato (web y móvil) — rediseño 24/7.
  Widget _candidateCardBody(Map<String, dynamic> item, bool isCompany, bool hasVideo, int match) {
    const brand = Color(0xFF185FA5);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE6F1FB), width: 2)),
            child: ClipOval(child: CachedNetworkImage(imageUrl: _getItemPhoto(item), fit: BoxFit.cover)),
          ),
          if (hasVideo)
            Positioned(bottom: -2, right: -2, child: Container(
              width: 20, height: 20,
              decoration: BoxDecoration(color: brand, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: const Icon(CupertinoIcons.play_fill, size: 9, color: Colors.white),
            )),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Flexible(child: Text(item['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
            if (!isCompany) ...[const SizedBox(width: 5), const Icon(CupertinoIcons.checkmark_seal_fill, size: 15, color: brand)],
          ]),
          const SizedBox(height: 2),
          Text(item['headline'] as String, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
          const SizedBox(height: 6),
          Row(children: [
            if (hasVideo) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFE6F1FB), borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(CupertinoIcons.video_camera_solid, size: 11, color: Color(0xFF0C447C)),
                  SizedBox(width: 3),
                  Text('Con video', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0C447C))),
                ]),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(CupertinoIcons.location_solid, size: 11, color: Color(0xFF94A3B8)),
            const SizedBox(width: 2),
            const Text('a 0-3 min', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ]),
        ])),
        const SizedBox(width: 8),
        if (!isCompany) Column(children: [
          Text('$match%', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: brand)),
          const Text('match', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ]),
      ]),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 11),
        color: brand,
        borderRadius: BorderRadius.circular(10),
        onPressed: () {
          if (isCompany) {
            Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const VacantesScreen()));
          } else {
            Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: _userFromPin(item))));
          }
        },
        child: Text(isCompany ? 'Ver vacantes' : 'Ver perfil', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
      )),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════
  // MOBILE LAYOUT WIDGETS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMobileSearchPanel(BuildContext context) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Search Input Row with Avatar
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.search, color: Color(0xFF64748B), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CupertinoTextField(
                            controller: _searchController,
                            placeholder: 'Buscar personas, empresas, ciudades...',
                            placeholderStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                            decoration: null,
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        const Icon(CupertinoIcons.mic_fill, color: Color(0xFF64748B), size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Profile Avatar (Top Right)
                GestureDetector(
                  onTap: () => _animatedMapMove(const LatLng(-34.6037, -58.3816), 13.5),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF185FA5), width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6),
                      ],
                    ),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&crop=face',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Location Badge below Search
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showCityDropdown = !_showCityDropdown),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.location_solid, size: 13, color: Color(0xFF185FA5)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Ciudad: $_currentCityLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF334155), fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(CupertinoIcons.chevron_down, size: 10, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Botón GPS: centra el mapa donde está el usuario.
                GestureDetector(
                  onTap: _goToMyLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.location_north_fill, size: 13, color: Color(0xFF185FA5)),
                        SizedBox(width: 4),
                        Text('Mi ubicación',
                            style: TextStyle(
                                color: Color(0xFF334155), fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Buscador de ciudades (cualquier ciudad del mundo, vía Nominatim)
            if (_showCityDropdown)
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: CupertinoTextField(
                        autofocus: true,
                        placeholder: 'Buscar ciudad (ej: Asunción)',
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 10),
                          child: Icon(CupertinoIcons.search, size: 16, color: Color(0xFF94A3B8)),
                        ),
                        suffix: _searchingCity
                            ? const Padding(
                                padding: EdgeInsets.only(right: 10),
                                child: CupertinoActivityIndicator(radius: 8))
                            : null,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        style: const TextStyle(fontSize: 13.5),
                        onChanged: _onCityQueryChanged,
                      ),
                    ),
                    if (_cityResults.isEmpty && !_searchingCity)
                      // Sin búsqueda todavía: atajos a las ciudades más usadas.
                      ...const [
                        {'label': 'Buenos Aires, Argentina', 'lat': -34.6037, 'lon': -58.3816},
                        {'label': 'Córdoba, Argentina', 'lat': -31.4201, 'lon': -64.1888},
                        {'label': 'Rosario, Argentina', 'lat': -32.9468, 'lon': -60.6393},
                        {'label': 'Asunción, Paraguay', 'lat': -25.2637, 'lon': -57.5759},
                        {'label': 'Montevideo, Uruguay', 'lat': -34.9011, 'lon': -56.1645},
                        {'label': 'Santiago, Chile', 'lat': -33.4489, 'lon': -70.6693},
                      ].map((c) => _cityOption(
                          c['label'] as String, c['lat'] as double, c['lon'] as double))
                    else
                      ..._cityResults.map((c) => _cityOption(
                          c['label'] as String, c['lat'] as double, c['lon'] as double)),
                    if (_cityResults.isEmpty && _searchingCity)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(child: CupertinoActivityIndicator()),
                      ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBottomDrawer(BuildContext context) {
    if (_selectedItem == null) return const SizedBox.shrink();
    final item = _selectedItem!;
    final isCompany = item['type'] == 'empresa';
    final hasVideo = item['video'] == true;
    final color = isCompany ? const Color(0xFF185FA5) : (hasVideo ? const Color(0xFF2563EB) : const Color(0xFF6D48E5));

    return Positioned(
      bottom: 80, // Floating safely above the bottom navigation bar
      left: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x18000000), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Safe Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // "Cerca de ti" label
            const Text(
              'Cerca de ti (1)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            _candidateCardBody(item, isCompany, hasVideo, 80 + (item['name'].hashCode.abs() % 18)),
          ],
        ),
      ),
    );
  }
}
