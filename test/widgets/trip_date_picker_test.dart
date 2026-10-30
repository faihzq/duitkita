import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/features/trips/trip_date_picker.dart';

void main() {
  final initial = DateTime(2026, 8, 8);

  /// Pumps a host screen and opens the picker, recording what it returns.
  Future<List<DateTime?>> open(WidgetTester tester, {String? helpText}) async {
    final results = <DateTime?>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                results.add(await showTripDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(2025),
                  lastDate: DateTime(2030),
                  helpText: helpText,
                ));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('opens with the DuitKita help text', (tester) async {
    await open(tester, helpText: 'TRIP STARTS');

    expect(find.text('TRIP STARTS'), findsOneWidget);
  });

  testWidgets('confirming returns the selected date', (tester) async {
    final results = await open(tester);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(results.single, initial);
  });

  testWidgets('cancelling returns null', (tester) async {
    final results = await open(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(results.single, isNull);
  });

  testWidgets('is themed in app colours, not the M3 default', (tester) async {
    await open(tester);

    final theme = Theme.of(
      tester.element(find.byType(DatePickerDialog)),
    ).datePickerTheme;

    expect(theme.headerBackgroundColor, DT.text);
    expect(theme.backgroundColor, DT.surface);
    // The lavender cast comes from the M3 surface tint.
    expect(theme.surfaceTintColor, Colors.transparent);
  });
}
