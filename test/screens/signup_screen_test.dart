import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duitkita/screens/signup_screen.dart';

import '../helpers/fake_auth.dart';

void main() {
  Future<void> pumpSignup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp(const SignupScreen()));
    await tester.pumpAndSettle();
  }

  // Step 1 fields by index: 0=name, 1=email, 2=phone.
  // Step 2 has a single field: 0=password. There is no confirm-password field —
  // the form is split across two steps rather than one long page.
  Future<void> fillField(WidgetTester tester, int index, String value) async {
    await tester.enterText(find.byType(TextField).at(index), value);
    await tester.pump();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.widgetWithText(ElevatedButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  Future<void> fillStep1(WidgetTester tester) async {
    await fillField(tester, 0, 'Ali Hassan');
    await fillField(tester, 1, 'ali@example.com');
    await fillField(tester, 2, '0123456789');
  }

  /// Completes step 1 and lands on the security step.
  Future<void> goToStep2(WidgetTester tester) async {
    await fillStep1(tester);
    await tapButton(tester, 'Continue');
    await tester.pumpAndSettle();
  }

  /// Ticks the terms box. "Create account" stays disabled until it is ticked,
  /// so every step-2 submission has to go through here first.
  Future<void> tapAgree(WidgetTester tester) async {
    await tester.tap(
      find
          .ancestor(
            of: find.textContaining('I agree to the'),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    await tester.pump();
  }

  ElevatedButton buttonNamed(WidgetTester tester, String label) =>
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, label));

  // ── Step 1: about you ─────────────────────────────────────────────────────

  group('SignupScreen — step 1', () {
    testWidgets('opens on the about-you step', (tester) async {
      await pumpSignup(tester);
      expect(find.text("Let's get you set up"), findsOneWidget);
      expect(find.text('STEP 1 OF 3 · ABOUT YOU'), findsOneWidget);
    });

    testWidgets('shows name, email and phone', (tester) async {
      await pumpSignup(tester);
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('advances with Continue, not Create account', (tester) async {
      await pumpSignup(tester);
      expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Create account'),
        findsNothing,
      );
    });

    testWidgets('shows name error when name is empty', (tester) async {
      await pumpSignup(tester);
      await tapButton(tester, 'Continue');
      expect(find.text('Full name is required'), findsOneWidget);
    });

    testWidgets('shows name error when name is too short', (tester) async {
      await pumpSignup(tester);
      await fillField(tester, 0, 'A');
      await tapButton(tester, 'Continue');
      expect(find.text('Name must be at least 2 characters'), findsOneWidget);
    });

    testWidgets('shows email error for invalid email', (tester) async {
      await pumpSignup(tester);
      await fillField(tester, 0, 'Ali');
      await fillField(tester, 1, 'notanemail');
      await tapButton(tester, 'Continue');
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('shows phone error when phone is empty', (tester) async {
      await pumpSignup(tester);
      await fillField(tester, 0, 'Ali');
      await fillField(tester, 1, 'ali@example.com');
      await tapButton(tester, 'Continue');
      expect(find.text('Phone number is required'), findsOneWidget);
    });

    testWidgets('shows phone error when phone is too short', (tester) async {
      await pumpSignup(tester);
      await fillField(tester, 0, 'Ali');
      await fillField(tester, 1, 'ali@example.com');
      await fillField(tester, 2, '0123');
      await tapButton(tester, 'Continue');
      expect(find.text('Please enter a valid phone number'), findsOneWidget);
    });

    testWidgets('no validation errors before the first submit', (tester) async {
      await pumpSignup(tester);
      expect(find.text('Full name is required'), findsNothing);
      expect(find.text('Please enter a valid email'), findsNothing);
      expect(find.text('Phone number is required'), findsNothing);
    });

    testWidgets('a valid step 1 moves on to security', (tester) async {
      await pumpSignup(tester);
      await goToStep2(tester);
      expect(find.text('Almost there'), findsOneWidget);
      expect(find.text('STEP 2 OF 3 · SECURITY'), findsOneWidget);
    });
  });

  // ── Step 2: security ──────────────────────────────────────────────────────

  group('SignupScreen — step 2', () {
    testWidgets('asks only for a password, obscured', (tester) async {
      await pumpSignup(tester);
      await goToStep2(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        true,
      );
    });

    testWidgets('Create account is blocked until the terms are agreed', (
      tester,
    ) async {
      await pumpSignup(tester);
      await goToStep2(tester);

      expect(buttonNamed(tester, 'Create account').onPressed, isNull);
      await tapAgree(tester);
      expect(buttonNamed(tester, 'Create account').onPressed, isNotNull);
    });

    testWidgets('rejects a weak password', (tester) async {
      await pumpSignup(tester);
      await goToStep2(tester);
      await tapAgree(tester);

      await fillField(tester, 0, '123');
      await tapButton(tester, 'Create account');

      expect(
        find.text('Choose a stronger password (min 8 chars)'),
        findsOneWidget,
      );
    });

    testWidgets('accepts a strong password', (tester) async {
      await pumpSignup(tester);
      await goToStep2(tester);
      await tapAgree(tester);

      await fillField(tester, 0, 'Password123');
      await tapButton(tester, 'Create account');
      await tester.pumpAndSettle();

      expect(
        find.text('Choose a stronger password (min 8 chars)'),
        findsNothing,
      );
    });

    testWidgets('back returns to step 1 rather than leaving', (tester) async {
      await pumpSignup(tester);
      await goToStep2(tester);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text("Let's get you set up"), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3));
    });
  });
}
