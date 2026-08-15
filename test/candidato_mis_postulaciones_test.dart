import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/mis_postulaciones_screen.dart';

import 'mp_golden_host.dart';

/// CANDIDATO — TANDA 2: Mis Postulaciones.
///
/// `MisPostulacionesScreen` no toca Supabase cuando llega `previewData` (mismo
/// patrón que `ProfilePreviewData`/`JobsPreviewData`), así que estos tests
/// mueven datos resueltos, nunca la red.
const _destino = 'design-reference/Candidato_Tanda1_Productivo_Final/mis_postulaciones';

const _filasEjemplo = <Map<String, dynamic>>[
  {
    'id': '1',
    'status': 'pending',
    'created_at': '2026-08-14T10:00:00Z',
    'jobs': {
      'title': 'UX/UI Designer',
      'location': 'Asunción, Paraguay',
      'is_remote': true,
      'users': {'name': 'NovaTech', 'avatar_url': null},
    },
  },
  {
    'id': '2',
    'status': 'viewed',
    'created_at': '2026-08-10T10:00:00Z',
    'jobs': {
      'title': 'Product Manager Senior',
      'location': 'Buenos Aires, Argentina',
      'is_remote': false,
      'users': {'name': 'Globant', 'avatar_url': null},
    },
  },
  {
    'id': '3',
    'status': 'accepted',
    'created_at': '2026-07-20T10:00:00Z',
    'jobs': {
      'title': 'Data Scientist',
      'location': 'Remoto',
      'is_remote': true,
      'users': {'name': 'Mercado Libre', 'avatar_url': null},
    },
  },
  {
    'id': '4',
    'status': 'rejected',
    'created_at': '2026-07-01T10:00:00Z',
    'jobs': {
      'title': 'Customer Success Manager',
      'location': 'Asunción, Paraguay',
      'is_remote': false,
      'users': {'name': 'Solventa Corp.', 'avatar_url': null},
    },
  },
];

Future<void> _montar(
  WidgetTester tester,
  Widget pantalla, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(data: MediaQueryData(size: size), child: pantalla),
    ),
  );
  await tester.pump(const Duration(milliseconds: 32));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async {
    await loadMpFonts();
  });

  testWidgets('monta sin overflow en mobile con postulaciones reales', (tester) async {
    await _montar(
      tester,
      const MisPostulacionesScreen(
        previewData: MisPostulacionesPreviewData(filas: _filasEjemplo),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Mis Postulaciones'), findsOneWidget);
    // Los 4 estados reales, ninguno inventado (Entrevista/Oferta/Contratado
    // no existen en el CHECK real y no deben aparecer).
    expect(find.text('Enviada'), findsWidgets);
    expect(find.text('Vista'), findsWidgets);
    expect(find.text('Aceptada'), findsWidgets);
    expect(find.text('No seleccionada'), findsWidgets);
    expect(find.text('Entrevista'), findsNothing);
    expect(find.text('Oferta'), findsNothing);
    expect(find.text('Contratado'), findsNothing);
  });

  testWidgets('monta sin overflow en tablet y desktop', (tester) async {
    for (final size in [const Size(820, 1180), const Size(1440, 900)]) {
      await _montar(
        tester,
        const MisPostulacionesScreen(
          previewData: MisPostulacionesPreviewData(filas: _filasEjemplo),
        ),
        size: size,
      );
      expect(tester.takeException(), isNull, reason: 'overflow en $size');
    }
  });

  testWidgets('estado vacío es honesto: no fabrica postulaciones', (tester) async {
    await _montar(
      tester,
      const MisPostulacionesScreen(
        previewData: MisPostulacionesPreviewData(filas: []),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Todavía no te postulaste a ninguna vacante.'), findsOneWidget);
    // Ningún nombre de empresa de ejemplo debe aparecer en el estado vacío.
    expect(find.text('NovaTech'), findsNothing);
    expect(find.text('Globant'), findsNothing);
  });

  testWidgets('captura final — mobile 390x844 con postulaciones', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: RepaintBoundary(
            key: key,
            child: const MisPostulacionesScreen(
              previewData: MisPostulacionesPreviewData(filas: _filasEjemplo),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_destino/mobile.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
