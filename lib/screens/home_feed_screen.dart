import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../providers/feed_provider.dart';
import '../services/coach_mark_service.dart';
import '../services/feed_service.dart';
import '../services/notification_service.dart';
import '../services/video_preload_manager.dart';
import '../widgets/feature_hint.dart';
import '../widgets/mploya_toast.dart';
import '../widgets/onboarding_tour.dart';
import '../widgets/premium_feed_reel_card.dart';
import 'jobs_screen.dart';
import 'notifications_screen.dart';

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

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

  @override
  void initState() {
    super.initState();
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

  String _haystackFor(Map<String, dynamic> row) => [
    (row['headline'] ?? '').toString(),
    (row['about'] ?? '').toString(),
    ...((row['tags'] as List?) ?? const []).map((e) => e.toString()),
    ...((row['skills'] as List?) ?? const []).map((e) => e.toString()),
  ].join(' ').toLowerCase();

  bool _keywordMatch(String haystack, String keyword) {
    if (keyword.length > 3) return haystack.contains(keyword);
    final re = RegExp(
      '(^|[^a-z])${RegExp.escape(keyword)}([^a-z]|\$)',
    );
    return re.hasMatch(haystack);
  }

  List<Map<String, dynamic>> _filterByCategory(List<Map<String, dynamic>> items) {
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
    ref.listen(feedProvider, (prev, next) {
      if (prev?.items != next.items) {
        final urls = next.items
            .map((row) => row['video_url']?.toString() ?? '')
            .where((url) => url.isNotEmpty)
            .toList();
        VideoPreloadManager.instance.updateFeedUrls(urls);
      }
    });

    final feedState = ref.watch(feedProvider);
    final items = feedState.items;
    final rows = _filterByCategory(items);

    return LayoutBuilder(
      builder: (context, constraints) {
        final webMode = kIsWeb && constraints.maxWidth >= 980;
        final bottomInset = webMode
            ? 0.0
            : MediaQuery.paddingOf(context).bottom + 94;

        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFF07111F),
          child: DecoratedBox(
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
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  webMode ? 24 : 0,
                  webMode ? 18 : 0,
                  webMode ? 24 : 0,
                  0,
                ),
                child: _buildBody(
                  context: context,
                  feedState: feedState,
                  rows: rows,
                  allItems: items,
                  webMode: webMode,
                  bottomInset: bottomInset,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required FeedState feedState,
    required List<Map<String, dynamic>> rows,
    required List<Map<String, dynamic>> allItems,
    required bool webMode,
    required double bottomInset,
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
        ? _buildDesktopFeed(context, feedState, rows)
        : _buildMobileFeed(context, feedState, rows, bottomInset);
  }

  Widget _buildDesktopFeed(
    BuildContext context,
    FeedState feedState,
    List<Map<String, dynamic>> rows,
  ) {
    final itemCount = rows.length + (feedState.isLoading ? 1 : 0);
    final visibleEntries = _visibleCategoryEntries(feedState.items).toList();
    final activeIndex = _currentPage.clamp(0, rows.length - 1);
    final activeAuthor = _userToPost(rows[activeIndex]).author;
    final activeTags = activeAuthor.tags.take(4).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 272,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'mploya',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFF6A1A),
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Feed principal',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Una oportunidad activa por vez, video vertical al centro y contexto real alrededor.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xB3FFFFFF),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: visibleEntries
                    .map(
                      (entry) => GestureDetector(
                        onTap: () => setState(() => _selectedCategory = entry.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedCategory == entry.key
                                ? const Color(0xFFFF6A1A)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _selectedCategory == entry.key
                                  ? const Color(0xFFFF8E4D)
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
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Modo descubrimiento',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB7C2D4),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _DesktopSignalRow(
                      icon: CupertinoIcons.play_circle_fill,
                      label: 'Video activo',
                      value: '${activeIndex + 1}/${rows.length}',
                    ),
                    const SizedBox(height: 10),
                    _DesktopSignalRow(
                      icon: CupertinoIcons.sparkles,
                      label: 'Match IA',
                      value: '${activeAuthor.matchPercentage.round()}%',
                    ),
                    const SizedBox(height: 10),
                    _DesktopSignalRow(
                      icon: CupertinoIcons.location_solid,
                      label: 'Ubicacion',
                      value: activeAuthor.location?.isNotEmpty == true
                          ? activeAuthor.location!
                          : 'Flexible',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
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
                  Expanded(
                    child: _DesktopArrow(
                      icon: CupertinoIcons.chevron_down,
                      onTap: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Para vos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${rows.length} oportunidades',
                              style: const TextStyle(
                                color: Color(0xFFD9E2F2),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          _TopCircleButton(
                            key: cmFeedJobsBtnKey,
                            icon: CupertinoIcons.search,
                            onTap: _openJobs,
                          ),
                          const SizedBox(width: 10),
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream:
                                NotificationService.instance.notificationsStream,
                            builder: (context, snap) {
                              final uid =
                                  Supabase.instance.client.auth.currentUser?.id;
                              final unread = (snap.data ?? [])
                                  .where(
                                    (n) =>
                                        n['user_id']?.toString() == uid &&
                                        n['is_read'] != true,
                                  )
                                  .length;
                              return _TopCircleButton(
                                key: cmFeedBellBtnKey,
                                icon: CupertinoIcons.bell,
                                badgeCount: unread,
                                onTap: _openNotifications,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: NotificationListener<OverscrollNotification>(
                          onNotification: (_) => false,
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
                                      color: Color(0xFFFF6A1A),
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: PremiumFeedReelCard(
                                    post: _userToPost(rows[index]),
                                    webMode: true,
                                    isFirstCard: index == 0,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 22),
              Container(
                width: 344,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 30,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Contexto rapido',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F7FB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${activeIndex + 1} de ${rows.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      activeAuthor.isCompanyAct
                          ? activeAuthor.name
                          : activeAuthor.headline,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activeAuthor.isCompanyAct
                          ? activeAuthor.headline
                          : activeAuthor.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF101A30), Color(0xFF1E293B)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${activeAuthor.matchPercentage.round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Match IA',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFCED7E8),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Desktop suma contexto lateral sin romper la logica TikTok de una oportunidad principal activa.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if ((activeAuthor.location ?? '').isNotEmpty)
                          _DesktopInfoPill(
                            icon: CupertinoIcons.location_solid,
                            label: activeAuthor.location!,
                          ),
                        if ((activeAuthor.salaryExpectation ?? '').isNotEmpty)
                          _DesktopInfoPill(
                            icon: CupertinoIcons.money_dollar_circle,
                            label: activeAuthor.salaryExpectation!,
                          ),
                        _DesktopInfoPill(
                          icon: CupertinoIcons.sparkles,
                          label: activeAuthor.isCompanyAct
                              ? 'Vacante en video'
                              : 'Talento en video',
                        ),
                      ],
                    ),
                    if (activeAuthor.about?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'Resumen',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        activeAuthor.about!.trim(),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                    if (activeTags.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'Skills y senales',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: activeTags
                            .map((tag) => _DesktopTag(label: tag))
                            .toList(),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        children: [
                          _DesktopSignalRow(
                            icon: CupertinoIcons.location,
                            label: 'Distancia',
                            value: _distanceLabel(activeAuthor),
                            dark: false,
                          ),
                          const SizedBox(height: 10),
                          _DesktopSignalRow(
                            icon: CupertinoIcons.clock,
                            label: 'Tiempo estimado',
                            value: '${12 + (activeIndex % 4) * 6} min',
                            dark: false,
                          ),
                          const SizedBox(height: 10),
                          _DesktopSignalRow(
                            icon: CupertinoIcons.eye,
                            label: 'Listo para decidir',
                            value: 'Guardar, compartir o abrir detalle',
                            dark: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
                          color: Color(0xFFFF6A1A),
                        ),
                      );
                    }
                    final card = Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: PremiumFeedReelCard(
                        post: _userToPost(rows[index]),
                        webMode: false,
                        isFirstCard: index == 0,
                      ),
                    );
                    if (index == 0) {
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
                Row(
                  children: [
                    const Text(
                      'mploya',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF6A1A),
                        letterSpacing: -1.3,
                      ),
                    ),
                    const Spacer(),
                    _TopCircleButton(
                      key: cmFeedJobsBtnKey,
                      icon: CupertinoIcons.search,
                      onTap: _openJobs,
                    ),
                    const SizedBox(width: 10),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: NotificationService.instance.notificationsStream,
                      builder: (context, snap) {
                        final uid = Supabase.instance.client.auth.currentUser?.id;
                        final unread = (snap.data ?? [])
                            .where(
                              (n) =>
                                  n['user_id']?.toString() == uid &&
                                  n['is_read'] != true,
                            )
                            .length;
                        return _TopCircleButton(
                          key: cmFeedBellBtnKey,
                          icon: CupertinoIcons.bell,
                          badgeCount: unread,
                          onTap: _openNotifications,
                        );
                      },
                    ),
                  ],
                ),
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
                                ? const Color(0xFFFF6A1A)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFFF9A63)
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
                color: Color(0xFFFF6A1A),
              ),
            ),
          ),
      ],
    );
  }

  String _distanceLabel(NexUser user) {
    if (user.latitude == null || user.longitude == null) return 'Compatible';
    final seed = (user.latitude!.abs() + user.longitude!.abs()) % 4.8;
    return '${(0.8 + seed).toStringAsFixed(1)} km';
  }
}

class _TopCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  const _TopCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6A1A),
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

class _DesktopSignalRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool dark;

  const _DesktopSignalRow({
    required this.icon,
    required this.label,
    required this.value,
    this.dark = true,
  });

  @override
  Widget build(BuildContext context) {
    final primary = dark ? Colors.white : const Color(0xFF0F172A);
    final secondary = dark ? const Color(0xFFB7C2D4) : const Color(0xFF64748B);

    return Row(
      children: [
        Icon(icon, size: 17, color: secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DesktopInfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF475569)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopTag extends StatelessWidget {
  final String label;

  const _DesktopTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.startsWith('#') ? label : '#$label',
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF5A36D8),
          fontWeight: FontWeight.w700,
        ),
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
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: enabled ? 0.12 : 0.06),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: enabled ? Colors.white : const Color(0xFF6B778C),
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
            CupertinoActivityIndicator(radius: 14, color: Color(0xFFFF6A1A)),
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
              color: const Color(0xFFFF6A1A),
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
