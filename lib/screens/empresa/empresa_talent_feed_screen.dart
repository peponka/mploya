import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../navigation/main_navigation.dart';
import '../../providers/feed_provider.dart';
import '../../services/ai_match_service.dart';
import '../../services/video_preload_manager.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../../widgets/empresa/talent_reel_card.dart';
import 'empresa_pipeline_screen.dart';
import 'empresa_publicar_vacante_screen.dart';

/// Feed de Talento de Empresa — descubrimiento de CANDIDATOS por video pitch.
///
/// Derivado de `video pantalla completa candidato.png`. Video-first, una
/// persona por vez, swipe vertical.
///
/// La empresa acá es RECRUITER: el objeto del feed es el candidato. No existe
/// "Postularme" ni un CTA principal "Ver vacante".
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// Auditada el 12/8/2026: se eliminaron de la tarjeta los "N+ años" (que eran
/// `experience.length * 2`) y la modalidad inferida de tags. El porcentaje de
/// Match sale de la RPC `match_candidates_for_job` y sin match no se dibuja.
class EmpresaTalentFeedScreen extends ConsumerStatefulWidget {
  /// `true` cuando vive como pestaña del shell (índice 0). En ese caso la
  /// reproducción depende de la pestaña activa; si se abre como ruta, no.
  final bool embedded;

  const EmpresaTalentFeedScreen({super.key, this.embedded = false});

  @override
  ConsumerState<EmpresaTalentFeedScreen> createState() =>
      _EmpresaTalentFeedScreenState();
}

class _EmpresaTalentFeedScreenState
    extends ConsumerState<EmpresaTalentFeedScreen> {
  final PageController _pageController = PageController();

  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _jobMatches = [];
  String? _selectedJobId;
  bool _loadingJobs = true;
  bool _loadingMatches = false;
  int _currentPage = 0;

  /// 0 = Para ti · 1 = Explorar
  int _tab = 0;

  /// Silencio del feed. Vive acá y no en cada reel para que no se reinicie al
  /// pasar de candidato.
  bool _muted = false;

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

  // ── Vacantes y Match ──────────────────────────────────────────────────────

  Future<void> _loadJobs() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loadingJobs = false);
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('jobs')
          .select('id, title, location, salary_range, tags, is_active')
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

  /// El Match de Empresa es candidato ↔ vacante. Sin vacante no hay porcentaje.
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
    if (_pageController.hasClients) _pageController.jumpToPage(0);
    _primeVideoPreload(_activeRows());
  }

  Future<void> _openJobSelector() async {
    if (_jobs.isEmpty) {
      await Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const EmpresaPublicarVacanteScreen()),
      );
      await _loadJobs();
      return;
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Seleccionar vacante'),
        message: const Text(
          'El Match IA se calcula siempre contra una vacante concreta.',
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

  String? _selectedJobTitle() => _selectedJob()?['title']?.toString();

  /// Línea de contexto de la vacante ("Remoto · Buenos Aires"), con los campos
  /// que realmente existen en `jobs`. Sin datos no se muestra nada.
  String? _selectedJobMeta() {
    final job = _selectedJob();
    if (job == null) return null;
    final parts = <String>[];
    final location = job['location']?.toString();
    final salary = job['salary_range']?.toString();
    if (location != null && location.isNotEmpty) parts.add(location);
    if (salary != null && salary.isNotEmpty) parts.add(salary);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  // ── Filas del feed ────────────────────────────────────────────────────────

  /// Sólo candidatos con video: el feed es video-first, una fila sin pitch no
  /// tiene nada que mostrar.
  List<Map<String, dynamic>> _candidatesWithVideo() {
    return ref
        .read(feedProvider)
        .items
        .where((row) {
          final type = row['account_type']?.toString().toLowerCase() ?? '';
          final video = row['video_url']?.toString() ?? '';
          final isCandidate = type == 'candidato' ||
              type.startsWith('confidenc') ||
              type == 'stealth';
          return isCandidate && video.isNotEmpty;
        })
        .toList();
  }

  List<Map<String, dynamic>> _activeRows() {
    if (_tab == 0 && _selectedJobId != null && _jobMatches.isNotEmpty) {
      return _jobMatches;
    }
    return _candidatesWithVideo();
  }

  void _primeVideoPreload(List<Map<String, dynamic>> rows) {
    VideoPreloadManager.instance.updateFeedUrls(
      rows
          .map((row) => row['video_url']?.toString() ?? '')
          .where((url) => url.isNotEmpty)
          .toList(),
    );
  }

  int? _matchFor(List<Map<String, dynamic>> rows, int index) {
    if (_selectedJobId == null || rows.isEmpty) return null;
    if (index < 0 || index >= rows.length) return null;
    return (rows[index]['match_percentage'] as num?)?.round();
  }

  Future<void> _openMenu() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Feed de talento'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openJobSelector();
            },
            child: Text(
              _selectedJobId == null
                  ? 'Elegir vacante para el Match'
                  : 'Cambiar vacante del Match',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              // Pipeline de Empresa, no el Kanban legacy: desde aquel se
              // llegaba al ATS viejo, que tiene datos demo.
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const EmpresaPipelineScreen(),
                ),
              );
            },
            child: const Text('Abrir pipeline'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              ref.read(feedProvider.notifier).refreshFeed();
            },
            child: const Text('Actualizar feed'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Se observa el feed para reconstruir cuando llegan filas nuevas.
    ref.watch(feedProvider);
    final rows = _activeRows();
    final wide = mpIsWide(context);

    final feed = MpSurface(
      style: MpSurfaceStyle.dark,
      child: ColoredBox(
        color: MpTokens.darkBg,
        child: Stack(
          children: [
            if (_loadingJobs || _loadingMatches)
              const Center(
                child: CupertinoActivityIndicator(
                  radius: 15,
                  color: Color(0xFFFFFFFF),
                ),
              )
            else if (rows.isEmpty)
              _empty()
            else
              _pager(rows),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(bottom: false, child: _topBar()),
            ),
          ],
        ),
      ),
    );

    if (!wide) return feed;

    // En escritorio el video no se estira a todo el ancho: se centra en una
    // columna vertical, que es la proporción en la que está grabado el pitch.
    return ColoredBox(
      color: MpTokens.darkBg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: feed,
        ),
      ),
    );
  }

  Widget _pager(List<Map<String, dynamic>> rows) {
    final visible = widget.embedded
        ? currentMainTabNotifier.value == 0
        : true;

    return PageView.builder(
      controller: _pageController,
      // Swipe arriba = siguiente candidato, swipe abajo = anterior.
      scrollDirection: Axis.vertical,
      itemCount: rows.length,
      onPageChanged: (index) {
        setState(() => _currentPage = index);
        // Se precargan los próximos para que el siguiente arranque sin espera.
        _primeVideoPreload(rows.skip(index).take(4).toList());
      },
      itemBuilder: (context, index) {
        return TalentReelCard(
          key: ValueKey(rows[index]['id'] ?? index),
          candidate: NexUser.fromJson(rows[index]),
          isActive: index == _currentPage,
          screenVisible: visible,
          muted: _muted,
          selectedJobTitle: _selectedJobTitle(),
          selectedJobMeta: _selectedJobMeta(),
          matchPercentage: _matchFor(rows, index),
          onSelectJob: _openJobSelector,
        );
      },
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MpTokens.space12,
        vertical: MpTokens.space8,
      ),
      child: Row(
        children: [
          _squareButton(
            CupertinoIcons.arrow_left,
            () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _tabLabel('Para ti', 0),
                const SizedBox(width: MpTokens.space24),
                _tabLabel('Explorar', 1),
              ],
            ),
          ),
          // El PNG no dibuja control de sonido, pero un feed de video lo
          // necesita: se agrega junto al menú, con el mismo estilo del mockup.
          _squareButton(
            _muted ? CupertinoIcons.volume_off : CupertinoIcons.volume_up,
            () => setState(() => _muted = !_muted),
          ),
          const SizedBox(width: MpTokens.space8),
          _squareButton(CupertinoIcons.ellipsis, _openMenu),
        ],
      ),
    );
  }

  Widget _tabLabel(String label, int index) {
    final active = _tab == index;

    return GestureDetector(
      onTap: () {
        if (_tab == index) return;
        setState(() {
          _tab = index;
          _currentPage = 0;
        });
        if (_pageController.hasClients) _pageController.jumpToPage(0);
        _primeVideoPreload(_activeRows().take(4).toList());
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: MpTokens.bodyStrong.copyWith(
              color: active ? const Color(0xFFFFFFFF) : const Color(0x99FFFFFF),
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            height: 2.5,
            width: 26,
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFFFFFFFF)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(MpTokens.radiusPill),
            ),
          ),
        ],
      ),
    );
  }

  /// Botón de la barra superior: cuadrado redondeado oscuro, como en el PNG
  /// (no un círculo).
  Widget _squareButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xB31A1A22),
          borderRadius: BorderRadius.circular(MpTokens.radiusMD),
        ),
        child: Icon(icon, size: 21, color: const Color(0xFFFFFFFF)),
      ),
    );
  }

  Widget _empty() {
    return MpEmptyState(
      icon: CupertinoIcons.videocam,
      title: _selectedJobId != null
          ? 'Sin candidatos para esta vacante'
          : 'Todavía no hay talento con video pitch',
      message: _selectedJobId != null
          ? 'Todavía no hay candidatos con video que coincidan con la vacante elegida.'
          : 'Cuando los candidatos suban su video pitch los vas a descubrir acá.',
      actionLabel: _jobs.isEmpty ? 'Publicar vacante' : 'Elegir otra vacante',
      onAction: _jobs.isEmpty
          ? () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const EmpresaPublicarVacanteScreen()),
              )
          : _openJobSelector,
    );
  }
}
