import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/models/models.dart';
import 'package:mploya/screens/headhunter/headhunter_interviews_screen.dart';
import 'package:mploya/screens/headhunter/headhunter_pipeline_screen.dart';
import 'package:mploya/screens/headhunter/headhunter_tools_screen.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

import 'mp_golden_host.dart';

NexUser _candidate({
  String id = 'candidate-1',
  String name = 'Lucia Benitez',
  String type = 'candidato',
}) {
  return NexUser.fromJson({
    'id': id,
    'name': name,
    'headline': 'Product Designer',
    'avatar_url': '',
    'video_url': 'https://example.test/private-video.mp4',
    'location': 'Asuncion',
    'account_type': type,
  });
}

HeadhunterPipelineCandidate _pipelineCandidate({
  String id = 'candidate-1',
  String name = 'Lucia Benitez',
  String type = 'candidato',
  String status = 'pending',
}) {
  return HeadhunterPipelineCandidate(
    applicationId: 'application-$id',
    candidate: _candidate(id: id, name: name, type: type),
    jobTitle: 'Senior Product Designer',
    status: status,
    appliedAt: DateTime.utc(2026, 8, 14),
  );
}

HeadhunterInterviewItem _interview({
  String id = 'interview-1',
  String name = 'Lucia Benitez',
  String type = 'candidato',
  String status = 'pending',
}) {
  return HeadhunterInterviewItem(
    id: id,
    candidate: _candidate(id: 'candidate-$id', name: name, type: type),
    jobTitle: 'Senior Product Designer',
    status: status,
    createdAt: DateTime.utc(2026, 8, 14),
    completedAt: status == 'completed' ? DateTime.utc(2026, 8, 15) : null,
  );
}

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

  group('contratos Headhunter lote 4', () {
    test('el selector compartido deriva solo Headhunter al hub nuevo', () {
      final source = File(
        'lib/screens/tools_hub_entry_screen.dart',
      ).readAsStringSync();
      expect(source, contains("profile.accountType == 'headhunter'"));
      expect(source, contains('HeadhunterToolsScreen'));
      expect(source, contains('MisHerramientasScreen'));
    });

    test('mensajes conserva agenda legacy fuera de Headhunter', () {
      final source = File(
        'lib/screens/messaging_screen.dart',
      ).readAsStringSync();
      expect(source, contains("_viewerAccountType == 'headhunter'"));
      expect(source, contains("'Ver entrevistas'"));
      expect(source, contains('const HeadhunterInterviewsScreen()'));
      expect(source, contains('const SchedulingScreen(isCompany: true)'));
    });

    testWidgets('herramientas ofrece solo destinos implementados', (
      tester,
    ) async {
      await _pump(tester, const HeadhunterToolsScreen());
      expect(find.text('Pipeline'), findsOneWidget);
      expect(find.text('Entrevistas'), findsOneWidget);
      expect(find.text('Talent Pool'), findsOneWidget);
      expect(find.text('Match IA'), findsNothing);
      expect(find.text('Upgrade'), findsNothing);
      expect(find.text('Clientes'), findsNothing);
    });

    testWidgets('pipeline usa estados canonicos y protege confidenciales', (
      tester,
    ) async {
      await _pump(
        tester,
        HeadhunterPipelineScreen(
          previewData: HeadhunterPipelineData(
            candidates: [
              _pipelineCandidate(),
              _pipelineCandidate(
                id: 'candidate-2',
                name: 'Identidad Privada',
                type: 'confidential_premium',
              ),
            ],
          ),
        ),
      );
      expect(find.text('Lucia Benitez'), findsOneWidget);
      expect(find.text('Talento confidencial'), findsOneWidget);
      expect(find.text('Identidad Privada'), findsNothing);
      expect(find.text('Perfil protegido'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('pipeline cambia etapa por la transicion real permitida', (
      tester,
    ) async {
      await _pump(
        tester,
        HeadhunterPipelineScreen(
          previewData: HeadhunterPipelineData(
            candidates: [_pipelineCandidate()],
          ),
        ),
      );
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis_vertical));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CupertinoActionSheetAction, 'Revisados'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lucia Benitez'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('entrevistas protege identidad y no inventa horarios', (
      tester,
    ) async {
      await _pump(
        tester,
        HeadhunterInterviewsScreen(
          previewData: HeadhunterInterviewsData(
            items: [
              _interview(),
              _interview(
                id: 'interview-2',
                name: 'Nombre Secreto',
                type: 'stealth',
              ),
            ],
          ),
        ),
      );
      expect(find.text('Lucia Benitez'), findsOneWidget);
      expect(find.text('Talento confidencial'), findsOneWidget);
      expect(find.text('Nombre Secreto'), findsNothing);
      expect(find.textContaining('08:30'), findsNothing);
      expect(find.textContaining('Google Calendar'), findsNothing);
      expect(find.textContaining('IA'), findsNothing);
    });

    testWidgets('sin overflow en anchos moviles requeridos', (tester) async {
      for (final width in <double>[400, 424, 430]) {
        await _pump(
          tester,
          HeadhunterPipelineScreen(
            previewData: HeadhunterPipelineData(
              candidates: [_pipelineCandidate()],
            ),
          ),
          size: Size(width, 760),
        );
        await _pump(
          tester,
          HeadhunterInterviewsScreen(
            previewData: HeadhunterInterviewsData(items: [_interview()]),
          ),
          size: Size(width, 760),
        );
      }
    });

    testWidgets('herramientas monta en tablet y desktop', (tester) async {
      for (final size in const [Size(768, 1024), Size(1440, 900)]) {
        await _pump(tester, const HeadhunterToolsScreen(), size: size);
      }
    });
  });

  group('capturas productivas lote 4', () {
    testWidgets('herramientas', (tester) async {
      await _pump(tester, const HeadhunterToolsScreen());
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/11_herramientas_final.png'),
      );
    });

    testWidgets('pipeline normal', (tester) async {
      await _pump(
        tester,
        HeadhunterPipelineScreen(
          previewData: HeadhunterPipelineData(
            candidates: [
              _pipelineCandidate(),
              _pipelineCandidate(id: 'candidate-2', name: 'Martin Gomez'),
            ],
          ),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/12_pipeline_final.png'),
      );
    });

    testWidgets('pipeline confidencial', (tester) async {
      await _pump(
        tester,
        HeadhunterPipelineScreen(
          previewData: HeadhunterPipelineData(
            candidates: [
              _pipelineCandidate(
                name: 'Identidad Privada',
                type: 'confidencial_hidden',
              ),
            ],
          ),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile(
          'goldens/headhunter/12_pipeline_confidencial_final.png',
        ),
      );
    });

    testWidgets('pipeline vacio', (tester) async {
      await _pump(
        tester,
        const HeadhunterPipelineScreen(
          previewData: HeadhunterPipelineData.empty,
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/12_pipeline_vacio_final.png'),
      );
    });

    testWidgets('entrevistas normal', (tester) async {
      await _pump(
        tester,
        HeadhunterInterviewsScreen(
          previewData: HeadhunterInterviewsData(
            items: [
              _interview(),
              _interview(
                id: 'interview-2',
                name: 'Martin Gomez',
                status: 'in_progress',
              ),
              _interview(
                id: 'interview-3',
                name: 'Sofia Lopez',
                status: 'completed',
              ),
            ],
          ),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/13_entrevistas_final.png'),
      );
    });

    testWidgets('entrevistas confidencial', (tester) async {
      await _pump(
        tester,
        HeadhunterInterviewsScreen(
          previewData: HeadhunterInterviewsData(
            items: [_interview(name: 'Nombre Secreto', type: 'stealth')],
          ),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile(
          'goldens/headhunter/13_entrevistas_confidencial_final.png',
        ),
      );
    });

    testWidgets('entrevistas vacio', (tester) async {
      await _pump(
        tester,
        const HeadhunterInterviewsScreen(
          previewData: HeadhunterInterviewsData.empty,
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/13_entrevistas_vacio_final.png'),
      );
    });
  });
}
