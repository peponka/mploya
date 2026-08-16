import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/headhunter/headhunter_edit_profile_screen.dart';
import 'package:mploya/screens/headhunter/headhunter_publish_job_screen.dart';
import 'package:mploya/screens/headhunter/headhunter_settings_screen.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

import 'mp_golden_host.dart';

const _profile = HeadhunterEditableProfile(
  name: 'Ana Benitez',
  headline: 'Recruiter Tech',
  about: 'Conecto equipos de producto con talento especializado.',
  location: 'Asuncion, Paraguay',
  company: 'AB Talent',
  tags: ['Tecnologia', 'Producto'],
);

const _settings = HeadhunterSettingsData(
  pushEnabled: true,
  emailEnabled: false,
  blindHiring: true,
  email: 'ana@example.test',
);

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: MpSurface(style: MpSurfaceStyle.light, child: screen),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(loadMpFonts);

  group('contratos Headhunter lote 5', () {
    test('navegacion deriva las tres rutas solo para Headhunter', () {
      final nav = File(
        'lib/navigation/main_navigation.dart',
      ).readAsStringSync();
      final profile = File(
        'lib/screens/profile_screen.dart',
      ).readAsStringSync();
      final tools = File(
        'lib/screens/headhunter/headhunter_tools_screen.dart',
      ).readAsStringSync();
      expect(nav, contains('HeadhunterPublishJobScreen'));
      expect(
        nav,
        contains('return const {0, 1, 2, 3, 5, 6, 7, 8, 9}.contains(index);'),
      );
      expect(nav, contains("child: const Text('Mis herramientas')"));
      expect(nav, contains("child: const Text('Mi perfil')"));
      expect(nav, contains(RegExp(r"case 'headhunter':\s+return 9;")));
      expect(profile, contains("type == 'headhunter'"));
      expect(profile, contains('HeadhunterEditProfileScreen'));
      expect(profile, contains('HeadhunterSettingsScreen'));
      expect(tools, contains('HeadhunterPublishJobScreen'));
      // Perfil propio se monta sin `user`; los perfiles observados siguen
      // pasando un usuario y `viewerAccountType: 'headhunter'`.
      expect(nav, contains('static const _profile = ProfileScreen();'));
      final publish = File(
        'lib/screens/headhunter/headhunter_publish_job_screen.dart',
      ).readAsStringSync();
      expect(publish, contains("'Vacante confidencial'"));
      expect(publish, isNot(contains("'client_id'")));
      expect(publish, isNot(contains("'video_url'")));
      final edit = File(
        'lib/screens/headhunter/headhunter_edit_profile_screen.dart',
      ).readAsStringSync();
      expect(edit, isNot(contains("'years_experience'")));
      expect(edit, isNot(contains("'rating'")));
    });

    testWidgets('publicar muestra solo campos soportados y valida titulo', (
      tester,
    ) async {
      await _pump(
        tester,
        HeadhunterPublishJobScreen(publishOverride: (_) async => 'job-1'),
      );
      expect(find.text('Descripción'), findsOneWidget);
      expect(find.text('Rango salarial'), findsOneWidget);
      expect(find.text('Horario'), findsOneWidget);
      expect(find.textContaining('precio'), findsNothing);
      expect(find.textContaining('alcance estimado'), findsNothing);
      expect(find.textContaining('canales sociales'), findsNothing);

      await tester.tap(find.widgetWithText(CupertinoButton, 'Publicar'));
      await tester.pump();
      expect(find.text('El título del puesto es obligatorio.'), findsOneWidget);
    });

    testWidgets('publicar envia exclusivamente parametros de la RPC real', (
      tester,
    ) async {
      Map<String, dynamic>? saved;
      await _pump(
        tester,
        HeadhunterPublishJobScreen(
          initialValues: const {
            'title': 'Flutter Developer',
            'description': 'Construir producto mobile',
            'required_tags': ['Flutter'],
          },
          publishOverride: (values) async {
            saved = values;
            return 'job-1';
          },
        ),
      );
      await tester.tap(find.widgetWithText(CupertinoButton, 'Publicar'));
      await tester.pumpAndSettle();
      expect(saved?['p_title'], 'Flutter Developer');
      expect(saved?['p_tags'], ['Flutter']);
      expect(saved?['p_lat'], isNull);
      expect(saved, isNot(contains('client_id')));
      expect(saved, isNot(contains('video_url')));
      expect(saved, isNot(contains('boost')));
    });

    testWidgets('configuracion persiste controles reales', (tester) async {
      String? column;
      bool? value;
      await _pump(
        tester,
        HeadhunterSettingsScreen(
          previewData: _settings,
          saveOverride: (nextColumn, nextValue) async {
            column = nextColumn;
            value = nextValue;
          },
        ),
      );
      expect(find.text('Notificaciones push'), findsOneWidget);
      expect(find.text('Notificaciones por email'), findsOneWidget);
      expect(find.text('Contratación a ciegas'), findsOneWidget);
      expect(find.text('Alertas de trabajo'), findsNothing);
      expect(find.text('Mploya Pro'), findsNothing);
      expect(find.text('Visibilidad de perfil'), findsNothing);

      await tester.tap(find.byType(CupertinoSwitch).first);
      await tester.pumpAndSettle();
      expect(column, 'push_enabled');
      expect(value, false);
      expect(find.text('Preferencia guardada.'), findsOneWidget);
    });

    testWidgets('configuracion restaura valor ante error real', (tester) async {
      await _pump(
        tester,
        HeadhunterSettingsScreen(
          previewData: _settings,
          saveOverride: (_, _) async => throw StateError('fallo'),
        ),
      );
      final before = tester.widget<CupertinoSwitch>(
        find.byType(CupertinoSwitch).first,
      );
      expect(before.value, true);
      await tester.tap(find.byType(CupertinoSwitch).first);
      await tester.pumpAndSettle();
      final after = tester.widget<CupertinoSwitch>(
        find.byType(CupertinoSwitch).first,
      );
      expect(after.value, true);
      expect(
        find.text('No se pudo guardar. Se restauró el valor anterior.'),
        findsOneWidget,
      );
    });

    testWidgets('editar perfil carga y guarda solo columnas reales', (
      tester,
    ) async {
      Map<String, dynamic>? saved;
      await _pump(
        tester,
        HeadhunterEditProfileScreen(
          previewData: _profile,
          saveOverride: (values) async => saved = values,
        ),
      );
      expect(find.text('Ana Benitez'), findsOneWidget);
      expect(find.text('Recruiter Tech'), findsOneWidget);
      expect(find.text('Rating'), findsNothing);
      expect(find.text('Años de experiencia'), findsNothing);

      await tester.enterText(
        find.widgetWithText(CupertinoTextField, 'Tu nombre profesional'),
        'Ana Maria Benitez',
      );
      await tester.tap(find.widgetWithText(CupertinoButton, 'Guardar cambios'));
      await tester.pumpAndSettle();
      expect(saved?['name'], 'Ana Maria Benitez');
      expect(saved?['headline'], 'Recruiter Tech');
      expect(saved, isNot(contains('rating')));
      expect(saved, isNot(contains('years_experience')));
      expect(find.text('Perfil actualizado correctamente.'), findsOneWidget);
    });

    testWidgets('editar perfil conserva cambios cuando guardar falla', (
      tester,
    ) async {
      await _pump(
        tester,
        HeadhunterEditProfileScreen(
          previewData: _profile,
          saveOverride: (_) async => throw StateError('fallo'),
        ),
      );
      await tester.enterText(
        find.widgetWithText(CupertinoTextField, 'Tu nombre profesional'),
        'Cambio pendiente',
      );
      await tester.tap(find.widgetWithText(CupertinoButton, 'Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Cambio pendiente'), findsOneWidget);
      expect(
        find.text('No se pudo guardar. Los cambios siguen en el formulario.'),
        findsOneWidget,
      );
    });

    testWidgets('sin overflow en 400 424 y 430 px', (tester) async {
      for (final width in <double>[400, 424, 430]) {
        await _pump(
          tester,
          HeadhunterPublishJobScreen(
            initialValues: const {'title': 'Flutter Developer'},
            publishOverride: (_) async => 'job-1',
          ),
          size: Size(width, 760),
        );
        await _pump(
          tester,
          const HeadhunterSettingsScreen(previewData: _settings),
          size: Size(width, 760),
        );
        await _pump(
          tester,
          const HeadhunterEditProfileScreen(previewData: _profile),
          size: Size(width, 760),
        );
      }
    });
  });

  group('capturas productivas lote 5', () {
    testWidgets('publicar vacante', (tester) async {
      await _pump(
        tester,
        HeadhunterPublishJobScreen(
          initialValues: const {
            'title': 'Senior Product Designer',
            'description':
                'Diseñar experiencias mobile junto al equipo de producto.',
            'salary_range': 'USD 2.500 - 3.200',
            'schedule': 'Lunes a viernes',
            'required_tags': ['Figma', 'Research'],
            'employment_type': 'Completa',
            'experience_level': 'Se valora',
          },
          publishOverride: (_) async => 'job-1',
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/14_publicar_vacante_final.png'),
      );
    });

    testWidgets('publicar validacion', (tester) async {
      await _pump(
        tester,
        HeadhunterPublishJobScreen(publishOverride: (_) async => 'job-1'),
      );
      await tester.tap(find.widgetWithText(CupertinoButton, 'Publicar'));
      await tester.pump();
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile(
          'goldens/headhunter/14_publicar_vacante_validacion_final.png',
        ),
      );
    });

    testWidgets('configuracion', (tester) async {
      await _pump(
        tester,
        const HeadhunterSettingsScreen(previewData: _settings),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/15_configuracion_final.png'),
      );
    });

    testWidgets('editar perfil', (tester) async {
      await _pump(
        tester,
        const HeadhunterEditProfileScreen(previewData: _profile),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/16_editar_perfil_final.png'),
      );
    });

    testWidgets('editar perfil error', (tester) async {
      await _pump(
        tester,
        HeadhunterEditProfileScreen(
          previewData: _profile,
          saveOverride: (_) async => throw StateError('fallo'),
        ),
      );
      await tester.tap(find.widgetWithText(CupertinoButton, 'Guardar cambios'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile(
          'goldens/headhunter/16_editar_perfil_error_final.png',
        ),
      );
    });
  });
}
