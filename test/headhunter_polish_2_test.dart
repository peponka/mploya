import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/l10n/app_localizations.dart';
import 'package:mploya/screens/home_feed_screen.dart';
import 'package:mploya/screens/job_detail_screen.dart';
import 'package:mploya/screens/jobs_screen.dart';
import 'package:mploya/screens/notifications_screen.dart';
import 'package:mploya/utils/headhunter_candidate_privacy.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'mp_golden_host.dart';

Map<String, dynamic> _candidate({
  String accountType = 'candidato',
  String name = 'Lucia Benitez',
}) {
  return {
    'id': 'candidate-1',
    'name': name,
    'headline': 'Product Designer',
    'account_type': accountType,
    'avatar_url': 'https://identidad-real.invalid/avatar.jpg',
    'video_url': 'https://identidad-real.invalid/video.mp4',
    'location': 'Asuncion, Paraguay',
    'company': 'Empresa identificable',
    'about': 'Diseño de productos digitales y research.',
    'tags': ['Producto', 'UX'],
    'skills': ['Figma', 'Research'],
    'is_verified': true,
  };
}

Map<String, dynamic> _notification({
  String accountType = 'candidato',
  String title = 'Lucia Benitez',
}) {
  return {
    'id': 'notification-1',
    'type': 'job_application',
    'title': title,
    'body': 'Se postuló a Product Designer',
    'is_read': false,
    'created_at': DateTime.now()
        .subtract(const Duration(minutes: 20))
        .toIso8601String(),
    'data': {'candidate_id': 'candidate-1', 'account_type': accountType},
  };
}

Map<String, dynamic> _job() {
  return {
    'id': 'job-1',
    'title': 'Senior Product Designer',
    'description':
        'Liderar el diseño de experiencias digitales y colaborar con producto.',
    'location': 'Asuncion, Paraguay',
    'modality': 'hybrid',
    'seniority': 'senior',
    'salary_range': 'USD 2.500 - 3.200',
    'tags': ['Figma', 'Research', 'Design Systems'],
    'users': {'name': 'Mploya Labs'},
  };
}

HomeFeedPreviewData _feed(Map<String, dynamic> candidate) {
  return HomeFeedPreviewData(
    feed: [candidate],
    usuario: const {
      'id': 'headhunter-1',
      'name': 'Sofia Recruiter',
      'headline': 'Talent Partner',
      'account_type': 'headhunter',
    },
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
    ProviderScope(
      child: CupertinoApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: MpSurface(
            style: MpSurfaceStyle.light,
            child: CupertinoPageScaffold(child: screen),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 250));
  expect(tester.takeException(), isNull);
}

void _expectProtectedIdentity({bool expectAnonymousName = true}) {
  if (expectAnonymousName) {
    expect(find.text(headhunterProtectedCandidateName), findsWidgets);
  }
  expect(find.text('Lucia Benitez'), findsNothing);
  expect(find.text('Asuncion, Paraguay'), findsNothing);
  expect(find.text('Empresa identificable'), findsNothing);
}

void main() {
  setUpAll(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    await loadMpFonts();
  });

  group('privacidad y roles', () {
    testWidgets('alertas headhunter vacias no muestran actividad demo', (
      tester,
    ) async {
      await _pump(
        tester,
        const NotificationsScreen(previewData: NotificationsPreviewData()),
      );

      expect(find.text('Estás al día'), findsOneWidget);
      expect(find.text('María López'), findsNothing);
      expect(find.text('Nada por acá con este filtro.'), findsOneWidget);
    });

    testWidgets('alerta confidencial oculta identidad embebida', (
      tester,
    ) async {
      await _pump(
        tester,
        NotificationsScreen(
          previewData: NotificationsPreviewData(
            notifications: [_notification(accountType: 'confidential')],
          ),
        ),
      );
      await tester.pump();

      _expectProtectedIdentity();
      expect(
        find.text('La identidad de este talento está protegida.'),
        findsOneWidget,
      );
    });

    testWidgets('feed headhunter anonimiza antes de construir el reel', (
      tester,
    ) async {
      await _pump(
        tester,
        HomeFeedScreen(previewData: _feed(_candidate(accountType: 'stealth'))),
      );

      _expectProtectedIdentity(expectAnonymousName: false);
      expect(find.text('Identidad protegida'), findsOneWidget);
      expect(find.text('Ver perfil'), findsOneWidget);
      expect(find.text('Ver vacante'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget.toString().contains(
            'https://identidad-real.invalid/video.mp4',
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('vacantes headhunter no ofrecen postulacion ni match', (
      tester,
    ) async {
      await _pump(
        tester,
        JobsScreen(
          previewData: JobsPreviewData(
            vacantes: [_job()],
            matchScores: const {'job-1': 97},
            viewerAccountType: 'headhunter',
          ),
        ),
      );

      expect(find.textContaining('Postular'), findsNothing);
      expect(find.textContaining('97%'), findsNothing);
      expect(find.text('Senior Product Designer'), findsOneWidget);
    });

    testWidgets('detalle headhunter permanece informativo', (tester) async {
      await _pump(
        tester,
        JobDetailScreen(
          job: _job(),
          matchScore: 97,
          viewerAccountType: 'headhunter',
          previewMode: true,
        ),
      );

      expect(find.textContaining('Postular'), findsNothing);
      expect(find.textContaining('97%'), findsNothing);
      expect(find.textContaining('Vista informativa'), findsOneWidget);
      expect(find.text('Startup'), findsNothing);
      expect(find.text('jilo.com'), findsNothing);
    });
  });

  group('capturas productivas', () {
    testWidgets('alertas normal', (tester) async {
      await _pump(
        tester,
        NotificationsScreen(
          previewData: NotificationsPreviewData(
            notifications: [_notification()],
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/04_alertas_final.png'),
      );
    });

    testWidgets('alertas confidencial', (tester) async {
      await _pump(
        tester,
        NotificationsScreen(
          previewData: NotificationsPreviewData(
            notifications: [_notification(accountType: 'confidential')],
          ),
        ),
      );
      await tester.pump();
      _expectProtectedIdentity();
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile(
          'goldens/headhunter/04_alertas_confidencial_final.png',
        ),
      );
    });

    testWidgets('alertas vacias', (tester) async {
      await _pump(
        tester,
        const NotificationsScreen(previewData: NotificationsPreviewData()),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/04_alertas_vacio_final.png'),
      );
    });

    testWidgets('feed normal', (tester) async {
      await _pump(tester, HomeFeedScreen(previewData: _feed(_candidate())));
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/05_feed_final.png'),
      );
    });

    testWidgets('feed confidencial', (tester) async {
      await _pump(
        tester,
        HomeFeedScreen(
          previewData: _feed(_candidate(accountType: 'confidential')),
        ),
      );
      _expectProtectedIdentity(expectAnonymousName: false);
      expect(find.text('Identidad protegida'), findsOneWidget);
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/05_feed_confidencial_final.png'),
      );
    });

    testWidgets('vacantes', (tester) async {
      await _pump(
        tester,
        JobsScreen(
          previewData: JobsPreviewData(
            vacantes: [_job()],
            viewerAccountType: 'headhunter',
          ),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/06_vacantes_final.png'),
      );
    });

    testWidgets('vacantes vacias', (tester) async {
      await _pump(
        tester,
        const JobsScreen(
          previewData: JobsPreviewData(
            vacantes: [],
            viewerAccountType: 'headhunter',
          ),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/06_vacantes_vacio_final.png'),
      );
    });

    testWidgets('detalle de vacante', (tester) async {
      await _pump(
        tester,
        JobDetailScreen(
          job: _job(),
          viewerAccountType: 'headhunter',
          previewMode: true,
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/07_detalle_vacante_final.png'),
      );
    });
  });
}
