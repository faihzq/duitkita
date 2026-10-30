import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/trips/add_stop_screen.dart';
import 'package:duitkita/models/itinerary_stop.dart';
import 'package:duitkita/models/trip_model.dart';
import 'package:duitkita/services/trip_service.dart';

void main() {
  final trip = TripModel(
    id: 'trip-1',
    name: 'Langkawi Road Trip',
    startDate: DateTime(2026, 8, 8),
    endDate: DateTime(2026, 8, 14),
    createdBy: 'uid-1',
    travellerIds: const ['uid-1'],
    travellers: const [TripTraveller(userId: 'uid-1', name: 'Ibu')],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  ItineraryStop stop(String id, int day, String time, {String? place}) =>
      ItineraryStop(
        id: id,
        day: day,
        time: time,
        title: 'Stop $id',
        placeQuery: place,
      );

  Future<void> pump(
    WidgetTester tester, {
    required List<ItineraryStop> stops,
    int day = 1,
    ItineraryStop? editing,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripStopsStreamProvider(trip.id).overrideWith((ref) => Stream.value(stops)),
        ],
        child: MaterialApp(
          home: AddStopScreen(trip: trip, initialDay: day, editing: editing),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('default time', () {
    testWidgets('falls back to 9:00 AM on an empty day', (tester) async {
      await pump(tester, stops: []);

      expect(find.text('9:00 AM'), findsOneWidget);
    });

    testWidgets('starts 30 minutes after the day\'s last stop', (tester) async {
      await pump(tester, day: 3, stops: [
        stop('a', 3, '6:01 AM'),
        stop('b', 3, '6:30 PM'),
        stop('c', 3, '1:00 PM'),
      ]);

      // Latest on day 3 is 6:30 PM, regardless of document order.
      expect(find.text('7:00 PM'), findsOneWidget);
    });

    testWidgets('ignores stops on other days', (tester) async {
      await pump(tester, day: 2, stops: [
        stop('a', 1, '11:00 PM'),
        stop('b', 2, '8:00 AM'),
        stop('c', 3, '9:00 PM'),
      ]);

      expect(find.text('8:30 AM'), findsOneWidget);
    });

    testWidgets('clamps at 23:59 instead of rolling past midnight',
        (tester) async {
      await pump(tester, day: 1, stops: [stop('a', 1, '11:50 PM')]);

      expect(find.text('11:59 PM'), findsOneWidget);
    });

    testWidgets('re-defaults when the day chip changes', (tester) async {
      await pump(tester, day: 1, stops: [
        stop('a', 1, '8:00 AM'),
        stop('b', 2, '4:00 PM'),
      ]);
      expect(find.text('8:30 AM'), findsOneWidget);

      // Day 2's chip shows the 9th of August.
      await tester.tap(find.text('9'));
      await tester.pumpAndSettle();

      expect(find.text('4:30 PM'), findsOneWidget);
      expect(find.text('8:30 AM'), findsNothing);
    });

    testWidgets('stops re-defaulting once the user picks a time',
        (tester) async {
      await pump(tester, day: 1, stops: [
        stop('a', 1, '8:00 AM'),
        stop('b', 2, '4:00 PM'),
      ]);
      expect(find.text('8:30 AM'), findsOneWidget);

      // Open the picker and confirm, which marks the time as user-chosen.
      await tester.tap(find.text('8:30 AM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('9'));
      await tester.pumpAndSettle();

      // Day 2 would have defaulted to 4:30 PM had the pick not stuck.
      expect(find.text('8:30 AM'), findsOneWidget);
      expect(find.text('4:30 PM'), findsNothing);
    });

    testWidgets('editing keeps the stop\'s own time', (tester) async {
      await pump(
        tester,
        day: 1,
        stops: [stop('a', 1, '8:00 AM'), stop('b', 1, '2:15 PM')],
        editing: stop('b', 1, '2:15 PM'),
      );

      // Not 2:45 PM — an edit must not be re-defaulted.
      expect(find.text('2:15 PM'), findsOneWidget);
      expect(find.text('Edit stop'), findsOneWidget);
    });
  });

  group('map link', () {
    // Fields in order: title, place, mapUrl, legMins, legKm, note, about.
    Finder mapUrlField() => find.byType(TextField).at(2);

    testWidgets('offers no resolve button until a Maps link is pasted',
        (tester) async {
      await pump(tester, stops: []);

      expect(find.text('Use exact location from this link'), findsNothing);

      await tester.enterText(mapUrlField(), 'Jeti Kuala Perlis');
      await tester.pumpAndSettle();
      expect(find.text('Use exact location from this link'), findsNothing);
    });

    testWidgets('offers to resolve once the text is a Maps link',
        (tester) async {
      await pump(tester, stops: []);

      await tester.enterText(mapUrlField(), 'https://maps.app.goo.gl/AbCdEf');
      await tester.pumpAndSettle();

      expect(find.text('Use exact location from this link'), findsOneWidget);
    });

    testWidgets('fills Place with coordinates the link already carries',
        (tester) async {
      await pump(tester, stops: []);

      await tester.enterText(
        mapUrlField(),
        'https://www.google.com/maps/place/X/@5.4239,100.2685,17z',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use exact location from this link'));
      await tester.pumpAndSettle();

      final place = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(place.controller?.text, '5.4239,100.2685');
    });

    testWidgets('loads an existing link when editing', (tester) async {
      await pump(
        tester,
        stops: [],
        editing: ItineraryStop(
          id: 'b',
          day: 1,
          time: '2:15 PM',
          title: 'Home',
          mapUrl: 'https://maps.app.goo.gl/Saved',
        ),
      );

      final field = tester.widget<TextField>(mapUrlField());
      expect(field.controller?.text, 'https://maps.app.goo.gl/Saved');
    });
  });

  group('leg lookup', () {
    /// The drive-estimate field sits below the fold, and ListView does not
    /// build off-screen children — without this every assertion below would
    /// pass or fail for the wrong reason.
    Future<void> scrollToDriveField(WidgetTester tester) async {
      // .first is the form; the day chip strip is a second, horizontal ListView.
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
    }

    testWidgets('is hidden when nothing earlier in the day is mappable',
        (tester) async {
      await pump(tester, day: 1, stops: []);

      await scrollToDriveField(tester);

      expect(find.textContaining('Check this leg'), findsNothing);
      expect(find.textContaining('Add a place first'), findsNothing);
    });

    testWidgets('names the stop it measures from', (tester) async {
      await pump(tester, day: 1, stops: [
        stop('a', 1, '8:00 AM', place: 'Kajang'),
      ]);

      await scrollToDriveField(tester);

      expect(find.textContaining('Add a place first'), findsOneWidget);
      expect(find.textContaining('Stop a'), findsOneWidget);
    });

    testWidgets('enables once this stop has a place', (tester) async {
      await pump(tester, day: 1, stops: [
        stop('a', 1, '8:00 AM', place: 'Kajang'),
      ]);

      // Fields in order: title, place, legMins, legKm, note, about.
      await tester.enterText(find.byType(TextField).at(1), 'Ipoh');
      await tester.pumpAndSettle();

      await scrollToDriveField(tester);

      expect(find.textContaining('Check this leg'), findsOneWidget);
      expect(find.textContaining('Add a place first'), findsNothing);
    });

    testWidgets('measures from the latest stop before the chosen time',
        (tester) async {
      await pump(tester, day: 1, stops: [
        stop('a', 1, '8:00 AM', place: 'Kajang'),
        stop('b', 1, '6:00 PM', place: 'Ipoh'),
      ]);

      await scrollToDriveField(tester);

      // Default is 6:30 PM, so the 6:00 PM stop is the predecessor.
      expect(find.textContaining('Stop b'), findsOneWidget);
      expect(find.textContaining('Stop a'), findsNothing);
    });

    testWidgets('skips the stop being edited and looks further back',
        (tester) async {
      await pump(
        tester,
        day: 1,
        stops: [
          stop('a', 1, '8:00 AM', place: 'Kajang'),
          stop('b', 1, '6:00 PM', place: 'Ipoh'),
        ],
        editing: stop('b', 1, '6:00 PM', place: 'Ipoh'),
      );

      await scrollToDriveField(tester);

      // b is the stop being edited, so the leg is measured from a.
      expect(find.textContaining('Stop a'), findsOneWidget);
      expect(find.textContaining('Stop b'), findsNothing);
    });

    testWidgets('ignores stops on other days', (tester) async {
      await pump(tester, day: 2, stops: [
        stop('a', 1, '8:00 AM', place: 'Kajang'),
      ]);

      await scrollToDriveField(tester);

      expect(find.textContaining('Stop a'), findsNothing);
    });
  });
}
