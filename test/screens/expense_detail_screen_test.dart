import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duitkita/models/expense_model.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/models/group_model.dart';
import 'package:duitkita/screens/expense_detail_screen.dart';
import 'package:duitkita/services/expense_service.dart';
import 'package:duitkita/services/group_service.dart';

import '../helpers/fake_auth.dart';

void main() {
  const groupId = 'group-1';
  const requesterUid = 'uid-requester';
  const adminUid = 'uid-admin';

  ExpenseModel expense({
    ExpenseStatus status = ExpenseStatus.pending,
    String? receiptUrl,
  }) => ExpenseModel(
    id: 'expense-1',
    groupId: groupId,
    requestedBy: requesterUid,
    requestedByName: 'Aina',
    title: 'Buka puasa catering',
    amount: 240,
    status: status,
    receiptUrl: receiptUrl,
    createdAt: DateTime(2026, 8, 1),
  );

  GroupMember member(String uid, String name, {required bool isAdmin}) =>
      GroupMember(
        userId: uid,
        userName: name,
        isAdmin: isAdmin,
        joinedAt: DateTime(2026, 1, 1),
        totalPaid: 0,
        paymentCount: 0,
      );

  final members = [
    member(requesterUid, 'Aina', isAdmin: false),
    member(adminUid, 'Zaki', isAdmin: true),
  ];

  final theGroup = GroupModel(
    id: groupId,
    name: 'Family Savings',
    description: 'Monthly kitty',
    createdBy: adminUid,
    monthlyAmount: 100,
    memberIds: const [requesterUid, adminUid],
    memberCount: 2,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  /// Renders the screen as [viewerUid] is seeing it.
  Future<void> pump(
    WidgetTester tester, {
    required String viewerUid,
    ExpenseModel? forExpense,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final e = forExpense ?? expense();

    await tester.pumpWidget(
      testApp(
        ExpenseDetailScreen(expense: e, groupId: groupId),
        controller: fakeAuthController(signedInUid: viewerUid),
        extraOverrides: [
          groupMembersStreamProvider(
            groupId,
          ).overrideWith((ref) => Stream.value(members)),
          groupStreamProvider(
            groupId,
          ).overrideWith((ref) => Stream.value(theGroup)),
          groupExpensesStreamProvider(
            groupId,
          ).overrideWith((ref) => Stream.value([e])),
        ],
      ),
    );
    // Not pumpAndSettle: a pending expense shows a _PulsingDot that repeats
    // forever, so settling never returns.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  final deleteButton = find.text('Delete request');

  group('ExpenseDetailScreen — delete request', () {
    // Before this existed, submitting an expense was one-way: the requester
    // had no way to withdraw it short of deleting their whole account.
    testWidgets('the requester can delete their own pending request', (
      tester,
    ) async {
      await pump(tester, viewerUid: requesterUid);
      expect(deleteButton, findsOneWidget);
    });

    testWidgets('other members do not see it', (tester) async {
      await pump(tester, viewerUid: adminUid);
      expect(deleteButton, findsNothing);
    });

    // An approved expense is part of the group's accounting. Letting one member
    // erase it would leave the balance wrong for everyone else.
    testWidgets('it disappears once the expense is approved', (tester) async {
      await pump(
        tester,
        viewerUid: requesterUid,
        forExpense: expense(status: ExpenseStatus.approved),
      );
      expect(deleteButton, findsNothing);
    });

    testWidgets('a rejected request keeps its record too', (tester) async {
      await pump(
        tester,
        viewerUid: requesterUid,
        forExpense: expense(status: ExpenseStatus.rejected),
      );
      expect(deleteButton, findsNothing);
    });

    testWidgets('confirming is required, and names the receipt', (
      tester,
    ) async {
      await pump(
        tester,
        viewerUid: requesterUid,
        forExpense: expense(receiptUrl: 'https://example.com/receipt.jpg'),
      );

      await tester.ensureVisible(deleteButton);
      await tester.tap(deleteButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Delete this request?'), findsOneWidget);
      expect(
        find.textContaining('along with the receipt you uploaded'),
        findsOneWidget,
      );
      expect(find.text('Keep it'), findsOneWidget);
    });

    testWidgets('no receipt, no mention of one', (tester) async {
      await pump(tester, viewerUid: requesterUid);

      await tester.ensureVisible(deleteButton);
      await tester.tap(deleteButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Delete this request?'), findsOneWidget);
      expect(
        find.textContaining('along with the receipt you uploaded'),
        findsNothing,
      );
    });
  });
}
