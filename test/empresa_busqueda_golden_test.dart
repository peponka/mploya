import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/models/models.dart';
import 'package:mploya/screens/empresa/empresa_busqueda_data.dart';
import 'package:mploya/screens/empresa/empresa_busqueda_screen.dart';

import 'mp_golden_host.dart';

/// Golden de Búsqueda de Talento, reconstruido de `usqueda IA avanada.png` (11)
/// con los resultados derivados de `busqueda global de talento.png` (25).
///
///   flutter test test/empresa_busqueda_golden_test.dart --update-goldens

const _etiquetas = [
  'Flutter',
  'React',
  'Figma',
  'Producto',
  'Analytics',
  'Node.js',
];

ResultadoTalento _r(String id, String nombre, String rol, {int? match}) {
  return ResultadoTalento(
    usuario: NexUser(
      id: id,
      name: nombre,
      headline: rol,
      location: 'Buenos Aires, Argentina',
      tags: const ['Flutter', 'React'],
      isVerified: true,
    ),
    match: match,
  );
}

final _conIa = BusquedaData(
  modo: ModoBusqueda.ia,
  resultados: [
    _r('1', 'Camila Rodríguez', 'UX/UI Designer Senior', match: 96),
    _r('2', 'Juan Pérez', 'Product Designer', match: 92),
    _r('3', 'Valentina Gómez', 'UI/UX Designer', match: 89),
  ],
);

final _porTexto = BusquedaData(
  modo: ModoBusqueda.texto,
  resultados: [
    _r('4', 'Fernando López', 'Frontend Developer'),
    _r('5', 'Sofía Nguyen', 'Flutter Developer'),
  ],
);

Widget _pantalla(BusquedaData? data, {String clave = 'busqueda'}) =>
    EmpresaBusquedaScreen(
      key: ValueKey(clave),
      previewData: data,
      previewEtiquetas: _etiquetas,
    );

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · estado inicial', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(null));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_busqueda.png'),
    );
  });

  testWidgets('golden · resultados por IA', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conIa, clave: 'ia'));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_busqueda_ia.png'),
    );
  });

  testWidgets('golden · resultados por texto', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(_porTexto, clave: 'texto'),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_busqueda_texto.png'),
    );
  });

  for (final size in mpTamanos) {
    final nombre = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_conIa, clave: 'ia-$nombre'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('inicial sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(null, clave: 'ini-$nombre'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('la búsqueda por texto NO inventa porcentaje de match',
      (tester) async {
    await pumpMp(
      tester,
      const Size(393, 1800),
      _pantalla(_porTexto, clave: 'texto-sin-match'),
    );
    expect(find.text('Por texto'), findsOneWidget);
    expect(find.textContaining('Match IA'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('la búsqueda por IA sí muestra el score real', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 1800),
      _pantalla(_conIa, clave: 'ia-score'),
    );
    expect(find.text('Por IA'), findsOneWidget);
    expect(find.text('96%'), findsOneWidget);
    expect(find.text('Match IA'), findsWidgets);
  });

  testWidgets('sin buscar todavía no hay resultados falsos', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(null));
    expect(find.text('Buscá tu próximo candidato'), findsOneWidget);
    expect(find.textContaining('candidatos encontrados'), findsNothing);
  });

  testWidgets('no se ofrecen filtros que la base no puede aplicar',
      (tester) async {
    await pumpMp(tester, const Size(393, 1400), _pantalla(null));
    for (final inventado in [
      'Idioma',
      'Salario esperado',
      'Disponibilidad',
      'Distancia máxima',
      'Mapa de talento',
    ]) {
      expect(find.text(inventado), findsNothing, reason: inventado);
    }
  });

  testWidgets('el buscar por texto se habilita al haber criterio',
      (tester) async {
    await pumpMp(tester, const Size(393, 1400), _pantalla(null));

    CupertinoButton boton() => tester.widget<CupertinoButton>(
          find.ancestor(
            of: find.text('Buscar'),
            matching: find.byType(CupertinoButton),
          ),
        );

    expect(boton().onPressed, isNull);

    await tester.tap(find.text('Flutter'));
    await tester.pump();

    expect(boton().onPressed, isNotNull);
  });

  testWidgets('la IA sin embedding lo explica, no dice "sin resultados"',
      (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(
        const BusquedaData(
          resultados: [],
          modo: ModoBusqueda.ia,
          sinEmbedding: true,
        ),
        clave: 'sin-embedding',
      ),
    );
    expect(find.text('La IA todavía no puede recomendarte'), findsOneWidget);
  });
}
