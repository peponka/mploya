import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/preview/preview_app.dart';
import 'package:mploya/preview/preview_fixtures.dart';
import 'package:mploya/preview/preview_flags.dart';

/// GUARDIÁN DEL AISLAMIENTO DEL MODO PREVIEW.
///
/// El preview existe para poder ver y capturar pantallas sin sesión, sin
/// Supabase y sin internet. Su valor depende enteramente de que NO pueda
/// filtrarse a producción ni tocar servicios reales. Estos tests son la red
/// que sostiene esa promesa.
///
/// Mezclan dos técnicas:
///  · lectura del código fuente, para probar ausencias (que `lib/preview/` no
///    importe Supabase, que no haya URLs remotas);
///  · widgets reales, para lo que sí se puede montar sin red.
void main() {
  final raiz = Directory.current.path;

  List<File> archivosPreview() => Directory('$raiz/lib/preview')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  group('La puerta de entrada', () {
    test('el preview está apagado en esta corrida', () {
      // Los tests no se compilan con --dart-define=MPLOYA_PREVIEW=true, así que
      // la constante tiene que ser falsa. Si esto fallara, alguien la dejó
      // encendida por defecto y el preview podría alcanzar producción.
      expect(
        kMployaPreviewFlag,
        isFalse,
        reason: 'MPLOYA_PREVIEW no debe estar activa por defecto.',
      );
      expect(kPreviewMode, isFalse);
    });

    test('exige debug Y bandera, no una sola de las dos', () {
      final fuente = File('$raiz/lib/preview/preview_flags.dart')
          .readAsStringSync();
      expect(fuente.contains('kDebugMode'), isTrue);
      expect(fuente.contains("bool.fromEnvironment('MPLOYA_PREVIEW')"), isTrue);
      expect(
        fuente.contains('kDebugMode && kMployaPreviewFlag'),
        isTrue,
        reason: 'Las dos condiciones deben ir juntas.',
      );
    });

    test('la bandera se resuelve en compilación, no en runtime', () {
      final fuente = File('$raiz/lib/preview/preview_flags.dart')
          .readAsStringSync();
      // `const bool.fromEnvironment` no se puede activar por URL, argumento,
      // preferencia guardada ni deep link.
      expect(fuente.contains('const bool kMployaPreviewFlag'), isTrue);
      expect(fuente.contains('const bool kPreviewMode'), isTrue);
    });

    test('main.dart corta antes de inicializar servicios productivos', () {
      final fuente = File('$raiz/lib/main.dart').readAsStringSync();
      final guarda = fuente.indexOf('if (kPreviewMode)');
      final initCore = fuente.indexOf('_initCore()');

      expect(guarda, greaterThan(-1), reason: 'Falta la guarda de preview.');
      expect(initCore, greaterThan(-1));
      expect(
        guarda,
        lessThan(initCore),
        reason:
            'La rama de preview debe cortar ANTES de _initCore(), que arranca '
            'Supabase, Firebase y el resto.',
      );
    });
  });

  group('Aislamiento de lib/preview', () {
    test('ningún archivo del preview importa Supabase ni Firebase', () {
      // Se miran SÓLO las directivas import/export. Buscar el texto suelto daba
      // falsos positivos: la cabecera de las fixtures nombra `supabase_flutter`
      // justamente para documentar que NO lo importa.
      final fugas = <String>[];
      for (final f in archivosPreview()) {
        final nombre = f.path.split(RegExp(r'[/\\]')).last;
        final directivas = f
            .readAsStringSync()
            .split('\n')
            .where((l) {
              final t = l.trimLeft();
              return t.startsWith('import ') || t.startsWith('export ');
            });

        for (final linea in directivas) {
          for (final prohibido in const [
            'supabase',
            'firebase',
            'package:http',
            'dart:io',
            'geolocator',
            'camera',
            'connectivity',
            'shared_preferences',
          ]) {
            if (linea.contains(prohibido)) {
              fugas.add('$nombre → $prohibido');
            }
          }
        }
      }
      expect(fugas, isEmpty, reason: 'El preview no puede depender de: $fugas');
    });

    test('las fixtures no traen ninguna URL remota', () {
      final fuente =
          File('$raiz/lib/preview/preview_fixtures.dart').readAsStringSync();
      expect(
        RegExp(r'https?://').hasMatch(fuente),
        isFalse,
        reason:
            'Sin red: los avatares se dibujan con iniciales y los videos son '
            'placeholders locales. Nada de randomuser.me.',
      );
    });

    test('las fixtures se identifican como ficticias', () {
      expect(kPreviewFixtureTag, 'PREVIEW_FIXTURE');
      expect(kPreviewIdPrefix, 'preview-');

      // Todo id de fixture lleva el prefijo, para que sea imposible confundirlo
      // con un UUID real de la base.
      final ids = <String>[
        previewCandidato['id'] as String,
        previewCandidatoConfidencial['id'] as String,
        ...previewPersonas.map((p) => p['id'] as String),
        ...previewVacantes.map((v) => v['id'] as String),
        ...previewConexiones.map((c) => c['id'] as String),
        ...previewSolicitudes.map((s) => s['id'] as String),
        ...previewMensajes.map((m) => m['id'] as String),
        ...previewFeed.map((f) => f['id'] as String),
        ...previewNotificaciones.map((n) => n['id'] as String),
      ];
      expect(ids, isNotEmpty);
      for (final id in ids) {
        expect(
          id.startsWith(kPreviewIdPrefix),
          isTrue,
          reason: 'Id sin prefijo de preview: $id',
        );
      }
    });

    test('hay fixtures para todo lo que la tanda necesita', () {
      expect(previewPersonas, isNotEmpty);
      expect(previewVacantes, isNotEmpty);
      expect(previewConexiones, isNotEmpty);
      expect(previewSolicitudes, isNotEmpty);
      expect(previewMensajes, isNotEmpty);
      expect(previewFeed, isNotEmpty);
      expect(previewNotificaciones, isNotEmpty);
      expect(previewCandidato['account_type'], 'candidato');
      expect(previewCandidatoConfidencial['account_type'], 'confidencial');
    });

    test('ninguna pantalla productiva importa las fixtures', () {
      final fugas = <String>[];
      final dir = Directory('$raiz/lib/screens');
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        if (f.readAsStringSync().contains('preview/preview_fixtures')) {
          fugas.add(f.path.split(RegExp(r'[/\\]')).last);
        }
      }
      expect(
        fugas,
        isEmpty,
        reason:
            'Las fixtures sólo las inyecta lib/preview. Si una pantalla las '
            'importa, pueden convertirse en fallback productivo: $fugas',
      );
    });
  });

  group('El shell', () {
    testWidgets('el banner dice PREVIEW LOCAL — DATOS FICTICIOS', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PreviewBanner())),
      );
      expect(find.text(PreviewBanner.texto), findsOneWidget);
      expect(PreviewBanner.texto, 'PREVIEW LOCAL — DATOS FICTICIOS');
    });

    test('ofrece las cinco pantallas de la tanda', () {
      final nombres = previewEntries().map((e) => e.nombre).toList();
      expect(nombres, ['Inicio', 'Vacantes', 'Red', 'Mensajes', 'Perfil']);
    });

    test('ofrece las tres resoluciones obligatorias', () {
      final medidas =
          PreviewViewport.values.map((v) => v.medida).toList();
      expect(medidas, ['390 × 844', '820 × 1180', '1440 × 900']);
    });
  });
}
