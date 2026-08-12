import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_actividad_screen.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

/// Golden de Actividad/Notificaciones Empresa contra
/// `actividad y notificaciones.png` (17).
///
///   flutter test test/empresa_actividad_golden_test.dart --update-goldens

Future<void> _loadFonts() async {
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

DateTime _hoy(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

DateTime _ayer(int h, int m) {
  final n = DateTime.now().subtract(const Duration(days: 1));
  return DateTime(n.year, n.month, n.day, h, m);
}

/// Muestra con la FORMA de datos reales — sólo vive en este test.
final _conDatos = ActividadData(
  items: [
    Actividad(
      id: '1',
      titulo: 'Recibiste una respuesta a tu mensaje',
      detalle: 'UX/UI Designer',
      tipo: ActividadTipo.candidatos,
      fecha: _hoy(10, 24),
    ),
    Actividad(
      id: '2',
      titulo: 'Se confirmó una entrevista',
      detalle: 'Product Designer',
      tipo: ActividadTipo.entrevistas,
      fecha: _hoy(9, 15),
    ),
    Actividad(
      id: '3',
      titulo: 'Tu vacante tuvo nuevas vistas',
      detalle: 'Publicada hace 2 días',
      tipo: ActividadTipo.vacantes,
      fecha: _hoy(8, 45),
      leida: true,
    ),
    Actividad(
      id: '4',
      titulo: 'Nuevos candidatos que hacen match',
      detalle: 'Basado en tus vacantes activas',
      tipo: ActividadTipo.candidatos,
      fecha: _ayer(18, 40),
      leida: true,
    ),
    Actividad(
      id: '5',
      titulo: 'Actualizamos la política de privacidad',
      tipo: ActividadTipo.sistema,
      fecha: _ayer(17, 30),
      leida: true,
    ),
  ],
);

Widget _host(Size size, ActividadData data) {
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
              Expanded(child: EmpresaActividadScreen(previewData: data)),
              MpBottomNav(
                items: MpRole.empresa.navItems(unreadMessages: 3),
                currentIndex: -1,
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

Future<void> _pump(WidgetTester tester, Size size, ActividadData data) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(size, data));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('golden · actividad con datos', (tester) async {
    await _pump(tester, const Size(393, 1000), _conDatos);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_actividad.png'),
    );
  });

  testWidgets('golden · actividad vacía', (tester) async {
    await _pump(tester, const Size(393, 900), ActividadData.empty);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_actividad_vacia.png'),
    );
  });

  testWidgets('golden · actividad en 424px', (tester) async {
    await _pump(tester, const Size(424, 1000), _conDatos);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_actividad_424.png'),
    );
  });

  for (final width in [393.0, 400.0, 424.0, 430.0]) {
    testWidgets('sin overflow en ${width.toInt()}px', (tester) async {
      await _pump(tester, Size(width, 1000), _conDatos);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no se copian las notificaciones del mockup', (tester) async {
    await _pump(tester, const Size(393, 1000), _conDatos);
    for (final falso in ['Camila Rodríguez', 'Juan Pérez', 'Fernando López',
        'Valentina Gómez', '245', '75%']) {
      expect(find.textContaining(falso), findsNothing, reason: falso);
    }
  });

  testWidgets('sin datos muestra estado vacío, no una lista falsa',
      (tester) async {
    await _pump(tester, const Size(393, 900), ActividadData.empty);
    expect(find.text('Sin actividad todavía'), findsOneWidget);
    expect(find.text('Hoy'), findsNothing);
  });

  testWidgets('el error de carga se distingue del vacío', (tester) async {
    await _pump(
      tester,
      const Size(393, 900),
      const ActividadData(items: [], error: true),
    );
    expect(find.text('No pudimos cargar tu actividad'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
