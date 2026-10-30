import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/models/user_profile.dart';

void main() {
  final fixedDate = DateTime(2024, 3, 20);
  final fixedTs = Timestamp.fromDate(fixedDate);

  Map<String, dynamic> fullMap() => {
    'name': 'Fairul Haziq',
    'email': 'fairul@example.com',
    'phoneNumber': '+60123456789',
    'profileImageUrl': 'https://storage.example.com/photo.jpg',
    'showJdtMatches': true,
    'notifyJdtMatches': true,
    'createdAt': fixedTs,
    'updatedAt': fixedTs,
  };

  group('UserProfile.fromMap', () {
    test('parses all fields correctly', () {
      final profile = UserProfile.fromMap(fullMap(), 'uid-001');

      expect(profile.uid, 'uid-001');
      expect(profile.name, 'Fairul Haziq');
      expect(profile.email, 'fairul@example.com');
      expect(profile.phoneNumber, '+60123456789');
      expect(profile.profileImageUrl, 'https://storage.example.com/photo.jpg');
      expect(profile.showJdtMatches, true);
      expect(profile.notifyJdtMatches, true);
      expect(profile.createdAt, fixedDate);
      expect(profile.updatedAt, fixedDate);
    });

    test('applies defaults for missing fields', () {
      final profile = UserProfile.fromMap({}, 'uid-002');

      expect(profile.uid, 'uid-002');
      expect(profile.name, isNull);
      expect(profile.email, isNull);
      expect(profile.phoneNumber, isNull);
      expect(profile.profileImageUrl, isNull);
      expect(profile.showJdtMatches, false);
      // Reminders stay off for every account that predates the toggle.
      expect(profile.notifyJdtMatches, false);
    });

    test('null timestamps default to a recent DateTime', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final profile = UserProfile.fromMap({}, 'uid-003');
      expect(profile.createdAt.isAfter(before), isTrue);
    });
  });

  group('UserProfile.toMap', () {
    test('serialises all fields', () {
      final profile = UserProfile.fromMap(fullMap(), 'uid-001');
      final map = profile.toMap();

      expect(map['name'], 'Fairul Haziq');
      expect(map['email'], 'fairul@example.com');
      expect(map['phoneNumber'], '+60123456789');
      expect(map['profileImageUrl'], 'https://storage.example.com/photo.jpg');
      expect(map['showJdtMatches'], true);
      expect(map['notifyJdtMatches'], true);
    });

    test('does not include uid in toMap', () {
      final profile = UserProfile.fromMap(fullMap(), 'uid-001');
      expect(profile.toMap().containsKey('uid'), isFalse);
    });
  });

  group('UserProfile.copyWith', () {
    test('overrides specified fields', () {
      final original = UserProfile.fromMap(fullMap(), 'uid-001');
      final copy = original.copyWith(
        name: 'New Name',
        showJdtMatches: false,
        profileImageUrl: 'https://new-photo.jpg',
      );

      expect(copy.uid, 'uid-001');
      expect(copy.name, 'New Name');
      expect(copy.showJdtMatches, false);
      // Untouched fields carry over.
      expect(copy.notifyJdtMatches, original.notifyJdtMatches);
      expect(copy.profileImageUrl, 'https://new-photo.jpg');
      expect(copy.email, original.email);
      expect(copy.phoneNumber, original.phoneNumber);
    });

    test('turns the reminder flag off', () {
      // `?? this.field` keeps a passed `false`; the guard is that it is not
      // mistaken for "not supplied", which would make the toggle unturnoffable.
      final original = UserProfile.fromMap(fullMap(), 'uid-001');
      expect(original.notifyJdtMatches, isTrue);

      expect(
        original.copyWith(notifyJdtMatches: false).notifyJdtMatches,
        isFalse,
      );
    });
  });
}
