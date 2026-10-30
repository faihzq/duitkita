import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/models/group_model.dart';

void main() {
  final fixedDate = DateTime(2025, 1, 15);
  final fixedTs = Timestamp.fromDate(fixedDate);

  Map<String, dynamic> fullMap() => {
        'name': 'Siblings',
        'description': 'Duit adik beradik',
        'createdBy': 'uid-001',
        'monthlyAmount': 200.0,
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
        'memberIds': ['uid-001', 'uid-002'],
        'memberCount': 2,
        'reminderDay': 15,
        'bankName': 'Maybank',
        'accountNumber': '1234567890',
        'accountHolderName': 'Fairul Haziq',
        'autoApprovePayments': true,
        'autoApproveExpenses': false,
      };

  group('GroupModel.fromMap', () {
    test('parses all fields correctly', () {
      final model = GroupModel.fromMap(fullMap(), 'grp-1');

      expect(model.id, 'grp-1');
      expect(model.name, 'Siblings');
      expect(model.description, 'Duit adik beradik');
      expect(model.createdBy, 'uid-001');
      expect(model.monthlyAmount, 200.0);
      expect(model.createdAt, fixedDate);
      expect(model.memberIds, ['uid-001', 'uid-002']);
      expect(model.memberCount, 2);
      expect(model.reminderDay, 15);
      expect(model.bankName, 'Maybank');
      expect(model.accountNumber, '1234567890');
      expect(model.accountHolderName, 'Fairul Haziq');
      expect(model.autoApprovePayments, true);
      expect(model.autoApproveExpenses, false);
    });

    test('applies defaults for missing fields', () {
      final model = GroupModel.fromMap({}, 'grp-2');

      expect(model.name, '');
      expect(model.monthlyAmount, 30.0);
      expect(model.memberIds, isEmpty);
      expect(model.memberCount, 0);
      expect(model.reminderDay, 28);
      expect(model.autoApprovePayments, false);
      expect(model.autoApproveExpenses, false);
      expect(model.bankName, isNull);
    });

    test('handles integer monthlyAmount', () {
      final model = GroupModel.fromMap({'monthlyAmount': 100}, 'grp-3');
      expect(model.monthlyAmount, 100.0);
      expect(model.monthlyAmount, isA<double>());
    });

    test('null timestamps default to a recent DateTime', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final model = GroupModel.fromMap({}, 'grp-4');
      expect(model.createdAt.isAfter(before), isTrue);
    });
  });

  group('GroupModel.toMap', () {
    test('serialises all fields', () {
      final model = GroupModel.fromMap(fullMap(), 'grp-1');
      final map = model.toMap();

      expect(map['name'], 'Siblings');
      expect(map['monthlyAmount'], 200.0);
      expect(map['memberIds'], ['uid-001', 'uid-002']);
      expect(map['reminderDay'], 15);
      expect(map['bankName'], 'Maybank');
      expect(map['autoApprovePayments'], true);
    });

    test('does not include id in toMap', () {
      final model = GroupModel.fromMap(fullMap(), 'grp-1');
      expect(model.toMap().containsKey('id'), isFalse);
    });
  });

  group('GroupModel.copyWith', () {
    test('overrides specified fields', () {
      final original = GroupModel.fromMap(fullMap(), 'grp-1');
      final copy = original.copyWith(
        name: 'New Name',
        monthlyAmount: 300.0,
        autoApprovePayments: false,
      );

      expect(copy.id, 'grp-1');
      expect(copy.name, 'New Name');
      expect(copy.monthlyAmount, 300.0);
      expect(copy.autoApprovePayments, false);
      expect(copy.description, original.description);
      expect(copy.memberIds, original.memberIds);
    });

    test('preserves original when no args given', () {
      final original = GroupModel.fromMap(fullMap(), 'grp-1');
      final copy = original.copyWith();

      expect(copy.name, original.name);
      expect(copy.monthlyAmount, original.monthlyAmount);
      expect(copy.reminderDay, original.reminderDay);
    });
  });
}
