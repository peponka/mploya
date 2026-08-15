import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/ofertas_recibidas_screen.dart';

import 'mp_golden_host.dart';

/// CANDIDATO — TANDA 5, Pantalla 5: Ofertas Recibidas.
const _destino = 'design-reference/Candidato_Tanda1_Productivo_Final/ofertas_recibidas';

const _filasEjemplo = <Map<String, dynamic>>[
  {
    'id': '1',
    'created_at': '2026-08-10T10:00:00Z',
    'jobs': {
      'title': 'Representante Comercial',
      'location': 'Asunción, Paraguay',
      'is_remote': true,
      'salary_range': 'PYG 5.000.000 / mes',
      'users': {'id': 'c1', 'name': 'Nexora S.A.', 'avatar_url': null, 'headline': ''},
    },
  },
];

Future<void> _montar(WidgetTester tester, OfertasPreviewData data) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: OfertasRecibidasScreen(previewData: data),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 32));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async {
    await loadMpFonts();
  });

  testWidgets('monta sin overflow con ofertas reales', (tester) async {
    await _montar(tester, const OfertasPreviewData(filas: _filasEjemplo));
    expect(tester.takeException(), isNull);
    expect(find.text('Representante Comercial'), findsOneWidget);
    expect(find.text('Nexora S.A.'), findsOneWidget);
    // Sin acciones fantasma: no hay Aceptar/Rechazar/Negociar reales.
    expect(find.text('Aceptar oferta'), findsNothing);
    expect(find.text('Rechazar oferta'), findsNothing);
    expect(find.text('Negociar'), findsNothing);
  });

  testWidgets('estado vacío es honesto: no fabrica ofertas', (tester) async {
    await _montar(tester, const OfertasPreviewData(filas: []));
    expect(tester.takeException(), isNull);
    expect(find.text('Todavía no tenés ofertas.'), findsOneWidget);
    expect(find.text('Nexora S.A.'), findsNothing);
  });

  testWidgets('captura final — mobile 390x844', (tester) async {
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
            child: const OfertasRecibidasScreen(
              previewData: OfertasPreviewData(filas: _filasEjemplo),
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
