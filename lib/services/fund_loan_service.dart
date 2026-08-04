import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/fund_loan_model.dart';

class FundLoanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _loans => _firestore.collection('fund_loans');

  // Create a loan drawn from the group fund. When [autoApprove] is true
  // (admin creating directly) it becomes active immediately; otherwise it is
  // submitted as a pending request for an admin to approve.
  Future<String> createFundLoan({
    required String groupId,
    required String borrowerId,
    required String borrowerName,
    required String title,
    String? note,
    required double principal,
    double monthlyRepayment = 0.0,
    required String createdBy,
    required String createdByName,
    bool autoApprove = false,
    String? approverName,
  }) async {
    if (title.trim().isEmpty) {
      throw Exception('Purpose cannot be empty');
    }
    if (principal <= 0) {
      throw Exception('Amount must be greater than zero');
    }
    try {
      final now = DateTime.now();
      final loan = FundLoanModel(
        id: '',
        groupId: groupId,
        borrowerId: borrowerId,
        borrowerName: borrowerName,
        title: title.trim(),
        note: (note == null || note.trim().isEmpty) ? null : note.trim(),
        principal: principal,
        monthlyRepayment: monthlyRepayment,
        repayments: const [],
        status: autoApprove ? 'approved' : 'pending',
        createdBy: createdBy,
        createdByName: createdByName,
        approvedByName: autoApprove ? (approverName ?? createdByName) : null,
        approvedAt: autoApprove ? now : null,
        createdAt: now,
        updatedAt: now,
      );
      final doc = await _loans.add(loan.toMap());
      return doc.id;
    } catch (e) {
      throw Exception('Failed to create fund loan: $e');
    }
  }

  // Approve a pending loan request (admin only).
  Future<void> approveFundLoan({
    required String loanId,
    required String approvedByName,
  }) async {
    try {
      await _loans.doc(loanId).update({
        'status': 'approved',
        'approvedByName': approvedByName,
        'approvedAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to approve fund loan: $e');
    }
  }

  // Reject a pending loan request (admin only).
  Future<void> rejectFundLoan({required String loanId}) async {
    try {
      await _loans.doc(loanId).update({
        'status': 'rejected',
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to reject fund loan: $e');
    }
  }

  // Record a repayment. Runs in a transaction so concurrent repayments don't
  // clobber each other's appended entry, and auto-settles when fully repaid.
  Future<void> recordRepayment({
    required String loanId,
    required double amount,
    String? note,
    required String recordedBy,
  }) async {
    if (amount <= 0) {
      throw Exception('Repayment must be greater than zero');
    }
    final ref = _loans.doc(loanId);
    try {
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) throw Exception('Loan not found');
        final loan = FundLoanModel.fromMap(
          snap.data() as Map<String, dynamic>,
          snap.id,
        );
        final entry = FundLoanRepayment(
          amount: amount,
          date: DateTime.now(),
          note: (note == null || note.trim().isEmpty) ? null : note.trim(),
          recordedBy: recordedBy,
        );
        final updated = [...loan.repayments, entry];
        final repaid = updated.fold<double>(0.0, (s, r) => s + r.amount);
        txn.update(ref, {
          'repayments': updated.map((r) => r.toMap()).toList(),
          'status': repaid >= loan.principal - 0.0001 ? 'settled' : 'active',
          'updatedAt': DateTime.now(),
        });
      });
    } catch (e) {
      throw Exception('Failed to record repayment: $e');
    }
  }

  Future<void> deleteFundLoan(String loanId) async {
    try {
      await _loans.doc(loanId).delete();
    } catch (e) {
      throw Exception('Failed to delete fund loan: $e');
    }
  }

  Stream<List<FundLoanModel>> getGroupLoansStream(String groupId) {
    // No orderBy here (avoids needing a composite Firestore index); sorted below.
    return _loans.where('groupId', isEqualTo: groupId).snapshots().map((snap) {
      final loans =
          snap.docs
              .map(
                (doc) => FundLoanModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
      loans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return loans;
    });
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

final fundLoanServiceProvider = Provider<FundLoanService>((ref) {
  return FundLoanService();
});

final groupFundLoansStreamProvider =
    StreamProvider.family<List<FundLoanModel>, String>((ref, groupId) {
      return ref.watch(fundLoanServiceProvider).getGroupLoansStream(groupId);
    });

// Total outstanding (unpaid) across a group's approved fund loans.
final groupOutstandingLoansProvider = StreamProvider.family<double, String>((
  ref,
  groupId,
) {
  return ref
      .watch(fundLoanServiceProvider)
      .getGroupLoansStream(groupId)
      .map(
        (loans) => loans
            .where((l) => l.affectsBalance)
            .fold<double>(0.0, (s, l) => s + l.outstanding),
      );
});

// Count of pending loan requests for a group (admin review badge).
final pendingFundLoansCountProvider = StreamProvider.family<int, String>((
  ref,
  groupId,
) {
  return ref
      .watch(fundLoanServiceProvider)
      .getGroupLoansStream(groupId)
      .map((loans) => loans.where((l) => l.isPending).length);
});
