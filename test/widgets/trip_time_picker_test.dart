import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/trips/trip_time_picker.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';

void main() {
  Future<TimeOfDay?> open(WidgetTester tester, TimeOfDay initial) async {
    TimeOfDay? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showTripTimePicker(
                    context: context, initial: initial);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('opens showing the initial time', (tester) async {
    await open(tester, const TimeOfDay(hour: 10, minute: 0));

    expect(find.text('Time'), findsOneWidget);
    expect(find.text('10:00 AM'), findsOneWidget);
  });

  testWidgets('returns null when cancelled', (tester) async {
    await open(tester, const TimeOfDay(hour: 9, minute: 30));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Time'), findsNothing);
  });

  testWidgets('confirming returns the initial time unchanged', (tester) async {
    TimeOfDay? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showTripTimePicker(
                  context: context,
                  initial: const TimeOfDay(hour: 14, minute: 45),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set time'));
    await tester.pumpAndSettle();

    expect(result, const TimeOfDay(hour: 14, minute: 45));
  });

  // Midnight and noon are where 12-hour pickers usually go wrong.
  testWidgets('shows midnight as 12:00 AM', (tester) async {
    await open(tester, const TimeOfDay(hour: 0, minute: 0));
    expect(find.text('12:00 AM'), findsOneWidget);
  });

  testWidgets('shows noon as 12:00 PM', (tester) async {
    await open(tester, const TimeOfDay(hour: 12, minute: 0));
    expect(find.text('12:00 PM'), findsOneWidget);
  });

  testWidgets('switching period updates the preview and the result',
      (tester) async {
    TimeOfDay? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showTripTimePicker(
                  context: context,
                  initial: const TimeOfDay(hour: 9, minute: 15),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('9:15 AM'), findsOneWidget);
    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();
    expect(find.text('9:15 PM'), findsOneWidget);

    await tester.tap(find.text('Set time'));
    await tester.pumpAndSettle();
    expect(result, const TimeOfDay(hour: 21, minute: 15));
  });

  testWidgets('round-trips through the itinerary time format', (tester) async {
    // 12 AM must survive label -> TimeOfDay -> label without drifting to noon.
    for (final t in [
      const TimeOfDay(hour: 0, minute: 0),
      const TimeOfDay(hour: 12, minute: 0),
      const TimeOfDay(hour: 6, minute: 1),
      const TimeOfDay(hour: 23, minute: 59),
    ]) {
      await open(tester, t);
      expect(find.text(formatTimeOfDay(t)), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
  });
}
