import 'package:flutter/cupertino.dart';
// Material widgets (Divider) have no Cupertino equivalent
import 'package:flutter/material.dart' show Divider, Colors;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_video_widgets.dart' show VideoPlayerModal;

/// Detalle de una oferta. Idea adaptada de JobToday (ficha de datos + mapa +
/// chips) pero con el video-pitch de la empresa como protagonista — que es lo
/// que Mploya tiene y un tablón de texto no.
///
/// Es resiliente: cada bloque (video, descripción, ficha, mapa, distancia) solo
/// aparece si el dato existe de verdad. Nada de placeholders vacíos ni urgencia
/// falsa. Los campos nuevos (jornada/horario/experiencia/descripción) aparecen
/// automáticamente cuando se corre la migración que agrega esas columnas.
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
        setState(() => _companyVideoUrl = url);
      }
    } catch (_) {}
  }

  // Distancia sin pedir permiso: solo usa la última ubicación conocida.
  Future<void> _computeDistance() async {
    if (_lat == null || _lng == null) return;
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null || !mounted) return;
      final meters = Geolocator.distanceBetween(pos.latitude, pos.longitude, _lat!, _lng!);
      setState(() => _distanceKm = meters / 1000);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = job['title']?.toString() ?? 'Oferta';
    final companyName = (job['users'] as Map<String, dynamic>?)?['name']?.toString()
        ?? job['company_name']?.toString()
        ?? 'Empresa';
    final companyAvatar = (job['users'] as Map<String, dynamic>?)?['avatar_url']?.toString();
    final salary = job['salary_range']?.toString() ?? job['salary']?.toString();
    final location = job['location']?.toString();
    final description = job['description']?.toString();
    final isConfidential = job['type'] == 'Stealth' || job['is_stealth'] == true;

    final tags = (job['tags'] is List)
        ? (job['tags'] as List).map((t) => t.toString()).toList()
        : <String>[];

    return CupertinoPageScaffold(
      backgroundColor: context.isDark ? NexTheme.darkBg : const Color(0xFFF7F8FA),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
        border: null,
        middle: Text(companyName, style: TextStyle(color: context.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // ── Empresa ──
                  Row(
                    children: [
                      _companyAvatar(context, companyName, companyAvatar),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(companyName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary)),
                            if (location != null && location.isNotEmpty)
                              Text(location, style: TextStyle(fontSize: 13, color: context.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      if (isConfidential) _confidentialBadge(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Video-Pitch de la empresa (el héroe) ──
                  if (_companyVideoUrl != null) ...[
                    _buildVideoHero(context, _companyVideoUrl!),
                    const SizedBox(height: 16),
                  ],

                  // ── Título + salario ──
                  Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary, letterSpacing: -0.4, height: 1.15)),
                  if (salary != null && salary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(salary, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: MployaTheme.brandAccent)),
                  ],
                  const SizedBox(height: 12),

                  // ── Chips (solo señales reales) ──
                  _buildChips(context, location, tags),

                  // ── Descripción (solo si existe) ──
                  if (description != null && description.trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(description, style: TextStyle(fontSize: 15, height: 1.5, color: context.textSecondary)),
                  ],

                  // ── Ficha de datos ──
                  _buildFactsTable(context, salary),

                  // ── Mapa (solo si hay coordenadas) ──
                  if (_lat != null && _lng != null) ...[
                    const SizedBox(height: 20),
                    _buildMap(context, location),
                  ],
                ],
              ),
            ),
            _buildCta(context),
          ],
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 200,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 24),
                ),
              ),
              const Positioned(
                top: 12, left: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x59000000), borderRadius: BorderRadius.all(Radius.circular(6))),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: Text('Pitch de la empresa', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _companyAvatar(BuildContext context, String name, String? avatar) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: MployaTheme.brandAccent.withValues(alpha: 0.1),
        image: (avatar != null && avatar.isNotEmpty)
            ? DecorationImage(image: CachedNetworkImageProvider(avatar), fit: BoxFit.cover)
            : null,
      ),
      child: (avatar == null || avatar.isEmpty)
          ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: MployaTheme.brandAccent, fontSize: 18, fontWeight: FontWeight.w800)))
          : null,
    );
  }

  Widget _confidentialBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDAA520).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(CupertinoIcons.lock_fill, size: 10, color: Color(0xFFDAA520)),
        SizedBox(width: 4),
        Text('C-Level', style: TextStyle(color: Color(0xFFDAA520), fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(100)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildFactsTable(BuildContext context, String? salary) {
    // Solo filas con dato real. Las nuevas (jornada/horario/experiencia)
    // aparecen cuando la migración agrega esas columnas.
    final rows = <(String, String)>[];
    void add(String label, dynamic value) {
      final v = value?.toString().trim();
      if (v != null && v.isNotEmpty) rows.add((label, v));
    }

    add('Experiencia', job['experience_level']);
    add('Jornada', job['employment_type']);
    add('Horario', job['schedule']);
    if (salary != null && salary.isNotEmpty) rows.add(('Salario', salary));
    add('Extras', job['extras']);

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.isDark ? NexTheme.darkSurface : CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.isDark ? const Color(0xFF222222) : const Color(0xFFEDEFF2)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 110, child: Text(rows[i].$1, style: TextStyle(fontSize: 14, color: context.textSecondary))),
                  Expanded(child: Text(rows[i].$2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary))),
                ],
              ),
            ),
            if (i < rows.length - 1) Divider(height: 0.5, thickness: 0.5, color: context.dividerColor),
          ],
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context, String? location) {
    final point = LatLng(_lat!, _lng!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 150,
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
                  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.mploya.ai',
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
                top: 10, left: 10, right: 10,
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
                    Expanded(child: Text(location, style: const TextStyle(fontSize: 13, color: Color(0xFF1C1C1E)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCta(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
        border: Border(top: BorderSide(color: context.dividerColor.withValues(alpha: 0.3), width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          borderRadius: BorderRadius.circular(100),
          padding: const EdgeInsets.symmetric(vertical: 15),
          color: _applied ? CupertinoColors.systemGrey4 : MployaTheme.brandAccent,
          onPressed: _applied || widget.onApply == null
              ? null
              : () {
                  widget.onApply!.call();
                  setState(() => _applied = true);
                },
          child: Text(
            _applied ? '✓ Postulación enviada' : 'Postularme con mi Video-Pitch',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _applied ? CupertinoColors.systemGrey : Colors.white),
          ),
        ),
      ),
    );
  }
}
