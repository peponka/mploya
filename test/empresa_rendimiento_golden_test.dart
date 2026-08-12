import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_proceso_data.dart';
import 'package:mploya/screens/empresa/empresa_rendimiento_screen.dart';

import 'mp_golden_host.dart';

/// Golden de Rendimiento de vacantes, derivado del bloque "Vacantes con mejor
/// rendimiento" de `analytics de vacantes.png` (24).
///
///   flutter test test/empresa_rendimiento_golden_test.dart --update-goldens

const _conDatos = RendimientoData(
  vacantes: [
    RendimientoVacante(
      id: '1',
      titulo: 'Product Manager Senior',
      postulaciones: 9,
      entrevistas: 3,
      activa: true,
    ),
    RendimientoVacante(
      id: '2',
      titulo: 'Desarrollador Flutter',
      postulaciones: 4,
      entrevistas: 1,
      activa: true,
    ),
    RendimientoVacante(
      id: '3',
      titulo: 'Data Scientist',
      postulaciones: 0,
      entrevistas: 0,
      activa: false,
    ),
  ],
);

Widget _pantalla(RendimientoData d, {String clave = 'rendimiento'}) =>
    EmpresaRendimientoScreen(key: ValueKey(clave), previewData: d);

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · con vacantes', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_rendimiento.png'));
  });

  testWidgets('golden · sin vacantes', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(RendimientoData.empty, clave: 'vacio'));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_rendimiento_vacio.png'));
  });

  for (final size in mpTamanos) {
    final n = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('sin overflow en $n', (tester) async {
      await pumpMp(tester, size, _pantalla(_conDatos, clave: 'a-$n'));
      expect(tester.takeException(), isNull);
    });
    testWidgets('vacío sin overflow en $n', (tester) async {
      await pumpMp(
          tester, size, _pantalla(RendimientoData.empty, clave: 'v-$n'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('los totales se calculan, no se copian', (tester) async {
    expect(_conDatos.totalPostulaciones, 13);
    expect(_conDatos.totalEntrevistas, 4);
    expect(_conDatos.activas, 2);
    expect(_conDatos.maxPostulaciones, 9);
    expect(_conDatos.sinPostulaciones.length, 1);
  });

  testWidgets('avisa de las vacantes sin postulaciones', (tester) async {
    await pumpMp(tester, const Size(393, 1800), _pantalla(_conDatos));
    expect(find.text('Una vacante sin postulaciones'), findsOneWidget);
  });

  testWidgets('no se inventan métricas de alcance ni de costo', (tester) async {
    await pumpMp(tester, const Size(393, 1800), _pantalla(_conDatos));
    for (final inventada in [
      'Visualizaciones',
      'Costo por contratación',
      'Tiempo promedio',
      'Índice de calidad',
      'ROI',
    ]) {
      expect(find.textContaining(inventada), findsNothing, reason: inventada);
    }
    expect(find.text('Qué no se mide todavía'), findsOneWidget);
  });

  testWidgets('sin entrevistas legibles no se muestra esa columna',
      (tester) async {
    await pumpMp(
      tester,
      const Size(393, 1800),
      _pantalla(
        const RendimientoData(
          vacantes: [
            RendimientoVacante(
              id: '1',
              titulo: 'Product Manager',
              postulaciones: 2,
              entrevistas: 0,
              activa: true,
            ),
          ],
          entrevistasNoDisponibles: true,
        ),
        clave: 'sin-entrevistas',
      ),
    );
    expect(find.text('Entrevistas'), findsNothing);
  });

  testWidgets('el error se distingue del vacío', (tester) async {
    await pumpMp(
        tester,
        const Size(393, 852),
        _pantalla(const RendimientoData(vacantes: [], error: true),
            clave: 'err'));
    expect(find.text('No pudimos cargar el rendimiento'), findsOneWidget);
  });
}
