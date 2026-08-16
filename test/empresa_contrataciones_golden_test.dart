import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_contrataciones_screen.dart';
import 'package:mploya/screens/empresa/empresa_proceso_data.dart';

import 'mp_golden_host.dart';

/// Golden de Contrataciones, derivado de `Headhunter_Colocaciones_Analytics.png`.
///
///   flutter test test/empresa_contrataciones_golden_test.dart --update-goldens

final _conDatos = ProcesoData(
  personas: [
    PersonaEnProceso(
      candidatoId: '1',
      nombre: 'María López',
      headline: 'Product Manager',
      vacante: 'Product Manager Senior',
      estado: 'hired',
      origen: 'job_applications',
      postuladoEl: DateTime(2026, 7, 20),
    ),
    // Viene del pipeline: NO tiene vacante asociada.
    const PersonaEnProceso(
      candidatoId: '2',
      nombre: 'Juan Martín',
      headline: 'Full Stack Dev',
      estado: 'hired',
      origen: 'connections',
    ),
  ],
);

Widget _pantalla(ProcesoData d, {String clave = 'contrataciones'}) =>
    EmpresaContratacionesScreen(key: ValueKey(clave), previewData: d);

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · con contrataciones', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_contrataciones.png'));
  });

  testWidgets('golden · sin contrataciones', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(ProcesoData.empty, clave: 'vacio'));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_contrataciones_vacio.png'));
  });

  for (final size in mpTamanos) {
    final n = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('sin overflow en $n', (tester) async {
      await pumpMp(tester, size, _pantalla(_conDatos, clave: 'a-$n'));
      expect(tester.takeException(), isNull);
    });
    testWidgets('vacío sin overflow en $n', (tester) async {
      await pumpMp(tester, size, _pantalla(ProcesoData.empty, clave: 'v-$n'));
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in const [Size(768, 1024), Size(1440, 900)]) {
    testWidgets('sin overflow en ${size.width.toInt()}px', (tester) async {
      await pumpMp(
        tester,
        size,
        _pantalla(_conDatos, clave: 'wide-${size.width}'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sin vacante registrada NO se inventa una', (tester) async {
    await pumpMp(tester, const Size(393, 1800), _pantalla(_conDatos));
    expect(find.text('Vacante no registrada'), findsOneWidget);
    expect(find.text('Sin vacante asociada'), findsOneWidget);
  });

  testWidgets('no se inventa onboarding ni datos de contrato', (tester) async {
    await pumpMp(tester, const Size(393, 1800), _pantalla(_conDatos));
    for (final inventado in [
      'Fecha de ingreso',
      'Onboarding',
      'Salario final',
      // "Manager" a secas daría falso positivo: es parte de titulares reales
      // como "Product Manager".
      'Reporta a',
      'Período de prueba',
      'Documentos',
    ]) {
      expect(find.textContaining(inventado), findsNothing, reason: inventado);
    }
  });

  testWidgets('la fecha mostrada es la de postulación', (tester) async {
    await pumpMp(tester, const Size(393, 1800), _pantalla(_conDatos));
    expect(find.textContaining('Postulado'), findsWidgets);
  });

  testWidgets('el error se distingue del vacío', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(const ProcesoData(personas: [], error: true), clave: 'err'));
    expect(find.text('No pudimos cargar las contrataciones'), findsOneWidget);
  });
}
