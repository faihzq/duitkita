class GroupAnalytics {
  final double totalCollected;
  final double averagePaymentAmount;
  final int totalPayments;
  final double expectedTotal;
  final double collectionRate;
  final Map<String, double> memberContributions;
  final Map<String, int> memberPaymentCounts;
  final Map<String, double> monthlyCollections; // month-year: amount
  final String topContributor;
  final double topContributorAmount;
  final int activeMembers; // members who have made at least one payment

  GroupAnalytics({
    required this.totalCollected,
    required this.averagePaymentAmount,
    required this.totalPayments,
    required this.expectedTotal,
    required this.collectionRate,
    required this.memberContributions,
    required this.memberPaymentCounts,
    required this.monthlyCollections,
    required this.topContributor,
    required this.topContributorAmount,
    required this.activeMembers,
  });

  factory GroupAnalytics.empty() {
    return GroupAnalytics(
      totalCollected: 0.0,
      averagePaymentAmount: 0.0,
      totalPayments: 0,
      expectedTotal: 0.0,
      collectionRate: 0.0,
      memberContributions: {},
      memberPaymentCounts: {},
      monthlyCollections: {},
      topContributor: '',
      topContributorAmount: 0.0,
      activeMembers: 0,
    );
  }
}

class MonthlyStats {
  final String monthYear;
  final double totalAmount;
  final int paymentCount;
  final int paidMembers;
  final int totalMembers;

  MonthlyStats({
    required this.monthYear,
    required this.totalAmount,
    required this.paymentCount,
    required this.paidMembers,
    required this.totalMembers,
  });
}
