import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/headhunter/headhunter_interview_data.dart';
import 'package:mploya/screens/headhunter/headhunter_interview_flow_screen.dart';
import 'package:mploya/screens/headhunter/headhunter_interview_report_screen.dart';
import 'package:mploya/screens/headhunter/headhunter_video_pitch_screen.dart';

import 'mp_golden_host.dart';

final _normalInterview = HeadhunterInterviewData(
  id: 'interview-1',
  status: 'completed',
  jobTitle: 'Senior Product Designer',
  candidateName: 'Camila Rodriguez',
  candidateHeadline: 'UX/UI Designer',
  createdAt: DateTime(2026, 8, 12),
  completedAt: DateTime(2026, 8, 14),
  questionCount: 4,
  answerCount: 4,
  hasReport: true,
);

final _confidentialInterview = HeadhunterInterviewData(
  id: 'interview-private',
  status: 'completed',
  jobTitle: 'Senior Product Designer',
  candidateName: 'Talento confidencial',
  createdAt: DateTime(2026, 8, 12),
  completedAt: DateTime(2026, 8, 14),
  questionCount: 4,
  answerCount: 4,
  hasReport: true,
  isConfidential: true,
);

HeadhunterInterviewReportData _report(
  HeadhunterInterviewData interview,
) => HeadhunterInterviewReportData(
  interview: interview,
  summary:
      'La conversación muestra experiencia sólida en diseño de producto y trabajo colaborativo.',
  rationale:
      'Las respuestas registradas respaldan el nivel observado en las competencias evaluadas.',
  score: 88,
  competencies: const [
    {
      'name': 'Comunicación',
      'score': 90,
      'note': 'Explica decisiones con claridad.',
    },
    {
      'name': 'Producto',
      'score': 86,
      'note': 'Conecta investigación y resultados.',
    },
  ],
  keywords: const ['Research', 'Producto', 'Colaboración'],
  createdAt: DateTime(2026, 8, 14),
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
        child: KeyedSubtree(key: UniqueKey(), child: screen),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(loadMpFonts);

  group('contratos Headhunter lote final', () {
    test('rutas separan video y entrevistas por rol', () {
      final profile = File(
        'lib/screens/profile_screen.dart',
      ).readAsStringSync();
      final interviews = File(
        'lib/screens/headhunter/headhunter_interviews_screen.dart',
      ).readAsStringSync();
      final notifications = File(
        'lib/screens/notifications_screen.dart',
      ).readAsStringSync();
      expect(profile, contains('HeadhunterVideoPitchScreen'));
      expect(interviews, contains('HeadhunterInterviewFlowScreen'));
      expect(
        interviews,
        isNot(contains("import '../interview_flow_screen.dart'")),
      );
      expect(notifications, contains('isHeadhunter'));
      expect(notifications, contains('HeadhunterInterviewFlowScreen'));
    });

    testWidgets('video contempla existente vacio y error', (tester) async {
      await _pump(
        tester,
        const HeadhunterVideoPitchScreen(
          previewData: HeadhunterVideoPitchData(
            videoUrl: 'https://example.test/pitch.mp4',
          ),
        ),
      );
      expect(find.text('Tu video está publicado'), findsOneWidget);
      expect(find.text('Ver video'), findsOneWidget);

      await _pump(
        tester,
        const HeadhunterVideoPitchScreen(
          previewData: HeadhunterVideoPitchData(),
        ),
      );
      expect(find.text('Todavía no cargaste un video'), findsOneWidget);
      expect(find.text('Grabar video'), findsOneWidget);

      await _pump(
        tester,
        const HeadhunterVideoPitchScreen(
          previewData: HeadhunterVideoPitchData(error: true),
        ),
      );
      expect(find.text('No pudimos leer tu video'), findsOneWidget);
    });

    testWidgets('las tres areas muestran loading real', (tester) async {
      final video = Completer<HeadhunterVideoPitchData>();
      await _pump(
        tester,
        HeadhunterVideoPitchScreen(loadOverride: () => video.future),
      );
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      final interview = Completer<HeadhunterInterviewData>();
      await _pump(
        tester,
        HeadhunterInterviewFlowScreen(
          interviewId: 'i',
          loadOverride: (_) => interview.future,
        ),
      );
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      final report = Completer<HeadhunterInterviewReportData>();
      await _pump(
        tester,
        HeadhunterInterviewReportScreen(
          interviewId: 'i',
          loadOverride: (_) => report.future,
        ),
      );
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });

    testWidgets('detalle usa solo estados y conteos reales', (tester) async {
      await _pump(
        tester,
        HeadhunterInterviewFlowScreen(
          interviewId: 'interview-1',
          previewData: _normalInterview,
        ),
      );
      expect(find.text('Completada'), findsOneWidget);
      expect(find.text('Preguntas'), findsOneWidget);
      expect(find.text('Respuestas'), findsOneWidget);
      expect(find.text('Ver informe de entrevista'), findsOneWidget);
      expect(find.textContaining('Google Meet'), findsNothing);
      expect(find.textContaining('videollamada'), findsNothing);
      expect(find.textContaining('calendario'), findsNothing);
    });

    testWidgets('detalle confidencial no expone identificadores', (
      tester,
    ) async {
      await _pump(
        tester,
        HeadhunterInterviewFlowScreen(
          interviewId: 'interview-private',
          previewData: _confidentialInterview,
        ),
      );
      expect(find.text('Talento confidencial'), findsOneWidget);
      expect(find.text('Identidad protegida'), findsOneWidget);
      expect(find.textContaining('Camila'), findsNothing);
      expect(find.textContaining('UX/UI'), findsNothing);
      expect(find.textContaining('ubicación'), findsOneWidget);
    });

    testWidgets('detalle contempla no disponible y error', (tester) async {
      final missing = HeadhunterInterviewData(
        id: 'missing',
        status: 'pending',
        jobTitle: '',
        candidateName: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        notFound: true,
      );
      await _pump(
        tester,
        HeadhunterInterviewFlowScreen(
          interviewId: 'missing',
          previewData: missing,
        ),
      );
      expect(find.text('Entrevista no disponible'), findsOneWidget);
      await _pump(
        tester,
        HeadhunterInterviewFlowScreen(
          interviewId: 'error',
          previewData: HeadhunterInterviewData(
            id: 'error',
            status: 'pending',
            jobTitle: '',
            candidateName: '',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            error: true,
          ),
        ),
      );
      expect(find.text('No pudimos cargar la entrevista'), findsOneWidget);
    });

    testWidgets('informe muestra exclusivamente campos persistidos', (
      tester,
    ) async {
      await _pump(
        tester,
        HeadhunterInterviewReportScreen(
          interviewId: 'interview-1',
          previewData: _report(_normalInterview),
        ),
      );
      expect(find.text('Resumen'), findsOneWidget);
      expect(find.text('Fundamento'), findsOneWidget);
      expect(find.text('Competencias'), findsOneWidget);
      expect(find.text('Palabras clave'), findsOneWidget);
      expect(find.textContaining('ranking'), findsNothing);
      expect(find.textContaining('grabación'), findsNothing);
      expect(find.textContaining('transcripción'), findsNothing);
    });

    testWidgets('informe confidencial oculta identidad y video', (
      tester,
    ) async {
      await _pump(
        tester,
        HeadhunterInterviewReportScreen(
          interviewId: 'interview-private',
          previewData: _report(_confidentialInterview),
        ),
      );
      expect(find.text('Talento confidencial'), findsOneWidget);
      expect(find.text('Identidad protegida'), findsOneWidget);
      expect(find.textContaining('Camila'), findsNothing);
      expect(find.textContaining('Ver video'), findsNothing);
      expect(find.textContaining('La conversación'), findsNothing);
      expect(find.textContaining('Explica decisiones'), findsNothing);
      expect(find.text('Palabras clave'), findsNothing);
    });

    testWidgets('informe contempla vacio y error', (tester) async {
      await _pump(
        tester,
        HeadhunterInterviewReportScreen(
          interviewId: 'empty',
          previewData: HeadhunterInterviewReportData(
            interview: _normalInterview,
            notFound: true,
          ),
        ),
      );
      expect(find.text('Informe no disponible'), findsOneWidget);
      await _pump(
        tester,
        HeadhunterInterviewReportScreen(
          interviewId: 'error',
          previewData: HeadhunterInterviewReportData(
            interview: _normalInterview,
            error: true,
          ),
        ),
      );
      expect(find.text('No pudimos cargar el informe'), findsOneWidget);
    });

    testWidgets('sin overflow en 400 424 y 430 px', (tester) async {
      for (final width in <double>[400, 424, 430]) {
        await _pump(
          tester,
          const HeadhunterVideoPitchScreen(
            previewData: HeadhunterVideoPitchData(),
          ),
          size: Size(width, 760),
        );
        await _pump(
          tester,
          HeadhunterInterviewFlowScreen(
            interviewId: 'i',
            previewData: _confidentialInterview,
          ),
          size: Size(width, 760),
        );
        await _pump(
          tester,
          HeadhunterInterviewReportScreen(
            interviewId: 'i',
            previewData: _report(_confidentialInterview),
          ),
          size: Size(width, 760),
        );
      }
    });
  });

  group('capturas productivas lote final', () {
    testWidgets('video existente', (tester) async {
      await _pump(
        tester,
        const HeadhunterVideoPitchScreen(
          previewData: HeadhunterVideoPitchData(videoUrl: 'preview://pitch'),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/17_video_pitch_final.png'),
      );
    });

    testWidgets('video vacio', (tester) async {
      await _pump(
        tester,
        const HeadhunterVideoPitchScreen(
          previewData: HeadhunterVideoPitchData(),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/17_video_pitch_vacio_final.png'),
      );
    });

    testWidgets('video error', (tester) async {
      await _pump(
        tester,
        const HeadhunterVideoPitchScreen(
          previewData: HeadhunterVideoPitchData(error: true),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/17_video_pitch_error_final.png'),
      );
    });

    testWidgets('entrevista normal', (tester) async {
      await _pump(
        tester,
        HeadhunterInterviewFlowScreen(
          interviewId: 'i',
          previewData: _normalInterview,
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/18_entrevista_final.png'),
      );
    });

    testWidgets('entrevista confidencial', (tester) async {
      await _pump(
        tester,
        HeadhunterInterviewFlowScreen(
          interviewId: 'i',
          previewData: _confidentialInterview,
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile(
          'goldens/headhunter/18_entrevista_confidencial_final.png',
        ),
      );
    });

    testWidgets('entrevista error', (tester) async {
      await _pump(
        tester,
        HeadhunterInterviewFlowScreen(
          interviewId: 'i',
          previewData: HeadhunterInterviewData(
            id: 'i',
            status: 'pending',
            jobTitle: '',
            candidateName: '',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            error: true,
          ),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/18_entrevista_error_final.png'),
      );
    });

    testWidgets('entrevista no disponible', (tester) async {
      await _pump(
        tester,
        HeadhunterInterviewFlowScreen(
          interviewId: 'missing',
          previewData: HeadhunterInterviewData(
            id: 'missing',
            status: 'pending',
            jobTitle: '',
            candidateName: '',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            notFound: true,
          ),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile(
          'goldens/headhunter/18_entrevista_no_disponible_final.png',
        ),
      );
    });

    testWidgets('informe normal', (tester) async {
      await _pump(
        tester,
        HeadhunterInterviewReportScreen(
          interviewId: 'i',
          previewData: _report(_normalInterview),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/19_informe_final.png'),
      );
    });

    testWidgets('informe confidencial', (tester) async {
      await _pump(
        tester,
        HeadhunterInterviewReportScreen(
          interviewId: 'i',
          previewData: _report(_confidentialInterview),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile(
          'goldens/headhunter/19_informe_confidencial_final.png',
        ),
      );
    });

    testWidgets('informe vacio', (tester) async {
      await _pump(
        tester,
        HeadhunterInterviewReportScreen(
          interviewId: 'i',
          previewData: HeadhunterInterviewReportData(
            interview: _normalInterview,
            notFound: true,
          ),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/19_informe_vacio_final.png'),
      );
    });

    testWidgets('informe error', (tester) async {
      await _pump(
        tester,
        HeadhunterInterviewReportScreen(
          interviewId: 'i',
          previewData: HeadhunterInterviewReportData(
            interview: _normalInterview,
            error: true,
          ),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/19_informe_error_final.png'),
      );
    });
  });
}
