import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/preferencias_laborales_screen.dart';

import 'mp_golden_host.dart';

/// CANDIDATO — TANDA 4: Preferencias Laborales.
///
/// El riesgo real de esta pantalla es de DATOS, no sólo de layout: lee y
/// reescribe `users.about`, que el wizard congelado (Tanda 1) también usa
/// para Portfolio:/Certificaciones:/Experiencia clave:/Educacion:. Estos
/// tests verifican que esos bloques ajenos sobreviven intactos al abrir la
/// pantalla con datos previos (no se prueba el guardado real porque no hay
/// Supabase en el test, pero sí que la pantalla no descarta lo que no
/// entiende al cargarlo).
const _destino = 'design-reference/Candidato_Tanda1_Productivo_Final/preferencias_laborales';

const _aboutConTodo =
    'Diseño experiencias digitales con foco en conversión.\n\n'
    'Idiomas: Español nativo, Inglés C1\n\n'
    'Portfolio: https://miportfolio.com\n\n'
    'Certificaciones: Scrum Fundamentals\n\n'
    'Preferencias: Remoto, Full Time\n\n'
    'Experiencia clave:\nSenior Product Designer · Uala · 2022-Actual';

Future<void> _montar(WidgetTester tester, PreferenciasPreviewData data) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: PreferenciasLaboralesScreen(previewData: data),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 32));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async {
    await loadMpFonts();
  });

  group('parseAboutPreferencias / rebuildAboutWithPreferencias (sin Supabase)', () {
    test('preserva Portfolio/Certificaciones/Experiencia al reescribir Idiomas y Preferencias', () {
      final parsed = parseAboutPreferencias(_aboutConTodo);
      expect(parsed.idiomas, 'Español nativo, Inglés C1');
      expect(parsed.modalidad, {'Remoto', 'Full Time'});
      expect(parsed.otrosParrafos, contains('Diseño experiencias digitales con foco en conversión.'));
      expect(parsed.otrosParrafos, contains('Portfolio: https://miportfolio.com'));
      expect(parsed.otrosParrafos, contains('Certificaciones: Scrum Fundamentals'));
      expect(
        parsed.otrosParrafos,
        contains('Experiencia clave:\nSenior Product Designer · Uala · 2022-Actual'),
      );

      // Simula guardar cambiando SOLO idiomas y modalidad.
      final nuevoAbout = rebuildAboutWithPreferencias(
        otrosParrafos: parsed.otrosParrafos,
        idiomas: 'Español nativo, Inglés C1, Portugués básico',
        modalidad: {'Hibrido'},
      );

      // Lo que no se tocó sigue presente tal cual.
      expect(nuevoAbout, contains('Diseño experiencias digitales con foco en conversión.'));
      expect(nuevoAbout, contains('Portfolio: https://miportfolio.com'));
      expect(nuevoAbout, contains('Certificaciones: Scrum Fundamentals'));
      expect(nuevoAbout, contains('Experiencia clave:\nSenior Product Designer · Uala · 2022-Actual'));
      // Lo que sí se tocó refleja el nuevo valor, no el viejo.
      expect(nuevoAbout, contains('Idiomas: Español nativo, Inglés C1, Portugués básico'));
      expect(nuevoAbout, contains('Preferencias: Hibrido'));
      expect(nuevoAbout, isNot(contains('Preferencias: Remoto, Full Time')));

      // Y el resultado vuelve a parsear igual de bien (round-trip estable).
      final reparsed = parseAboutPreferencias(nuevoAbout);
      expect(reparsed.idiomas, 'Español nativo, Inglés C1, Portugués básico');
      expect(reparsed.modalidad, {'Hibrido'});
    });

    test('about vacío no rompe nada', () {
      final parsed = parseAboutPreferencias('');
      expect(parsed.idiomas, isEmpty);
      expect(parsed.modalidad, isEmpty);
      expect(parsed.otrosParrafos, isEmpty);

      final about = rebuildAboutWithPreferencias(
        otrosParrafos: parsed.otrosParrafos,
        idiomas: '',
        modalidad: {},
      );
      expect(about, isEmpty);
    });

    test('primera vez que se agregan Idiomas/Preferencias no toca "Sobre mí" ni el resto', () {
      const aboutSinPreferencias =
          'Apasionado por crear experiencias digitales que generan impacto.\n\n'
          'Portfolio: https://miportfolio.com\n\n'
          'Certificaciones: Scrum Fundamentals, Google Analytics\n\n'
          'Experiencia clave:\nSenior Product Designer · Uala · 2022-Actual\n'
          'UX Designer · Globant · 2020-2022\n\n'
          'Educacion:\nLic. en Marketing · UCA · 2018-2022';

      final parsed = parseAboutPreferencias(aboutSinPreferencias);
      expect(parsed.idiomas, isEmpty);
      expect(parsed.modalidad, isEmpty);
      // Los 5 bloques ajenos (sobre mí + 4 más) llegan intactos como "otros".
      expect(parsed.otrosParrafos, hasLength(5));

      final about = rebuildAboutWithPreferencias(
        otrosParrafos: parsed.otrosParrafos,
        idiomas: 'Inglés B2',
        modalidad: {'Remoto'},
      );

      expect(about, contains('Apasionado por crear experiencias digitales que generan impacto.'));
      expect(about, contains('Portfolio: https://miportfolio.com'));
      expect(about, contains('Certificaciones: Scrum Fundamentals, Google Analytics'));
      expect(
        about,
        contains('Experiencia clave:\nSenior Product Designer · Uala · 2022-Actual\nUX Designer · Globant · 2020-2022'),
      );
      expect(about, contains('Educacion:\nLic. en Marketing · UCA · 2018-2022'));
      expect(about, contains('Idiomas: Inglés B2'));
      expect(about, contains('Preferencias: Remoto'));
    });

    test('borrar Idiomas/Preferencias no deja líneas vacías ni basura', () {
      final parsed = parseAboutPreferencias(_aboutConTodo);
      final about = rebuildAboutWithPreferencias(
        otrosParrafos: parsed.otrosParrafos,
        idiomas: '', // el usuario borró el campo
        modalidad: {}, // deseleccionó todas las chips
      );
      expect(about, isNot(contains('Idiomas:')));
      expect(about, isNot(contains('Preferencias:')));
      // Pero el resto sigue ahí — borrar preferencias no borra el perfil.
      expect(about, contains('Portfolio: https://miportfolio.com'));
      expect(about, contains('Certificaciones: Scrum Fundamentals'));
      expect(about, contains('Experiencia clave:\nSenior Product Designer · Uala · 2022-Actual'));
    });

    test('múltiples ediciones seguidas no duplican ni acumulan versiones viejas', () {
      var about = _aboutConTodo;

      // Edición 1: cambia idiomas.
      var parsed = parseAboutPreferencias(about);
      about = rebuildAboutWithPreferencias(
        otrosParrafos: parsed.otrosParrafos,
        idiomas: 'Español nativo',
        modalidad: parsed.modalidad,
      );

      // Edición 2: cambia modalidad.
      parsed = parseAboutPreferencias(about);
      about = rebuildAboutWithPreferencias(
        otrosParrafos: parsed.otrosParrafos,
        idiomas: parsed.idiomas,
        modalidad: {'Presencial', 'Viajes'},
      );

      // Edición 3: vuelve a cambiar idiomas.
      parsed = parseAboutPreferencias(about);
      about = rebuildAboutWithPreferencias(
        otrosParrafos: parsed.otrosParrafos,
        idiomas: 'Español nativo, Inglés avanzado',
        modalidad: parsed.modalidad,
      );

      // Sólo debe existir UNA línea de cada tipo, con el valor final.
      expect('Idiomas:'.allMatches(about).length, 1);
      expect('Preferencias:'.allMatches(about).length, 1);
      expect(about, contains('Idiomas: Español nativo, Inglés avanzado'));
      expect(about, contains('Preferencias: Presencial, Viajes'));
      // Ningún valor intermedio quedó pegado en otro lado.
      expect(about, isNot(contains('Remoto, Full Time')));
      expect(about, isNot(contains('Idiomas: Español nativo\n')));
      // Y los bloques ajenos, después de 3 ediciones, siguen intactos.
      expect(about, contains('Portfolio: https://miportfolio.com'));
      expect(about, contains('Certificaciones: Scrum Fundamentals'));
      expect(about, contains('Experiencia clave:\nSenior Product Designer · Uala · 2022-Actual'));
    });
  });

  testWidgets('monta sin overflow y sin excepción', (tester) async {
    await _montar(
      tester,
      const PreferenciasPreviewData(
        about: _aboutConTodo,
        city: 'Asunción, Paraguay',
        salaryExpectation: 'USD 2.500 - 3.500 / mes',
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Preferencias laborales'), findsOneWidget);
  });

  testWidgets('parsea Idiomas, Preferencias y ciudad/país reales del about existente', (tester) async {
    await _montar(
      tester,
      const PreferenciasPreviewData(about: _aboutConTodo, city: 'Asunción, Paraguay'),
    );
    expect(tester.takeException(), isNull);

    // El campo de idiomas se prellena con lo que ya había en `about`.
    final idiomasField = tester.widget<CupertinoTextField>(
      find.byWidgetPredicate(
        (w) => w is CupertinoTextField && w.placeholder == 'Español nativo, Inglés C1, Portugués intermedio',
      ),
    );
    expect(idiomasField.controller?.text, 'Español nativo, Inglés C1');

    // Ciudad y país separados correctamente desde "Asunción, Paraguay".
    final ciudadField = tester.widget<CupertinoTextField>(
      find.byWidgetPredicate((w) => w is CupertinoTextField && w.placeholder == 'Ciudad'),
    );
    expect(ciudadField.controller?.text, 'Asunción');
    final paisField = tester.widget<CupertinoTextField>(
      find.byWidgetPredicate((w) => w is CupertinoTextField && w.placeholder == 'País'),
    );
    expect(paisField.controller?.text, 'Paraguay');

    // Las chips de modalidad reflejan lo que ya había en "Preferencias:".
    expect(find.text('Remoto'), findsOneWidget);
    expect(find.text('Full Time'), findsOneWidget);
  });

  testWidgets('no ofrece controles falsos de radio/industrias/disponibilidad', (tester) async {
    await _montar(tester, const PreferenciasPreviewData());
    expect(tester.takeException(), isNull);
    // El aviso vive al final del formulario — hay que scrollear para
    // materializarlo (virtualización normal de `ListView`, no es un bug).
    await tester.scrollUntilVisible(
      find.textContaining('todavía no se guardan'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    // Sin campo editable con esos labels — no hay sección propia para ellos.
    expect(find.text('Radio de búsqueda'), findsNothing);
    expect(find.text('Industrias de interés'), findsNothing);
    expect(find.text('Disponibilidad'), findsNothing);
    // El único rastro permitido es el aviso honesto de que no se guardan.
    expect(find.textContaining('todavía no se guardan'), findsOneWidget);
  });

  testWidgets('captura final — mobile 390x844', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: RepaintBoundary(
            key: key,
            child: const PreferenciasLaboralesScreen(
              previewData: PreferenciasPreviewData(
                about: _aboutConTodo,
                city: 'Asunción, Paraguay',
                salaryExpectation: 'USD 2.500 - 3.500 / mes',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_destino/mobile.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
