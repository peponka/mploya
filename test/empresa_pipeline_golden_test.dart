import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/models/models.dart';
import 'package:mploya/screens/empresa/empresa_pipeline_screen.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

/// Golden del Pipeline de Empresa, derivado de
/// `_Headhunter_Pipeline_Busqueda.png`.
///
///   flutter test test/empresa_pipeline_golden_test.dart --update-goldens

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

CandidatoPipeline _c(String id, String nombre, String rol, EtapaPipeline e) {
  return CandidatoPipeline(
    connectionId: id,
    etapa: e,
    usuario: NexUser(id: id, name: nombre, headline: rol),
  );
}

/// Muestra con la FORMA de datos reales — sólo vive en este test.
final _conDatos = PipelineData(
  candidatos: [
    _c('1', 'Jorge R.', 'Full Stack Dev', EtapaPipeline.nuevos),
    _c('2', 'Martín L.', 'Full Stack Dev', EtapaPipeline.nuevos),
    _c('3', 'Ana P.', 'Backend Dev', EtapaPipeline.nuevos),
    _c('4', 'Camila R.', 'UX/UI Designer', EtapaPipeline.entrevista),
    _c('5', 'Mateo S.', 'Full Stack Dev', EtapaPipeline.entrevista),
    _c('6', 'Pablo B.', 'Data Analyst', EtapaPipeline.contratados),
    _c('7', 'Julieta T.', 'QA Engineer', EtapaPipeline.descartados),
  ],
);

Widget _host(Size size, PipelineData data) {
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
              Expanded(child: EmpresaPipelineScreen(previewData: data)),
              MpBottomNav(
                items: MpRole.empresa.navItems(unreadMessages: 3),
                currentIndex: -1,
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

Future<void> _pump(WidgetTester tester, Size size, PipelineData data) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(size, data));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('golden · pipeline con candidatos', (tester) async {
    await _pump(tester, const Size(393, 852), _conDatos);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_pipeline.png'),
    );
  });

  testWidgets('golden · pipeline vacío', (tester) async {
    await _pump(tester, const Size(393, 852), PipelineData.empty);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_pipeline_vacio.png'),
    );
  });

  testWidgets('golden · pipeline en 424x852', (tester) async {
    await _pump(tester, const Size(424, 852), _conDatos);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_pipeline_424.png'),
    );
  });

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
      await _pump(tester, size, PipelineData.empty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sólo existen las 4 etapas que soporta la base', (tester) async {
    await _pump(tester, const Size(393, 852), _conDatos);
    for (final real in ['Nuevos', 'En entrevista', 'Contratados',
        'Descartados']) {
      expect(find.text(real), findsWidgets, reason: real);
    }
    // Etapas del mockup de headhunter que Empresa no tiene.
    for (final ajena in ['Presentados al cliente', 'Entrevista con cliente',
        'Descubiertos', 'Contactados', 'Interesados', 'Oferta', 'Colocado']) {
      expect(find.text(ajena), findsNothing, reason: ajena);
    }
  });

  testWidgets('no se muestra Match sin vacante', (tester) async {
    await _pump(tester, const Size(393, 852), _conDatos);
    expect(find.textContaining('Match'), findsNothing);
  });

  testWidgets('sin candidatos muestra estado vacío, no columnas falsas',
      (tester) async {
    await _pump(tester, const Size(393, 852), PipelineData.empty);
    expect(
      find.text('Todavía no hay candidatos en proceso'),
      findsOneWidget,
    );
    expect(find.textContaining('Jorge'), findsNothing);
  });

  testWidgets('empujado desde otra pantalla ofrece salida', (tester) async {
    // Como pestaña del IndexedStack no hay de dónde volver: sin botón.
    await _pump(tester, const Size(393, 852), _conDatos);
    expect(find.byIcon(CupertinoIcons.chevron_left), findsNothing);

    // Empujado (Herramientas, detalle de vacante), tiene que poder volverse.
    await tester.pumpWidget(
      CupertinoApp(
        home: MpSurface(
          style: MpSurfaceStyle.light,
          child: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => EmpresaPipelineScreen(previewData: _conDatos),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.byIcon(CupertinoIcons.chevron_left), findsOneWidget);
    await tester.tap(find.byIcon(CupertinoIcons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('Pipeline'), findsNothing);
  });

  testWidgets('el error de carga se distingue del vacío', (tester) async {
    await _pump(
      tester,
      const Size(393, 852),
      const PipelineData(candidatos: [], error: true),
    );
    expect(find.text('No pudimos cargar el pipeline'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
