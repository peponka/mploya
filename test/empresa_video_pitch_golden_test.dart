import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_video_pitch_screen.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

import 'mp_golden_host.dart';

/// Golden del Video Pitch de Empresa, reconstruido de
/// `video pitch de tu empresa.png`.
///
///   flutter test test/empresa_video_pitch_golden_test.dart --update-goldens

const _conVideo = VideoPitchEmpresa(
  videoUrl: 'https://example.com/pitch.mp4',
);

const _sinVideo = VideoPitchEmpresa();

Widget _pantalla(VideoPitchEmpresa d, {String clave = 'pitch'}) =>
    EmpresaVideoPitchScreen(key: ValueKey(clave), previewData: d);

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · con video', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conVideo),
        style: MpSurfaceStyle.dark);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_video_pitch.png'));
  });

  testWidgets('golden · sin video', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(_sinVideo, clave: 'sin'),
        style: MpSurfaceStyle.dark);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_video_pitch_sin.png'));
  });

  for (final size in mpTamanos) {
    final n = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('sin overflow en $n', (tester) async {
      await pumpMp(tester, size, _pantalla(_conVideo, clave: 'a-$n'),
          style: MpSurfaceStyle.dark);
      expect(tester.takeException(), isNull);
    });
    testWidgets('sin video, sin overflow en $n', (tester) async {
      await pumpMp(tester, size, _pantalla(_sinVideo, clave: 'v-$n'),
          style: MpSurfaceStyle.dark);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('el estado del video sale del dato real', (tester) async {
    await pumpMp(tester, const Size(393, 1600), _pantalla(_conVideo),
        style: MpSurfaceStyle.dark);
    expect(find.text('Tu empresa tiene video'), findsOneWidget);
    expect(find.text('Quitar del perfil'), findsOneWidget);
    expect(find.text('Grabar uno nuevo'), findsOneWidget);

    await pumpMp(tester, const Size(393, 1600),
        _pantalla(_sinVideo, clave: 'sin2'),
        style: MpSurfaceStyle.dark);
    expect(find.text('Todavía sin video'), findsOneWidget);
    expect(find.text('Quitar del perfil'), findsNothing);
    expect(find.text('Grabar video'), findsOneWidget);
  });

  testWidgets('la guía es la del PNG, sin métricas inventadas', (tester) async {
    await pumpMp(tester, const Size(393, 1600), _pantalla(_sinVideo),
        style: MpSurfaceStyle.dark);
    expect(find.text('Guía para tu video'), findsOneWidget);
    // El mockup del onboarding numera "Paso 3 de 3": acá no se entra desde el
    // alta, así que no corresponde.
    expect(find.textContaining('Paso 3'), findsNothing);
    // Y nada de estadísticas de rendimiento del video, que nadie mide.
    expect(find.textContaining('reproducciones'), findsNothing);
    expect(find.textContaining('vistas'), findsNothing);
  });

  testWidgets('con video hay póster tocable; sin video no', (tester) async {
    await pumpMp(tester, const Size(393, 1600), _pantalla(_conVideo),
        style: MpSurfaceStyle.dark);
    expect(find.text('Ver el video de tu empresa'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.play_fill), findsOneWidget);

    await pumpMp(tester, const Size(393, 1600),
        _pantalla(_sinVideo, clave: 'sin-poster'),
        style: MpSurfaceStyle.dark);
    expect(find.text('Ver el video de tu empresa'), findsNothing);
    expect(find.byIcon(CupertinoIcons.play_fill), findsNothing);
  });

  testWidgets('el error se distingue del "sin video"', (tester) async {
    await pumpMp(
        tester,
        const Size(393, 852),
        _pantalla(const VideoPitchEmpresa(error: true), clave: 'err'),
        style: MpSurfaceStyle.dark);
    expect(find.text('No pudimos leer tu video'), findsOneWidget);
    expect(find.text('Todavía sin video'), findsNothing);
  });
}
