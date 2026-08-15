import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/ia_coach_result_screen.dart';
import 'package:mploya/services/ia_coach_service.dart';

import 'mp_golden_host.dart';

/// CANDIDATO — TANDA 5, Pantalla 4: Análisis IA de Video.
///
/// Referencia: design-reference/FINAL_SCREENS_CODEX/.../
/// analisis de ia video candidato.png.
///
/// `IACoachResultScreen` ya recibía `PitchAnalysis` real por parámetro (no
/// Supabase adentro) — sólo se retintó `MployaTheme.brandAccent` →
/// `MpTokens.primary` y `NexTheme.premiumEnd` → `MpTokens.premiumBright`.
/// Cero cambios de lógica: mismo score, mismas categorías, mismos tips.
const _destino = 'design-reference/Candidato_Tanda1_Productivo_Final/analisis_ia_video';

const _analysis = PitchAnalysis(
  overallScore: 89,
  communication: CategoryScore(
    name: 'Comunicación',
    emoji: '🗣️',
    score: 92,
    label: 'Excelente',
    tips: ['Hablás claro y con buen ritmo.'],
  ),
  content: CategoryScore(
    name: 'Contenido',
    emoji: '📋',
    score: 85,
    label: 'Muy bueno',
    tips: ['Mencionaste tu experiencia clave.'],
  ),
  technical: CategoryScore(
    name: 'Técnico',
    emoji: '🎥',
    score: 80,
    label: 'Bueno',
    tips: ['Buena iluminación.'],
  ),
  impact: CategoryScore(
    name: 'Impacto',
    emoji: '⚡',
    score: 90,
    label: 'Excelente',
    tips: ['Cierre con energía.'],
  ),
  summary: 'Presentación clara, estructurada y con buena energía general.',
  topTips: [
    'Sonreí al inicio del video para generar mayor conexión.',
    'Estructurá tu mensaje en 3 partes: quién sos, qué hacés, qué buscás.',
    'Mirá más a la cámara para transmitir mayor confianza.',
  ],
  wordCount: 120,
  estimatedWPM: 140,
  durationSeconds: 48,
);

void main() {
  setUpAll(() async {
    await loadMpFonts();
  });

  testWidgets('monta sin overflow y sin excepción con un análisis real', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: IACoachResultScreen(
            analysis: _analysis,
            onReRecord: () {},
            onPublish: () {},
          ),
        ),
      ),
    );
    // Animaciones de 1800ms/600ms — se dejan asentar completas.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    // El score se pinta en un anillo animado (CustomPainter), no como
    // `Text` — por eso no se busca "89" como texto. Se verifica en cambio
    // el resumen y los tips reales, que sí son widgets `Text`.
    expect(find.textContaining('clara, estructurada'), findsOneWidget);
    expect(find.textContaining('Sonreí al inicio'), findsOneWidget);
  });

  testWidgets('captura final — mobile 390x844', (tester) async {
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
            child: IACoachResultScreen(
              analysis: _analysis,
              onReRecord: () {},
              onPublish: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
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
