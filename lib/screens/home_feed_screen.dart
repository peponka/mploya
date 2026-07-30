import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/feed_service.dart';
import '../services/video_preload_manager.dart';
import '../services/notification_service.dart';
import '../widgets/tiktok_reel_card.dart';
import '../widgets/story_row.dart';
import '../widgets/onboarding_tour.dart';
import '../theme/app_theme.dart';
import 'notifications_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../providers/feed_provider.dart';
import '../screens/jobs_screen.dart';
import '../widgets/mploya_toast.dart';
import '../widgets/feature_hint.dart';
import '../services/coach_mark_service.dart';

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {

  // â”€â”€ Controlador de pÃ¡ginas para detectar el fin del feed â”€â”€
  final PageController _pageController = PageController();

  // IDs de pitches que el usuario actual ya likeÃ³ (real-time stream).
  final Set<String> _likedUserIds = {};
  StreamSubscription<List<Map<String, dynamic>>>? _likesSub;

  // Pull-to-refresh state for TikTok PageView
  bool _isRefreshing = false;
  double _overscrollTotal = 0;

  // ── Categorías (rediseño 30/7) ──
  // Reemplazan el patrón de "letras circulares confusas" del mockup de
  // referencia por chips claras. Filtran client-side sobre lo ya traído del
  // feed (headline/tags/skills contra un set de palabras clave por rubro) —
  // no hay una taxonomía de categorías real en la base todavía, así que esto
  // filtra de verdad en vez de ser una UI decorativa sin efecto.
  String _selectedCategory = 'todos';

  static const Map<String, String> _categoryLabels = {
    'todos': 'Todos',
    'tecnologia': 'Tecnología',
    'ventas': 'Ventas',
    'administracion': 'Administración',
    'finanzas': 'Finanzas',
    'marketing': 'Marketing',
    'diseno': 'Diseño',
  };

  static const Map<String, List<String>> _categoryKeywords = {
    'tecnologia': ['flutter', 'react', 'developer', 'dev', 'software', 'engineer',
      'ingenier', 'backend', 'frontend', 'fullstack', 'devops', 'data', 'python',
      'java', 'node', 'sql', 'aws', 'cloud', 'programad', 'tech', 'it'],
    'ventas': ['ventas', 'sales', 'comercial', 'account manager', 'business dev'],
    'administracion': ['administra', 'operaciones', 'rrhh', 'recursos humanos',
      'hr', 'people', 'talent'],
    'finanzas': ['finanzas', 'contab', 'cfo', 'contador', 'financial', 'tesorer'],
    'marketing': ['marketing', 'growth', 'seo', 'ads', 'contenido', 'social media',
      'comunicaci'],
    'diseno': ['diseñ', 'design', 'ux', 'ui', 'product designer', 'creativ'],
  };

  String _haystackFor(Map<String, dynamic> r) => [
        (r['headline'] ?? '').toString(),
        (r['about'] ?? '').toString(),
        ...((r['tags'] as List?) ?? const []).map((e) => e.toString()),
        ...((r['skills'] as List?) ?? const []).map((e) => e.toString()),
      ].join(' ').toLowerCase();

  /// Palabras de 3 letras o menos (ui, hr, it, dev, sql...) necesitan borde de
  /// palabra: sin esto, "ui" matcheaba dentro de "equipo" (eq-UI-po) y un CFO
  /// con la etiqueta "trabajo en equipo" aparecía listado en Diseño. Las
  /// palabras más largas (diseñ, administra, programad...) son prefijos a
  /// propósito para cubrir conjugaciones (diseñador/diseñadora/diseño) y sí
  /// pueden matchear como substring.
  bool _keywordMatch(String haystack, String kw) {
    if (kw.length > 3) return haystack.contains(kw);
    final re = RegExp('(^|[^a-záéíóúñ])${RegExp.escape(kw)}([^a-záéíóúñ]|\$)');
    return re.hasMatch(haystack);
  }

  List<Map<String, dynamic>> _filterByCategory(List<Map<String, dynamic>> items) {
    if (_selectedCategory == 'todos') return items;
    final kws = _categoryKeywords[_selectedCategory] ?? const [];
    return items.where((r) {
      final haystack = _haystackFor(r);
      return kws.any((k) => _keywordMatch(haystack, k));
    }).toList();
  }

  /// Categorías que tienen al menos un candidato real en el feed actual.
  /// Con pocos usuarios (hoy: Ventas y Administración en 0), mostrar una
  /// categoría siempre vacía es peor que no mostrarla — un reclutador que la
  /// toca y ve "sin resultados" desconfía del producto. Al calcularse en cada
  /// render, las categorías aparecen solas apenas haya un candidato real de
  /// ese rubro, sin tocar código de nuevo.
  Set<String> _categoriesWithData(List<Map<String, dynamic>> items) {
    final present = <String>{};
    for (final entry in _categoryKeywords.entries) {
      final hasMatch = items.any((r) {
        final haystack = _haystackFor(r);
        return entry.value.any((k) => _keywordMatch(haystack, k));
      });
      if (hasMatch) present.add(entry.key);
    }
    return present;
  }

  Iterable<MapEntry<String, String>> _visibleCategoryEntries(List<Map<String, dynamic>> items) {
    final present = _categoriesWithData(items);
    return _categoryLabels.entries.where((e) => e.key == 'todos' || present.contains(e.key));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Pausar videos mientras se muestra el tour para que no suene el audio de fondo
      VideoPreloadManager.instance.pauseAll();
      final shown = await OnboardingTourOverlay.showIfNeeded(context);
      if (shown && mounted) {
        // Tour terminÃ³ â€” reanudar videos
        VideoPreloadManager.instance.resumeCurrent();
      } else if (!shown) {
        // No se mostrÃ³ el tour (ya lo vio) â€” reanudar normalmente
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
            }, onError: (e) {
              debugPrint('âš ï¸ pitch_likes stream error (non-fatal): $e');
            });
      } catch (e) {
        debugPrint('âš ï¸ pitch_likes stream init failed (non-fatal): $e');
      }
    }
  }

  // Funciones de carga delegadas al FeedNotifier


  @override
  void dispose() {
    _pageController.dispose();
    _likesSub?.cancel();
    // IMPORTANTE: NO llamar disposeAll() aquÃ­ â€” el manager es singleton y
    // los TikTokReelCard pueden seguir referenciando controllers activos.
    // Solo pausar. disposeAll() se llama Ãºnicamente en logout/deleteAccount.
    VideoPreloadManager.instance.pauseAll();
    super.dispose();
  }


  Post _userToPost(Map<String, dynamic> data) {
    return FeedService.instance.userRowToPost(data, likedUserIds: _likedUserIds);
  }

  // ── Sidebar de categorías (web) ──
  // Columna izquierda del layout de 3 columnas del rediseño 30/7. Mismas
  // categorías y misma lógica de filtro que la barra horizontal de móvil
  // (_filterByCategory arriba) — es la versión ancha del mismo control, no un
  // filtro nuevo/distinto.
  Widget _buildWebCategorySidebar() {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text('CATEGORÍAS',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Color(0xFF94A3B8))),
          ),
          ..._visibleCategoryEntries(ref.watch(feedProvider).items).map((e) {
            final selected = _selectedCategory == e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () => setState(() => _selectedCategory = e.key),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF185FA5) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? const Color(0xFF185FA5) : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(e.value,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : const Color(0xFF334155))),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(feedProvider, (prev, next) {
      if (prev?.items != next.items) {
        final urls = next.items.map((r) {
          final url = r['video_url']?.toString() ?? '';
          return url.isNotEmpty ? url : '';
        }).toList();
        VideoPreloadManager.instance.updateFeedUrls(urls);
      }
    });

    final webMode = kIsWeb && MediaQuery.of(context).size.width > 700;

    return CupertinoPageScaffold(
      // Rediseño 23/7: fondo claro en web y móvil (antes el móvil era negro
      // full-bleed). Ahora cada reel es una tarjeta clara contenida.
      backgroundColor: const Color(0xFFF7F8FA),
      child: SizedBox.expand(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                // Móvil ocupa todo el ancho; en web usa 3 columnas: categorías,
                // video e info del candidato (antes quedaba angosto sin sidebar).
                constraints: BoxConstraints(maxWidth: webMode ? 1120 : 430),
                child: Builder(builder: (context) {
                final stackChildren = <Widget>[
          // â”€â”€ Capa 1: Feed TikTok Infinito (Fondo) â”€â”€
          Positioned.fill(
            child: Builder(
              builder: (context) {
                final feedState = ref.watch(feedProvider);

                // â”€â”€ Estado de carga inicial â”€â”€
                if (feedState.isInitialLoading) {
                  return Container(
                    color: Colors.black,
                    child: Stack(
                      children: [
                        // Pulsing dark gradient background
                        Positioned.fill(
                          child: _FeedSkeletonPulse(),
                        ),
                        // ── Branding AI Match (render #2) ──
                        Positioned.fill(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 60, height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF185FA5).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(CupertinoIcons.bolt_fill, color: Color(0xFF185FA5), size: 30),
                                ),
                                const SizedBox(height: 18),
                                const Text('AI Match', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                                const SizedBox(height: 6),
                                Text('Encontrando tu match ideal…', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                                const SizedBox(height: 18),
                                const CupertinoActivityIndicator(color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                        // Placeholder overlay info
                        Positioned(
                          bottom: 100,
                          left: 20,
                          right: 80,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 160, height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: 220, height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Container(
                                    width: 70, height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 80, height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Right side action buttons placeholder
                        Positioned(
                          bottom: 140,
                          right: 16,
                          child: Column(
                            children: List.generate(4, (i) => Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // â”€â”€ Error sin datos previos â”€â”€
                if (feedState.error != null && feedState.items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.wifi_slash, color: Colors.white54, size: 48),
                          const SizedBox(height: 16),
                          const Text('Error al cargar el feed',
                              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => ref.read(feedProvider.notifier).refreshFeed(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              decoration: NexTheme.gradientButtonDecoration(
                                borderRadius: 20,
                              ),
                              child: const Text(
                                'Reintentar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final currentUserAsync = ref.watch(currentUserProvider);

                if (currentUserAsync.isLoading) {
                  return const Center(
                    child: CupertinoActivityIndicator(color: Colors.white, radius: 16),
                  );
                }

                // El array de items ya viene 100% filtrado y ordenado; acá se
                // le suma el filtro de categoría (client-side, ver arriba).
                final allRows = feedState.items;
                final rows = _filterByCategory(allRows);

                if (allRows.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.rocket_fill,
                              size: 56, color: Colors.white.withValues(alpha: 0.4)),
                          const SizedBox(height: 20),
                          Text(
                            'Sé el primero en tu industria',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 20,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Los candidatos con Video-Pitch reciben 3x más contactos de empresas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 14,
                                fontWeight: FontWeight.w400),
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: () => ref.read(feedProvider.notifier).refreshFeed(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              decoration: NexTheme.gradientButtonDecoration(
                                borderRadius: 25,
                              ),
                              child: const Text(
                                'Actualizar feed',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Hay feed, pero ninguno matchea la categoría elegida: no
                // mostrar la pantalla vacía genérica de arriba (esa es para
                // "no hay nadie en la base todavía"), sino invitar a volver a
                // "Todos" — la categoría filtró de más, no falta contenido.
                if (rows.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.search,
                              size: 48, color: Colors.white.withValues(alpha: 0.35)),
                          const SizedBox(height: 16),
                          Text(
                            'Sin resultados en ${_categoryLabels[_selectedCategory]}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 17,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Todavía no hay candidatos en esta categoría.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 13.5),
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => setState(() => _selectedCategory = 'todos'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF185FA5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Ver todos',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // itemCount +1 cuando hay mÃ¡s datos cargÃ¡ndose (spinner al final)
                final itemCount = rows.length + (feedState.isLoading ? 1 : 0);

                return Stack(
                  children: [
                    NotificationListener<OverscrollNotification>(
                      onNotification: (notification) {
                        // Only trigger refresh when overscrolling at the top (page 0)
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
                            VideoPreloadManager.instance.onPageChanged(index);
                            if (feedState.hasMore && !feedState.isLoading && index >= rows.length - 3) {
                              ref.read(feedProvider.notifier).loadMore();
                            }
                          },
                          itemCount: itemCount,
                          itemBuilder: (context, index) {
                            if (index >= rows.length) {
                              return const Center(
                                child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
                              );
                            }
                            final card = TikTokReelCard(post: _userToPost(rows[index]), webMode: webMode, isFirstCard: index == 0);
                            // Show gesture hint only on the very first card
                            if (index == 0) {
                              return FeatureHints.doubleTapInterest(child: card);
                            }
                            return card;
                          },
                        ),
                      ),
                    ),
                    // Pull-to-refresh indicator overlay
                    if (_isRefreshing)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 60,
                        left: 0,
                        right: 0,
                        child: const Center(
                          child: CupertinoActivityIndicator(color: Colors.white, radius: 12),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // ── Header (oculto en web: el sidebar ya navega; look más limpio) ──
          if (!webMode)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Builder(
              builder: (context) {
                final currentUser = ref.watch(currentUserProvider).value;
                final topPad = MediaQuery.of(context).padding.top;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 0.75, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: topPad + 6),
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 6,
                          left: 16,
                          right: 14,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // ── Logo ──
                            const Text(
                              'MPLOYA',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 3.0,
                                height: 1.0,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 10),
                                  Shadow(color: Colors.black, blurRadius: 20),
                                ],
                              ),
                            ),
                            // ── Acciones: Empleos + Mensajes + Alertas ──
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ── Empleos / Vacantes ──
                                CupertinoButton(
                                  key: cmFeedJobsBtnKey,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.of(context).push(
                                      CupertinoPageRoute<void>(
                                        builder: (_) => const JobsScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                    ),
                                    child: const Icon(CupertinoIcons.briefcase_fill, size: 20, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // ── Bell ──
                                CupertinoButton(
                                  key: cmFeedBellBtnKey,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.of(context).push(
                                      CupertinoPageRoute(builder: (_) => const NotificationsScreen()),
                                    );
                                  },
                                  child: StreamBuilder<List<Map<String, dynamic>>>(
                                    stream: NotificationService.instance.notificationsStream,
                                    builder: (context, snap) {
                                      final uid = Supabase.instance.client.auth.currentUser?.id;
                                      final unread = (snap.data ?? [])
                                          .where((n) => n['user_id']?.toString() == uid && n['is_read'] != true)
                                          .length;
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 40, height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.45),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                            ),
                                            child: const Icon(CupertinoIcons.bell_fill, size: 20, color: Colors.white),
                                          ),
                                          if (unread > 0)
                                            Positioned(
                                              right: -6,
                                              top: -4,
                                              child: Container(
                                                padding: const EdgeInsets.all(3),
                                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFFF3B30),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    unread > 9 ? '9+' : '$unread',
                                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // ── Historias ──
                      // El widget existía pero no estaba montado en ninguna
                      // pantalla, y consultaba la vista `active_story_users` que
                      // no existía (creada en la migración 024). Solo se muestra
                      // si hay historias vigentes: se esconde solo.
                      Builder(
                        builder: (context) {
                          final items = ref.watch(feedProvider).items;
                          if (items.isEmpty) return const SizedBox.shrink();
                          final autores = items
                              .map((r) => _userToPost(r).author)
                              .toList();
                          return StoryRow(
                            users: autores,
                            isDarkOverlay: true,
                            currentAccountType: currentUser?.accountType ?? 'candidato',
                          );
                        },
                      ),
                      // ── Categorías ──
                      // Reemplaza las "letras circulares confusas" del mockup
                      // de referencia por chips claras y legibles; filtran de
                      // verdad sobre el feed (_filterByCategory arriba). Solo
                      // se muestran las que tienen al menos 1 candidato real
                      // (_visibleCategoryEntries) — con pocos usuarios, una
                      // categoría siempre vacía es peor que no tenerla.
                      Builder(
                        builder: (context) {
                          final items = ref.watch(feedProvider).items;
                          return SizedBox(
                            height: 34,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                              children: _visibleCategoryEntries(items).map((e) {
                            final selected = _selectedCategory == e.key;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedCategory = e.key),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 15),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selected ? const Color(0xFF185FA5) : Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                        color: selected ? const Color(0xFF185FA5) : Colors.white.withValues(alpha: 0.25)),
                                  ),
                                  child: Text(e.value,
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.9))),
                                ),
                              ),
                            );
                          }).toList(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),


            ];
                if (webMode) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 188, child: _buildWebCategorySidebar()),
                      const SizedBox(width: 18),
                      Expanded(child: Stack(children: stackChildren)),
                    ],
                  );
                }
                return Stack(children: stackChildren);
              }),
            ),     // ConstrainedBox
          ),       // Center
          if (webMode)
            Positioned(
              right: 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WebNavArrow(
                      icon: CupertinoIcons.chevron_up,
                      onTap: () {
                        if ((_pageController.page ?? 0) > 0) {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    _WebNavArrow(
                      icon: CupertinoIcons.chevron_down,
                      onTap: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
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
}

// ── Icono de Mensajes con contador de no leídos en tiempo real ──
class _UnreadMessagesIcon extends StatefulWidget {
  const _UnreadMessagesIcon();

  @override
  State<_UnreadMessagesIcon> createState() => _UnreadMessagesIconState();
}

class _UnreadMessagesIconState extends State<_UnreadMessagesIcon> {
  Stream<List<Map<String, dynamic>>>? _stream;

  @override
  void initState() {
    super.initState();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      _stream = Supabase.instance.client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('receiver_id', uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: const Icon(CupertinoIcons.chat_bubble_fill, size: 20, color: Colors.white),
    );
    if (_stream == null) return icon;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final unread = (snap.data ?? []).where((m) => m['is_read'] != true).length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            if (unread > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// â”€â”€ Animated pulsing skeleton for feed loading â”€â”€
class _FeedSkeletonPulse extends StatefulWidget {
  @override
  State<_FeedSkeletonPulse> createState() => _FeedSkeletonPulseState();
}

class _FeedSkeletonPulseState extends State<_FeedSkeletonPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final shimmerPos = -1.5 + _controller.value * 3.5;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(shimmerPos - 0.9, 0),
              end: Alignment(shimmerPos + 0.9, 0),
              colors: const [
                Color(0xFF080808),
                Color(0xFF161824),
                Color(0xFF242638),
                Color(0xFF161824),
                Color(0xFF080808),
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class _WebNavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _WebNavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF333333)),
      ),
    );
  }
}
