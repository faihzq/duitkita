import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/trips/trip_form_screen.dart';
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
    status: TripStatus.confirmed,
    createdBy: 'uid-1',
    travellerIds: const ['uid-1', 'uid-2'],
    travellers: const [
      TripTraveller(userId: 'uid-1', name: 'Ibu'),
      TripTraveller(userId: 'uid-2', name: 'Along'),
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<void> pump(WidgetTester tester, {TripModel? editing}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testApp(
        TripFormScreen(editing: editing),
        extraOverrides: [
          tripStopsStreamProvider(trip.id)
              .overrideWith((ref) => Stream.value(const <ItineraryStop>[])),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  group('edit mode', () {
    testWidgets('loads the trip into the form', (tester) async {
      await pump(tester, editing: trip);

      expect(find.text('Edit trip'), findsOneWidget);
      expect(find.text('Langkawi Road Trip'), findsWidgets);
      expect(find.text('Perlis'), findsOneWidget);
      expect(find.text('Kedah'), findsOneWidget);
      expect(find.text('8 Aug 2026'), findsOneWidget);
      expect(find.text('14 Aug 2026'), findsOneWidget);
    });

    testWidgets('saves rather than creating', (tester) async {
      await pump(tester, editing: trip);

      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Create & add itinerary'), findsNothing);
    });

    testWidgets('lists travellers so they can be removed', (tester) async {
      await pump(tester, editing: trip);
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Ibu'), findsOneWidget);
      expect(find.text('Along'), findsOneWidget);
    });

    testWidgets('marks the creator as organiser and gives them no remove button',
        (tester) async {
      await pump(tester, editing: trip);
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Organiser'), findsOneWidget);
      // Only the non-organiser row carries a close button.
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('removing a traveller drops them from the list',
        (tester) async {
      await pump(tester, editing: trip);
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Along'), findsNothing);
      expect(find.text('Ibu'), findsOneWidget);
    });
  });

  group('create mode', () {
    testWidgets('starts empty with the create CTA', (tester) async {
      await pump(tester);

      expect(find.text('New trip'), findsOneWidget);
      expect(find.text('Create & add itinerary'), findsOneWidget);
      expect(find.text('Pick a date'), findsNWidgets(2));
    });

    testWidgets('hides the traveller list until someone is added',
        (tester) async {
      await pump(tester);

      // Only the signed-in user is seeded, so there is nobody to remove.
      expect(find.text('On this trip'), findsNothing);
    });
  });
}
