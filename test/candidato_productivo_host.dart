import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/theme/mploya_tokens.dart';
import 'package:mploya/widgets/candidato/cand_ui.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// ANDAMIAJE DE LAS PANTALLAS PRODUCTIVAS DE CANDIDATO.
///
/// Monta la pantalla REAL (`ProfileScreen`, `JobsScreen`, …) dentro del shell
/// de candidato, que es como la ve la persona: barra inferior en mobile y
/// tablet, barra lateral en desktop. La pantalla que se captura es siempre la
/// productiva; el shell sólo aporta la navegación, igual que hace
/// `mp_golden_host.dart` con las pantallas de Empresa.
///
/// Los datos los inyecta cada pantalla por su `previewData`, así que nada de
/// esto toca Supabase.

/// Las tres medidas obligatorias de la tanda.
const candMedidas = <String, Size>{
  'mobile': Size(390, 844),
  'tablet': Size(820, 1180),
  'desktop': Size(1440, 900),
};

/// Límite del recorte de captura.
final candCapturaKey = GlobalKey();

/// Prepara el entorno de render.
///
/// `VisibilityDetector` —que usa el reel de Inicio para saber si está en
/// pantalla— agenda un timer de 500 ms por defecto. En un widget test eso deja
/// un timer vivo al desmontar el árbol y hace fallar la prueba sin que haya
/// nada mal en la pantalla. Con intervalo cero notifica en el mismo frame.
void candPrepararEntorno() {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
}

Widget candHost(
  Size size,
  Widget pantalla, {
  required CandDestino destino,
  int badgeMensajes = 0,
  bool oscuro = false,
}) {
  final formato = candFormato(size.width);

  Widget cuerpo;
  if (formato == CandFormato.desktop) {
    cuerpo = Row(
      children: [
        CandSidebar(activo: destino, badgeMensajes: badgeMensajes),
        Expanded(child: pantalla),
      ],
    );
  } else {
    cuerpo = Column(
      children: [
        Expanded(child: pantalla),
        CandBarraInferior(activo: destino, badgeMensajes: badgeMensajes),
      ],
    );
  }

  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: RepaintBoundary(
          key: candCapturaKey,
          child: ColoredBox(
            color: oscuro ? MpTokens.darkBg : MpTokens.lightBg,
            child: Material(
              color: oscuro ? MpTokens.darkBg : MpTokens.lightBg,
              child: cuerpo,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Monta la pantalla al tamaño pedido y deja asentar entradas y esqueletos.
Future<void> pumpCandidato(
  WidgetTester tester,
  Size size,
  Widget pantalla, {
  required CandDestino destino,
  int badgeMensajes = 0,
  bool oscuro = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    candHost(
      size,
      pantalla,
      destino: destino,
      badgeMensajes: badgeMensajes,
      oscuro: oscuro,
    ),
  );
  // Varios frames sueltos en vez de `pumpAndSettle`: si algo animara en bucle,
  // el test se colgaría en lugar de fallar.
  await tester.pump(const Duration(milliseconds: 32));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Falla con el detalle completo si el render dejó una excepción (un overflow
/// llega por acá).
void candSinExcepciones(WidgetTester tester, String contexto) {
  final e = tester.takeException();
  if (e == null) return;
  final detalle = e is FlutterError
      ? e.diagnostics.map((d) => d.toStringDeep()).join('\n')
      : e.toString();
  fail('Excepción al renderizar $contexto:\n$e\n$detalle');
}

/// Guarda la pantalla montada como PNG en [ruta].
Future<void> candCapturar(WidgetTester tester, String ruta) async {
  final boundary =
      candCapturaKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  late Uint8List bytes;
  await tester.runAsync(() async {
    final ui.Image imagen = await boundary.toImage(pixelRatio: 1.0);
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    bytes = datos!.buffer.asUint8List();
    imagen.dispose();
  });

  final archivo = File(ruta);
  archivo.parent.createSync(recursive: true);
  archivo.writeAsBytesSync(bytes);
}
