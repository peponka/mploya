import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_mensajes_data.dart';
import 'package:mploya/screens/empresa/empresa_mensajes_screen.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

/// Golden de Mensajes Empresa (lista full-screen), derivada de la columna de
/// conversaciones de `mensaes especiales.png`.
///
///   flutter test test/empresa_mensajes_golden_test.dart --update-goldens

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

DateTime _hoy(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

/// Muestra con la FORMA de datos reales — sólo vive en este test.
final _conDatos = MensajesData(
  conversaciones: [
    Conversacion(
      otroId: '1',
      nombre: 'Camila R.',
      headline: 'UX/UI Designer',
      ultimoMensaje: 'Perfecto, quedo atenta a la entrevista del viernes.',
      fecha: _hoy(13, 45),
      sinLeer: 2,
    ),
    Conversacion(
      otroId: '2',
      nombre: 'Lucas F.',
      headline: 'Backend Developer',
      ultimoMensaje: 'Te comparto mi disponibilidad para la próxima semana.',
      fecha: _hoy(11, 20),
      sinLeer: 1,
    ),
    Conversacion(
      otroId: '3',
      nombre: 'Mariana L.',
      headline: 'Product Manager',
      ultimoMensaje: 'Gracias por la información, suena muy interesante.',
      fecha: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      ultimoEsMio: true,
    ),
  ],
);

Widget _host(Size size, MensajesData data) {
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
              Expanded(child: EmpresaMensajesScreen(previewData: data)),
              MpBottomNav(
                items: MpRole.empresa.navItems(
                  unreadMessages: data.totalSinLeer,
                ),
                currentIndex: 2,
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

Future<void> _pump(WidgetTester tester, Size size, MensajesData data) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(size, data));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('golden · mensajes con conversaciones', (tester) async {
    await _pump(tester, const Size(393, 852), _conDatos);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_mensajes.png'),
    );
  });

  testWidgets('golden · mensajes vacío', (tester) async {
    await _pump(tester, const Size(393, 852), MensajesData.empty);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_mensajes_vacio.png'),
    );
  });

  testWidgets('golden · mensajes en 424x852', (tester) async {
    await _pump(tester, const Size(424, 852), _conDatos);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_mensajes_424.png'),
    );
  });

  // Las cinco medidas exigidas, con datos y vacío.
  for (final size in [
    Size(393, 852),
    Size(393, 667),
    Size(375, 667),
    Size(424, 651),
    Size(424, 852),
  ]) {
    final nombre = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('sin overflow en $nombre', (tester) async {
      await _pump(tester, size, _conDatos);
      expect(tester.takeException(), isNull);
    });

    testWidgets('vacío sin overflow en $nombre', (tester) async {
      await _pump(tester, size, MensajesData.empty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sin conversaciones muestra estado vacío real', (tester) async {
    await _pump(tester, const Size(393, 852), MensajesData.empty);
    expect(find.text('Todavía no tenés conversaciones'), findsOneWidget);
    // Nada de conversaciones de relleno.
    expect(find.textContaining('Camila'), findsNothing);
  });

  testWidgets('el contador de sin leer sale de los datos', (tester) async {
    await _pump(tester, const Size(393, 852), _conDatos);
    expect(find.text('3 sin leer'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('el error de carga se distingue del vacío', (tester) async {
    await _pump(
      tester,
      const Size(393, 852),
      const MensajesData(conversaciones: [], error: true),
    );
    expect(find.text('No pudimos cargar tus mensajes'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
