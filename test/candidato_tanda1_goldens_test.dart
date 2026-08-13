import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/preview/candidato/cand_inicio_preview.dart';
import 'package:mploya/preview/candidato/cand_mensajes_preview.dart';
import 'package:mploya/preview/candidato/cand_perfil_preview.dart';
import 'package:mploya/preview/candidato/cand_red_preview.dart';
import 'package:mploya/preview/candidato/cand_vacantes_preview.dart';

import 'mp_golden_host.dart';

/// GOLDENS DE LA TANDA 1 DE CANDIDATO.
///
/// Genera las 15 imágenes de la propuesta visual: cinco pantallas por tres
/// resoluciones. Usa el mismo andamiaje que los golden de Empresa
/// (`mp_golden_host.dart`) para que las fuentes carguen igual y las capturas
/// sean comparables entre roles.
///
/// Las composiciones son presentacionales puras: no tocan Supabase, no hacen
/// red y no dependen de sesión. Por eso pueden renderizarse en un test.
///
/// Regenerar:  flutter test test/candidato_tanda1_goldens_test.dart --update-goldens
/// Verificar:  flutter test test/candidato_tanda1_goldens_test.dart
void main() {
  setUpAll(loadMpFonts);

  /// Las tres medidas de la tanda.
  const medidas = <String, Size>{
    'mobile': Size(390, 844),
    'tablet': Size(820, 1180),
    'desktop': Size(1440, 900),
  };

  /// Las cinco pantallas, en el orden de la navegación canónica.
  final pantallas = <String, Widget Function()>{
    '01_inicio': () => const CandInicioPreview(),
    '02_vacantes': () => const CandVacantesPreview(),
    '03_red': () => const CandRedPreview(),
    '04_mensajes': () => const CandMensajesPreview(),
    '05_perfil': () => const CandPerfilPreview(),
  };

  for (final medida in medidas.entries) {
    for (final pantalla in pantallas.entries) {
      final nombre = '${pantalla.key}_${medida.key}';

      testWidgets(nombre, (tester) async {
        await pumpMp(tester, medida.value, pantalla.value());

        // Ninguna composición debe desbordar en su tamaño de diseño: un
        // overflow acá es un defecto visual real, no un detalle del test.
        expect(
          tester.takeException(),
          isNull,
          reason: 'Excepción u overflow al renderizar $nombre',
        );

        await expectLater(
          find.byType(CupertinoApp),
          matchesGoldenFile('goldens/candidato_tanda1/$nombre.png'),
        );
      });
    }
  }
}
