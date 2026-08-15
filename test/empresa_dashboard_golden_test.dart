import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_dashboard_data.dart';
import 'package:mploya/screens/empresa/empresa_dashboard_screen.dart';
import 'package:mploya/screens/empresa/empresa_shell.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

/// Renderiza el Dashboard de Empresa a PNG para compararlo lado a lado con
/// `dashboard empresa.png`.
///
/// Existe porque la pantalla vive detrás del login: sin esto no hay forma de
/// mirarla sin credenciales. Se ejecuta con:
///
///   flutter test test/empresa_dashboard_golden_test.dart --update-goldens
///
/// Los datos son de MUESTRA y sólo viven en este test — la app nunca los usa.
/// Sirven para verificar la COMPOSICIÓN, no para inventar métricas.

/// Carga Roboto desde el SDK; sin una fuente real el golden sale con cajas.
Future<void> _loadFonts() async {
  final sdkFonts = Directory(
    '${Directory.current.path}/.flutter-sdk/bin/cache/artifacts/material_fonts',
  );
  if (!sdkFonts.existsSync()) return;

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var found = false;
    for (final file in files) {
      final f = File('${sdkFonts.path}/$file');
      if (!f.existsSync()) continue;
      found = true;
      loader.addFont(
        Future.value(f.readAsBytesSync().buffer.asByteData()),
      );
    }
    if (found) await loader.load();
  }

  // Los íconos: sin esta fuente el golden dibuja cuadraditos y no se puede
  // verificar la fidelidad de los íconos contra el PNG.
  final iconFont = File(
    '${Platform.environment['LOCALAPPDATA']}'
    r'\Pub\Cache\hosted\pub.dev\cupertino_icons-1.0.8\assets\CupertinoIcons.ttf',
  );
  if (iconFont.existsSync()) {
    final bytes = iconFont.readAsBytesSync().buffer.asByteData();
    // El IconData de Cupertino resuelve a la familia con prefijo de paquete;
    // registrarla sólo como "CupertinoIcons" no alcanza.
    for (final family in [
      'CupertinoIcons',
      'packages/cupertino_icons/CupertinoIcons',
    ]) {
      final loader = FontLoader(family)..addFont(Future.value(bytes));
      await loader.load();
    }
  }

  // La app usa las familias de sistema de Cupertino; se mapean a Roboto para
  // que el golden tenga texto legible.
  await load('Roboto', ['roboto-regular.ttf']);
  await load('.SF Pro Text', ['roboto-regular.ttf']);
  await load('.SF Pro Display', ['roboto-regular.ttf']);
  await load('.SF UI Text', ['roboto-regular.ttf']);
  await load('.SF UI Display', ['roboto-regular.ttf']);
  await load('CupertinoSystemText', ['roboto-regular.ttf']);
  await load('CupertinoSystemDisplay', ['roboto-regular.ttf']);
}

/// Datos de muestra con la forma que tendría una empresa activa.
final _sample = EmpresaDashboardData(
  companyName: 'Globant',
  vacantesActivas: 24,
  candidatosEnProceso: 156,
  entrevistasSemana: 18,
  contratacionesMes: 32,
  // El embudo SÍ tiene datos de muestra desde el 15/8/2026 — 4 etapas reales
  // (Postulados/Screening/Entrevistas/Oferta), la misma composición que arma
  // `loadEmpresaDashboard` con columnas reales. Los otros tres bloques
  // (fuentes, tiempo por etapa, evolución) siguen vacíos también acá: el
  // golden tiene que mostrar la composición REAL, no una versión más rica
  // que la que ve una empresa. Ver los comentarios en empresa_dashboard_data.
  funnel: const [
    EmpresaStage(label: 'Postulados', value: 210),
    EmpresaStage(label: 'Screening', value: 96),
    EmpresaStage(label: 'Entrevistas', value: 41),
    EmpresaStage(label: 'Oferta', value: 32),
  ],
  hiringTrend: const [],
  sources: const [],
  stageDays: const {},
);

Widget _host({
  required Size size,
  required EmpresaDashboardData data,
  bool withNav = true,
}) {
  return CupertinoApp(
    debugShowCheckedModeBanner: false,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: MpSurface(
        style: MpSurfaceStyle.light,
        child: CupertinoPageScaffold(
          backgroundColor: MpTokens.lightBg,
          child: Column(
            children: [
              Expanded(
                child: EmpresaDashboardScreen(
                  unreadNotifications: 3,
                  previewData: data,
                ),
              ),
              if (withNav)
                MpBottomNav(
                  items: MpRole.empresa.navItems(unreadMessages: 3),
                  currentIndex: 0,
                  onTap: (_) {},
                  onCenterTap: () {},
                  centerLabel: MpRole.empresa.centerLabel,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('golden · dashboard empresa móvil', (tester) async {
    // Alto generoso para capturar la página entera sin scroll.
    const size = Size(393, 1500);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(size: size, data: _sample));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_dashboard_mobile.png'),
    );
  });

  testWidgets('golden · dashboard empresa móvil sin datos', (tester) async {
    const size = Size(393, 1400);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(size: size, data: EmpresaDashboardData.empty),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_dashboard_mobile_vacio.png'),
    );
  });

  testWidgets('golden · dashboard empresa escritorio', (tester) async {
    // Con el shell real: barra lateral oscura + contenido.
    const size = Size(1280, 1180);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: const MediaQueryData(size: size),
          child: EmpresaShell(
            currentIndex: 7,
            onTap: (_) {},
            onPrimaryAction: () {},
            unreadMessages: 3,
            companyName: 'Globant',
            body: EmpresaDashboardScreen(
              unreadNotifications: 3,
              previewData: _sample,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_dashboard_desktop.png'),
    );
  });
}
