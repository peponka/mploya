import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/headhunter/headhunter_clients_screen.dart';
import 'package:mploya/screens/headhunter/headhunter_dashboard_screen.dart';
import 'package:mploya/screens/headhunter/headhunter_talent_pool_screen.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

import 'mp_golden_host.dart';

const _jobs = [
  {
    'id': 'job-1',
    'title': 'Senior Product Designer',
    'status': 'active',
    'created_at': '2026-08-14T12:00:00Z',
  },
  {
    'id': 'job-2',
    'title': 'Flutter Developer',
    'status': 'active',
    'created_at': '2026-08-13T12:00:00Z',
  },
];

const _applications = [
  {'job_id': 'job-1', 'status': 'applied'},
  {'job_id': 'job-1', 'status': 'interview'},
  {'job_id': 'job-2', 'status': 'hired'},
];

const _interviews = [
  {'id': 'interview-1', 'job_id': 'job-1', 'status': 'scheduled'},
];

Map<String, dynamic> _talent({
  String id = 'candidate-1',
  String name = 'Lucia Benitez',
  String type = 'candidato',
}) {
  return {
    'pin_id': id,
    'pin_name': name,
    'pin_headline': 'Product Designer',
    'pin_type': type,
    'avatar_url': '',
    'distance_km': 12.4,
  };
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  const size = Size(393, 852);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: const MediaQueryData(size: size),
        child: MpSurface(style: MpSurfaceStyle.light, child: screen),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(loadMpFonts);

  group('contratos Headhunter lote 3', () {
    test('la navegación usa pantallas específicas del rol', () {
      final source = File(
        'lib/navigation/main_navigation.dart',
      ).readAsStringSync();
      expect(source, contains('_headhunterDashboard'));
      expect(source, contains('_headhunterClients'));
      expect(source, contains('_headhunterTalentPool'));
      expect(
        source,
        isNot(contains("_accountType == 'headhunter' ? _atsDashboard")),
      );
      expect(source, contains("Text('Publicar vacante')"));
    });

    testWidgets('dashboard muestra sólo conteos derivados', (tester) async {
      await _pump(
        tester,
        const HeadhunterDashboardScreen(
          previewData: HeadhunterDashboardData(
            name: 'Ana Belen',
            jobs: _jobs,
            applications: _applications,
            interviews: _interviews,
          ),
        ),
      );

      expect(find.text('2'), findsWidgets);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('NovaTech'), findsNothing);
      expect(find.text('156'), findsNothing);
      expect(find.textContaining('Camila Rodriguez'), findsNothing);
    });

    testWidgets('clientes no inventa empresas ni alta funcional', (
      tester,
    ) async {
      await _pump(tester, const HeadhunterClientsScreen());

      expect(find.text('Sin clientes conectados'), findsOneWidget);
      expect(find.textContaining('Agregar cliente'), findsNothing);
      expect(find.text('TechPro'), findsNothing);
      expect(find.text('NovaSoft'), findsNothing);
    });

    testWidgets('talent pool excluye variantes confidenciales', (tester) async {
      await _pump(
        tester,
        HeadhunterTalentPoolScreen(
          previewRows: [
            _talent(),
            _talent(id: 'candidate-2', name: 'Nombre Real A', type: 'stealth'),
            _talent(
              id: 'candidate-3',
              name: 'Nombre Real B',
              type: 'confidential',
            ),
            _talent(
              id: 'candidate-4',
              name: 'Nombre Real C',
              type: 'confidencial_premium',
            ),
          ],
        ),
      );

      expect(find.text('Lucia Benitez'), findsOneWidget);
      expect(find.textContaining('Nombre Real'), findsNothing);
      expect(find.textContaining('match'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('capturas productivas', () {
    testWidgets('dashboard normal', (tester) async {
      await _pump(
        tester,
        const HeadhunterDashboardScreen(
          previewData: HeadhunterDashboardData(
            name: 'Ana Belen',
            jobs: _jobs,
            applications: _applications,
            interviews: _interviews,
          ),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/08_dashboard_final.png'),
      );
    });

    testWidgets('dashboard vacío', (tester) async {
      await _pump(
        tester,
        const HeadhunterDashboardScreen(
          previewData: HeadhunterDashboardData(name: 'Ana Belen'),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/08_dashboard_vacio_final.png'),
      );
    });

    testWidgets('clientes sin backend', (tester) async {
      await _pump(tester, const HeadhunterClientsScreen());
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/09_clientes_final.png'),
      );
    });

    testWidgets('talent pool normal', (tester) async {
      await _pump(
        tester,
        HeadhunterTalentPoolScreen(
          previewRows: [
            _talent(),
            _talent(id: 'candidate-2', name: 'Martin Gomez')
              ..['pin_headline'] = 'Flutter Developer',
          ],
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/10_talent_pool_final.png'),
      );
    });

    testWidgets('talent pool confidencial queda vacío', (tester) async {
      await _pump(
        tester,
        HeadhunterTalentPoolScreen(
          previewRows: [
            _talent(type: 'stealth'),
            _talent(
              id: 'candidate-2',
              name: 'Otra Identidad Real',
              type: 'confidencial_hidden',
            ),
          ],
        ),
      );
      expect(find.text('Lucia Benitez'), findsNothing);
      expect(find.text('Otra Identidad Real'), findsNothing);
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile(
          'goldens/headhunter/10_talent_pool_confidencial_final.png',
        ),
      );
    });
  });
}
