import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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

/// EVIDENCIA VISUAL DE LA TANDA 1 DE CANDIDATO.
///
/// Genera las 15 capturas de las pantallas PRODUCTIVAS —`HomeFeedScreen`,
/// `JobsScreen`, `NetworkScreen`, `MessagingScreen` y `ProfileScreen`— en las
/// tres medidas obligatorias, y arma las cuatro hojas de contacto.
///
/// No son mockups: es el mismo widget que ve el usuario, montado dentro del
/// shell de candidato. Los datos entran por la inyección aislada de cada
/// pantalla, así que nada de esto toca Supabase.
///
/// Correr:  flutter test test/candidato_capturas_test.dart
const _destino = 'design-reference/Candidato_Tanda1_Productivo_Final';

void main() {
  setUpAll(() async {
    candPrepararEntorno();
    await loadMpFonts();
  });

  final conexiones =
      previewPersonas.map((p) => NexUser.fromJson(Map.of(p))).toList();

  final pantallas = <String, (Widget Function(), CandDestino, bool)>{
    '01_inicio': (
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
    '02_vacantes': (
      () => JobsScreen(
            previewData: const JobsPreviewData(
              vacantes: previewVacantes,
              matchScores: previewMatchScores,
            ),
          ),
      CandDestino.vacantes,
      false,
    ),
    '03_red': (
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
    '04_mensajes': (
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
    '05_perfil': (
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

  for (final medida in candMedidas.entries) {
    for (final pantalla in pantallas.entries) {
      final (constructor, destino, oscuro) = pantalla.value;

      testWidgets('${medida.key}/${pantalla.key}', (tester) async {
        await pumpCandidato(
          tester,
          medida.value,
          constructor(),
          destino: destino,
          badgeMensajes: 3,
          oscuro: oscuro && medida.value.width < 700,
        );
        candSinExcepciones(tester, '${pantalla.key} ${medida.key}');
        await candCapturar(
          tester,
          '$_destino/${medida.key}/${pantalla.key}.png',
        );
      });
    }
  }

  test('hojas de contacto', () {
    final nombres = pantallas.keys.toList();

    img.Image cargar(String medida, String nombre) {
      final archivo = File('$_destino/$medida/$nombre.png');
      expect(
        archivo.existsSync(),
        isTrue,
        reason: 'Falta la captura $medida/$nombre.png',
      );
      return img.decodePng(archivo.readAsBytesSync())!;
    }

    /// Arma una hoja de contacto en [columnas] columnas, con el nombre de cada
    /// pantalla debajo.
    img.Image hoja(
      List<(String, img.Image)> piezas, {
      required int columnas,
      required double escala,
    }) {
      const margen = 28;
      const pie = 34;

      final anchoCelda = (piezas.first.$2.width * escala).round();
      final filas = (piezas.length / columnas).ceil();
      var altoCelda = 0;
      for (final p in piezas) {
        final alto = (p.$2.height * escala).round();
        if (alto > altoCelda) altoCelda = alto;
      }

      final ancho = margen + columnas * (anchoCelda + margen);
      final alto = margen + filas * (altoCelda + pie + margen);

      final hoja = img.Image(width: ancho, height: alto, numChannels: 4);
      img.fill(hoja, color: img.ColorRgb8(0xF8, 0xF8, 0xFF));

      for (var i = 0; i < piezas.length; i++) {
        final (nombre, original) = piezas[i];
        final col = i % columnas;
        final fila = i ~/ columnas;
        final x = margen + col * (anchoCelda + margen);
        final y = margen + fila * (altoCelda + pie + margen);

        final escalada = img.copyResize(
          original,
          width: anchoCelda,
          interpolation: img.Interpolation.average,
        );
        img.compositeImage(hoja, escalada, dstX: x, dstY: y);
        img.drawRect(
          hoja,
          x1: x,
          y1: y,
          x2: x + escalada.width - 1,
          y2: y + escalada.height - 1,
          color: img.ColorRgb8(0xED, 0xED, 0xF6),
        );
        img.drawString(
          hoja,
          nombre,
          font: img.arial24,
          x: x,
          y: y + escalada.height + 6,
          color: img.ColorRgb8(0x0A, 0x0A, 0x0F),
        );
      }
      return hoja;
    }

    void guardar(String nombre, img.Image imagen) {
      final archivo = File('$_destino/$nombre.png');
      archivo.parent.createSync(recursive: true);
      archivo.writeAsBytesSync(img.encodePng(imagen));
    }

    // Una hoja por medida.
    final porMedida = <String, img.Image>{};
    for (final medida in candMedidas.keys) {
      final piezas = [
        for (final n in nombres) ('$medida · $n', cargar(medida, n)),
      ];
      final escala = switch (medida) {
        'mobile' => 1.0,
        'tablet' => 0.62,
        _ => 0.5,
      };
      final columnas = medida == 'desktop' ? 3 : 5;
      final sheet = hoja(piezas, columnas: columnas, escala: escala);
      porMedida[medida] = sheet;
      guardar('contact_sheet_$medida', sheet);
    }

    // Hoja general: las tres apiladas, alineadas al ancho mayor.
    final anchoMax = porMedida.values
        .map((i) => i.width)
        .reduce((a, b) => a > b ? a : b);
    final normalizadas = porMedida.values
        .map(
          (i) => i.width == anchoMax
              ? i
              : img.copyResize(
                  i,
                  width: anchoMax,
                  interpolation: img.Interpolation.average,
                ),
        )
        .toList();
    final altoTotal = normalizadas.fold<int>(0, (t, i) => t + i.height);
    final todas = img.Image(width: anchoMax, height: altoTotal, numChannels: 4);
    img.fill(todas, color: img.ColorRgb8(0xF8, 0xF8, 0xFF));
    var y = 0;
    for (final i in normalizadas) {
      img.compositeImage(todas, i, dstX: 0, dstY: y);
      y += i.height;
    }
    guardar('contact_sheet_all', todas);

    for (final nombre in const [
      'contact_sheet_mobile',
      'contact_sheet_tablet',
      'contact_sheet_desktop',
      'contact_sheet_all',
    ]) {
      expect(File('$_destino/$nombre.png').existsSync(), isTrue);
    }
  });
}
