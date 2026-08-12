import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../providers/feed_provider.dart';
import '../services/ai_match_service.dart';
import '../services/video_preload_manager.dart';
import '../widgets/candidate_talent_reel_card.dart';
import '../widgets/mploya_shell.dart';
import 'ats_dashboard_screen.dart';
import 'chat_inmail_screen.dart';
import 'nueva_vacante_screen.dart';
import 'profile_screen.dart';
import 'scheduling_screen.dart';

class CompanyTalentFeedScreen extends ConsumerStatefulWidget {
  const CompanyTalentFeedScreen({super.key});

  @override
  ConsumerState<CompanyTalentFeedScreen> createState() =>
      _CompanyTalentFeedScreenState();
}

class _CompanyTalentFeedScreenState
    extends ConsumerState<CompanyTalentFeedScreen> {
  final PageController _pageController = PageController();

  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _jobMatches = [];
  String? _selectedJobId;
  bool _loadingJobs = true;
  bool _loadingMatches = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedProvider.notifier).refreshFeed();
      _loadJobs();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loadingJobs = false);
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('jobs')
          .select(
            'id, title, location, salary_range, tags, is_active, created_at',
          )
          .eq('company_id', uid)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _jobs = List<Map<String, dynamic>>.from(res);
        _loadingJobs = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingJobs = false);
    }
  }

  Future<void> _selectJob(String? jobId) async {
    if (!mounted) return;
    setState(() {
      _selectedJobId = jobId;
      _loadingMatches = jobId != null;
      _jobMatches = [];
      _currentPage = 0;
    });
    if (jobId == null) return;
    final rows = await AIMatchService.instance.getCandidatesForJob(
      jobId,
      limit: 30,
    );
    if (!mounted) return;
    setState(() {
      _jobMatches = rows;
      _loadingMatches = false;
    });
    _pageController.jumpToPage(0);
    _primeVideoPreload(_activeRows());
  }

  Future<void> _openJobSelector() async {
    if (_jobs.isEmpty) {
      await Navigator.of(
        context,
      ).push(CupertinoPageRoute(builder: (_) => const NuevaVacanteScreen()));
      await _loadJobs();
      return;
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Seleccionar vacante'),
        message: const Text(
          'El Match IA en Empresa siempre se calcula contra una vacante concreta.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _selectJob(null);
            },
            child: const Text('Ver talento sin comparar vacante'),
          ),
          for (final job in _jobs.take(8))
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _selectJob(job['id']?.toString());
              },
              child: Text(job['title']?.toString() ?? 'Vacante'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Map<String, dynamic>? _selectedJob() {
    if (_selectedJobId == null) return null;
    for (final job in _jobs) {
      if (job['id']?.toString() == _selectedJobId) return job;
    }
    return null;
  }

  List<Map<String, dynamic>> _activeRows() {
    if (_selectedJobId != null && _jobMatches.isNotEmpty) {
      return _jobMatches;
    }
    final items = ref.read(feedProvider).items;
    return items.where((row) {
      final type = row['account_type']?.toString().toLowerCase() ?? '';
      final video = row['video_url']?.toString() ?? '';
      return (type == 'candidato' ||
              type.startsWith('confidenc') ||
              type == 'stealth') &&
          video.isNotEmpty;
    }).toList();
  }

  void _primeVideoPreload(List<Map<String, dynamic>> rows) {
    final urls = rows
        .map((row) => row['video_url']?.toString() ?? '')
        .where((url) => url.isNotEmpty)
        .toList();
    VideoPreloadManager.instance.updateFeedUrls(urls);
  }

  NexUser _currentCandidate(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const NexUser(
        id: 'empty',
        name: 'Sin talento',
        headline: 'Todavía no encontramos candidatos con video pitch.',
      );
    }
    final index = _currentPage.clamp(0, rows.length - 1);
    return NexUser.fromJson(rows[index]);
  }

  int? _currentMatch(List<Map<String, dynamic>> rows) {
    if (_selectedJobId == null || rows.isEmpty) return null;
    final index = _currentPage.clamp(0, rows.length - 1);
    return (rows[index]['match_percentage'] as num?)?.round();
  }

  Widget _emptyState({required bool noJobs}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.person_3_fill,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              noJobs
                  ? 'Publicá una vacante para activar tu motor de talento'
                  : 'Todavía no hay candidatos listos para este contexto',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              noJobs
                  ? 'El feed sigue disponible sin vacante seleccionada, pero el Match IA y el contexto recruiter funcionan mejor cuando comparás contra una búsqueda activa.'
                  : 'Probá otra vacante o volvé al feed general para descubrir talento con video pitch.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFD6DCF0),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: noJobs
                  ? () => Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const NuevaVacanteScreen(),
                      ),
                    )
                  : _openJobSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B4DFF), Color(0xFF4A32D8)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  noJobs ? 'Crear vacante' : 'Cambiar vacante',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topOverlay(List<Map<String, dynamic>> rows) {
    final selectedJob = _selectedJob();
    final total = rows.length;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: MployaGlassPanel(
                  radius: 22,
                  blur: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  color: const Color(0xFF111827).withValues(alpha: 0.58),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Feed talento',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedJob == null
                            ? '$total candidatos con video pitch'
                            : '${selectedJob['title']} · $total candidatos',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFD6DCF0),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _openJobSelector,
                child: MployaGlassPanel(
                  radius: 20,
                  blur: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  color: const Color(0xFF111827).withValues(alpha: 0.58),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.briefcase_fill,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        selectedJob == null ? 'Vacante' : 'Cambiar',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopSidebar(List<Map<String, dynamic>> rows) {
    final candidate = _currentCandidate(rows);
    final selectedJob = _selectedJob();
    final match = _currentMatch(rows);
    final transcript = candidate.aiTranscript.isNotEmpty
        ? candidate.aiTranscript.first.text
        : null;

    return SizedBox(
      width: 360,
      child: Column(
        children: [
          MployaShellCard(
            radius: 28,
            color: const Color(0xFF11172A),
            borderColor: const Color(0xFF2A3350),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B4DFF).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        CupertinoIcons.sparkles,
                        color: Color(0xFFC5BCFF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Match IA contextual',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Empresa compara talento contra una vacante real.',
                            style: TextStyle(
                              color: Color(0xFFB6C1DB),
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (selectedJob != null) ...[
                  Text(
                    selectedJob['title']?.toString() ?? 'Vacante seleccionada',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [
                      selectedJob['location']?.toString() ??
                          'Ubicación flexible',
                      selectedJob['salary_range']?.toString() ??
                          'Rango reservado',
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB6C1DB),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171E33),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(
                                0xFF4ADE80,
                              ).withValues(alpha: 0.4),
                              width: 6,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            match == null ? '--' : '$match%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            match == null
                                ? 'Elegí una vacante para activar el cálculo contextual.'
                                : '${candidate.name} aparece en el contexto activo del proceso.',
                            style: const TextStyle(
                              color: Color(0xFFDCE3F7),
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171E33),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Text(
                      'Todavía no hay vacante seleccionada. El feed sigue mostrando candidatos reales, pero el Match IA queda en pausa hasta que elijas una búsqueda.',
                      style: TextStyle(
                        color: Color(0xFFDCE3F7),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _openJobSelector,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6B4DFF), Color(0xFF4A32D8)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      selectedJob == null
                          ? 'Seleccionar vacante'
                          : 'Cambiar vacante',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          MployaShellCard(
            radius: 28,
            color: const Color(0xFF11172A),
            borderColor: const Color(0xFF2A3350),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contexto profesional',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 14),
                _sidebarRow(
                  'Perfil',
                  candidate.headline.isEmpty
                      ? candidate.name
                      : candidate.headline,
                ),
                _sidebarRow(
                  'Ubicación',
                  candidate.location ?? 'No especificada',
                ),
                _sidebarRow(
                  'Disponibilidad',
                  candidate.isOpenToWork
                      ? 'Abierto a conversar'
                      : 'Perfil activo',
                ),
                _sidebarRow(
                  'Skills',
                  candidate.skills.take(3).join(' · ').isEmpty
                      ? 'Sin skills visibles'
                      : candidate.skills.take(3).join(' · '),
                ),
                if (transcript != null && transcript.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171E33),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      transcript.trim(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFDCE3F7),
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _sidebarButton(
                      label: 'Ver perfil',
                      filled: false,
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => ProfileScreen(user: candidate),
                        ),
                      ),
                    ),
                    _sidebarButton(
                      label: 'Contactar',
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) =>
                              ChatInmailScreen(targetUser: candidate),
                        ),
                      ),
                    ),
                    _sidebarButton(
                      label: 'Entrevista',
                      filled: false,
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) =>
                              const SchedulingScreen(isCompany: true),
                        ),
                      ),
                    ),
                    _sidebarButton(
                      label: 'Pipeline',
                      filled: false,
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => const AtsDashboardScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF97A4C3),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarButton({
    required String label,
    required VoidCallback onTap,
    bool filled = true,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: filled
              ? const LinearGradient(
                  colors: [Color(0xFF6B4DFF), Color(0xFF4A32D8)],
                )
              : null,
          color: filled ? null : const Color(0xFF171E33),
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: const Color(0xFF2A3350)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);
    final rows = _activeRows();
    _primeVideoPreload(rows);
    final width = MediaQuery.of(context).size.width;
    final webMode = kIsWeb && width >= 1040;
    final noJobs = !_loadingJobs && _jobs.isEmpty;

    if (_loadingJobs || feedState.isInitialLoading || _loadingMatches) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF060B16), Color(0xFF0D1324), Color(0xFF060A14)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: CupertinoActivityIndicator(color: Colors.white, radius: 16),
        ),
      );
    }

    if (rows.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF060B16), Color(0xFF0D1324), Color(0xFF060A14)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _emptyState(noJobs: noJobs),
      );
    }

    final selectedJobLabel = _selectedJob()?['title']?.toString();

    if (webMode) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF060B16), Color(0xFF0D1324), Color(0xFF060A14)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          scrollDirection: Axis.vertical,
                          itemCount: rows.length,
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                          },
                          itemBuilder: (context, index) {
                            final user = NexUser.fromJson(rows[index]);
                            final match =
                                (rows[index]['match_percentage'] as num?)
                                    ?.round();
                            return CandidateTalentReelCard(
                              candidate: user,
                              isActive: _currentPage == index,
                              webMode: true,
                              selectedJobLabel: selectedJobLabel,
                              matchPercentage: match,
                              onSelectJob: _openJobSelector,
                            );
                          },
                        ),
                        Positioned(
                          left: 22,
                          bottom: 22,
                          child: MployaGlassPanel(
                            radius: 18,
                            blur: 18,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            color: const Color(
                              0xFF111827,
                            ).withValues(alpha: 0.58),
                            child: Text(
                              '${_currentPage + 1} de ${rows.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                _desktopSidebar(rows),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF060B16), Color(0xFF0D1324), Color(0xFF060A14)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: rows.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final user = NexUser.fromJson(rows[index]);
              final match = (rows[index]['match_percentage'] as num?)?.round();
              return CandidateTalentReelCard(
                candidate: user,
                isActive: _currentPage == index,
                webMode: false,
                selectedJobLabel: selectedJobLabel,
                matchPercentage: match,
                onSelectJob: _openJobSelector,
              );
            },
          ),
          _topOverlay(rows),
        ],
      ),
    );
  }
}
