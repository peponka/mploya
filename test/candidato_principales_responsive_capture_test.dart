import 'package:flutter/widgets.dart';
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

const _captura = String.fromEnvironment('CAPTURE_SET', defaultValue: 'current');
const _destino = 'test/failures/candidato_principales_capture';

const _medidas = <String, Size>{
  'mobile_400': Size(400, 900),
  'mobile_424': Size(424, 900),
  'mobile_430': Size(430, 932),
  'tablet_768': Size(768, 1024),
  'desktop_1440': Size(1440, 900),
};

void main() {
  setUpAll(() async {
    candPrepararEntorno();
    await loadMpFonts();
  });

  final conexiones = previewPersonas
      .map((persona) => NexUser.fromJson(Map.of(persona)))
      .toList();

  final pantallas = <String, (Widget Function(), CandDestino, bool)>{
    'inicio': (
      () => const HomeFeedScreen(
        previewData: HomeFeedPreviewData(
          feed: previewFeed,
          vacantes: previewVacantes,
          usuario: previewCandidato,
        ),
      ),
      CandDestino.inicio,
      true,
    ),
    'vacantes': (
      () => const JobsScreen(
        previewData: JobsPreviewData(
          vacantes: previewVacantes,
          matchScores: previewMatchScores,
        ),
      ),
      CandDestino.vacantes,
      false,
    ),
    'red': (
      () => NetworkScreen(
        previewData: NetworkPreviewData(
          conexiones: conexiones,
          recomendados: previewPersonas,
          solicitudes: previewSolicitudes,
          personas: previewPersonas,
        ),
      ),
      CandDestino.red,
      false,
    ),
    'mensajes': (
      () => const MessagingScreen(
        previewData: MessagingPreviewData(
          conexiones: previewConexiones,
          usuarios: previewPersonas,
          mensajes: previewMensajes,
        ),
      ),
      CandDestino.mensajes,
      false,
    ),
    'perfil': (
      () => ProfileScreen(
        previewData: ProfilePreviewData(
          usuario: previewCandidato,
          viewCount: 128,
        ),
      ),
      CandDestino.perfil,
      false,
    ),
  };

  for (final pantalla in pantallas.entries) {
    final (construir, destino, oscuroEnMobile) = pantalla.value;
    for (final medida in _medidas.entries) {
      testWidgets('captura ${pantalla.key} ${medida.key}', (tester) async {
        await pumpCandidato(
          tester,
          medida.value,
          construir(),
          destino: destino,
          badgeMensajes: 3,
          oscuro: oscuroEnMobile && medida.value.width < 700,
        );
        candSinExcepciones(tester, '${pantalla.key} ${medida.key}');
        await candCapturar(
          tester,
          '$_destino/$_captura/${pantalla.key}_${medida.key}.png',
        );
      });
    }
  }
}
