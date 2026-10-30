import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:duitkita/features/jdt/jdt_matches_screen.dart';
import 'package:duitkita/models/match_model.dart';
import 'package:duitkita/services/match_service.dart';

/// Drives the screen with canned fixtures so the team toggle can be exercised
/// without a network, Firebase, or a signed-in user.
void main() {
  MatchModel finished() => MatchModel(
    id: 'done-1',
    homeTeam: "Johor Darul Ta'zim",
    awayTeam: 'Imigresen',
    // Midnight: the Results section of the source page carries a score where
    // fixtures carry a kick-off, so a scraped result has no time of day.
    matchDate: DateTime(2026, 8, 29),
    league: 'Malaysian Super League',
    status: 'FT',
    homeScore: 7,
    awayScore: 0,
  );

  MatchModel fixture(FootballTeam team) => MatchModel(
    id: '${team.name}-1',
    homeTeam: team == FootballTeam.jdt ? "Johor Darul Ta'zim" : 'Malaysia',
    awayTeam: team == FootballTeam.jdt ? 'Negeri Sembilan' : 'Vietnam',
    matchDate: DateTime(2026, 9, 11, 21),
    league: team.fallbackLeague,
    status: 'NS',
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchServiceProvider.overrideWithValue(
            MatchService(
              client: MockClient((_) async => http.Response('', 200)),
              firestore: FakeFirebaseFirestore(),
            ),
          ),
          upcomingMatchesProvider.overrideWith(
            (ref, team) async => [fixture(team)],
          ),
          recentResultsProvider.overrideWith((ref, team) async => [finished()]),
        ],
        child: const MaterialApp(home: JdtMatchesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers both teams and opens on JDT', (tester) async {
    await pump(tester);

    expect(find.text('JDT'), findsOneWidget);
    expect(find.text('Malaysia'), findsOneWidget);
    expect(find.text('JDT Matches'), findsOneWidget);
    expect(find.text("Johor Darul Ta'zim"), findsWidgets);
  });

  testWidgets('switching team swaps the fixtures and the title', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Malaysia'));
    await tester.pumpAndSettle();

    expect(find.text('Malaysia Matches'), findsOneWidget);
    expect(find.text('Vietnam'), findsWidgets);
    expect(find.text('Negeri Sembilan'), findsNothing);
  });

  testWidgets('the add-match button is JDT only', (tester) async {
    // Manual fixtures are stored for JDT alone, so offering the button on the
    // national side would write matches that never surface.
    await pump(tester);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.text('Malaysia'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('a finished match shows a date with no invented time', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();

    expect(find.textContaining('29 Aug 2026'), findsOneWidget);
    // The old card printed "00:00" here for every result.
    expect(find.textContaining('00:00'), findsNothing);
  });

  testWidgets('a fixture still shows its kick-off', (tester) async {
    await pump(tester);
    expect(find.textContaining('21:00'), findsOneWidget);
  });
}
