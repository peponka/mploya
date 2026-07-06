import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../screens/jobs_screen.dart';
import '../screens/messaging_screen.dart';
import '../services/revenuecat_service.dart';
import '../services/connectivity_service.dart';
import '../services/video_preload_manager.dart';
import '../services/coach_mark_service.dart';

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
  int _unreadMessages = 0;
  String _accountType = 'candidato';
  int _fetchAccountTypeRetries = 0;

  StreamSubscription<List<Map<String, dynamic>>>? _notifSub;
  StreamSubscription<List<Map<String, dynamic>>>? _connSub;
  StreamSubscription<List<Map<String, dynamic>>>? _msgSub;

  @override
  void initState() {
    super.initState();
    _subscribeToCounters();
    _fetchAccountType();

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      RevenueCatService.instance.initialize(uid);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CoachMarkService.showNavTour(context);
    });
  }

  // Screens estáticos (nunca se reconstruyen)
  static const _homeFeed = HomeFeedScreen();
  static const _explore = ExploreScreen();
  static const _network = NetworkScreen();
  static const _atsDashboard = AtsDashboardScreen();
  static const _notifications = NotificationsScreen();
  static const _profile = ProfileScreen();
  // Unificado en un solo sistema de chat (antes había dos pantallas de
  // mensajería distintas y no relacionadas: "Mensajes" acá vs "Inbox" desde
  // el ícono de sobre del Feed). Nos quedamos con MessagingScreen (Inbox),
  // la más completa: rompehielos con IA, indicador de "escribiendo...",
  // videollamada.
  static const _messages = MessagingScreen();

  List<Widget> get _screens => [
        _homeFeed,           // 0
        _explore,            // 1
        (_accountType == 'empresa' || _accountType == 'headhunter') ? _atsDashboard : _network, // 2
        _notifications,      // 3
        _profile,            // 4
        _messages,           // 5
        const JobsScreen(),  // 6 (web sidebar only)
      ];

  Future<void> _fetchAccountType() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('mploya_account_type');
      if (cached != null && cached != _accountType && mounted) {
        setState(() => _accountType = cached);
      }
    } catch (_) {}

    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('account_type')
          .eq('id', uid)
          .single();
      final newType = res['account_type']?.toString() ?? 'candidato';

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('mploya_account_type', newType);
      } catch (_) {}

      if (mounted && newType != _accountType) {
        setState(() => _accountType = newType);
      }
    } catch (e) {
      debugPrint('⚠️ fetchAccountType failed: $e');
      if (mounted && _fetchAccountTypeRetries < 3) {
        _fetchAccountTypeRetries++;
        Future.delayed(Duration(seconds: 3 * _fetchAccountTypeRetries), _fetchAccountType);
      }
    }
  }

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
              _unreadNotifications =
                  rows.where((r) => r['is_read'] == false).length;
            });
          },
          onError: (e) =>
              debugPrint('⚠️ notifications stream error (non-fatal): $e'),
        );

    _connSub = Supabase.instance.client
        .from('connections')
        .stream(primaryKey: ['id'])
        .eq('addressee_id', uid)
        .listen(
          (rows) {
            if (!mounted) return;
            setState(() {
              _pendingConnections =
                  rows.where((r) => r['status'] == 'pending').length;
            });
          },
          onError: (e) =>
              debugPrint('⚠️ connections stream error (non-fatal): $e'),
        );

    _msgSub = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .listen(
          (rows) {
            if (!mounted) return;
            setState(() {
              _unreadMessages = rows
                  .where((r) =>
                      r['receiver_id'] == uid && r['is_read'] == false)
                  .length;
            });
          },
          onError: (e) =>
              debugPrint('⚠️ messages stream error (non-fatal): $e'),
        );
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _connSub?.cancel();
    _msgSub?.cancel();
    super.dispose();
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    if (!kIsWeb) HapticFeedback.selectionClick();
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
    // ── Layout responsive: sidebar en web/desktop, tab bar en mobile ──
    final isWideScreen =
        kIsWeb && MediaQuery.of(context).size.width > 700;

    if (isWideScreen) {
      return _WebLayout(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        screens: _screens,
        unreadNotifications: _unreadNotifications,
        pendingConnections: _pendingConnections,
        unreadMessages: _unreadMessages,
        accountType: _accountType,
      );
    }

    // Mobile layout (tab bar inferior)
    // El OfflineBanner vive en el flujo normal (Column), no flotando encima
    // del contenido: así empuja la pantalla hacia abajo en vez de taparle
    // el título (antes se superponía a "Notificaciones", "Perfil", etc.).
    return Container(
      color: CupertinoColors.systemBackground,
      child: Column(
        children: [
          const SafeArea(bottom: false, child: OfflineBanner()),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _CustomTabBar(
                    currentIndex: _currentIndex,
                    onTap: _onTabTap,
                    unreadNotifications: _unreadNotifications,
                    pendingConnections: _pendingConnections,
                    unreadMessages: _unreadMessages,
                    accountType: _accountType,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Web Layout — TikTok-style: sidebar izquierda + feed central + panel derecho
// ─────────────────────────────────────────────────────────────────────────────

class _WebLayout extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<Widget> screens;
  final int unreadNotifications;
  final int pendingConnections;
  final int unreadMessages;
  final String accountType;

  const _WebLayout({
    required this.currentIndex,
    required this.onTap,
    required this.screens,
    required this.unreadNotifications,
    required this.pendingConnections,
    required this.unreadMessages,
    required this.accountType,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final screenWidth = MediaQuery.of(context).size.width;
    // sidebar expandida en pantallas >= 1200px
    final isExpanded = screenWidth >= 1200;

    final sidebarBg = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0);

    return Row(
      children: [
        // ── LEFT SIDEBAR (TikTok-style) ──────────────────────────────────
        Container(
          width: isExpanded ? 240 : 72,
          decoration: BoxDecoration(
            color: sidebarBg,
            border: Border(
              right: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Logo
              Container(
                height: 60,
                alignment:
                    isExpanded ? Alignment.centerLeft : Alignment.center,
                padding: EdgeInsets.symmetric(
                  horizontal: isExpanded ? 20 : 0,
                ),
                child: isExpanded
                    ? Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFF97316),
                                  Color(0xFFEA580C),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'm',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'mploya',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF97316),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Text(
                            '.ai',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF9CA3AF),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            'm',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              // Nav items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    Container(
                      key: cmNavFeedKey,
                      child: _SidebarItem(
                        icon: CupertinoIcons.play_rectangle_fill,
                        inactiveIcon: CupertinoIcons.play_rectangle,
                        label: 'Para ti',
                        isActive: currentIndex == 0,
                        isExpanded: isExpanded,
                        badgeCount: 0,
                        onTap: () => onTap(0),
                      ),
                    ),
                    Container(
                      key: cmNavExploreKey,
                      child: _SidebarItem(
                        icon: CupertinoIcons.compass_fill,
                        inactiveIcon: CupertinoIcons.compass,
                        label: 'Explorar',
                        isActive: currentIndex == 1,
                        isExpanded: isExpanded,
                        badgeCount: 0,
                        onTap: () => onTap(1),
                      ),
                    ),
                    Container(
                      key: cmNavMatchKey,
                      child: _SidebarItem(
                        icon: (accountType == 'empresa' || accountType == 'headhunter')
                            ? CupertinoIcons.briefcase_fill
                            : CupertinoIcons.bolt_fill,
                        inactiveIcon: (accountType == 'empresa' || accountType == 'headhunter')
                            ? CupertinoIcons.briefcase
                            : CupertinoIcons.bolt,
                        label: (accountType == 'empresa' || accountType == 'headhunter') ? 'Candidatos' : 'Matches',
                        isActive: currentIndex == 2,
                        isExpanded: isExpanded,
                        badgeCount: pendingConnections,
                        onTap: () => onTap(2),
                      ),
                    ),
                    Container(
                      key: cmNavAlertsKey,
                      child: _SidebarItem(
                        icon: CupertinoIcons.bell_fill,
                        inactiveIcon: CupertinoIcons.bell,
                        label: 'Alertas',
                        isActive: currentIndex == 3,
                        isExpanded: isExpanded,
                        badgeCount: unreadNotifications,
                        onTap: () => onTap(3),
                      ),
                    ),
                    Container(
                      key: cmNavProfileKey,
                      child: _SidebarItem(
                        icon: CupertinoIcons.person_fill,
                        inactiveIcon: CupertinoIcons.person,
                        label: 'Perfil',
                        isActive: currentIndex == 4,
                        isExpanded: isExpanded,
                        badgeCount: 0,
                        onTap: () => onTap(4),
                      ),
                    ),
                    _SidebarItem(
                      icon: CupertinoIcons.chat_bubble_2_fill,
                      inactiveIcon: CupertinoIcons.chat_bubble_2,
                      label: 'Mensajes',
                      isActive: currentIndex == 5,
                      isExpanded: isExpanded,
                      badgeCount: unreadMessages,
                      onTap: () => onTap(5),
                    ),
                    Container(
                      key: cmNavJobsKey,
                      child: _SidebarItem(
                        icon: CupertinoIcons.briefcase_fill,
                        inactiveIcon: CupertinoIcons.briefcase,
                        label: 'Vacantes',
                        isActive: currentIndex == 6,
                        isExpanded: isExpanded,
                        badgeCount: 0,
                        onTap: () => onTap(6),
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom separator
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: borderColor,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // ── CENTER CONTENT ───────────────────────────────────────────────
        // El OfflineBanner va en el flujo normal (Column) para empujar el
        // contenido hacia abajo en vez de superponerse y tapar títulos.
        Expanded(
          child: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: IndexedStack(
                  index: currentIndex,
                  children: [
                    // Feed (0): ancho completo. El propio feed se centra a
                    // 430px sobre fondo negro (estilo TikTok web).
                    screens[0],
                    // Resto: área web ancha y centrada (no columna mobile).
                    for (int i = 1; i < screens.length; i++)
                      _WebContentArea(child: screens[i]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar Nav Item
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final IconData inactiveIcon;
  final String label;
  final bool isActive;
  final bool isExpanded;
  final int badgeCount;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.inactiveIcon,
    required this.label,
    required this.isActive,
    required this.isExpanded,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    const activeColor = MployaTheme.brandAccent;
    final inactiveColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final hoverBg = isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF9FAFB);
    final activeBg = const Color(0xFFF97316).withValues(alpha: 0.10);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isExpanded ? 12 : 0,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? activeBg
                : _hovering
                    ? hoverBg
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: widget.isExpanded
              ? Row(
                  children: [
                    const SizedBox(width: 4),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          widget.isActive
                              ? widget.icon
                              : widget.inactiveIcon,
                          size: 24,
                          color:
                              widget.isActive ? activeColor : inactiveColor,
                        ),
                        if (widget.badgeCount > 0)
                          Positioned(
                            right: -8,
                            top: -4,
                            child: _Badge(count: widget.badgeCount),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: widget.isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color:
                            widget.isActive ? activeColor : inactiveColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        widget.isActive ? widget.icon : widget.inactiveIcon,
                        size: 24,
                        color: widget.isActive ? activeColor : inactiveColor,
                      ),
                      if (widget.badgeCount > 0)
                        Positioned(
                          right: -8,
                          top: -4,
                          child: _Badge(count: widget.badgeCount),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: MployaTheme.danger,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Web Content Area — centra el contenido en un ancho web cómodo (no mobile)
// ─────────────────────────────────────────────────────────────────────────────
class _WebContentArea extends StatelessWidget {
  final Widget child;
  const _WebContentArea({required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile Tab Bar (unchanged from original)
// ─────────────────────────────────────────────────────────────────────────────

class _CustomTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadNotifications;
  final int pendingConnections;
  final int unreadMessages;
  final String accountType;

  const _CustomTabBar({
    required this.currentIndex,
    required this.onTap,
    required this.unreadNotifications,
    required this.pendingConnections,
    required this.unreadMessages,
    required this.accountType,
  });

  bool get isCompanyAccount => accountType == 'empresa' || accountType == 'headhunter';

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? Colors.black : Colors.white,
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
          Container(
            key: cmNavFeedKey,
            child: _TabItem(
              icon: CupertinoIcons.play_rectangle_fill,
              inactiveIcon: CupertinoIcons.play_rectangle,
              label: 'Feed',
              isActive: currentIndex == 0,
              onTap: () => onTap(0),
            ),
          ),
          Container(
            key: cmNavExploreKey,
            child: _TabItem(
              icon: CupertinoIcons.compass_fill,
              inactiveIcon: CupertinoIcons.compass,
              label: 'Explorar',
              isActive: currentIndex == 1,
              onTap: () => onTap(1),
            ),
          ),
          Container(
            key: cmNavMatchKey,
            child: _TabItem(
              icon: isCompanyAccount ? CupertinoIcons.briefcase_fill : CupertinoIcons.bolt_fill,
              inactiveIcon: isCompanyAccount ? CupertinoIcons.briefcase : CupertinoIcons.bolt,
              label: isCompanyAccount ? 'Candidatos' : 'Matches',
              badgeCount: pendingConnections,
              isActive: currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ),
          Container(
            key: cmNavAlertsKey,
            child: _TabItem(
              icon: CupertinoIcons.bell_fill,
              inactiveIcon: CupertinoIcons.bell,
              label: 'Alertas',
              badgeCount: unreadNotifications,
              isActive: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ),
          Container(
            key: cmNavProfileKey,
            child: _TabItem(
              icon: CupertinoIcons.person_fill,
              inactiveIcon: CupertinoIcons.person,
              label: 'Perfil',
              isActive: currentIndex == 4,
              onTap: () => onTap(4),
            ),
          ),
          _TabItem(
            icon: CupertinoIcons.chat_bubble_2_fill,
            inactiveIcon: CupertinoIcons.chat_bubble_2,
            label: 'Mensajes',
            badgeCount: unreadMessages,
            isActive: currentIndex == 5,
            onTap: () => onTap(5),
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
                      child: _Badge(count: badgeCount),
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
