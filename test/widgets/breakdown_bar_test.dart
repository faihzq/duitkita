import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/features/home/breakdown_bar.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    double groups = 0,
    double debts = 0,
    double bills = 0,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: BreakdownSegmentBar(
              groupMonthly: groups,
              debtMonthly: debts,
              billMonthly: bills,
            ),
          ),
        ),
      ),
    ),
  );

  // Scoped to the bar: Scaffold and Material paint their own ColoredBoxes.
  final segmentFinder = find.descendant(
    of: find.byType(BreakdownSegmentBar),
    matching: find.byType(ColoredBox),
  );

  /// The laid-out segments, in order.
  List<Size> segmentSizes(WidgetTester tester) => tester
      .widgetList<ColoredBox>(segmentFinder)
      .map((b) => tester.getSize(find.byWidget(b)))
      .toList();

  // The bug this guards: a childless ColoredBox takes constraints.smallest, so
  // with the Row's default centre alignment every segment rendered 0 high and
  // the bar was invisible.
  testWidgets('segments are drawn at full height, not collapsed', (
    tester,
  ) async {
    await pump(tester, groups: 580, debts: 400, bills: 743);

    final sizes = segmentSizes(tester);
    expect(sizes, hasLength(3));
    for (final s in sizes) {
      expect(s.height, 12, reason: 'segment collapsed to ${s.height}');
      expect(s.width, greaterThan(0));
    }
  });

  testWidgets('widths are proportional to the amounts', (tester) async {
    await pump(tester, groups: 100, debts: 200, bills: 100);

    final sizes = segmentSizes(tester);
    // The middle category is twice either side.
    expect(sizes[1].width / sizes[0].width, closeTo(2.0, 0.05));
    expect(sizes[2].width, closeTo(sizes[0].width, 0.5));
  });

  testWidgets('shows only the categories that have a commitment', (
    tester,
  ) async {
    await pump(tester, groups: 300, bills: 50);

    expect(segmentSizes(tester), hasLength(2));
  });

  testWidgets('renders nothing when there is no commitment', (tester) async {
    await pump(tester);

    expect(segmentFinder, findsNothing);
    expect(tester.getSize(find.byType(BreakdownSegmentBar)).height, 0);
  });

  testWidgets('a tiny amount still gets a visible sliver', (tester) async {
    // (0.004 * 100).round() is 0, which would collapse the segment.
    await pump(tester, groups: 1000, bills: 0.004);

    final sizes = segmentSizes(tester);
    expect(sizes, hasLength(2));
    expect(sizes.last.width, greaterThan(0));
  });

  testWidgets('uses the category colours', (tester) async {
    await pump(tester, groups: 10, debts: 10, bills: 10);

    final colours = tester
        .widgetList<ColoredBox>(segmentFinder)
        .map((b) => b.color)
        .toList();
    expect(colours, [DT.catGroups, DT.catDebts, DT.catBills]);
  });
}
