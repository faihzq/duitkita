import 'package:flutter_test/flutter_test.dart';

import 'package:duitkita/services/auth_service.dart';
import 'package:duitkita/utils/utils.dart';

void main() {
  // ── isValidEmail ──────────────────────────────────────────────────────────

  group('isValidEmail', () {
    test('returns true for standard email', () {
      expect(isValidEmail('user@example.com'), isTrue);
    });

    test('returns true for email with subdomain', () {
      expect(isValidEmail('user@mail.example.co.uk'), isTrue);
    });

    test('returns true for email with plus sign', () {
      expect(isValidEmail('user+tag@example.com'), isTrue);
    });

    test('returns true for email with underscores and dots in local part', () {
      expect(isValidEmail('first.last_name@example.org'), isTrue);
    });

    test('returns false for empty string', () {
      expect(isValidEmail(''), isFalse);
    });

    test('returns false when @ is missing', () {
      expect(isValidEmail('userexample.com'), isFalse);
    });

    test('returns false when domain has no dot', () {
      expect(isValidEmail('user@example'), isFalse);
    });

    test('returns false when TLD is too short', () {
      expect(isValidEmail('user@example.c'), isFalse);
    });

    test('returns false for plain string', () {
      expect(isValidEmail('notvalid'), isFalse);
    });

    test('returns false when local part is missing', () {
      expect(isValidEmail('@example.com'), isFalse);
    });
  });

  // ── isValidPassword ───────────────────────────────────────────────────────

  group('isValidPassword', () {
    test('returns true for exactly 6 characters', () {
      expect(isValidPassword('abcdef'), isTrue);
    });

    test('returns true for long password', () {
      expect(isValidPassword('supersecretpassword123'), isTrue);
    });

    test('returns false for 5 characters', () {
      expect(isValidPassword('abcde'), isFalse);
    });

    test('returns false for empty string', () {
      expect(isValidPassword(''), isFalse);
    });

    test('returns false for single character', () {
      expect(isValidPassword('a'), isFalse);
    });
  });

  // ── getAuthErrorMessage ───────────────────────────────────────────────────

  group('getAuthErrorMessage', () {
    test('invalidEmail returns correct message', () {
      expect(
        getAuthErrorMessage(AuthError.invalidEmail),
        'The email address is not valid.',
      );
    });

    test('userDisabled returns correct message', () {
      expect(
        getAuthErrorMessage(AuthError.userDisabled),
        'This user has been disabled.',
      );
    });

    test('userNotFound returns correct message', () {
      expect(
        getAuthErrorMessage(AuthError.userNotFound),
        'No user found for this email.',
      );
    });

    test('wrongPassword returns correct message', () {
      expect(
        getAuthErrorMessage(AuthError.wrongPassword),
        contains('If you signed up with Google'),
      );
    });

    test('emailAlreadyInUse returns correct message', () {
      expect(
        getAuthErrorMessage(AuthError.emailAlreadyInUse),
        'The email address is already in use.',
      );
    });

    test('invalidCredential returns correct message', () {
      expect(
        getAuthErrorMessage(AuthError.invalidCredential),
        contains('If you signed up with Google'),
      );
    });

    test('operationNotAllowed returns correct message', () {
      expect(
        getAuthErrorMessage(AuthError.operationNotAllowed),
        'This operation is not allowed.',
      );
    });

    test('weakPassword returns correct message', () {
      expect(
        getAuthErrorMessage(AuthError.weakPassword),
        'The password is too weak.',
      );
    });

    test('undefined returns fallback message', () {
      expect(
        getAuthErrorMessage(AuthError.undefined),
        'An unknown error occurred.',
      );
    });

    test('null returns fallback message', () {
      expect(getAuthErrorMessage(null), 'An unknown error occurred.');
    });
  });
}
