import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_vacante_detalle_data.dart';
import 'package:mploya/screens/empresa/empresa_vacante_detalle_screen.dart';
import 'package:mploya/screens/empresa/empresa_vacantes_data.dart';

import 'mp_golden_host.dart';

/// Golden del Detalle de Vacante (Empresa), derivado de
/// `detalle de vacantes.png` — que en el mockup es la ficha del CANDIDATO.
///
///   flutter test test/empresa_vacante_detalle_golden_test.dart --update-goldens

final _vacante = Vacante(
  id: 'job-1',
  titulo: 'Product Manager Senior',
  estado: VacanteEstado.activa,
  candidatos: 3,
  ubicacion: 'Buenos Aires, Argentina',
  salario: 'USD 3.000 – 4.500 / mes',
  jornada: 'Tiempo completo',
  modalidad: 'Híbrido',
  tags: const ['Producto', 'Analytics', 'Liderazgo', 'Roadmap'],
  creada: DateTime.now().subtract(const Duration(hours: 5)),
);

PostulanteVacante _p(String id, String nombre, String rol, {String? estado}) {
  return PostulanteVacante(
    applicationId: 'app-$id',
    candidatoId: id,
    nombre: nombre,
    headline: rol,
    tags: const ['Producto', 'Analytics'],
    estado: estado,
    postuladoEl: DateTime.now().subtract(const Duration(days: 2)),
  );
}

final _conDatos = VacanteDetalle(
  vacante: _vacante,
  descripcion: 'Buscamos un/a Product Manager Senior que lidere el ciclo de '
      'vida completo de nuestros productos digitales.',
  horario: 'Lun a Vie, 9 a 18',
  experiencia: 'Senior',
  extras: 'Prepaga familiar · 15 días libres extra',
  postulantes: [
    _p('1', 'María López', 'Product Manager', estado: 'pending'),
    _p('2', 'Juan Martín', 'Product Owner'),
    _p('3', 'Carla Méndez', 'Producto Senior'),
  ],
  entrevistas: 2,
);

final _sinPostulantes = VacanteDetalle(
  vacante: Vacante(
    id: 'job-2',
    titulo: 'Data Scientist',
    estado: VacanteEstado.pausada,
    candidatos: 0,
    creada: DateTime.now().subtract(const Duration(days: 3)),
  ),
);

Widget _pantalla(VacanteDetalle data) => EmpresaVacanteDetalleScreen(
      vacante: data.vacante,
      previewData: data,
    );

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · detalle con postulantes', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_vacante_detalle.png'),
    );
  });

  testWidgets('golden · detalle sin postulantes', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_sinPostulantes));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_vacante_detalle_vacio.png'),
    );
  });

  testWidgets('golden · detalle en 424x852', (tester) async {
    await pumpMp(tester, const Size(424, 852), _pantalla(_conDatos));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_vacante_detalle_424.png'),
    );
  });

  for (final size in mpTamanos) {
    final nombre = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_conDatos));
      expect(tester.takeException(), isNull);
    });

    testWidgets('vacío sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_sinPostulantes));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('nunca aparece la acción de candidato "Postularme"',
      (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos));
    expect(find.textContaining('Postularme'), findsNothing);
    expect(find.textContaining('Postularse'), findsNothing);
  });

  testWidgets('no se inventa match de la vacante consigo misma', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos));
    expect(find.textContaining('Match IA'), findsNothing);
  });

  testWidgets('los datos duros que la vacante no declara no se dibujan',
      (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_sinPostulantes));
    expect(find.text('Rango salarial'), findsNothing);
    expect(find.text('Horario'), findsNothing);
  });

  testWidgets('sin postulaciones ofrece la shortlist, no una lista falsa',
      (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_sinPostulantes));
    await tester.tap(find.text('Candidatos'));
    await tester.pump();
    expect(find.text('Todavía no hay postulaciones'), findsOneWidget);
    expect(find.textContaining('María'), findsNothing);
  });

  testWidgets('sin acceso a postulaciones muestra "—", no un cero',
      (tester) async {
    final sinAcceso = VacanteDetalle(
      vacante: _vacante,
      postulantesNoDisponibles: true,
    );
    await pumpMp(tester, const Size(393, 852), _pantalla(sinAcceso));
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('la vacante pausada ofrece Activar', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_sinPostulantes));
    expect(find.text('Activar'), findsOneWidget);
    expect(find.text('Pausar'), findsNothing);
  });

  testWidgets('sin estado en la base no se ofrece pausar', (tester) async {
    final sinEstado = VacanteDetalle(
      vacante: Vacante(
        id: 'job-3',
        titulo: 'QA Engineer',
        estado: VacanteEstado.desconocido,
        candidatos: 0,
      ),
    );
    await pumpMp(tester, const Size(393, 852), _pantalla(sinEstado));
    expect(find.text('Pausar'), findsNothing);
    expect(find.text('Activar'), findsNothing);
    expect(find.text('Ver shortlist'), findsOneWidget);
  });
}
