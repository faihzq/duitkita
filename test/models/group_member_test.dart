import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/models/group_member.dart';

void main() {
  final fixedDate = DateTime(2024, 6, 1);
  final fixedTs = Timestamp.fromDate(fixedDate);

  Map<String, dynamic> fullMap() => {
        'userId': 'uid-001',
        'userName': 'Fairul Haziq',
        'userEmail': 'fairul@example.com',
        'isAdmin': true,
        'joinedAt': fixedTs,
        'totalPaid': 600.0,
        'paymentCount': 3,
      };

  group('GroupMember.fromMap', () {
    test('parses all fields correctly', () {
      final member = GroupMember.fromMap(fullMap());

      expect(member.userId, 'uid-001');
      expect(member.userName, 'Fairul Haziq');
      expect(member.userEmail, 'fairul@example.com');
      expect(member.isAdmin, true);
      expect(member.joinedAt, fixedDate);
      expect(member.totalPaid, 600.0);
      expect(member.paymentCount, 3);
    });

    test('applies defaults for missing fields', () {
      final member = GroupMember.fromMap({});

      expect(member.userId, '');
      expect(member.userName, '');
      expect(member.userEmail, isNull);
      expect(member.isAdmin, false);
      expect(member.totalPaid, 0.0);
      expect(member.paymentCount, 0);
    });

    test('handles integer totalPaid as double', () {
      final member = GroupMember.fromMap({'totalPaid': 200});
      expect(member.totalPaid, 200.0);
      expect(member.totalPaid, isA<double>());
    });
  });

  group('GroupMember.toMap', () {
    test('serialises all fields', () {
      final member = GroupMember.fromMap(fullMap());
      final map = member.toMap();

      expect(map['userId'], 'uid-001');
      expect(map['userName'], 'Fairul Haziq');
      expect(map['isAdmin'], true);
      expect(map['totalPaid'], 600.0);
      expect(map['paymentCount'], 3);
    });
  });

  group('GroupMember.copyWith', () {
    test('overrides specified fields', () {
      final original = GroupMember.fromMap(fullMap());
      final copy = original.copyWith(isAdmin: false, totalPaid: 800.0, paymentCount: 4);

      expect(copy.userId, original.userId);
      expect(copy.userName, original.userName);
      expect(copy.isAdmin, false);
      expect(copy.totalPaid, 800.0);
      expect(copy.paymentCount, 4);
    });

    test('preserves all fields when no args given', () {
      final original = GroupMember.fromMap(fullMap());
      final copy = original.copyWith();

      expect(copy.userId, original.userId);
      expect(copy.userName, original.userName);
      expect(copy.isAdmin, original.isAdmin);
      expect(copy.totalPaid, original.totalPaid);
    });
  });
}
