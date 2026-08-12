import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/models/models.dart';
import 'package:mploya/screens/empresa/empresa_editar_perfil_screen.dart';

import 'mp_golden_host.dart';

/// Golden de Editar Perfil de Empresa, derivado de `perfil empresa premium.png`
/// tras auditar qué campos puede persistir `public.users`.
///
///   flutter test test/empresa_editar_perfil_golden_test.dart --update-goldens

const _completa = NexUser(
  id: 'e1',
  name: 'NovaTech',
  headline: 'Tecnología que impulsa el futuro',
  about: 'Creamos soluciones SaaS que ayudan a empresas de todo el mundo.',
  location: 'Buenos Aires, Argentina',
  accountType: 'empresa',
  tags: ['Producto', 'Analytics'],
  isHiring: true,
);

const _vacia = NexUser(id: 'e2', name: 'Mi Empresa', headline: '');

Widget _pantalla(NexUser empresa, {String clave = 'editar'}) =>
    EmpresaEditarPerfilScreen(
      key: ValueKey(clave),
      empresa: empresa,
      previewMode: true,
    );

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · perfil con datos', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_completa));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_editar_perfil.png'),
    );
  });

  testWidgets('golden · perfil sin datos', (tester) async {
    await pumpMp(
        tester, const Size(393, 852), _pantalla(_vacia, clave: 'vacia'));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_editar_perfil_vacio.png'),
    );
  });

  for (final size in mpTamanos) {
    final nombre = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_completa, clave: 'a-$nombre'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('vacía sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_vacia, clave: 'v-$nombre'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sólo se piden campos que la base guarda', (tester) async {
    await pumpMp(tester, const Size(393, 2000), _pantalla(_completa));

    for (final real in [
      'Nombre de la empresa',
      'Titular',
      'Sobre la empresa',
      'Ubicación',
      'En qué buscás',
      'Estamos contratando',
    ]) {
      expect(find.text(real), findsWidgets, reason: real);
    }

    // Campos del mockup —y del formulario legacy— que no tienen columna.
    for (final inventado in [
      'Cantidad de empleados',
      'Año de fundación',
      'Cultura',
      'Beneficios',
      'Sitio web',
      'Stack tecnológico',
      'Oficinas',
    ]) {
      expect(find.text(inventado), findsNothing, reason: inventado);
    }
  });

  testWidgets('se explica qué todavía no se puede cargar', (tester) async {
    await pumpMp(tester, const Size(393, 2000), _pantalla(_completa));
    expect(find.text('Qué todavía no se puede cargar'), findsOneWidget);
  });

  testWidgets('los campos llegan cargados con lo que ya había',
      (tester) async {
    await pumpMp(tester, const Size(393, 2000), _pantalla(_completa));
    expect(find.text('NovaTech'), findsWidgets);
    expect(find.text('Tecnología que impulsa el futuro'), findsWidgets);
    expect(find.text('Producto'), findsWidgets);
  });

  testWidgets('sin nombre no se puede guardar', (tester) async {
    await pumpMp(
        tester, const Size(393, 2000), _pantalla(_vacia, clave: 'sin-nombre'));

    await tester.enterText(find.byType(CupertinoTextField).first, '');
    await tester.pump();

    final guardar = tester.widget<CupertinoButton>(
      find.ancestor(
        of: find.text('Guardar'),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(guardar.onPressed, isNull);
  });

  testWidgets('las etiquetas se agregan sin duplicar por tilde',
      (tester) async {
    await pumpMp(
        tester, const Size(393, 2000), _pantalla(_vacia, clave: 'tags'));

    expect(find.text('Todavía no agregaste ninguna.'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField).at(4), 'Diseño');
    await tester.pump();
    await tester.tap(find.byIcon(CupertinoIcons.add_circled_solid));
    await tester.pump();
    expect(find.text('Diseño'), findsOneWidget);

    // "diseno" sin tilde ni mayúscula es la misma etiqueta: no se duplica.
    await tester.enterText(find.byType(CupertinoTextField).at(4), 'diseno');
    await tester.pump();
    await tester.tap(find.byIcon(CupertinoIcons.add_circled_solid));
    await tester.pump();
    expect(find.text('diseno'), findsNothing);
    expect(find.text('Diseño'), findsOneWidget);
  });
}
