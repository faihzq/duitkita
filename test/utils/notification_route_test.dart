import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/core/notification_route.dart';

void main() {
  test('group notifications open the group', () {
    for (final type in [
      'member_added',
      'payment_received',
      'payment_verified',
      'payment_reminder',
      'expense_submitted',
      'fund_loan_requested',
      'fund_loan_decision',
    ]) {
      final route = notificationRoute({'type': type, 'groupId': 'g1'});
      expect(route, isA<GroupRoute>(), reason: type);
      expect((route as GroupRoute).groupId, 'g1');
    }
  });

  test('a bill reminder opens the debt', () {
    final route = notificationRoute({
      'type': 'debt_bill_reminder',
      'debtId': 'd1',
    });
    expect((route as DebtRoute).debtId, 'd1');
  });

  test('a match reminder opens the team', () {
    final route = notificationRoute({'type': 'jdt_match', 'teamId': '140138'});
    expect((route as MatchRoute).teamId, '140138');
  });

  test('removal, unknown types and missing ids stay on Home', () {
    expect(
      notificationRoute({'type': 'member_removed', 'groupId': 'g1'}),
      isNull,
    );
    expect(notificationRoute({'type': 'something_new'}), isNull);
    // Older fund-loan decisions carried no group id.
    expect(
      notificationRoute({'type': 'fund_loan_decision', 'loanId': 'l1'}),
      isNull,
    );
    expect(notificationRoute(const {}), isNull);
  });
}
