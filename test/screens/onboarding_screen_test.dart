import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:duitkita/features/onboarding/onboarding_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpOnboarding(WidgetTester tester,
      {VoidCallback? onDone}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The onboarding art widgets use fixed-size boxes that can overflow with
    // fallback test fonts. Suppress overflow-only errors so functional
    // assertions still run.
    final prevHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      prevHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = prevHandler);

    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onDone: onDone ?? () {}),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();
  }

  // ── First slide ───────────────────────────────────────────────────────────

  group('OnboardingScreen — first slide', () {
    testWidgets('shows first slide title', (tester) async {
      await pumpOnboarding(tester);
      expect(find.text('Track money\nwith your people'), findsOneWidget);
    });

    testWidgets('shows Continue button on first slide', (tester) async {
      await pumpOnboarding(tester);
      expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);
    });

    testWidgets('does not show Get started button on first slide', (tester) async {
      await pumpOnboarding(tester);
      expect(find.widgetWithText(ElevatedButton, 'Get started'), findsNothing);
    });
  });

  // ── Navigation ────────────────────────────────────────────────────────────

  group('OnboardingScreen — navigation', () {
    testWidgets('tapping Continue advances to second slide', (tester) async {
      await pumpOnboarding(tester);
      await tapContinue(tester);
      expect(find.text('Never miss\na monthly payment'), findsOneWidget);
    });

    testWidgets('can advance through all slides to last', (tester) async {
      await pumpOnboarding(tester);
      for (int i = 0; i < 3; i++) {
        await tapContinue(tester);
      }
      expect(find.text('Stay in control,\ntogether'), findsOneWidget);
    });

    testWidgets('Get started button appears on last slide', (tester) async {
      await pumpOnboarding(tester);
      for (int i = 0; i < 3; i++) {
        await tapContinue(tester);
      }
      expect(find.widgetWithText(ElevatedButton, 'Get started'), findsOneWidget);
    });

    testWidgets('Continue button absent on last slide', (tester) async {
      await pumpOnboarding(tester);
      for (int i = 0; i < 3; i++) {
        await tapContinue(tester);
      }
      expect(find.widgetWithText(ElevatedButton, 'Continue'), findsNothing);
    });

    testWidgets('tapping Get started calls onDone callback', (tester) async {
      bool called = false;
      await pumpOnboarding(tester, onDone: () => called = true);
      for (int i = 0; i < 3; i++) {
        await tapContinue(tester);
      }
      await tester.tap(find.widgetWithText(ElevatedButton, 'Get started'));
      await tester.pump();
      expect(called, isTrue);
    });
  });

  // ── Skip ──────────────────────────────────────────────────────────────────

  group('OnboardingScreen — skip', () {
    testWidgets('shows Skip button on non-last slides', (tester) async {
      await pumpOnboarding(tester);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('tapping Skip calls onDone', (tester) async {
      bool called = false;
      await pumpOnboarding(tester, onDone: () => called = true);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(called, isTrue);
    });

    testWidgets('Skip button absent on last slide', (tester) async {
      await pumpOnboarding(tester);
      for (int i = 0; i < 3; i++) {
        await tapContinue(tester);
      }
      expect(find.text('Skip'), findsNothing);
    });
  });

  // ── Dots indicator ────────────────────────────────────────────────────────

  group('OnboardingScreen — page dots', () {
    testWidgets('four animated dot containers are rendered', (tester) async {
      await pumpOnboarding(tester);
      // Four animated dots (one per slide) rendered by the indicator row
      expect(find.byType(AnimatedContainer), findsNWidgets(4));
    });
  });
}
