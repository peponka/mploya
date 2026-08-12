import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_publicar_vacante_screen.dart';

import 'mp_golden_host.dart';

/// Golden del asistente de Publicar Vacante (Empresa móvil), reconstruido de
/// `crear vacante con ia.png`, `crear vacante.png`, `publicar vacante.png`,
/// `publicar vacante 2.png` y `publicar vacante3.png`.
///
///   flutter test test/empresa_publicar_vacante_golden_test.dart --update-goldens

void main() {
  setUpAll(loadMpFonts);

  for (var paso = 0; paso < 4; paso++) {
    testWidgets('golden · paso ${paso + 1}', (tester) async {
      await pumpMp(
        tester,
        const Size(393, 852),
        EmpresaPublicarVacanteScreen(pasoInicial: paso),
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_publicar_vacante_p${paso + 1}.png'),
      );
    });
  }

  for (final size in mpTamanos) {
    final nombre = '${size.width.toInt()}x${size.height.toInt()}';

    for (var paso = 0; paso < 4; paso++) {
      testWidgets('paso ${paso + 1} sin overflow en $nombre', (tester) async {
        await pumpMp(
          tester,
          size,
          EmpresaPublicarVacanteScreen(pasoInicial: paso),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('los cuatro pasos son los de FINAL_SCREENS', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      const EmpresaPublicarVacanteScreen(),
    );
    for (final paso in ['Información', 'Descripción', 'Requisitos', 'Publicar']) {
      expect(find.text(paso), findsWidgets, reason: paso);
    }
  });

  testWidgets('sin título no se puede avanzar ni publicar', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      const EmpresaPublicarVacanteScreen(),
    );
    final continuar = tester.widget<CupertinoButton>(
      find.ancestor(
        of: find.text('Continuar'),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(continuar.onPressed, isNull);
  });

  testWidgets('con título el paso 1 habilita continuar', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      const EmpresaPublicarVacanteScreen(),
    );
    await tester.enterText(
      find.byType(CupertinoTextField).first,
      'Product Manager Senior',
    );
    await tester.pump();
    final continuar = tester.widget<CupertinoButton>(
      find.ancestor(
        of: find.text('Continuar'),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(continuar.onPressed, isNotNull);
  });

  testWidgets('no se ofrece grabar video: jobs no lo guarda', (tester) async {
    for (var paso = 0; paso < 4; paso++) {
      await pumpMp(
        tester,
        const Size(393, 852),
        EmpresaPublicarVacanteScreen(pasoInicial: paso),
      );
      expect(find.textContaining('Grabar video'), findsNothing);
      expect(find.textContaining('Subir video'), findsNothing);
    }
  });

  testWidgets('no se prometen créditos ni duración que no existen',
      (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      const EmpresaPublicarVacanteScreen(pasoInicial: 3),
    );
    expect(find.textContaining('créditos'), findsNothing);
    expect(find.textContaining('30 días'), findsNothing);
  });

  testWidgets('los canales externos se marcan como pendientes', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      const EmpresaPublicarVacanteScreen(pasoInicial: 3),
    );
    for (final canal in ['WhatsApp', 'LinkedIn', 'Instagram']) {
      expect(
        find.text('$canal · Próximamente'),
        findsOneWidget,
        reason: canal,
      );
    }
    // Y no hay ningún interruptor que sugiera que se van a publicar.
    expect(find.byType(CupertinoSwitch), findsNothing);
  });

  testWidgets('la IA queda bloqueada hasta que haya título', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      const EmpresaPublicarVacanteScreen(pasoInicial: 1),
    );
    final boton = tester.widget<CupertinoButton>(
      find.ancestor(
        of: find.text('Generar descripción con IA'),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('las habilidades se agregan y se quitan', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      const EmpresaPublicarVacanteScreen(pasoInicial: 2),
    );
    expect(find.text('Todavía no agregaste habilidades.'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField).first, 'Figma');
    await tester.pump();
    await tester.tap(find.byIcon(CupertinoIcons.add_circled_solid));
    await tester.pump();

    expect(find.text('Figma'), findsOneWidget);
    expect(find.text('Todavía no agregaste habilidades.'), findsNothing);
  });
}
