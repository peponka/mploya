import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_confidenciales_data.dart';
import 'package:mploya/screens/empresa/empresa_confidenciales_screen.dart';

import 'mp_golden_host.dart';

/// Golden de Candidatos Confidenciales, derivado de los PNG de escritorio
/// 31 (`candidatos conidenciales`), 32 (`perfil confidencial`) y
/// 35 (`desbloquear un candidato`).
///
///   flutter test test/empresa_confidenciales_golden_test.dart --update-goldens

const _conDatos = ConfidencialesData(
  candidatos: [
    CandidatoConfidencial(
      id: '1',
      nombre: 'Ana Suárez',
      desbloqueado: true,
      headline: 'Senior Product Manager',
      about: 'Doce años liderando producto en fintech regionales.',
      tags: ['Product Strategy', 'Agile', 'Leadership'],
    ),
    CandidatoConfidencial(
      id: '2',
      nombre: 'Confidencial',
      desbloqueado: false,
      headline: 'UX/UI Designer Senior',
      about: 'Ocho años diseñando productos digitales.',
      tags: ['Figma', 'UI Design', 'Design System'],
    ),
    CandidatoConfidencial(
      id: '3',
      nombre: 'Confidencial',
      desbloqueado: false,
      headline: 'Flutter Developer',
      tags: ['Flutter', 'Dart', 'Firebase'],
    ),
  ],
  billetera: BilleteraEmpresa(creditos: 12, plan: 'Pro Recruiter'),
);

const _sinCreditos = ConfidencialesData(
  candidatos: [
    CandidatoConfidencial(
      id: '2',
      nombre: 'Confidencial',
      desbloqueado: false,
      headline: 'UX/UI Designer Senior',
      tags: ['Figma'],
    ),
  ],
  billetera: BilleteraEmpresa(creditos: 0),
);

Widget _pantalla(ConfidencialesData data, {String clave = 'confidenciales'}) =>
    EmpresaConfidencialesScreen(key: ValueKey(clave), previewData: data);

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · catálogo con créditos', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_confidenciales.png'),
    );
  });

  testWidgets('golden · sin créditos', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_sinCreditos));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_confidenciales_sin_creditos.png'),
    );
  });

  testWidgets('golden · catálogo vacío', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(ConfidencialesData.empty, clave: 'vacio'));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_confidenciales_vacio.png'),
    );
  });

  for (final size in mpTamanos) {
    final nombre = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_conDatos));
      expect(tester.takeException(), isNull);
    });

    testWidgets('vacío sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size,
          _pantalla(ConfidencialesData.empty, clave: 'vacio-$nombre'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('el bloqueado no expone identidad, el desbloqueado sí',
      (tester) async {
    await pumpMp(tester, const Size(393, 2200), _pantalla(_conDatos));
    expect(find.text('Ana Suárez'), findsOneWidget);
    expect(find.text('Identidad reservada'), findsNWidgets(2));
  });

  testWidgets('el precio es el real de la RPC, no la tabla del mockup',
      (tester) async {
    await pumpMp(tester, const Size(393, 2200), _pantalla(_conDatos));
    // La RPC cobra 1 crédito fijo.
    expect(find.text('1 crédito'), findsNWidgets(2));
    // La tarifa por seniority del mockup no existe.
    for (final falso in [
      '5 créditos',
      '10 créditos',
      '20 créditos',
      '35 créditos',
      '50 créditos',
    ]) {
      expect(find.text(falso), findsNothing, reason: falso);
    }
  });

  testWidgets('no se ofrece comprar créditos sin checkout', (tester) async {
    await pumpMp(tester, const Size(393, 2200), _pantalla(_sinCreditos));
    expect(find.text('Comprar créditos'), findsNothing);
    expect(find.text('Sin créditos disponibles'), findsOneWidget);
  });

  testWidgets('el saldo ilegible se distingue de saldo cero', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(
        const ConfidencialesData(
          candidatos: [],
          billetera: BilleteraEmpresa(noDisponible: true),
        ),
        clave: 'sin-billetera',
      ),
    );
    expect(find.text('No pudimos leer tu saldo'), findsOneWidget);
  });

  testWidgets('los contadores salen del catálogo real', (tester) async {
    expect(_conDatos.total, 3);
    expect(_conDatos.desbloqueados, 1);
    expect(_conDatos.bloqueados, 2);
  });
}
