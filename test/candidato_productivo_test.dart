import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/models/models.dart';
import 'package:mploya/preview/preview_fixtures.dart';
import 'package:mploya/screens/home_feed_screen.dart';
import 'package:mploya/screens/jobs_screen.dart';
import 'package:mploya/screens/messaging_screen.dart';
import 'package:mploya/screens/network_screen.dart';
import 'package:mploya/screens/profile_screen.dart';
import 'package:mploya/widgets/candidato/cand_ui.dart';

import 'candidato_productivo_host.dart';
import 'mp_golden_host.dart';

/// PANTALLAS PRODUCTIVAS DE CANDIDATO — RENDER, OVERFLOW Y HONESTIDAD.
///
/// Monta las CINCO pantallas reales en las tres medidas de la tanda. No son
/// mockups: son `ProfileScreen`, `JobsScreen`, `NetworkScreen`,
/// `MessagingScreen` y `HomeFeedScreen`, las mismas que ve el usuario.
///
/// Que monten prueba además que la inyección aislada funciona: en el entorno de
/// test Supabase no está inicializado, así que cualquier consulta al construir
/// haría fallar el test.
void main() {
  setUpAll(() async {
    candPrepararEntorno();
    await loadMpFonts();
  });

  ProfileScreen perfil() => ProfileScreen(
        previewData: ProfilePreviewData(
          usuario: previewCandidato,
          viewCount: 128,
        ),
      );

  JobsScreen vacantes() => JobsScreen(
        previewData: const JobsPreviewData(
          vacantes: previewVacantes,
          matchScores: previewMatchScores,
        ),
      );

  final conexiones =
      previewPersonas.map((p) => NexUser.fromJson(Map.of(p))).toList();

  NetworkScreen red() => NetworkScreen(
        previewData: NetworkPreviewData(
          conexiones: conexiones,
          recomendados: previewPersonas,
          solicitudes: previewSolicitudes,
          personas: previewPersonas,
        ),
      );

  MessagingScreen mensajes() => const MessagingScreen(
        previewData: MessagingPreviewData(
          conexiones: previewConexiones,
          usuarios: previewPersonas,
          mensajes: previewMensajes,
        ),
      );

  HomeFeedScreen inicio() => const HomeFeedScreen(
        previewData: HomeFeedPreviewData(
          feed: previewFeed,
          vacantes: previewVacantes,
          usuario: previewCandidato,
        ),
      );

  final pantallas = <String, (Widget Function(), CandDestino, bool)>{
    'Inicio': (inicio, CandDestino.inicio, true),
    'Vacantes': (vacantes, CandDestino.vacantes, false),
    'Red': (red, CandDestino.red, false),
    'Mensajes': (mensajes, CandDestino.mensajes, false),
    'Perfil': (perfil, CandDestino.perfil, false),
  };

  for (final entrada in pantallas.entries) {
    group(entrada.key, () {
      final (constructor, destino, oscuro) = entrada.value;
      for (final medida in candMedidas.entries) {
        testWidgets('monta sin overflow en ${medida.key}', (tester) async {
          await pumpCandidato(
            tester,
            medida.value,
            constructor(),
            destino: destino,
            badgeMensajes: 3,
            // El reel de Inicio es oscuro por diseño en mobile.
            oscuro: oscuro && medida.value.width < 700,
          );
          candSinExcepciones(tester, '${entrada.key} ${medida.key}');
        });
      }
    });
  }

  group('Honestidad de los datos', () {
    testWidgets('Perfil no inventa métricas cuando el perfil está vacío', (
      tester,
    ) async {
      await pumpCandidato(
        tester,
        const Size(390, 844),
        ProfileScreen(
          previewData: const ProfilePreviewData(
            usuario: {
              'id': 'preview-vacio',
              'name': 'Perfil Nuevo',
              'account_type': 'candidato',
            },
          ),
        ),
        destino: CandDestino.perfil,
      );

      // Cero vistas y cero conexiones se muestran como cero, no como un número
      // de relleno, y no se filtra ningún dato de otro perfil.
      expect(find.text('Perfil Nuevo'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      expect(find.text('Renata Ferreyra'), findsNothing);
      expect(find.text('128'), findsNothing);
      candSinExcepciones(tester, 'Perfil vacío');

      // Los estados honestos existen aunque estén fuera de la primera pantalla.
      await tester.scrollUntilVisible(
        find.text('Todavía no escribiste tu descripción.'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Todavía no escribiste tu descripción.'), findsOneWidget);
    });

    testWidgets('Mensajes vacío no inventa conversaciones', (tester) async {
      await pumpCandidato(
        tester,
        const Size(390, 844),
        const MessagingScreen(previewData: MessagingPreviewData()),
        destino: CandDestino.mensajes,
      );
      for (final inventado in const ['Elena García', 'Valentina Torres']) {
        expect(find.text(inventado), findsNothing);
      }
      candSinExcepciones(tester, 'Mensajes vacío');
    });

    testWidgets('Vacantes vacío no inventa vacantes', (tester) async {
      await pumpCandidato(
        tester,
        const Size(390, 844),
        const JobsScreen(previewData: JobsPreviewData(vacantes: [])),
        destino: CandDestino.vacantes,
      );
      expect(find.text('Product Designer Senior'), findsNothing);
      candSinExcepciones(tester, 'Vacantes vacío');
    });
  });
}
