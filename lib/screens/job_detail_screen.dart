import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_video_widgets.dart' show VideoPlayerModal;
import '../models/models.dart' show resolveVideoUrl;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Detalle de una oferta rediseñado con estética premium y adaptabilidad responsive
/// según el mockup del usuario.
class JobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final int? matchScore;
  final bool isApplied;
  final bool isSaved;

  /// Postula a esta vacante y devuelve si quedó registrada.
  ///
  /// ADENDA 31/8/2026 — antes era un `VoidCallback`: se disparaba y la
  /// pantalla asumía éxito en el mismo instante. Ahora informa el
  /// resultado real y el botón espera esa respuesta.
  final Future<bool> Function()? onApply;
  final VoidCallback? onToggleSaved;
  final String? viewerAccountType;
  final bool previewMode;

  const JobDetailScreen({
    super.key,
    required this.job,
    this.matchScore,
    this.isApplied = false,
    this.isSaved = false,
    this.onApply,
    this.onToggleSaved,
    this.viewerAccountType,
    this.previewMode = false,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  String? _companyVideoUrl;
  double? _distanceKm;
  bool _applied = false;
  bool _applying = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _applied = widget.isApplied;
    _saved = widget.isSaved;
    if (!widget.previewMode && !_isHeadhunter) {
      _loadCompanyVideo();
      _computeDistance();
    }
  }

  void _toggleSaved() {
    if (widget.onToggleSaved == null) return;
    setState(() => _saved = !_saved);
    widget.onToggleSaved!.call();
  }

  bool get _isHeadhunter =>
      widget.viewerAccountType?.toLowerCase() == 'headhunter';

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
      await launchUrl(
        Uri.parse(cleanUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'job_detail_screen: launchUrl',
        fatal: false,
      );
    }
  }

  Future<void> _loadCompanyVideo() async {
    final companyId = job['company_id']?.toString();
    if (companyId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('accessible_user_profiles')
          .select('video_url')
          .eq('id', companyId)
          .maybeSingle();
      final url = row?['video_url']?.toString();
      if (mounted && url != null && url.isNotEmpty) {
        setState(() => _companyVideoUrl = resolveVideoUrl(url));
      }
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'job_detail_screen: cargar video de la empresa',
        fatal: false,
      );
    }
  }

  Future<void> _computeDistance() async {
    if (_lat == null || _lng == null) return;
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null || !mounted) return;
      final meters = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        _lat!,
        _lng!,
      );
      setState(() => _distanceKm = meters / 1000);
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'job_detail_screen: calcular distancia',
        fatal: false,
      );
    }
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
          tipo = trimmed
              .split(RegExp(r'tipo:', caseSensitive: false))
              .last
              .trim();
        } else if (lower.contains('tamaño:') || lower.contains('tamano:')) {
          tamano = trimmed
              .split(RegExp(r'tamaño:|tamano:', caseSensitive: false))
              .last
              .trim();
        } else if (lower.contains('fundada:')) {
          fundada = trimmed
              .split(RegExp(r'fundada:', caseSensitive: false))
              .last
              .trim();
        } else if (lower.contains('ubicación:') ||
            lower.contains('ubicacion:')) {
          ubicacion = trimmed
              .split(RegExp(r'ubicación:|ubicacion:', caseSensitive: false))
              .last
              .trim();
        } else if (lower.contains('modalidad:')) {
          modalidad = trimmed
              .split(RegExp(r'modalidad:', caseSensitive: false))
              .last
              .trim();
        } else if (lower.contains('web:')) {
          web = trimmed
              .split(RegExp(r'web:', caseSensitive: false))
              .last
              .trim();
        } else if (lower.contains('tech stack:')) {
          techStack = trimmed
              .split(RegExp(r'tech stack:', caseSensitive: false))
              .last
              .trim();
        } else if (lower.contains('cultura:')) {
          cultura = trimmed
              .split(RegExp(r'cultura:', caseSensitive: false))
              .last
              .trim();
        } else if (lower.contains('beneficios:')) {
          beneficios = trimmed
              .split(RegExp(r'beneficios:', caseSensitive: false))
              .last
              .trim();
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
    if (_isHeadhunter) return _buildHeadhunterDetail(context);
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

  Widget _buildHeadhunterDetail(BuildContext context) {
    final title = job['title']?.toString().trim() ?? '';
    final company =
        (job['users'] as Map?)?['name']?.toString().trim() ??
        job['company_name']?.toString().trim() ??
        job['company']?.toString().trim() ??
        '';
    final location = job['location']?.toString().trim() ?? '';
    final salary =
        (job['salary_range'] ?? job['salary'])?.toString().trim() ?? '';
    final modality = switch (job['modality']?.toString()) {
      'remote' => 'Remoto',
      'hybrid' => 'Híbrido',
      'onsite' => 'Presencial',
      final value when value != null => value,
      _ => '',
    };
    final seniority = job['seniority']?.toString().trim() ?? '';
    final description = job['description']?.toString().trim() ?? '';
    final tags = ((job['tags'] as List?) ?? const [])
        .map((tag) => tag.toString().trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    final facts = [
      location,
      modality,
      seniority,
    ].where((value) => value.isNotEmpty).toList();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(40, 40),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      CupertinoIcons.chevron_back,
                      color: Color(0xFF263247),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Detalle de vacante',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF263247),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF173B63), Color(0xFF185FA5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              CupertinoIcons.briefcase_fill,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            title.isEmpty ? 'Vacante sin título' : title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (company.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Text(
                              company,
                              style: const TextStyle(
                                color: Color(0xFFD8E8F8),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (salary.isNotEmpty) ...[
                            const SizedBox(height: 13),
                            Text(
                              salary,
                              style: const TextStyle(
                                color: Color(0xFFFFC267),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (facts.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: facts
                            .map(
                              (fact) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  fact,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF58667A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 25),
                      const Text(
                        'Sobre la posición',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF263247),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: Color(0xFF657287),
                        ),
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Skills publicadas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF263247),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF3FC),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: Color(0xFF185FA5),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFE0AA)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            CupertinoIcons.info_circle_fill,
                            color: Color(0xFFD4740A),
                            size: 19,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Vista informativa para Headhunter. Las postulaciones corresponden al rol Candidato.',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: Color(0xFF855111),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT (Ancho <= 800px)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context, Map<String, String?> parsed) {
    final title = job['title']?.toString() ?? 'Oferta';
    final companyName =
        (job['users'] as Map<String, dynamic>?)?['name']?.toString() ??
        job['company_name']?.toString() ??
        'Empresa';
    final salary =
        (job['salary_range']?.toString() ?? job['salary']?.toString() ?? '')
            .trim();
    final location = (job['location']?.toString() ?? parsed['ubicacion'] ?? '')
        .trim();
    final modality =
        _jobModality() ??
        (parsed['modalidad']?.isNotEmpty == true ? parsed['modalidad'] : null);
    final seniority = job['seniority']?.toString().trim() ?? '';
    final tags = (job['tags'] is List)
        ? (job['tags'] as List).map((t) => t.toString()).toList()
        : <String>[];

    return Column(
      children: [
        // ── Custom Dark Header ──
        Container(
          color: const Color(0xFF22211F),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            bottom: 16,
          ),
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
                  child: const Icon(
                    CupertinoIcons.chevron_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: const Text(
                    'Vacante',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              _headerAction(
                icon: _saved
                    ? CupertinoIcons.bookmark_fill
                    : CupertinoIcons.bookmark,
                tooltip: _saved ? 'Vacante guardada' : 'Guardar vacante',
                onPressed: widget.onToggleSaved == null ? null : _toggleSaved,
              ),
              _headerAction(
                icon: CupertinoIcons.share,
                tooltip: 'Compartir vacante',
                onPressed: () => Share.share(
                  'Mirá esta oferta de empleo en Mploya: $title en $companyName',
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

              // ── Employer, title & compensation ──
              Text(
                companyName,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5B39E6),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF22211F),
                  height: 1.14,
                ),
              ),
              if (salary.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  salary,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF3B6D11),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // ── Chips ──
              _buildChips(context, location, tags, modality: modality),
              const SizedBox(height: 20),

              // ── Actual job facts only ──
              if (location.isNotEmpty ||
                  modality != null ||
                  seniority.isNotEmpty) ...[
                _buildMobileFacts(
                  location: location,
                  modality: modality,
                  seniority: seniority,
                ),
                const SizedBox(height: 24),
              ],

              // ── Description ──
              if (parsed['about'] != null && parsed['about']!.isNotEmpty) ...[
                const Text(
                  'Sobre el rol',
                  style: TextStyle(
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
              if (parsed['techStack'] != null &&
                  parsed['techStack']!.isNotEmpty) ...[
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

        // Sólo se muestra si este acceso puede realizar una postulación real.
        // Así no aparece un botón apagado en enlaces informativos (por ejemplo,
        // al recorrer vacantes desde el perfil público de una empresa).
        if (widget.onApply != null || _applied)
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFFAF8F5),
              border: Border(
                top: BorderSide(color: Color(0xFFE2DFD5), width: 0.5),
              ),
            ),
            child: _buildGoldCTA(context),
          ),
      ],
    );
  }

  Widget _buildMobileFacts({
    required String location,
    required String? modality,
    required String seniority,
  }) {
    final facts = <({IconData icon, String title, String value})>[
      if (location.isNotEmpty)
        (
          icon: CupertinoIcons.location_solid,
          title: 'Ubicación',
          value: location,
        ),
      if (modality != null && modality.isNotEmpty)
        (icon: CupertinoIcons.house_fill, title: 'Modalidad', value: modality),
      if (seniority.isNotEmpty)
        (
          icon: CupertinoIcons.chart_bar_fill,
          title: 'Experiencia',
          value: seniority,
        ),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: facts
          .map(
            (fact) => SizedBox(
              width: (facts.length == 1) ? double.infinity : 165,
              child: _infoFactCard(fact.icon, fact.title, fact.value),
            ),
          )
          .toList(),
    );
  }

  Widget _infoFactCard(IconData icon, String title, String value) {
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
    final companyName =
        (job['users'] as Map<String, dynamic>?)?['name']?.toString() ??
        job['company_name']?.toString() ??
        'Empresa';
    final salary =
        (job['salary_range']?.toString() ?? job['salary']?.toString() ?? '')
            .trim();
    final location = (job['location']?.toString() ?? parsed['ubicacion'] ?? '')
        .trim();
    final tags = (job['tags'] is List)
        ? (job['tags'] as List).map((t) => t.toString()).toList()
        : <String>[];

    final modalidad =
        _jobModality() ??
        (parsed['modalidad']?.isNotEmpty == true ? parsed['modalidad'] : null);
    final seniority = job['seniority']?.toString().trim() ?? '';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // ── Top Dark Banner Block ──
          Container(
            color: const Color(0xFF22211F),
            padding: const EdgeInsets.fromLTRB(
              40,
              24,
              40,
              60,
            ), // Extra bottom padding for overlap
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
                            child: const Icon(
                              CupertinoIcons.chevron_back,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const Text(
                          'Vacante',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Row(
                          children: [
                            _headerAction(
                              icon: _saved
                                  ? CupertinoIcons.bookmark_fill
                                  : CupertinoIcons.bookmark,
                              tooltip: _saved
                                  ? 'Vacante guardada'
                                  : 'Guardar vacante',
                              onPressed: widget.onToggleSaved == null
                                  ? null
                                  : _toggleSaved,
                            ),
                            _headerAction(
                              icon: CupertinoIcons.share,
                              tooltip: 'Compartir vacante',
                              onPressed: () => Share.share(
                                'Mirá esta oferta de empleo en Mploya: $title en $companyName',
                              ),
                            ),
                          ],
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
                                    child: Icon(
                                      CupertinoIcons.video_camera_solid,
                                      color: Colors.white24,
                                      size: 48,
                                    ),
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
                              if (location.isNotEmpty)
                                _infoListCard(
                                  CupertinoIcons.location,
                                  'Ubicación: $location',
                                ),
                              if (modalidad != null)
                                _infoListCard(
                                  CupertinoIcons.house,
                                  'Modalidad: $modalidad',
                                ),
                              if (seniority.isNotEmpty)
                                _infoListCard(
                                  CupertinoIcons.chart_bar,
                                  'Experiencia: $seniority',
                                ),
                              if (location.isEmpty &&
                                  modalidad == null &&
                                  seniority.isEmpty)
                                _infoListCard(
                                  CupertinoIcons.briefcase,
                                  'Consultá los detalles con la empresa',
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
                        if (salary.isNotEmpty)
                          Text(
                            salary,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Color(0xFF3B6D11),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(height: 16),
                        _buildChips(
                          context,
                          location,
                          tags,
                          modality: modalidad,
                        ),
                        const SizedBox(height: 32),

                        // Description
                        if (parsed['about'] != null &&
                            parsed['about']!.isNotEmpty) ...[
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
                        if (parsed['techStack'] != null &&
                            parsed['techStack']!.isNotEmpty) ...[
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
                            border: Border.all(
                              color: const Color(0xFFE2DFD5),
                              width: 1,
                            ),
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
                              if (location.isNotEmpty)
                                _detailRow('Ubicación', location),
                              if (modalidad != null)
                                _detailRow('Modalidad', modalidad),
                              if (seniority.isNotEmpty)
                                _detailRow('Experiencia', seniority),
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
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
  String? _modalityLabel(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'remote':
      case 'remoto':
        return 'Remoto';
      case 'hybrid':
      case 'híbrido':
      case 'hibrido':
        return 'Híbrido';
      case 'onsite':
      case 'presencial':
        return 'Presencial';
      default:
        return null;
    }
  }

  String? _jobModality() {
    final direct = _modalityLabel(job['modality']?.toString());
    if (direct != null) return direct;
    final tags = job['tags'];
    if (tags is List) {
      for (final tag in tags) {
        final fromTag = _modalityLabel(tag.toString());
        if (fromTag != null) return fromTag;
      }
    }
    return job['is_remote'] == true ? 'Remoto' : null;
  }

  Widget _headerAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.only(left: 3),
      minSize: 40,
      onPressed: onPressed,
      child: Semantics(
        label: tooltip,
        button: true,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    );
  }

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
            ),
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
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.play_fill,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            const Positioned(
              top: 12,
              left: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x7F000000),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Text(
                    'Pitch de la empresa',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChips(
    BuildContext context,
    String? location,
    List<String> tags, {
    String? modality,
  }) {
    final chips = <Widget>[];

    if (widget.matchScore != null && widget.matchScore! > 0) {
      chips.add(
        _chip(context, '${widget.matchScore}% match', accent: true),
      );
    }
    if (_distanceKm != null) {
      final d = _distanceKm! < 1
          ? '${(_distanceKm! * 1000).round()} m'
          : '${_distanceKm!.toStringAsFixed(1)} km';
      chips.add(_chip(context, 'A $d'));
    }
    if (modality != null && modality.isNotEmpty) {
      chips.add(_chip(context, modality));
    }
    for (final t in tags.take(4)) {
      chips.add(_chip(context, t.startsWith('#') ? t : '#$t'));
    }

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  Widget _chip(BuildContext context, String label, {bool accent = false}) {
    final color = accent ? context.brandAccent : const Color(0xFF6C6C70);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent
            ? context.brandAccent.withValues(alpha: 0.08)
            : const Color(0xFFF6F4EE),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: accent
              ? context.brandAccent.withValues(alpha: 0.18)
              : const Color(0xFFE2DFD5),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTechStackBlock(String techStack) {
    final List<String> bullets = techStack
        .split(',')
        .map((s) => s.trim())
        .toList();

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
                    const Text(
                      '•  ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFDCAE50),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  // ArcGIS World_Street_Map: OSM degrada tiles en prod por Referer.
                  // OJO: orden {z}/{y}/{x}.
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'ai.mploya.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        CupertinoIcons.location_solid,
                        color: MployaTheme.brandAccent,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (location != null && location.isNotEmpty)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.location_solid,
                        size: 15,
                        color: MployaTheme.brandAccent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF22211F),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Postula y recién entonces cambia el botón.
  ///
  /// ADENDA 31/8/2026 — LA POSTULACIÓN QUE NO SE GUARDABA. Acá se hacía
  /// `setState(() => _applied = true)` en la misma línea que la llamada,
  /// sin esperarla. Quien cancelaba el diálogo del video, o la cámara, o
  /// se quedaba sin conexión, veía igual "✓ Postulación enviada" y se iba
  /// convencido de haberse postulado, mientras `job_applications` seguía
  /// vacía. Una pantalla no puede afirmar algo que no le consta.
  Future<void> _postularse() async {
    final postular = widget.onApply;
    if (postular == null) return;
    setState(() => _applying = true);
    final enviada = await postular();
    if (!mounted) return;
    setState(() {
      _applying = false;
      _applied = enviada;
    });
  }

  Widget _buildGoldCTA(BuildContext context) {
    final bool isEnabled = !_applied && !_applying && widget.onApply != null;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: isEnabled ? _postularse : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: _applied
              ? CupertinoColors.systemGrey4
              : context.brandAccent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _applied
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.paperplane_fill,
              size: 18,
              color: _applied ? CupertinoColors.systemGrey : Colors.white,
            ),
            const SizedBox(width: 9),
            Text(
              _applying
                  ? 'Enviando postulación…'
                  : _applied
                  ? 'Postulación enviada'
                  : 'Postularme',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _applied ? CupertinoColors.systemGrey : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
