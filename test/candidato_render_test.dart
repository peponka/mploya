import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/preview/preview_fixtures.dart';
import 'package:mploya/screens/jobs_screen.dart';
import 'package:mploya/screens/messaging_screen.dart';
import 'package:mploya/screens/network_screen.dart';

/// RENDER Y OVERFLOW DE LAS PANTALLAS DE CANDIDATO.
///
/// A diferencia de los otros guardianes de esta tanda, estos tests SÍ montan
/// widgets de verdad. Es la prueba de que la inyección de `previewData` cumple
/// su promesa: si una pantalla todavía tocara Supabase al construirse, acá
/// fallaría, porque en el entorno de test Supabase no está inicializado y
/// `Supabase.instance.client` lanza.
///
/// También cubren las tres resoluciones obligatorias de la tanda. Flutter
/// reporta un overflow como excepción capturada por `tester.takeException()`,
/// así que un `RenderFlex overflowed` hace fallar el test.
void main() {
  /// Las tres medidas de la tanda.
  const tamanos = <String, Size>{
    'mobile 390×844': Size(390, 844),
    'tablet 820×1180': Size(820, 1180),
    'desktop 1440×900': Size(1440, 900),
  };

  Future<void> montar(WidgetTester tester, Widget pantalla, Size tamano) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: Material(child: pantalla)),
      ),
    );
    // Varios frames: deja correr animaciones de entrada y skeletons sin quedar
    // colgado en un `pumpAndSettle` si hubiera un loop infinito.
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 300));
  }

  void sinExcepciones(WidgetTester tester, String contexto) {
    final e = tester.takeException();
    if (e == null) return;
    // Se vuelca el detalle completo —no sólo el resumen— porque en un overflow
    // el widget culpable y su ubicación vienen en el cuerpo del FlutterError.
    final detalle = e is FlutterError
        ? e.diagnostics.map((d) => d.toStringDeep()).join('\n')
        : e.toString();
    fail('Excepción al renderizar $contexto:\n$e\n$detalle');
  }

  group('Vacantes', () {
    for (final entry in tamanos.entries) {
      testWidgets('monta sin overflow en ${entry.key}', (tester) async {
        await montar(
          tester,
          JobsScreen(
            previewData: JobsPreviewData(
              vacantes: previewVacantes,
              matchScores: previewMatchScores,
            ),
          ),
          entry.value,
        );
        sinExcepciones(tester, 'Vacantes ${entry.key}');
      });
    }

    testWidgets('muestra las vacantes ficticias y no consulta la red', (
      tester,
    ) async {
      await montar(
        tester,
        JobsScreen(
          previewData: const JobsPreviewData(vacantes: previewVacantes),
        ),
        const Size(390, 844),
      );
      // Si hubiera intentado consultar Supabase, el montaje ya habría lanzado.
      expect(find.text('Vacantes'), findsWidgets);
      sinExcepciones(tester, 'Vacantes contenido');
    });
  });

  group('Red', () {
    for (final entry in tamanos.entries) {
      testWidgets('monta sin overflow en ${entry.key}', (tester) async {
        await montar(
          tester,
          const NetworkScreen(previewData: NetworkPreviewData()),
          entry.value,
        );
        sinExcepciones(tester, 'Red ${entry.key}');
      });
    }
  });

  group('Mensajes', () {
    for (final entry in tamanos.entries) {
      testWidgets('monta sin overflow en ${entry.key}', (tester) async {
        await montar(
          tester,
          MessagingScreen(
            previewData: MessagingPreviewData(
              conexiones: previewConexiones,
              usuarios: previewPersonas,
              mensajes: previewMensajes,
            ),
          ),
          entry.value,
        );
        sinExcepciones(tester, 'Mensajes ${entry.key}');
      });
    }

    testWidgets('la bandeja vacía no inventa conversaciones', (tester) async {
      await montar(
        tester,
        const MessagingScreen(previewData: MessagingPreviewData()),
        const Size(390, 844),
      );
      // Los nombres demo que se eliminaron en esta tanda.
      for (final inventado in const ['Elena García', 'Valentina Torres']) {
        expect(find.text(inventado), findsNothing);
      }
      sinExcepciones(tester, 'Mensajes vacío');
    });
  });
}
