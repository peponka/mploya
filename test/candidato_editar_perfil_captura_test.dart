import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/candidate_profile_form_screen.dart';

import 'candidato_productivo_host.dart';
import 'mp_golden_host.dart';

/// EVIDENCIA VISUAL — CANDIDATO TANDA 1 (Editar Perfil).
///
/// Captura `CandidateProfileFormScreen(isEditing: true)` productiva, la misma
/// que abre "Editar perfil" desde `ProfileScreen`. Sin `previewData` propio:
/// como Supabase no está inicializado en el test, `_loadExistingData` cae en
/// su propio try/catch y el formulario queda vacío (mismo comportamiento
/// seguro que ya tenía antes de esta tanda) — sirve para comparar estructura
/// contra el mockup, no contenido con datos reales.
///
/// Correr: flutter test test/candidato_editar_perfil_captura_test.dart
const _destino = 'design-reference/Candidato_Tanda1_Productivo_Final/editar_perfil';

void main() {
  setUpAll(() async {
    candPrepararEntorno();
    await loadMpFonts();
  });

  testWidgets('Editar perfil (candidato) — captura mobile 390x844', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: RepaintBoundary(
            key: key,
            child: const CandidateProfileFormScreen(isEditing: true),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 400));

    candSinExcepciones(tester, 'Editar perfil candidato');

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
