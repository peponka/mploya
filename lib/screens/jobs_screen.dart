import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import 'camera_screen.dart';
import '../widgets/job_heatmap_bar.dart';
import '../services/ghost_apply_service.dart';
import '../services/saved_jobs_service.dart';
import '../widgets/coach_mark.dart';
import '../widgets/web_ui.dart';
import '../widgets/mploya_toast.dart';
import 'saved_jobs_screen.dart';
import 'create_job_screen.dart';
import 'job_detail_screen.dart';

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _jobs = [];
  String _selectedFilter = 'Para Ti';
  Map<String, int> _matchScores = {};
  final Set<String> _appliedJobIds = {};

  // ── Filtros avanzados (solo panel web) — aplicados en cliente sobre _jobs,
  // igual que _selectedFilter, sin pegarle de nuevo al backend. ──
  final Set<String> _skillsFilter = {};
  String _companyFilter = '';
  bool _onlySalary = false;

  // ── Barra de filtros web (Ubicación / Tipo / Seniority / Buscar) — mismos
  // valores reales que usa create_job_screen.dart al publicar una vacante. ──
  String? _locationFilter;
  String? _modalityFilter;
  String? _seniorityFilter;
  String _titleSearch = '';

  static const Map<String, String> _modalityLabels = {
    'remote': 'Remoto',
    'hybrid': 'Híbrido',
    'onsite': 'Presencial',
  };

  static const Map<String, String> _seniorityLabels = {
    'junior': 'Junior',
    'mid': 'Mid-Level',
    'senior': 'Senior',
    'lead': 'Lead / Manager',
    'clevel': 'C-Level / Director',
  };

  List<Map<String, dynamic>> get _visibleJobs {
    var jobs = _jobs;
    if (_skillsFilter.isNotEmpty) {
      jobs = jobs.where((j) {
        final tags = ((j['tags'] as List?) ?? []).map((t) => t.toString().toLowerCase()).toSet();
        return tags.intersection(_skillsFilter).isNotEmpty;
      }).toList();
    }
    if (_companyFilter.trim().isNotEmpty) {
      final q = _companyFilter.trim().toLowerCase();
      jobs = jobs.where((j) {
        final companyName = ((j['users'] as Map?)?['name']?.toString() ?? j['company']?.toString() ?? '').toLowerCase();
        return companyName.contains(q);
      }).toList();
    }
    if (_onlySalary) {
      jobs = jobs.where((j) {
        final s = j['salary_range']?.toString() ?? j['salary']?.toString() ?? '';
        return s.trim().isNotEmpty;
      }).toList();
    }
    if (_locationFilter != null) {
      jobs = jobs.where((j) => j['location']?.toString() == _locationFilter).toList();
    }
    if (_modalityFilter != null) {
      jobs = jobs.where((j) => j['modality']?.toString() == _modalityFilter).toList();
    }
    if (_seniorityFilter != null) {
      jobs = jobs.where((j) => j['seniority']?.toString() == _seniorityFilter).toList();
    }
    if (_titleSearch.trim().isNotEmpty) {
      final q = _titleSearch.trim().toLowerCase();
      jobs = jobs.where((j) => (j['title']?.toString().toLowerCase() ?? '').contains(q)).toList();
    }
    return jobs;
  }

  List<String> get _availableSkills {
    final counts = <String, int>{};
    for (final j in _jobs) {
      for (final t in ((j['tags'] as List?) ?? [])) {
        final tag = t.toString().toLowerCase().trim();
        if (tag.isNotEmpty) counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(12).map((e) => e.key).toList();
  }

  List<String> get _availableLocations {
    final set = <String>{};
    for (final j in _jobs) {
      final loc = j['location']?.toString().trim() ?? '';
      if (loc.isNotEmpty) set.add(loc);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _availableCompanies {
    final set = <String>{};
    for (final j in _jobs) {
      final name = ((j['users'] as Map?)?['name']?.toString() ?? j['company']?.toString() ?? '').trim();
      if (name.isNotEmpty) set.add(name);
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  // Token anti-carrera: si el usuario cambia de filtro rápido, solo el último
  // fetch tiene derecho a escribir el resultado (evita que una respuesta vieja
  // pise a una nueva y las vacantes "aparezcan y desaparezcan").
  int _fetchSeq = 0;

  Future<void> _fetchJobs() async {
    final int seq = ++_fetchSeq;
    setState(() => _isLoading = true);

    // Una sola consulta confiable: no depende de columnas que la tabla puede no
    // tener (antes filtraba por is_active/modality/seniority, inexistentes, y la
    // query fallaba). El filtrado Remoto/Presencial/C-Level se hace del lado del
    // cliente sobre los datos que sí existen.
    List<Map<String, dynamic>> jobs = [];
    try {
      final res = await _supabase
          .from('jobs')
          .select('*, users!jobs_company_id_fkey(name, avatar_url)')
          .order('created_at', ascending: false)
          .limit(50);
      jobs = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetch jobs (con join): $e');
      try {
        final res = await _supabase
            .from('jobs')
            .select()
            .order('created_at', ascending: false)
            .limit(50);
        jobs = List<Map<String, dynamic>>.from(res);
      } catch (e2) {
        debugPrint('Error fetch jobs (fallback): $e2');
        jobs = [];
      }
    }

    jobs = _applyClientFilter(jobs);

    if (_selectedFilter == 'Para Ti') {
      jobs = await _rankJobsForUser(jobs);
    }

    // Solo el fetch más reciente escribe el resultado.
    if (mounted && seq == _fetchSeq) {
      setState(() {
        _jobs = jobs;
        _isLoading = false;
      });
    }
  }

  // Filtro best-effort sobre campos que sí existen (location, tags, title).
  List<Map<String, dynamic>> _applyClientFilter(List<Map<String, dynamic>> jobs) {
    bool isRemote(Map<String, dynamic> j) =>
        (j['location']?.toString().toLowerCase() ?? '').contains('remoto');
    bool isClevel(Map<String, dynamic> j) {
      final hay = '${j['title'] ?? ''} ${(j['tags'] as List?)?.join(' ') ?? ''}'.toLowerCase();
      return ['c-level', 'clevel', 'cto', 'cfo', 'ceo', 'director', 'lead', 'head'].any(hay.contains);
    }

    switch (_selectedFilter) {
      case 'Remoto':
        return jobs.where(isRemote).toList();
      case 'Presencial':
        return jobs.where((j) => !isRemote(j)).toList();
      case 'C-Level':
        return jobs.where(isClevel).toList();
      default:
        return jobs;
    }
  }

  Future<List<Map<String, dynamic>>> _rankJobsForUser(List<Map<String, dynamic>> jobs) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return jobs;

    try {
      final userData = await _supabase
          .from('users')
          .select('tags, skills')
          .eq('id', uid)
          .maybeSingle();

      final userTags = List<String>.from(userData?['tags'] ?? []);
      final userSkills = List<String>.from(userData?['skills'] ?? []);

      if (userTags.isEmpty && userSkills.isEmpty) return jobs;

      final scores = <String, int>{};
      for (final job in jobs) {
        final jobId = job['id']?.toString() ?? '';
        final jobTags = List<String>.from(job['tags'] ?? []);
        final jobTitle = job['title']?.toString().toLowerCase() ?? '';

        int score = 0;
        for (final t in userTags) {
          if (jobTags.any((jt) => jt.toLowerCase() == t.toLowerCase())) score += 20;
          if (jobTitle.contains(t.toLowerCase())) score += 10;
        }
        for (final s in userSkills) {
          if (jobTags.any((jt) => jt.toLowerCase() == s.toLowerCase())) score += 15;
        }
        scores[jobId] = score.clamp(0, 100);
      }

      if (mounted) setState(() => _matchScores = scores);

      jobs.sort((a, b) {
        final sa = scores[a['id']?.toString() ?? ''] ?? 0;
        final sb = scores[b['id']?.toString() ?? ''] ?? 0;
        return sb.compareTo(sa);
      });
    } catch (e) {
      debugPrint('Error ranking jobs: $e');
    }

    return jobs;
  }

  void _applyToJob(String jobId, String jobTitle) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    // Verificar si el usuario ya tiene un Video-Pitch usando la DB
    final userData = await _supabase
        .from('users')
        .select('video_url')
        .eq('id', uid)
        .maybeSingle();

    final hasPitch = userData != null &&
        userData['video_url'] != null &&
        userData['video_url'].toString().isNotEmpty;

    // Check if the user is a confidential candidate → offer Ghost Apply
    final accountType = await _supabase
        .from('users')
        .select('account_type')
        .eq('id', uid)
        .maybeSingle();
    final isConfidential = accountType?['account_type'] == 'confidencial' ||
        accountType?['account_type'] == 'stealth';

    bool forceCamera = false;

    if (!mounted) return;
    if (hasPitch) {
      final reuse = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('¿Cómo quieres aplicar?'),
          content: const Text(
              'Ya cuentas con un Video-Pitch en tu perfil. ¿Deseas enviarlo o prefieres grabar uno nuevo específico para destacar en esta vacante?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false), // Grabar Nuevo
              child: const Text('Grabar Nuevo'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx, true), // Usar Guardado
              child: const Text('Usar Guardado'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, null), // Cancelar
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );

      if (reuse == null) return; // Canceló
      if (reuse == false) forceCamera = true;
    } else {
      forceCamera = true; // No tiene pitch, obligar cámara
    }

    // Offer Ghost Apply for confidential candidates
    if (!mounted) return;
    if (isConfidential && !forceCamera) {
      final ghostChoice = await showCupertinoModalPopup<String>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Modo de Aplicación'),
          message: const Text('Como candidato confidencial, podés aplicar de forma anónima.'),
          actions: [
            CupertinoActionSheetAction(
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('👻 '),
                  Text('Aplicar como Ghost', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              onPressed: () => Navigator.pop(ctx, 'ghost'),
            ),
            CupertinoActionSheetAction(
              child: const Text('Aplicar con Identidad'),
              onPressed: () => Navigator.pop(ctx, 'normal'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
        ),
      );

      if (ghostChoice == null) return;
      if (ghostChoice == 'ghost') {
        // Ghost Apply flow
        setState(() => _appliedJobIds.add(jobId));
        final error = await GhostApplyService.instance.ghostApply(
          jobId: jobId,
          jobTitle: jobTitle,
        );
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: Text(error == null ? '👻 Ghost Apply Enviado' : 'Aviso'),
              content: Text(error ?? 'Tu CV ciego fue enviado a la empresa. '
                  'Solo podrán ver tu identidad si pagan un token.'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    if (forceCamera) {
      // Fricción Estratégica: Grabar/Confirmar Video-Pitch
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const CameraScreen()),
      );

      // Si el usuario cancela o no graba/sube el pitch, abortamos la postulación
      if (result != true) return;
    }

    setState(() => _appliedJobIds.add(jobId));

    // Insertar notificación al dueño del job
    try {
      final job = _jobs.firstWhere((j) => j['id'].toString() == jobId, orElse: () => {});
      final companyId = job['company_id']?.toString();
      if (companyId != null) {
        final userData = await _supabase.from('users').select('name').eq('id', uid).maybeSingle();
        final userName = userData?['name'] ?? 'Un candidato';
        await _supabase.rpc('create_system_notification', params: {
          'p_user_id': companyId,
          'p_type': 'jobAlert',
          'p_description': '📩 $userName aplicó a tu vacante "$jobTitle".',
          'p_actor_id': uid,
        });
      }
    } catch (e) {
      debugPrint('Error notificando aplicación: $e');
    }

    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('¡Aplicación enviada!'),
          content: Text('Tu perfil fue enviado para "$jobTitle". La empresa recibirá tu Video-Pitch.'),
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: context.bgColor.withValues(alpha: 0.8),
        middle: const Text('Vacantes'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const SavedJobsScreen()),
              ),
              child: Icon(CupertinoIcons.bookmark_fill, size: 20, color: context.brandAccent),
            ),
            const SizedBox(width: 12),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: _fetchJobs,
              child: Icon(CupertinoIcons.refresh, size: 22, color: context.brandAccent),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? _buildLoadingSkeleton()
            : _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final visible = _visibleJobs;
    final list = visible.isEmpty ? _buildEmptyState() : _buildJobsList(visible);
    if (!isWebWide(context)) return list;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: list),
        SizedBox(
          width: 280,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
            child: _buildFiltersSidebar(context),
          ),
        ),
      ],
    );
  }

  Widget _buildJobsList(List<Map<String, dynamic>> visible) {
    return CustomScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      // ── Pull-to-Refresh nativo iOS ──
                      CupertinoSliverRefreshControl(
                        onRefresh: () async {
                          HapticFeedback.mediumImpact();
                          await _fetchJobs();
                        },
                      ),
                      // ── Barra de filtros web (Ubicación / Tipo / Seniority / Buscar) ──
                      if (isWebWide(context))
                        SliverToBoxAdapter(child: _buildWebFilterBar(context))
                      else
                        // ── Filtros (pills, mobile) ──
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 50,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              children: ['Para Ti', 'Todos', 'Remoto', 'Presencial', 'C-Level']
                                  .map((f) => Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() => _selectedFilter = f);
                                            _fetchJobs();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: _selectedFilter == f ? context.brandAccent : context.cardColor,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: _selectedFilter == f ? Colors.transparent : context.dividerColor.withValues(alpha: 0.5),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Text(
                                              f,
                                              style: TextStyle(
                                                color: _selectedFilter == f ? Colors.white : context.textSecondary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),

                      // ── Coach Banner (first visit) ──
                      SliverToBoxAdapter(
                        child: CoachBanner(
                          id: 'jobs_intro',
                          icon: CupertinoIcons.bookmark_fill,
                          title: 'Guardá vacantes',
                          message: 'Tocá el ícono 🔖 en cada tarjeta para guardar las vacantes que te interesan.',
                        ),
                      ),

                      // ── Job Cards (grilla responsive: 2 columnas en web) ──
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: WebGrid(children: [
                            for (int index = 0; index < visible.length; index++)
                              Builder(builder: (context) {
                                final job = visible[index];
                                final jobId = job['id']?.toString() ?? '';
                                final matchScore = _matchScores[jobId];
                                final effectiveScore = matchScore != null && matchScore > 0 ? matchScore : null;
                                void apply() => _applyToJob(jobId, job['title']?.toString() ?? 'Vacante');
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => Navigator.of(context).push(
                                    CupertinoPageRoute(
                                      builder: (_) => JobDetailScreen(
                                        job: job,
                                        matchScore: effectiveScore,
                                        isApplied: _appliedJobIds.contains(jobId),
                                        onApply: apply,
                                      ),
                                    ),
                                  ),
                                  child: _JobListCard(
                                    job: job,
                                    isApplied: _appliedJobIds.contains(jobId),
                                    matchScore: effectiveScore,
                                    onApply: apply,
                                  ),
                                );
                              }),
                          ]),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  );
  }

  Widget _buildWebFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _dropdownChip(
            context,
            label: 'Ubicación',
            value: _locationFilter,
            options: _availableLocations,
            onSelect: (v) => setState(() => _locationFilter = v),
          ),
          _dropdownChip(
            context,
            label: 'Tipo',
            value: _modalityFilter != null ? _modalityLabels[_modalityFilter] : null,
            options: _modalityLabels.values.toList(),
            onSelect: (v) => setState(() =>
                _modalityFilter = v == null ? null : _modalityLabels.entries.firstWhere((e) => e.value == v).key),
          ),
          _dropdownChip(
            context,
            label: 'Seniority',
            value: _seniorityFilter != null ? _seniorityLabels[_seniorityFilter] : null,
            options: _seniorityLabels.values.toList(),
            onSelect: (v) => setState(() =>
                _seniorityFilter = v == null ? null : _seniorityLabels.entries.firstWhere((e) => e.value == v).key),
          ),
          SizedBox(
            width: 220,
            child: CupertinoTextField(
              placeholder: 'Buscar vacante...',
              prefix: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Icon(CupertinoIcons.search, size: 16, color: context.textTertiary),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.dividerColor.withValues(alpha: 0.4)),
              ),
              style: TextStyle(fontSize: 13, color: context.textPrimary),
              onChanged: (v) => setState(() => _titleSearch = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownChip(
    BuildContext context, {
    required String label,
    required String? value,
    required List<String> options,
    required void Function(String?) onSelect,
  }) {
    return GestureDetector(
      onTap: () async {
        final choice = await showCupertinoModalPopup<String>(
          context: context,
          builder: (ctx) => CupertinoActionSheet(
            title: Text(label),
            actions: [
              CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Todos')),
              ...options.map((o) => CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, o), child: Text(o))),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx),
              isDefaultAction: true,
              child: const Text('Cancelar'),
            ),
          ),
        );
        if (choice == null) return;
        onSelect(choice.isEmpty ? null : choice);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.dividerColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value ?? label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: value != null ? context.textPrimary : context.textSecondary)),
            const SizedBox(width: 6),
            Icon(CupertinoIcons.chevron_down, size: 12, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSidebar(BuildContext context) {
    final skills = _availableSkills;
    return SingleChildScrollView(
      child: WebCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WebSectionLabel('Refiná tu búsqueda'),
            Text('Por Empresa', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
            const SizedBox(height: 8),
            CupertinoTextField(
              placeholder: 'Ej. Globant, MercadoLibre...',
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.dividerColor.withValues(alpha: 0.4)),
              ),
              style: TextStyle(fontSize: 13, color: context.textPrimary),
              onChanged: (v) => setState(() => _companyFilter = v),
            ),
            if (_availableCompanies.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _availableCompanies.take(8).map((c) {
                  final active = _companyFilter.trim().toLowerCase() == c.toLowerCase();
                  return GestureDetector(
                    onTap: () => setState(() => _companyFilter = active ? '' : c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? context.brandAccent : (context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(c, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: active ? CupertinoColors.white : context.textSecondary)),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 18),
            Text('Skills', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
            const SizedBox(height: 8),
            if (skills.isEmpty)
              Text('Sin datos todavía', style: TextStyle(fontSize: 12.5, color: context.textTertiary))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: skills.map((s) {
                  final active = _skillsFilter.contains(s);
                  return GestureDetector(
                    onTap: () => setState(() => active ? _skillsFilter.remove(s) : _skillsFilter.add(s)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? context.brandAccent : (context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('#$s',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: active ? CupertinoColors.white : context.textSecondary)),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 18),
            Text('Rango Salarial', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text('Con salario informado',
                      style: TextStyle(fontSize: 12.5, color: context.textSecondary)),
                ),
                CupertinoSwitch(
                  value: _onlySalary,
                  activeTrackColor: context.brandAccent,
                  onChanged: (v) => setState(() => _onlySalary = v),
                ),
              ],
            ),
            if (_skillsFilter.isNotEmpty ||
                _companyFilter.isNotEmpty ||
                _onlySalary ||
                _locationFilter != null ||
                _modalityFilter != null ||
                _seniorityFilter != null ||
                _titleSearch.isNotEmpty) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => setState(() {
                  _skillsFilter.clear();
                  _companyFilter = '';
                  _onlySalary = false;
                  _locationFilter = null;
                  _modalityFilter = null;
                  _seniorityFilter = null;
                  _titleSearch = '';
                }),
                child: Text('Limpiar filtros',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.brandAccent)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final userAsync = ref.watch(currentUserProvider);
    final isCompany = userAsync.value?.accountType == 'empresa' || userAsync.value?.accountType == 'headhunter';
    
    return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.briefcase, size: 56, color: context.textTertiary.withValues(alpha: 0.3)),
              const SizedBox(height: 20),
              Text(
                isCompany ? 'No tienes vacantes activas' : 'No hay vacantes disponibles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isCompany
                  ? 'Publicá tu primera posición para recibir video-pitches de los mejores perfiles.'
                  : 'Las empresas publicarán oportunidades pronto. ¡Mantené tu perfil actualizado!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.textTertiary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (isCompany) {
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(builder: (_) => const CreateJobScreen()),
                    );
                  } else {
                    _fetchJobs();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                  decoration: NexTheme.gradientButtonDecoration(borderRadius: 24),
                  child: Text(
                    isCompany ? 'Publicar vacante' : 'Actualizar',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: context.dividerColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 160, height: 16,
                          decoration: BoxDecoration(
                            color: context.dividerColor.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 100, height: 12,
                          decoration: BoxDecoration(
                            color: context.dividerColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: 120, height: 28,
                decoration: BoxDecoration(
                  color: context.dividerColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity, height: 44,
                decoration: BoxDecoration(
                  color: context.dividerColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Job Card Widget ──
class _JobListCard extends StatefulWidget {
  final Map<String, dynamic> job;
  final bool isApplied;
  final VoidCallback onApply;
  final int? matchScore;

  const _JobListCard({
    required this.job,
    required this.isApplied,
    required this.onApply,
    this.matchScore,
  });

  @override
  State<_JobListCard> createState() => _JobListCardState();
}

class _JobListCardState extends State<_JobListCard> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final id = widget.job['id']?.toString();
    if (id == null) return;
    final s = await SavedJobsService.instance.isJobSaved(id);
    if (mounted) setState(() => _saved = s);
  }

  Map<String, dynamic> get job => widget.job;
  bool get isApplied => widget.isApplied;
  VoidCallback get onApply => widget.onApply;

  @override
  Widget build(BuildContext context) {
    final title = job['title']?.toString() ?? 'Sin título';
    final salary = job['salary_range']?.toString() ?? job['salary']?.toString();
    final isStealth = job['type'] == 'Stealth' || job['is_stealth'] == true;
    final companyData = job['users'] as Map<String, dynamic>?;
    final companyName = companyData?['name']?.toString() ?? 'Empresa';
    final companyAvatar = companyData?['avatar_url']?.toString();
    final tagsRaw = job['tags'];
    final tags = tagsRaw is List ? tagsRaw.map((t) => t.toString()).toList() : <String>[];
    final createdAt = job['created_at']?.toString() ?? '';

    final matchScore = widget.matchScore ?? 0;
    final location = job['location']?.toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: isStealth
            ? Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.35), width: 1.5)
            : Border.all(color: context.dividerColor.withValues(alpha: 0.18), width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Company + Stealth badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Company avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [context.brandAccent.withValues(alpha: 0.16), context.brandAccent.withValues(alpha: 0.08)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  image: (companyAvatar != null && companyAvatar.isNotEmpty)
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(companyAvatar),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (companyAvatar == null || companyAvatar.isEmpty)
                    ? Center(
                        child: Text(
                          companyName[0].toUpperCase(),
                          style: TextStyle(
                            color: context.brandAccent,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Match % circle ──
              if (matchScore > 0)
                SizedBox(
                  width: 52, height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 48, height: 48,
                        child: CircularProgressIndicator(
                          value: matchScore / 100,
                          strokeWidth: 4,
                          backgroundColor: context.dividerColor.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation(matchScore >= 80 ? const Color(0xFF34C759) : matchScore >= 50 ? MployaTheme.brandAccent : context.textTertiary),
                        ),
                      ),
                      Text('$matchScore%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.textPrimary)),
                    ],
                  ),
                ),
              // ── Bookmark ──
              GestureDetector(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  final id = job['id']?.toString();
                  if (id == null) return;
                  await SavedJobsService.instance.toggleSave(id);
                  if (mounted) {
                    setState(() => _saved = !_saved);
                    if (_saved) {
                      MployaToast.saved(context, 'Vacante guardada');
                    } else {
                      MployaToast.removed(context, 'Vacante eliminada de guardados');
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    _saved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                    size: 20,
                    color: _saved ? MployaTheme.brandAccent : context.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Badges: match IA, stealth, salario — misma altura, mismo idioma visual
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.matchScore != null && widget.matchScore! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: kMployaPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.sparkles, size: 12, color: kMployaPurple),
                      const SizedBox(width: 5),
                      Text(
                        '${widget.matchScore}% match',
                        style: const TextStyle(color: kMployaPurple, fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              if (isStealth)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDAA520).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.lock_fill, size: 11, color: Color(0xFFDAA520)),
                      SizedBox(width: 5),
                      Text(
                        'C-Level',
                        style: TextStyle(color: Color(0xFFDAA520), fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              if (salary != null && salary.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.brandAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.money_dollar_circle, size: 13, color: context.brandAccent),
                      const SizedBox(width: 5),
                      Text(
                        salary,
                        style: TextStyle(color: context.brandAccent, fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Tags
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.take(5).map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: context.isDark ? CupertinoColors.systemGrey6.darkColor : const Color(0xFFF3F3F5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag.startsWith('#') ? tag : '#$tag',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )).toList(),
            ),
          ],
          
          if (createdAt.isNotEmpty && DateTime.tryParse(createdAt) != null) ...[
            const SizedBox(height: 18),
            JobHeatmapBar(createdAt: DateTime.parse(createdAt).toLocal()),
          ],
          const SizedBox(height: 18),

          // ── Location row ──
          if (location != null && location.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(CupertinoIcons.location_solid, size: 13, color: context.textTertiary),
              const SizedBox(width: 5),
              Flexible(child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500))),
            ]),
          ],

          // Apply button (premium gradient)
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: isApplied ? null : onApply,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: isApplied ? null : const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFE2860B), Color(0xFFD4740A)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  color: isApplied ? CupertinoColors.systemGrey4 : null,
                  boxShadow: isApplied ? null : [
                    BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isApplied ? CupertinoIcons.checkmark_alt : CupertinoIcons.videocam_fill,
                      size: 17,
                      color: isApplied ? CupertinoColors.systemGrey : Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isApplied ? 'Aplicación enviada' : '▶ Aplicar con Video',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isApplied ? CupertinoColors.systemGrey : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}