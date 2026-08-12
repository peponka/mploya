import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/company_verification_service.dart';
import 'package:mploya/screens/empresa/empresa_verificacion_data.dart';
import 'package:mploya/screens/empresa/empresa_verificacion_screen.dart';

import 'mp_golden_host.dart';

/// Golden de Verificación de Empresa.
///
/// El PNG de referencia (`veriifcacion de perfil.png`) es de escritorio y del
/// rol candidato: se reutiliza su ESTRUCTURA, no su contenido.
///
///   flutter test test/empresa_verificacion_golden_test.dart --update-goldens

final _hoy = DateTime(2026, 8, 12);

VerificacionData _conNivel() => VerificacionData(
      nivel: VerificationLevel.basic,
      dominioEmail: 'nexora.com',
      historial: [
        SolicitudVerificacion(
          id: 'v2',
          nivel: VerificationLevel.verified,
          estado: 'pending',
          cuando: _hoy,
        ),
        SolicitudVerificacion(
          id: 'v1',
          nivel: VerificationLevel.basic,
          estado: 'approved',
          cuando: DateTime(2026, 8, 4),
          notaDeRevision: 'Auto-verificado: email corporativo (nexora.com)',
        ),
      ],
    );

VerificacionData _sinNada() =>
    const VerificacionData(dominioEmail: 'gmail.com');

Widget _pantalla(VerificacionData d, {String clave = 'verif'}) =>
    EmpresaVerificacionScreen(key: ValueKey(clave), previewData: d);

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · con nivel obtenido y una solicitud en revisión',
      (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conNivel()));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_verificacion.png'),
    );
  });

  testWidgets('golden · sin verificar', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(_sinNada(), clave: 'verif-sin'),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_verificacion_sin.png'),
    );
  });

  testWidgets('golden · error', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(const VerificacionData(error: true), clave: 'verif-err'),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_verificacion_error.png'),
    );
  });

  testWidgets('golden · 424x852', (tester) async {
    await pumpMp(
      tester,
      const Size(424, 852),
      _pantalla(_conNivel(), clave: 'verif-424'),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_verificacion_424.png'),
    );
  });

  group('sin overflow en seis tamaños', () {
    for (final size in const [
      Size(320, 640),
      Size(360, 780),
      Size(375, 812),
      Size(393, 852),
      Size(424, 852),
      Size(480, 960),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await pumpMp(
          tester,
          size,
          _pantalla(_conNivel(), clave: 'v${size.width}'),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('sólo se muestran estados reales', () {
    testWidgets('el nivel obtenido se marca y no ofrece verificar de nuevo',
        (tester) async {
      await pumpMp(
        tester,
        const Size(393, 852),
        _pantalla(_conNivel(), clave: 'v-ok'),
      );
      expect(find.text('Email Verificado'), findsWidgets);
      expect(find.text('Obtenido'), findsOneWidget);
      expect(find.text('En revisión'), findsOneWidget);
      expect(find.text('Verificar mi email'), findsNothing);
    });

    testWidgets('sin verificación se ofrece la acción real', (tester) async {
      await pumpMp(
        tester,
        const Size(393, 852),
        _pantalla(_sinNada(), clave: 'v-none'),
      );
      expect(find.text('Sin verificar'), findsOneWidget);
      expect(find.text('Verificar mi email'), findsOneWidget);
      expect(find.text('Obtenido'), findsNothing);
    });

    testWidgets('nunca se dibuja progreso hacia trusted', (tester) async {
      await pumpMp(
        tester,
        const Size(393, 852),
        _pantalla(_conNivel(), clave: 'v-trusted'),
      );
      // El criterio automático es inalcanzable hoy: no puede aparecer ningún
      // contador tipo "0 de 5 contrataciones".
      expect(find.textContaining('de 5'), findsNothing);
      expect(find.textContaining('contrataciones exitosas'), findsNothing);
    });

    testWidgets('no se ofrece subir documentos', (tester) async {
      await pumpMp(
        tester,
        const Size(393, 852),
        _pantalla(_conNivel(), clave: 'v-docs'),
      );
      expect(find.textContaining('Subir'), findsNothing);
      expect(find.textContaining('documento de identidad'), findsNothing);
    });
  });

  group('VerificacionData · lógica pura', () {
    test('el nivel vigente es el más alto aprobado, no el más reciente', () {
      final d = VerificacionData(
        historial: [
          SolicitudVerificacion(
            id: 'b',
            nivel: VerificationLevel.basic,
            estado: 'approved',
            cuando: _hoy,
          ),
          SolicitudVerificacion(
            id: 't',
            nivel: VerificationLevel.trusted,
            estado: 'approved',
            cuando: DateTime(2026, 1, 1),
          ),
        ],
      );
      expect(d.tieneAprobado(VerificationLevel.trusted), isTrue);
      expect(d.tieneAprobado(VerificationLevel.verified), isFalse);
    });

    test('una solicitud pendiente no cuenta como aprobada', () {
      final d = VerificacionData(
        historial: [
          SolicitudVerificacion(
            id: 'p',
            nivel: VerificationLevel.verified,
            estado: 'pending',
            cuando: _hoy,
          ),
        ],
      );
      expect(d.tieneAprobado(VerificationLevel.verified), isFalse);
      expect(d.pendienteDe(VerificationLevel.verified), isNotNull);
      expect(d.rechazoDe(VerificationLevel.verified), isNull);
    });

    test('un rechazo se distingue de una pendiente', () {
      final d = VerificacionData(
        historial: [
          SolicitudVerificacion(
            id: 'r',
            nivel: VerificationLevel.verified,
            estado: 'rejected',
            cuando: _hoy,
            notaDeRevision: 'Documentación ilegible',
          ),
        ],
      );
      expect(d.rechazoDe(VerificationLevel.verified)?.notaDeRevision,
          'Documentación ilegible');
      expect(d.pendienteDe(VerificationLevel.verified), isNull);
    });
  });
}
