import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/makan/makan_home_card.dart';
import 'package:duitkita/models/makan_spot.dart';
import 'package:duitkita/services/makan_service.dart';

import '../helpers/fake_auth.dart';

MakanSpot spot(String id, String name, WeeklyHours hours) => MakanSpot(
  id: id,
  name: name,
  area: 'Bangi',
  menu: const ['Nasi Lemak'],
  hours: hours,
  addedBy: 'uid-1',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  Future<void> pump(WidgetTester tester, List<MakanSpot> spots) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testApp(
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: MakanHomeCard(userId: 'uid-1'),
          ),
        ),
        extraOverrides: [
          allMakanSpotsProvider('uid-1').overrideWithValue(AsyncData(spots)),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('invites the first spot when the list is empty', (tester) async {
    await pump(tester, const []);
    expect(find.text('Where to eat?'), findsOneWidget);
    expect(
      find.text('Save your go-to places with their hours and menu'),
      findsOneWidget,
    );
  });

  testWidgets('lists what is open and leaves out what is closed', (
    tester,
  ) async {
    final always = {
      for (var d = 1; d <= 7; d++) d: const [OpenSlot.allDay],
    };
    await pump(tester, [
      spot('a', 'Mamak Bistro', always),
      spot('b', 'Never Open', const {}),
    ]);

    expect(find.textContaining('1 open now'), findsOneWidget);
    expect(find.text('Mamak Bistro'), findsOneWidget);
    expect(find.text('Never Open'), findsNothing);
    expect(find.text('Open 24 hours'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
