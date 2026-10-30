import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/screens/auth_widgets.dart';

void main() {
  Future<void> pumpButton(WidgetTester tester, {bool loading = false}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: SizedBox(
              width: 300,
              child: GoogleButton(onPressed: () {}, loading: loading),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('draws a mark rather than a lettered G', (tester) async {
    await pumpButton(tester);

    expect(find.text('Continue with Google'), findsOneWidget);
    // The old mark was a Manrope "G" in a single blue; the logo is painted now.
    expect(find.text('G'), findsNothing);
  });

  testWidgets('the mark is a 20pt square painted inside the button',
      (tester) async {
    await pumpButton(tester);

    final mark = find.byWidgetPredicate(
      (w) =>
          w is CustomPaint &&
          (w.painter?.runtimeType.toString().contains('GoogleMark') ?? false),
    );

    expect(mark, findsOneWidget);
    // The laid-out size, not CustomPaint.size — that stays zero when the
    // parent constrains the painter.
    expect(tester.getSize(mark), const Size(20, 20));
  });

  testWidgets('swaps the mark for a spinner while signing in', (tester) async {
    await pumpButton(tester, loading: true);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('is not tappable while loading', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GoogleButton(onPressed: () => taps++, loading: true),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(GoogleButton));
    await tester.pump();

    expect(taps, 0);
  });
}
