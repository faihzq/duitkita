import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';
import 'package:duitkita/models/trip_model.dart';

void main() {
  const travellers = [
    TripTraveller(userId: 'uid-1', name: 'Ibu'),
    TripTraveller(userId: 'uid-2', name: 'Along'),
    TripTraveller(userId: 'uid-3', name: 'Angah'),
  ];

  Future<void> open(WidgetTester tester, {String? currentUserId}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showTravellersSheet(
                context,
                travellers: travellers,
                organiserId: 'uid-1',
                currentUserId: currentUserId,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists everyone on the trip', (tester) async {
    await open(tester);

    expect(find.text('Travellers'), findsOneWidget);
    expect(find.text('3 on this trip'), findsOneWidget);
    expect(find.text('Along'), findsOneWidget);
    expect(find.text('Angah'), findsOneWidget);
  });

  testWidgets('marks the organiser', (tester) async {
    await open(tester);

    expect(find.text('Organiser'), findsOneWidget);
    expect(find.text('Ibu'), findsOneWidget);
  });

  testWidgets('marks the signed-in traveller as you', (tester) async {
    await open(tester, currentUserId: 'uid-2');

    expect(find.text('Along (you)'), findsOneWidget);
    // Plain name for everyone else.
    expect(find.text('Angah'), findsOneWidget);
  });

  testWidgets('shows an avatar per traveller', (tester) async {
    await open(tester);

    expect(find.byType(TripAvatar), findsNWidgets(3));
  });

  testWidgets('dismisses on tap outside', (tester) async {
    await open(tester);
    expect(find.text('Travellers'), findsOneWidget);

    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();

    expect(find.text('Travellers'), findsNothing);
  });
}
