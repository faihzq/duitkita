import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/expense_model.dart';

class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _expenses => _firestore.collection('expenses');

  // Submit expense request
  Future<void> submitExpense({
    required String groupId,
    required String requestedBy,
    required String requestedByName,
    required String title,
    String? description,
    required double amount,
    String? receiptUrl,
    bool autoApprove = false,
    String? approvedByName,
  }) async {
    try {
      final now = DateTime.now();
      final expenseData = {
        'groupId': groupId,
        'requestedBy': requestedBy,
        'requestedByName': requestedByName,
        'title': title,
        'description': description,
        'amount': amount,
        'status': autoApprove ? ExpenseStatus.approved.name : ExpenseStatus.pending.name,
        'receiptUrl': receiptUrl,
        'approvedBy': autoApprove ? requestedBy : null,
        'approvedByName': autoApprove ? (approvedByName ?? requestedByName) : null,
        'approvedAt': autoApprove ? now : null,
        'rejectedBy': null,
        'rejectedByName': null,
        'rejectedAt': null,
        'createdAt': now,
      };

      await _expenses.add(expenseData);
    } catch (e) {
      throw Exception('Failed to submit expense: $e');
    }
  }

  // Approve expense (admin only)
  Future<void> approveExpense({
    required String expenseId,
    required String approvedBy,
    required String approvedByName,
  }) async {
    try {
      await _expenses.doc(expenseId).update({
        'status': ExpenseStatus.approved.name,
        'approvedBy': approvedBy,
        'approvedByName': approvedByName,
        'approvedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to approve expense: $e');
    }
  }

  // Reject expense (admin only)
  Future<void> rejectExpense({
    required String expenseId,
    required String rejectedBy,
    required String rejectedByName,
  }) async {
    try {
      await _expenses.doc(expenseId).update({
        'status': ExpenseStatus.rejected.name,
        'rejectedBy': rejectedBy,
        'rejectedByName': rejectedByName,
        'rejectedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to reject expense: $e');
    }
  }

  // Get all expenses for a group
  Stream<List<ExpenseModel>> getGroupExpensesStream(String groupId) {
    return _expenses
        .where('groupId', isEqualTo: groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => ExpenseModel.fromMap(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    ),
                  )
                  .toList(),
        );
  }

  // Get pending expenses for a group
  Stream<List<ExpenseModel>> getPendingExpensesStream(String groupId) {
    return _expenses
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: ExpenseStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => ExpenseModel.fromMap(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    ),
                  )
                  .toList(),
        );
  }

  // Get pending expenses for multiple groups (admin review)
  Stream<List<ExpenseModel>> getPendingExpensesForGroupsStream(List<String> groupIds) {
    if (groupIds.isEmpty) return Stream.value([]);

    final limitedIds = groupIds.take(30).toList();
    return _expenses
        .where('groupId', whereIn: limitedIds)
        .where('status', isEqualTo: ExpenseStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Approve all pending expenses for a group
  Future<int> approveAllPendingExpenses({
    required String groupId,
    required String approvedBy,
    required String approvedByName,
  }) async {
    final snapshot = await _expenses
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: ExpenseStatus.pending.name)
        .get();

    if (snapshot.docs.isEmpty) return 0;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': ExpenseStatus.approved.name,
        'approvedBy': approvedBy,
        'approvedByName': approvedByName,
        'approvedAt': DateTime.now(),
      });
    }
    await batch.commit();
    return snapshot.docs.length;
  }

  // Batch approve selected expenses
  Future<int> batchApproveExpenses({
    required List<String> expenseIds,
    required String approvedBy,
    required String approvedByName,
  }) async {
    if (expenseIds.isEmpty) return 0;

    final batch = _firestore.batch();
    final now = DateTime.now();
    for (final id in expenseIds) {
      batch.update(_expenses.doc(id), {
        'status': ExpenseStatus.approved.name,
        'approvedBy': approvedBy,
        'approvedByName': approvedByName,
        'approvedAt': now,
      });
    }
    await batch.commit();
    return expenseIds.length;
  }

  // Batch reject selected expenses
  Future<int> batchRejectExpenses({
    required List<String> expenseIds,
    required String rejectedBy,
    required String rejectedByName,
  }) async {
    if (expenseIds.isEmpty) return 0;

    final batch = _firestore.batch();
    final now = DateTime.now();
    for (final id in expenseIds) {
      batch.update(_expenses.doc(id), {
        'status': ExpenseStatus.rejected.name,
        'rejectedBy': rejectedBy,
        'rejectedByName': rejectedByName,
        'rejectedAt': now,
      });
    }
    await batch.commit();
    return expenseIds.length;
  }

  // Delete expense
  Future<void> deleteExpense(String expenseId) async {
    try {
      await _expenses.doc(expenseId).delete();
    } catch (e) {
      throw Exception('Failed to delete expense: $e');
    }
  }
}

// Provider for expense service
final expenseServiceProvider = Provider<ExpenseService>((ref) {
  return ExpenseService();
});

// Stream provider for group expenses
final groupExpensesStreamProvider =
    StreamProvider.family<List<ExpenseModel>, String>((ref, groupId) {
      final expenseService = ref.watch(expenseServiceProvider);
      return expenseService.getGroupExpensesStream(groupId);
    });

// Stream provider for pending expenses (for badge count)
final pendingExpensesStreamProvider =
    StreamProvider.family<List<ExpenseModel>, String>((ref, groupId) {
      final expenseService = ref.watch(expenseServiceProvider);
      return expenseService.getPendingExpensesStream(groupId);
    });
