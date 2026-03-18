import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/debt_model.dart';
import 'package:duitkita/models/debt_payment_model.dart';

class DebtService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _debts => _firestore.collection('debts');

  // Create a new debt
  Future<String> createDebt({
    required String userId,
    required String title,
    String? description,
    required String creditor,
    required double totalAmount,
    required double monthlyPayment,
    required DateTime startDate,
    int dueDay = 1,
    String category = 'other',
    String type = 'debt',
    double totalPaid = 0,
  }) async {
    final now = DateTime.now();
    final doc = await _debts.add({
      'userId': userId,
      'title': title,
      'description': description,
      'creditor': creditor,
      'totalAmount': totalAmount,
      'monthlyPayment': monthlyPayment,
      'totalPaid': totalPaid,
      'startDate': startDate,
      'dueDay': dueDay,
      'category': category,
      'type': type,
      'isActive': true,
      'createdAt': now,
      'updatedAt': now,
    });
    return doc.id;
  }

  // Get all active debts for a user
  Stream<List<DebtModel>> getUserDebtsStream(String userId) {
    return _debts
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => DebtModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get all debts (including completed) for a user
  Stream<List<DebtModel>> getAllUserDebtsStream(String userId) {
    return _debts
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => DebtModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get single debt stream
  Stream<DebtModel?> getDebtStream(String debtId) {
    return _debts.doc(debtId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return DebtModel.fromMap(snap.data() as Map<String, dynamic>, snap.id);
    });
  }

  // Update debt
  Future<void> updateDebt(String debtId, Map<String, dynamic> data) async {
    data['updatedAt'] = DateTime.now();
    await _debts.doc(debtId).update(data);
  }

  // Delete debt and its payments subcollection
  Future<void> deleteDebt(String debtId) async {
    final payments = await _debts.doc(debtId).collection('payments').get();
    final batch = _firestore.batch();
    for (final doc in payments.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_debts.doc(debtId));
    await batch.commit();
  }

  // Mark debt as completed
  Future<void> markDebtComplete(String debtId) async {
    await _debts.doc(debtId).update({
      'isActive': false,
      'updatedAt': DateTime.now(),
    });
  }

  // Reactivate a completed debt
  Future<void> reactivateDebt(String debtId) async {
    await _debts.doc(debtId).update({
      'isActive': true,
      'updatedAt': DateTime.now(),
    });
  }

  // Add a payment to a debt
  Future<void> addDebtPayment({
    required String debtId,
    required double amount,
    required DateTime paymentDate,
    String? notes,
  }) async {
    final batch = _firestore.batch();

    // Add payment to subcollection
    final paymentRef = _debts.doc(debtId).collection('payments').doc();
    batch.set(paymentRef, {
      'debtId': debtId,
      'amount': amount,
      'paymentDate': paymentDate,
      'month': paymentDate.month,
      'year': paymentDate.year,
      'notes': notes,
      'createdAt': DateTime.now(),
    });

    // Update totalPaid on parent debt
    batch.update(_debts.doc(debtId), {
      'totalPaid': FieldValue.increment(amount),
      'updatedAt': DateTime.now(),
    });

    await batch.commit();
  }

  // Get payments for a debt
  Stream<List<DebtPaymentModel>> getDebtPaymentsStream(String debtId) {
    return _debts
        .doc(debtId)
        .collection('payments')
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => DebtPaymentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Check if payment exists for a specific month/year
  Future<bool> hasDebtPaidForMonth({
    required String debtId,
    required int month,
    required int year,
  }) async {
    try {
      final snapshot = await _debts
          .doc(debtId)
          .collection('payments')
          .where('month', isEqualTo: month)
          .where('year', isEqualTo: year)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Delete a payment
  Future<void> deleteDebtPayment({
    required String debtId,
    required String paymentId,
    required double amount,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_debts.doc(debtId).collection('payments').doc(paymentId));
    batch.update(_debts.doc(debtId), {
      'totalPaid': FieldValue.increment(-amount),
      'updatedAt': DateTime.now(),
    });
    await batch.commit();
  }
}

// Providers
final debtServiceProvider = Provider<DebtService>((ref) => DebtService());

final userDebtsStreamProvider = StreamProvider.family<List<DebtModel>, String>((ref, userId) {
  return ref.watch(debtServiceProvider).getUserDebtsStream(userId);
});

final allUserDebtsStreamProvider = StreamProvider.family<List<DebtModel>, String>((ref, userId) {
  return ref.watch(debtServiceProvider).getAllUserDebtsStream(userId);
});

final debtStreamProvider = StreamProvider.family<DebtModel?, String>((ref, debtId) {
  return ref.watch(debtServiceProvider).getDebtStream(debtId);
});

final debtPaymentsStreamProvider = StreamProvider.family<List<DebtPaymentModel>, String>((ref, debtId) {
  return ref.watch(debtServiceProvider).getDebtPaymentsStream(debtId);
});

// Provider for current month payment status of a debt/bill
final debtMonthPaidProvider = FutureProvider.family<bool, String>((ref, debtId) async {
  final debtService = ref.read(debtServiceProvider);
  final now = DateTime.now();
  return debtService.hasDebtPaidForMonth(
    debtId: debtId,
    month: now.month,
    year: now.year,
  );
});
