import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../providers/feed_provider.dart';
import '../providers/user_provider.dart';
import '../services/coach_mark_service.dart';
import '../services/feed_service.dart';
import '../services/notification_service.dart';
import '../services/video_preload_manager.dart';
import '../theme/mploya_tokens.dart';
import '../utils/headhunter_candidate_privacy.dart';
import '../widgets/candidato/cand_inicio.dart';
import '../widgets/candidato/cand_red.dart' show CandPersonaVista;
import '../widgets/candidato/cand_ui.dart';
import '../widgets/candidato/cand_vacantes.dart' show CandVacanteVista;
import '../widgets/feature_hint.dart';
import '../widgets/mploya_toast.dart';
import '../widgets/onboarding_tour.dart';
import '../widgets/premium_feed_reel_card.dart';
import 'jobs_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

/// Datos ya resueltos para el render aislado. Mismo patrón que
/// `JobsPreviewData`: si llega, la pantalla NO consulta Supabase ni abre video.
@immutable
class HomeFeedPreviewData {
  const HomeFeedPreviewData({
    this.feed = const [],
    this.vacantes = const [],
    this.usuario,
  });

  /// Filas del feed con la forma que devuelve `FeedService`.
  final List<Map<String, dynamic>> feed;

  /// Filas de `jobs` para la columna lateral.
  final List<Map<String, dynamic>> vacantes;

  /// Fila de `users` del propio candidato.
  final Map<String, dynamic>? usuario;
}

class HomeFeedScreen extends ConsumerStatefulWidget {
  /// Sólo lo usan los tests y el generador de capturas. En producción es
  /// `null` y el camino de datos es el real.
  final HomeFeedPreviewData? previewData;

  const HomeFeedScreen({super.key, this.previewData});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  final PageController _pageController = PageController();
  final Set<String> _likedUserIds = {};
  StreamSubscription<List<Map<String, dynamic>>>? _likesSub;

  bool _isRefreshing = false;
  double _overscrollTotal = 0;
  int _currentPage = 0;
  String _selectedCategory = 'todos';

  static const Map<String, String> _categoryLabels = {
    'todos': 'Para vos',
    'tecnologia': 'Tecnologia',
    'finanzas': 'Finanzas',
    'marketing': 'Marketing',
    'ventas': 'Ventas',
    'administracion': 'Admin',
    'diseno': 'Diseno',
  };

  static const Map<String, List<String>> _categoryKeywords = {
    'tecnologia': [
      'flutter',
      'react',
      'developer',
      'software',
      'engineer',
      'backend',
      'frontend',
      'fullstack',
      'devops',
      'data',
      'python',
      'java',
      'node',
      'sql',
      'aws',
      'cloud',
      'tech',
      'it',
    ],
    'finanzas': ['finanzas', 'contab', 'cfo', 'contador', 'financial'],
    'marketing': [
      'marketing',
      'growth',
      'seo',
      'ads',
      'contenido',
      'social media',
      'comunicaci',
    ],
    'ventas': ['ventas', 'sales', 'comercial', 'account manager'],
    'administracion': [
      'administra',
      'operaciones',
      'rrhh',
      'recursos humanos',
      'hr',
      'people',
    ],
    'diseno': ['disen', 'design', 'ux', 'ui', 'product designer', 'creativ'],
  };

  /// Vacantes de la columna lateral. Son filas reales de `jobs`; si la consulta
  /// falla o no trae nada, el bloque no se dibuja.
  List<Map<String, dynamic>> _vacantesPanel = const [];

  @override
  void initState() {
    super.initState();
    final preview = widget.previewData;
    if (preview != null) {
      // Render aislado: datos ya resueltos, sin tour, sin streams y sin video.
      _vacantesPanel = preview.vacantes;
      return;
    }
    _cargarVacantesPanel();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      VideoPreloadManager.instance.pauseAll();
      final shown = await OnboardingTourOverlay.showIfNeeded(context);
      if (shown && mounted) {
        VideoPreloadManager.instance.resumeCurrent();
      } else if (!shown) {
        VideoPreloadManager.instance.resumeCurrent();
      }
      ref.read(feedProvider.notifier).loadInitial();
      if (mounted) CoachMarkService.showFeedTour(context);
    });

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      try {
        _likesSub = Supabase.instance.client
            .from('pitch_likes')
            .stream(primaryKey: ['liker_id', 'pitch_owner_id'])
            .eq('liker_id', uid)
            .listen((rows) {
              if (!mounted) return;
              setState(() {
                _likedUserIds
                  ..clear()
                  ..addAll(rows.map((r) => r['pitch_owner_id'].toString()));
              });
            }, onError: (e) => debugPrint('pitch_likes stream error: $e'));
      } catch (e) {
        debugPrint('pitch_likes stream init failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _likesSub?.cancel();
    VideoPreloadManager.instance.pauseAll();
    super.dispose();
  }

  /// Últimas vacantes publicadas, para la columna lateral de tablet y desktop.
  Future<void> _cargarVacantesPanel() async {
    try {
      final res = await Supabase.instance.client
          .from('jobs')
          .select('*, users!jobs_company_id_fkey(name, avatar_url)')
          .order('created_at', ascending: false)
          .limit(3);
      if (!mounted) return;
      setState(() => _vacantesPanel = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint('feed · vacantes del panel: $e');
    }
  }

  String _haystackFor(Map<String, dynamic> row) => [
    (row['headline'] ?? '').toString(),
    (row['about'] ?? '').toString(),
    ...((row['tags'] as List?) ?? const []).map((e) => e.toString()),
    ...((row['skills'] as List?) ?? const []).map((e) => e.toString()),
  ].join(' ').toLowerCase();

  bool _keywordMatch(String haystack, String keyword) {
    if (keyword.length > 3) return haystack.contains(keyword);
    final re = RegExp('(^|[^a-z])${RegExp.escape(keyword)}([^a-z]|\$)');
    return re.hasMatch(haystack);
  }

  List<Map<String, dynamic>> _filterByCategory(
    List<Map<String, dynamic>> items,
  ) {
    if (_selectedCategory == 'todos') return items;
    final keywords = _categoryKeywords[_selectedCategory] ?? const [];
    return items.where((row) {
      final haystack = _haystackFor(row);
      return keywords.any((k) => _keywordMatch(haystack, k));
    }).toList();
  }

  Set<String> _categoriesWithData(List<Map<String, dynamic>> items) {
    final present = <String>{};
    for (final entry in _categoryKeywords.entries) {
      final hasMatch = items.any((row) {
        final haystack = _haystackFor(row);
        return entry.value.any((k) => _keywordMatch(haystack, k));
      });
      if (hasMatch) present.add(entry.key);
    }
    return present;
  }

  Iterable<MapEntry<String, String>> _visibleCategoryEntries(
    List<Map<String, dynamic>> items,
  ) {
    final present = _categoriesWithData(items);
    return _categoryLabels.entries.where(
      (entry) => entry.key == 'todos' || present.contains(entry.key),
    );
  }

  Post _userToPost(Map<String, dynamic> row) {
    return FeedService.instance.userRowToPost(row, likedUserIds: _likedUserIds);
  }

  String? get _viewerAccountType {
    final previewType = widget.previewData?.usuario?['account_type']
        ?.toString();
    if (previewType != null) return previewType;
    return ref.read(currentUserProvider).valueOrNull?.accountType;
  }

  List<Map<String, dynamic>> _protectFeedRows(List<Map<String, dynamic>> rows) {
    final viewerType = _viewerAccountType;
    if (viewerType?.toLowerCase() != 'headhunter') return rows;
    return rows
        .map((row) => protectCandidateRowForHeadhunter(row, viewerType))
        .toList(growable: false);
  }

  void _openJobs() {
    HapticFeedback.selectionClick();
    Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => const JobsScreen()));
  }

  void _openNotifications() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.previewData;
    if (preview == null) {
    ref.listen(feedProvider, (prev, next) {
      if (prev?.items != next.items) {
          final urls = _protectFeedRows(next.items)
            .map((row) => row['video_url']?.toString() ?? '')
            .where((url) => url.isNotEmpty)
            .toList();
        VideoPreloadManager.instance.updateFeedUrls(urls);
      }
    });
    }

    final feedState = preview != null
        ? FeedState(items: preview.feed, hasMore: false)
        : ref.watch(feedProvider);
    final items = _protectFeedRows(feedState.items);
    final safeFeedState = preview != null
        ? FeedState(items: items, hasMore: false)
        : feedState;
    final rows = _filterByCategory(items);

    // Los tres formatos de la tanda. El reel domina en mobile; en tablet y
    // desktop se acota y aparece la columna de contexto.
    final formato = candFormatoDe(context);
    final ancho = formato != CandFormato.mobile;
    final bottomInset = ancho ? 0.0 : MediaQuery.paddingOf(context).bottom + 94;

    return CupertinoPageScaffold(
      backgroundColor: ancho ? MpTokens.lightBg : const Color(0xFF07111F),
      child: ancho
          ? SafeArea(
              bottom: false,
              child: _buildBody(
                context: context,
                feedState: safeFeedState,
                rows: rows,
                allItems: items,
                webMode: true,
                bottomInset: 0,
                formato: formato,
              ),
            )
          : DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF09111E),
                    Color(0xFF111B2D),
                    Color(0xFF050814),
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: _buildBody(
                  context: context,
                  feedState: safeFeedState,
                  rows: rows,
                  allItems: items,
                  webMode: false,
                  bottomInset: bottomInset,
                  formato: formato,
                ),
              ),
            ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required FeedState feedState,
    required List<Map<String, dynamic>> rows,
    required List<Map<String, dynamic>> allItems,
    required bool webMode,
    required double bottomInset,
    required CandFormato formato,
  }) {
    if (feedState.isInitialLoading) {
      return _FeedLoadingState(webMode: webMode);
    }

    if (feedState.error != null && allItems.isEmpty) {
      return _FeedEmptyState(
        title: 'No pudimos abrir el feed',
        body: feedState.error!,
        primaryLabel: 'Reintentar',
        onPrimaryTap: () => ref.read(feedProvider.notifier).refreshFeed(),
      );
    }

    if (allItems.isEmpty) {
      return _FeedEmptyState(
        title: 'Todavia no hay contenido visible en tu feed',
        body:
            'Cuando haya mas perfiles y empresas con video pitch, el swipe vertical aparecera aca.',
        primaryLabel: 'Actualizar feed',
        onPrimaryTap: () => ref.read(feedProvider.notifier).refreshFeed(),
      );
    }

    if (rows.isEmpty) {
      return _FeedEmptyState(
        title: 'Sin resultados en ${_categoryLabels[_selectedCategory]}',
        body: 'Proba otra categoria o volve a Para vos para ver todo el feed.',
        primaryLabel: 'Ver todo',
        onPrimaryTap: () => setState(() => _selectedCategory = 'todos'),
      );
    }

    return webMode
        ? _buildAnchoFeed(context, feedState, rows, formato)
        : _buildMobileFeed(context, feedState, rows, bottomInset);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TABLET Y DESKTOP — composición aprobada de la Tanda 1
  //
  // Referencia: design-reference/Candidato_Tanda1_Final/{tablet,desktop}/
  //             01_inicio.png
  //
  // El reel deja de estirarse a todo el ancho y se acota en proporción
  // vertical, con la columna de contexto al costado. La barra lateral de
  // navegación la pone el shell, así que acá no se repite.
  // ───────────────────────────────────────────────────────────────────────────

  /// Perfil propio para la tarjeta de la columna lateral.
  NexUser? get _miPerfil {
    final preview = widget.previewData;
    if (preview != null) {
      final fila = preview.usuario;
      return fila == null ? null : NexUser.fromJson(Map.of(fila));
    }
    // `valueOrNull` y no `value`: con la sesión en error, `value` relanza.
    return ref.watch(currentUserProvider).valueOrNull;
  }

  /// Vacantes reales de la columna lateral.
  List<CandVacanteVista> get _vacantesVista => _vacantesPanel.map((job) {
        final empresa = ((job['users'] as Map?)?['name']?.toString() ??
                job['company']?.toString() ??
                '')
            .trim();
        return CandVacanteVista(
          id: job['id']?.toString() ?? '',
          puesto: job['title']?.toString().trim() ?? 'Vacante',
          empresa: empresa.isEmpty ? 'Empresa' : empresa,
          logoEmpresa: (job['users'] as Map?)?['avatar_url']?.toString(),
          modalidad: switch (job['modality']?.toString()) {
            'remote' => 'Remoto',
            'hybrid' => 'Híbrido',
            'onsite' => 'Presencial',
            _ => '',
          },
        );
      }).toList();

  /// Gente del propio feed: son perfiles reales, los mismos que el reel muestra
  /// más adelante. No se inventa ninguno.
  List<CandPersonaVista> _personasVista(
    List<Map<String, dynamic>> rows,
    int activeIndex,
    int cantidad,
  ) {
    final otras = <CandPersonaVista>[];
    for (var i = 0; i < rows.length && otras.length < cantidad; i++) {
      if (i == activeIndex) continue;
      final autor = _userToPost(rows[i]).author;
      if (autor.isCompanyAct) continue;
      otras.add(
        CandPersonaVista(
          id: autor.id,
          nombre: autor.name,
          titulo: autor.headline,
          ciudad: (autor.location ?? '').trim(),
          avatarUrl: autor.avatarUrl,
          verificado: autor.isVerified,
        ),
      );
    }
    return otras;
  }

  Widget _buildAnchoFeed(
    BuildContext context,
    FeedState feedState,
    List<Map<String, dynamic>> rows,
    CandFormato formato,
  ) {
    final esDesktop = formato == CandFormato.desktop;
    final itemCount = rows.length + (feedState.isLoading ? 1 : 0);
    final visibleEntries = _visibleCategoryEntries(feedState.items).toList();
    final activeIndex = _currentPage.clamp(0, rows.length - 1);
    final perfil = _miPerfil;

    final panel = CandPanelInicio(
      nombre: perfil?.name ?? '',
      avatarUrl: perfil?.avatarUrl,
      detallePerfil: perfil == null
          ? ''
          : [
              perfil.headline.trim(),
              (perfil.location ?? '').trim(),
            ].where((p) => p.isNotEmpty).join(' · '),
      vacantes: _vacantesVista,
      personas: _personasVista(rows, activeIndex, esDesktop ? 3 : 2),
      // En desktop el tip vive al pie de la barra lateral del shell: repetirlo
      // acá lo duplicaba en la misma pantalla.
      tip: esDesktop
          ? null
          : 'Completá tu video pitch: los perfiles con video reciben más '
              'visitas de empresas.',
      onPerfil: () => Navigator.of(
        context,
      ).push(CupertinoPageRoute<void>(builder: (_) => const ProfileScreen())),
      onVerVacantes: _openJobs,
      onVacante: (_) => _openJobs(),
      onPersona: (p) => Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => ProfileScreen(
            user: _autorPorId(rows, p.id),
            viewerAccountType: _viewerAccountType,
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        esDesktop ? 28 : 20,
        esDesktop ? 26 : 20,
        esDesktop ? 28 : 20,
        esDesktop ? 26 : 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _barraSuperior(claro: true, cantidad: rows.length),
                const SizedBox(height: 14),
                if (visibleEntries.length > 1) ...[
                  CandFilaChips(
                    padding: 0,
                    children: [
                      for (final entry in visibleEntries)
                        CandChip(
                          entry.value,
                          activo: _selectedCategory == entry.key,
                          onTap: () =>
                              setState(() => _selectedCategory = entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: esDesktop ? 470 : 520,
                      ),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: PageView.builder(
                          controller: _pageController,
                          scrollDirection: Axis.vertical,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                            VideoPreloadManager.instance.onPageChanged(index);
                            if (feedState.hasMore &&
                                !feedState.isLoading &&
                                index >= rows.length - 2) {
                              ref.read(feedProvider.notifier).loadMore();
                            }
                          },
                          itemCount: itemCount,
                          itemBuilder: (context, index) {
                            if (index >= rows.length) {
                              return const Center(
                                child: CupertinoActivityIndicator(
                                  radius: 14,
                                  color: MpTokens.primary,
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: PremiumFeedReelCard(
                                post: _userToPost(rows[index]),
                                webMode: true,
                                isFirstCard: index == 0,
                                esPreview: widget.previewData != null,
                                viewerAccountType: _viewerAccountType,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      child: _DesktopArrow(
                        icon: CupertinoIcons.chevron_up,
                        onTap: activeIndex > 0
                            ? () => _pageController.previousPage(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${activeIndex + 1} de ${rows.length}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: MpTokens.lightTextTertiary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: _DesktopArrow(
                        icon: CupertinoIcons.chevron_down,
                        onTap: activeIndex < rows.length - 1
                            ? () => _pageController.nextPage(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                )
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: esDesktop ? 24 : 16),
          if (esDesktop)
            SizedBox(width: 360, child: panel)
          else
            Expanded(flex: 2, child: panel),
        ],
      ),
    );
  }

  /// Devuelve el autor real de una fila del feed por id, para abrir su perfil.
  NexUser? _autorPorId(List<Map<String, dynamic>> rows, String id) {
    for (final row in rows) {
      final autor = _userToPost(row).author;
      if (autor.id == id) return autor;
    }
    return null;
  }

  /// Barra superior de la pantalla: logotipo, acceso a Vacantes y campana.
  ///
  /// `claro` la pinta para la superficie clara de tablet y desktop; en mobile
  /// va sobre el video, que es oscuro por diseño.
  Widget _barraSuperior({required bool claro, required int cantidad}) {
    return Row(
      children: [
        CandLogotipo(claro: !claro),
        const SizedBox(width: 14),
        if (cantidad > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: claro
                  ? MpTokens.lightFill
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$cantidad ${cantidad == 1 ? 'oportunidad' : 'oportunidades'}',
              style: TextStyle(
                color: claro ? MpTokens.lightTextSecondary : Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const Spacer(),
        _TopCircleButton(
          key: cmFeedJobsBtnKey,
          icon: CupertinoIcons.briefcase,
          onTap: _openJobs,
          claro: claro,
        ),
        const SizedBox(width: 10),
        _campana(claro: claro),
      ],
    );
  }

  /// Campana con el contador real de notificaciones sin leer.
  Widget _campana({required bool claro}) {
    if (widget.previewData != null) {
      return _TopCircleButton(
        key: cmFeedBellBtnKey,
        icon: CupertinoIcons.bell,
        onTap: _openNotifications,
        claro: claro,
      );
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: NotificationService.instance.notificationsStream,
      builder: (context, snap) {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        final unread = (snap.data ?? [])
            .where(
              (n) => n['user_id']?.toString() == uid && n['is_read'] != true,
            )
            .length;
        return _TopCircleButton(
          key: cmFeedBellBtnKey,
          icon: CupertinoIcons.bell,
          badgeCount: unread,
          onTap: _openNotifications,
          claro: claro,
        );
      },
    );
  }

  Widget _buildMobileFeed(
    BuildContext context,
    FeedState feedState,
    List<Map<String, dynamic>> rows,
    double bottomInset,
  ) {
    final itemCount = rows.length + (feedState.isLoading ? 1 : 0);
    final visibleEntries = _visibleCategoryEntries(feedState.items).toList();

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(top: 128, bottom: bottomInset),
            child: NotificationListener<OverscrollNotification>(
              onNotification: (notification) {
                if (_pageController.page != null &&
                    _pageController.page! <= 0.0 &&
                    notification.overscroll < 0 &&
                    !_isRefreshing) {
                  _overscrollTotal += notification.overscroll.abs();
                  if (_overscrollTotal > 80) {
                    _overscrollTotal = 0;
                    HapticFeedback.mediumImpact();
                    setState(() => _isRefreshing = true);
                    ref.read(feedProvider.notifier).refreshFeed().then((_) {
                      if (mounted) {
                        setState(() => _isRefreshing = false);
                        MployaToast.success(context, 'Feed actualizado');
                      }
                    });
                  }
                } else if (notification.overscroll >= 0) {
                  _overscrollTotal = 0;
                }
                return false;
              },
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  onPageChanged: (index) {
                    _overscrollTotal = 0;
                    setState(() => _currentPage = index);
                    VideoPreloadManager.instance.onPageChanged(index);
                    if (feedState.hasMore &&
                        !feedState.isLoading &&
                        index >= rows.length - 3) {
                      ref.read(feedProvider.notifier).loadMore();
                    }
                  },
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (index >= rows.length) {
                      return const Center(
                        child: CupertinoActivityIndicator(
                          radius: 14,
                          color: MpTokens.primary,
                        ),
                      );
                    }
                    // Sin margen ni padding: el reel es la superficie
                    // principal de la pantalla, no una tarjeta flotando
                    // dentro de otra — así lo muestra la composición
                    // aprobada.
                    final card = PremiumFeedReelCard(
                      post: _userToPost(rows[index]),
                      webMode: false,
                      isFirstCard: index == 0,
                      esPreview: widget.previewData != null,
                      viewerAccountType: _viewerAccountType,
                    );
                    // El hint de onboarding lee preferencias del dispositivo;
                    // en render aislado no hay plugin, así que no se monta.
                    if (index == 0 && widget.previewData == null) {
                      return FeatureHints.doubleTapInterest(child: card);
                    }
                    return card;
                  },
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF07111F),
                  const Color(0xFF07111F).withValues(alpha: 0.92),
                  const Color(0xFF07111F).withValues(alpha: 0),
                ],
              ),
            ),
            child: Column(
              children: [
                _barraSuperior(claro: false, cantidad: 0),
                const SizedBox(height: 14),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: visibleEntries.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final entry = visibleEntries[index];
                      final selected = _selectedCategory == entry.key;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = entry.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? MpTokens.primary
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected
                                  ? MpTokens.primaryLight
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isRefreshing)
          const Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: CupertinoActivityIndicator(
                radius: 12,
                color: MpTokens.primary,
              ),
            ),
          ),
      ],
    );
  }

}

class _TopCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  /// `true` sobre la superficie clara de tablet y desktop; `false` sobre el
  /// video de mobile, que es oscuro por diseño.
  final bool claro;

  const _TopCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
    this.claro = false,
  });

  @override
  Widget build(BuildContext context) {
    final frente = claro ? MpTokens.lightText : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: claro
                  ? MpTokens.lightFill
                  : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: claro
                    ? MpTokens.lightBorder
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(icon, color: frente, size: 20),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: MpTokens.danger,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DesktopArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _DesktopArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Las flechas viven sobre la superficie clara de tablet y desktop, no sobre
    // el video: con los blancos translúcidos de antes quedaban invisibles.
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: MpTokens.lightFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MpTokens.lightBorderStrong),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: enabled ? MpTokens.lightText : MpTokens.lightTextTertiary,
          size: 20,
        ),
      ),
    );
  }
}

class _FeedLoadingState extends StatelessWidget {
  final bool webMode;

  const _FeedLoadingState({required this.webMode});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: webMode ? 420 : 260,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(radius: 14, color: MpTokens.primary),
            SizedBox(height: 18),
            Text(
              'Preparando el feed en video...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Cargando videos, match y contexto para el siguiente swipe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFB7C2D4),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedEmptyState extends StatelessWidget {
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimaryTap;

  const _FeedEmptyState({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.play_rectangle_fill,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB7C2D4),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            CupertinoButton(
              color: MpTokens.primary,
              borderRadius: BorderRadius.circular(18),
              onPressed: onPrimaryTap,
              child: Text(
                primaryLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
