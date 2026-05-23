/// Pantalla de exploración con mapa y búsqueda.
///
/// Search bar, filter chips, mapa OpenStreetMap con controles,
/// y bottom sheet draggable con estado vacío.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:mploya/config/theme.dart';

// ─── City Data ───────────────────────────────────────────────────────

class _CityData {
  const _CityData(this.name, this.country, this.latLng);
  final String name;
  final String country;
  final LatLng latLng;
}

const _cities = [
  // ── Latin America ──
  _CityData('Asunción', 'Paraguay', LatLng(-25.2637, -57.5759)),
  _CityData('Buenos Aires', 'Argentina', LatLng(-34.6037, -58.3816)),
  _CityData('São Paulo', 'Brasil', LatLng(-23.5505, -46.6333)),
  _CityData('Río de Janeiro', 'Brasil', LatLng(-22.9068, -43.1729)),
  _CityData('Lima', 'Perú', LatLng(-12.0464, -77.0428)),
  _CityData('Bogotá', 'Colombia', LatLng(4.7110, -74.0721)),
  _CityData('Medellín', 'Colombia', LatLng(6.2442, -75.5812)),
  _CityData('Santiago', 'Chile', LatLng(-33.4489, -70.6693)),
  _CityData('México DF', 'México', LatLng(19.4326, -99.1332)),
  _CityData('Guadalajara', 'México', LatLng(20.6597, -103.3496)),
  _CityData('Monterrey', 'México', LatLng(25.6866, -100.3161)),
  _CityData('Montevideo', 'Uruguay', LatLng(-34.9011, -56.1645)),
  _CityData('Quito', 'Ecuador', LatLng(-0.1807, -78.4678)),
  _CityData('Guayaquil', 'Ecuador', LatLng(-2.1894, -79.8891)),
  _CityData('Caracas', 'Venezuela', LatLng(10.4806, -66.9036)),
  _CityData('La Paz', 'Bolivia', LatLng(-16.4897, -68.1193)),
  _CityData('Santa Cruz', 'Bolivia', LatLng(-17.7833, -63.1822)),
  _CityData('San José', 'Costa Rica', LatLng(9.9281, -84.0907)),
  _CityData('Panamá', 'Panamá', LatLng(8.9824, -79.5199)),
  _CityData('La Habana', 'Cuba', LatLng(23.1136, -82.3666)),
  _CityData('Santo Domingo', 'Rep. Dominicana', LatLng(18.4861, -69.9312)),
  _CityData('Guatemala', 'Guatemala', LatLng(14.6349, -90.5069)),
  _CityData('Tegucigalpa', 'Honduras', LatLng(14.0723, -87.1921)),
  _CityData('Managua', 'Nicaragua', LatLng(12.1150, -86.2362)),
  _CityData('San Salvador', 'El Salvador', LatLng(13.6929, -89.2182)),
  // ── North America ──
  _CityData('New York', 'USA', LatLng(40.7128, -74.0060)),
  _CityData('Los Angeles', 'USA', LatLng(34.0522, -118.2437)),
  _CityData('Chicago', 'USA', LatLng(41.8781, -87.6298)),
  _CityData('Houston', 'USA', LatLng(29.7604, -95.3698)),
  _CityData('Miami', 'USA', LatLng(25.7617, -80.1918)),
  _CityData('San Francisco', 'USA', LatLng(37.7749, -122.4194)),
  _CityData('Washington DC', 'USA', LatLng(38.9072, -77.0369)),
  _CityData('Toronto', 'Canadá', LatLng(43.6532, -79.3832)),
  _CityData('Vancouver', 'Canadá', LatLng(49.2827, -123.1207)),
  _CityData('Montreal', 'Canadá', LatLng(45.5017, -73.5673)),
  // ── Europe ──
  _CityData('Londres', 'Reino Unido', LatLng(51.5074, -0.1278)),
  _CityData('París', 'Francia', LatLng(48.8566, 2.3522)),
  _CityData('Madrid', 'España', LatLng(40.4168, -3.7038)),
  _CityData('Barcelona', 'España', LatLng(41.3851, 2.1734)),
  _CityData('Berlín', 'Alemania', LatLng(52.5200, 13.4050)),
  _CityData('Múnich', 'Alemania', LatLng(48.1351, 11.5820)),
  _CityData('Roma', 'Italia', LatLng(41.9028, 12.4964)),
  _CityData('Milán', 'Italia', LatLng(45.4642, 9.1900)),
  _CityData('Ámsterdam', 'Países Bajos', LatLng(52.3676, 4.9041)),
  _CityData('Bruselas', 'Bélgica', LatLng(50.8503, 4.3517)),
  _CityData('Lisboa', 'Portugal', LatLng(38.7223, -9.1393)),
  _CityData('Viena', 'Austria', LatLng(48.2082, 16.3738)),
  _CityData('Zúrich', 'Suiza', LatLng(47.3769, 8.5417)),
  _CityData('Estocolmo', 'Suecia', LatLng(59.3293, 18.0686)),
  _CityData('Oslo', 'Noruega', LatLng(59.9139, 10.7522)),
  _CityData('Copenhague', 'Dinamarca', LatLng(55.6761, 12.5683)),
  _CityData('Helsinki', 'Finlandia', LatLng(60.1699, 24.9384)),
  _CityData('Dublín', 'Irlanda', LatLng(53.3498, -6.2603)),
  _CityData('Varsovia', 'Polonia', LatLng(52.2297, 21.0122)),
  _CityData('Praga', 'Chequia', LatLng(50.0755, 14.4378)),
  _CityData('Budapest', 'Hungría', LatLng(47.4979, 19.0402)),
  _CityData('Bucarest', 'Rumanía', LatLng(44.4268, 26.1025)),
  _CityData('Atenas', 'Grecia', LatLng(37.9838, 23.7275)),
  _CityData('Moscú', 'Rusia', LatLng(55.7558, 37.6173)),
  _CityData('Estambul', 'Turquía', LatLng(41.0082, 28.9784)),
  // ── Asia ──
  _CityData('Tokio', 'Japón', LatLng(35.6762, 139.6503)),
  _CityData('Osaka', 'Japón', LatLng(34.6937, 135.5023)),
  _CityData('Seúl', 'Corea del Sur', LatLng(37.5665, 126.9780)),
  _CityData('Pekín', 'China', LatLng(39.9042, 116.4074)),
  _CityData('Shanghái', 'China', LatLng(31.2304, 121.4737)),
  _CityData('Hong Kong', 'China', LatLng(22.3193, 114.1694)),
  _CityData('Singapur', 'Singapur', LatLng(1.3521, 103.8198)),
  _CityData('Bangkok', 'Tailandia', LatLng(13.7563, 100.5018)),
  _CityData('Kuala Lumpur', 'Malasia', LatLng(3.1390, 101.6869)),
  _CityData('Yakarta', 'Indonesia', LatLng(-6.2088, 106.8456)),
  _CityData('Manila', 'Filipinas', LatLng(14.5995, 120.9842)),
  _CityData('Hanói', 'Vietnam', LatLng(21.0278, 105.8342)),
  _CityData('Mumbai', 'India', LatLng(19.0760, 72.8777)),
  _CityData('Nueva Delhi', 'India', LatLng(28.6139, 77.2090)),
  _CityData('Bangalore', 'India', LatLng(12.9716, 77.5946)),
  _CityData('Taipéi', 'Taiwán', LatLng(25.0330, 121.5654)),
  // ── Middle East ──
  _CityData('Dubái', 'EAU', LatLng(25.2048, 55.2708)),
  _CityData('Abu Dabi', 'EAU', LatLng(24.4539, 54.3773)),
  _CityData('Riad', 'Arabia Saudita', LatLng(24.7136, 46.6753)),
  _CityData('Doha', 'Catar', LatLng(25.2854, 51.5310)),
  _CityData('Tel Aviv', 'Israel', LatLng(32.0853, 34.7818)),
  _CityData('Beirut', 'Líbano', LatLng(33.8938, 35.5018)),
  _CityData('Ammán', 'Jordania', LatLng(31.9454, 35.9284)),
  // ── Africa ──
  _CityData('El Cairo', 'Egipto', LatLng(30.0444, 31.2357)),
  _CityData('Lagos', 'Nigeria', LatLng(6.5244, 3.3792)),
  _CityData('Nairobi', 'Kenia', LatLng(-1.2921, 36.8219)),
  _CityData('Ciudad del Cabo', 'Sudáfrica', LatLng(-33.9249, 18.4241)),
  _CityData('Johannesburgo', 'Sudáfrica', LatLng(-26.2041, 28.0473)),
  _CityData('Casablanca', 'Marruecos', LatLng(33.5731, -7.5898)),
  _CityData('Accra', 'Ghana', LatLng(5.6037, -0.1870)),
  _CityData('Addis Abeba', 'Etiopía', LatLng(9.0250, 38.7469)),
  // ── Oceania ──
  _CityData('Sídney', 'Australia', LatLng(-33.8688, 151.2093)),
  _CityData('Melbourne', 'Australia', LatLng(-37.8136, 144.9631)),
  _CityData('Auckland', 'Nueva Zelanda', LatLng(-36.8485, 174.7633)),
];

// ─── Mock Company Data ───────────────────────────────────────────────

class _CompanyMarker {
  const _CompanyMarker(this.name, this.role, this.latLng, this.initial, this.type);
  final String name;
  final String role;
  final LatLng latLng;
  final String initial;
  final String type; // 'Empresa' | 'Startup'
}

// Companies near Buenos Aires (default city)
const _mockCompanies = [
  _CompanyMarker('Globant', 'Hiring Product Managers', LatLng(-34.5970, -58.3730), 'G', 'Empresa'),
  _CompanyMarker('Mercado Libre', 'Busca Desarrolladores', LatLng(-34.6290, -58.3700), 'M', 'Empresa'),
  _CompanyMarker('TiendaNube', 'UX Designer', LatLng(-34.5600, -58.4600), 'T', 'Startup'),
  _CompanyMarker('Despegar', 'Data Engineer', LatLng(-34.6100, -58.3900), 'D', 'Empresa'),
  _CompanyMarker('Auth0', 'Backend Engineer', LatLng(-34.5850, -58.4200), 'A', 'Startup'),
  _CompanyMarker('Ualá', 'Mobile Developer', LatLng(-34.6200, -58.3650), 'U', 'Startup'),
];

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  int _selectedChip = 1; // 'Ciudad' selected by default
  bool _isSaved = false;
  _CityData _selectedCity = _cities[0]; // Asunción by default
  late final MapController _mapController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  bool _showGpsBanner = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    // Proteger dispose del MapController para evitar lifecycle errors
    try {
      _mapController.dispose();
    } catch (e) {
      debugPrint('⚠️ MapController dispose error: $e');
    }
    try {
      _sheetController.dispose();
    } catch (e) {
      debugPrint('⚠️ SheetController dispose error: $e');
    }
    super.dispose();
  }

  void _onCiudadTap() {
    setState(() => _selectedChip = 1);
    _showCityPicker();
  }

  void _showCityPicker() {
    showModalBottomSheet<_CityData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MployaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (ctx) {
        return _CitySearchSheet(
          selectedCity: _selectedCity,
          fallbackCities: _cities.toList(),
        );
      },
    ).then((city) {
      if (city != null) {
        setState(() => _selectedCity = city);
        _mapController.move(city.latLng, 13.0);
      }
    });
  }

  void _toggleSaved() {
    setState(() => _isSaved = !_isSaved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: GestureDetector(
                onTap: () {
                  showSearch(
                    context: context,
                    delegate: _ExploreSearchDelegate(),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: MployaColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: MployaColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: MployaColors.textTertiary,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Buscar personas, empresas, ciudades...',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: MployaColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms),

            // ── Filter chips row ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: Row(
                children: [
                  _FilterChip(
                    label: '📍 Cerca',
                    isSelected: _selectedChip == 0,
                    onTap: () => setState(() => _selectedChip = 0),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FilterChip(
                    label: '🏙 Ciudad',
                    isSelected: _selectedChip == 1,
                    onTap: _onCiudadTap,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FilterChip(
                    label: '🌍 Todos',
                    isSelected: _selectedChip == 2,
                    onTap: () => setState(() => _selectedChip = 2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // # button
                  GestureDetector(
                    onTap: () => context.push('/hashtags/trending'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: MployaColors.orange,
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Center(
                        child: Text(
                          '#',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: MployaColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 400.ms),

            const SizedBox(height: AppSpacing.sm),

            // ── Map area + draggable bottom sheet ──
            Expanded(
              child: Stack(
                children: [
                  // ── OpenStreetMap ──
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedCity.latLng,
                      initialZoom: 13.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.mploya.app',
                      ),
                      // User location marker
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedCity.latLng,
                            width: 56,
                            height: 70,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: MployaColors.orange
                                        .withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: MployaColors.orange,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: MployaColors.white,
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: MployaColors.orange
                                                .withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Company markers on map
                      MarkerLayer(
                        markers: _mockCompanies.map((company) {
                          return Marker(
                            point: company.latLng,
                            width: 44,
                            height: 56,
                            child: GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${company.name} · ${company.role}',
                                      style: GoogleFonts.inter(),
                                    ),
                                    backgroundColor: MployaColors.orange,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                    ),
                                  ),
                                );
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1),
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      border: Border.all(
                                        color: MployaColors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF6366F1)
                                              .withValues(alpha: 0.4),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.business_rounded,
                                        color: MployaColors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: MployaColors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      company.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        color: MployaColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  // City label overlay
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 64),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: MployaColors.white,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.xs),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _selectedCity.name,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: MployaColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Map controls (right side)
                  Positioned(
                    right: AppSpacing.md,
                    bottom: 180,
                    child: Column(
                      children: [
                        _MapControlButton(
                          icon: Icons.my_location,
                          onTap: () {
                            _mapController.move(
                                _selectedCity.latLng, 13.0);
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MapControlButton(
                          icon: Icons.add,
                          onTap: () {
                            final zoom = _mapController.camera.zoom + 1;
                            _mapController.move(
                                _mapController.camera.center, zoom);
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MapControlButton(
                          icon: Icons.remove,
                          onTap: () {
                            final zoom = _mapController.camera.zoom - 1;
                            _mapController.move(
                                _mapController.camera.center, zoom);
                          },
                        ),
                      ],
                    ),
                  ),

                  // ── GPS Banner ──
                  if (_showGpsBanner)
                    Positioned(
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      bottom: 190,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: MployaColors.textPrimary.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.wifi_off_rounded,
                                    color: MployaColors.white, size: 18),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Sin GPS · Seleccioná tu ciudad',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: MployaColors.white,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _showGpsBanner = false),
                                  child: const Icon(Icons.close,
                                      color: MployaColors.white, size: 18),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _showCityPicker,
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: MployaColors.orange,
                                        borderRadius: BorderRadius.circular(AppRadius.pill),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Elegir Ciudad',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: MployaColors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _showGpsBanner = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.gps_fixed, color: MployaColors.white, size: 18),
                                              const SizedBox(width: AppSpacing.sm),
                                              Text(
                                                'Ubicación activada · Buenos Aires',
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: MployaColors.teal,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.md),
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: MployaColors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(AppRadius.pill),
                                        border: Border.all(
                                          color: MployaColors.white.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Activar GPS',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: MployaColors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms).slideY(
                            begin: 0.3, end: 0, duration: 300.ms),
                    ),

                  // ── Draggable bottom sheet ──
                  DraggableScrollableSheet(
                    controller: _sheetController,
                    initialChildSize: 0.25,
                    minChildSize: 0.08,
                    maxChildSize: 0.75,
                    snap: true,
                    snapSizes: const [0.08, 0.25, 0.5, 0.75],
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: MployaColors.white,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppRadius.xxl),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: ListView(
                          controller: scrollController,
                          padding: EdgeInsets.zero,
                          children: [
                            // Drag handle
                            const SizedBox(height: AppSpacing.sm),
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: MployaColors.border,
                                  borderRadius: BorderRadius.circular(
                                      AppRadius.pill),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Header row
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Cerca de ti · ${_mockCompanies.length}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: MployaColors.textPrimary,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _toggleSaved,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                          milliseconds: 200),
                                      transitionBuilder:
                                          (child, animation) {
                                        return ScaleTransition(
                                          scale: animation,
                                          child: child,
                                        );
                                      },
                                      child: Icon(
                                        _isSaved
                                            ? Icons.bookmark
                                            : Icons.bookmark_outline,
                                        key: ValueKey(_isSaved),
                                        color: _isSaved
                                            ? MployaColors.orange
                                            : MployaColors.textTertiary,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppSpacing.sm),

                            // Company cards
                            ..._mockCompanies.map((company) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: MployaColors.white,
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.lg),
                                    border: Border.all(
                                        color:
                                            MployaColors.borderLight),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Company avatar
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                        ),
                                        child: Center(
                                          child: Text(
                                            company.initial,
                                            style: GoogleFonts.outfit(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF6366F1),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      // Company info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  company.name,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: MployaColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: company.type == 'Startup'
                                                        ? MployaColors.teal.withValues(alpha: 0.1)
                                                        : MployaColors.blue.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    company.type,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: company.type == 'Startup'
                                                          ? MployaColors.teal
                                                          : MployaColors.blue,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              company.role,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: MployaColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Arrow
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: MployaColors.textTertiary,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter Chip ─────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? MployaColors.orange : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? MployaColors.orange : MployaColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? MployaColors.white
                : MployaColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ─── Map Control Button ──────────────────────────────────────────────

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: MployaColors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: MployaColors.textPrimary, size: 20),
      ),
    );
  }
}

// ─── Search Delegate ─────────────────────────────────────────────────

class _ExploreSearchDelegate extends SearchDelegate<String> {
  _ExploreSearchDelegate() : super(searchFieldLabel: 'Buscar personas, empresas...');

  static const _suggestions = [
    'Desarrollador Flutter',
    'Diseñador UX/UI',
    'Product Manager',
    'Analista Financiero',
    'Data Scientist',
    'Marketing Digital',
    'Ingeniero de Software',
    'Recursos Humanos',
  ];

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Center(
      child: Text(
        'Resultados para "$query"',
        style: GoogleFonts.inter(fontSize: 16, color: MployaColors.textSecondary),
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filtered = _suggestions
        .where((s) => s.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        return ListTile(
          leading: const Icon(Icons.search, color: MployaColors.textTertiary),
          title: Text(filtered[i]),
          onTap: () {
            query = filtered[i];
            showResults(context);
          },
        );
      },
    );
  }
}

// ─── City Search Sheet (Nominatim) ───────────────────────────────────

class _CitySearchSheet extends StatefulWidget {
  const _CitySearchSheet({
    required this.selectedCity,
    required this.fallbackCities,
  });

  final _CityData selectedCity;
  final List<_CityData> fallbackCities;

  @override
  State<_CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<_CitySearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<_CityData> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _results = widget.fallbackCities.take(15).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();

    if (query.trim().length < 2) {
      setState(() {
        _results = widget.fallbackCities.take(15).toList();
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchNominatim(query.trim());
    });
  }

  Future<void> _searchNominatim(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&addressdetails=1'
        '&limit=15'
        '&featuretype=city',
      );

      final response = await http.get(uri, headers: {
        'Accept-Language': 'es',
        'User-Agent': 'mploya-app/1.0',
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final cities = <_CityData>[];

        for (final item in data) {
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          if (lat == null || lon == null) continue;

          final address = item['address'] as Map<String, dynamic>? ?? {};
          final cityName = item['display_name']?.toString().split(',').first ?? '';
          final country = address['country']?.toString() ??
              item['display_name']?.toString().split(',').last.trim() ??
              '';

          if (cityName.isNotEmpty) {
            cities.add(_CityData(cityName, country, LatLng(lat, lon)));
          }
        }

        setState(() {
          _results = cities;
          _isLoading = false;
          _hasSearched = true;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasSearched = true;
        });
      }
    }
  }

  // Popular cities for quick-access chips
  static const _popularCityNames = [
    'Buenos Aires',
    'New York',
    'Londres',
    'São Paulo',
    'Madrid',
    'México DF',
    'Bogotá',
    'Miami',
  ];

  @override
  Widget build(BuildContext context) {
    final showPopularCities =
        _controller.text.trim().isEmpty && !_hasSearched;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // ── Drag handle ──
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: MployaColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Title ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Elegir ciudad',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: MployaColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // Close button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: MployaColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Search field (iOS style) ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7), // iOS system gray 6
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: MployaColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar ciudad en el mundo...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: MployaColors.textTertiary,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 6),
                      child: Icon(
                        Icons.search_rounded,
                        color: MployaColors.textTertiary
                            .withValues(alpha: 0.7),
                        size: 22,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 0,
                    ),
                    suffixIcon: _isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: MployaColors.orange
                                    .withValues(alpha: 0.8),
                              ),
                            )
                                .animate(
                                    onPlay: (c) => c.repeat())
                                .shimmer(
                                  duration: 1200.ms,
                                  color: MployaColors.orangeLight
                                      .withValues(alpha: 0.3),
                                ),
                          )
                        : _controller.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _controller.clear();
                                  _onQueryChanged('');
                                },
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: MployaColors.textTertiary
                                        .withValues(alpha: 0.25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: MployaColors.white,
                                  ),
                                ),
                              )
                            : null,
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 0,
                    ),
                  ),
                  onChanged: _onQueryChanged,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: -0.05, end: 0, duration: 300.ms),

            const SizedBox(height: AppSpacing.sm),

            // ── Popular cities chips (shown when search is empty) ──
            if (showPopularCities)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    child: Text(
                      'Ciudades populares',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MployaColors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      itemCount: _popularCityNames.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (ctx, i) {
                        final name = _popularCityNames[i];
                        // Find the matching city data
                        final cityData =
                            widget.fallbackCities.cast<_CityData?>().firstWhere(
                                  (c) => c!.name == name,
                                  orElse: () => null,
                                );
                        final isActive =
                            name == widget.selectedCity.name;

                        return GestureDetector(
                          onTap: () {
                            if (cityData != null) {
                              Navigator.pop(ctx, cityData);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? MployaColors.orange
                                  : MployaColors.white,
                              borderRadius: BorderRadius.circular(
                                  AppRadius.pill),
                              border: Border.all(
                                color: isActive
                                    ? MployaColors.orange
                                    : MployaColors.border,
                              ),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: MployaColors.orange
                                            .withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: isActive
                                      ? MployaColors.white
                                      : MployaColors.orange,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isActive
                                        ? MployaColors.white
                                        : MployaColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(
                              delay: Duration(milliseconds: 50 * i),
                              duration: 300.ms,
                            )
                            .slideX(
                              begin: 0.15,
                              end: 0,
                              delay: Duration(milliseconds: 50 * i),
                              duration: 300.ms,
                              curve: Curves.easeOut,
                            );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Divider(
                      color: MployaColors.borderLight,
                      height: 1,
                    ),
                  ),
                ],
              ),

            // ── Results list / Empty state ──
            Expanded(
              child: _results.isEmpty && _hasSearched
                  // ── Empty state ──
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: MployaColors.surfaceVariant,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_off_rounded,
                              size: 32,
                              color: MployaColors.textTertiary
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'No se encontraron ciudades',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: MployaColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Intentá con otro nombre o revisá\nla ortografía',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: MployaColors.textTertiary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          end: const Offset(1, 1),
                          duration: 400.ms,
                          curve: Curves.easeOut,
                        )
                  // ── Results list ──
                  : ListView.builder(
                      itemCount: _results.length,
                      padding: const EdgeInsets.only(
                        top: AppSpacing.sm,
                        bottom: AppSpacing.xxl,
                      ),
                      itemBuilder: (ctx, i) {
                        final city = _results[i];
                        final isActive =
                            city.name == widget.selectedCity.name;

                        return GestureDetector(
                          onTap: () => Navigator.pop(ctx, city),
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? MployaColors.orangeSurface
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: i < _results.length - 1
                                      ? MployaColors.borderLight
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  // Left: pin icon in circle
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? MployaColors.orange
                                              .withValues(alpha: 0.15)
                                          : MployaColors.orangeSurface,
                                      borderRadius:
                                          BorderRadius.circular(
                                              AppRadius.md),
                                    ),
                                    child: Icon(
                                      Icons.location_on_rounded,
                                      color: isActive
                                          ? MployaColors.orange
                                          : MployaColors.orangeLight,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),

                                  // Center: city name + country
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          city.name,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isActive
                                                ? MployaColors.orangeDark
                                                : MployaColors
                                                    .textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          city.country,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: MployaColors
                                                .textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),

                                  // Right: checkmark or chevron
                                  if (isActive)
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: const BoxDecoration(
                                        color: MployaColors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: MployaColors.white,
                                        size: 16,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: MployaColors.textTertiary
                                          .withValues(alpha: 0.5),
                                      size: 22,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(
                              delay: Duration(
                                  milliseconds: 30 * i.clamp(0, 15)),
                              duration: 350.ms,
                            )
                            .slideX(
                              begin: 0.03,
                              end: 0,
                              delay: Duration(
                                  milliseconds: 30 * i.clamp(0, 15)),
                              duration: 350.ms,
                              curve: Curves.easeOut,
                            );
                      },
                    ),
            ),

            // ── Bottom: Powered by OpenStreetMap ──
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: MployaColors.borderLight,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.public_rounded,
                    size: 12,
                    color:
                        MployaColors.textTertiary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Powered by OpenStreetMap',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: MployaColors.textTertiary
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
