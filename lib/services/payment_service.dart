import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/payment_model.dart';

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
    String? receiptUrl,
    bool autoApprove = false,
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
        'receiptUrl': receiptUrl,
        'createdAt': DateTime.now(),
        'paymentMethod': 'cash',
        'paymentStatus': autoApprove ? 'confirmed' : 'pending',
      };

      await _payments.add(paymentData);
    } catch (e) {
      throw Exception('Failed to add payment: $e');
    }
  }

  // Add payment with payment method (DuitNow, online banking, etc.)
  Future<void> addPaymentWithMethod({
    required String groupId,
    required String userId,
    required String userName,
    required double amount,
    required DateTime paymentDate,
    String? notes,
    String? receiptUrl,
    required String paymentMethod,
    required String paymentStatus,
    String? recipientPhone,
    String? transactionReference,
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
        'receiptUrl': receiptUrl,
        'createdAt': DateTime.now(),
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'recipientPhone': recipientPhone,
        'transactionReference': transactionReference,
      };

      await _payments.add(paymentData);
    } catch (e) {
      throw Exception('Failed to add payment: $e');
    }
  }

  // Verify or reject payment (for admin)
  Future<void> verifyPayment({
    required String paymentId,
    required String status,
    required String verifiedBy,
    required String verifiedByName,
    String? rejectionReason,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'paymentStatus': status,
        'verifiedBy': verifiedBy,
        'verifiedByName': verifiedByName,
        'verifiedAt': DateTime.now(),
      };
      if (rejectionReason != null && rejectionReason.isNotEmpty) {
        updateData['rejectionReason'] = rejectionReason;
      }
      await _payments.doc(paymentId).update(updateData);
    } catch (e) {
      throw Exception('Failed to update payment status: $e');
    }
  }

  // Get payments for a specific user in a group for a month (with status)
  Future<List<PaymentModel>> getUserMonthPayments({
    required String groupId,
    required String userId,
    required int month,
    required int year,
  }) async {
    try {
      final snapshot = await _payments
          .where('groupId', isEqualTo: groupId)
          .where('userId', isEqualTo: userId)
          .where('month', isEqualTo: month)
          .where('year', isEqualTo: year)
          .get();

      return snapshot.docs
          .map((doc) => PaymentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting user month payments: $e');
      return [];
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
      debugPrint('Error checking user payment status: $e');
      return false;
    }
  }

  // Bulk import payments (for backfilling historical data)
  // Returns the number of payments actually added (skips duplicates)
  Future<int> addBulkPayments({
    required String groupId,
    required List<({String userId, String userName, int month, int year})> entries,
    required double amount,
    String? notes,
  }) async {
    int added = 0;
    final batches = <WriteBatch>[];
    var currentBatch = _firestore.batch();
    int opsInBatch = 0;

    // Track per-user stats to update after
    final userStats = <String, ({String userName, int count, double total})>{};

    for (final entry in entries) {
      // Skip if already paid
      final alreadyPaid = await hasUserPaidForMonth(
        groupId: groupId,
        userId: entry.userId,
        month: entry.month,
        year: entry.year,
      );
      if (alreadyPaid) continue;

      final paymentDate = DateTime(entry.year, entry.month, 15);
      final docRef = _payments.doc();
      currentBatch.set(docRef, {
        'groupId': groupId,
        'userId': entry.userId,
        'userName': entry.userName,
        'amount': amount,
        'paymentDate': paymentDate,
        'month': entry.month,
        'year': entry.year,
        'notes': notes ?? 'Bulk import',
        'receiptUrl': null,
        'createdAt': DateTime.now(),
        'paymentMethod': 'cash',
        'paymentStatus': 'confirmed',
        'bulkImport': true,
      });

      // Track stats
      final prev = userStats[entry.userId];
      userStats[entry.userId] = (
        userName: entry.userName,
        count: (prev?.count ?? 0) + 1,
        total: (prev?.total ?? 0) + amount,
      );

      added++;
      opsInBatch++;

      // Firestore batch limit is 500
      if (opsInBatch >= 450) {
        batches.add(currentBatch);
        currentBatch = _firestore.batch();
        opsInBatch = 0;
      }
    }

    if (opsInBatch > 0) {
      batches.add(currentBatch);
    }

    // Commit all batches
    for (final batch in batches) {
      await batch.commit();
    }

    // Update member stats
    for (final entry in userStats.entries) {
      final stats = entry.value;
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(entry.key)
          .update({
        'totalPaid': FieldValue.increment(stats.total),
        'paymentCount': FieldValue.increment(stats.count),
      });
    }

    return added;
  }

  // Delete payment
  Future<void> deletePayment(String paymentId) async {
    try {
      await _payments.doc(paymentId).delete();
    } catch (e) {
      throw Exception('Failed to delete payment: $e');
    }
  }

  // Confirm all pending payments for a group
  Future<int> confirmAllPendingPayments({
    required String groupId,
    required String verifiedBy,
    required String verifiedByName,
  }) async {
    final snapshot = await _payments
        .where('groupId', isEqualTo: groupId)
        .where('paymentStatus', isEqualTo: 'pending')
        .get();

    if (snapshot.docs.isEmpty) return 0;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'paymentStatus': 'confirmed',
        'verifiedBy': verifiedBy,
        'verifiedByName': verifiedByName,
        'verifiedAt': DateTime.now(),
      });
    }
    await batch.commit();
    return snapshot.docs.length;
  }

  // Batch verify selected payments
  Future<int> batchVerifyPayments({
    required List<String> paymentIds,
    required String status,
    required String verifiedBy,
    required String verifiedByName,
    String? rejectionReason,
  }) async {
    if (paymentIds.isEmpty) return 0;

    final batch = _firestore.batch();
    final now = DateTime.now();
    for (final id in paymentIds) {
      final updateData = <String, dynamic>{
        'paymentStatus': status,
        'verifiedBy': verifiedBy,
        'verifiedByName': verifiedByName,
        'verifiedAt': now,
      };
      if (rejectionReason != null && rejectionReason.isNotEmpty) {
        updateData['rejectionReason'] = rejectionReason;
      }
      batch.update(_payments.doc(id), updateData);
    }
    await batch.commit();
    return paymentIds.length;
  }

  // Get pending payments for a group
  Stream<List<PaymentModel>> getPendingPaymentsStream(String groupId) {
    return _payments
        .where('groupId', isEqualTo: groupId)
        .where('paymentStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
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

  // Delete payment and update member stats (for admin)
  Future<void> deletePaymentWithStats({
    required String paymentId,
    required String groupId,
    required String userId,
    required double amount,
  }) async {
    try {
      // Delete payment
      await _payments.doc(paymentId).delete();

      // Update member stats (reduce totalPaid and paymentCount)
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(userId)
          .update({
        'totalPaid': FieldValue.increment(-amount),
        'paymentCount': FieldValue.increment(-1),
      });
    } catch (e) {
      throw Exception('Failed to delete payment: $e');
    }
  }

  // Get pending payments for multiple groups (admin review)
  Stream<List<PaymentModel>> getPendingPaymentsForGroupsStream(List<String> groupIds) {
    if (groupIds.isEmpty) return Stream.value([]);

    // Firestore 'whereIn' supports max 30 values
    final limitedIds = groupIds.take(30).toList();
    return _payments
        .where('groupId', whereIn: limitedIds)
        .where('paymentStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
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

// Stream provider for pending payments
final pendingPaymentsStreamProvider =
    StreamProvider.family<List<PaymentModel>, String>((ref, groupId) {
      final paymentService = ref.watch(paymentServiceProvider);
      return paymentService.getPendingPaymentsStream(groupId);
    });

// Provider for current month payment status (returns 'confirmed', 'pending', 'rejected', or 'unpaid')
final groupMonthPaymentStatusProvider = FutureProvider.family<String, ({String groupId, String userId})>((ref, params) async {
  final paymentService = ref.read(paymentServiceProvider);
  final now = DateTime.now();
  final payments = await paymentService.getUserMonthPayments(
    groupId: params.groupId,
    userId: params.userId,
    month: now.month,
    year: now.year,
  );
  if (payments.isEmpty) return 'unpaid';
  return payments.first.paymentStatus;
});
