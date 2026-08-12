import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/models/models.dart';
import 'package:mploya/screens/empresa/empresa_guardados_data.dart';
import 'package:mploya/screens/empresa/empresa_guardados_screen.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

import 'mp_golden_host.dart';

/// Golden de Guardados, derivado de `ffavoritos y colecciones.png` (54).
///
///   flutter test test/empresa_guardados_golden_test.dart --update-goldens

CandidatoGuardado _c(
  String id,
  String nombre,
  String rol,
  List<String> tags, {
  int diasAtras = 1,
  bool verificado = false,
  bool disponible = false,
}) {
  return CandidatoGuardado(
    usuario: NexUser(
      id: id,
      name: nombre,
      headline: rol,
      tags: tags,
      isVerified: verificado,
      isOpenToWork: disponible,
    ),
    guardadoEl: DateTime.now().subtract(Duration(days: diasAtras)),
  );
}

final _conDatos = GuardadosData(
  candidatos: [
    _c('1', 'María López', 'Product Manager', const ['Producto', 'Analytics'],
        verificado: true, disponible: true),
    _c('2', 'Juan Martín', 'Product Owner', const ['Producto', 'Scrum'],
        diasAtras: 3),
    _c('3', 'Carla Méndez', 'UX Researcher', const ['Analytics', 'Research'],
        diasAtras: 20, verificado: true),
  ],
);

Widget _pantalla(GuardadosData data, {String clave = 'guardados'}) =>
    EmpresaGuardadosScreen(key: ValueKey(clave), previewData: data);

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · guardados con candidatos', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos),
        style: MpSurfaceStyle.dark);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_guardados.png'),
    );
  });

  testWidgets('golden · guardados vacío', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(GuardadosData.empty),
        style: MpSurfaceStyle.dark);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_guardados_vacio.png'),
    );
  });

  testWidgets('golden · guardados en 424x852', (tester) async {
    await pumpMp(tester, const Size(424, 852), _pantalla(_conDatos),
        style: MpSurfaceStyle.dark);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_guardados_424.png'),
    );
  });

  for (final size in mpTamanos) {
    final nombre = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_conDatos),
          style: MpSurfaceStyle.dark);
      expect(tester.takeException(), isNull);
    });

    testWidgets('vacío sin overflow en $nombre', (tester) async {
      await pumpMp(
        tester,
        size,
        _pantalla(GuardadosData.empty, clave: 'vacio-$nombre'),
        style: MpSurfaceStyle.dark,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no se inventan colecciones que la base no tiene',
      (tester) async {
    await pumpMp(tester, const Size(393, 2000), _pantalla(_conDatos),
        style: MpSurfaceStyle.dark);
    for (final falsa in [
      'Mis colecciones',
      'Nueva colección',
      'Talento Tech Senior',
      'Futuros Líderes',
      'Compartir colección',
      'Mover a etapa',
    ]) {
      expect(find.text(falsa), findsNothing, reason: falsa);
    }
    // Lo que sí existe: agrupación por las etiquetas reales.
    expect(find.text('Por habilidad'), findsOneWidget);
  });

  testWidgets('las métricas se calculan sobre los datos, no se copian',
      (tester) async {
    expect(_conDatos.total, 3);
    expect(_conDatos.verificados, 2);
    expect(_conDatos.disponibles, 1);
    // Sólo dos de los tres se guardaron dentro de la última semana.
    expect(_conDatos.estaSemana, 2);
    // Producto aparece en dos candidatos, Analytics en dos.
    final grupos = {
      for (final g in _conDatos.agrupacionesPorTag) g.tag: g.cantidad,
    };
    expect(grupos['Producto'], 2);
    expect(grupos['Analytics'], 2);
    expect(grupos['Scrum'], 1);
  });

  testWidgets('no se muestra match sin vacante elegida', (tester) async {
    await pumpMp(tester, const Size(393, 2000), _pantalla(_conDatos),
        style: MpSurfaceStyle.dark);
    expect(find.textContaining('Match'), findsNothing);
  });

  testWidgets('filtrar por habilidad reduce la lista', (tester) async {
    await pumpMp(tester, const Size(393, 2000), _pantalla(_conDatos),
        style: MpSurfaceStyle.dark);
    expect(find.text('María López'), findsOneWidget);

    // "Scrum" aparece dos veces: como chip de agrupación y como etiqueta de la
    // tarjeta de Juan. El primero en el árbol es el de agrupación.
    await tester.tap(find.text('Scrum').first);
    await tester.pump();

    expect(find.text('Juan Martín'), findsOneWidget);
    expect(find.text('María López'), findsNothing);
  });

  testWidgets('vacío distingue error de "todavía no"', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(const GuardadosData(candidatos: [], error: true),
          clave: 'error'),
      style: MpSurfaceStyle.dark,
    );
    expect(find.text('No pudimos cargar tus guardados'), findsOneWidget);

    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(GuardadosData.empty, clave: 'sin-datos'),
      style: MpSurfaceStyle.dark,
    );
    expect(find.text('Todavía no guardaste candidatos'), findsOneWidget);
  });
}
