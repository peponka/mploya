import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/models/models.dart';
import 'package:mploya/screens/talent_onboarding_complete_screen.dart';

import 'mp_golden_host.dart';

/// CANDIDATO — TANDA 3: Perfil Listo (Asistente A10).
///
/// La versión anterior era 100% hardcodeada ("95%", "IA Score 8.7/10", 3
/// recomendaciones fijas). Estos tests verifican que la nueva versión:
///   - calcula el % real según los campos que de verdad están completos;
///   - NO muestra ningún "IA Score" (no existe fuente real);
///   - genera tips sólo para los campos que faltan de verdad;
///   - muestra la tarjeta de confidencialidad sólo si corresponde.
const _destino = 'design-reference/Candidato_Tanda1_Productivo_Final/perfil_listo';

const _perfilIncompleto = NexUser(
  id: 'u1',
  name: 'Juan Pérez',
  headline: 'Flutter Developer',
  accountType: 'candidato',
  // Sin video, sin tags, sin about, sin avatar, sin company → 1/6 (headline).
);

const _perfilCompleto = NexUser(
  id: 'u2',
  name: 'Camila Ruiz',
  headline: 'Product Designer',
  accountType: 'candidato',
  videoUrl: 'https://example.com/video.mp4',
  avatarUrl: 'https://example.com/avatar.jpg',
  about: 'Diseño experiencias digitales.',
  company: 'Globant',
  tags: ['UX', 'Figma'],
);

const _perfilConfidencial = NexUser(
  id: 'u3',
  name: 'Candidato Confidencial',
  headline: 'Senior Product Manager',
  accountType: 'confidencial',
  videoUrl: 'https://example.com/video.mp4',
  avatarUrl: 'https://example.com/avatar.jpg',
  about: 'Perfil confidencial.',
  company: 'Empresa actual',
  tags: ['Producto'],
);

Future<void> _montar(WidgetTester tester, NexUser perfil) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: TalentOnboardingCompleteScreen(previewData: perfil),
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

  testWidgets('perfil incompleto: % real, tips reales, sin IA Score', (tester) async {
    await _montar(tester, _perfilIncompleto);
    expect(tester.takeException(), isNull);

    // 1/6 campos reales → 17%, no el "95%" hardcodeado de antes.
    expect(find.text('17%'), findsOneWidget);
    expect(find.text('95%'), findsNothing);

    // Ningún IA Score inventado.
    expect(find.text('IA Score'), findsNothing);
    expect(find.textContaining('8.7'), findsNothing);

    // Tips reales por campo faltante (no las 3 fijas de antes).
    expect(find.text('Grabá tu video pitch'), findsOneWidget);
    expect(find.text('Sumá una foto de perfil'), findsOneWidget);
    expect(find.text('Agregá mas certificaciones'), findsNothing); // texto viejo inventado
  });

  testWidgets('perfil completo (6/6): sin tarjeta de tips', (tester) async {
    await _montar(tester, _perfilCompleto);
    expect(tester.takeException(), isNull);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Para completar tu perfil'), findsNothing);
  });

  testWidgets('perfil confidencial: muestra la tarjeta', (tester) async {
    await _montar(tester, _perfilConfidencial);
    expect(tester.takeException(), isNull);
    expect(find.text('Tu perfil es confidencial'), findsOneWidget);
  });

  testWidgets('perfil normal: NO muestra la tarjeta de confidencialidad', (tester) async {
    await _montar(tester, _perfilCompleto);
    expect(tester.takeException(), isNull);
    expect(find.text('Tu perfil es confidencial'), findsNothing);
  });

  testWidgets('captura final — perfil incompleto, mobile 390x844', (tester) async {
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
            child: const TalentOnboardingCompleteScreen(previewData: _perfilIncompleto),
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
