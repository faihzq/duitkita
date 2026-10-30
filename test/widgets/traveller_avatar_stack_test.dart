import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';
import 'package:duitkita/models/trip_model.dart';

void main() {
  List<TripTraveller> people(int n) => [
        for (var i = 0; i < n; i++)
          TripTraveller(userId: 'uid-$i', name: 'Traveller $i'),
      ];

  Future<void> pump(WidgetTester tester, int n, {double size = 34}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TravellerAvatarStack(travellers: people(n), size: size),
          ),
        ),
      ),
    );
  }

  // The stack used to overlap avatars with a negative Container margin, which
  // trips `margin.isNonNegative` the moment a second avatar exists.
  group('renders without overflowing or asserting', () {
    for (final n in [1, 2, 3, 5, 6, 12]) {
      testWidgets('$n travellers', (tester) async {
        await pump(tester, n);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('is empty when there are no travellers', (tester) async {
    await pump(tester, 0);
    expect(find.byType(TripAvatar), findsNothing);
  });

  testWidgets('overlaps avatars instead of laying them out end to end',
      (tester) async {
    await pump(tester, 3, size: 34);

    // outer (38) + 2 * advance (28) = 94, versus 114 with no overlap.
    final box = tester.getSize(find.byType(TravellerAvatarStack));
    expect(box.width, 94);
    expect(box.height, 38);
  });

  testWidgets('caps the avatars and shows a +N chip beyond the max',
      (tester) async {
    await pump(tester, 8);

    expect(find.byType(TripAvatar), findsNWidgets(5));
    expect(find.text('+3'), findsOneWidget);
  });

  testWidgets('shows no +N chip at exactly the max', (tester) async {
    await pump(tester, 5);

    expect(find.byType(TripAvatar), findsNWidgets(5));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('paints the leftmost avatar on top', (tester) async {
    await pump(tester, 3);

    // Reversed paint order: the last Positioned in the tree is the first
    // traveller, so it renders above its neighbours.
    final positioned =
        tester.widgetList<Positioned>(find.byType(Positioned)).toList();
    expect(positioned.last.left, 0);
  });
}
