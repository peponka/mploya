import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_entrevistas_data.dart';
import 'package:mploya/screens/empresa/empresa_sala_entrevista_screen.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

import 'mp_golden_host.dart';

/// Golden de la Sala de Entrevista, derivada de `entrevistas video.png`.
///
///   flutter test test/empresa_sala_entrevista_golden_test.dart --update-goldens

/// Fecha FIJA y pasada: la pantalla calcula "empieza en X min" contra el reloj,
/// así que una fecha relativa haría que el golden cambiara en cada corrida.
final _cuandoFijo = DateTime(2026, 1, 15, 10, 30);

final _conSala = EntrevistaEmpresa(
  id: 'e1',
  fuente: FuenteEntrevista.agenda,
  candidatoId: 'c1',
  candidato: 'Juan Pérez',
  candidatoHeadline: 'Product Designer',
  cuando: _cuandoFijo,
  duracionMinutos: 45,
  estado: 'confirmed',
  meetingUrl: 'https://meet.jit.si/mploya-entrevista-e1',
);

final _sinSala = EntrevistaEmpresa(
  id: 'e2',
  fuente: FuenteEntrevista.agenda,
  candidatoId: 'c2',
  candidato: 'Camila Rodríguez',
  candidatoHeadline: 'UX/UI Designer',
  cuando: _cuandoFijo,
  duracionMinutos: 30,
  estado: 'pending',
);

const _conIa = EntrevistaEmpresa(
  id: 'ia1',
  fuente: FuenteEntrevista.ia,
  candidatoId: 'c3',
  candidato: 'Lucas Fernández',
  candidatoHeadline: 'Data Scientist',
  vacante: 'Data Scientist',
  estado: 'completed',
);

Widget _pantalla(EntrevistaEmpresa e, {String clave = 'sala'}) =>
    EmpresaSalaEntrevistaScreen(
      key: ValueKey(clave),
      entrevista: e,
      previewMode: true,
    );

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · sala lista', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conSala),
        style: MpSurfaceStyle.dark);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_sala_entrevista.png'),
    );
  });

  testWidgets('golden · todavía sin sala', (tester) async {
    await pumpMp(
        tester, const Size(393, 852), _pantalla(_sinSala, clave: 'sin-sala'),
        style: MpSurfaceStyle.dark);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_sala_entrevista_sin_sala.png'),
    );
  });

  testWidgets('golden · entrevista con IA', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conIa, clave: 'ia'),
        style: MpSurfaceStyle.dark);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_sala_entrevista_ia.png'),
    );
  });

  for (final size in mpTamanos) {
    final nombre = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_conSala, clave: 'a-$nombre'),
          style: MpSurfaceStyle.dark);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin sala, sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_sinSala, clave: 'b-$nombre'),
          style: MpSurfaceStyle.dark);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no se dibuja nada de la IA en vivo del mockup', (tester) async {
    await pumpMp(tester, const Size(393, 1600), _pantalla(_conSala),
        style: MpSurfaceStyle.dark);
    for (final inventado in [
      'IA Score en vivo',
      'Transcripción',
      'Notas privadas',
      'Grabando',
      'Resumen IA',
      'Comunicación',
      'Liderazgo potencial',
    ]) {
      expect(find.textContaining(inventado), findsNothing, reason: inventado);
    }
  });

  testWidgets('sin sala ofrece crearla; con sala, entrar', (tester) async {
    await pumpMp(
        tester, const Size(393, 1600), _pantalla(_sinSala, clave: 'crear'),
        style: MpSurfaceStyle.dark);
    expect(find.text('Todavía sin sala'), findsOneWidget);
    expect(find.text('Crear sala'), findsOneWidget);

    await pumpMp(
        tester, const Size(393, 1600), _pantalla(_conSala, clave: 'entrar'),
        style: MpSurfaceStyle.dark);
    expect(find.text('Sala lista'), findsOneWidget);
    expect(find.text('Entrar a la sala'), findsOneWidget);
  });

  testWidgets('la entrevista con IA no promete sala en vivo', (tester) async {
    await pumpMp(tester, const Size(393, 1600), _pantalla(_conIa, clave: 'ia2'),
        style: MpSurfaceStyle.dark);
    expect(find.text('Entrar a la sala'), findsNothing);
    expect(find.textContaining('asíncrona'), findsWidgets);
  });

  testWidgets('la cancelada no deja entrar', (tester) async {
    final cancelada = EntrevistaEmpresa(
      id: 'e9',
      fuente: FuenteEntrevista.agenda,
      candidato: 'Ana Suárez',
      cuando: _cuandoFijo,
      estado: 'cancelled',
      meetingUrl: 'https://meet.jit.si/x',
    );
    await pumpMp(
        tester, const Size(393, 852), _pantalla(cancelada, clave: 'cancel'),
        style: MpSurfaceStyle.dark);
    expect(find.text('Entrar a la sala'), findsNothing);
    expect(find.textContaining('cancelada'), findsWidgets);
  });

  testWidgets('el link de sala se deriva del id, igual para ambas partes',
      (tester) async {
    expect(salaDeEntrevista('abc'), 'https://meet.jit.si/mploya-entrevista-abc');
  });
}
