import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/models/models.dart';
import 'package:mploya/screens/empresa/empresa_candidato_data.dart';
import 'package:mploya/screens/empresa/empresa_candidato_perfil_screen.dart';

import 'mp_golden_host.dart';

/// Golden del Perfil de Candidato visto por Empresa, reconstruido de
/// `perfil de candidato.png` (Pantalla 7).
///
///   flutter test test/empresa_candidato_perfil_golden_test.dart --update-goldens

final _completo = CandidatoPerfil(
  usuario: NexUser(
    id: 'c1',
    name: 'Camila Rodríguez',
    headline: 'UX/UI Designer',
    location: 'Buenos Aires, Argentina',
    about: 'Diseñadora UX/UI con experiencia creando productos digitales '
        'intuitivos y centrados en las personas.',
    tags: const ['Figma', 'UI Design', 'UX Research', 'Prototipado'],
    isOpenToWork: true,
    isVerified: true,
    salaryExpectation: 'USD 2.500 – 3.200',
    ratingStars: 4.8,
    ratingCount: 12,
    experience: const [
      Experience(
        role: 'Senior UX/UI Designer',
        company: 'StartSoft',
        duration: '2022 – Actualidad',
        description: 'Lidero el diseño de productos SaaS para LATAM.',
      ),
    ],
    education: const [
      Education(
        school: 'Universidad de Buenos Aires',
        degree: 'Licenciatura en Diseño Multimedia',
        years: '2016 – 2019',
      ),
    ],
  ),
  guardado: true,
  match: 92,
  vacanteTitulo: 'Product Manager Senior',
);

const _minimo = CandidatoPerfil(
  usuario: NexUser(id: 'c2', name: 'Juan Martín', headline: ''),
);

const _confidencial = CandidatoPerfil(
  usuario: NexUser(
    id: 'c3',
    name: 'Nombre Real Oculto',
    headline: 'Senior Product Manager',
    accountType: 'confidencial',
    tags: ['Producto', 'Estrategia'],
  ),
);

Widget _pantalla(CandidatoPerfil data, {String clave = 'perfil'}) =>
    EmpresaCandidatoPerfilScreen(
      key: ValueKey(clave),
      candidatoId: data.usuario.id,
      previewData: data,
    );

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · perfil completo', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_completo));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_candidato_perfil.png'),
    );
  });

  testWidgets('golden · perfil sin completar', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_minimo));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_candidato_perfil_vacio.png'),
    );
  });

  testWidgets('golden · perfil confidencial', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_confidencial));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_candidato_perfil_confidencial.png'),
    );
  });

  for (final size in mpTamanos) {
    final nombre = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_completo));
      expect(tester.takeException(), isNull);
    });

    testWidgets('mínimo sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_minimo, clave: 'min-$nombre'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('el confidencial no expone nombre ni permite compartir',
      (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_confidencial));
    expect(find.text('Nombre Real Oculto'), findsNothing);
    expect(find.text('Candidato confidencial'), findsWidgets);
    expect(find.text('Compartir'), findsNothing);
  });

  testWidgets('sin match no se dibuja el anillo', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_minimo));
    expect(find.text('Match'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('con match muestra el número real de la vacante', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_completo));
    // Una sola vez: el anillo vive en el héroe y el bloque de vacante explica,
    // no repite el número.
    expect(find.text('92%'), findsOneWidget);
    expect(find.textContaining('Product Manager Senior'), findsWidgets);
  });

  testWidgets('el perfil sin datos lo dice en vez de fingir secciones',
      (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_minimo));
    expect(find.text('Perfil sin completar'), findsOneWidget);
    expect(find.text('Skills principales'), findsNothing);
    expect(find.text('Experiencia'), findsNothing);
    expect(find.text('Educación'), findsNothing);
  });

  testWidgets('no se inventan campos que users no tiene', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_completo));
    for (final inventado in ['Idiomas', 'Modalidad', 'km de vos']) {
      expect(find.textContaining(inventado), findsNothing, reason: inventado);
    }
  });

  testWidgets('el estado guardado se refleja en la acción', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_completo));
    expect(find.text('Guardado'), findsOneWidget);

    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(_minimo, clave: 'no-guardado'),
    );
    expect(find.text('Guardar'), findsOneWidget);
  });
}
