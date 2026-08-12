import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_match_ia_data.dart';
import 'package:mploya/screens/empresa/empresa_match_ia_screen.dart';

import 'mp_golden_host.dart';

/// Golden de Match IA, reconstruido de `matchIAverdadera.png` con
/// `match IA 3.png` y `matchia.png` de apoyo.
///
///   flutter test test/empresa_match_ia_golden_test.dart --update-goldens
///
/// Los datos de estos goldens son de PRUEBA, no de la base: `previewData`
/// existe justamente para que el golden no toque red. Lo que se fija acá es el
/// LAYOUT — que cada bloque aparezca sólo cuando su dato existe.

MatchIaData _completo() => const MatchIaData(
      match: 87,
      candidato: 'Ana Suárez',
      candidatoHeadline: 'Senior Product Manager',
      candidatoCiudad: 'Asunción',
      vacante: 'Product Manager',
      empresa: 'Nexora',
      empresaCiudad: 'Asunción',
      skillsEnComun: ['Product', 'Roadmap', 'Discovery', 'SQL'],
      skillsQueFaltan: ['B2B SaaS'],
      expectativaCandidato: 'USD 2.500',
      rangoVacante: 'USD 2.000 - 3.000',
      distanciaKm: 4.2,
    );

/// El caso que más importa: la vacante no tiene embedding todavía, y el
/// candidato no declara ni salario ni coordenadas. No se dibuja ningún número
/// inventado: ni match, ni salario, ni distancia.
MatchIaData _sinDatos() => const MatchIaData(
      candidato: 'Ana Suárez',
      candidatoHeadline: 'Senior Product Manager',
      vacante: 'Product Manager',
      empresa: 'Nexora',
      skillsQueFaltan: ['Product', 'Roadmap'],
    );

Widget _pantalla(MatchIaData data, {String clave = 'match'}) =>
    EmpresaMatchIaScreen(
      key: ValueKey(clave),
      jobId: 'job-preview',
      candidatoId: 'cand-preview',
      previewData: data,
    );

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · match con todos los datos', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_completo()));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_match_ia.png'),
    );
  });

  testWidgets('golden · sin match ni salario ni distancia', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(_sinDatos(), clave: 'match-sin'),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_match_ia_sin_datos.png'),
    );
  });

  testWidgets('golden · móvil chico 360x780', (tester) async {
    await pumpMp(
      tester,
      const Size(360, 780),
      _pantalla(_completo(), clave: 'match-360'),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_match_ia_360.png'),
    );
  });

  testWidgets('golden · móvil ancho 424x852', (tester) async {
    await pumpMp(
      tester,
      const Size(424, 852),
      _pantalla(_completo(), clave: 'match-424'),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_match_ia_424.png'),
    );
  });

  group('sin overflow en seis tamaños', () {
    for (final size in const [
      Size(320, 640),
      Size(360, 780),
      Size(375, 812),
      Size(393, 852),
      Size(424, 852),
      Size(480, 960),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await pumpMp(
          tester,
          size,
          _pantalla(_completo(), clave: 'm${size.width}'),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('la pantalla no dibuja lo que no tiene', () {
    testWidgets('sin match no aparece ningún porcentaje', (tester) async {
      await pumpMp(
        tester,
        const Size(393, 852),
        _pantalla(_sinDatos(), clave: 'm-nomatch'),
      );
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('Sin match\ncalculado'), findsOneWidget);
    });

    testWidgets('sin salario no aparece el bloque de salario', (tester) async {
      await pumpMp(
        tester,
        const Size(393, 852),
        _pantalla(_sinDatos(), clave: 'm-nosal'),
      );
      expect(find.text('Salario'), findsNothing);
      expect(find.text('Ubicación'), findsNothing);
    });

    testWidgets('con datos completos sí aparecen los tres bloques',
        (tester) async {
      await pumpMp(
        tester,
        const Size(393, 852),
        _pantalla(_completo(), clave: 'm-full'),
      );
      expect(find.text('87%'), findsOneWidget);
      expect(find.text('Match alto'), findsOneWidget);
      expect(find.text('Salario'), findsOneWidget);
      expect(find.text('Ubicación'), findsOneWidget);
      expect(find.text('4.2 km de distancia'), findsOneWidget);
    });
  });

  group('cruce de skills · lógica pura', () {
    test('empareja sin importar mayúsculas ni #', () {
      final r = cruzarSkills(
        ['#Flutter', 'SQL', 'Discovery'],
        ['flutter', 'sql'],
      );
      expect(r.comunes, ['Flutter', 'SQL']);
      expect(r.faltantes, ['Discovery']);
    });

    test('no repite un tag duplicado de la vacante', () {
      final r = cruzarSkills(['SQL', 'sql', '#SQL'], ['SQL']);
      expect(r.comunes, ['SQL']);
      expect(r.faltantes, isEmpty);
    });

    test('sin tags del candidato, todo queda como faltante', () {
      final r = cruzarSkills(['Figma'], const []);
      expect(r.comunes, isEmpty);
      expect(r.faltantes, ['Figma']);
    });
  });

  group('distancia · lógica pura', () {
    test('el mismo punto da cero', () {
      expect(distanciaEnKm(-25.3, -57.6, -25.3, -57.6), closeTo(0, 0.001));
    });

    test('un grado de latitud son ~111 km', () {
      expect(distanciaEnKm(0, 0, 1, 0), closeTo(111.19, 0.5));
    });
  });
}
