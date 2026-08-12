import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_vacante_analytics_data.dart';
import 'package:mploya/screens/empresa/empresa_vacante_analytics_screen.dart';
import 'package:mploya/screens/empresa/empresa_vacantes_data.dart';

import 'mp_golden_host.dart';

/// Golden de Analytics de Vacante, derivado de `analytics de vacantes.png` (24),
/// que es de escritorio.
///
///   flutter test test/empresa_vacante_analytics_golden_test.dart --update-goldens

const _vacante = Vacante(
  id: 'j1',
  titulo: 'Product Manager Senior',
  estado: VacanteEstado.activa,
  candidatos: 9,
);

/// Muestra con la FORMA de datos reales, anclada a hoy para que la serie no
/// dependa de cuándo corre el test.
VacanteAnalytics _conDatos() {
  final hoy = DateTime.now();
  final base = DateTime(hoy.year, hoy.month, hoy.day);
  return VacanteAnalytics(
    porEstado: const {
      'pending': 5,
      'reviewed': 3,
      'rejected': 1,
    },
    porDia: {
      base: 2,
      base.subtract(const Duration(days: 1)): 3,
      base.subtract(const Duration(days: 3)): 1,
      base.subtract(const Duration(days: 8)): 2,
      base.subtract(const Duration(days: 11)): 1,
    },
    entrevistas: 2,
  );
}

Widget _pantalla(VacanteAnalytics data, {String clave = 'analytics'}) =>
    EmpresaVacanteAnalyticsScreen(
      key: ValueKey(clave),
      vacante: _vacante,
      previewData: data,
    );

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · analytics con datos', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos()));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_vacante_analytics.png'),
    );
  });

  testWidgets('golden · analytics sin datos', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(VacanteAnalytics.empty, clave: 'vacio'));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_vacante_analytics_vacio.png'),
    );
  });

  for (final size in mpTamanos) {
    final nombre = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_conDatos(), clave: 'a-$nombre'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('vacío sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size,
          _pantalla(VacanteAnalytics.empty, clave: 'v-$nombre'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no se inventan métricas de alcance', (tester) async {
    await pumpMp(tester, const Size(393, 2200), _pantalla(_conDatos()));
    for (final inventada in [
      'Visualizaciones',
      'Fuentes de tráfico',
      'Costo por contratación',
      'Índice de calidad',
      'Tasa de conversión total',
    ]) {
      expect(find.text(inventada), findsNothing, reason: inventada);
    }
    // Y se dice explícitamente que no se miden.
    expect(find.text('Qué no se mide todavía'), findsOneWidget);
  });

  testWidgets('los KPI salen de las filas, no del mockup', (tester) async {
    final d = _conDatos();
    expect(d.postulaciones, 9);
    expect(d.entrevistas, 2);
    expect(d.pico, 3);
    expect(d.tasaEntrevista, 22);
    expect(d.serie.length, 14);
  });

  testWidgets('sin postulaciones no hay tasa que calcular', (tester) async {
    const vacio = VacanteAnalytics();
    expect(vacio.tasaEntrevista, isNull);
    expect(vacio.variacionSemanal, isNull);
    expect(vacio.sinDatos, isTrue);
  });

  testWidgets('sin datos lo dice en vez de graficar ceros', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(VacanteAnalytics.empty, clave: 'sin-datos'));
    expect(find.text('Todavía no hay nada que medir'), findsOneWidget);
    expect(find.text('Postulaciones por día'), findsNothing);
  });

  testWidgets('el error se distingue del vacío', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(const VacanteAnalytics(error: true), clave: 'error'));
    expect(find.text('No pudimos cargar las métricas'), findsOneWidget);
  });

  testWidgets('entrevistas ilegibles muestran "—", no cero', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 2200),
      _pantalla(
        VacanteAnalytics(
          porEstado: const {'pending': 3},
          porDia: {DateTime.now(): 3},
          entrevistasNoDisponibles: true,
        ),
        clave: 'sin-entrevistas',
      ),
    );
    expect(find.text('—'), findsWidgets);
  });
}
