/// Pantalla de exploración con mapa y búsqueda.
///
/// Search bar, filter chips, mapa OpenStreetMap con controles,
/// y bottom sheet draggable con estado vacío.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/core/services/location_service.dart';
import 'package:mploya/core/utils/responsive.dart';

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

// Companies pool – a large set that gets shuffled/filtered per city
const _allCompanies = [
  // ── LATAM ──
  _CompanyMarker('Globant',       'Hiring Product Managers', LatLng(0, 0), 'G', 'Empresa'),
  _CompanyMarker('Mercado Libre', 'Busca Desarrolladores',   LatLng(0, 0), 'M', 'Empresa'),
  _CompanyMarker('TiendaNube',    'UX Designer',             LatLng(0, 0), 'T', 'Startup'),
  _CompanyMarker('Despegar',      'Data Engineer',           LatLng(0, 0), 'D', 'Empresa'),
  _CompanyMarker('Auth0',         'Backend Engineer',        LatLng(0, 0), 'A', 'Startup'),
  _CompanyMarker('Ualá',          'Mobile Developer',        LatLng(0, 0), 'U', 'Startup'),
  // ── Tech global ──
  _CompanyMarker('Rappi',         'Growth Analyst',          LatLng(0, 0), 'R', 'Startup'),
  _CompanyMarker('Nubank',        'Frontend Engineer',       LatLng(0, 0), 'N', 'Startup'),
  _CompanyMarker('Kavak',         'Ops Manager',             LatLng(0, 0), 'K', 'Empresa'),
  _CompanyMarker('Cornershop',    'Android Developer',       LatLng(0, 0), 'C', 'Startup'),
  _CompanyMarker('Crehana',       'Content Strategist',      LatLng(0, 0), 'C', 'Startup'),
  _CompanyMarker('dLocal',        'DevOps Engineer',         LatLng(0, 0), 'D', 'Empresa'),
  _CompanyMarker('Wizeline',      'Full Stack Developer',    LatLng(0, 0), 'W', 'Empresa'),
  _CompanyMarker('Gorilla Logic', 'QA Automation',           LatLng(0, 0), 'G', 'Empresa'),
  _CompanyMarker('Lemon Cash',    'Blockchain Developer',    LatLng(0, 0), 'L', 'Startup'),
  _CompanyMarker('Vercel',        'Solutions Engineer',      LatLng(0, 0), 'V', 'Startup'),
  _CompanyMarker('Mundi',         'Data Scientist',          LatLng(0, 0), 'M', 'Startup'),
  _CompanyMarker('Clip',          'Product Designer',        LatLng(0, 0), 'C', 'Empresa'),
  _CompanyMarker('Bitso',         'Crypto Engineer',         LatLng(0, 0), 'B', 'Startup'),
  _CompanyMarker('Konfio',        'Risk Analyst',            LatLng(0, 0), 'K', 'Empresa'),
];

// ─── Global Hub Data (para vista "Todos") ────────────────────────────

class _GlobalHub {
  const _GlobalHub({
    required this.city,
    required this.country,
    required this.latLng,
    required this.jobCount,
    required this.topCompany,
    required this.color,
  });
  final String city;
  final String country;
  final LatLng latLng;
  final int jobCount;
  final String topCompany;
  final Color color;
}

const _globalHubs = [
  // ── Sudamérica ──
  _GlobalHub(city: 'Buenos Aires', country: 'AR', latLng: LatLng(-34.60, -58.38), jobCount: 847, topCompany: 'Mercado Libre', color: Color(0xFFFF6B35)),
  _GlobalHub(city: 'São Paulo', country: 'BR', latLng: LatLng(-23.55, -46.63), jobCount: 1230, topCompany: 'Nubank', color: Color(0xFF8B5CF6)),
  _GlobalHub(city: 'Bogotá', country: 'CO', latLng: LatLng(4.71, -74.07), jobCount: 412, topCompany: 'Rappi', color: Color(0xFFFF6B35)),
  _GlobalHub(city: 'Santiago', country: 'CL', latLng: LatLng(-33.45, -70.67), jobCount: 298, topCompany: 'Cornershop', color: Color(0xFF06B6D4)),
  _GlobalHub(city: 'Lima', country: 'PE', latLng: LatLng(-12.05, -77.04), jobCount: 189, topCompany: 'Crehana', color: Color(0xFF06B6D4)),
  _GlobalHub(city: 'Medellín', country: 'CO', latLng: LatLng(6.24, -75.58), jobCount: 267, topCompany: 'Globant', color: Color(0xFF10B981)),
  _GlobalHub(city: 'Montevideo', country: 'UY', latLng: LatLng(-34.90, -56.16), jobCount: 134, topCompany: 'dLocal', color: Color(0xFF06B6D4)),
  _GlobalHub(city: 'Asunción', country: 'PY', latLng: LatLng(-25.26, -57.58), jobCount: 56, topCompany: 'Penguin', color: Color(0xFF10B981)),
  // ── Centroamérica & Caribe ──
  _GlobalHub(city: 'México DF', country: 'MX', latLng: LatLng(19.43, -99.13), jobCount: 920, topCompany: 'Kavak', color: Color(0xFF8B5CF6)),
  _GlobalHub(city: 'Guadalajara', country: 'MX', latLng: LatLng(20.66, -103.35), jobCount: 345, topCompany: 'Wizeline', color: Color(0xFFFF6B35)),
  _GlobalHub(city: 'San José', country: 'CR', latLng: LatLng(9.93, -84.09), jobCount: 178, topCompany: 'Gorilla Logic', color: Color(0xFF10B981)),
  // ── Norteamérica ──
  _GlobalHub(city: 'New York', country: 'US', latLng: LatLng(40.71, -74.01), jobCount: 3420, topCompany: 'Google', color: Color(0xFFEF4444)),
  _GlobalHub(city: 'San Francisco', country: 'US', latLng: LatLng(37.77, -122.42), jobCount: 2890, topCompany: 'Meta', color: Color(0xFFEF4444)),
  _GlobalHub(city: 'Miami', country: 'US', latLng: LatLng(25.76, -80.19), jobCount: 780, topCompany: 'Stripe', color: Color(0xFF8B5CF6)),
  _GlobalHub(city: 'Toronto', country: 'CA', latLng: LatLng(43.65, -79.38), jobCount: 560, topCompany: 'Shopify', color: Color(0xFFEF4444)),
  // ── Europa (para dar escala global) ──
  _GlobalHub(city: 'Londres', country: 'UK', latLng: LatLng(51.51, -0.13), jobCount: 2100, topCompany: 'DeepMind', color: Color(0xFFEF4444)),
  _GlobalHub(city: 'Berlín', country: 'DE', latLng: LatLng(52.52, 13.41), jobCount: 890, topCompany: 'Zalando', color: Color(0xFF8B5CF6)),
  _GlobalHub(city: 'Madrid', country: 'ES', latLng: LatLng(40.42, -3.70), jobCount: 430, topCompany: 'Cabify', color: Color(0xFFFF6B35)),
];

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  int _selectedChip = 1; // 'Ciudad' selected by default
  bool _isSaved = false;
  bool _hasCitySelected = false;
  final LocationService _locationService = LocationService();
  bool _isLoadingLocation = false;
  _CityData _selectedCity = _cities[0]; // fallback
  late final MapController _mapController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // ── City-reactive companies ──
  List<_CompanyMarker> _currentCompanies = [];

  List<_CompanyMarker> _getCompaniesForCity(_CityData city) {
    final seed = city.name.hashCode;
    final rng = math.Random(seed);
    // Shuffle the pool deterministically per city
    final pool = List<_CompanyMarker>.from(_allCompanies);
    pool.shuffle(rng);
    // Pick 4-7 companies for this city
    final count = 4 + rng.nextInt(4);
    final selected = pool.take(count.clamp(1, pool.length)).toList();
    // Assign positions scattered around the city center
    return selected.map((c) {
      final latOff = (rng.nextDouble() - 0.5) * 0.08;
      final lngOff = (rng.nextDouble() - 0.5) * 0.10;
      return _CompanyMarker(
        c.name,
        c.role,
        LatLng(city.latLng.latitude + latOff, city.latLng.longitude + lngOff),
        c.initial,
        c.type,
      );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCompanies = _getCompaniesForCity(_selectedCity);
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
        setState(() {
          _selectedCity = city;
          _hasCitySelected = true;
          _currentCompanies = _getCompaniesForCity(city);
        });
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
            // ── Location pill + filter chips row ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  // Location pill (replaces Ciudad chip + GPS banner)
                  GestureDetector(
                    onTap: () {
                      _onCiudadTap();
                    },
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedChip == 1
                            ? MployaColors.orange
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: _selectedChip == 1
                              ? MployaColors.orange
                              : MployaColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: _selectedChip == 1
                                ? MployaColors.white
                                : MployaColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            _hasCitySelected ? _selectedCity.name : 'Elegir ciudad',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _selectedChip == 1
                                  ? MployaColors.white
                                  : MployaColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: _selectedChip == 1
                                ? MployaColors.white.withValues(alpha: 0.8)
                                : MployaColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FilterChip(
                    label: '📍 Cerca',
                    isSelected: _selectedChip == 0,
                    onTap: () {
                      setState(() => _selectedChip = 0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.gps_fixed,
                                  color: MployaColors.white, size: 16),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Ubicación activada',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: MployaColors.teal,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FilterChip(
                    label: '🌍 Todos',
                    isSelected: _selectedChip == 2,
                    onTap: () {
                      setState(() => _selectedChip = 2);
                      // Zoom out a Sudamérica
                      _mapController.move(
                        const LatLng(-15.0, -60.0),
                        3.5,
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // # button
                  GestureDetector(
                    onTap: () => context.push('/hashtags/trending'),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: MployaColors.orange,
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Center(
                        child: Text(
                          '#',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: MployaColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // GPS button — siempre vuelve a la ubicación "home"
                  GestureDetector(
                    onTap: () async {
                      setState(() => _isLoadingLocation = true);
                      final location = await _locationService.getCurrentLocation();
                      if (!mounted) return;
                      setState(() => _isLoadingLocation = false);
                      
                      if (location != null) {
                        // Find nearest city from our list
                        _CityData nearestCity = _cities[0];
                        double minDist = double.infinity;
                        for (final city in _cities) {
                          final dist = _locationService.distanceTo(location, city.latLng);
                          if (dist < minDist) {
                            minDist = dist;
                            nearestCity = city;
                          }
                        }
                        setState(() {
                          _selectedCity = nearestCity;
                          _selectedChip = 0;
                          _hasCitySelected = true;
                          _currentCompanies = _getCompaniesForCity(nearestCity);
                        });
                        _mapController.move(location, 13.0);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.gps_fixed,
                                    color: MployaColors.white, size: 16),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  '📍 GPS · ${nearestCity.name} (${minDist.toStringAsFixed(1)} km)',
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
                      } else {
                        // GPS failed - show error
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.gps_off,
                                    color: MployaColors.white, size: 16),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'No se pudo obtener ubicación',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: MployaColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: MployaColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isLoadingLocation
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: MployaColors.textSecondary,
                                  ),
                                )
                              : const Icon(
                                  Icons.gps_fixed_rounded,
                                  size: 15,
                                  color: MployaColors.textSecondary,
                                ),
                          const SizedBox(width: 4),
                          Text(
                            _isLoadingLocation ? '...' : 'GPS',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: MployaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 400.ms),

            const SizedBox(height: AppSpacing.sm),

            // ── Map area + results ──
            Expanded(
              child: isDesktop(context)
                  ? _buildDesktopLayout()
                  : _buildMobileLayout(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Desktop: Map (60%) + Side Panel (40%) ──
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left: Map
        Expanded(
          flex: 6,
          child: Stack(
            children: [
              _buildMapWidget(),
              // Map controls (right side)
              Positioned(
                right: 16,
                bottom: 24,
                child: Column(
                  children: [
                    _MapControlButton(
                      icon: Icons.my_location,
                      onTap: () {
                        _mapController.move(_selectedCity.latLng, 13.0);
                      },
                    ),
                    const SizedBox(height: 6),
                    _MapControlButton(
                      icon: Icons.add,
                      onTap: () {
                        final zoom = _mapController.camera.zoom + 1;
                        _mapController.move(
                            _mapController.camera.center, zoom);
                      },
                    ),
                    const SizedBox(height: 6),
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
            ],
          ),
        ),
        // Right: Results side panel
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              color: MployaColors.white,
              border: Border(
                left: BorderSide(
                  color: MployaColors.borderLight,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _selectedChip == 2
                              ? '🌍 Hubs globales · ${_globalHubs.length}'
                              : 'Empresas cercanas · ${_currentCompanies.length}',
                          key: ValueKey('desktop_header_$_selectedChip'),
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: MployaColors.textPrimary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _toggleSaved,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) {
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
                Divider(
                  height: 1,
                  color: MployaColors.borderLight,
                ),
                // Scrollable list
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    children: [
                      if (_selectedChip == 2)
                        ..._globalHubs.map((hub) {
                          final jobLabel = hub.jobCount >= 1000
                              ? '${(hub.jobCount / 1000).toStringAsFixed(1)}k'
                              : '${hub.jobCount}';
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.xs,
                            ),
                            child: GestureDetector(
                              onTap: () {
                                _mapController.move(hub.latLng, 12.0);
                                setState(() => _selectedChip = 1);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: MployaColors.white,
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  border: Border.all(color: MployaColors.borderLight),
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
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: hub.color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                      ),
                                      child: Center(
                                        child: Text(
                                          jobLabel,
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: hub.color,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                hub.city,
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: MployaColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                hub.country,
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: MployaColors.textTertiary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '🏢 ${hub.topCompany} + ${hub.jobCount - 1} más',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: MployaColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: MployaColors.textTertiary,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        })
                      else
                        ..._currentCompanies.map((company) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.xs,
                            ),
                            child: GestureDetector(
                              onTap: () => _showCompanyDetail(context, company),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: MployaColors.white,
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  border: Border.all(color: MployaColors.borderLight),
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
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  company.name,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: MployaColors.textPrimary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
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
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: MployaColors.textTertiary,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Mobile: Original fullscreen map + draggable sheet ──
  Widget _buildMobileLayout() {
    return Stack(
      children: [
        _buildMapWidget(),
        // Map controls (right side)
        Positioned(
          right: 12,
          bottom: 200,
          child: Column(
            children: [
              _MapControlButton(
                icon: Icons.my_location,
                onTap: () {
                  _mapController.move(_selectedCity.latLng, 13.0);
                },
              ),
              const SizedBox(height: 6),
              _MapControlButton(
                icon: Icons.add,
                onTap: () {
                  final zoom = _mapController.camera.zoom + 1;
                  _mapController.move(
                      _mapController.camera.center, zoom);
                },
              ),
              const SizedBox(height: 6),
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
        // ── Draggable bottom sheet ──
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.12,
          minChildSize: 0.06,
          maxChildSize: 0.85,
          snap: true,
          snapSizes: const [0.06, 0.12, 0.4, 0.85],
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _selectedChip == 2
                                ? '🌍 Hubs globales · ${_globalHubs.length}'
                                : 'Cerca de ti · ${_currentCompanies.length}',
                            key: ValueKey(_selectedChip),
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: MployaColors.textPrimary,
                            ),
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

                  // Content según el chip seleccionado
                  if (_selectedChip == 2)
                    // ── Vista "Todos": Lista de hubs globales ──
                    ..._globalHubs.map((hub) {
                      final jobLabel = hub.jobCount >= 1000
                          ? '${(hub.jobCount / 1000).toStringAsFixed(1)}k'
                          : '${hub.jobCount}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            _mapController.move(hub.latLng, 12.0);
                            setState(() => _selectedChip = 1);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: MployaColors.white,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: MployaColors.borderLight),
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
                                // Job count badge
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: hub.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Center(
                                    child: Text(
                                      jobLabel,
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: hub.color,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                // City info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            hub.city,
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: MployaColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            hub.country,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: MployaColors.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '🏢 ${hub.topCompany} + ${hub.jobCount - 1} más',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
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
                        ),
                      );
                    })
                  else
                    // ── Vista "Cerca" / "Ciudad": Cards locales ──
                    ..._currentCompanies.map((company) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: GestureDetector(
                          onTap: () => _showCompanyDetail(context, company),
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
    );
  }

  // ── Shared map widget used by both layouts ──
  Widget _buildMapWidget() {
    return FlutterMap(
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
        // Company / Hub markers on map
        if (_selectedChip == 2)
          // ── Vista "Todos": Hub markers globales ──
          MarkerLayer(
            markers: _globalHubs.map((hub) {
              // Tamaño proporcional al número de jobs
              final size = (32 + (hub.jobCount / 100).clamp(0, 28)).toDouble();
              final jobLabel = hub.jobCount >= 1000
                  ? '${(hub.jobCount / 1000).toStringAsFixed(1)}k'
                  : '${hub.jobCount}';
              return Marker(
                point: hub.latLng,
                width: 90,
                height: 70,
                child: GestureDetector(
                  onTap: () {
                    // Zoom a la ciudad al tocar
                    _mapController.move(hub.latLng, 12.0);
                    setState(() => _selectedChip = 1);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Círculo con cantidad de jobs
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: hub.color.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: MployaColors.white,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: hub.color.withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            jobLabel,
                            style: GoogleFonts.inter(
                              fontSize: size > 50 ? 13 : 10,
                              fontWeight: FontWeight.w800,
                              color: MployaColors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Label con nombre de ciudad
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: MployaColors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          hub.city,
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
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
          )
        else
          // ── Vista "Cerca" / "Ciudad": Markers locales ──
          MarkerLayer(
            markers: _currentCompanies.map((company) {
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
    );
  }

  void _showCompanyDetail(BuildContext context, _CompanyMarker company) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: MployaColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MployaColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Company avatar large
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Center(
                child: Text(
                  company.initial,
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Company name + type badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  company.name,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: MployaColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: company.type == 'Startup'
                        ? MployaColors.teal.withValues(alpha: 0.1)
                        : MployaColors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    company.type,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: company.type == 'Startup'
                          ? MployaColors.teal
                          : MployaColors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Role
            Text(
              company.role,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: MployaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            // CTA Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('Postulación a ${company.name} enviada'),
                        ],
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Postularse',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: MployaColors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, color: MployaColors.textSecondary, size: 18),
      ),
    );
  }
}

// ─── Search Delegate ─────────────────────────────────────────────────

class _ExploreSearchDelegate extends SearchDelegate<String> {
  _ExploreSearchDelegate({required this.companies}) : super(searchFieldLabel: 'Buscar personas, empresas...');

  final List<_CompanyMarker> companies;

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
    final q = query.toLowerCase();
    final matchingCities = _cities
        .where((c) => c.name.toLowerCase().contains(q) || c.country.toLowerCase().contains(q))
        .toList();
    final matchingCompanies = companies
        .where((c) => c.name.toLowerCase().contains(q) || c.role.toLowerCase().contains(q))
        .toList();

    if (matchingCities.isEmpty && matchingCompanies.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: MployaColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'No se encontraron resultados para "$query"',
              style: GoogleFonts.inter(fontSize: 15, color: MployaColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (matchingCompanies.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Empresas',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: MployaColors.textPrimary),
            ),
          ),
          ...matchingCompanies.map((company) => ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
              child: Text(company.initial, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: const Color(0xFF6366F1))),
            ),
            title: Text(company.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            subtitle: Text(company.role, style: GoogleFonts.inter(fontSize: 13, color: MployaColors.textSecondary)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: company.type == 'Startup' ? MployaColors.teal.withValues(alpha: 0.1) : MployaColors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(company.type, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: company.type == 'Startup' ? MployaColors.teal : MployaColors.blue)),
            ),
            onTap: () { close(context, company.name); },
          )),
        ],
        if (matchingCities.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Ciudades',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: MployaColors.textPrimary),
            ),
          ),
          ...matchingCities.take(20).map((city) => ListTile(
            leading: const Icon(Icons.location_city_rounded, color: MployaColors.orange),
            title: Text(city.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            subtitle: Text(city.country, style: GoogleFonts.inter(fontSize: 13, color: MployaColors.textSecondary)),
            onTap: () { close(context, city.name); },
          )),
        ],
      ],
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
  DateTime? _lastGeocodingCall;

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
    // Nominatim usage policy: max 1 request per second
    final now = DateTime.now();
    if (_lastGeocodingCall != null &&
        now.difference(_lastGeocodingCall!).inMilliseconds < 1000) {
      await Future<void>.delayed(
        Duration(milliseconds: 1000 - now.difference(_lastGeocodingCall!).inMilliseconds),
      );
    }
    _lastGeocodingCall = DateTime.now();

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
