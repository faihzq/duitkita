import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/utils/username.dart';

void main() {
  group('normaliseUsername', () {
    test('lowercases and trims', () {
      expect(normaliseUsername('  FairulHaziq '), 'fairulhaziq');
    });

    test('strips the decorative @', () {
      expect(normaliseUsername('@fairul'), 'fairul');
      // Pasted twice by accident.
      expect(normaliseUsername('@@fairul'), 'fairul');
    });

    test('makes case differences the same handle', () {
      expect(normaliseUsername('@Fairul'), normaliseUsername('fairul'));
    });
  });

  group('usernameError', () {
    test('accepts a normal handle', () {
      expect(usernameError('fairulhaziq'), isNull);
      expect(usernameError('a_b_1'), isNull);
      expect(usernameError('@Fairul'), isNull);
    });

    test('rejects one that is too short or too long', () {
      expect(usernameError('ab'), contains('3'));
      expect(usernameError('a' * 21), contains('20'));
      expect(usernameError('abc'), isNull);
      expect(usernameError('a' * 20), isNull);
    });

    test('requires a leading letter', () {
      expect(usernameError('1fairul'), 'Must start with a letter');
      expect(usernameError('_fairul'), 'Must start with a letter');
    });

    test('rejects punctuation and spaces', () {
      expect(usernameError('fairul haziq'), isNotNull);
      expect(usernameError('fairul.haziq'), isNotNull);
      expect(usernameError('fairul-haziq'), isNotNull);
      // An email is not a handle.
      expect(usernameError('fairul@mail.com'), isNotNull);
    });

    test('rejects empty', () {
      expect(usernameError(''), 'Pick a username');
      expect(usernameError('   '), 'Pick a username');
    });
  });

  group('suggestUsername', () {
    test('prefers the name', () {
      expect(
        suggestUsername(name: 'Fairul Haziq', email: 'other@mail.com'),
        'fairulhaziq',
      );
    });

    test('falls back to the email local part', () {
      expect(
        suggestUsername(name: null, email: 'fairul.haziq@gmail.com'),
        'fairulhaziq',
      );
    });

    test('drops leading digits so the handle starts with a letter', () {
      expect(suggestUsername(name: '99 Fairul'), 'fairul');
    });

    test('truncates to the maximum length', () {
      final handle = suggestUsername(name: 'a' * 40);
      expect(handle.length, kUsernameMaxLength);
    });

    test('always returns something usable', () {
      // Nothing to work with: digits only, no email.
      final handle = suggestUsername(name: '12345', uid: 'abc123XYZ');
      expect(usernameError(handle), isNull);
    });

    test('every suggestion is itself valid', () {
      for (final name in ['Ibu', 'Along', 'Siti Nurhaliza', 'A B', '  x  ']) {
        final handle = suggestUsername(name: name, email: 'fallback@mail.com');
        expect(usernameError(handle), isNull, reason: 'from "$name"');
      }
    });
  });

  group('usernameAttempt', () {
    test('leaves the first attempt alone', () {
      expect(usernameAttempt('fairul', 1), 'fairul');
    });

    test('appends the number for later attempts', () {
      expect(usernameAttempt('fairul', 2), 'fairul2');
      expect(usernameAttempt('fairul', 7), 'fairul7');
    });

    // Trim the base, not the number — otherwise long names would collide again.
    test('stays within the length limit', () {
      final handle = usernameAttempt('a' * 20, 10);
      expect(handle.length, kUsernameMaxLength);
      expect(handle.endsWith('10'), isTrue);
      expect(usernameError(handle), isNull);
    });
  });
}
