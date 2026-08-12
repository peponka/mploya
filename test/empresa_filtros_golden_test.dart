import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_filtros_data.dart';
import 'package:mploya/screens/empresa/empresa_filtros_screen.dart';

import 'mp_golden_host.dart';

/// Golden de Filtros avanzados, reconstruido de `ffiltros avanzados.png` con
/// `busqueda global de talento.png` de apoyo.
///
///   flutter test test/empresa_filtros_golden_test.dart --update-goldens

ResultadoBusqueda _conResultados() => const ResultadoBusqueda(
      talentos: [
        TalentoEncontrado(
          id: 'c1',
          nombre: 'Ana Suárez',
          headline: 'Senior Product Manager',
          ciudad: 'Asunción',
          tags: ['Product', 'Roadmap', 'SQL'],
          verificado: true,
          disponible: true,
          expectativa: 'USD 2.500',
          distanciaKm: 3.4,
        ),
        TalentoEncontrado(
          id: 'c2',
          nombre: 'Martín Gil',
          headline: 'Flutter Developer',
          ciudad: 'Luque',
          tags: ['Flutter', 'Dart'],
          distanciaKm: 12.0,
        ),
      ],
    );

const _filtros = FiltrosTalento(
  texto: 'Product',
  skills: ['Flutter'],
  ciudad: 'Asunción',
  radioKm: 25,
  soloDisponibles: true,
);

Widget _pantalla({
  FiltrosTalento? filtros,
  ResultadoBusqueda? data,
  String clave = 'filtros',
}) =>
    EmpresaFiltrosScreen(
      key: ValueKey(clave),
      inicial: filtros,
      previewData: data ?? _conResultados(),
      previewSugerencias: const ['Flutter', 'Product', 'SQL', 'Figma'],
    );

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · resultados con filtros activos', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(filtros: _filtros),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_filtros.png'),
    );
  });

  testWidgets('golden · sin resultados', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(
        filtros: _filtros,
        data: const ResultadoBusqueda(),
        clave: 'filtros-vacio',
      ),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_filtros_vacio.png'),
    );
  });

  testWidgets('golden · error', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(
        data: const ResultadoBusqueda(error: true),
        clave: 'filtros-error',
      ),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_filtros_error.png'),
    );
  });

  testWidgets('golden · 424x852', (tester) async {
    await pumpMp(
      tester,
      const Size(424, 852),
      _pantalla(filtros: _filtros, clave: 'filtros-424'),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_filtros_424.png'),
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
          _pantalla(filtros: _filtros, clave: 'f${size.width}'),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('filtros activos · quitar y limpiar', () {
    testWidgets('cada filtro activo se puede quitar por separado',
        (tester) async {
      await pumpMp(
        tester,
        const Size(393, 852),
        _pantalla(filtros: _filtros, clave: 'f-chips'),
      );
      expect(find.text('5 filtros activos'), findsOneWidget);
      expect(find.text('Limpiar todos'), findsOneWidget);
      expect(find.text('"Product"'), findsOneWidget);
      expect(find.text('Hasta 25 km'), findsOneWidget);
      expect(find.text('Disponibles'), findsOneWidget);
    });

    testWidgets('sin filtros no aparece la barra de activos', (tester) async {
      await pumpMp(
        tester,
        const Size(393, 852),
        _pantalla(clave: 'f-sinchips'),
      );
      expect(find.text('Limpiar todos'), findsNothing);
    });
  });

  // ── Lógica pura de los filtros ──
  group('FiltrosTalento', () {
    test('cuenta cada filtro activo, y las skills una por una', () {
      expect(FiltrosTalento.vacios.cantidad, 0);
      expect(FiltrosTalento.vacios.hayAlguno, isFalse);
      expect(_filtros.cantidad, 5); // texto + 1 skill + ciudad + radio + dispo
      expect(_filtros.hayAlguno, isTrue);
    });

    test('el espacio en blanco no cuenta como filtro', () {
      const f = FiltrosTalento(texto: '   ', ciudad: '  ');
      expect(f.cantidad, 0);
      expect(f.hayAlguno, isFalse);
    });

    test('quitar un filtro no toca los demás', () {
      final sinRadio = _filtros.sin('radio');
      expect(sinRadio.radioKm, isNull);
      expect(sinRadio.texto, 'Product');
      expect(sinRadio.skills, ['Flutter']);
      expect(sinRadio.soloDisponibles, isTrue);
    });

    test('quitar una skill deja las otras', () {
      const f = FiltrosTalento(skills: ['Flutter', 'Dart']);
      expect(f.sin('skill:Flutter').skills, ['Dart']);
    });

    test('quitar una clave desconocida no cambia nada', () {
      expect(_filtros.sin('sarasa').cantidad, _filtros.cantidad);
    });

    test('las etiquetas activas traen su clave para poder quitarlas', () {
      final claves = _filtros.activos.map((a) => a.clave).toList();
      expect(claves, contains('texto'));
      expect(claves, contains('skill:Flutter'));
      expect(claves, contains('radio'));
      expect(claves.length, _filtros.cantidad);
    });

    test('copyWith puede limpiar el radio de forma explícita', () {
      expect(_filtros.copyWith(limpiarRadio: true).radioKm, isNull);
      expect(_filtros.copyWith(radioKm: 50).radioKm, 50);
    });
  });
}
