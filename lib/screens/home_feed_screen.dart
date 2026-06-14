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

import 'profile_screen.dart';
import 'ats_kanban_screen.dart';
import 'premium_paywall_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../providers/feed_provider.dart';
import '../screens/jobs_screen.dart';
import '../screens/vacantes_screen.dart';
import '../screens/messaging_screen.dart';
import '../screens/analytics_dashboard_screen.dart';
import '../services/revenuecat_service.dart';
import 'pitch_challenge_screen.dart';
import '../widgets/mploya_toast.dart';
import '../widgets/feature_hint.dart';

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


  void _showPremiumPaywall() {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const PremiumPaywallScreen()),
    );
  }

  Post _userToPost(Map<String, dynamic> data) {
    return FeedService.instance.userRowToPost(data, likedUserIds: _likedUserIds);
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
      // Web (TikTok web): fondo claro. Móvil: negro full-bleed.
      backgroundColor: webMode ? const Color(0xFFF7F8FA) : Colors.black,
      child: SizedBox.expand(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                // Móvil ocupa todo el ancho; en web deja lugar para video + acciones.
                constraints: BoxConstraints(maxWidth: webMode ? 540 : 430),
                child: Stack(
            children: [
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

                // El array de items ya viene 100% filtrado y ordenado
                final rows = feedState.items;

                if (rows.isEmpty) {
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
                            'SÃ© el primero en tu industria',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 20,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Los candidatos con Video-Pitch reciben 3x mÃ¡s contactos de empresas.',
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
                            final card = TikTokReelCard(post: _userToPost(rows[index]), webMode: webMode);
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
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    final isCompany = currentUser?.accountType == 'empresa' ||
                                        currentUser?.accountType == 'headhunter';
                                    Navigator.of(context).push(
                                      CupertinoPageRoute<void>(
                                        builder: (_) => isCompany
                                            ? const VacantesScreen()
                                            : const JobsScreen(),
                                      ),
                                    );
                                  },
                                  child: const Icon(CupertinoIcons.briefcase, size: 20, color: Colors.white,
                                      shadows: [Shadow(color: Colors.black, blurRadius: 8)]),
                                ),
                                const SizedBox(width: 18),
                                // ── Mensajes (con contador de no leídos) ──
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.of(context).push(
                                      CupertinoPageRoute<void>(builder: (_) => const MessagingScreen()),
                                    );
                                  },
                                  child: const _UnreadMessagesIcon(),
                                ),
                                const SizedBox(width: 18),
                                // ── Bell ──
                                CupertinoButton(
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
                                          const Icon(CupertinoIcons.bell, size: 20, color: Colors.white,
                                              shadows: [Shadow(color: Colors.black, blurRadius: 8)]),
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
                    ],
                  ),
                );
              },
            ),
          ),


            ],
              ),   // Stack inner
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
    const icon = Icon(CupertinoIcons.chat_bubble, size: 20, color: Colors.white,
        shadows: [Shadow(color: Colors.black, blurRadius: 8)]);
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
