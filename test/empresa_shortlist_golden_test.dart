import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_shortlist_data.dart';
import 'package:mploya/screens/empresa/empresa_shortlist_screen.dart';
import 'package:mploya/screens/empresa/empresa_vacantes_data.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

import 'mp_golden_host.dart';

/// Golden de la Shortlist Inteligente, reconstruida de
/// `shortlist inteligente.png` (Pantalla 53).
///
///   flutter test test/empresa_shortlist_golden_test.dart --update-goldens

const _vacante = Vacante(
  id: 'job-1',
  titulo: 'Product Manager Senior',
  estado: VacanteEstado.activa,
  candidatos: 4,
  ubicacion: 'Buenos Aires, Argentina',
  jornada: 'Tiempo completo',
  modalidad: 'Remoto',
  tags: ['Producto', 'Analytics', 'Roadmap'],
);

CandidatoShortlist _c(
  String id,
  String nombre,
  String rol, {
  double? match,
  double? sem,
  double? skl,
  bool postulado = false,
}) {
  return CandidatoShortlist(
    id: id,
    nombre: nombre,
    headline: rol,
    tags: const ['Producto', 'Analytics', 'Scrum'],
    match: match,
    semantico: sem,
    skills: skl,
    postulado: postulado,
    estadoPostulacion: postulado ? 'pending' : null,
  );
}

final _conDatos = ShortlistData(
  candidatos: [
    _c(
      '1',
      'María López',
      'Product Manager',
      match: 0.87,
      sem: 0.90,
      skl: 0.80,
      postulado: true,
    ),
    _c('2', 'Juan Martín', 'Product Owner', match: 0.62, sem: 0.65, skl: 0.55),
    _c(
      '3',
      'Carla Méndez',
      'Producto Senior',
      match: 0.41,
      sem: 0.44,
      skl: 0.33,
    ),
    _c('4', 'Diego Ramírez', 'PM / Tech Lead', postulado: true),
  ],
);

/// La clave evita que dos `pumpWidget` seguidos dentro del mismo test reusen el
/// State anterior (mismo runtimeType) y se queden con los datos viejos.
Widget _pantalla(ShortlistData data, {String clave = 'shortlist'}) =>
    EmpresaShortlistScreen(
      key: ValueKey(clave),
      vacante: _vacante,
      previewData: data,
    );

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · shortlist con candidatos', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(_conDatos),
      style: MpSurfaceStyle.dark,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_shortlist.png'),
    );
  });

  testWidgets('golden · shortlist vacía', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(ShortlistData.empty),
      style: MpSurfaceStyle.dark,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_shortlist_vacia.png'),
    );
  });

  testWidgets('golden · shortlist en 424x852', (tester) async {
    await pumpMp(
      tester,
      const Size(424, 852),
      _pantalla(_conDatos),
      style: MpSurfaceStyle.dark,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_shortlist_424.png'),
    );
  });

  for (final size in mpTamanos) {
    final nombre = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('sin overflow en $nombre', (tester) async {
      await pumpMp(
        tester,
        size,
        _pantalla(_conDatos),
        style: MpSurfaceStyle.dark,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('vacía sin overflow en $nombre', (tester) async {
      await pumpMp(
        tester,
        size,
        _pantalla(ShortlistData.empty),
        style: MpSurfaceStyle.dark,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(768, 1024), const Size(1440, 900)]) {
    testWidgets('sin overflow en ${size.width.toInt()}px', (tester) async {
      await pumpMp(
        tester,
        size,
        _pantalla(_conDatos),
        style: MpSurfaceStyle.dark,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('el candidato sin score no muestra porcentaje inventado', (
    tester,
  ) async {
    // Alto generoso: así se construyen las cuatro tarjetas de una sola vez y no
    // hace falta scrollear para comprobar la última.
    await pumpMp(
      tester,
      const Size(393, 2200),
      _pantalla(_conDatos),
      style: MpSurfaceStyle.dark,
    );
    expect(find.text('87%'), findsWidgets);
    expect(find.text('Sin match\ncalculado'), findsOneWidget);
  });

  testWidgets('cada candidato publica acceso contextual a Match IA', (
    tester,
  ) async {
    await pumpMp(
      tester,
      const Size(393, 2400),
      _pantalla(_conDatos),
      style: MpSurfaceStyle.dark,
    );
    expect(find.text('Ver Match IA'), findsNWidgets(_conDatos.total));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no se copian las métricas del mockup que no existen', (
    tester,
  ) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(_conDatos),
      style: MpSurfaceStyle.dark,
    );
    for (final falsa in [
      'Puntaje promedio del shortlist',
      'Tiempo promedio en etapa',
      'Listo para entrevista',
    ]) {
      expect(find.text(falsa), findsNothing, reason: falsa);
    }
  });

  testWidgets('comparar exige al menos dos seleccionados', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 2200),
      _pantalla(_conDatos),
      style: MpSurfaceStyle.dark,
    );

    CupertinoButton boton() => tester.widget<CupertinoButton>(
      find.ancestor(
        of: find.text('Comparar'),
        matching: find.byType(CupertinoButton),
      ),
    );

    expect(boton().onPressed, isNull);

    await tester.tap(find.byIcon(CupertinoIcons.square_split_2x1).first);
    await tester.pump();
    expect(boton().onPressed, isNull, reason: 'con uno solo no alcanza');

    await tester.tap(find.byIcon(CupertinoIcons.square_split_2x1).first);
    await tester.pump();
    expect(boton().onPressed, isNotNull);
  });

  testWidgets('vacía distingue error de "todavía no hay"', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(
        const ShortlistData(candidatos: [], matchError: true),
        clave: 'error',
      ),
      style: MpSurfaceStyle.dark,
    );
    expect(find.text('No pudimos calcular la shortlist'), findsOneWidget);

    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(ShortlistData.empty, clave: 'vacia'),
      style: MpSurfaceStyle.dark,
    );
    expect(
      find.text('Todavía no hay candidatos para esta vacante'),
      findsOneWidget,
    );
  });

  testWidgets('las bandas salen del score real', (tester) async {
    expect(BandaInfo.de(0.87), BandaAjuste.alta);
    expect(BandaInfo.de(0.41), BandaAjuste.media);
    expect(BandaInfo.de(0.10), BandaAjuste.baja);
    expect(_conDatos.enBanda(BandaAjuste.alta), 2);
    expect(_conDatos.ajustePromedio, closeTo(0.633, 0.01));
    expect(_conDatos.mejorAjuste, 0.87);
    expect(_conDatos.postulados, 2);
  });
}
