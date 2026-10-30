import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/widgets/dk_toast.dart';

void main() {
  /// Pumps a screen with a button that fires [onPressed].
  Future<void> host(
    WidgetTester tester,
    void Function(BuildContext) onPressed,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => ElevatedButton(
                  onPressed: () => onPressed(context),
                  child: const Text('fire'),
                ),
          ),
        ),
      ),
    );
  }

  Future<void> fire(WidgetTester tester) async {
    await tester.tap(find.text('fire'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('DkToast', () {
    testWidgets('shows a title', (tester) async {
      await host(tester, (c) => DkToast.success(c, 'Stop added'));
      await fire(tester);

      expect(find.text('Stop added'), findsOneWidget);
    });

    testWidgets('shows body copy and an action', (tester) async {
      await host(
        tester,
        (c) => DkToast.error(
          c,
          "Couldn't create group",
          message: 'Check your connection and try again.',
          actionLabel: 'Retry',
          onAction: () {},
        ),
      );
      await fire(tester);

      expect(find.text("Couldn't create group"), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('running the action dismisses the toast', (tester) async {
      var tapped = false;
      await host(
        tester,
        (c) => DkToast.info(
          c,
          'Reminder sent',
          actionLabel: 'Undo',
          onAction: () => tapped = true,
        ),
      );
      await fire(tester);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(find.text('Reminder sent'), findsNothing);
    });

    testWidgets('auto-dismisses when its time is up', (tester) async {
      await host(
        tester,
        (c) => DkToast.success(
          c,
          'Saved',
          duration: const Duration(milliseconds: 600),
        ),
      );
      await fire(tester);
      expect(find.text('Saved'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('stacks several at once', (tester) async {
      await host(tester, (c) {
        DkToast.success(c, 'First');
        DkToast.success(c, 'Second');
      });
      await fire(tester);

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsNothing);
    });

    // The stack is capped at 3, so the oldest is faded out entirely.
    // Note: a plain pump, not pumpAndSettle — the auto-dismiss timer keeps
    // scheduling frames, so settling would run every toast to its end.
    testWidgets('fades the oldest out beyond three', (tester) async {
      await host(tester, (c) {
        for (final t in ['One', 'Two', 'Three', 'Four']) {
          DkToast.info(c, t);
        }
      });
      await fire(tester);

      expect(find.text('Four'), findsOneWidget);

      double opacityOf(String label) =>
          tester
              .widget<Opacity>(
                find
                    .ancestor(
                      of: find.text(label),
                      matching: find.byType(Opacity),
                    )
                    .first,
              )
              .opacity;

      expect(opacityOf('Four'), greaterThan(0));
      expect(opacityOf('One'), 0);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('showSnackBar', () {
    testWidgets('routes a plain message to a success toast', (tester) async {
      await host(tester, (c) => showSnackBar(c, 'Trip updated'));
      await fire(tester);

      expect(find.text('Trip updated'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('routes isError to an error toast', (tester) async {
      await host(
        tester,
        (c) => showSnackBar(c, 'Could not save', isError: true),
      );
      await fire(tester);

      expect(find.text('Could not save'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    // Call sites routinely report success right after Navigator.pop, and the
    // overlay lookup would otherwise run against a dead context.
    testWidgets('does nothing for an unmounted context', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(() => showSnackBar(captured, 'gone'), returnsNormally);
    });

    // Sign-up, login and every other form reports its errors by toast while the
    // keyboard is still up. Anchored to padding.bottom alone the card renders
    // underneath the keyboard, so the user sees no feedback and reads the
    // screen as frozen.
    testWidgets('lifts above an open keyboard', (tester) async {
      const screen = 800.0;
      const keyboard = 320.0;

      // The toast renders in the Navigator's overlay, which sits above any
      // MediaQuery a screen inserts — so the insets have to come from the view,
      // exactly as the real keyboard does.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, screen);
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.reset);

      await host(
        tester,
        (c) => showSnackBar(c, 'Email already in use', isError: true),
      );
      await fire(tester);

      final card = tester.getRect(find.text('Email already in use'));

      expect(
        card.bottom,
        lessThan(screen - keyboard),
        reason: 'toast is hidden behind the keyboard',
      );

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}
