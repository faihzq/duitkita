import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/screens/login_screen.dart';
import 'package:duitkita/services/auth_service.dart';

import '../helpers/fake_auth.dart';

void main() {
  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> pumpLogin(WidgetTester tester,
      {AuthController? controller}) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp(const LoginScreen(), controller: controller));
    await tester.pumpAndSettle();
  }

  Future<void> enterEmail(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextField).at(0), value);
    await tester.pump();
  }

  Future<void> enterPassword(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextField).at(1), value);
    await tester.pump();
  }

  Future<void> tapSignIn(WidgetTester tester) async {
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pump();
  }

  // ── Rendering ─────────────────────────────────────────────────────────────

  group('LoginScreen — rendering', () {
    testWidgets('shows app name and sign-in heading', (tester) async {
      await pumpLogin(tester);
      expect(find.text('DuitKita'), findsOneWidget);
      expect(find.text('Sign in'), findsWidgets);
    });

    testWidgets('shows two input fields', (tester) async {
      await pumpLogin(tester);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('shows sign-in button', (tester) async {
      await pumpLogin(tester);
      expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsOneWidget);
    });

    testWidgets('shows sign-up link', (tester) async {
      await pumpLogin(tester);
      expect(find.text('New to DuitKita?'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('shows forgot-password link', (tester) async {
      await pumpLogin(tester);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('password field is obscured by default', (tester) async {
      await pumpLogin(tester);
      final pwField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(pwField.obscureText, isTrue);
    });
  });

  // ── Validation ────────────────────────────────────────────────────────────

  group('LoginScreen — validation', () {
    testWidgets('shows email error when submitted with empty email',
        (tester) async {
      await pumpLogin(tester);
      await tapSignIn(tester);
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('shows email error for malformed email', (tester) async {
      await pumpLogin(tester);
      await enterEmail(tester, 'notanemail');
      await tapSignIn(tester);
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('shows password error for short password', (tester) async {
      await pumpLogin(tester);
      await enterEmail(tester, 'user@example.com');
      await enterPassword(tester, 'abc');
      await tapSignIn(tester);
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
      expect(find.text('Please enter a valid email'), findsNothing);
    });

    testWidgets('shows both errors when both fields are invalid', (tester) async {
      await pumpLogin(tester);
      await enterEmail(tester, 'bad');
      await enterPassword(tester, '12');
      await tapSignIn(tester);
      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('clears email error when user types a valid email',
        (tester) async {
      await pumpLogin(tester);
      await tapSignIn(tester); // trigger error
      expect(find.text('Please enter a valid email'), findsOneWidget);

      await enterEmail(tester, 'user@example.com');
      expect(find.text('Please enter a valid email'), findsNothing);
    });

    testWidgets('no errors shown before first submit', (tester) async {
      await pumpLogin(tester);
      expect(find.text('Please enter a valid email'), findsNothing);
      expect(find.text('Password must be at least 6 characters'), findsNothing);
    });
  });

  // ── Password visibility ───────────────────────────────────────────────────

  group('LoginScreen — password visibility toggle', () {
    testWidgets('password becomes visible after tapping eye icon', (tester) async {
      await pumpLogin(tester);
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
          isTrue);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
          isFalse);
    });

    testWidgets('tapping eye icon again re-hides password', (tester) async {
      await pumpLogin(tester);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
          isTrue);
    });
  });

  // ── Loading state ─────────────────────────────────────────────────────────

  group('LoginScreen — loading state', () {
    testWidgets('shows spinner while sign-in is in progress', (tester) async {
      final completer = Completer<AuthResponse>();
      final ctrl = fakeAuthController(signInCompleter: completer);
      await pumpLogin(tester, controller: ctrl);

      await enterEmail(tester, 'user@example.com');
      await enterPassword(tester, 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsNothing);

      completer.complete(
          AuthResponse(user: null, error: AuthError.invalidCredential));
      await tester.pumpAndSettle();
    });

    testWidgets('hides spinner after sign-in completes', (tester) async {
      await pumpLogin(tester);
      await enterEmail(tester, 'user@example.com');
      await enterPassword(tester, 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsOneWidget);
    });
  });
}
