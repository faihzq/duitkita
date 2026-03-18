import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/group_analytics.dart';
import 'package:duitkita/models/payment_model.dart';
import 'package:duitkita/models/group_model.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/expense_service.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get comprehensive group analytics
  Future<GroupAnalytics> getGroupAnalytics({
    required String groupId,
    required GroupModel group,
    required List<GroupMember> members,
  }) async {
    try {
      // Get all payments for this group
      final paymentsSnapshot =
          await _firestore
              .collection('payments')
              .where('groupId', isEqualTo: groupId)
              .get();

      final allPayments =
          paymentsSnapshot.docs
              .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
              .toList();

      // Only count confirmed payments for analytics
      final payments = allPayments
          .where((p) => p.paymentStatus == 'confirmed')
          .toList();

      if (allPayments.isEmpty) {
        return GroupAnalytics.empty();
      }

      // Calculate total collected (confirmed only)
      final totalCollected = payments.fold<double>(
        0.0,
        (sum, payment) => sum + payment.amount,
      );

      // Calculate average payment amount
      final averagePaymentAmount = payments.isNotEmpty
          ? totalCollected / payments.length
          : 0.0;

      // Calculate member contributions (confirmed only)
      final Map<String, double> memberContributions = {};
      final Map<String, int> memberPaymentCounts = {};

      for (var payment in payments) {
        memberContributions[payment.userId] =
            (memberContributions[payment.userId] ?? 0.0) + payment.amount;
        memberPaymentCounts[payment.userId] =
            (memberPaymentCounts[payment.userId] ?? 0) + 1;
      }

      // Find top contributor
      String topContributor = '';
      double topContributorAmount = 0.0;

      memberContributions.forEach((userId, amount) {
        if (amount > topContributorAmount) {
          topContributorAmount = amount;
          topContributor = userId;
        }
      });

      // Get top contributor name
      final topContributorMember = members.firstWhere(
        (m) => m.userId == topContributor,
        orElse:
            () => GroupMember(
              userId: '',
              userName: 'Unknown',
              isAdmin: false,
              joinedAt: DateTime.now(),
              totalPaid: 0.0,
              paymentCount: 0,
            ),
      );

      // Calculate monthly collections (confirmed only)
      final Map<String, double> monthlyCollections = {};
      for (var payment in payments) {
        final monthYear =
            '${payment.year}-${payment.month.toString().padLeft(2, '0')}';
        monthlyCollections[monthYear] =
            (monthlyCollections[monthYear] ?? 0.0) + payment.amount;
      }

      // Calculate expected total based on each member's join date
      final now = DateTime.now();
      double expectedTotal = 0.0;
      for (final member in members) {
        // Months from member's join date to now (inclusive of both months)
        final memberMonths = _calculateMonthsDifference(member.joinedAt, now) + 1;
        expectedTotal += memberMonths * group.monthlyAmount;
      }

      // Calculate collection rate
      final collectionRate =
          expectedTotal > 0 ? (totalCollected / expectedTotal) * 100 : 0.0;

      // Count active members (members who have made at least one confirmed payment)
      final activeMembers = memberContributions.length;

      // Calculate all expenses (all statuses for breakdown)
      final allExpensesSnapshot =
          await _firestore
              .collection('expenses')
              .where('groupId', isEqualTo: groupId)
              .get();

      final allExpenseDocs = allExpensesSnapshot.docs;

      // Status counts
      int pendingExpenseCount = 0;
      int approvedExpenseCount = 0;
      int rejectedExpenseCount = 0;
      double pendingExpenseAmount = 0.0;
      double totalExpenses = 0.0;
      final Map<String, double> expenseByRequester = {};
      final Map<String, double> monthlyExpenses = {};
      final List<ExpenseItem> recentExpenses = [];

      for (final doc in allExpenseDocs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'pending';
        final amount = ((data['amount'] ?? 0.0) as num).toDouble();
        final requesterName = data['requestedByName'] as String? ?? 'Unknown';
        final title = data['title'] as String? ?? '';
        final createdAt = data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now();

        if (status == 'pending') {
          pendingExpenseCount++;
          pendingExpenseAmount += amount;
        } else if (status == 'approved') {
          approvedExpenseCount++;
          totalExpenses += amount;

          // Track by requester (approved only)
          expenseByRequester[requesterName] =
              (expenseByRequester[requesterName] ?? 0.0) + amount;

          // Track monthly expenses (approved only)
          final monthYear =
              '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
          monthlyExpenses[monthYear] =
              (monthlyExpenses[monthYear] ?? 0.0) + amount;

          // Collect for recent list
          recentExpenses.add(ExpenseItem(
            title: title,
            amount: amount,
            requestedByName: requesterName,
            status: status,
            date: createdAt,
          ));
        } else if (status == 'rejected') {
          rejectedExpenseCount++;
        }
      }

      // Sort recent expenses by date descending, take top 5
      recentExpenses.sort((a, b) => b.date.compareTo(a.date));
      final recentExpensesList = recentExpenses.take(5).toList();

      final totalExpenseCount = allExpenseDocs.length;
      final netBalance = totalCollected - totalExpenses;

      // Aggregate yearly collections from monthly data
      final Map<int, double> yearlyCollections = {};
      for (final entry in monthlyCollections.entries) {
        final year = int.parse(entry.key.split('-')[0]);
        yearlyCollections[year] = (yearlyCollections[year] ?? 0.0) + entry.value;
      }

      // Aggregate yearly expenses from monthly data
      final Map<int, double> yearlyExpenses = {};
      for (final entry in monthlyExpenses.entries) {
        final year = int.parse(entry.key.split('-')[0]);
        yearlyExpenses[year] = (yearlyExpenses[year] ?? 0.0) + entry.value;
      }

      return GroupAnalytics(
        totalCollected: totalCollected,
        averagePaymentAmount: averagePaymentAmount,
        totalPayments: payments.length,
        expectedTotal: expectedTotal,
        collectionRate: collectionRate,
        memberContributions: memberContributions,
        memberPaymentCounts: memberPaymentCounts,
        monthlyCollections: monthlyCollections,
        topContributor: topContributorMember.userName,
        topContributorAmount: topContributorAmount,
        activeMembers: activeMembers,
        totalExpenses: totalExpenses,
        totalExpenseCount: totalExpenseCount,
        netBalance: netBalance,
        pendingExpenseCount: pendingExpenseCount,
        approvedExpenseCount: approvedExpenseCount,
        rejectedExpenseCount: rejectedExpenseCount,
        pendingExpenseAmount: pendingExpenseAmount,
        expenseByRequester: expenseByRequester,
        monthlyExpenses: monthlyExpenses,
        recentExpenses: recentExpensesList,
        yearlyCollections: yearlyCollections,
        yearlyExpenses: yearlyExpenses,
      );
    } catch (e) {
      throw Exception('Failed to generate analytics: $e');
    }
  }

  // Get monthly statistics for chart
  Future<List<MonthlyStats>> getMonthlyStats({
    required String groupId,
    int? limitMonths,
  }) async {
    try {
      final paymentsSnapshot =
          await _firestore
              .collection('payments')
              .where('groupId', isEqualTo: groupId)
              .orderBy('paymentDate', descending: true)
              .get();

      final payments =
          paymentsSnapshot.docs
              .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
              .where((p) => p.paymentStatus == 'confirmed')
              .toList();

      // Group payments by month
      final Map<String, List<PaymentModel>> paymentsByMonth = {};
      for (var payment in payments) {
        final monthYear =
            '${payment.year}-${payment.month.toString().padLeft(2, '0')}';
        if (!paymentsByMonth.containsKey(monthYear)) {
          paymentsByMonth[monthYear] = [];
        }
        paymentsByMonth[monthYear]!.add(payment);
      }

      // Create monthly stats
      final List<MonthlyStats> monthlyStats = [];
      final sortedMonths = paymentsByMonth.keys.toList()..sort();

      // Limit to recent months if specified
      final monthsToShow =
          limitMonths != null && sortedMonths.length > limitMonths
              ? sortedMonths.sublist(sortedMonths.length - limitMonths)
              : sortedMonths;

      for (var monthYear in monthsToShow) {
        final monthPayments = paymentsByMonth[monthYear]!;
        final totalAmount = monthPayments.fold<double>(
          0.0,
          (sum, payment) => sum + payment.amount,
        );
        final uniqueUsers = monthPayments.map((p) => p.userId).toSet();

        monthlyStats.add(
          MonthlyStats(
            monthYear: monthYear,
            totalAmount: totalAmount,
            paymentCount: monthPayments.length,
            paidMembers: uniqueUsers.length,
            totalMembers:
                0, // This would need to be calculated based on group members at that time
          ),
        );
      }

      return monthlyStats;
    } catch (e) {
      throw Exception('Failed to get monthly stats: $e');
    }
  }

  // Helper function to calculate months difference
  int _calculateMonthsDifference(DateTime start, DateTime end) {
    return (end.year - start.year) * 12 + end.month - start.month;
  }

}

// Provider for analytics service
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

// Future provider for group analytics
final groupAnalyticsProvider = FutureProvider.family<GroupAnalytics, String>((
  ref,
  groupId,
) async {
  final analyticsService = ref.watch(analyticsServiceProvider);

  // Watch expenses stream to auto-refresh when expenses change
  ref.watch(groupExpensesStreamProvider(groupId));

  // Get group and members data
  final group = await ref.watch(groupStreamProvider(groupId).future);
  final members = await ref.watch(groupMembersStreamProvider(groupId).future);

  if (group == null) {
    return GroupAnalytics.empty();
  }

  return analyticsService.getGroupAnalytics(
    groupId: groupId,
    group: group,
    members: members,
  );
});
