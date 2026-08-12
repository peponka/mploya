import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/models/models.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';
import 'package:mploya/widgets/empresa/talent_reel_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Renderiza el reel del Feed de Talento de Empresa para compararlo con
/// `video pantalla completa candidato.png`.
///
/// El video no se reproduce en un widget test, así que se ve el fondo de
/// respaldo. Lo que se valida acá es la CAPA DE INTERFAZ: barra superior, riel
/// de acciones del recruiter, bloque de datos del candidato y tarjeta de
/// contexto de vacante.
///
///   flutter test test/empresa_feed_golden_test.dart --update-goldens

Future<void> _loadFonts() async {
  final sdkFonts = Directory(
    '${Directory.current.path}/.flutter-sdk/bin/cache/artifacts/material_fonts',
  );
  if (!sdkFonts.existsSync()) return;

  final roboto = File('${sdkFonts.path}/roboto-regular.ttf');
  if (roboto.existsSync()) {
    final bytes = roboto.readAsBytesSync().buffer.asByteData();
    for (final family in [
      'Roboto',
      '.SF Pro Text',
      '.SF Pro Display',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
    ]) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
  }

  final iconFont = File(
    '${Platform.environment['LOCALAPPDATA']}'
    r'\Pub\Cache\hosted\pub.dev\cupertino_icons-1.0.8\assets\CupertinoIcons.ttf',
  );
  if (iconFont.existsSync()) {
    final bytes = iconFont.readAsBytesSync().buffer.asByteData();
    for (final family in [
      'CupertinoIcons',
      'packages/cupertino_icons/CupertinoIcons',
    ]) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
  }
}

/// Candidato de MUESTRA — vive sólo en este test, la app nunca lo usa.
const _candidate = NexUser(
  id: 'preview-1',
  name: 'Camila Rodríguez',
  headline: 'UX/UI Designer',
  location: 'Buenos Aires, Argentina',
  about:
      'Me apasiona diseñar experiencias digitales que conecten personas con '
      'productos que realmente resuelvan problemas.',
  isVerified: true,
  isOpenToWork: true,
  accountType: 'candidato',
  tags: ['Figma', 'UI Design', 'UX Research', 'Prototipado', 'Design System',
      'Testing', 'Remoto'],
  experience: [
    Experience(
      role: 'Senior Designer',
      company: 'NovaSoft',
      duration: '2022 - hoy',
    ),
    Experience(
      role: 'Designer',
      company: 'TechPro',
      duration: '2020 - 2022',
    ),
  ],
);

Widget _host({
  required Size size,
  int? match,
  String? jobTitle,
  String? jobMeta,
}) {
  return CupertinoApp(
    debugShowCheckedModeBanner: false,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: ColoredBox(
        color: MpTokens.darkBg,
        child: Column(
          children: [
            Expanded(
              child: TalentReelCard(
                candidate: _candidate,
                isActive: false,
                screenVisible: false,
                muted: false,
                matchPercentage: match,
                selectedJobTitle: jobTitle,
                selectedJobMeta: jobMeta,
                onSelectJob: () {},
              ),
            ),
            MpBottomNav(
              items: MpRole.empresa.navItems(unreadMessages: 3),
              currentIndex: -1,
              onTap: (_) {},
              onCenterTap: () {},
              centerLabel: MpRole.empresa.centerLabel,
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Size size, Widget widget) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    SharedPreferences.setMockInitialValues({});
    // Cliente local de mentira: el reel consulta `saved_profiles` al montarse y
    // sin cliente inicializado la llamada lanzaría.
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });

  testWidgets('golden · feed talento con vacante elegida (393x852)',
      (tester) async {
    await _pump(
      tester,
      const Size(393, 852),
      _host(
        size: const Size(393, 852),
        match: 96,
        jobTitle: 'UX/UI Designer Senior',
        jobMeta: 'Remoto · Buenos Aires',
      ),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_feed_con_vacante.png'),
    );
  });

  testWidgets('golden · feed talento SIN vacante elegida (393x852)',
      (tester) async {
    await _pump(
      tester,
      const Size(393, 852),
      _host(size: const Size(393, 852)),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/empresa_feed_sin_vacante.png'),
    );
  });

  // Barrido de anchos: los cuatro tamaños que hay que verificar.
  for (final width in [400.0, 424.0, 430.0]) {
    testWidgets('golden · feed talento en ${width.toInt()}px', (tester) async {
      final size = Size(width, 900);
      await _pump(
        tester,
        size,
        _host(
          size: size,
          match: 96,
          jobTitle: 'UX/UI Designer Senior',
          jobMeta: 'Remoto · Buenos Aires',
        ),
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_feed_${width.toInt()}.png'),
      );
    });
  }

  // El caso sin vacante es el que más texto mete en la tarjeta: se verifica
  // que no desborde en ninguno de los anchos.
  for (final width in [393.0, 400.0, 424.0, 430.0]) {
    testWidgets('sin vacante no desborda en ${width.toInt()}px', (tester) async {
      final size = Size(width, 900);
      await _pump(tester, size, _host(size: size));
      expect(tester.takeException(), isNull);
      expect(find.text('Seleccionar vacante'), findsOneWidget);
    });
  }

  // ── Alturas reducidas ──────────────────────────────────────────────────────
  // El riel necesita ~546pt y antes se salía por arriba en pantallas bajas.
  // Estas son las alturas donde el bug aparecía.
  for (final size in [
    Size(393, 667), // iPhone SE de alto
    Size(375, 667), // iPhone SE completo
    Size(424, 651), // DevTools acoplado abajo
    Size(393, 560), // teclado abierto: caso extremo
  ]) {
    testWidgets(
      'el riel entra en ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await _pump(
          tester,
          size,
          _host(size: size, match: 96, jobTitle: 'UX/UI Designer Senior'),
        );
        expect(tester.takeException(), isNull);
        // Las seis acciones siguen presentes: se comprime, no se recorta.
        for (final label in ['Match IA', 'Guardar', 'Mensaje', 'Invitar',
            'Interesado', 'Compartir']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
      },
    );
  }

  testWidgets('en 393x852 el riel NO se escala (pantalla aprobada intacta)',
      (tester) async {
    const size = Size(393, 852);
    await _pump(
      tester,
      size,
      _host(size: size, match: 96, jobTitle: 'UX/UI Designer Senior'),
    );

    // El botón "Interesado" mide 54pt de lado en el diseño aprobado. Si el
    // FittedBox estuviera comprimiendo, mediría menos.
    final interesado = find.ancestor(
      of: find.text('Interesado'),
      matching: find.byType(Column),
    );
    final circulo = tester.getSize(
      find
          .descendant(of: interesado.first, matching: find.byType(Container))
          .first,
    );
    expect(circulo.width, closeTo(54, 0.5));
    expect(circulo.height, closeTo(54, 0.5));
  });

  testWidgets('sin vacante NO se muestra ningún porcentaje', (tester) async {
    await _pump(
      tester,
      const Size(393, 852),
      _host(size: const Size(393, 852)),
    );
    expect(find.text('Elegí vacante'), findsOneWidget);
    expect(find.text('Match IA'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('el feed de Empresa no ofrece Postularme ni Ver vacante',
      (tester) async {
    await _pump(
      tester,
      const Size(393, 852),
      _host(
        size: const Size(393, 852),
        match: 96,
        jobTitle: 'UX/UI Designer Senior',
      ),
    );
    expect(find.textContaining('Postular'), findsNothing);
    expect(find.text('Ver vacante'), findsNothing);
    // Las acciones del recruiter sí están.
    for (final label in ['Guardar', 'Mensaje', 'Invitar', 'Interesado']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
