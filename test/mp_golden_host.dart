import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

/// Andamiaje compartido por los golden de la tanda de Empresa móvil.
///
/// Los test anteriores repetían este mismo cargador de fuentes en cada archivo;
/// los nuevos lo importan de acá. No se tocaron los viejos a propósito: mover
/// su código sería tocar pantallas ya aprobadas sin necesidad.

/// Carga Roboto y CupertinoIcons para que los golden no salgan con cajas.
Future<void> loadMpFonts() async {
  final sdkFonts = Directory(
    '${Directory.current.path}/.flutter-sdk/bin/cache/artifacts/material_fonts',
  );
  if (sdkFonts.existsSync()) {
    final roboto = File('${sdkFonts.path}/roboto-regular.ttf');
    if (roboto.existsSync()) {
      final bytes = roboto.readAsBytesSync().buffer.asByteData();
      for (final family in [
        'Roboto',
        '.SF Pro Text',
        '.SF Pro Display',
        'CupertinoSystemText',
        'CupertinoSystemDisplay',
      ]) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
    }
  }

  final iconFont = File(
    '${Platform.environment['LOCALAPPDATA']}'
    r'\Pub\Cache\hosted\pub.dev\cupertino_icons-1.0.8\assets\CupertinoIcons.ttf',
  );
  if (iconFont.existsSync()) {
    final bytes = iconFont.readAsBytesSync().buffer.asByteData();
    for (final family in [
      'CupertinoIcons',
      'packages/cupertino_icons/CupertinoIcons',
    ]) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
  }
}

/// Envuelve una pantalla en su superficie y, opcionalmente, en la barra
/// inferior de Empresa — igual que la ve el usuario dentro del shell.
Widget mpHost(
  Size size,
  Widget screen, {
  MpSurfaceStyle? style,
  bool bottomNav = false,
}) {
  final surface = style ?? MpSurfaceStyle.light;

  return CupertinoApp(
    debugShowCheckedModeBanner: false,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: MpSurface(
        style: surface,
        child: CupertinoPageScaffold(
          backgroundColor: surface.bg,
          child: bottomNav
              ? Column(
                  children: [
                    Expanded(child: screen),
                    MpBottomNav(
                      items: MpRole.empresa.navItems(unreadMessages: 3),
                      currentIndex: -1,
                      onTap: (_) {},
                      onCenterTap: () {},
                      centerLabel: MpRole.empresa.centerLabel,
                    ),
                  ],
                )
              : screen,
        ),
      ),
    ),
  );
}

/// Monta la pantalla al tamaño pedido y deja asentar las animaciones.
Future<void> pumpMp(
  WidgetTester tester,
  Size size,
  Widget screen, {
  MpSurfaceStyle? style,
  bool bottomNav = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    mpHost(size, screen, style: style, bottomNav: bottomNav),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

/// Los seis tamaños que la tanda debe soportar sin overflow.
const mpTamanos = <Size>[
  Size(393, 852),
  Size(393, 667),
  Size(375, 667),
  Size(400, 800),
  Size(424, 651),
  Size(424, 852),
];
