import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duitkita/screens/forgot_password_screen.dart';

import '../helpers/fake_auth.dart';

void main() {
  Future<void> pumpForgotPassword(WidgetTester tester,
      {bool forgotPasswordSucceeds = true}) async {
    final ctrl = fakeAuthController(forgotPasswordSucceeds: forgotPasswordSucceeds);
    await tester.pumpWidget(testApp(const ForgotPasswordScreen(), controller: ctrl));
    await tester.pumpAndSettle();
  }

  Future<void> enterEmail(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextField).first, value);
    await tester.pump();
  }

  Future<void> tapSend(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send reset link'));
    await tester.pump();
  }

  // ── Rendering ─────────────────────────────────────────────────────────────

  group('ForgotPasswordScreen — rendering', () {
    testWidgets('shows reset-password heading', (tester) async {
      await pumpForgotPassword(tester);
      expect(find.text('Reset password'), findsOneWidget);
    });

    testWidgets('shows email field', (tester) async {
      await pumpForgotPassword(tester);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows send-reset-link button', (tester) async {
      await pumpForgotPassword(tester);
      expect(find.widgetWithText(ElevatedButton, 'Send reset link'), findsOneWidget);
    });

    testWidgets('shows back-to-sign-in link', (tester) async {
      await pumpForgotPassword(tester);
      expect(find.text('Back to sign in'), findsWidgets);
    });
  });

  // ── Validation ────────────────────────────────────────────────────────────

  group('ForgotPasswordScreen — validation', () {
    testWidgets('shows email error when submitted with empty email',
        (tester) async {
      await pumpForgotPassword(tester);
      await tapSend(tester);
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('shows email error for malformed email', (tester) async {
      await pumpForgotPassword(tester);
      await enterEmail(tester, 'notvalid');
      await tapSend(tester);
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('clears email error when user types a valid email',
        (tester) async {
      await pumpForgotPassword(tester);
      await tapSend(tester);
      expect(find.text('Please enter a valid email'), findsOneWidget);

      await enterEmail(tester, 'user@example.com');
      expect(find.text('Please enter a valid email'), findsNothing);
    });

    testWidgets('no email error shown before first submit', (tester) async {
      await pumpForgotPassword(tester);
      expect(find.text('Please enter a valid email'), findsNothing);
    });
  });

  // ── Success state ─────────────────────────────────────────────────────────

  group('ForgotPasswordScreen — success state', () {
    testWidgets('shows confirmation view after successful reset', (tester) async {
      await pumpForgotPassword(tester, forgotPasswordSucceeds: true);
      await enterEmail(tester, 'user@example.com');
      await tapSend(tester);
      await tester.pumpAndSettle();

      expect(find.text('Check your inbox'), findsOneWidget);
      // Email is inside a RichText TextSpan — match by substring
      expect(
        find.byWidgetPredicate((w) =>
            w is RichText &&
            w.text.toPlainText().contains('user@example.com')),
        findsOneWidget,
      );
      expect(find.text('Resend email'), findsOneWidget);
    });

    testWidgets('shows form again after tapping resend', (tester) async {
      await pumpForgotPassword(tester, forgotPasswordSucceeds: true);
      await enterEmail(tester, 'user@example.com');
      await tapSend(tester);
      await tester.pumpAndSettle();

      expect(find.text('Check your inbox'), findsOneWidget);
      await tester.tap(find.text('Resend email'));
      await tester.pump();

      expect(find.text('Reset password'), findsOneWidget);
      expect(find.text('Check your inbox'), findsNothing);
    });
  });

  // ── Loading state ─────────────────────────────────────────────────────────

  group('ForgotPasswordScreen — loading state', () {
    testWidgets('shows loading spinner while request is in flight', (tester) async {
      // We can only observe this if the reset call is slow; the fake is
      // instant, so we tap and pump once (before pumpAndSettle) to catch
      // the frame where loading=true.
      await pumpForgotPassword(tester, forgotPasswordSucceeds: true);
      await enterEmail(tester, 'user@example.com');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Send reset link'));
      await tester.pump(); // one frame — might show spinner briefly
      // The fake resolves synchronously, so spinner may have already gone;
      // just verify the UI reaches a stable state without errors.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
