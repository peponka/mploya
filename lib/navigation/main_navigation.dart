import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/ats_dashboard_screen.dart';
import '../screens/create_story_screen.dart';
import '../screens/empresa_panel_hub_screen.dart';
import '../screens/empresa/empresa_actividad_screen.dart';
import '../screens/empresa/empresa_dashboard_screen.dart';
import '../screens/empresa/empresa_herramientas_screen.dart';
import '../screens/empresa/empresa_mapa_screen.dart';
import '../screens/empresa/empresa_mensajes_screen.dart';
import '../screens/empresa/empresa_perfil_screen.dart';
import '../screens/empresa/empresa_pipeline_screen.dart';
import '../screens/empresa/empresa_publicar_vacante_screen.dart';
import '../screens/empresa/empresa_shell.dart';
import '../screens/empresa/empresa_talent_feed_screen.dart';
import '../screens/empresa/empresa_vacantes_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/home_feed_screen.dart';
import '../screens/jobs_screen.dart';
import '../screens/messaging_screen.dart';
import '../screens/network_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/nueva_vacante_screen.dart';
import '../screens/onboarding_pitch_screen.dart';
import '../screens/post_composer_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/tools_hub_entry_screen.dart';
import '../services/coach_mark_service.dart';
import '../services/connectivity_service.dart';
import '../services/revenuecat_service.dart';
import '../services/video_preload_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/mploya_shell.dart';

final ValueNotifier<int> currentMainTabNotifier = ValueNotifier<int>(0);

final RouteObserver<ModalRoute<dynamic>> feedRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

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

  static const _homeFeed = HomeFeedScreen();
  // TANDA 1 — Empresa: feed de talento y dashboard rediseñados contra
  // FINAL_SCREENS_CODEX. Las pantallas legacy siguen en el repo para los otros
  // roles hasta que les toque su tanda.
  static const _companyTalentFeed = EmpresaTalentFeedScreen(embedded: true);
  static const _explore = ExploreScreen();
  static const _network = NetworkScreen();
  static const _atsDashboard = AtsDashboardScreen();
  static const _notifications = NotificationsScreen();
  static const _profile = ProfileScreen();
  static const _messages = MessagingScreen();
  static const _tools = ToolsHubEntryScreen();
  // TANDA 3 — Vacantes de Empresa rediseñada. `VacantesScreen` (legacy) queda
  // en el repo para los otros roles hasta que les toque su tanda.
  static const _companyVacantes = EmpresaVacantesScreen();

  /// No es `const`: le pasa el contador real de notificaciones a la campana.
  Widget get _companyDashboard =>
      EmpresaDashboardScreen(unreadNotifications: _unreadNotifications);

  /// Las ranuras son COMPARTIDAS por los tres roles y su numeración es un
  /// contrato: Empresa usa 0-8 y Headhunter {0,1,2,3,5,6,7,8}. Por eso el array
  /// no se reordena ni cambia de longitud — sólo cambia qué monta cada rol.
  ///
  /// Las ranuras que un rol no expone en su barra se neutralizan con
  /// `SizedBox.shrink()`: el `IndexedStack` construye TODOS sus hijos, así que
  /// dejar una pantalla real en una ranura inalcanzable la monta igual y
  /// dispara sus consultas para nada.
  List<Widget> get _screens => [
    // 0 · Inicio
    _accountType == 'empresa' ? _companyTalentFeed : _homeFeed,
    // 1 · Empresa: Pipeline · Headhunter: ATS · Candidato: Vacantes
    _accountType == 'empresa'
        ? const EmpresaPipelineScreen()
        : (_accountType == 'headhunter' ? _atsDashboard : const JobsScreen()),
    // 2 · Empresa: Mapa · Headhunter: Explorar · Candidato: Red
    _accountType == 'empresa'
        ? const EmpresaMapaScreen()
        : (_accountType == 'headhunter' ? _explore : _network),
    // 3 · Actividad / Notificaciones. Candidato llega desde Inicio, no por barra.
    _accountType == 'empresa'
        ? const EmpresaActividadScreen()
        : _notifications,
    // FASE DE CIERRE DE LEGACY — la ranura 4 es "Perfil". Para Empresa abre su
    // ficha institucional; `ProfileScreen` es el perfil personal del rol
    // candidato y no corresponde acá. Para los demás roles queda vacía: el
    // perfil personal vive en la ranura 9 y montarlo dos veces duplicaba
    // consultas sin que se pudiera llegar a esta copia.
    _accountType == 'empresa' ? const EmpresaPerfilScreen() : const SizedBox.shrink(),
    // 5 · Mensajes
    _accountType == 'empresa'
        ? const EmpresaMensajesScreen()
        : _messages,
    // 6 · Empresa: Vacantes · Headhunter: Búsquedas · Candidato: vacía, porque
    //     sus Vacantes pasaron a la ranura 1 y montar `JobsScreen` dos veces
    //     dispararía dos veces la carga de vacantes.
    _accountType == 'empresa'
        ? _companyVacantes
        : (_accountType == 'headhunter'
              ? const JobsScreen()
              : const SizedBox.shrink()),
    // 7 · Empresa: Dashboard · Headhunter: hub · Candidato: vacía (era una
    //     pantalla de Empresa en la ranura de un candidato).
    _accountType == 'empresa'
        ? _companyDashboard
        : (_accountType == 'headhunter'
              ? const EmpresaPanelHubScreen()
              : const SizedBox.shrink()),
    // 8 · Herramientas. Candidato: vacía por ahora; su acceso será un push desde
    //     Perfil en el paso siguiente del bloque.
    _accountType == 'empresa'
        ? EmpresaHerramientasScreen(
            unreadNotifications: _unreadNotifications,
          )
        : (_accountType == 'headhunter' ? _tools : const SizedBox.shrink()),
    // 9 · Perfil personal
    _profile,
  ];

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

  int _defaultIndexForAccount(String accountType) {
    switch (accountType) {
      case 'empresa':
      case 'headhunter':
        return 7;
      default:
        return 0;
    }
  }

  bool _isIndexAllowedForAccount(String accountType, int index) {
    switch (accountType) {
      case 'empresa':
        return const {0, 1, 2, 3, 4, 5, 6, 7, 8}.contains(index);
      case 'headhunter':
        return const {0, 1, 2, 3, 5, 6, 7, 8}.contains(index);
      default:
        // Candidato: exactamente los cinco destinos que publica su barra.
        // Antes declaraba {0,1,2,3,5,6,8,9} —ocho— mientras la barra sólo
        // mostraba cuatro, así que había ranuras "permitidas" inalcanzables.
        return const {0, 1, 2, 5, 9}.contains(index);
    }
  }

  void _applyAccountType(String newType) {
    final nextIndex = _isIndexAllowedForAccount(newType, _currentIndex)
        ? _currentIndex
        : _defaultIndexForAccount(newType);
    if (!mounted) return;
    setState(() {
      _accountType = newType;
      _currentIndex = nextIndex;
      currentMainTabNotifier.value = nextIndex;
    });
  }

  Future<void> _fetchAccountType() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('mploya_account_type');
      if (cached != null &&
          (cached != _accountType ||
              !_isIndexAllowedForAccount(cached, _currentIndex))) {
        _applyAccountType(cached);
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

      if (mounted &&
          (newType != _accountType ||
              !_isIndexAllowedForAccount(newType, _currentIndex))) {
        _applyAccountType(newType);
      }
    } catch (e) {
      debugPrint('fetchAccountType failed: $e');
      if (mounted && _fetchAccountTypeRetries < 3) {
        _fetchAccountTypeRetries++;
        Future.delayed(
          Duration(seconds: 3 * _fetchAccountTypeRetries),
          _fetchAccountType,
        );
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
        .listen((rows) {
          if (!mounted) return;
          setState(() {
            _unreadNotifications = rows
                .where((r) => r['is_read'] == false)
                .length;
          });
        }, onError: (e) => debugPrint('notifications stream error: $e'));

    _connSub = Supabase.instance.client
        .from('connections')
        .stream(primaryKey: ['id'])
        .eq('addressee_id', uid)
        .listen((rows) {
          if (!mounted) return;
          setState(() {
            _pendingConnections = rows
                .where((r) => r['status'] == 'pending')
                .length;
          });
        }, onError: (e) => debugPrint('connections stream error: $e'));

    _msgSub = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .listen((rows) {
          if (!mounted) return;
          setState(() {
            _unreadMessages = rows
                .where((r) => r['receiver_id'] == uid && r['is_read'] == false)
                .length;
          });
        }, onError: (e) => debugPrint('messages stream error: $e'));
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _connSub?.cancel();
    _msgSub?.cancel();
    super.dispose();
  }

  void _onTabTap(int index) {
    // BLINDAJE. Las ranuras que un rol no expone montan `SizedBox.shrink()`,
    // así que aterrizar en una sería una pantalla en blanco sin forma de
    // volver. Hoy todos los llamadores están gateados por rol, pero eso es una
    // garantía del llamador, no de esta función: un acceso nuevo, un deep link
    // o un estado restaurado alcanzarían para romperlo. La regla vive acá.
    if (!_isIndexAllowedForAccount(_accountType, index)) return;
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

  Future<void> _toggleDemoRole() async {
    final newType = _accountType == 'empresa' ? 'candidato' : 'empresa';
    _applyAccountType(newType);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mploya_account_type', newType);
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        await Supabase.instance.client
            .from('users')
            .update({'account_type': newType})
            .eq('id', uid);
      }
    } catch (_) {}
  }

  Future<void> _openPrimaryAction() async {
    if (!mounted) return;
    final navigator = Navigator.of(context);

    if (_accountType == 'empresa') {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (sheetContext) => CupertinoActionSheet(
          title: const Text('Accesos Empresa'),
          message: const Text(
            'Elegí el módulo que querés abrir dentro de la experiencia Empresa.',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _onTabTap(7);
              },
              child: const Text('Dashboard'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _onTabTap(0);
              },
              child: const Text('Feed talento'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                navigator.push(
                  CupertinoPageRoute(
                    builder: (_) => const EmpresaPublicarVacanteScreen(),
                  ),
                );
              },
              child: const Text('Publicar vacante'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _onTabTap(6);
              },
              child: const Text('Vacantes'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _onTabTap(1);
              },
              child: const Text('Pipeline'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _onTabTap(5);
              },
              child: const Text('Mensajes'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _onTabTap(2);
              },
              child: const Text('Mapa'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _onTabTap(3);
              },
              child: const Text('Alertas'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _onTabTap(4);
              },
              child: const Text('Perfil empresa'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _onTabTap(8);
              },
              child: const Text('Herramientas'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('Cancelar'),
          ),
        ),
      );
      return;
    }

    if (_accountType == 'headhunter') {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (sheetContext) => CupertinoActionSheet(
          title: const Text('Acción rápida'),
          message: const Text(
            'La navegación principal ya está reservada para Dashboard, Clientes, Búsquedas y Talent Pool.',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                navigator.push(
                  CupertinoPageRoute(
                    builder: (_) => const NuevaVacanteScreen(),
                  ),
                );
              },
              child: const Text('Nueva búsqueda'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _onTabTap(5);
              },
              child: const Text('Abrir mensajes'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('Cancelar'),
          ),
        ),
      );
      return;
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Crear'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              navigator.push(
                CupertinoPageRoute(builder: (_) => const PostComposerScreen()),
              );
            },
            child: const Text('Crear publicación'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              navigator.push(
                CupertinoPageRoute(builder: (_) => const CreateStoryScreen()),
              );
            },
            child: const Text('Subir historia'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              navigator.push(
                CupertinoPageRoute(
                  builder: (_) => const OnboardingPitchScreen(isCompany: false),
                ),
              );
            },
            child: const Text('Actualizar video pitch'),
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
    final width = MediaQuery.of(context).size.width;
    final isDesktopShell = kIsWeb && width >= 980;
    final navItems = _navItemsForAccount(_accountType);

    // TANDA 1 — Empresa usa el shell del sistema de diseño (barra inferior con
    // FAB central en móvil, barra lateral oscura en ancho). Los demás roles
    // siguen con el shell anterior hasta su propia tanda.
    if (_accountType == 'empresa') {
      return EmpresaShell(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        onPrimaryAction: _openPrimaryAction,
        unreadMessages: _unreadMessages,
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: _screens),
            ),
          ],
        ),
      );
    }

    if (isDesktopShell) {
      return _DesktopShell(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        onPrimaryAction: _openPrimaryAction,
        screens: _screens,
        accountType: _accountType,
        navItems: navItems,
        unreadNotifications: _unreadNotifications,
        pendingConnections: _pendingConnections,
        unreadMessages: _unreadMessages,
        onToggleRole: _supportsRoleToggle(_accountType)
            ? _toggleDemoRole
            : null,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(gradient: context.shellGradient),
      child: Column(
        children: [
          const SafeArea(bottom: false, child: OfflineBanner()),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(index: _currentIndex, children: _screens),
                if (_supportsRoleToggle(_accountType))
                  Positioned(
                    top: 14,
                    right: 14,
                    child: SafeArea(
                      bottom: false,
                      child: _CompactRoleToggleButton(
                        label: _roleToggleLabel(_accountType),
                        onTap: _toggleDemoRole,
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: SafeArea(
                    top: false,
                    child: _MobileNavigationBar(
                      items: navItems,
                      currentIndex: _currentIndex,
                      onTap: _onTabTap,
                      onPrimaryAction: _openPrimaryAction,
                      accountType: _accountType,
                    ),
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

List<_NavItemData> _navItemsForAccount(String accountType) {
  final isCompany = accountType == 'empresa';
  final isHeadhunter = accountType == 'headhunter';

  if (isCompany) {
    return const [
      _NavItemData(
        index: 7,
        label: 'Dashboard',
        shortLabel: 'Inicio',
        icon: CupertinoIcons.square_grid_2x2_fill,
        inactiveIcon: CupertinoIcons.square_grid_2x2,
      ),
      _NavItemData(
        index: 0,
        label: 'Feed talento',
        shortLabel: 'Talento',
        icon: CupertinoIcons.play_rectangle_fill,
        inactiveIcon: CupertinoIcons.play_rectangle,
      ),
      _NavItemData(
        index: 6,
        label: 'Vacantes',
        shortLabel: 'Vacantes',
        icon: CupertinoIcons.briefcase_fill,
        inactiveIcon: CupertinoIcons.briefcase,
      ),
      _NavItemData(
        index: 5,
        label: 'Mensajes',
        shortLabel: 'Inbox',
        icon: CupertinoIcons.chat_bubble_2_fill,
        inactiveIcon: CupertinoIcons.chat_bubble_2,
      ),
      _NavItemData(
        index: 8,
        label: 'Herramientas',
        shortLabel: 'Tools',
        icon: CupertinoIcons.square_grid_2x2_fill,
        inactiveIcon: CupertinoIcons.square_grid_2x2,
      ),
      _NavItemData(
        index: 4,
        label: 'Perfil empresa',
        shortLabel: 'Perfil',
        icon: CupertinoIcons.building_2_fill,
        inactiveIcon: CupertinoIcons.building_2_fill,
      ),
      _NavItemData(
        index: 6,
        label: 'Vacantes',
        shortLabel: 'Vacantes',
        icon: CupertinoIcons.briefcase_fill,
        inactiveIcon: CupertinoIcons.briefcase,
      ),
      _NavItemData(
        index: 1,
        label: 'Pipeline',
        shortLabel: 'Pipeline',
        icon: CupertinoIcons.person_3_fill,
        inactiveIcon: CupertinoIcons.person_3,
      ),
      _NavItemData(
        index: 2,
        label: 'Mapa',
        shortLabel: 'Mapa',
        icon: CupertinoIcons.map_fill,
        inactiveIcon: CupertinoIcons.map,
      ),
      _NavItemData(
        index: 3,
        label: 'Alertas',
        shortLabel: 'Alertas',
        icon: CupertinoIcons.bell_fill,
        inactiveIcon: CupertinoIcons.bell,
      ),
    ];
  }

  if (isHeadhunter) {
    return const [
      _NavItemData(
        index: 7,
        label: 'Dashboard',
        shortLabel: 'Dashboard',
        icon: CupertinoIcons.square_grid_2x2_fill,
        inactiveIcon: CupertinoIcons.square_grid_2x2,
      ),
      _NavItemData(
        index: 1,
        label: 'Clientes',
        shortLabel: 'Clientes',
        icon: CupertinoIcons.building_2_fill,
        inactiveIcon: CupertinoIcons.building_2_fill,
      ),
      _NavItemData(
        index: 6,
        label: 'Busquedas',
        shortLabel: 'Busquedas',
        icon: CupertinoIcons.briefcase_fill,
        inactiveIcon: CupertinoIcons.briefcase,
      ),
      _NavItemData(
        index: 2,
        label: 'Talent Pool',
        shortLabel: 'Talent Pool',
        icon: CupertinoIcons.person_3_fill,
        inactiveIcon: CupertinoIcons.person_3,
      ),
    ];
  }

  // CANDIDATO — navegación canónica de cinco destinos. Los índices son los del
  // array `_screens` compartido y no deben renumerarse.
  return const [
    _NavItemData(
      index: 0,
      label: 'Inicio',
      shortLabel: 'Inicio',
      icon: CupertinoIcons.house_fill,
      inactiveIcon: CupertinoIcons.house,
    ),
    _NavItemData(
      index: 1,
      label: 'Vacantes',
      shortLabel: 'Vacantes',
      icon: CupertinoIcons.briefcase_fill,
      inactiveIcon: CupertinoIcons.briefcase,
    ),
    _NavItemData(
      index: 2,
      label: 'Red',
      shortLabel: 'Red',
      icon: CupertinoIcons.person_2_fill,
      inactiveIcon: CupertinoIcons.person_2,
    ),
    _NavItemData(
      index: 5,
      label: 'Mensajes',
      shortLabel: 'Inbox',
      icon: CupertinoIcons.chat_bubble_2_fill,
      inactiveIcon: CupertinoIcons.chat_bubble_2,
    ),
    _NavItemData(
      index: 9,
      label: 'Perfil',
      shortLabel: 'Perfil',
      icon: CupertinoIcons.person_fill,
      inactiveIcon: CupertinoIcons.person,
    ),
  ];
}

String _roleLabel(String accountType) {
  switch (accountType) {
    case 'empresa':
      return 'Empresa';
    case 'headhunter':
      return 'Headhunter';
    case 'confidencial':
      return 'Confidencial';
    default:
      return 'Talento';
  }
}

bool _supportsRoleToggle(String accountType) =>
    accountType == 'empresa' || accountType == 'candidato';

String _profileShortcutLabelForAccount(String accountType) {
  switch (accountType) {
    case 'empresa':
      return 'Perfil';
    case 'headhunter':
      return 'Dashboard';
    default:
      return 'Perfil';
  }
}

int _profileShortcutIndexForAccount(String accountType) {
  switch (accountType) {
    case 'empresa':
      return 4;
    case 'headhunter':
      return 7;
    default:
      return 9;
  }
}

String _roleToggleLabel(String accountType) {
  switch (accountType) {
    case 'empresa':
      return 'Cambiar a Talento';
    default:
      return 'Cambiar a Empresa';
  }
}

String _screenTitle(String accountType, int currentIndex) {
  final items = _navItemsForAccount(accountType);
  for (final item in items) {
    if (item.index == currentIndex) return item.label;
  }
  return 'Mploya';
}

String _screenSubtitle(String accountType, int currentIndex) {
  final isCompany = accountType == 'empresa';
  final isHeadhunter = accountType == 'headhunter';
  switch (currentIndex) {
    case 0:
      return isCompany || isHeadhunter
          ? isCompany
                ? 'Video pitch, match por vacante y descubrimiento recruiter.'
                : 'Contenido, video y señales en tiempo real.'
          : 'Tu experiencia video-first para descubrir oportunidades.';
    case 1:
      return isCompany
          ? 'Pipeline, candidatos asociados y avance real por vacante.'
          : 'Exploracion y descubrimiento sobre datos reales.';
    case 2:
      return isCompany
          ? 'Mapa y descubrimiento geolocalizado de talento disponible.'
          : isHeadhunter
          ? 'Pool y descubrimiento para tus busquedas activas.'
          : 'Compatibilidades, conexiones y recomendaciones.';
    case 3:
      return 'Actividad, eventos y seguimiento de la plataforma.';
    case 4:
      return isCompany
          ? 'Marca empleadora, cultura y video pitch de tu empresa.'
          : 'Tu presencia profesional y configuracion visual.';
    case 9:
      return 'Tu presencia profesional y configuracion visual.';
    case 5:
      return 'Conversaciones, matches e interacciones activas.';
    case 6:
      return isCompany
          ? 'Vacantes, candidatos asociados y gestion del proceso.'
          : isHeadhunter
          ? 'Busquedas, oportunidades y posiciones activas.'
          : 'Vacantes y publicaciones de hiring.';
    case 7:
      return isHeadhunter
          ? 'Operacion, clientes y progreso comercial.'
          : 'Dashboard de recruiting con KPIs, pipeline y match contextual.';
    case 8:
      return isCompany
          ? 'IA, productividad y accesos de soporte para reclutamiento.'
          : 'Plataforma conectada a datos reales.';
    default:
      return 'Plataforma conectada a datos reales.';
  }
}

class _DesktopShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Future<void> Function() onPrimaryAction;
  final List<Widget> screens;
  final String accountType;
  final List<_NavItemData> navItems;
  final int unreadNotifications;
  final int pendingConnections;
  final int unreadMessages;
  final Future<void> Function()? onToggleRole;

  const _DesktopShell({
    required this.currentIndex,
    required this.onTap,
    required this.onPrimaryAction,
    required this.screens,
    required this.accountType,
    required this.navItems,
    required this.unreadNotifications,
    required this.pendingConnections,
    required this.unreadMessages,
    this.onToggleRole,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final expandedRail = width >= 1280;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: context.shellGradient),
      child: Row(
        children: [
          _DesktopRail(
            accountType: accountType,
            navItems: navItems,
            currentIndex: currentIndex,
            expanded: expandedRail,
            unreadNotifications: unreadNotifications,
            unreadMessages: unreadMessages,
            pendingConnections: pendingConnections,
            onTap: onTap,
            onPrimaryAction: onPrimaryAction,
            onToggleRole: onToggleRole,
          ),
          Expanded(
            child: Column(
              children: [
                const OfflineBanner(),
                _DesktopTopBar(
                  title: _screenTitle(accountType, currentIndex),
                  subtitle: _screenSubtitle(accountType, currentIndex),
                  accountType: accountType,
                  onTap: onTap,
                  unreadNotifications: unreadNotifications,
                  unreadMessages: unreadMessages,
                  pendingConnections: pendingConnections,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                    child: _DesktopContentViewport(
                      currentIndex: currentIndex,
                      screens: screens,
                    ),
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

class _DesktopRail extends StatelessWidget {
  final String accountType;
  final List<_NavItemData> navItems;
  final int currentIndex;
  final bool expanded;
  final int unreadNotifications;
  final int unreadMessages;
  final int pendingConnections;
  final ValueChanged<int> onTap;
  final Future<void> Function() onPrimaryAction;
  final Future<void> Function()? onToggleRole;

  const _DesktopRail({
    required this.accountType,
    required this.navItems,
    required this.currentIndex,
    required this.expanded,
    required this.unreadNotifications,
    required this.unreadMessages,
    required this.pendingConnections,
    required this.onTap,
    required this.onPrimaryAction,
    this.onToggleRole,
  });

  @override
  Widget build(BuildContext context) {
    final width = expanded ? 296.0 : 96.0;
    final label = _roleLabel(accountType);

    return Container(
      width: width,
      margin: const EdgeInsets.fromLTRB(18, 18, 0, 18),
      decoration: BoxDecoration(
        color: NexTheme.shellDark,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: NexTheme.shellStrokeDark),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3B000000),
            blurRadius: 34,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              expanded ? 22 : 16,
              22,
              expanded ? 22 : 16,
              18,
            ),
            child: Column(
              crossAxisAlignment: expanded
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: NexTheme.accentGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: NexTheme.brandOrange.withValues(alpha: 0.32),
                        blurRadius: 20,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'm',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                      ),
                    ),
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Mploya',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.9,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$label · FINAL shell',
                    style: const TextStyle(
                      color: Color(0xFFB3BCD7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  MployaGlassPanel(
                    radius: 22,
                    padding: const EdgeInsets.all(14),
                    color: Colors.white.withValues(alpha: 0.08),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MployaPill(
                          label: label,
                          icon: _roleIcon(accountType),
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Shell base listo para soportar el rediseño completo de FINAL_SCREENS.',
                          style: TextStyle(
                            color: Color(0xFFD6DCF0),
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: [
                for (final item in navItems)
                  _DesktopRailItem(
                    item: item,
                    expanded: expanded,
                    isActive: currentIndex == item.index,
                    badgeCount: _badgeCountFor(
                      item.index,
                      unreadNotifications: unreadNotifications,
                      unreadMessages: unreadMessages,
                      pendingConnections: pendingConnections,
                    ),
                    onTap: () => onTap(item.index),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                  child: MployaPrimaryButton(
                    label: _primaryActionLabel(accountType),
                    icon: CupertinoIcons.add,
                    compact: true,
                    onPressed: () => onPrimaryAction(),
                  ),
                ),
              ],
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MployaShellCard(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderColor: Colors.white.withValues(alpha: 0.10),
                          radius: 22,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Realtime',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '$unreadMessages mensajes · $unreadNotifications alertas',
                                style: const TextStyle(
                                  color: Color(0xFFB5BEDA),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  MployaSecondaryButton(
                    label: _profileShortcutLabelForAccount(accountType),
                    icon: CupertinoIcons.person_crop_circle,
                    onPressed: () =>
                        onTap(_profileShortcutIndexForAccount(accountType)),
                  ),
                  if (onToggleRole != null &&
                      _supportsRoleToggle(accountType)) ...[
                    const SizedBox(height: 12),
                    MployaPrimaryButton(
                      label: _roleToggleLabel(accountType),
                      icon: CupertinoIcons.arrow_2_circlepath,
                      compact: true,
                      onPressed: () => onToggleRole!(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final String accountType;
  final ValueChanged<int> onTap;
  final int unreadNotifications;
  final int unreadMessages;
  final int pendingConnections;

  const _DesktopTopBar({
    required this.title,
    required this.subtitle,
    required this.accountType,
    required this.onTap,
    required this.unreadNotifications,
    required this.unreadMessages,
    required this.pendingConnections,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Row(
        children: [
          Expanded(
            child: MployaShellCard(
              radius: 28,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.end,
                    children: [
                      MployaPill(
                        label: _roleLabel(accountType),
                        icon: _roleIcon(accountType),
                        active: true,
                      ),
                      MployaPill(
                        label: '$pendingConnections Match IA',
                        icon: CupertinoIcons.sparkles,
                        color: NexTheme.aiAccent,
                      ),
                      _UtilityCounter(
                        icon: CupertinoIcons.chat_bubble_2_fill,
                        count: unreadMessages,
                        onTap: () => onTap(5),
                      ),
                      _UtilityCounter(
                        icon: CupertinoIcons.bell_fill,
                        count: unreadNotifications,
                        onTap: () => onTap(3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopContentViewport extends StatelessWidget {
  final int currentIndex;
  final List<Widget> screens;

  const _DesktopContentViewport({
    required this.currentIndex,
    required this.screens,
  });

  @override
  Widget build(BuildContext context) {
    final allowFullBleed =
        currentIndex == 0 || screens[currentIndex] is ExploreScreen;

    if (allowFullBleed) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: IndexedStack(index: currentIndex, children: screens),
      );
    }

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(32)),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: IndexedStack(index: currentIndex, children: screens),
        ),
      ),
    );
  }
}

class _DesktopRailItem extends StatefulWidget {
  final _NavItemData item;
  final bool expanded;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  const _DesktopRailItem({
    required this.item,
    required this.expanded,
    required this.isActive,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  State<_DesktopRailItem> createState() => _DesktopRailItemState();
}

class _DesktopRailItemState extends State<_DesktopRailItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final activeBg = Colors.white.withValues(alpha: 0.10);
    final hoverBg = Colors.white.withValues(alpha: 0.05);
    final activeColor = Colors.white;
    final inactiveColor = const Color(0xFFB8C1DB);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          padding: EdgeInsets.symmetric(
            horizontal: widget.expanded ? 14 : 0,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? activeBg
                : _hovering
                ? hoverBg
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: widget.isActive
                ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                : null,
          ),
          child: widget.expanded
              ? Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          widget.isActive
                              ? widget.item.icon
                              : widget.item.inactiveIcon,
                          color: widget.isActive ? activeColor : inactiveColor,
                          size: 22,
                        ),
                        if (widget.badgeCount > 0)
                          Positioned(
                            right: -8,
                            top: -6,
                            child: _ShellBadge(count: widget.badgeCount),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.item.label,
                        style: TextStyle(
                          color: widget.isActive ? activeColor : inactiveColor,
                          fontWeight: widget.isActive
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        widget.isActive
                            ? widget.item.icon
                            : widget.item.inactiveIcon,
                        color: widget.isActive ? activeColor : inactiveColor,
                        size: 22,
                      ),
                      if (widget.badgeCount > 0)
                        Positioned(
                          right: -8,
                          top: -6,
                          child: _ShellBadge(count: widget.badgeCount),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _MobileNavigationBar extends StatelessWidget {
  final List<_NavItemData> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Future<void> Function() onPrimaryAction;
  final String accountType;

  const _MobileNavigationBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.onPrimaryAction,
    required this.accountType,
  });

  @override
  Widget build(BuildContext context) {
    final leftItems = items.take(2).toList();
    final rightItems = items.skip(2).take(2).toList();
    return MployaGlassPanel(
      radius: 28,
      blur: 24,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        children: [
          for (final item in leftItems)
            Expanded(
              child: _MobileNavItem(
                item: item,
                isActive: currentIndex == item.index,
                onTap: () => onTap(item.index),
              ),
            ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onPrimaryAction(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: context.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: context.primaryAccent.withValues(alpha: 0.28),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.add,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _mobilePrimaryActionShortLabel(accountType),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final item in rightItems)
            Expanded(
              child: _MobileNavItem(
                item: item,
                isActive: currentIndex == item.index,
                onTap: () => onTap(item.index),
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final _NavItemData item;
  final bool isActive;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: isActive ? context.primaryGradient : null,
              color: isActive ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: context.primaryAccent.withValues(alpha: 0.26),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isActive ? item.icon : item.inactiveIcon,
              size: 22,
              color: isActive ? Colors.white : context.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.shortLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isActive ? context.primaryAccent : context.textTertiary,
              fontSize: 10.5,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilityCounter extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback? onTap;

  const _UtilityCounter({required this.icon, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: context.shellBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: context.textPrimary),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactRoleToggleButton extends StatelessWidget {
  final String label;
  final Future<void> Function() onTap;

  const _CompactRoleToggleButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(),
      child: MployaGlassPanel(
        radius: 999,
        blur: 20,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.arrow_2_circlepath,
              size: 15,
              color: context.primaryAccent,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellBadge extends StatelessWidget {
  final int count;

  const _ShellBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: NexTheme.accentGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NavItemData {
  final int index;
  final String label;
  final String shortLabel;
  final IconData icon;
  final IconData inactiveIcon;

  const _NavItemData({
    required this.index,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.inactiveIcon,
  });
}

int _badgeCountFor(
  int index, {
  required int unreadNotifications,
  required int unreadMessages,
  required int pendingConnections,
}) {
  switch (index) {
    case 2:
      return pendingConnections;
    case 3:
      return unreadNotifications;
    case 5:
      return unreadMessages;
    default:
      return 0;
  }
}

IconData _roleIcon(String accountType) {
  switch (accountType) {
    case 'empresa':
      return CupertinoIcons.building_2_fill;
    case 'headhunter':
      return CupertinoIcons.person_2_square_stack_fill;
    case 'confidencial':
      return CupertinoIcons.eye_slash_fill;
    default:
      return CupertinoIcons.person_crop_circle_fill;
  }
}

String _primaryActionLabel(String accountType) {
  switch (accountType) {
    case 'empresa':
      return 'Accesos Empresa';
    case 'headhunter':
      return 'Nueva búsqueda';
    default:
      return 'Crear';
  }
}

String _mobilePrimaryActionShortLabel(String accountType) {
  switch (accountType) {
    case 'empresa':
      return 'Accesos';
    case 'headhunter':
      return 'Nuevo';
    default:
      return 'Crear';
  }
}
