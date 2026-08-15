import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_creditos_data.dart';
import 'package:mploya/screens/empresa/empresa_creditos_screen.dart';

import 'mp_golden_host.dart';

/// Golden de Créditos, derivado de `creditos y planes.png` (37) y
/// `analitics y desbloqueados.png` (36), ambos de escritorio.
///
///   flutter test test/empresa_creditos_golden_test.dart --update-goldens

CreditosData _conDatos() {
  return CreditosData(
    creditos: 12,
    plan: 'Pro Recruiter',
    desbloqueos: [
      DesbloqueoRealizado(
        candidatoId: 'c1',
        cuando: DateTime(2026, 8, 9),
        nombre: 'Ana Suárez',
        headline: 'Senior Product Manager',
      ),
      DesbloqueoRealizado(
        candidatoId: 'c2',
        cuando: DateTime(2026, 7, 2),
        nombre: 'Martín Gil',
        headline: 'Flutter Developer',
      ),
    ],
  );
}

Widget _pantalla(CreditosData data, {String clave = 'creditos'}) =>
    EmpresaCreditosScreen(key: ValueKey(clave), previewData: data);

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · con saldo y desbloqueos', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos()));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_creditos.png'),
    );
  });

  testWidgets('golden · sin saldo ni desbloqueos', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(CreditosData.empty, clave: 'vacio'));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_creditos_vacio.png'),
    );
  });

  for (final size in mpTamanos) {
    final nombre = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_conDatos(), clave: 'a-$nombre'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('vacío sin overflow en $nombre', (tester) async {
      await pumpMp(
          tester, size, _pantalla(CreditosData.empty, clave: 'v-$nombre'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no se inventan planes, precios ni checkout', (tester) async {
    await pumpMp(tester, const Size(393, 2000), _pantalla(_conDatos()));
    for (final inventado in [
      'Comprar créditos',
      'Elegir plan',
      'Starter',
      'Growth',
      'Enterprise',
      r'$49',
      r'$149',
      r'$299',
      'Ahorra 20%',
    ]) {
      expect(find.text(inventado), findsNothing, reason: inventado);
    }
    // Y se dice que todavía no se pueden comprar.
    expect(find.textContaining('todavía no están disponibles'), findsWidgets);
  });

  testWidgets('el consumo se deriva de los desbloqueos reales', (tester) async {
    final d = _conDatos();
    expect(d.totalDesbloqueos, 2);
    // Uno es de hace 40 días: no cuenta en el mes en curso.
    expect(d.desbloqueosDelMes, 1);
    // 1 crédito por desbloqueo, según la RPC.
    expect(d.creditosGastados, 2);
  });

  testWidgets('sin desbloqueos lo dice, no muestra una lista falsa',
      (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(CreditosData.empty, clave: 'sin-unlocks'));
    expect(find.text('Todavía no desbloqueaste a nadie'), findsOneWidget);
    expect(find.textContaining('Ana Suárez'), findsNothing);
  });

  testWidgets('el saldo ilegible se distingue de saldo cero', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(
        const CreditosData(billeteraNoDisponible: true),
        clave: 'sin-billetera',
      ),
    );
    expect(find.text('No pudimos leer tu saldo'), findsOneWidget);
  });

  testWidgets('saldo cero avisa que no se puede desbloquear', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(CreditosData.empty, clave: 'cero'));
    expect(
      find.text('Sin créditos: no vas a poder desbloquear perfiles.'),
      findsOneWidget,
    );
  });

  testWidgets('sin billetera ofrece el bono real de bienvenida',
      (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(
        const CreditosData(puedeReclamarBienvenida: true),
        clave: 'bienvenida',
      ),
    );
    expect(
      find.text('Activar 5 créditos de bienvenida'),
      findsOneWidget,
    );
    expect(find.text('Comprar créditos'), findsNothing);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_creditos_bienvenida.png'),
    );
  });
}
