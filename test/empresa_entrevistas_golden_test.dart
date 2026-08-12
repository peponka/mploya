import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_entrevistas_data.dart';
import 'package:mploya/screens/empresa/empresa_entrevistas_screen.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

import 'mp_golden_host.dart';

/// Golden de Entrevistas / Agenda (Empresa móvil), derivado de
/// `agenda inteligente.png` y `entrevistas nuevas.png`.
///
///   flutter test test/empresa_entrevistas_golden_test.dart --update-goldens

/// Día fijo para que el golden no dependa de cuándo corre el test.
final _dia = DateTime(2026, 8, 12);

EntrevistaEmpresa _agendada(
  String id,
  String nombre,
  String rol,
  int hora, {
  String estado = 'confirmed',
  String? url,
}) {
  return EntrevistaEmpresa(
    id: id,
    fuente: FuenteEntrevista.agenda,
    candidatoId: id,
    candidato: nombre,
    candidatoHeadline: rol,
    cuando: DateTime(_dia.year, _dia.month, _dia.day, hora, 30),
    duracionMinutos: 45,
    estado: estado,
    meetingUrl: url,
  );
}

final _conDatos = EntrevistasData(
  agenda: [
    _agendada('1', 'Juan Pérez', 'Product Designer', 9,
        url: 'https://meet.example.com/abc'),
    _agendada('2', 'Camila Rodríguez', 'UX/UI Designer', 11),
    _agendada('3', 'Fernando López', 'Frontend Developer', 15,
        estado: 'pending'),
  ],
  conIa: const [
    EntrevistaEmpresa(
      id: 'ia-1',
      fuente: FuenteEntrevista.ia,
      candidatoId: '9',
      candidato: 'Lucas Fernández',
      candidatoHeadline: 'Data Scientist',
      vacante: 'Data Scientist',
      estado: 'completed',
    ),
    EntrevistaEmpresa(
      id: 'ia-2',
      fuente: FuenteEntrevista.ia,
      candidatoId: '10',
      candidato: 'Mariana López',
      vacante: 'Product Manager Senior',
      estado: 'pending',
    ),
  ],
);

/// La clave evita que dos `pumpWidget` seguidos dentro del mismo test reusen el
/// State anterior (mismo runtimeType) y se queden con los datos viejos.
Widget _pantalla(EntrevistasData data, {String clave = 'entrevistas'}) =>
    EmpresaEntrevistasScreen(
      key: ValueKey(clave),
      previewData: data,
      diaInicial: _dia,
    );

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · agenda con entrevistas', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos),
        bottomNav: true);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_entrevistas.png'),
    );
  });

  testWidgets('golden · agenda vacía', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(EntrevistasData.empty),
        bottomNav: true);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_entrevistas_vacia.png'),
    );
  });

  testWidgets('golden · agenda en 424x852', (tester) async {
    await pumpMp(tester, const Size(424, 852), _pantalla(_conDatos),
        bottomNav: true);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_entrevistas_424.png'),
    );
  });

  for (final size in mpTamanos) {
    final nombre = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(_conDatos), bottomNav: true);
      expect(tester.takeException(), isNull);
    });

    testWidgets('vacía sin overflow en $nombre', (tester) async {
      await pumpMp(tester, size, _pantalla(EntrevistasData.empty),
          bottomNav: true);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sin entrevistas no se inventa ninguna', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(EntrevistasData.empty));
    expect(
      find.text('Todavía no tenés entrevistas agendadas'),
      findsOneWidget,
    );
    expect(find.textContaining('Juan Pérez'), findsNothing);
  });

  testWidgets('no se promete lo que no existe', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos));
    for (final inventado in [
      'Google Calendar',
      'Outlook Calendar',
      'Optimizar mi agenda',
      'Sincronización',
    ]) {
      expect(find.text(inventado), findsNothing, reason: inventado);
    }
  });

  testWidgets('sólo hay botón de unirse si hay link real', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos));
    // Una sola de las tres entrevistas del día tiene meeting_url.
    expect(find.text('Unirse'), findsOneWidget);
  });

  testWidgets('la agenda rota se distingue de la agenda vacía', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(
        const EntrevistasData(agendaNoDisponible: true),
        clave: 'agenda-rota',
      ),
    );
    expect(find.text('No pudimos leer la agenda'), findsOneWidget);

    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(
        const EntrevistasData(agendaNoDisponible: true, iaNoDisponible: true),
        clave: 'todo-roto',
      ),
    );
    expect(find.text('No pudimos cargar las entrevistas'), findsOneWidget);
  });

  testWidgets('las métricas salen de las filas reales', (tester) async {
    expect(_conDatos.del(_dia).length, 3);
    expect(_conDatos.del(_dia.add(const Duration(days: 1))), isEmpty);
    expect(_conDatos.agenda.where((e) => e.cancelada), isEmpty);
  });

  testWidgets('empujada desde Herramientas ofrece salida', (tester) async {
    // Por ícono solo no alcanza: la tira de semana usa el mismo chevron para
    // retroceder de semana. El botón de volver es el único que es MpIconButton.
    final volver =
        find.widgetWithIcon(MpIconButton, CupertinoIcons.chevron_left);

    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos));
    expect(volver, findsNothing);

    await tester.pumpWidget(
      CupertinoApp(
        home: MpSurface(
          style: MpSurfaceStyle.light,
          child: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => _pantalla(_conDatos)),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(volver, findsOneWidget);
    await tester.tap(volver);
    await tester.pumpAndSettle();
    expect(find.text('Entrevistas'), findsNothing);
  });

  testWidgets('sin fuente de IA no se muestra su sección', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(EntrevistasData(agenda: _conDatos.agenda)),
    );
    expect(find.text('Entrevistas con IA'), findsNothing);
  });
}
