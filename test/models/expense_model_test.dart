import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/models/expense_model.dart';

void main() {
  final fixedDate = DateTime(2025, 4, 5);
  final fixedTs = Timestamp.fromDate(fixedDate);

  Map<String, dynamic> fullMap({String status = 'pending'}) => {
        'groupId': 'grp-1',
        'requestedBy': 'uid-001',
        'requestedByName': 'Fairul Haziq',
        'title': 'Team lunch',
        'description': 'McDonalds',
        'amount': 80.0,
        'status': status,
        'receiptUrl': 'https://storage.example.com/receipt.jpg',
        'approvedBy': null,
        'approvedByName': null,
        'approvedAt': null,
        'rejectedBy': null,
        'rejectedByName': null,
        'rejectedAt': null,
        'createdAt': fixedTs,
      };

  group('ExpenseModel.fromMap', () {
    test('parses all fields for pending status', () {
      final model = ExpenseModel.fromMap(fullMap(), 'exp-1');

      expect(model.id, 'exp-1');
      expect(model.groupId, 'grp-1');
      expect(model.requestedBy, 'uid-001');
      expect(model.requestedByName, 'Fairul Haziq');
      expect(model.title, 'Team lunch');
      expect(model.amount, 80.0);
      expect(model.status, ExpenseStatus.pending);
      expect(model.createdAt, fixedDate);
      expect(model.approvedAt, isNull);
    });

    test('parses approved status correctly', () {
      final map = fullMap(status: 'approved')
        ..addAll({
          'approvedBy': 'uid-admin',
          'approvedByName': 'Admin',
          'approvedAt': fixedTs,
        });

      final model = ExpenseModel.fromMap(map, 'exp-2');
      expect(model.status, ExpenseStatus.approved);
      expect(model.approvedBy, 'uid-admin');
      expect(model.approvedAt, fixedDate);
    });

    test('parses rejected status correctly', () {
      final map = fullMap(status: 'rejected')
        ..addAll({
          'rejectedBy': 'uid-admin',
          'rejectedByName': 'Admin',
          'rejectedAt': fixedTs,
        });

      final model = ExpenseModel.fromMap(map, 'exp-3');
      expect(model.status, ExpenseStatus.rejected);
      expect(model.rejectedBy, 'uid-admin');
      expect(model.rejectedAt, fixedDate);
    });

    test('unknown status defaults to pending', () {
      final model = ExpenseModel.fromMap({'status': 'invalid-value', 'createdAt': fixedTs}, 'exp-4');
      expect(model.status, ExpenseStatus.pending);
    });

    test('applies defaults for missing fields', () {
      final model = ExpenseModel.fromMap({}, 'exp-5');
      expect(model.groupId, '');
      expect(model.amount, 0.0);
      expect(model.status, ExpenseStatus.pending);
      expect(model.description, isNull);
      expect(model.receiptUrl, isNull);
    });

    test('handles integer amount as double', () {
      final model = ExpenseModel.fromMap({'amount': 50, 'createdAt': fixedTs}, 'exp-6');
      expect(model.amount, 50.0);
      expect(model.amount, isA<double>());
    });
  });

  group('ExpenseModel.toMap', () {
    test('serialises status as string name', () {
      final model = ExpenseModel.fromMap(fullMap(status: 'approved')..addAll({'approvedAt': fixedTs}), 'exp-1');
      final map = model.toMap();

      expect(map['status'], 'approved');
      expect(map['groupId'], 'grp-1');
      expect(map['amount'], 80.0);
    });

    test('does not include id in toMap', () {
      final model = ExpenseModel.fromMap(fullMap(), 'exp-1');
      expect(model.toMap().containsKey('id'), isFalse);
    });
  });
}
