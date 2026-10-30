import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/home/hero_ring.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget ring) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 128, height: 128, child: ring)),
      ),
    ),
  );

  /// The painter currently driving the ring. Its identity changes each frame
  /// while animating, which is what the animation tests key off.
  CustomPainter painterOf(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((c) => c.painter)
      .firstWhere(
        (p) => p?.runtimeType.toString().contains('RingPainter') ?? false,
      )!;

  testWidgets('renders its centre content', (tester) async {
    await pump(tester, const HeroRing(pct: 0.43, center: Text('43%')));

    expect(find.text('43%'), findsOneWidget);
  });

  testWidgets('fills its box', (tester) async {
    await pump(tester, const HeroRing(pct: 0.5, center: SizedBox()));

    expect(tester.getSize(find.byType(CustomPaint).last), const Size(128, 128));
  });

  // pct is clamped, so a value past 1.0 cannot sweep beyond a full turn and
  // overlap its own start cap.
  testWidgets('accepts out-of-range percentages without throwing', (
    tester,
  ) async {
    for (final pct in [-0.5, 0.0, 1.0, 1.7]) {
      await pump(tester, HeroRing(pct: pct, center: const SizedBox()));
      expect(tester.takeException(), isNull, reason: 'pct $pct');
    }
  });

  testWidgets('a static ring does not repaint against itself', (tester) async {
    await pump(tester, const HeroRing(pct: 0.6, center: SizedBox()));
    final first = painterOf(tester);

    await tester.pump(const Duration(milliseconds: 200));

    expect(painterOf(tester).shouldRepaint(first), isFalse);
  });

  group('AnimatedHeroRing', () {
    testWidgets('animates towards the target rather than snapping', (
      tester,
    ) async {
      await pump(
        tester,
        const AnimatedHeroRing(
          pct: 0.8,
          center: Text('80%'),
          duration: Duration(milliseconds: 300),
        ),
      );

      final atStart = painterOf(tester);
      await tester.pump(const Duration(milliseconds: 150));
      final midway = painterOf(tester);

      // Still moving: the painter reports it needs a repaint against the
      // earlier frame.
      expect(midway.shouldRepaint(atStart), isTrue);

      await tester.pumpAndSettle();
      final settled = painterOf(tester);
      expect(settled.shouldRepaint(midway), isTrue);

      // Settled: a further frame changes nothing.
      await tester.pump(const Duration(milliseconds: 200));
      expect(painterOf(tester).shouldRepaint(settled), isFalse);
    });

    testWidgets('clamps its target', (tester) async {
      await pump(
        tester,
        const AnimatedHeroRing(pct: 2.5, center: SizedBox()),
      );
      await tester.pumpAndSettle();

      final tween = tester
          .widget<TweenAnimationBuilder<double>>(
            find.byType(TweenAnimationBuilder<double>),
          )
          .tween;
      expect(tween.end, 1.0);
    });

    testWidgets('still renders its centre while animating', (tester) async {
      await pump(tester, const AnimatedHeroRing(pct: 0.25, center: Text('25%')));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('25%'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}
