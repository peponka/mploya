import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_ofertas_screen.dart';
import 'package:mploya/screens/empresa/empresa_proceso_data.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

import 'mp_golden_host.dart';

/// Golden de Ofertas. Derivación: no hay PNG de gestión de ofertas de Empresa.
///
///   flutter test test/empresa_ofertas_golden_test.dart --update-goldens

PersonaEnProceso _p(
  String id,
  String nombre,
  String? vacante, {
  bool confidencial = false,
}) {
  return PersonaEnProceso(
    candidatoId: id,
    nombre: nombre,
    headline: 'Product Manager',
    vacante: vacante,
    estado: 'accepted',
    origen: 'job_applications',
    confidencial: confidencial,
    // Mantiene estable el texto del golden (`Se postuló hace 10 días`).
    postuladoEl: DateTime.now().subtract(const Duration(days: 10)),
  );
}

final _conDatos = ProcesoData(
  personas: [
    _p('1', 'María López', 'Product Manager Senior'),
    _p('2', 'Juan Martín', 'Product Manager Senior'),
    _p('3', 'Carla Méndez', 'Data Scientist'),
  ],
);

Widget _pantalla(ProcesoData d, {String clave = 'ofertas'}) =>
    EmpresaOfertasScreen(key: ValueKey(clave), previewData: d);

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · con ofertas', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_ofertas.png'));
  });

  testWidgets('golden · sin ofertas', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(ProcesoData.empty, clave: 'vacio'));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_ofertas_vacio.png'));
  });

  for (final size in mpTamanos) {
    final n = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('sin overflow en $n', (tester) async {
      await pumpMp(tester, size, _pantalla(_conDatos, clave: 'a-$n'));
      expect(tester.takeException(), isNull);
    });
    testWidgets('vacío sin overflow en $n', (tester) async {
      await pumpMp(tester, size, _pantalla(ProcesoData.empty, clave: 'v-$n'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no se inventan datos de oferta que no existen', (tester) async {
    await pumpMp(tester, const Size(393, 1800), _pantalla(_conDatos));
    for (final inventado in [
      'Salario ofrecido',
      'Vence',
      'Contrato',
      'Firma',
      'Negociación',
    ]) {
      expect(find.textContaining(inventado), findsNothing, reason: inventado);
    }
    expect(find.text('Qué no queda registrado'), findsOneWidget);
  });

  testWidgets('la fecha se rotula como la de la postulación', (tester) async {
    await pumpMp(tester, const Size(393, 1800), _pantalla(_conDatos));
    expect(find.textContaining('Se postuló'), findsWidgets);
  });

  testWidgets('una oferta confidencial no expone nombre ni avatar',
      (tester) async {
    final data = ProcesoData(
      personas: [
        _p(
          'confidencial',
          'Nombre Real Oculto',
          'Product Manager Senior',
          confidencial: true,
        ),
      ],
    );
    await pumpMp(tester, const Size(393, 852), _pantalla(data));

    expect(find.text('Candidato confidencial'), findsOneWidget);
    expect(find.text('Nombre Real Oculto'), findsNothing);
    final avatar = tester.widget<MpAvatar>(find.byType(MpAvatar));
    expect(avatar.image, isNull);
  });

  testWidgets('se agrupa por vacante real', (tester) async {
    expect(_conDatos.porVacante.length, 2);
    expect(_conDatos.porVacante['Product Manager Senior']!.length, 2);
  });

  testWidgets('el error se distingue del vacío', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(const ProcesoData(personas: [], error: true), clave: 'err'));
    expect(find.text('No pudimos cargar las ofertas'), findsOneWidget);

    await pumpMp(tester, const Size(393, 852),
        _pantalla(ProcesoData.empty, clave: 'sin'));
    expect(find.text('Todavía no hay ofertas'), findsOneWidget);
  });
}
