import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/trips/import_itinerary_screen.dart';
import 'package:duitkita/models/trip_model.dart';

import '../helpers/fake_auth.dart';

void main() {
  // 3-day trip, so day 4 is out of range.
  final trip = TripModel(
    id: 'trip-1',
    name: 'Langkawi Road Trip',
    startDate: DateTime(2026, 8, 8),
    endDate: DateTime(2026, 8, 10),
    createdBy: 'uid-1',
    travellerIds: const ['uid-1'],
    travellers: const [TripTraveller(userId: 'uid-1', name: 'Ibu')],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testApp(ImportItineraryScreen(trip: trip, initialDay: 1)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> paste(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read itinerary'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the paste step', (tester) async {
    await pump(tester);

    expect(find.text('Paste itinerary'), findsOneWidget);
    expect(find.text('Read itinerary'), findsOneWidget);
  });

  testWidgets('parses a paste into a reviewable list', (tester) async {
    await pump(tester);
    await paste(tester, 'Day 1\n10:00 AM Ferry to Langkawi\n1:00 PM Cable Car');

    expect(find.text('Review import'), findsOneWidget);
    expect(find.text('Ferry to Langkawi'), findsOneWidget);
    expect(find.text('Cable Car'), findsOneWidget);
    expect(find.text('Add 2 stops'), findsOneWidget);
  });

  testWidgets('groups the preview by day with real dates', (tester) async {
    await pump(tester);
    await paste(tester, 'Day 1\n10:00 AM Ferry\nDay 2\n9:00 AM Breakfast');

    expect(find.textContaining('Day 1 · Sat, 8 Aug'), findsOneWidget);
    expect(find.textContaining('Day 2 · Sun, 9 Aug'), findsOneWidget);
  });

  testWidgets('warns about lines with no time rather than dropping them',
      (tester) async {
    await pump(tester);
    await paste(tester, '10:00 AM Ferry\nremember sunscreen');

    expect(find.textContaining('remember sunscreen'), findsOneWidget);
    expect(find.text('Add 1 stop'), findsOneWidget);
  });

  // Stops past the last day would sit behind day tabs that do not exist.
  testWidgets('warns about stops beyond the end of the trip', (tester) async {
    await pump(tester);
    await paste(tester, 'Day 4\n10:00 AM Too far');

    expect(find.textContaining('beyond day 3'), findsOneWidget);
    expect(find.text('Nothing to import'), findsOneWidget);
  });

  testWidgets('refuses a paste with no times at all', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, 'just some notes');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read itinerary'));

    // Plain pumps, not pumpAndSettle: the toast animates for its whole life,
    // so settling would run it past its auto-dismiss and find nothing.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Stays on the paste step and explains why.
    expect(find.text('Paste itinerary'), findsOneWidget);
    expect(find.textContaining('needs a time'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('back from review returns to the paste step', (tester) async {
    await pump(tester);
    await paste(tester, '10:00 AM Ferry');

    expect(find.text('Review import'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Paste itinerary'), findsOneWidget);
  });
}
