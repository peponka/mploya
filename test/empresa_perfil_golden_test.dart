import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/models/models.dart';
import 'package:mploya/screens/empresa/empresa_perfil_data.dart';
import 'package:mploya/screens/empresa/empresa_perfil_screen.dart';
import 'package:mploya/screens/empresa/empresa_vacantes_data.dart';

import 'mp_golden_host.dart';

/// Golden del Perfil de Empresa, derivado de `perfil empresa premium.png` (39),
/// que en el mockup está escrito desde el lado del candidato.
///
///   flutter test test/empresa_perfil_golden_test.dart --update-goldens

final _vacantes = [
  Vacante(
    id: 'j1',
    titulo: 'Product Manager Senior',
    estado: VacanteEstado.activa,
    candidatos: 3,
    ubicacion: 'Buenos Aires, Argentina',
    modalidad: 'Híbrido',
    tags: const ['Producto', 'Analytics'],
    creada: DateTime.now().subtract(const Duration(days: 2)),
  ),
  Vacante(
    id: 'j2',
    titulo: 'Desarrollador Flutter',
    estado: VacanteEstado.pausada,
    candidatos: 1,
    modalidad: 'Remoto',
    tags: const ['Flutter', 'Producto'],
    creada: DateTime.now().subtract(const Duration(days: 9)),
  ),
];

final _completo = PerfilEmpresa(
  empresa: const NexUser(
    id: 'e1',
    name: 'NovaTech',
    headline: 'Tecnología que impulsa el futuro',
    about: 'Creamos soluciones SaaS que ayudan a empresas de todo el mundo a '
        'ser más productivas.',
    location: 'Buenos Aires, Argentina',
    accountType: 'empresa',
    isVerified: true,
    ratingStars: 4.8,
    ratingCount: 12,
  ),
  vacantes: _vacantes,
  postulaciones: 4,
);

const _incompleto = PerfilEmpresa(
  empresa: NexUser(
    id: 'e2',
    name: 'Mi Empresa',
    headline: '',
    accountType: 'empresa',
  ),
);

Widget _pantalla(PerfilEmpresa data, {String clave = 'perfil-empresa'}) =>
    EmpresaPerfilScreen(key: ValueKey(clave), previewData: data);

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · perfil completo', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_completo));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_perfil.png'),
    );
  });

  testWidgets('golden · perfil incompleto y sin vacantes', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(_incompleto, clave: 'incompleto'));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_perfil_incompleto.png'),
    );
  });

  testWidgets('golden · perfil en 424x852', (tester) async {
    await pumpMp(tester, const Size(424, 852), _pantalla(_completo));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_perfil_424.png'),
    );
  });

  for (final size in mpTamanos) {
    final nombre = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_completo));
      expect(tester.takeException(), isNull);
    });

    testWidgets('incompleto sin overflow en $nombre', (tester) async {
      await pumpMp(
        tester,
        size,
        _pantalla(_incompleto, clave: 'inc-$nombre'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no se inventan datos que users no guarda', (tester) async {
    await pumpMp(tester, const Size(393, 1800), _pantalla(_completo));
    for (final inventado in [
      'empleados',
      'crecimiento anual',
      'Fundada en',
      'Cultura & Ambiente',
      'Beneficios destacados',
      'Oficinas',
    ]) {
      expect(find.textContaining(inventado), findsNothing, reason: inventado);
    }
  });

  testWidgets('sin reseñas no se muestra valoración', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(_incompleto, clave: 'sin-resenas'),
    );
    expect(find.text('Valoración'), findsNothing);
  });

  testWidgets('con reseñas reales sí se muestra', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_completo));
    expect(find.text('Valoración'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
  });

  testWidgets('el perfil incompleto avisa en vez de disimular',
      (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(_incompleto, clave: 'aviso'),
    );
    expect(find.text('Tu perfil está incompleto'), findsOneWidget);
    expect(find.text('Todavía no publicaste vacantes'), findsOneWidget);
  });

  testWidgets('los sectores salen de las etiquetas reales de las vacantes',
      (tester) async {
    // Producto aparece en las dos vacantes; Flutter y Analytics en una.
    expect(_completo.sectores.first, 'Producto');
    expect(_completo.sectores.contains('Flutter'), isTrue);
    expect(_completo.vacantesActivas, 1);
  });
}
