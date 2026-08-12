import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_vacantes_data.dart';
import 'package:mploya/screens/empresa/empresa_vacantes_screen.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

/// Renderiza Vacantes Empresa para compararla con
/// `10_Headhunter_Busquedas_Activas.png` (referencia estructural autorizada).
///
///   flutter test test/empresa_vacantes_golden_test.dart --update-goldens

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

DateTime _hace(int dias) => DateTime.now().subtract(Duration(days: dias));

/// Muestra con la FORMA de datos reales — sólo vive en este test.
final _conEstados = VacantesData(
  soportaEstados: true,
  vacantes: [
    Vacante(
      id: '1',
      titulo: 'Desarrollador Full Stack',
      ubicacion: 'Asunción, PY',
      salario: 'USD 2.200 – 3.500',
      modalidad: 'Remoto',
      creada: _hace(2),
      estado: VacanteEstado.activa,
      candidatos: 8,
    ),
    Vacante(
      id: '2',
      titulo: 'Product Manager Senior',
      ubicacion: 'Buenos Aires, AR',
      salario: 'USD 3.000 – 4.500',
      modalidad: 'Híbrido',
      creada: _hace(5),
      estado: VacanteEstado.activa,
      candidatos: 12,
    ),
    Vacante(
      id: '3',
      titulo: 'Analista de Datos Senior',
      ubicacion: 'São Paulo, BR',
      modalidad: 'Remoto',
      creada: _hace(9),
      estado: VacanteEstado.activa,
      candidatos: 6,
    ),
    Vacante(
      id: '4',
      titulo: 'Especialista en Marketing Digital',
      ubicacion: 'Bogotá, CO',
      modalidad: 'Presencial',
      creada: _hace(12),
      estado: VacanteEstado.pausada,
      candidatos: 0,
    ),
    Vacante(
      id: '5',
      titulo: 'Ingeniero DevOps',
      ubicacion: 'Santiago, CL',
      salario: 'USD 2.800 – 4.000',
      modalidad: 'Remoto',
      creada: _hace(15),
      estado: VacanteEstado.activa,
      candidatos: 5,
      confidencial: true,
    ),
  ],
);

/// Caso real de hoy: la base no expone campo de estado.
final _sinEstados = VacantesData(
  soportaEstados: false,
  vacantes: [
    Vacante(
      id: '1',
      titulo: 'Desarrollador Full Stack',
      ubicacion: 'Asunción, PY',
      modalidad: 'Remoto',
      creada: _hace(2),
      estado: VacanteEstado.desconocido,
      candidatos: 3,
    ),
    Vacante(
      id: '2',
      titulo: 'Product Manager Senior',
      ubicacion: 'Buenos Aires, AR',
      creada: _hace(6),
      estado: VacanteEstado.desconocido,
      candidatos: 0,
    ),
  ],
);

Widget _host(Size size, VacantesData data) {
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
              Expanded(child: EmpresaVacantesScreen(previewData: data)),
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

Future<void> _pump(WidgetTester tester, Size size, VacantesData data) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(size, data));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('golden · vacantes con estados (393x852)', (tester) async {
    await _pump(tester, const Size(393, 1250), _conEstados);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_vacantes.png'),
    );
  });

  testWidgets('golden · vacantes sin campo de estado', (tester) async {
    await _pump(tester, const Size(393, 1000), _sinEstados);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_vacantes_sin_estados.png'),
    );
  });

  testWidgets('golden · vacantes vacío', (tester) async {
    await _pump(tester, const Size(393, 950), VacantesData.empty);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_vacantes_vacio.png'),
    );
  });

  testWidgets('golden · vacantes en 424px', (tester) async {
    await _pump(tester, const Size(424, 1250), _conEstados);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_vacantes_424.png'),
    );
  });

  // Barrido de anchos: nada debe desbordar.
  for (final width in [393.0, 400.0, 424.0, 430.0]) {
    testWidgets('sin overflow en ${width.toInt()}px', (tester) async {
      await _pump(tester, Size(width, 1250), _conEstados);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sin campo de estado no se inventan chips ni métricas',
      (tester) async {
    await _pump(tester, const Size(393, 1000), _sinEstados);
    // "Cerradas" no existe en el modelo: nunca debe aparecer.
    expect(find.text('Cerradas'), findsNothing);
    expect(find.text('Activas'), findsNothing);
    expect(find.text('Pausadas'), findsNothing);
    expect(find.text('Todas'), findsOneWidget);
  });

  testWidgets('con campo de estado sí aparecen Activas y Pausadas',
      (tester) async {
    await _pump(tester, const Size(393, 1250), _conEstados);
    expect(find.text('Cerradas'), findsNothing);
    expect(find.text('Activas'), findsWidgets);
    expect(find.text('Pausadas'), findsWidgets);
  });

  testWidgets('no aparece lenguaje de headhunter', (tester) async {
    await _pump(tester, const Size(393, 1250), _conEstados);
    for (final palabra in ['Cliente', 'Clientes', 'Búsqueda', 'Búsquedas']) {
      expect(find.textContaining(palabra), findsNothing, reason: palabra);
    }
    expect(find.text('Vacantes'), findsWidgets);
  });
}
