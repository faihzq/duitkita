import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/models/debt_model.dart';

void main() {
  final fixedDate = DateTime(2024, 1, 1);
  final fixedTs = Timestamp.fromDate(fixedDate);

  DebtModel makeDebt({
    double totalAmount = 12000.0,
    double monthlyPayment = 1000.0,
    double totalPaid = 3000.0,
    String type = 'debt',
  }) =>
      DebtModel(
        id: 'debt-1',
        userId: 'uid-001',
        title: 'Car Loan',
        creditor: 'Maybank',
        totalAmount: totalAmount,
        monthlyPayment: monthlyPayment,
        totalPaid: totalPaid,
        startDate: fixedDate,
        createdAt: fixedDate,
        updatedAt: fixedDate,
        type: type,
      );

  group('DebtModel.fromMap', () {
    test('parses all fields correctly', () {
      final map = {
        'userId': 'uid-001',
        'title': 'Car Loan',
        'description': 'Proton X50',
        'creditor': 'Maybank',
        'totalAmount': 50000.0,
        'monthlyPayment': 800.0,
        'totalPaid': 9600.0,
        'startDate': fixedTs,
        'dueDay': 5,
        'category': 'car',
        'type': 'debt',
        'isActive': true,
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
      };

      final model = DebtModel.fromMap(map, 'debt-1');

      expect(model.id, 'debt-1');
      expect(model.userId, 'uid-001');
      expect(model.title, 'Car Loan');
      expect(model.description, 'Proton X50');
      expect(model.creditor, 'Maybank');
      expect(model.totalAmount, 50000.0);
      expect(model.monthlyPayment, 800.0);
      expect(model.totalPaid, 9600.0);
      expect(model.dueDay, 5);
      expect(model.category, 'car');
      expect(model.type, 'debt');
      expect(model.isActive, true);
    });

    test('applies defaults for missing fields', () {
      final model = DebtModel.fromMap({}, 'debt-2');

      expect(model.totalAmount, 0.0);
      expect(model.monthlyPayment, 0.0);
      expect(model.totalPaid, 0.0);
      expect(model.dueDay, 1);
      expect(model.category, 'other');
      expect(model.type, 'debt');
      expect(model.isActive, true);
    });
  });

  group('DebtModel computed properties', () {
    test('remainingBalance = totalAmount - totalPaid', () {
      final debt = makeDebt(totalAmount: 12000, totalPaid: 3000);
      expect(debt.remainingBalance, 9000.0);
    });

    test('remainingBalance clamps to 0 when overpaid', () {
      final debt = makeDebt(totalAmount: 5000, totalPaid: 6000);
      expect(debt.remainingBalance, 0.0);
    });

    test('progressPercent is totalPaid / totalAmount', () {
      final debt = makeDebt(totalAmount: 10000, totalPaid: 2500);
      expect(debt.progressPercent, closeTo(0.25, 0.001));
    });

    test('progressPercent clamps to 1.0 when overpaid', () {
      final debt = makeDebt(totalAmount: 1000, totalPaid: 1500);
      expect(debt.progressPercent, 1.0);
    });

    test('estimatedTotalMonths = ceil(totalAmount / monthlyPayment)', () {
      final debt = makeDebt(totalAmount: 10000, monthlyPayment: 3000, totalPaid: 0);
      expect(debt.estimatedTotalMonths, 4); // ceil(10000/3000) = 4
    });

    test('monthsRemaining = ceil(remainingBalance / monthlyPayment)', () {
      final debt = makeDebt(totalAmount: 12000, monthlyPayment: 1000, totalPaid: 3000);
      expect(debt.monthsRemaining, 9); // remaining = 9000, ceil(9000/1000) = 9
    });

    test('bill type returns 0 for debt-specific computed props', () {
      final bill = makeDebt(type: 'bill');
      expect(bill.remainingBalance, 0.0);
      expect(bill.progressPercent, 0.0);
      expect(bill.estimatedTotalMonths, 0);
      expect(bill.monthsRemaining, 0);
    });

    test('isBill and isDebt are mutually exclusive', () {
      final debt = makeDebt(type: 'debt');
      expect(debt.isDebt, isTrue);
      expect(debt.isBill, isFalse);

      final bill = makeDebt(type: 'bill');
      expect(bill.isBill, isTrue);
      expect(bill.isDebt, isFalse);
    });
  });

  group('DebtModel categories', () {
    test('categoriesForType returns debt categories for debt', () {
      final cats = DebtModel.categoriesForType('debt');
      expect(cats.map((c) => c.value), containsAll(['car', 'personal', 'housing', 'education', 'other']));
    });

    test('categoriesForType returns bill categories for bill', () {
      final cats = DebtModel.categoriesForType('bill');
      expect(cats.map((c) => c.value), containsAll(['internet', 'phone', 'streaming', 'insurance', 'utilities']));
    });

    test('findCategory returns correct category', () {
      final cat = DebtModel.findCategory('debt', 'car');
      expect(cat, isNotNull);
      expect(cat!.label, 'Car');
    });

    test('findCategory returns null for unknown category', () {
      final cat = DebtModel.findCategory('debt', 'unknown-value');
      expect(cat, isNull);
    });

    test('categoryInfo falls back to other for unknown value', () {
      final debt = makeDebt().copyWith(category: 'nonexistent');
      expect(debt.categoryInfo.value, 'other');
    });
  });

  group('DebtModel.toMap', () {
    test('serialises fields without id', () {
      final debt = makeDebt();
      final map = debt.toMap();

      expect(map['title'], 'Car Loan');
      expect(map['totalAmount'], 12000.0);
      expect(map['type'], 'debt');
      expect(map.containsKey('id'), isFalse);
    });
  });

  group('DebtModel.copyWith', () {
    test('overrides specified fields only', () {
      final original = makeDebt();
      final copy = original.copyWith(title: 'Personal Loan', totalAmount: 5000);

      expect(copy.id, original.id);
      expect(copy.title, 'Personal Loan');
      expect(copy.totalAmount, 5000.0);
      expect(copy.creditor, original.creditor);
      expect(copy.type, original.type);
    });
  });
}
