import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/mis_postulaciones_screen.dart';

import 'mp_golden_host.dart';

/// Captura del estado vacío honesto de Mis Postulaciones — evidencia visual
/// para el punto 8 de la validación de Tanda 2.
const _destino = 'design-reference/Candidato_Tanda1_Productivo_Final/mis_postulaciones';

void main() {
  setUpAll(() async {
    await loadMpFonts();
  });

  testWidgets('captura estado vacío — mobile 390x844', (tester) async {
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
              previewData: MisPostulacionesPreviewData(filas: []),
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
      final file = File('$_destino/mobile_vacio.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
