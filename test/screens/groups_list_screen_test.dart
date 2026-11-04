import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/groups/groups_list_screen.dart';
import 'package:duitkita/models/group_model.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/payment_service.dart';

import '../helpers/fake_auth.dart';

GroupModel group(String id, String name, {bool settled = false}) => GroupModel(
  id: id,
  name: name,
  description: '',
  createdBy: 'someone',
  monthlyAmount: 200,
  isSettled: settled,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  memberIds: const ['uid-1', 'someone'],
  memberCount: 2,
);

void main() {
  Future<void> pump(WidgetTester tester, String uid) async {
    tester.view.physicalSize = const Size(560 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testApp(
        const GroupsListScreen(),
        controller: fakeAuthController(signedInUid: uid),
        extraOverrides: [
          userGroupsStreamProvider.overrideWith(
            (ref, _) => Stream.value([
              group('open', 'Saving B'),
              group('done', 'Langkawi', settled: true),
            ]),
          ),
          adminGroupIdsStreamProvider.overrideWith(
            (ref, _) => Stream.value(<String>{}),
          ),
          groupMonthPaymentStatusProvider.overrideWith(
            (ref, _) => Stream.value('unpaid'),
          ),
          groupMonthPaidCountProvider.overrideWith((ref, _) => Stream.value(0)),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a settled group shows its goal, not "Not paid"', (tester) async {
    await pump(tester, 'uid-1');

    expect(find.text('Goal reached'), findsOneWidget);
    // The chip plus the one open group; Langkawi adds no third.
    expect(find.text('Not paid'), findsNWidgets(2));
    expect(find.text('0/2 paid'), findsOneWidget);
  });

  testWidgets('the Not paid filter leaves settled groups out', (tester) async {
    await pump(tester, 'uid-1');

    await tester.tap(find.text('Not paid').first);
    await tester.pumpAndSettle();

    expect(find.text('Saving B'), findsOneWidget);
    expect(find.text('Langkawi'), findsNothing);
  });

  testWidgets('the Paid filter includes settled groups', (tester) async {
    await pump(tester, 'uid-1');

    await tester.tap(find.text('Paid'));
    await tester.pumpAndSettle();

    expect(find.text('Langkawi'), findsOneWidget);
    expect(find.text('Saving B'), findsNothing);
  });
}
