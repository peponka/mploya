import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../screens/home_feed_screen.dart';
import '../screens/network_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/ats_dashboard_screen.dart';
import '../services/revenuecat_service.dart';
import '../services/connectivity_service.dart';
import '../services/video_preload_manager.dart';

final ValueNotifier<int> currentMainTabNotifier = ValueNotifier<int>(0);

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  int _unreadNotifications = 0;
  int _pendingConnections = 0;
  String _accountType = 'candidato';

  StreamSubscription<List<Map<String, dynamic>>>? _notifSub;
  StreamSubscription<List<Map<String, dynamic>>>? _connSub;


  @override
  void initState() {
    super.initState();
    _subscribeToCounters();
    _fetchAccountType();
    
    // Inicializar RevenueCat con el UID
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      RevenueCatService.instance.initialize(uid);
    }
  }

  // Screens estáticos (nunca se reconstruyen)
  static const _homeFeed = HomeFeedScreen();
  static const _explore = ExploreScreen();
  static const _network = NetworkScreen();
  static const _atsDashboard = AtsDashboardScreen();
  static const _notifications = NotificationsScreen();
  static const _profile = ProfileScreen();

  /// Retorna la lista de screens usando el tipo de cuenta actual.
  /// Solo tab 2 cambia entre Network y ATS — los demás son constantes.
  List<Widget> get _screens => [
    _homeFeed,
    _explore,
    _accountType == 'empresa' ? _atsDashboard : _network,
    _notifications,
    _profile,
  ];

  Future<void> _fetchAccountType() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    // 1. Leer inmediatamente el valor cacheado para evitar flash de UI incorrecta
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('mploya_account_type');
      if (cached != null && cached != _accountType && mounted) {
        setState(() => _accountType = cached);
      }
    } catch (_) {}

    // 2. Intentar obtener el valor real del servidor
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('account_type')
          .eq('id', uid)
          .single();
      final newType = res['account_type']?.toString() ?? 'candidato';
      
      // 3. Persistir en SharedPreferences para futuros arranques
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('mploya_account_type', newType);
      } catch (_) {}

      if (mounted && newType != _accountType) {
        setState(() => _accountType = newType);
      }
    } catch (e) {
      debugPrint('⚠️ fetchAccountType failed: $e');
      // Retry con backoff — pero el valor cacheado ya se aplicó arriba
      if (mounted) {
        Future.delayed(const Duration(seconds: 3), _fetchAccountType);
      }
    }
  }

  /// Suscribe a notificaciones no leídas y solicitudes de conexión pendientes.
  /// Los contadores se actualizan en tiempo real sin polling.
  void _subscribeToCounters() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _notifSub = Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .listen(
          (rows) {
            if (!mounted) return;
            setState(() {
              _unreadNotifications = rows.where((r) => r['is_read'] == false).length;
            });
          },
          onError: (e) => debugPrint('⚠️ notifications stream error (non-fatal): $e'),
        );

    _connSub = Supabase.instance.client
        .from('connections')
        .stream(primaryKey: ['id'])
        .eq('addressee_id', uid)
        .listen(
          (rows) {
            if (!mounted) return;
            setState(() {
              _pendingConnections = rows.where((r) => r['status'] == 'pending').length;
            });
          },
          onError: (e) => debugPrint('⚠️ connections stream error (non-fatal): $e'),
        );
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return; // sin haptic si ya estás en ese tab
    HapticFeedback.selectionClick();
    // ── Audio del Feed: cortar al salir, reanudar al volver ──
    // Como la navegación usa IndexedStack, el Feed sigue vivo en segundo plano;
    // sin esto, el audio del video se escucharía en toda la app.
    if (index != 0) {
      VideoPreloadManager.instance.pauseAll();
    } else {
      VideoPreloadManager.instance.resumeCurrent();
    }
    setState(() => _currentIndex = index);
    currentMainTabNotifier.value = index;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CupertinoColors.systemBackground,
      child: Stack(
        children: [
          // ── Screen Content ──
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // ── Offline Banner ──
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: OfflineBanner(),
            ),
          ),

          // ── Custom Tab Bar ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _CustomTabBar(
              currentIndex: _currentIndex,
              onTap: _onTabTap,
              unreadNotifications: _unreadNotifications,
              pendingConnections: _pendingConnections,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadNotifications;
  final int pendingConnections;

  const _CustomTabBar({
    required this.currentIndex,
    required this.onTap,
    required this.unreadNotifications,
    required this.pendingConnections,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.isDark
            ? Colors.black
            : Colors.white,
        border: Border(
          top: BorderSide(
            color: context.dividerColor.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Row(
            children: [
              _TabItem(
                icon: CupertinoIcons.play_rectangle_fill,
                inactiveIcon: CupertinoIcons.play_rectangle,
                label: 'Feed',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _TabItem(
                icon: CupertinoIcons.compass_fill,
                inactiveIcon: CupertinoIcons.compass,
                label: 'Explorar',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _TabItem(
                icon: CupertinoIcons.bolt_fill,
                inactiveIcon: CupertinoIcons.bolt,
                label: 'Matches',
                badgeCount: pendingConnections,
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _TabItem(
                icon: CupertinoIcons.bell_fill,
                inactiveIcon: CupertinoIcons.bell,
                label: 'Alertas',
                badgeCount: unreadNotifications,
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _TabItem(
                icon: CupertinoIcons.person_fill,
                inactiveIcon: CupertinoIcons.person,
                label: 'Perfil',
                isActive: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final IconData inactiveIcon;
  final String label;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.inactiveIcon,
    required this.label,
    required this.isActive,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = MployaTheme.brandAccent;
    final inactiveColor = context.textTertiary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFF97316).withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isActive ? icon : inactiveIcon,
                    size: isActive ? 24 : 22,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: MployaTheme.danger,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: MployaTheme.danger.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeColor : inactiveColor,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            // Active pill indicator (more visible than a dot)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: isActive ? 16 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: MployaTheme.brandAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}
