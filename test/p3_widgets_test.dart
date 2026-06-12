import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexwork/widgets/unsaved_changes_guard.dart';
import 'package:nexwork/widgets/feature_hint.dart';
import 'package:nexwork/widgets/mploya_shimmer.dart';
import 'package:nexwork/widgets/mploya_empty_state.dart';
import 'package:nexwork/widgets/double_tap_heart.dart';
import 'package:nexwork/services/mploya_haptics.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // ─── UnsavedChangesGuard Tests ───────────────────────────────────────────
  group('UnsavedChangesGuard', () {
    testWidgets('allows back navigation when no unsaved changes', (tester) async {
      bool popped = false;
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => CupertinoButton(
                child: const Text('Go'),
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => UnsavedChangesGuard(
                        hasUnsavedChanges: () => false,
                        child: CupertinoPageScaffold(
                          navigationBar: const CupertinoNavigationBar(
                            middle: Text('Form'),
                          ),
                          child: const Text('Form Content'),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Navigate to form
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.text('Form Content'), findsOneWidget);
    });

    testWidgets('shows dialog when has unsaved changes', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: UnsavedChangesGuard(
            hasUnsavedChanges: () => true,
            child: const CupertinoPageScaffold(
              child: Text('Form'),
            ),
          ),
        ),
      );

      expect(find.text('Form'), findsOneWidget);
    });
  });

  // ─── DoubleTapHeartOverlay Tests ────────────────────────────────────────
  group('DoubleTapHeartOverlay', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: DoubleTapHeartOverlay(
            child: Text('Video'),
          ),
        ),
      );

      expect(find.text('Video'), findsOneWidget);
    });

    testWidgets('calls onSingleTap on single tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        CupertinoApp(
          home: DoubleTapHeartOverlay(
            onSingleTap: () => tapped = true,
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      );

      await tester.tap(find.byType(DoubleTapHeartOverlay));
      expect(tapped, true);
    });

    testWidgets('calls onDoubleTap on double tap', (tester) async {
      bool doubleTapped = false;
      await tester.pumpWidget(
        CupertinoApp(
          home: DoubleTapHeartOverlay(
            onDoubleTap: () => doubleTapped = true,
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      );

      // Double tap gesture
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(doubleTapped, true);
    });
  });

  // ─── Shimmer Tests ──────────────────────────────────────────────────────
  group('MployaShimmer', () {
    testWidgets('feedCard renders without errors', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(child: MployaShimmer.feedCard()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ShimmerBox), findsWidgets);
      expect(find.byType(ShimmerCircle), findsOneWidget);
    });

    testWidgets('profileHeader renders without errors', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(child: MployaShimmer.profileHeader()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ShimmerBox), findsWidgets);
      expect(find.byType(ShimmerCircle), findsOneWidget);
    });

    testWidgets('listTile renders correct count', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(child: MployaShimmer.listTile(count: 3)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      // Each tile has 3 ShimmerBoxes + 1 ShimmerCircle = 4 shimmer widgets per tile
      expect(find.byType(ShimmerCircle), findsNWidgets(3));
    });

    testWidgets('card renders without errors', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(child: MployaShimmer.card()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ShimmerBox), findsWidgets);
    });
  });

  // ─── MployaEmptyState Tests ─────────────────────────────────────────────
  group('MployaEmptyState', () {
    testWidgets('inbox displays correct text and action', (tester) async {
      bool actionCalled = false;
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: MployaEmptyState.inbox(onAction: () => actionCalled = true),
          ),
        ),
      );

      expect(find.text('Inbox Vacío'), findsOneWidget);
      expect(find.text('Ir al Feed'), findsOneWidget);

      await tester.tap(find.text('Ir al Feed'));
      expect(actionCalled, true);
    });

    testWidgets('savedJobs displays correct text', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: MployaEmptyState.savedJobs(onAction: () {}),
          ),
        ),
      );

      expect(find.text('Sin vacantes guardadas'), findsOneWidget);
      expect(find.text('Explorar vacantes'), findsOneWidget);
    });

    testWidgets('notifications displays correct text', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: MployaEmptyState.notifications(),
          ),
        ),
      );

      expect(find.text('Todo tranquilo'), findsOneWidget);
    });

    testWidgets('custom displays provided text', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: MployaEmptyState.custom(
              title: 'Custom Title',
              subtitle: 'Custom Subtitle',
              icon: CupertinoIcons.star,
            ),
          ),
        ),
      );

      expect(find.text('Custom Title'), findsOneWidget);
      expect(find.text('Custom Subtitle'), findsOneWidget);
    });
  });

  // ─── FeatureHint Tests ──────────────────────────────────────────────────
  group('FeatureHint', () {
    testWidgets('renders child immediately', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const CupertinoApp(
          home: CupertinoPageScaffold(
            child: FeatureHint(
              hintKey: 'test_hint',
              icon: CupertinoIcons.info,
              text: 'Test hint text',
              delay: Duration(milliseconds: 100),
              child: Text('Child Widget'),
            ),
          ),
        ),
      );

      expect(find.text('Child Widget'), findsOneWidget);
    });

    testWidgets('shows hint after delay', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const CupertinoApp(
          home: CupertinoPageScaffold(
            child: FeatureHint(
              hintKey: 'test_hint_show',
              icon: CupertinoIcons.info,
              text: 'Gesture hint text',
              delay: Duration(milliseconds: 100),
              child: Text('Child'),
            ),
          ),
        ),
      );

      // Before delay
      expect(find.text('Gesture hint text'), findsNothing);

      // After delay
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Gesture hint text'), findsOneWidget);
    });
  });

  // ─── MployaHaptics Tests ────────────────────────────────────────────────
  group('MployaHaptics', () {
    test('all methods execute without error', () {
      // These methods use platform channels that won't work in test,
      // but they should not throw
      expect(() => MployaHaptics.success(), returnsNormally);
      expect(() => MployaHaptics.warning(), returnsNormally);
      expect(() => MployaHaptics.error(), returnsNormally);
      expect(() => MployaHaptics.selection(), returnsNormally);
      expect(() => MployaHaptics.light(), returnsNormally);
      expect(() => MployaHaptics.impact(), returnsNormally);
      expect(() => MployaHaptics.notification(), returnsNormally);
    });
  });
}
