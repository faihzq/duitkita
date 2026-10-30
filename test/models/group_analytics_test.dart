import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/models/group_analytics.dart';

void main() {
  group('GroupAnalytics.empty', () {
    test('all numeric fields are zero', () {
      final analytics = GroupAnalytics.empty();

      expect(analytics.totalCollected, 0.0);
      expect(analytics.averagePaymentAmount, 0.0);
      expect(analytics.totalPayments, 0);
      expect(analytics.expectedTotal, 0.0);
      expect(analytics.collectionRate, 0.0);
      expect(analytics.activeMembers, 0);
      expect(analytics.totalExpenses, 0.0);
      expect(analytics.totalExpenseCount, 0);
      expect(analytics.netBalance, 0.0);
    });

    test('all map fields are empty', () {
      final analytics = GroupAnalytics.empty();

      expect(analytics.memberContributions, isEmpty);
      expect(analytics.memberPaymentCounts, isEmpty);
      expect(analytics.monthlyCollections, isEmpty);
    });

    test('topContributor is empty string', () {
      final analytics = GroupAnalytics.empty();
      expect(analytics.topContributor, '');
      expect(analytics.topContributorAmount, 0.0);
    });
  });

  group('GroupAnalytics constructor', () {
    test('stores all provided values', () {
      final analytics = GroupAnalytics(
        totalCollected: 1200.0,
        averagePaymentAmount: 200.0,
        totalPayments: 6,
        expectedTotal: 1400.0,
        collectionRate: 0.857,
        memberContributions: {'Alice': 400.0, 'Bob': 800.0},
        memberPaymentCounts: {'Alice': 2, 'Bob': 4},
        monthlyCollections: {'Jan-2025': 600.0, 'Feb-2025': 600.0},
        topContributor: 'Bob',
        topContributorAmount: 800.0,
        activeMembers: 2,
        totalExpenses: 150.0,
        totalExpenseCount: 3,
        netBalance: 1050.0,
        pendingExpenseCount: 1,
        approvedExpenseCount: 2,
      );

      expect(analytics.totalCollected, 1200.0);
      expect(analytics.collectionRate, closeTo(0.857, 0.001));
      expect(analytics.memberContributions['Bob'], 800.0);
      expect(analytics.topContributor, 'Bob');
      expect(analytics.netBalance, 1050.0);
      expect(analytics.pendingExpenseCount, 1);
      expect(analytics.approvedExpenseCount, 2);
    });

    test('optional fields default correctly', () {
      final analytics = GroupAnalytics(
        totalCollected: 0,
        averagePaymentAmount: 0,
        totalPayments: 0,
        expectedTotal: 0,
        collectionRate: 0,
        memberContributions: {},
        memberPaymentCounts: {},
        monthlyCollections: {},
        topContributor: '',
        topContributorAmount: 0,
        activeMembers: 0,
        totalExpenses: 0,
        totalExpenseCount: 0,
        netBalance: 0,
      );

      expect(analytics.pendingExpenseCount, 0);
      expect(analytics.approvedExpenseCount, 0);
      expect(analytics.rejectedExpenseCount, 0);
      expect(analytics.pendingExpenseAmount, 0.0);
      expect(analytics.expenseByRequester, isEmpty);
      expect(analytics.monthlyExpenses, isEmpty);
      expect(analytics.recentExpenses, isEmpty);
      expect(analytics.yearlyCollections, isEmpty);
      expect(analytics.yearlyExpenses, isEmpty);
    });
  });

  group('ExpenseItem', () {
    test('stores all fields', () {
      final item = ExpenseItem(
        title: 'Team lunch',
        amount: 80.0,
        requestedByName: 'Alice',
        status: 'approved',
        date: DateTime(2025, 3, 10),
      );

      expect(item.title, 'Team lunch');
      expect(item.amount, 80.0);
      expect(item.requestedByName, 'Alice');
      expect(item.status, 'approved');
    });
  });

  group('MonthlyStats', () {
    test('stores all fields', () {
      final stats = MonthlyStats(
        monthYear: 'Mar-2025',
        totalAmount: 600.0,
        paymentCount: 3,
        paidMembers: 3,
        totalMembers: 4,
      );

      expect(stats.monthYear, 'Mar-2025');
      expect(stats.totalAmount, 600.0);
      expect(stats.paymentCount, 3);
      expect(stats.paidMembers, 3);
      expect(stats.totalMembers, 4);
    });
  });
}
