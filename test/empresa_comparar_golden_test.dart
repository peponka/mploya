import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_comparar_screen.dart';
import 'package:mploya/screens/empresa/empresa_shortlist_data.dart';
import 'package:mploya/screens/empresa/empresa_vacantes_data.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

import 'mp_golden_host.dart';

/// Golden de Comparar Candidatos, reconstruido de
/// `comparar candidatos con ia.png` (Pantalla 52).
///
///   flutter test test/empresa_comparar_golden_test.dart --update-goldens

const _vacante = Vacante(
  id: 'job-1',
  titulo: 'Product Manager Senior',
  estado: VacanteEstado.activa,
  candidatos: 4,
  modalidad: 'Remoto',
  tags: ['Producto', 'Analytics', 'Roadmap'],
);

const _candidatos = [
  CandidatoShortlist(
    id: '1',
    nombre: 'María López',
    headline: 'Product Manager',
    tags: ['Producto', 'Analytics', 'Roadmap', 'UI/UX'],
    match: 0.87,
    semantico: 0.90,
    skills: 0.80,
    postulado: true,
    estadoPostulacion: 'pending',
  ),
  CandidatoShortlist(
    id: '2',
    nombre: 'Juan Martín',
    headline: 'Product Owner',
    tags: ['Producto', 'Scrum'],
    match: 0.62,
    semantico: 0.68,
    skills: 0.40,
  ),
  CandidatoShortlist(
    id: '3',
    nombre: 'Carla Méndez',
    headline: 'Producto Senior',
    tags: ['Roadmap'],
    match: 0.41,
    semantico: 0.45,
    skills: 0.30,
  ),
];

Widget _pantalla(List<CandidatoShortlist> candidatos) =>
    EmpresaCompararScreen(vacante: _vacante, candidatos: candidatos);

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · comparar tres candidatos', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_candidatos),
        style: MpSurfaceStyle.dark);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_comparar.png'),
    );
  });

  testWidgets('golden · comparar sin match calculado', (tester) async {
    const sinMatch = [
      CandidatoShortlist(id: '1', nombre: 'María López', postulado: true),
      CandidatoShortlist(id: '2', nombre: 'Juan Martín'),
    ];
    await pumpMp(tester, const Size(393, 852), _pantalla(sinMatch),
        style: MpSurfaceStyle.dark);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_comparar_sin_match.png'),
    );
  });

  testWidgets('golden · comparar en 424x852', (tester) async {
    await pumpMp(tester, const Size(424, 852), _pantalla(_candidatos),
        style: MpSurfaceStyle.dark);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_comparar_424.png'),
    );
  });

  for (final size in mpTamanos) {
    final nombre = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_candidatos),
          style: MpSurfaceStyle.dark);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cuatro candidatos sin overflow en $nombre', (tester) async {
      await pumpMp(
        tester,
        size,
        _pantalla([
          ..._candidatos,
          const CandidatoShortlist(id: '4', nombre: 'Diego Ramírez'),
        ]),
        style: MpSurfaceStyle.dark,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sólo se comparan dimensiones que la base calcula',
      (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_candidatos),
        style: MpSurfaceStyle.dark);

    for (final real in [
      'Ajuste total',
      'Afinidad de perfil',
      'Coincidencia de skills',
      'Skills en común',
      'Postulación',
    ]) {
      expect(find.text(real), findsWidgets, reason: real);
    }

    // Dimensiones del mockup que nadie calcula.
    for (final inventada in [
      'Potencial de crecimiento',
      'Ajuste cultural',
      'Comunicación',
      'Liderazgo',
      'Predicción de desempeño',
    ]) {
      expect(find.text(inventada), findsNothing, reason: inventada);
    }
  });

  testWidgets('no se firma un análisis de IA que nadie generó', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_candidatos),
        style: MpSurfaceStyle.dark);
    expect(find.textContaining('La IA analizó'), findsNothing);
    expect(find.textContaining('señales'), findsNothing);
    expect(find.text('Mejor ajuste'), findsOneWidget);
  });

  testWidgets('sin score no se corona a nadie', (tester) async {
    const sinMatch = [
      CandidatoShortlist(id: '1', nombre: 'María López'),
      CandidatoShortlist(id: '2', nombre: 'Juan Martín'),
    ];
    await pumpMp(tester, const Size(393, 852), _pantalla(sinMatch),
        style: MpSurfaceStyle.dark);
    expect(find.text('Sin ajuste calculado'), findsOneWidget);
    expect(find.text('Mejor ajuste'), findsNothing);
  });

  testWidgets('con menos de dos candidatos avisa en vez de comparar',
      (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla([_candidatos.first]),
      style: MpSurfaceStyle.dark,
    );
    expect(find.text('Elegí al menos dos candidatos'), findsOneWidget);
  });
}
