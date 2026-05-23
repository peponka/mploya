/// Widget raíz de la aplicación mploya.ai
///
/// Configura [MaterialApp.router] con el tema naranja/blanco,
/// router y ajustes globales de la interfaz.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mploya/config/routes.dart';
import 'package:mploya/config/theme.dart';

/// Custom scroll behavior that enables drag scrolling with mouse on web.
/// This makes PageView and other scrollables work with mouse drag,
/// just like touch scrolling on mobile (TikTok-style).
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

/// Widget raíz que envuelve toda la aplicación.
///
/// Debe ser envuelto por [ProviderScope] en `main.dart`:
/// ```dart
/// runApp(const ProviderScope(child: App()));
/// ```
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp.router(
      // ── Metadata ──
      title: 'mploya.ai',
      debugShowCheckedModeBanner: false,

      // ── Scroll (enables mouse drag on web) ──
      scrollBehavior: AppScrollBehavior(),

      // ── Tema ──
      theme: buildMployaTheme(),
      themeMode: ThemeMode.light,

      // ── Router ──
      routerConfig: router,
    );
  }
}
