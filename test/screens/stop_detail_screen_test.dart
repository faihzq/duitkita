import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/trips/stop_detail_screen.dart';
import 'package:duitkita/models/itinerary_stop.dart';
import 'package:duitkita/models/trip_model.dart';
import 'package:duitkita/services/trip_service.dart';

import '../helpers/fake_auth.dart';

void main() {
  final trip = TripModel(
    id: 'trip-1',
    name: 'Langkawi Road Trip',
    destinations: const ['Perlis', 'Kedah'],
    startDate: DateTime(2026, 8, 8),
    endDate: DateTime(2026, 8, 14),
    createdBy: 'uid-1',
    travellerIds: const ['uid-1'],
    travellers: const [TripTraveller(userId: 'uid-1', name: 'Ibu')],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final stop = ItineraryStop(
    id: 'stop-1',
    day: 3,
    time: '10:00 AM',
    title: 'Ferry to Langkawi',
    type: StopType.travel,
    icon: 'ferry',
    placeQuery: 'Kuala Perlis Ferry Terminal',
    legMinutes: 75,
    legKm: 45,
  );

  Future<void> pump(WidgetTester tester) async {
    // A real phone width — the footer bug only shows on narrow screens.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testApp(
        StopDetailScreen(trip: trip, stopId: stop.id),
        extraOverrides: [
          tripStopsStreamProvider(
            trip.id,
          ).overrideWith((ref) => Stream.value([stop])),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the stop', (tester) async {
    await pump(tester);

    expect(find.text('Ferry to Langkawi'), findsOneWidget);
    expect(find.text('Stop details'), findsOneWidget);
    expect(find.text('Kuala Perlis Ferry Terminal'), findsOneWidget);
    expect(find.text('Travel'), findsOneWidget);
    expect(find.text('10:00 AM'), findsOneWidget);
  });

  testWidgets('shows the leg estimate', (tester) async {
    await pump(tester);

    expect(find.text('~1 h 15 · 45 km'), findsOneWidget);
  });

  // "Open in Maps" was collapsing to "O…" because its Expanded was left at the
  // default flex of 1 against the Directions button's 6.
  testWidgets('footer buttons split 5:6, leaving both labels readable',
      (tester) async {
    await pump(tester);

    Size boxOf(String label) => tester.getSize(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(GestureDetector),
              )
              .first,
        );

    final maps = boxOf('Open in Maps');
    final directions = boxOf('Directions');

    expect(maps.width / directions.width, closeTo(5 / 6, 0.02));

    // The label must fit rather than ellipsize inside its button.
    final textWidth = tester.getSize(find.text('Open in Maps')).width;
    expect(textWidth, greaterThan(70));
  });

  // The fake auth controller reports no signed-in user, so nobody in these
  // tests is the organiser. Rules enforce this server-side; the UI must not
  // offer an action that would be rejected.
  testWidgets('hides edit and delete from anyone but the organiser',
      (tester) async {
    await pump(tester);

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  });

  testWidgets('still shows the place and both map actions', (tester) async {
    await pump(tester);

    // Read access is unaffected — only editing is restricted.
    expect(find.text('Open in Maps'), findsOneWidget);
    expect(find.text('Directions'), findsOneWidget);
  });

  testWidgets('falls back to generic copy when the stop has no about text',
      (tester) async {
    await pump(tester);

    expect(
      find.text(
          'A leg of the journey — open the map to navigate and gauge drive time.'),
      findsOneWidget,
    );
  });
}
