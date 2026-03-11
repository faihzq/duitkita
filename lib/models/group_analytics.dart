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
  final double totalExpenses;
  final int totalExpenseCount;
  final double netBalance; // totalCollected - totalExpenses

  // Detailed expense tracking
  final int pendingExpenseCount;
  final int approvedExpenseCount;
  final int rejectedExpenseCount;
  final double pendingExpenseAmount;
  final Map<String, double> expenseByRequester; // userName -> amount
  final Map<String, double> monthlyExpenses; // month-year: amount
  final List<ExpenseItem> recentExpenses; // last 5 approved expenses

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
    required this.totalExpenses,
    required this.totalExpenseCount,
    required this.netBalance,
    this.pendingExpenseCount = 0,
    this.approvedExpenseCount = 0,
    this.rejectedExpenseCount = 0,
    this.pendingExpenseAmount = 0.0,
    this.expenseByRequester = const {},
    this.monthlyExpenses = const {},
    this.recentExpenses = const [],
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
      totalExpenses: 0.0,
      totalExpenseCount: 0,
      netBalance: 0.0,
    );
  }
}

class ExpenseItem {
  final String title;
  final double amount;
  final String requestedByName;
  final String status;
  final DateTime date;

  ExpenseItem({
    required this.title,
    required this.amount,
    required this.requestedByName,
    required this.status,
    required this.date,
  });
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
