import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_herramientas_screen.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

/// Golden de Herramientas Empresa contra `mis herramientas.png` (08).
///
///   flutter test test/empresa_herramientas_golden_test.dart --update-goldens

Future<void> _loadFonts() async {
  final sdkFonts = Directory(
    '${Directory.current.path}/.flutter-sdk/bin/cache/artifacts/material_fonts',
  );
  if (sdkFonts.existsSync()) {
    final roboto = File('${sdkFonts.path}/roboto-regular.ttf');
    if (roboto.existsSync()) {
      final bytes = roboto.readAsBytesSync().buffer.asByteData();
      for (final family in [
        'Roboto',
        '.SF Pro Text',
        '.SF Pro Display',
        'CupertinoSystemText',
        'CupertinoSystemDisplay',
      ]) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
    }
  }

  final iconFont = File(
    '${Platform.environment['LOCALAPPDATA']}'
    r'\Pub\Cache\hosted\pub.dev\cupertino_icons-1.0.8\assets\CupertinoIcons.ttf',
  );
  if (iconFont.existsSync()) {
    final bytes = iconFont.readAsBytesSync().buffer.asByteData();
    for (final family in [
      'CupertinoIcons',
      'packages/cupertino_icons/CupertinoIcons',
    ]) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
  }
}

Widget _host(Size size, {bool conDatos = true}) {
  return CupertinoApp(
    debugShowCheckedModeBanner: false,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: MpSurface(
        style: MpSurfaceStyle.light,
        child: CupertinoPageScaffold(
          backgroundColor: MpTokens.lightBg,
          child: Column(
            children: [
              Expanded(
                child: EmpresaHerramientasScreen(
                  unreadNotifications: 3,
                  enProceso: conDatos ? 12 : null,
                  entrevistasAgendadas: conDatos ? 5 : null,
                  candidatosGuardados: conDatos ? 24 : null,
                ),
              ),
              MpBottomNav(
                items: MpRole.empresa.navItems(unreadMessages: 3),
                currentIndex: 3,
                onTap: (_) {},
                onCenterTap: () {},
                centerLabel: MpRole.empresa.centerLabel,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  bool conDatos = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(size, conDatos: conDatos));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('golden · herramientas con contadores', (tester) async {
    await _pump(tester, const Size(393, 1150));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_herramientas.png'),
    );
  });

  testWidgets('golden · herramientas sin contadores reales', (tester) async {
    await _pump(tester, const Size(393, 1150), conDatos: false);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_herramientas_sin_datos.png'),
    );
  });

  testWidgets('golden · herramientas en 424px', (tester) async {
    await _pump(tester, const Size(424, 1150));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_herramientas_424.png'),
    );
  });

  for (final width in [393.0, 400.0, 424.0, 430.0]) {
    testWidgets('sin overflow en ${width.toInt()}px', (tester) async {
      await _pump(tester, Size(width, 1150));
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(768, 1024), const Size(1440, 900)]) {
    testWidgets('sin overflow en ${size.width.toInt()}px', (tester) async {
      await _pump(tester, size);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sin datos reales no se inventan contadores', (tester) async {
    await _pump(tester, const Size(393, 1150), conDatos: false);
    // Los contadores del mockup no deben aparecer nunca como dato inventado.
    // Se buscan los valores exactos del PNG, no palabras sueltas: "candidatos"
    // aparece legítimamente en descripciones estáticas.
    for (final falso in [
      '12 en proceso',
      '5 agendadas',
      '24 candidatos',
      '156 esta semana',
    ]) {
      expect(find.text(falso), findsNothing, reason: falso);
    }
  });

  testWidgets('sólo lista herramientas con pantalla existente', (tester) async {
    await _pump(tester, const Size(393, 1150));
    // Del mockup se omiten las que hoy no tienen destino real.
    expect(find.text('Plantillas de mensajes'), findsNothing);
    expect(find.text('Evaluaciones'), findsNothing);
    expect(find.text('Preguntas sugeridas'), findsNothing);
    // Las que sí existen están.
    for (final t in [
      'Match IA',
      'Publicar vacante',
      'Mis vacantes',
      'Base de talento',
      'Contrataciones',
      'Cuenta y seguridad',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  });

  testWidgets('las dos configuraciones se distinguen entre sí', (tester) async {
    // FASE DE CIERRE DE LEGACY: conviven dos opciones y NO hacen lo mismo.
    // "Configuración de empresa" son las preferencias de reclutamiento
    // (pantalla nueva); "Cuenta y seguridad" es la cuenta en sí —contraseña,
    // usuarios bloqueados, tema, cerrar sesión—, que la nueva no cubre y por
    // eso sigue apuntando a `SettingsScreen`.
    await _pump(tester, const Size(393, 1600));
    expect(find.text('Configuración de empresa'), findsOneWidget);
    expect(find.text('Cuenta y seguridad'), findsOneWidget);
    // Y ya no queda una fila llamada sólo "Configuración", que era la que se
    // confundía con la otra.
    expect(find.text('Configuración'), findsNothing);
  });
}
