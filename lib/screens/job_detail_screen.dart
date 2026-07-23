import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider, Colors, Icons;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_video_widgets.dart' show VideoPlayerModal;
import '../models/models.dart' show resolveVideoUrl;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Detalle de una oferta rediseñado con estética premium y adaptabilidad responsive
/// según el mockup del usuario.
class JobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final int? matchScore;
  final bool isApplied;
  final VoidCallback? onApply;

  const JobDetailScreen({
    super.key,
    required this.job,
    this.matchScore,
    this.isApplied = false,
    this.onApply,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  String? _companyVideoUrl;
  double? _distanceKm;
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    _applied = widget.isApplied;
    _loadCompanyVideo();
    _computeDistance();
  }

  Map<String, dynamic> get job => widget.job;

  double? get _lat => _asDouble(job['latitude']);
  double? get _lng => _asDouble(job['longitude']);

  double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Future<void> _openWeb(String url) async {
    String cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    try {
      await launchUrl(Uri.parse(cleanUrl), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _loadCompanyVideo() async {
    final companyId = job['company_id']?.toString();
    if (companyId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('video_url')
          .eq('id', companyId)
          .maybeSingle();
      final url = row?['video_url']?.toString();
      if (mounted && url != null && url.isNotEmpty) {
        setState(() => _companyVideoUrl = resolveVideoUrl(url));
      }
    } catch (_) {}
  }

  Future<void> _computeDistance() async {
    if (_lat == null || _lng == null) return;
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null || !mounted) return;
      final meters = Geolocator.distanceBetween(pos.latitude, pos.longitude, _lat!, _lng!);
      setState(() => _distanceKm = meters / 1000);
    } catch (_) {}
  }

  Map<String, String?> _parseDescription(String? desc) {
    if (desc == null || desc.isEmpty) {
      return {'about': 'Buscando talento en Mploya.'};
    }
    final lines = desc.split('\n');
    String aboutText = '';
    String? tipo;
    String? tamano;
    String? fundada;
    String? ubicacion;
    String? modalidad;
    String? web;
    String? techStack;
    String? cultura;
    String? beneficios;
    
    bool foundSeparator = false;
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('─────') || trimmed.contains('──────')) {
        foundSeparator = true;
        continue;
      }
      
      if (!foundSeparator) {
        if (aboutText.isNotEmpty) aboutText += '\n';
        aboutText += line;
      } else {
        final lower = trimmed.toLowerCase();
        if (lower.contains('tipo:')) {
          tipo = trimmed.split(RegExp(r'tipo:', caseSensitive: false)).last.trim();
        } else if (lower.contains('tamaño:') || lower.contains('tamano:')) {
          tamano = trimmed.split(RegExp(r'tamaño:|tamano:', caseSensitive: false)).last.trim();
        } else if (lower.contains('fundada:')) {
          fundada = trimmed.split(RegExp(r'fundada:', caseSensitive: false)).last.trim();
        } else if (lower.contains('ubicación:') || lower.contains('ubicacion:')) {
          ubicacion = trimmed.split(RegExp(r'ubicación:|ubicacion:', caseSensitive: false)).last.trim();
        } else if (lower.contains('modalidad:')) {
          modalidad = trimmed.split(RegExp(r'modalidad:', caseSensitive: false)).last.trim();
        } else if (lower.contains('web:')) {
          web = trimmed.split(RegExp(r'web:', caseSensitive: false)).last.trim();
        } else if (lower.contains('tech stack:')) {
          techStack = trimmed.split(RegExp(r'tech stack:', caseSensitive: false)).last.trim();
        } else if (lower.contains('cultura:')) {
          cultura = trimmed.split(RegExp(r'cultura:', caseSensitive: false)).last.trim();
        } else if (lower.contains('beneficios:')) {
          beneficios = trimmed.split(RegExp(r'beneficios:', caseSensitive: false)).last.trim();
        }
      }
    }
    
    String cleanField(String? val) {
      if (val == null) return '';
      return val.replaceAll(RegExp(r'^[🏢👥📅📍🏠🌐⚡🎯🎁]\s*'), '').trim();
    }

    return {
      'about': aboutText.trim(),
      'tipo': cleanField(tipo),
      'tamano': cleanField(tamano),
      'fundada': cleanField(fundada),
      'ubicacion': cleanField(ubicacion),
      'modalidad': cleanField(modalidad),
      'web': cleanField(web),
      'techStack': cleanField(techStack),
      'cultura': cleanField(cultura),
      'beneficios': cleanField(beneficios),
    };
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parseDescription(job['description']?.toString());
    
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFAF8F5), // Premium light cream
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return _buildWebLayout(context, parsed);
          } else {
            return _buildMobileLayout(context, parsed);
          }
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT (Ancho <= 800px)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context, Map<String, String?> parsed) {
    final title = job['title']?.toString() ?? 'Oferta';
    final companyName = (job['users'] as Map<String, dynamic>?)?['name']?.toString()
        ?? job['company_name']?.toString()
        ?? 'Empresa';
    final salary = job['salary_range']?.toString() ?? job['salary']?.toString() ?? 'A convenir';
    final location = parsed['ubicacion'] ?? job['location']?.toString() ?? 'Asunción';
    final tags = (job['tags'] is List)
        ? (job['tags'] as List).map((t) => t.toString()).toList()
        : <String>[];

    return Column(
      children: [
        // ── Custom Dark Header ──
        Container(
          color: const Color(0xFF22211F),
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, bottom: 16),
          child: Row(
            children: [
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.chevron_back, color: Colors.white, size: 20),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    companyName.toLowerCase(),
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  Share.share('Mirá esta oferta de empleo en Mploya: $title en $companyName');
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.share, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),

        // ── Scrollable Content ──
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            physics: const BouncingScrollPhysics(),
            children: [
              // ── Video Hero ──
              if (_companyVideoUrl != null) ...[
                _buildVideoHero(context, _companyVideoUrl!),
                const SizedBox(height: 24),
              ],

              // ── Title & Salary ──
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF22211F),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                salary,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6C6C70),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              // ── Chips ──
              _buildChips(context, location, tags),
              const SizedBox(height: 24),

              // ── Grid of Info Cards (4 Cards) ──
              _buildMobileGrid(parsed, location),
              const SizedBox(height: 24),

              // ── Description ──
              if (parsed['about'] != null && parsed['about']!.isNotEmpty) ...[
                const Text(
                  'Sobre el rol',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF22211F),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  parsed['about']!,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: Color(0xFF6C6C70),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Tech Stack ──
              if (parsed['techStack'] != null && parsed['techStack']!.isNotEmpty) ...[
                _buildTechStackBlock(parsed['techStack']!),
                const SizedBox(height: 24),
              ],

              // ── Map ──
              if (_lat != null && _lng != null) ...[
                const Text(
                  'Ubicación',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF22211F),
                  ),
                ),
                const SizedBox(height: 12),
                _buildMap(context, location),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),

        // ── Pinned CTA Button at Bottom ──
        Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF8F5),
            border: Border(top: BorderSide(color: Color(0xFFE2DFD5), width: 0.5)),
          ),
          child: _buildGoldCTA(context),
        ),
      ],
    );
  }

  Widget _buildMobileGrid(Map<String, String?> parsed, String location) {
    final tipo = parsed['tipo']?.isNotEmpty == true ? parsed['tipo']! : 'Startup';
    final tamano = parsed['tamano']?.isNotEmpty == true ? parsed['tamano']! : '20 empleados';
    final fundada = parsed['fundada']?.isNotEmpty == true ? parsed['fundada']! : '2022';
    final web = parsed['web']?.isNotEmpty == true ? parsed['web']! : 'jilo.com';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: [
        _infoGridCard(CupertinoIcons.briefcase, tipo, 'Size'),
        _infoGridCard(CupertinoIcons.calendar, 'Fundada', fundada),
        _infoGridCard(CupertinoIcons.location, 'Location', location),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openWeb(web),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: _infoGridCard(CupertinoIcons.globe, 'Web', web),
          ),
        ),
      ],
    );
  }

  Widget _infoGridCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2DFD5), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF22211F)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF22211F),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6C6C70),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // WEB LAYOUT (Ancho > 800px)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildWebLayout(BuildContext context, Map<String, String?> parsed) {
    final title = job['title']?.toString() ?? 'Oferta';
    final companyName = (job['users'] as Map<String, dynamic>?)?['name']?.toString()
        ?? job['company_name']?.toString()
        ?? 'Empresa';
    final salary = job['salary_range']?.toString() ?? job['salary']?.toString() ?? 'A convenir';
    final location = parsed['ubicacion'] ?? job['location']?.toString() ?? 'Asunción';
    final tags = (job['tags'] is List)
        ? (job['tags'] as List).map((t) => t.toString()).toList()
        : <String>[];

    final tipo = parsed['tipo']?.isNotEmpty == true ? parsed['tipo']! : 'Startup';
    final tamano = parsed['tamano']?.isNotEmpty == true ? parsed['tamano']! : '20 empleados';
    final fundada = parsed['fundada']?.isNotEmpty == true ? parsed['fundada']! : '2022';
    final web = parsed['web']?.isNotEmpty == true ? parsed['web']! : 'jilo.com';
    final modalidad = parsed['modalidad']?.isNotEmpty == true ? parsed['modalidad']! : 'Remoto';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // ── Top Dark Banner Block ──
          Container(
            color: const Color(0xFF22211F),
            padding: const EdgeInsets.fromLTRB(40, 24, 40, 60), // Extra bottom padding for overlap
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  children: [
                    // Back & Logo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.chevron_back, color: Colors.white, size: 20),
                          ),
                        ),
                        Text(
                          companyName.toLowerCase(),
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            Share.share('Mirá esta oferta de empleo en Mploya: $title en $companyName');
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.share, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    
                    // Row for overlapping Video & Stacked Info Cards
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Video player (takes most space)
                        Expanded(
                          flex: 3,
                          child: _companyVideoUrl != null
                              ? _buildVideoHero(context, _companyVideoUrl!)
                              : Container(
                                  height: 260,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1C),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Center(
                                    child: Icon(CupertinoIcons.video_camera_solid, color: Colors.white24, size: 48),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 40),
                        
                        // Right: stacked transparent info cards
                        Expanded(
                          flex: 2,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              _infoListCard(CupertinoIcons.briefcase, '$tipo | $tamano'),
                              _infoListCard(CupertinoIcons.calendar, 'Fundada: $fundada'),
                              _infoListCard(CupertinoIcons.location, 'Ubicación: $location | Modalidad: $modalidad'),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _openWeb(web),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: _infoListCard(CupertinoIcons.globe, 'Website: $web'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom Cream Block (Content) ──
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1100),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Job detail details
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF22211F),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          salary,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF6C6C70),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildChips(context, location, tags),
                        const SizedBox(height: 32),
                        
                        // Description
                        if (parsed['about'] != null && parsed['about']!.isNotEmpty) ...[
                          const Text(
                            'Sobre el rol',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF22211F),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            parsed['about']!,
                            style: const TextStyle(
                              fontSize: 15.5,
                              height: 1.6,
                              color: Color(0xFF6C6C70),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Tech Stack
                        if (parsed['techStack'] != null && parsed['techStack']!.isNotEmpty) ...[
                          _buildTechStackBlock(parsed['techStack']!),
                          const SizedBox(height: 32),
                        ],

                        // Map
                        if (_lat != null && _lng != null) ...[
                          const Text(
                            'Ubicación en mapa',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF22211F),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildMap(context, location),
                          const SizedBox(height: 40),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),

                  // Right Column: Details Card & Gold Apply Button
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Details Summary Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F4EE),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2DFD5), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Detalles',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF22211F),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _detailRow('Fundada', fundada),
                              _detailRow('Ubicación', location),
                              _detailRow('Modalidad', modalidad),
                              _detailRow('Website', web),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Gold Apply Button
                        _buildGoldCTA(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoListCard(IconData icon, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  $label: ',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6C6C70),
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF22211F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // COMMON HELPER COMPONENT WIDGETS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildVideoHero(BuildContext context, String videoUrl) {
    return GestureDetector(
      onTap: () => showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => VideoPlayerModal(videoUrl: videoUrl, index: 0),
      ),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF333230), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                ),
                child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 26),
              ),
            ),
            const Positioned(
              top: 12, left: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x7F000000),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Text(
                    'Pitch de la empresa',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChips(BuildContext context, String? location, List<String> tags) {
    final chips = <Widget>[];

    if (widget.matchScore != null && widget.matchScore! > 0) {
      chips.add(_chip('${widget.matchScore}% match', const Color(0xFF6C3FC8)));
    }
    if (_distanceKm != null) {
      final d = _distanceKm! < 1
          ? '${(_distanceKm! * 1000).round()} m'
          : '${_distanceKm!.toStringAsFixed(1)} km';
      chips.add(_chip('A $d', const Color(0xFF185FA5)));
    }
    if (location != null && location.toLowerCase().contains('remoto')) {
      chips.add(_chip('Remoto', const Color(0xFF3B6D11)));
    }
    chips.add(_chip('Sin CV', const Color(0xFF3B6D11)));
    for (final t in tags.take(4)) {
      chips.add(_chip(t.startsWith('#') ? t : '#$t', const Color(0xFF6B7280)));
    }

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildTechStackBlock(String techStack) {
    final List<String> bullets = techStack.split(',').map((s) => s.trim()).toList();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2DFD5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tech Stack',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF22211F),
            ),
          ),
          const SizedBox(height: 12),
          for (var item in bullets)
            if (item.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontSize: 14, color: Color(0xFFDCAE50), fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6C6C70),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context, String? location) {
    final point = LatLng(_lat!, _lng!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  // ArcGIS World_Street_Map: OSM degrada tiles en prod por Referer.
                  // OJO: orden {z}/{y}/{x}.
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'ai.mploya.app',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: point,
                    width: 40,
                    height: 40,
                    child: const Icon(CupertinoIcons.location_solid, color: MployaTheme.brandAccent, size: 32),
                  ),
                ]),
              ],
            ),
            if (location != null && location.isNotEmpty)
              Positioned(
                top: 12, left: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Row(children: [
                    const Icon(CupertinoIcons.location_solid, size: 15, color: MployaTheme.brandAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF22211F), fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldCTA(BuildContext context) {
    final bool isEnabled = !_applied && widget.onApply != null;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: isEnabled
          ? () {
              widget.onApply?.call();
              setState(() => _applied = true);
            }
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _applied 
              ? CupertinoColors.systemGrey4 
              : const Color(0xFFDCAE50), // Gold/Mustard yellow from mockup
          borderRadius: BorderRadius.circular(12),
          boxShadow: _applied
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFFDCAE50).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Center(
          child: Text(
            _applied ? '✓ Postulación enviada' : 'Postularme con mi Video-Pitch',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _applied ? CupertinoColors.systemGrey : const Color(0xFF22211F), // Dark charcoal text on gold
            ),
          ),
        ),
      ),
    );
  }
}
