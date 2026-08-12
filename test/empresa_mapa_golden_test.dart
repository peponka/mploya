import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_mapa_screen.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

/// Golden del Mapa de Empresa, derivado de `mapa de candidatos 2.png`.
///
/// En un widget test no hay iframe ni mapa nativo: el recuadro del mapa sale
/// vacío. Lo que se valida acá es la CAPA DE INTERFAZ —encabezado, filtros,
/// controles y hoja de candidatos— y que no desborde en las cinco alturas.
///
///   flutter test test/empresa_mapa_golden_test.dart --update-goldens

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

/// Muestra con la FORMA de datos reales — sólo vive en este test.
const _conDatos = MapaData(
  candidatos: [
    CandidatoCercano(
      id: '1',
      nombre: 'Camila R.',
      headline: 'UX/UI Designer',
      lat: -34.60,
      lng: -58.38,
      tieneVideo: true,
      distanciaKm: 0.8,
    ),
    CandidatoCercano(
      id: '2',
      nombre: 'Martín L.',
      headline: 'Product Designer',
      lat: -34.59,
      lng: -58.40,
      tieneVideo: true,
      distanciaKm: 1.2,
    ),
    CandidatoCercano(
      id: '3',
      nombre: 'Solange V.',
      headline: 'Frontend Developer',
      lat: -34.61,
      lng: -58.37,
      distanciaKm: 2.1,
    ),
    CandidatoCercano(
      id: '4',
      nombre: 'Nicolás F.',
      headline: 'Data Analyst',
      lat: -34.62,
      lng: -58.42,
      distanciaKm: 34.0,
    ),
  ],
);

Widget _host(Size size, MapaData data) {
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
              Expanded(child: EmpresaMapaScreen(previewData: data)),
              MpBottomNav(
                items: MpRole.empresa.navItems(unreadMessages: 3),
                currentIndex: 1,
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

Future<void> _pump(WidgetTester tester, Size size, MapaData data) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(size, data));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('golden · mapa con candidatos', (tester) async {
    await _pump(tester, const Size(393, 852), _conDatos);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_mapa.png'),
    );
  });

  testWidgets('golden · mapa sin candidatos', (tester) async {
    await _pump(tester, const Size(393, 852), MapaData.empty);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_mapa_vacio.png'),
    );
  });

  testWidgets('golden · mapa en 424x852', (tester) async {
    await _pump(tester, const Size(424, 852), _conDatos);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_mapa_424.png'),
    );
  });

  // Las cinco medidas exigidas.
  for (final size in [
    Size(393, 852),
    Size(393, 667),
    Size(375, 667),
    Size(424, 651),
    Size(424, 852),
  ]) {
    testWidgets(
      'sin overflow en ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await _pump(tester, size, _conDatos);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'vacío sin overflow en ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await _pump(tester, size, MapaData.empty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('sin candidatos no se dibujan pines demo', (tester) async {
    await _pump(tester, const Size(393, 852), MapaData.empty);
    expect(find.text('Sin candidatos con ubicación'), findsWidgets);
    // La pantalla legacy inventa gente cuando la consulta vuelve vacía.
    for (final demo in ['Camila', 'Martín', 'Solange', 'Nicolás']) {
      expect(find.textContaining(demo), findsNothing, reason: demo);
    }
  });

  testWidgets('no se muestra Match IA sin vacante seleccionada',
      (tester) async {
    await _pump(tester, const Size(393, 852), _conDatos);
    expect(find.textContaining('Match'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('la distancia sale del dato real', (tester) async {
    await _pump(tester, const Size(393, 852), _conDatos);
    expect(find.text('a 800 m del centro'), findsOneWidget);
    expect(find.text('a 1.2 km del centro'), findsOneWidget);
  });

  testWidgets('la distancia NO se atribuye a la ubicación del usuario',
      (tester) async {
    await _pump(tester, const Size(393, 852), _conDatos);
    // El centro del mapa es un punto fijo, no la ubicación real de la empresa:
    // decir "de vos" era falso.
    expect(find.textContaining('de vos'), findsNothing);
  });

  // Test aparte y no un segundo pump: al reconstruir con el mismo tipo de
  // widget Flutter reutiliza el State y `initState` no vuelve a correr, así que
  // los datos viejos seguirían en pantalla.
  testWidgets('sin distancia real no se muestra ninguna', (tester) async {
    await _pump(
      tester,
      const Size(393, 852),
      const MapaData(
        candidatos: [
          CandidatoCercano(
            id: 'x',
            nombre: 'Sin distancia',
            headline: 'QA',
            lat: -34.6,
            lng: -58.4,
          ),
        ],
      ),
    );
    expect(find.text('Sin distancia'), findsOneWidget);
    expect(find.textContaining('del centro'), findsNothing);
  });

  testWidgets('el error de carga se distingue del vacío', (tester) async {
    await _pump(
      tester,
      const Size(393, 852),
      const MapaData(candidatos: [], error: true),
    );
    expect(find.text('No pudimos cargar el mapa'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
