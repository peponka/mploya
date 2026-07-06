import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/nex_avatar.dart';
import 'profile_screen.dart';

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

    Widget field(BuildContext context, TextEditingController c, String placeholder, {int maxLines = 1}) {
      return CupertinoTextField(
        controller: c,
        placeholder: placeholder,
        maxLines: maxLines,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          Widget segmented(String label, List<String> options, String? value, ValueChanged<String> onPick) {
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: active ? MployaTheme.brandAccent : CupertinoColors.systemGrey6.resolveFrom(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(o, style: TextStyle(color: active ? Colors.white : context.textPrimary, fontWeight: active ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lanzar Nueva Búsqueda', style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          field(context, titleCtrl, 'Puesto (Ej. Bartender fin de semana)'),
                          const SizedBox(height: 14),
                          field(context, descCtrl, 'Descripción: qué va a hacer la persona…', maxLines: 4),
                          const SizedBox(height: 14),
                          field(context, salaryCtrl, 'Rango Salarial (Ej. \$90K - \$120K)'),
                          const SizedBox(height: 14),
                          field(context, scheduleCtrl, 'Horario (Ej. Jue a Dom, tardes)'),
                          const SizedBox(height: 14),
                          field(context, extrasCtrl, 'Extras (Ej. Plus propinas)'),
                          const SizedBox(height: 18),
                          segmented('Jornada', const ['Completa', 'Parcial', 'Por horas'], employmentType, (v) => employmentType = v),
                          const SizedBox(height: 18),
                          segmented('Experiencia', const ['Sin experiencia', 'Se valora', 'Imprescindible'], experienceLevel, (v) => experienceLevel = v),
                          const SizedBox(height: 18),
                          field(context, tagsCtrl, 'Skills / hashtags (#React, #B2B, #Ingles)'),
                          const SizedBox(height: 20),
                          Text('Estrategia de Sourcing:', style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => setModalState(() => isConfidential = !isConfidential),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isConfidential ? MployaTheme.brandAccent.withValues(alpha: 0.08) : CupertinoColors.systemGrey6.resolveFrom(context),
                                border: Border.all(color: isConfidential ? MployaTheme.brandAccent : Colors.transparent),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Radar C-Level (Confidencial)', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
                                  if (isConfidential) const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: MployaTheme.brandAccent)
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: MployaTheme.brandAccent,
                        borderRadius: BorderRadius.circular(30),
                        child: isPublishing
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : const Text('Publicar Vacante con GPS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                      ),
                    )
                  ],
                ),
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

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
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
                          Text('Postulantes', style: TextStyle(color: ctx.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                          Text(jobTitle, style: TextStyle(color: ctx.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchApplicants(jobId),
                  builder: (ctx, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CupertinoActivityIndicator());
                    }
                    final applicants = snap.data!;
                    if (applicants.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Todavía no hay postulantes para esta vacante.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ctx.textTertiary),
                          ),
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
                                _statusChip(status),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
    return CupertinoPageScaffold(
      backgroundColor: context.bgColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: context.bgColor,
        middle: Text('Mis Vacantes Activas', style: TextStyle(color: context.textPrimary)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showCreateJobModal,
          child: const Icon(CupertinoIcons.add_circled_solid, color: MployaTheme.brandAccent),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _vacantes.isEmpty
               ? _buildEmptyState()
               : ListView.builder(
                   padding: const EdgeInsets.all(16),
                   itemCount: _vacantes.length,
                   itemBuilder: (context, index) {
                     final job = _vacantes[index];
                     final isStealth = job['type'] == 'Stealth';
                     final count = _applicationCounts[job['id'].toString()] ?? 0;
                     return Padding(
                       padding: const EdgeInsets.only(bottom: 16),
                       child: GestureDetector(
                         onTap: () => _showApplicantsSheet(job),
                         behavior: HitTestBehavior.opaque,
                         child: _buildVacanteCard(
                             job['title'] ?? 'Sin Título',
                             '${job['salary_range'] ?? 'Salario No Info'} / ${job['location'] ?? 'Remoto'}',
                             count,
                             isStealth
                         ),
                       ),
                     );
                   },
                 ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text('No has publicado vacantes.\n\nToca el icono "+" arriba a la derecha para lanzar tu primera búsqueda.', textAlign: TextAlign.center, style: TextStyle(color: context.textTertiary)),
    ),
  );

  Widget _buildVacanteCard(String title, String subtitle, int matchCount, bool isStealth) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.cardShadow,
        border: isStealth ? Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.3)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold))),
              if (isStealth)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Text('C-Level Radar', style: TextStyle(color: MployaTheme.brandAccent, fontSize: 10, fontWeight: FontWeight.w800)),
                )
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: context.textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(CupertinoIcons.person_2_fill, color: MployaTheme.brandAccent, size: 16),
              const SizedBox(width: 8),
              Text(
                matchCount == 0 ? 'Sin postulantes todavía' : '$matchCount postulante${matchCount == 1 ? '' : 's'} · Ver',
                style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Icon(CupertinoIcons.chevron_right, size: 14, color: context.textTertiary),
            ],
          ),
        ],
      ),
    );
  }
}
