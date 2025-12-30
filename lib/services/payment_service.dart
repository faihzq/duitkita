import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/payment_model.dart';
import 'package:duitkita/services/group_service.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _payments => _firestore.collection('payments');

  // Add payment
  Future<void> addPayment({
    required String groupId,
    required String userId,
    required String userName,
    required double amount,
    required DateTime paymentDate,
    String? notes,
  }) async {
    try {
      final paymentData = {
        'groupId': groupId,
        'userId': userId,
        'userName': userName,
        'amount': amount,
        'paymentDate': paymentDate,
        'month': paymentDate.month,
        'year': paymentDate.year,
        'notes': notes,
        'createdAt': DateTime.now(),
      };

      await _payments.add(paymentData);
    } catch (e) {
      throw Exception('Failed to add payment: $e');
    }
  }

  // Get payments for a group
  Stream<List<PaymentModel>> getGroupPaymentsStream(String groupId) {
    return _payments
        .where('groupId', isEqualTo: groupId)
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => PaymentModel.fromMap(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    ),
                  )
                  .toList(),
        );
  }

  // Get payments for a specific user in a group
  Stream<List<PaymentModel>> getUserPaymentsInGroupStream({
    required String groupId,
    required String userId,
  }) {
    return _payments
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: userId)
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => PaymentModel.fromMap(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    ),
                  )
                  .toList(),
        );
  }

  // Get payments for a specific month/year
  Stream<List<PaymentModel>> getMonthPaymentsStream({
    required String groupId,
    required int month,
    required int year,
  }) {
    return _payments
        .where('groupId', isEqualTo: groupId)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => PaymentModel.fromMap(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    ),
                  )
                  .toList(),
        );
  }

  // Check if user has paid for specific month
  Future<bool> hasUserPaidForMonth({
    required String groupId,
    required String userId,
    required int month,
    required int year,
  }) async {
    try {
      final snapshot =
          await _payments
              .where('groupId', isEqualTo: groupId)
              .where('userId', isEqualTo: userId)
              .where('month', isEqualTo: month)
              .where('year', isEqualTo: year)
              .limit(1)
              .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get total paid by user in group
  Future<double> getUserTotalInGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      final snapshot =
          await _payments
              .where('groupId', isEqualTo: groupId)
              .where('userId', isEqualTo: userId)
              .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['amount'] ?? 0.0).toDouble();
      }

      return total;
    } catch (e) {
      return 0.0;
    }
  }

  // Get group total collected
  Future<double> getGroupTotalCollected(String groupId) async {
    try {
      final snapshot =
          await _payments.where('groupId', isEqualTo: groupId).get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['amount'] ?? 0.0).toDouble();
      }

      return total;
    } catch (e) {
      return 0.0;
    }
  }

  // Delete payment
  Future<void> deletePayment(String paymentId) async {
    try {
      await _payments.doc(paymentId).delete();
    } catch (e) {
      throw Exception('Failed to delete payment: $e');
    }
  }

  // Get payment statistics for group
  Future<Map<String, dynamic>> getGroupPaymentStats(String groupId) async {
    try {
      final snapshot =
          await _payments.where('groupId', isEqualTo: groupId).get();

      double totalCollected = 0.0;
      int totalPayments = snapshot.docs.length;
      Map<String, int> monthlyPayments = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalCollected += (data['amount'] ?? 0.0).toDouble();

        final month = data['month'] ?? 0;
        final year = data['year'] ?? 0;
        final key = '$year-${month.toString().padLeft(2, '0')}';
        monthlyPayments[key] = (monthlyPayments[key] ?? 0) + 1;
      }

      return {
        'totalCollected': totalCollected,
        'totalPayments': totalPayments,
        'monthlyPayments': monthlyPayments,
      };
    } catch (e) {
      return {'totalCollected': 0.0, 'totalPayments': 0, 'monthlyPayments': {}};
    }
  }
}

// Provider for payment service
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});

// Stream provider for group payments
final groupPaymentsStreamProvider =
    StreamProvider.family<List<PaymentModel>, String>((ref, groupId) {
      final paymentService = ref.watch(paymentServiceProvider);
      return paymentService.getGroupPaymentsStream(groupId);
    });

// Stream provider for user payments in group
final userPaymentsInGroupStreamProvider = StreamProvider.family<
  List<PaymentModel>,
  ({String groupId, String userId})
>((ref, params) {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getUserPaymentsInGroupStream(
    groupId: params.groupId,
    userId: params.userId,
  );
});

// Stream provider for month payments
final monthPaymentsStreamProvider = StreamProvider.family<
  List<PaymentModel>,
  ({String groupId, int month, int year})
>((ref, params) {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getMonthPaymentsStream(
    groupId: params.groupId,
    month: params.month,
    year: params.year,
  );
});
