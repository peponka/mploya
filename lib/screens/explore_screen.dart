import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Colors, LinearProgressIndicator, AlwaysStoppedAnimation, CircularProgressIndicator;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../widgets/web_ui.dart';
import '../screens/vacantes_screen.dart';
import 'explore_demo_data.dart';
// Mapa web con Leaflet (flutter_map no pinta tiles en Flutter web/CanvasKit).
import '../widgets/web_map_stub.dart'
    if (dart.library.html) '../widgets/web_map.dart';

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
    if (name.contains('Sofía')) return 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop';
    if (name.contains('Martín')) return 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop';
    if (name.contains('Mariano')) return 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop';
    if (name.contains('Valentina')) return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&h=100&fit=crop';
    if (name.contains('Lucía')) return 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100&h=100&fit=crop';
    if (name.contains('Franco')) return 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop';
    if (name.contains('Camila')) return 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&h=100&fit=crop';
    if (name.contains('Lucas')) return 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=100&h=100&fit=crop';
    return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop'; // default avatar
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

  void _selectCity(String name, LatLng coords) {
    setState(() {
      _currentCityLabel = name;
      _showCityDropdown = false;
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
    if (isCompany) return '#F97316';
    return hasVideo ? '#2563EB' : '#6D48E5';
  }

  Widget _buildMap() {
    // En web, flutter_map no dibuja los tiles (CanvasKit). Usamos Leaflet nativo.
    if (kIsWeb) {
      final pins = _filteredItems
          .map((item) => <String, dynamic>{
                'id': item['name'],
                'lat': (item['lat'] as num).toDouble(),
                'lng': (item['lng'] as num).toDouble(),
                'color': _pinColorHex(item),
                'avatar': _getItemPhoto(item),
              })
          .toList();
      return buildWebMap(
        centerLat: _mapCenter.latitude,
        centerLng: _mapCenter.longitude,
        zoom: _mapZoom,
        pins: pins,
        selectedId: _selectedItem?['name'] as String?,
        onPinTap: (id) {
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
        },
      );
    }
    return FlutterMap(
      options: MapOptions(
        initialCenter: _mapCenter,
        initialZoom: _mapZoom,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      ),
      mapController: _mapController,
      children: [
        TileLayer(
          // OSM (tile.openstreetmap.org) degrada/vacía los tiles en produccion
          // por su politica de uso (bloqueo por Referer) → mapa gris. ArcGIS
          // World_Street_Map sirve el tile completo. OJO: orden {z}/{y}/{x}.
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'ai.mploya.app',
          tileProvider: CancellableNetworkTileProvider(),
        ),
        MarkerLayer(
          markers: _filteredItems.map((item) {
            final isSelected = _selectedItem != null && _selectedItem!['name'] == item['name'];
            return Marker(
              point: _getLatLng(item),
              width: isSelected ? 160 : 42,
              height: isSelected ? 110 : 42,
              alignment: Alignment.bottomCenter,
              child: _buildMapPin(item, isSelected),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMapPin(Map<String, dynamic> item, bool isSelected) {
    final isCompany = item['type'] == 'empresa';
    final hasVideo = item['video'] == true;
    final color = isCompany ? const Color(0xFFF97316) : (hasVideo ? const Color(0xFF2563EB) : const Color(0xFF6D48E5));

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedItem = item;
        });
        _animatedMapMove(_getLatLng(item), 14.5);
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Tooltip above marker
          if (isSelected)
            Positioned(
              bottom: 46,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item['name'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCompany ? 'Empresa · CABA' : (hasVideo ? 'Candidato · Video Pitch' : 'Candidato'),
                      style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          
          // Marker circle pin
          Container(
            width: isSelected ? 42 : 36,
            height: isSelected ? 42 : 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: color, width: isSelected ? 3.0 : 2.0),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: isSelected ? 12 : 6,
                  spreadRadius: isSelected ? 2 : 0,
                ),
              ],
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: _getItemPhoto(item),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(
                  isCompany ? CupertinoIcons.building_2_fill : CupertinoIcons.person_fill,
                  color: color,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
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
                    const Icon(CupertinoIcons.location_solid, size: 15, color: Color(0xFFF97316)),
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
              color: active ? const Color(0xFFF97316) : Colors.white.withValues(alpha: 0.80),
              border: Border.all(
                color: active ? const Color(0xFFEA580C) : Colors.white.withValues(alpha: 0.4),
                width: 1,
              ),
              boxShadow: active ? [
                BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2)),
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
    final color = isCompany ? const Color(0xFFF97316) : (hasVideo ? const Color(0xFF2563EB) : const Color(0xFF6D48E5));

    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.90),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x11000000), blurRadius: 20, offset: Offset(0, 10)),
                ],
              ),
              child: Row(
                children: [
                  // Logo/Photo Avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: _getItemPhoto(item),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // Text details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item['name'] as String,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['headline'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isCompany ? 'EMPRESA' : (hasVideo ? 'CON VIDEO' : 'CANDIDATO'),
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '📍 0 - 3 min',
                              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Action Button
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () {
                      if (isCompany) {
                        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const VacantesScreen()));
                      } else {
                        // Open profile simulator or alert
                        showCupertinoDialog(
                          context: context,
                          builder: (ctx) => CupertinoAlertDialog(
                            title: Text(item['name'] as String),
                            content: Text('${item['headline']}\n\n¿Quieres iniciar una conversación para coordinar una entrevista?'),
                            actions: [
                              CupertinoDialogAction(
                                isDestructiveAction: true,
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancelar'),
                              ),
                              CupertinoDialogAction(
                                isDefaultAction: true,
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Enviar Mensaje'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: Text(
                      isCompany ? 'Ver Vacantes' : 'Ver Perfil',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
                      border: Border.all(color: const Color(0xFFF97316), width: 2),
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
                        const Icon(CupertinoIcons.location_solid, size: 13, color: Color(0xFFF97316)),
                        const SizedBox(width: 4),
                        const Text(
                          'Ciudad: Buenos Aires, Argentina',
                          style: TextStyle(color: Color(0xFF334155), fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 2),
                        const Icon(CupertinoIcons.chevron_down, size: 10, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // City drop down overlay for mobile
            if (_showCityDropdown)
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: Column(
                  children: [
                    'BUENOS AIRES',
                    'ROSARIO',
                    'CORDOBA',
                    'MENDOZA',
                  ].map((city) {
                    return CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      alignment: Alignment.centerLeft,
                      onPressed: () {
                        LatLng coords = const LatLng(-34.6037, -58.3816);
                        if (city == 'ROSARIO') coords = const LatLng(-32.9468, -60.6393);
                        if (city == 'CORDOBA') coords = const LatLng(-31.4201, -64.1888);
                        if (city == 'MENDOZA') coords = const LatLng(-32.8895, -68.8458);
                        _selectCity(city, coords);
                      },
                      child: Text(
                        city,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      ),
                    );
                  }).toList(),
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
    final color = isCompany ? const Color(0xFFF97316) : (hasVideo ? const Color(0xFF2563EB) : const Color(0xFF6D48E5));

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
            
            // Card Content row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: _getItemPhoto(item),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] as String,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCompany ? 'Tecnología · Fintech' : (item['headline'] as String),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(CupertinoIcons.location_solid, size: 10, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              isCompany ? 'Avenida Corrientes 1200, CABA (3 min)' : 'Buenos Aires, AR (A 1.2 km)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 14),
            
            // Full Width Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                color: color,
                borderRadius: BorderRadius.circular(12),
                onPressed: () {
                  if (isCompany) {
                    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const VacantesScreen()));
                  } else {
                    showCupertinoDialog(
                      context: context,
                      builder: (ctx) => CupertinoAlertDialog(
                        title: Text(item['name'] as String),
                        content: Text('${item['headline']}\n\n¿Quieres iniciar una conversación con el candidato?'),
                        actions: [
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          CupertinoDialogAction(
                            isDefaultAction: true,
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Contactar'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: Text(
                  isCompany ? 'Ver Detalles' : 'Ver Detalles del Candidato',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
