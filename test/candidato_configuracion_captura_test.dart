import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mp_golden_host.dart';

/// CANDIDATO — TANDA 5, Pantalla 2: Configuración y Privacidad.
///
/// Referencia: design-reference/FINAL_SCREENS_CODEX/.../
/// configuracion y privacidad.png — confirmado candidato (María López,
/// Product Manager Senior, visibilidad del perfil ante empresas).
///
/// `SettingsScreen` es real y compartida entre roles — no se tocó
/// estructura, secciones, toggles ni persistencia (SharedPreferences +
/// `users`), sólo se retintó `MployaTheme.brandAccent` → `MpTokens.primary`
/// (6 ocurrencias: cuenta, notificaciones por email, alertas de trabajo).
/// Los demás colores de ícono por fila (teal, púrpura, gris, rojo) se
/// dejaron — son variedad semántica intencional, no accent de marca.
const _destino = 'design-reference/Candidato_Tanda1_Productivo_Final/configuracion';

void main() {
  setUpAll(() async {
    await loadMpFonts();
  });

  testWidgets('monta sin overflow ni excepción (sin Supabase, valores por defecto)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.text('Configuración'), findsWidgets);
    expect(find.text('CUENTA'), findsOneWidget);
    expect(find.text('PRIVACIDAD'), findsOneWidget);
  });

  testWidgets('captura final — mobile 390x844', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
            child: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
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
