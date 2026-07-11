import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/nex_avatar.dart';
import '../widgets/web_ui.dart';
import '../services/ai_match_service.dart';
import 'profile_screen.dart';
import 'nueva_vacante_screen.dart';

class VacantesScreen extends StatefulWidget {
  const VacantesScreen({super.key});

  @override
  State<VacantesScreen> createState() => _VacantesScreenState();
}

class _VacantesScreenState extends State<VacantesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _vacantes = [];
  // job_id -> cantidad real de postulaciones (antes era un "0" hardcodeado
  // que no reflejaba la realidad).
  Map<String, int> _applicationCounts = {};

  @override
  void initState() {
    super.initState();
    _fetchVacantes();
  }

  Future<void> _fetchVacantes() async {
    setState(() => _isLoading = true);
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await _supabase
          .from('jobs')
          .select()
          .eq('company_id', uid)
          .order('created_at', ascending: false);
      final jobs = List<Map<String, dynamic>>.from(res);

      Map<String, int> counts = {};
      final jobIds = jobs.map((j) => j['id'].toString()).toList();
      if (jobIds.isNotEmpty) {
        try {
          final apps = await _supabase
              .from('job_applications')
              .select('job_id')
              .inFilter('job_id', jobIds);
          for (final a in apps as List) {
            final jid = a['job_id']?.toString() ?? '';
            if (jid.isEmpty) continue;
            counts[jid] = (counts[jid] ?? 0) + 1;
          }
        } catch (e) {
          debugPrint('Error contando postulaciones: $e');
        }
      }

      if (mounted) {
        setState(() {
          _vacantes = jobs;
          _applicationCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetch vacantes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // En web (pantalla ancha) abre la página web-friendly de 2 columnas; en móvil,
  // el bottom-sheet.
  void _openCreate() {
    final isWide = kIsWeb && MediaQuery.of(context).size.width > 700;
    if (isWide) {
      Navigator.of(context)
          .push(CupertinoPageRoute(builder: (_) => const NuevaVacanteScreen()))
          .then((created) {
        if (created == true) _fetchVacantes();
      });
    } else {
      _showCreateJobModal();
    }
  }

  void _showCreateJobModal() {
    final titleCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final scheduleCtrl = TextEditingController();
    final extrasCtrl = TextEditingController();
    String? employmentType; // Completa / Parcial / Por horas
    String? experienceLevel; // Sin experiencia / Se valora / Imprescindible
    bool isConfidential = false;
    bool isPublishing = false;
    bool isGenerating = false;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final fieldBg = CupertinoColors.systemGrey6.resolveFrom(context);
          final hairline = context.dividerColor.withValues(alpha: 0.5);

          // Input con label arriba, esquinas redondeadas y hairline sutil.
          Widget labeled(String label, TextEditingController c, String placeholder, {int maxLines = 1}) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                CupertinoTextField(
                  controller: c,
                  placeholder: placeholder,
                  maxLines: maxLines,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  style: TextStyle(color: context.textPrimary, fontSize: 15),
                  placeholderStyle: TextStyle(color: context.textTertiary, fontSize: 15),
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: hairline, width: 0.5),
                  ),
                ),
              ],
            );
          }

          // Grupo de pills seleccionables (Jornada / Experiencia).
          Widget pills(String label, List<String> options, String? value, ValueChanged<String> onPick) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((o) {
                    final active = o == value;
                    return GestureDetector(
                      onTap: () => setModalState(() => onPick(o)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: active ? MployaTheme.brandAccent : fieldBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: active ? Colors.transparent : hairline, width: 0.5),
                        ),
                        child: Text(o, style: TextStyle(color: active ? Colors.white : context.textSecondary, fontWeight: active ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          }

          Widget sectionLabel(String t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(t.toUpperCase(), style: TextStyle(color: context.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              );

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: context.bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // ── Header: logo + título + cerrar ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(color: MployaTheme.brandAccent, borderRadius: BorderRadius.circular(9)),
                          alignment: Alignment.center,
                          child: const Text('m', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Nueva vacante', style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                              Text('Publicá una posición y recibí video-pitches', style: TextStyle(color: context.textTertiary, fontSize: 12.5)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(color: fieldBg, borderRadius: BorderRadius.circular(8)),
                            child: Icon(CupertinoIcons.xmark, size: 16, color: context.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 0.5, thickness: 0.5, color: hairline),
                  // ── Body ──
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      children: [
                        sectionLabel('Lo esencial'),
                        labeled('Puesto', titleCtrl, 'Ej. Desarrollador Flutter Senior'),
                        const SizedBox(height: 12),
                        // ── Generar con IA (botón sólido + microcopy) ──
                        GestureDetector(
                          onTap: () async {
                            if (titleCtrl.text.trim().isEmpty || isGenerating) return;
                            setModalState(() => isGenerating = true);
                            final res = await AIMatchService.instance
                                .generateJobPosting(titleCtrl.text.trim());
                            if (res != null) {
                              final desc = (res['description'] ?? '').toString().trim();
                              final reqs = (res['requirements'] as List?)
                                      ?.map((e) => '• $e')
                                      .join('\n') ??
                                  '';
                              descCtrl.text = [
                                if (desc.isNotEmpty) desc,
                                if (reqs.isNotEmpty) 'Requisitos:\n$reqs',
                              ].join('\n\n');
                              final salary = (res['salary_range'] ?? '').toString().trim();
                              if (salary.isNotEmpty) salaryCtrl.text = salary;
                              final tags = (res['tags'] as List?)
                                      ?.map((t) => t.toString())
                                      .join(', ') ??
                                  '';
                              if (tags.isNotEmpty) tagsCtrl.text = tags;
                            }
                            setModalState(() => isGenerating = false);
                          },
                          child: Container(
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: MployaTheme.brandAccent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isGenerating)
                                  const CupertinoActivityIndicator(radius: 9, color: Colors.white)
                                else
                                  const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  isGenerating ? 'Generando…' : 'Generar con IA',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Icon(CupertinoIcons.wand_stars, size: 13, color: context.textTertiary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('La IA completa descripción, salario y skills desde el título',
                                  style: TextStyle(color: context.textTertiary, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        labeled('Descripción', descCtrl, 'Qué va a hacer la persona…', maxLines: 4),
                        const SizedBox(height: 16),
                        labeled('Rango salarial', salaryCtrl, 'Ej. USD 3.000 - 5.500 / mes'),
                        const SizedBox(height: 16),
                        labeled('Skills / hashtags', tagsCtrl, 'Ej. flutter, react, fintech'),
                        const SizedBox(height: 24),
                        Divider(height: 0.5, thickness: 0.5, color: hairline),
                        const SizedBox(height: 20),
                        sectionLabel('Condiciones'),
                        pills('Jornada', const ['Completa', 'Parcial', 'Por horas'], employmentType, (v) => employmentType = v),
                        const SizedBox(height: 18),
                        pills('Experiencia', const ['Sin experiencia', 'Se valora', 'Imprescindible'], experienceLevel, (v) => experienceLevel = v),
                        const SizedBox(height: 18),
                        labeled('Horario', scheduleCtrl, 'Ej. Lun a Vie, mañanas'),
                        const SizedBox(height: 16),
                        labeled('Extras', extrasCtrl, 'Ej. Plus propinas, auto de empresa'),
                        const SizedBox(height: 24),
                        Divider(height: 0.5, thickness: 0.5, color: hairline),
                        const SizedBox(height: 20),
                        sectionLabel('Sourcing'),
                        // ── Radar C-Level (tarjeta destacada con toggle) ──
                        GestureDetector(
                          onTap: () => setModalState(() => isConfidential = !isConfidential),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isConfidential ? MployaTheme.brandAccent.withValues(alpha: 0.08) : fieldBg,
                              border: Border.all(
                                color: isConfidential ? MployaTheme.brandAccent.withValues(alpha: 0.5) : hairline,
                                width: isConfidential ? 1 : 0.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34, height: 34,
                                  decoration: BoxDecoration(color: MployaTheme.brandAccent, borderRadius: BorderRadius.circular(9)),
                                  child: const Icon(CupertinoIcons.dot_radiowaves_left_right, color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Radar C-Level (confidencial)', style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text('Búsqueda discreta para perfiles senior', style: TextStyle(color: context.textTertiary, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                CupertinoSwitch(
                                  value: isConfidential,
                                  activeTrackColor: MployaTheme.brandAccent,
                                  onChanged: (v) => setModalState(() => isConfidential = v),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Footer: hint GPS + CTA ──
                  Divider(height: 0.5, thickness: 0.5, color: hairline),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            color: MployaTheme.brandAccent,
                            borderRadius: BorderRadius.circular(13),
                            onPressed: () async {
                              if (titleCtrl.text.isEmpty || isPublishing) return;

                              setModalState(() => isPublishing = true);

                              final uid = _supabase.auth.currentUser?.id;
                              if (uid != null) {
                                try {
                                  double? lat, lng;
                                  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                                  if (serviceEnabled) {
                                    LocationPermission permission = await Geolocator.checkPermission();
                                    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
                                      final pos = await Geolocator.getCurrentPosition(
                                        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
                                      );
                                      lat = pos.latitude;
                                      lng = pos.longitude;
                                    }
                                  }

                                  final listTags = tagsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                                  String? nn(String s) => s.trim().isEmpty ? null : s.trim();

                                  await _supabase.rpc('create_job_with_postgis', params: {
                                    'p_title': titleCtrl.text,
                                    'p_salary': salaryCtrl.text,
                                    'p_tags': listTags,
                                    'p_is_stealth': isConfidential,
                                    'p_lat': lat,
                                    'p_lng': lng,
                                    'p_description': nn(descCtrl.text),
                                    'p_employment_type': employmentType,
                                    'p_schedule': nn(scheduleCtrl.text),
                                    'p_experience_level': experienceLevel,
                                    'p_extras': nn(extrasCtrl.text),
                                  });

                                  if (!context.mounted) return;
                                  Navigator.pop(ctx);
                                  _fetchVacantes();
                                } catch (e) {
                                  debugPrint('Error creando job geoespacial: $e');
                                  setModalState(() => isPublishing = false);
                                }
                              }
                            },
                            child: isPublishing
                                ? const CupertinoActivityIndicator(color: Colors.white)
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(CupertinoIcons.briefcase_fill, size: 18, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('Publicar vacante', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.location_solid, size: 12, color: context.textTertiary),
                            const SizedBox(width: 5),
                            Text('Se publica con tu ubicación GPS', style: TextStyle(color: context.textTertiary, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  // ── Postulantes de una vacante puntual ──────────────────────────────────
  void _showApplicantsSheet(Map<String, dynamic> job) {
    final jobId = job['id'].toString();
    final jobTitle = job['title']?.toString() ?? 'Vacante';

    // 'applicants' = quienes se postularon · 'recommended' = ranking IA (embeddings)
    String mode = 'applicants';

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 36, height: 4, decoration: BoxDecoration(color: ctx.dividerColor, borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Candidatos', style: TextStyle(color: ctx.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                            Text(jobTitle, style: TextStyle(color: ctx.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Toggle: Postulantes / Recomendados por IA ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      _segTab(ctx, 'Postulantes', mode == 'applicants', () => setSheetState(() => mode = 'applicants')),
                      const SizedBox(width: 8),
                      _segTab(ctx, 'Recomendados por IA ✨', mode == 'recommended', () => setSheetState(() => mode = 'recommended')),
                    ],
                  ),
                ),
                Expanded(
                  child: mode == 'applicants'
                      ? _applicantsList(ctx, jobId)
                      : _recommendedList(ctx, jobId),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Pill de toggle del sheet de candidatos.
  Widget _segTab(BuildContext ctx, String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? MployaTheme.brandAccent : CupertinoColors.systemGrey6.resolveFrom(ctx),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : ctx.textSecondary,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // Lista de quienes se postularon (job_applications).
  Widget _applicantsList(BuildContext ctx, String jobId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchApplicants(jobId),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CupertinoActivityIndicator());
        final applicants = snap.data!;
        if (applicants.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Todavía no hay postulantes para esta vacante.',
                  textAlign: TextAlign.center, style: TextStyle(color: ctx.textTertiary)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: applicants.length,
          separatorBuilder: (_, __) => Divider(height: 1, indent: 68, color: ctx.dividerColor.withValues(alpha: 0.2)),
          itemBuilder: (_, i) {
            final a = applicants[i];
            final user = NexUser.fromJson(a);
            final status = a['_status']?.toString() ?? 'pending';
            return _candidateRow(ctx, user, trailing: _statusChip(status));
          },
        );
      },
    );
  }

  // Ranking de candidatos por IA (embeddings, match_candidates_for_job).
  Widget _recommendedList(BuildContext ctx, String jobId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AIMatchService.instance.getCandidatesForJob(jobId, limit: 25),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CupertinoActivityIndicator());
        final rows = snap.data!;
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Sin recomendaciones todavía.\nLa vacante y los perfiles necesitan estar vectorizados.',
                textAlign: TextAlign.center, style: TextStyle(color: ctx.textTertiary),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => Divider(height: 1, indent: 68, color: ctx.dividerColor.withValues(alpha: 0.2)),
          itemBuilder: (_, i) {
            final c = rows[i];
            final user = NexUser.fromJson(c);
            final pct = (c['match_percentage'] as num?)?.round() ?? 0;
            return _candidateRow(ctx, user, trailing: _matchChip(pct));
          },
        );
      },
    );
  }

  // Fila reutilizable de candidato (avatar + nombre + headline + trailing).
  Widget _candidateRow(BuildContext ctx, NexUser user, {required Widget trailing}) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: user))),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            NexAvatar(user: user, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: TextStyle(color: ctx.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                  if (user.headline.isNotEmpty)
                    Text(user.headline, style: TextStyle(color: ctx.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  // Chip de % de compatibilidad IA.
  Widget _matchChip(int pct) {
    final color = pct >= 70
        ? MployaTheme.success
        : pct >= 50
            ? MployaTheme.brandAccent
            : const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.sparkles, color: color, size: 12),
          const SizedBox(width: 4),
          Text('$pct%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final label = switch (status) {
      'accepted' => 'Aceptado',
      'rejected' => 'Rechazado',
      'viewed' => 'Visto',
      _ => 'Nuevo',
    };
    final color = switch (status) {
      'accepted' => MployaTheme.success,
      'rejected' => MployaTheme.danger,
      'viewed' => const Color(0xFF6B7280),
      _ => MployaTheme.brandAccent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchApplicants(String jobId) async {
    try {
      final apps = await _supabase
          .from('job_applications')
          .select('candidate_id, status')
          .eq('job_id', jobId);
      final ids = (apps as List).map((a) => a['candidate_id'].toString()).toList();
      if (ids.isEmpty) return [];
      final statusByCandidate = {for (final a in apps) a['candidate_id'].toString(): a['status']?.toString() ?? 'pending'};
      final users = await _supabase.from('users').select().inFilter('id', ids);
      return (users as List).map((u) {
        final map = Map<String, dynamic>.from(u as Map);
        map['_status'] = statusByCandidate[map['id'].toString()];
        return map;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching applicants: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebPage(
      title: 'Vacantes',
      subtitle: 'Gestioná tus búsquedas y revisá los candidatos.',
      leading: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: context.dividerColor.withValues(alpha: 0.5), width: 0.5),
          ),
          child: Icon(CupertinoIcons.chevron_left, size: 18, color: context.textSecondary),
        ),
      ),
      actions: [
        WebButton(icon: CupertinoIcons.add, label: 'Nueva vacante', onTap: _openCreate),
      ],
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _vacantes.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 4, bottom: 28),
                  child: WebGrid(children: [for (final job in _vacantes) _vacanteCard(job)]),
                ),
    );
  }

  Widget _buildEmptyState() => WebEmptyState(
        icon: CupertinoIcons.briefcase,
        title: 'Publicá tu primera vacante',
        subtitle: 'Creá una búsqueda y recibí video-pitches de los mejores perfiles. La IA te ayuda a redactarla en segundos.',
        actionLabel: 'Nueva vacante',
        actionIcon: CupertinoIcons.add,
        onAction: _openCreate,
      );

  Widget _vacanteCard(Map<String, dynamic> job) {
    final isStealth = job['type'] == 'Stealth';
    final count = _applicationCounts[job['id'].toString()] ?? 0;
    final title = (job['title'] ?? 'Sin título').toString();
    final salary = (job['salary_range'] ?? 'A convenir').toString();
    final location = (job['location'] ?? 'Remoto').toString();
    final hairline = context.dividerColor.withValues(alpha: 0.5);
    return WebCard(
      onTap: () => _showApplicantsSheet(job),
      borderColor: isStealth ? MployaTheme.brandAccent.withValues(alpha: 0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                child: const Icon(CupertinoIcons.briefcase_fill, color: MployaTheme.brandAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (isStealth)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Text('C-Level', style: TextStyle(color: MployaTheme.brandAccent, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            Icon(CupertinoIcons.money_dollar_circle, size: 15, color: context.textTertiary),
            const SizedBox(width: 5),
            Text(salary, style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 14),
            Icon(CupertinoIcons.location, size: 15, color: context.textTertiary),
            const SizedBox(width: 5),
            Flexible(child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.textSecondary, fontSize: 13))),
          ]),
          const SizedBox(height: 14),
          Divider(height: 0.5, thickness: 0.5, color: hairline),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(7)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(CupertinoIcons.person_2_fill, color: MployaTheme.brandAccent, size: 13),
                  const SizedBox(width: 5),
                  Text(count == 0 ? 'Sin postulantes' : '$count postulante${count == 1 ? '' : 's'}',
                      style: const TextStyle(color: MployaTheme.brandAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
              const Spacer(),
              Text('Ver candidatos', style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_right, size: 14, color: context.textTertiary),
            ],
          ),
        ],
      ),
    );
  }
}
