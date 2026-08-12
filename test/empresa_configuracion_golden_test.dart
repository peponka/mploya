import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_configuracion_screen.dart';

import 'mp_golden_host.dart';

/// Golden de Configuración de Empresa, derivado de
/// `configuracion y privacidad.png` (58), que en el mockup es del candidato.
///
///   flutter test test/empresa_configuracion_golden_test.dart --update-goldens

const _conDatos = ConfiguracionEmpresa(
  push: true,
  email: false,
  alertas: true,
  contratacionCiega: false,
  contratando: true,
);

Widget _pantalla(ConfiguracionEmpresa d, {String clave = 'config'}) =>
    EmpresaConfiguracionScreen(key: ValueKey(clave), previewData: d);

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · configuración cargada', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_configuracion.png'));
  });

  testWidgets('golden · todo apagado', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(const ConfiguracionEmpresa(), clave: 'apagado'));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_configuracion_apagado.png'));
  });

  testWidgets('golden · sin poder leer', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(const ConfiguracionEmpresa(error: true), clave: 'err'));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_configuracion_error.png'));
  });

  for (final size in mpTamanos) {
    final n = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('sin overflow en $n', (tester) async {
      await pumpMp(tester, size, _pantalla(_conDatos, clave: 'a-$n'));
      expect(tester.takeException(), isNull);
    });
    testWidgets('error sin overflow en $n', (tester) async {
      await pumpMp(tester, size,
          _pantalla(const ConfiguracionEmpresa(error: true), clave: 'e-$n'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('los interruptores reflejan el estado real', (tester) async {
    await pumpMp(tester, const Size(393, 1800), _pantalla(_conDatos));
    final switches = tester
        .widgetList<CupertinoSwitch>(find.byType(CupertinoSwitch))
        .toList();
    // push, email, alertas, contratando, ciega
    expect(switches.length, 5);
    expect(switches[0].value, isTrue);
    expect(switches[1].value, isFalse);
    expect(switches[2].value, isTrue);
    expect(switches[3].value, isTrue);
    expect(switches[4].value, isFalse);
  });

  testWidgets('sin poder leer NO se dibujan interruptores', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(const ConfiguracionEmpresa(error: true), clave: 'err2'));
    expect(find.byType(CupertinoSwitch), findsNothing);
    expect(find.text('No pudimos cargar tu configuración'), findsOneWidget);
  });

  testWidgets('no se ofrecen opciones sin soporte', (tester) async {
    await pumpMp(tester, const Size(393, 1800), _pantalla(_conDatos));
    for (final inventado in [
      'Cambiar contraseña',
      'Autenticación en dos pasos',
      'Sesiones activas',
      'Descargar mis datos',
      'Eliminar cuenta',
    ]) {
      expect(find.text(inventado), findsNothing, reason: inventado);
    }
    expect(find.text('Qué no está acá todavía'), findsOneWidget);
  });

  testWidgets('no duplica los campos de Editar perfil', (tester) async {
    await pumpMp(tester, const Size(393, 1800), _pantalla(_conDatos));
    for (final delPerfil in [
      'Nombre de la empresa',
      'Titular',
      'Sobre la empresa',
      'Ubicación',
    ]) {
      expect(find.text(delPerfil), findsNothing, reason: delPerfil);
    }
  });
}
