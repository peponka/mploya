import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_crear_entrevista_data.dart';
import 'package:mploya/screens/empresa/empresa_crear_entrevista_screen.dart';

import 'mp_golden_host.dart';

/// Golden de "Nueva entrevista con IA", la pieza que faltaba para que el
/// circuito de entrevista con IA se pueda originar desde Empresa.
///
///   flutter test test/empresa_crear_entrevista_golden_test.dart --update-goldens

const _conDatos = CrearEntrevistaData(
  candidatos: [
    CandidatoEntrevistable(
      candidatoId: 'c1',
      nombre: 'María López',
      headline: 'Product Manager',
      vacanteId: 'j1',
      vacante: 'Product Manager Senior',
    ),
    CandidatoEntrevistable(
      candidatoId: 'c2',
      nombre: 'Juan Martín',
      headline: 'Product Owner',
      vacanteId: 'j1',
      vacante: 'Product Manager Senior',
      yaTieneEntrevista: true,
    ),
    CandidatoEntrevistable(
      candidatoId: 'c3',
      nombre: 'Carla Méndez',
      headline: 'Data Scientist',
      vacanteId: 'j2',
      vacante: 'Data Scientist',
    ),
  ],
);

Widget _pantalla(CrearEntrevistaData d, {String clave = 'crear'}) =>
    EmpresaCrearEntrevistaScreen(key: ValueKey(clave), previewData: d);

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · con candidatos', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_crear_entrevista.png'));
  });

  testWidgets('golden · sin candidatos', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(CrearEntrevistaData.empty, clave: 'vacio'));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_crear_entrevista_vacio.png'));
  });

  for (final size in mpTamanos) {
    final n = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('sin overflow en $n', (tester) async {
      await pumpMp(tester, size, _pantalla(_conDatos, clave: 'a-$n'));
      expect(tester.takeException(), isNull);
    });
    testWidgets('vacío sin overflow en $n', (tester) async {
      await pumpMp(
          tester, size, _pantalla(CrearEntrevistaData.empty, clave: 'v-$n'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sólo se ofrece a quien todavía no tiene entrevista',
      (tester) async {
    await pumpMp(tester, const Size(393, 1600), _pantalla(_conDatos));
    // Dos disponibles → dos botones "Pedir".
    expect(find.text('Pedir'), findsNWidgets(2));
    // El que ya tiene, marcado y sin botón.
    expect(find.text('Ya pedida'), findsOneWidget);
    expect(_conDatos.disponibles, 2);
  });

  testWidgets('se agrupa por la vacante real', (tester) async {
    expect(_conDatos.porVacante.length, 2);
    expect(_conDatos.porVacante['Product Manager Senior']!.length, 2);
  });

  testWidgets('sin postulantes no se ofrece entrevistar a nadie',
      (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(CrearEntrevistaData.empty, clave: 'sin'));
    expect(find.text('Todavía no hay a quién entrevistar'), findsOneWidget);
    expect(find.text('Pedir'), findsNothing);
  });

  testWidgets('el error se distingue del vacío', (tester) async {
    await pumpMp(
        tester,
        const Size(393, 852),
        _pantalla(const CrearEntrevistaData(candidatos: [], error: true),
            clave: 'err'));
    expect(find.text('No pudimos cargar tus candidatos'), findsOneWidget);
  });

  testWidgets('no se prometen funciones que el backend no tiene',
      (tester) async {
    await pumpMp(tester, const Size(393, 1600), _pantalla(_conDatos));
    for (final inventado in [
      'Plantilla de entrevista',
      'Preguntas personalizadas',
      'Programar',
      'Duración',
      'Recordatorio',
    ]) {
      expect(find.textContaining(inventado), findsNothing, reason: inventado);
    }
  });
}
