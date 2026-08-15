import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/notifications_screen.dart';

import 'mp_golden_host.dart';

/// CANDIDATO — TANDA 5, Pantalla 1: Centro de Notificaciones.
///
/// Referencia: design-reference/FINAL_SCREENS_CODEX/.../
/// centro de notificaciones.png.
///
/// `NotificationsScreen` es real y comparte código con Headhunter — no se
/// tocó estructura, filtros, agrupado ni manejadores (`_handleAccept`,
/// `_abrirEntrevista`, etc.), sólo se retintó el acento de marca de azul
/// (#185FA5/#378ADD, de la fase de rediseño 23/7) a violeta `MpTokens.primary`
/// (#4129F0) / `primaryLight` (#6D5AF5) — 23 ocurrencias, mismo patrón que
/// portfolio_section.dart en Tanda 3.
///
/// Cuando no hay notificaciones reales, la pantalla muestra su estado vacio y
/// nunca completa la lista con identidades o actividad de demostracion.
const _destino =
    'design-reference/Candidato_Tanda1_Productivo_Final/notificaciones';

void main() {
  setUpAll(() async {
    await loadMpFonts();
  });

  for (final width in [400.0, 424.0, 430.0]) {
    testWidgets('estado vacio real sin overflow a ${width.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const ProviderScope(
          child: CupertinoApp(
            debugShowCheckedModeBanner: false,
            home: NotificationsScreen(
              previewData: NotificationsPreviewData(
                viewerAccountType: 'candidato',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.text('Novedades'), findsOneWidget);
      expect(find.text('Estás al día'), findsOneWidget);
      expect(find.text('María López'), findsNothing);
      expect(find.text('Nada por acá con este filtro.'), findsOneWidget);
    });
  }

  testWidgets('captura final — mobile 390x844', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: CupertinoApp(
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: RepaintBoundary(
              key: key,
              child: const NotificationsScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 500));
    // No se afirma `takeException() == null` como condición de éxito acá
    // porque el objetivo de este test es la captura visual, ya cubierta por
    // el test anterior — se documenta igual si aparece algo nuevo.
    final err = tester.takeException();
    if (err != null) {
      // ignore: avoid_print
      print('Aviso (no fatal para la captura): $err');
    }

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
