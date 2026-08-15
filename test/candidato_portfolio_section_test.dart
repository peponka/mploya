import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/widgets/portfolio_section.dart';

import 'mp_golden_host.dart';

/// CANDIDATO — TANDA 3: `PortfolioSection` modernizado de `NexTheme` a
/// `MpTokens`/`widgets/ds/*`. Sin Supabase inicializado en el test,
/// `_loadPortfolio` cae en su propio try/catch (ya existía antes de esta
/// tanda) y muestra el estado vacío — no hay `previewData` en este widget
/// (nunca lo tuvo), así que esto verifica estructura/color, no la lista con
/// videos reales.
const _destino = 'design-reference/Candidato_Tanda1_Productivo_Final/portfolio';

void main() {
  setUpAll(() async {
    await loadMpFonts();
  });

  testWidgets('monta sin overflow y sin excepción (perfil propio)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: CupertinoPageScaffold(
          child: SingleChildScrollView(
            child: PortfolioSection(userId: 'test-uid', isOwnProfile: true),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Portfolio'), findsOneWidget);
    expect(find.text('Mostrá tu trabajo en acción'), findsOneWidget);
  });

  testWidgets('captura final — estado vacío, mobile 390x844', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: CupertinoPageScaffold(
          child: RepaintBoundary(
            key: key,
            child: const SingleChildScrollView(
              child: PortfolioSection(userId: 'test-uid', isOwnProfile: true),
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
