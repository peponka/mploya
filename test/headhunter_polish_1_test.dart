import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/l10n/app_localizations.dart';
import 'package:mploya/models/models.dart';
import 'package:mploya/screens/messaging_screen.dart';
import 'package:mploya/screens/profile_screen.dart';
import 'package:mploya/screens/saved_profiles_screen.dart';
import 'package:mploya/utils/headhunter_candidate_privacy.dart';
import 'package:mploya/widgets/nex_avatar.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

import 'mp_golden_host.dart';

const _viewerId = 'preview-cand-01';

Map<String, dynamic> _candidate({
  String id = 'candidate-1',
  String accountType = 'candidato',
  String name = 'Lucia Benitez',
}) {
  return {
    'id': id,
    'name': name,
    'headline': 'Product Designer',
    'account_type': accountType,
    'avatar_url': accountType == 'candidato'
        ? null
        : 'https://identidad-real.invalid/avatar.jpg',
    'banner_url': 'https://identidad-real.invalid/banner.jpg',
    'video_url': 'https://identidad-real.invalid/video.mp4',
    'location': 'Asuncion, Paraguay',
    'company': 'Empresa identificable',
    'about': 'Biografia identificable',
    'salary_expectation': 'USD 3000',
    'skills': ['Figma', 'Research', 'Prototipado'],
    'tags': ['Producto', 'UX'],
    'experience': [
      {
        'role': 'Product Designer',
        'company': 'Empresa identificable',
        'duration': '2022 - Actualidad',
        'location': 'Asuncion',
        'description': 'Experiencia real',
      },
    ],
    'education': [
      {
        'school': 'Universidad identificable',
        'degree': 'Diseno',
        'field': 'Producto',
        'years': '2018 - 2022',
      },
    ],
  };
}

MessagingPreviewData _messages(Map<String, dynamic> candidate) {
  return MessagingPreviewData(
    viewerAccountType: 'headhunter',
    conexiones: [
      {
        'requester_id': _viewerId,
        'addressee_id': candidate['id'],
        'status': 'accepted',
      },
    ],
    usuarios: [candidate],
    mensajes: [
      {
        'id': 'message-1',
        'sender_id': candidate['id'],
        'receiver_id': _viewerId,
        'content':
            isConfidentialAccountType(candidate['account_type']?.toString())
            ? 'Soy Lucia Benitez. Escribime a lucia@example.com.'
            : 'Gracias por contactarme. Coordinemos una entrevista.',
        'created_at': DateTime.now()
            .subtract(const Duration(minutes: 8))
            .toIso8601String(),
        'is_read': false,
      },
    ],
  );
}

ProfilePreviewData _profile(
  Map<String, dynamic> candidate, {
  String viewerAccountType = 'headhunter',
}) {
  return ProfilePreviewData(
    usuario: candidate,
    isOwnProfile: false,
    viewerAccountType: viewerAccountType,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CupertinoApp(
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
  );
  await tester.pump(const Duration(milliseconds: 200));
  expect(tester.takeException(), isNull);
}

void _expectNoRealIdentity() {
  expect(find.text('Lucia Benitez'), findsNothing);
  expect(find.textContaining('lucia@example.com'), findsNothing);
  expect(find.text('Product Designer'), findsNothing);
  expect(find.text('Asuncion, Paraguay'), findsNothing);
  expect(find.text('Empresa identificable'), findsNothing);
  expect(find.text('Biografia identificable'), findsNothing);
  expect(find.text('USD 3000'), findsNothing);
  expect(
    find.byWidgetPredicate(
      (widget) =>
          widget is NexAvatar &&
          widget.user.avatarUrl == 'https://identidad-real.invalid/avatar.jpg',
    ),
    findsNothing,
  );
}

void main() {
  setUpAll(loadMpFonts);

  group('presentacion confidencial para headhunter', () {
    test('normal conserva identidad y confidencial/stealth la ocultan', () {
      final normal = NexUser.fromJson(_candidate());
      final confidential = NexUser.fromJson(
        _candidate(accountType: 'confidential'),
      );
      final stealth = NexUser.fromJson(_candidate(accountType: 'stealth'));

      expect(
        protectCandidateForHeadhunter(normal, 'headhunter').name,
        'Lucia Benitez',
      );
      for (final protected in [confidential, stealth]) {
        final visible = protectCandidateForHeadhunter(protected, 'headhunter');
        expect(visible.name, headhunterProtectedCandidateName);
        expect(visible.headline, isEmpty);
        expect(visible.avatarUrl, isNull);
        expect(visible.location, isNull);
        expect(visible.videoUrl, isNull);
        expect(visible.experience, isEmpty);
        expect(visible.education, isEmpty);
      }
      expect(
        protectCandidateForHeadhunter(confidential, 'candidato').name,
        'Lucia Benitez',
      );
    });

    testWidgets('inbox oculta nombre y avatar confidential', (tester) async {
      await _pump(
        tester,
        MessagingScreen(
          previewData: _messages(_candidate(accountType: 'confidential')),
        ),
      );

      expect(find.text(headhunterProtectedCandidateName), findsOneWidget);
      expect(find.text(headhunterProtectedMessageText), findsOneWidget);
      _expectNoRealIdentity();
    });

    testWidgets('inbox oculta nombre y avatar stealth', (tester) async {
      await _pump(
        tester,
        MessagingScreen(
          previewData: _messages(_candidate(accountType: 'stealth')),
        ),
      );

      expect(find.text(headhunterProtectedCandidateName), findsOneWidget);
      expect(find.text(headhunterProtectedMessageText), findsOneWidget);
      _expectNoRealIdentity();
    });

    testWidgets('chat normal sigue abriendo desde el inbox', (tester) async {
      await _pump(
        tester,
        MessagingScreen(previewData: _messages(_candidate())),
      );
      await tester.tap(find.text('Lucia Benitez'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatDetailScreen), findsOneWidget);
      expect(find.text('Lucia Benitez'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.video_camera_solid), findsOneWidget);
    });

    testWidgets('chat y navegacion al perfil permanecen protegidos', (
      tester,
    ) async {
      final raw = NexUser.fromJson(_candidate(accountType: 'confidential'));
      await _pump(
        tester,
        ChatDetailScreen(
          otherUser: raw,
          viewerAccountType: 'headhunter',
          previewData: ChatDetailPreviewData(
            miId: _viewerId,
            mensajes: _messages(raw.toJson()).mensajes,
          ),
        ),
      );

      expect(find.text(headhunterProtectedCandidateName), findsOneWidget);
      expect(find.text(headhunterProtectedMessageText), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.video_camera_solid), findsNothing);
      _expectNoRealIdentity();
      await tester.tap(find.byIcon(CupertinoIcons.person_fill));
      await tester.pumpAndSettle();
      expect(find.text('Identidad protegida'), findsOneWidget);
      _expectNoRealIdentity();
    });

    testWidgets('perfil confidencial no muestra ubicacion video o portfolio', (
      tester,
    ) async {
      await _pump(
        tester,
        ProfileScreen(
          previewData: _profile(_candidate(accountType: 'confidential')),
        ),
      );

      expect(find.text('Identidad protegida'), findsOneWidget);
      expect(find.textContaining('portfolio'), findsOneWidget);
      _expectNoRealIdentity();
    });

    testWidgets('perfil propio Headhunter monta en tablet y desktop', (
      tester,
    ) async {
      final propio = ProfilePreviewData(
        usuario: {
          ..._candidate(
            id: 'headhunter-1',
            accountType: 'headhunter',
            name: 'Ana Headhunter',
          ),
          'avatar_url': null,
          'banner_url': null,
          'video_url': null,
        },
        isOwnProfile: true,
        viewerAccountType: 'headhunter',
      );
      for (final size in const [Size(768, 1024), Size(1440, 900)]) {
        await _pump(tester, ProfileScreen(previewData: propio), size: size);
      }
    });

    testWidgets('guardados protege listado y perfil abierto', (tester) async {
      await _pump(
        tester,
        SavedProfilesScreen(
          previewData: SavedProfilesPreviewData(
            profiles: [_candidate(accountType: 'stealth')],
          ),
        ),
      );

      expect(find.text(headhunterProtectedCandidateName), findsOneWidget);
      _expectNoRealIdentity();
      await tester.tap(find.text(headhunterProtectedCandidateName));
      await tester.pumpAndSettle();
      expect(find.text('Identidad protegida'), findsOneWidget);
      _expectNoRealIdentity();
    });
  });

  group('capturas productivas', () {
    testWidgets('mensajes normal', (tester) async {
      await _pump(
        tester,
        MessagingScreen(previewData: _messages(_candidate())),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/01_mensajes_final.png'),
      );
    });

    testWidgets('mensajes confidencial', (tester) async {
      await _pump(
        tester,
        MessagingScreen(
          previewData: _messages(_candidate(accountType: 'confidential')),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile(
          'goldens/headhunter/01_mensajes_confidencial_final.png',
        ),
      );
    });

    testWidgets('chat normal', (tester) async {
      final raw = NexUser.fromJson(_candidate());
      await _pump(
        tester,
        ChatDetailScreen(
          otherUser: raw,
          viewerAccountType: 'headhunter',
          previewData: ChatDetailPreviewData(
            miId: _viewerId,
            mensajes: _messages(raw.toJson()).mensajes,
          ),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/01_chat_final.png'),
      );
    });

    testWidgets('chat confidencial', (tester) async {
      final raw = NexUser.fromJson(_candidate(accountType: 'confidential'));
      await _pump(
        tester,
        ChatDetailScreen(
          otherUser: raw,
          viewerAccountType: 'headhunter',
          previewData: ChatDetailPreviewData(
            miId: _viewerId,
            mensajes: _messages(raw.toJson()).mensajes,
          ),
        ),
      );
      _expectNoRealIdentity();
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/01_chat_confidencial_final.png'),
      );
    });

    testWidgets('perfil normal', (tester) async {
      await _pump(tester, ProfileScreen(previewData: _profile(_candidate())));
      expect(find.text('81%'), findsNothing);
      expect(find.text('Señal IA'), findsNothing);
      expect(find.text('Remoto / Híbrido'), findsNothing);
      expect(find.text('Español +1'), findsNothing);
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/02_perfil_final.png'),
      );
    });

    testWidgets('perfil confidencial', (tester) async {
      await _pump(
        tester,
        ProfileScreen(
          previewData: _profile(_candidate(accountType: 'confidential')),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile(
          'goldens/headhunter/02_perfil_confidencial_final.png',
        ),
      );
    });

    testWidgets('guardados normal', (tester) async {
      await _pump(
        tester,
        SavedProfilesScreen(
          previewData: SavedProfilesPreviewData(profiles: [_candidate()]),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/headhunter/03_guardados_final.png'),
      );
    });

    testWidgets('guardados confidencial', (tester) async {
      await _pump(
        tester,
        SavedProfilesScreen(
          previewData: SavedProfilesPreviewData(
            profiles: [_candidate(accountType: 'stealth')],
          ),
        ),
      );
      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile(
          'goldens/headhunter/03_guardados_confidencial_final.png',
        ),
      );
    });
  });
}
