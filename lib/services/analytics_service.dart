import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/group_analytics.dart';
import 'package:duitkita/models/payment_model.dart';
import 'package:duitkita/models/group_model.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/services/group_service.dart';

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

      final payments =
          paymentsSnapshot.docs
              .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
              .toList();

      if (payments.isEmpty) {
        return GroupAnalytics.empty();
      }

      // Calculate total collected
      final totalCollected = payments.fold<double>(
        0.0,
        (sum, payment) => sum + payment.amount,
      );

      // Calculate average payment amount
      final averagePaymentAmount = totalCollected / payments.length;

      // Calculate member contributions
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

      // Calculate monthly collections
      final Map<String, double> monthlyCollections = {};
      for (var payment in payments) {
        final monthYear =
            '${payment.year}-${payment.month.toString().padLeft(2, '0')}';
        monthlyCollections[monthYear] =
            (monthlyCollections[monthYear] ?? 0.0) + payment.amount;
      }

      // Calculate expected total based on group age and member count
      final now = DateTime.now();
      final monthsSinceCreation = _calculateMonthsDifference(
        group.createdAt,
        now,
      );
      final expectedTotal =
          monthsSinceCreation * group.monthlyAmount * members.length;

      // Calculate collection rate
      final collectionRate =
          expectedTotal > 0 ? (totalCollected / expectedTotal) * 100 : 0.0;

      // Count active members (members who have made at least one payment)
      final activeMembers = memberContributions.length;

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

  // Get payment trends (last 6 months)
  Future<Map<String, double>> getPaymentTrends(String groupId) async {
    try {
      final monthlyStats = await getMonthlyStats(
        groupId: groupId,
        limitMonths: 6,
      );
      final Map<String, double> trends = {};

      for (var stat in monthlyStats) {
        trends[stat.monthYear] = stat.totalAmount;
      }

      return trends;
    } catch (e) {
      throw Exception('Failed to get payment trends: $e');
    }
  }

  // Helper function to calculate months difference
  int _calculateMonthsDifference(DateTime start, DateTime end) {
    return (end.year - start.year) * 12 + end.month - start.month;
  }

  // Get member contribution percentages
  Map<String, double> getMemberContributionPercentages(
    Map<String, double> memberContributions,
    double totalCollected,
  ) {
    final Map<String, double> percentages = {};

    if (totalCollected == 0) return percentages;

    memberContributions.forEach((userId, amount) {
      percentages[userId] = (amount / totalCollected) * 100;
    });

    return percentages;
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

  // Get group and members data
  final groupStream = ref.read(groupStreamProvider(groupId).future);
  final membersStream = ref.read(groupMembersStreamProvider(groupId).future);
  final group = await groupStream;
  final members = await membersStream;

  if (group == null) {
    return GroupAnalytics.empty();
  }

  return analyticsService.getGroupAnalytics(
    groupId: groupId,
    group: group,
    members: members,
  );
});
