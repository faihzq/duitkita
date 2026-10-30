import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/models/payment_model.dart';

void main() {
  final fixedDate = DateTime(2025, 3, 10);
  final fixedTs = Timestamp.fromDate(fixedDate);

  Map<String, dynamic> fullMap() => {
        'groupId': 'grp-1',
        'userId': 'uid-001',
        'userName': 'Fairul Haziq',
        'amount': 200.0,
        'paymentDate': fixedTs,
        'month': 3,
        'year': 2025,
        'notes': 'March payment',
        'receiptUrl': 'https://storage.example.com/receipt.jpg',
        'createdAt': fixedTs,
        'paymentMethod': 'duitnow',
        'paymentStatus': 'confirmed',
        'transactionReference': 'TXN-001',
        'verifiedBy': 'uid-admin',
        'verifiedByName': 'Admin',
        'verifiedAt': fixedTs,
        'rejectionReason': null,
      };

  group('PaymentModel.fromMap', () {
    test('parses all fields correctly', () {
      final model = PaymentModel.fromMap(fullMap(), 'pay-1');

      expect(model.id, 'pay-1');
      expect(model.groupId, 'grp-1');
      expect(model.userId, 'uid-001');
      expect(model.userName, 'Fairul Haziq');
      expect(model.amount, 200.0);
      expect(model.paymentDate, fixedDate);
      expect(model.month, 3);
      expect(model.year, 2025);
      expect(model.notes, 'March payment');
      expect(model.paymentMethod, 'duitnow');
      expect(model.paymentStatus, 'confirmed');
      expect(model.transactionReference, 'TXN-001');
      expect(model.verifiedBy, 'uid-admin');
      expect(model.verifiedAt, fixedDate);
    });

    test('applies defaults for missing fields', () {
      final model = PaymentModel.fromMap({}, 'pay-2');

      expect(model.groupId, '');
      expect(model.amount, 0.0);
      expect(model.paymentMethod, 'cash');
      expect(model.paymentStatus, 'pending');
      expect(model.notes, isNull);
      expect(model.receiptUrl, isNull);
      expect(model.verifiedAt, isNull);
    });

    test('parses integer amount as double', () {
      final model = PaymentModel.fromMap({'amount': 100}, 'pay-3');
      expect(model.amount, 100.0);
      expect(model.amount, isA<double>());
    });

    test('verifiedAt is null when not set', () {
      final map = fullMap()..remove('verifiedAt');
      final model = PaymentModel.fromMap(map, 'pay-4');
      expect(model.verifiedAt, isNull);
    });
  });

  group('PaymentModel.toMap', () {
    test('serialises all fields', () {
      final model = PaymentModel.fromMap(fullMap(), 'pay-1');
      final map = model.toMap();

      expect(map['groupId'], 'grp-1');
      expect(map['amount'], 200.0);
      expect(map['paymentStatus'], 'confirmed');
      expect(map['paymentMethod'], 'duitnow');
      expect(map['transactionReference'], 'TXN-001');
    });

    test('does not include id in toMap', () {
      final model = PaymentModel.fromMap(fullMap(), 'pay-1');
      expect(model.toMap().containsKey('id'), isFalse);
    });

    test('pending payment has null verification fields', () {
      final map = {
        'groupId': 'grp-1',
        'userId': 'uid-001',
        'userName': 'User',
        'amount': 50.0,
        'paymentDate': fixedTs,
        'month': 3,
        'year': 2025,
        'createdAt': fixedTs,
        'paymentStatus': 'pending',
      };
      final model = PaymentModel.fromMap(map, 'pay-5');
      final out = model.toMap();

      expect(out['paymentStatus'], 'pending');
      expect(out['verifiedBy'], isNull);
      expect(out['verifiedByName'], isNull);
      expect(out['verifiedAt'], isNull);
    });
  });
}
